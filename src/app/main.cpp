#include "FlowController.h"

#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

#ifndef UIFLOW_VERSION
#define UIFLOW_VERSION "dev"
#endif

namespace {

void loadFonts()
{
    bool ok = false;
    for (const char* f : {":/fonts/Inter-Regular.ttf", ":/fonts/Inter-Medium.ttf", ":/fonts/Inter-SemiBold.ttf"})
        ok |= QFontDatabase::addApplicationFont(QString::fromLatin1(f)) >= 0;
    QFont font = ok ? QFont(QStringLiteral("Inter")) : QGuiApplication::font();
    font.setPixelSize(12);
    font.setHintingPreference(QFont::PreferVerticalHinting);
    QGuiApplication::setFont(font);
}

} // namespace

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName(QStringLiteral("ui-flow"));
    QGuiApplication::setApplicationName(QStringLiteral("ui-flow"));
    QGuiApplication::setApplicationVersion(QStringLiteral(UIFLOW_VERSION));
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/qt/qml/UiFlow/icons/app.svg")));
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    loadFonts();

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Local, single-file UI flow designer."));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("file"), QStringLiteral("App file (.json) to open."), QStringLiteral("[file]"));
    QCommandLineOption playOpt(QStringLiteral("play"), QStringLiteral("Start in the player."));
    QCommandLineOption editOpt(QStringLiteral("edit"), QStringLiteral("Open <screen-id> in the screen editor."),
                               QStringLiteral("screen-id"));
    QCommandLineOption shotOpt(QStringLiteral("screenshot"),
                               QStringLiteral("Save a screenshot of the window to <png> and quit."), QStringLiteral("png"));
    QCommandLineOption delayOpt(QStringLiteral("screenshot-delay"),
                                QStringLiteral("Milliseconds before --screenshot is taken (default 2500)."), QStringLiteral("ms"),
                                QStringLiteral("2500"));
    QCommandLineOption sizeOpt(QStringLiteral("size"), QStringLiteral("Window size, e.g. 1440x900."), QStringLiteral("WxH"));
    QCommandLineOption selectOpt(QStringLiteral("select"), QStringLiteral("Select <id> (screen or link) on start."),
                                 QStringLiteral("id"));
    parser.addOptions({playOpt, editOpt, shotOpt, delayOpt, sizeOpt, selectOpt});
    parser.process(app);

    auto* flow = new uiflow::FlowController(&app);
    const QStringList args = parser.positionalArguments();
    if (!args.isEmpty())
        flow->openApp(QFileInfo(args.first()).absoluteFilePath());

    QVariantMap startup;
    startup["mode"] = parser.isSet(playOpt) ? QStringLiteral("play") : parser.isSet(editOpt) ? QStringLiteral("edit") : QString();
    startup["screen"] = parser.value(editOpt);
    startup["select"] = parser.value(selectOpt);
    const QStringList size = parser.value(sizeOpt).split(QLatin1Char('x'));
    if (size.size() == 2) {
        startup["width"] = size[0].toInt();
        startup["height"] = size[1].toInt();
    }
    flow->setStartup(startup);

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("uiflow"), flow->takeImageProvider());
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("UiFlow", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
#ifdef Q_OS_WASM
    // The window fills the page's container element, without a window frame.
    if (auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().value(0)))
        window->showFullScreen();
#endif

    if (parser.isSet(shotOpt)) {
        const QString out = QFileInfo(parser.value(shotOpt)).absoluteFilePath();
        QTimer::singleShot(parser.value(delayOpt).toInt(), &app, [&engine, out] {
            if (auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().value(0))) {
                if (!window->grabWindow().save(out))
                    qWarning("Cannot write %s", qPrintable(out));
            }
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
