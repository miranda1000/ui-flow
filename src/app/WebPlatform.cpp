#include "WebPlatform.h"

#include <QDir>
#include <QFile>

#include <emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/val.h>

#include <map>

namespace uiflow::web {

namespace {

std::map<int, std::function<void(const QList<QUrl>&)>> s_pending;
int s_nextRequest = 1;

// Called from JavaScript once the picked files are read (or with none on cancel).
// files: [{ name: string, bytes: Uint8Array }]
void filesPicked(int request, emscripten::val files)
{
    auto it = s_pending.find(request);
    if (it == s_pending.end())
        return;
    auto done = std::move(it->second);
    s_pending.erase(it);

    const int count = files["length"].as<int>();
    if (count == 0)
        return;
    QDir dir(QStringLiteral("/tmp/uiflow-picked/%1").arg(request));
    dir.mkpath(QStringLiteral("."));
    QList<QUrl> urls;
    for (int i = 0; i < count; ++i) {
        emscripten::val file = files[i];
        emscripten::val bytes = file["bytes"];
        QByteArray data(bytes["length"].as<int>(), Qt::Uninitialized);
        emscripten::val(emscripten::typed_memory_view(size_t(data.size()), reinterpret_cast<std::uint8_t*>(data.data())))
            .call<void>("set", bytes);
        QString name = QString::fromStdString(file["name"].as<std::string>());
        name.replace(QLatin1Char('/'), QLatin1Char('_'));
        QFile out(dir.filePath(name));
        if (out.open(QIODevice::WriteOnly) && out.write(data) == data.size())
            urls.append(QUrl::fromLocalFile(out.fileName()));
    }
    done(urls);
    dir.removeRecursively();
}

} // namespace

EM_JS_DEPS(uiflow_web, "$UTF8ToString");

EM_JS(void, uiflow_pick_files, (int request, const char* accept, bool multiple), {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = UTF8ToString(accept);
    input.multiple = multiple;
    input.addEventListener('change', async () => {
        const files = await Promise.all(Array.from(input.files, async (f) => (
            { name: f.name, bytes: new Uint8Array(await f.arrayBuffer()) })));
        Module.uiflowFilesPicked(request, files);
    });
    input.addEventListener('cancel', () => Module.uiflowFilesPicked(request, []));
    input.click();
});

EM_JS(void, uiflow_download, (const char* name, const char* mime, const char* data, size_t size), {
    const blob = new Blob([HEAPU8.slice(data, data + size)], { type: UTF8ToString(mime) });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = UTF8ToString(name);
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 60000);
});

EM_JS(void, uiflow_set_leave_warning, (bool on), {
    window.onbeforeunload = on ? (e) => { e.preventDefault(); e.returnValue = true; } : null;
});

EMSCRIPTEN_BINDINGS(uiflow_web)
{
    emscripten::function("uiflowFilesPicked", &filesPicked);
}

void pickFiles(const QString& accept, bool multiple, std::function<void(const QList<QUrl>&)> done)
{
    const int request = s_nextRequest++;
    s_pending[request] = std::move(done);
    uiflow_pick_files(request, accept.toUtf8().constData(), multiple);
}

void download(const QString& fileName, const QByteArray& data, const QString& mimeType)
{
    uiflow_download(fileName.toUtf8().constData(), mimeType.toUtf8().constData(), data.constData(), size_t(data.size()));
}

void setLeaveWarning(bool on) { uiflow_set_leave_warning(on); }

} // namespace uiflow::web
