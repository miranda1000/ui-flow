// Browser integration of the WebAssembly build (target "web"); not compiled elsewhere.
//
// A web page has no file system to open or save through: files come in through the
// browser's file picker and go out as downloads. Picked files are written to Qt's
// in-memory file system for the duration of the callback, so the rest of the app reads
// them through the same code paths as on the desktop (drag and drop works the same way:
// Qt hands over dropped files as in-memory files).
#pragma once

#include <QByteArray>
#include <QList>
#include <QString>
#include <QUrl>

#include <functional>

namespace uiflow::web {

// Shows the browser's file picker. `done` gets file:// URLs of the chosen files, which
// stay readable until it returns; it is not called if the user cancels.
void pickFiles(const QString& accept, bool multiple, std::function<void(const QList<QUrl>&)> done);

// Hands `data` to the browser as a download named `fileName`.
void download(const QString& fileName, const QByteArray& data, const QString& mimeType);

// While on, leaving or reloading the page asks for confirmation first.
void setLeaveWarning(bool on);

} // namespace uiflow::web
