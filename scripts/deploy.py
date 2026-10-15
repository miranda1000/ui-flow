#!/usr/bin/env python3
"""deploy.py --target <t> --dist <dir> --qml <qml source dir>

Linux-hosted stand-in for windeployqt / linuxdeployqt. Copies the Qt runtime that the
installed executable needs (libraries, platform/image plugins, QML modules) next to it
and writes qt.conf.

  Windows:  <dist>/ui-flow.exe, Qt6*.dll, plugins/, qml/, qt.conf
  Linux:    <dist>/ui-flow, lib/, plugins/, qml/, qt.conf   (RUNPATH $ORIGIN/lib)

Dependencies are followed transitively; anything not found in the Qt installation is a
system library and is left alone. Needs llvm-readobj (and patchelf for Linux).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

QT_ENV = {
    "linux-x64": "QT_LINUX_X64_PATH",
    "linux-arm64": "QT_LINUX_ARM64_PATH",
    "windows-x64": "QT_WIN_X64_PATH",
    "windows-arm64": "QT_WIN_ARM64_PATH",
}

# Plugins (relative to <qt>/plugins). A directory name means "all release files in it".
WINDOWS_PLUGINS = [
    "platforms/qwindows.dll",
    "imageformats/qsvg.dll", "imageformats/qjpeg.dll", "imageformats/qgif.dll", "imageformats/qico.dll",
    "iconengines/qsvgicon.dll",
]
LINUX_PLUGINS = [
    "platforms/libqxcb.so", "platforms/libqwayland.so",
    "xcbglintegrations",
    "wayland-shell-integration", "wayland-decoration-client", "wayland-graphics-integration-client",
    "platforminputcontexts",
    "platformthemes/libqxdgdesktopportal.so", "platformthemes/libqgtk3.so",
    "imageformats/libqsvg.so", "imageformats/libqjpeg.so", "imageformats/libqgif.so", "imageformats/libqico.so",
    "iconengines/libqsvgicon.so",
]
# QML modules loaded at run time that qmlimportscanner does not see (style internals,
# the non-native file dialog implementation). Copied recursively.
EXTRA_QML_TREES = [
    "QtQuick/Controls/impl", "QtQuick/Controls/Basic", "QtQuick/Templates",
    "QtQuick/Dialogs", "QtQuick/Layouts", "QtQuick/Shapes", "QtQml/WorkerScript",
]
SKIP_SUFFIXES = (".pdb", ".lib", ".prl", ".debug", ".a")
# Controls styles other than Basic (the app forces Basic): reported by the scanner as
# optional imports of QtQuick.Controls, never loaded.
UNUSED_QML_PREFIXES = tuple("QtQuick/Controls/" + s for s in (
    "Fusion", "Imagine", "Material", "Universal", "FluentWinUI3", "Windows", "macOS", "iOS")) + ("QtQuick/NativeStyle",)


def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def is_debug_twin(path):
    """foo d.dll next to foo.dll (Windows debug build of a Qt binary)."""
    name = os.path.basename(path)
    return name.lower().endswith("d.dll") and os.path.exists(path[:-5] + ".dll")


def wanted_file(path, windows):
    lower = path.lower()
    if lower.endswith(SKIP_SUFFIXES):
        return False
    if windows and is_debug_twin(path):
        return False
    return True


class Deployer:
    def __init__(self, target, dist, qml_src):
        self.target = target
        self.windows = target.startswith("windows")
        self.dist = os.path.realpath(dist)
        self.qml_src = os.path.realpath(qml_src)
        self.qt = os.environ.get(QT_ENV[target]) or sys.exit(f"{QT_ENV[target]} is not set")
        self.host_qt = os.environ.get("QT_HOST_PATH") or sys.exit("QT_HOST_PATH is not set")
        self.lib_src = os.path.join(self.qt, "bin" if self.windows else "lib")
        self.lib_dst = self.dist if self.windows else os.path.join(self.dist, "lib")
        self.seen = set()
        self.queue = []
        self.elf_files = []
        self.lib_index = {n.lower() if self.windows else n: n for n in os.listdir(self.lib_src)}

    # --- dependency walking
    def needed(self, path):
        if self.windows:
            out = run(["llvm-readobj", "--coff-imports", path])
            return [l.split(":", 1)[1].strip() for l in out.splitlines() if l.strip().startswith("Name:")]
        out = run(["llvm-readobj", "--needed-libs", path])
        libs, inside = [], False
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("NeededLibraries"):
                inside = True
            elif inside and line == "]":
                inside = False
            elif inside and line:
                libs.append(line)
        return libs

    def copy_lib(self, name):
        key = name.lower() if self.windows else name
        if key in self.seen:
            return
        self.seen.add(key)
        real = self.lib_index.get(key)
        if not real:
            return  # system library
        os.makedirs(self.lib_dst, exist_ok=True)
        dst = os.path.join(self.lib_dst, real)
        shutil.copy2(os.path.realpath(os.path.join(self.lib_src, real)), dst)
        self.add_binary(dst)

    def add_binary(self, path):
        self.queue.append(path)
        if not self.windows:
            self.elf_files.append(path)

    def resolve(self):
        i = 0
        while i < len(self.queue):
            for dep in self.needed(self.queue[i]):
                self.copy_lib(dep)
            i += 1

    # --- plugins and QML
    def copy_file(self, src, dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        if dst.endswith((".dll", ".so")) or ".so." in os.path.basename(dst):
            self.add_binary(dst)

    def copy_plugins(self):
        for rel in WINDOWS_PLUGINS if self.windows else LINUX_PLUGINS:
            src = os.path.join(self.qt, "plugins", rel)
            if os.path.isdir(src):
                for name in sorted(os.listdir(src)):
                    f = os.path.join(src, name)
                    if os.path.isfile(f) and wanted_file(f, self.windows):
                        self.copy_file(f, os.path.join(self.dist, "plugins", rel, name))
            elif os.path.isfile(src):
                self.copy_file(src, os.path.join(self.dist, "plugins", rel))
            else:
                print(f"    (plugin {rel} not in this Qt, skipped)")

    def copy_qml_dir(self, rel, recursive):
        src = os.path.join(self.qt, "qml", rel)
        if not os.path.isdir(src):
            return
        for root, dirs, files in os.walk(src):
            for name in files:
                f = os.path.join(root, name)
                if wanted_file(f, self.windows):
                    self.copy_file(f, os.path.join(self.dist, "qml", os.path.relpath(f, os.path.join(self.qt, "qml"))))
            if not recursive:
                break

    def copy_qml(self):
        scanner = os.path.join(self.host_qt, "libexec", "qmlimportscanner")
        out = run([scanner, "-rootPath", self.qml_src, "-importPath", os.path.join(self.qt, "qml")])
        qt_qml = os.path.realpath(os.path.join(self.qt, "qml"))
        modules = set()
        for entry in json.loads(out):
            path = entry.get("path")
            if entry.get("type") != "module" or not path:
                continue
            rel = os.path.relpath(os.path.realpath(path), qt_qml)
            if not rel.startswith("..") and not rel.replace(os.sep, "/").startswith(UNUSED_QML_PREFIXES):
                modules.add(rel)
        for rel in sorted(modules):
            self.copy_qml_dir(rel, recursive=False)
        for rel in EXTRA_QML_TREES:
            self.copy_qml_dir(rel, recursive=True)
        # The Controls module itself (attached types such as ToolTip import it at run time).
        self.copy_qml_dir("QtQuick/Controls", recursive=False)
        print(f"    QML modules: {', '.join(sorted(modules))}")

    # --- finishing
    def fix_rpaths(self):
        """Every ELF file finds the Qt libraries through a RUNPATH relative to itself."""
        lib = os.path.join(self.dist, "lib")
        for f in self.elf_files:
            rel = os.path.relpath(lib, os.path.dirname(f))
            rpath = "$ORIGIN" if rel == "." else "$ORIGIN/" + rel
            run(["patchelf", "--set-rpath", rpath, f])

    def write_qt_conf(self):
        lines = ["[Paths]", "Prefix = .", "Plugins = plugins", "QmlImports = qml"]
        if not self.windows:
            lines.insert(2, "Libraries = lib")
        with open(os.path.join(self.dist, "qt.conf"), "w", newline="\r\n" if self.windows else "\n") as f:
            f.write("\n".join(lines) + "\n")

    def deploy(self):
        exe = os.path.join(self.dist, "ui-flow.exe" if self.windows else "ui-flow")
        if not os.path.isfile(exe):
            sys.exit(f"deploy.py: {exe} not found (run cmake --install first)")
        self.add_binary(exe)
        self.copy_plugins()
        self.copy_qml()
        self.resolve()
        if not self.windows:
            self.elf_files.remove(exe)  # keeps its CMake INSTALL_RPATH ($ORIGIN/lib)
            self.fix_rpaths()
        self.write_qt_conf()
        count = sum(len(files) for _, _, files in os.walk(self.dist))
        size = run(["du", "-sh", "--apparent-size", self.dist]).split()[0]
        print(f"    deployed {count} files ({size})")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--target", required=True, choices=sorted(QT_ENV))
    p.add_argument("--dist", required=True)
    p.add_argument("--qml", required=True)
    a = p.parse_args()
    Deployer(a.target, a.dist, a.qml).deploy()


if __name__ == "__main__":
    main()
