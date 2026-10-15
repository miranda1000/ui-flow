// Bridge between the document model (core/) and the QML UI: the `Doc` singleton.
//
// Change protocol used by the QML side:
//   * one-shot edits (rename, add, delete, ...) record their own undo step;
//   * continuous edits (dragging a screen, resizing a hotspot, a slider) call
//     beginChange() once when the gesture starts, then the "live" setters.
//
// The canvas binds to the `screens` / `links` list models, which emit fine-grained
// dataChanged() so delegates survive drags. Panels call the query functions and bind to
// `revision`, which changes on every structural edit.
#pragma once

#include "core/flow.h"
#include "core/model.h"

#include <QAbstractListModel>
#include <QHash>
#include <QMutex>
#include <QObject>
#include <QPointF>
#include <QQuickImageProvider>
#include <QRectF>
#include <QTimer>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

#include <deque>

class QQmlEngine;
class QJSEngine;

namespace uiflow {

// Serves "image://uiflow/<imageId>". Images never change once added (a replaced screen
// image gets a new id), so the cache never needs invalidating. Thread-safe: Image items
// with asynchronous: true request from a loader thread.
class ImageProvider : public QQuickImageProvider {
public:
    ImageProvider();
    void add(const ImageAsset& img);
    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;

private:
    QMutex mutex_;
    QHash<QString, QByteArray> data_;
};

// List model over an ordered list of ids. applyIds() turns a change of the list into
// insert/remove notifications when one row was added or removed (so the other delegates
// survive), and into a reset otherwise.
class IdListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ANONYMOUS
public:
    using QAbstractListModel::QAbstractListModel;
    int rowCount(const QModelIndex& parent = {}) const override { return parent.isValid() ? 0 : int(ids_.size()); }
    void resetTo(const QStringList& ids);

protected:
    void applyIds(const QStringList& next);
    QStringList ids_;
};

class ScreenModel : public IdListModel {
    Q_OBJECT
    QML_ANONYMOUS
public:
    enum Role {
        IdRole = Qt::UserRole + 1, NameRole, ImageUrlRole, PosXRole, PosYRole, WidthRole, HeightRole,
        ImageWidthRole, ImageHeightRole, IsStartRole, ReachableRole, HotspotsRole
    };
    explicit ScreenModel(QObject* parent = nullptr) : IdListModel(parent) {}
    void setSource(const Document* doc, const FlowAnalysis* fa) { doc_ = doc; fa_ = fa; }
    void sync();                                        // after structural changes
    void rowChanged(const QString& id, bool geometry);  // live move (or resize) of one screen

    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    const Document* doc_ = nullptr;
    const FlowAnalysis* fa_ = nullptr;
};

class LinkModel : public IdListModel {
    Q_OBJECT
    QML_ANONYMOUS
public:
    enum Role {
        IdRole = Qt::UserRole + 1, FromRole, ToRole, HotspotRole, IsHotspotLinkRole, MessageRole, LabelRole,
        P0Role, C0Role, C1Role, P1Role, MidRole, SelfLoopRole
    };
    explicit LinkModel(QObject* parent = nullptr) : IdListModel(parent) {}
    void setSource(const Document* doc) { doc_ = doc; }
    void sync();
    void geometryChanged(const QString& screenId);  // links touching that screen

    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    const Document* doc_ = nullptr;
};

class FlowController : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Doc)
    QML_SINGLETON

    Q_PROPERTY(bool hasDocument READ hasDocument NOTIFY documentChanged)
    Q_PROPERTY(QString appName READ appName NOTIFY revisionChanged)
    Q_PROPERTY(QString filePath READ filePath NOTIFY fileChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY fileChanged)
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)
    Q_PROPERTY(bool autosave READ autosave WRITE setAutosave NOTIFY settingsChanged)
    Q_PROPERTY(bool wheelZooms READ wheelZooms WRITE setWheelZooms NOTIFY settingsChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY undoChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(QString startScreen READ startScreen NOTIFY revisionChanged)
    Q_PROPERTY(int screenCount READ screenCount NOTIFY revisionChanged)
    Q_PROPERTY(int linkCount READ linkCount NOTIFY revisionChanged)
    Q_PROPERTY(QStringList recentFiles READ recentFiles NOTIFY recentChanged)
    Q_PROPERTY(QObject* screens READ screens CONSTANT)
    Q_PROPERTY(QObject* links READ links CONSTANT)
    Q_PROPERTY(QVariantMap startup READ startup CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)

public:
    // Not default-constructible on purpose: QML must use create() (the instance made in
    // main()) - for a default-constructible type it would build a second one.
    explicit FlowController(QObject* parent);
    static FlowController* instance();
    static FlowController* create(QQmlEngine*, QJSEngine*);

    // Must be handed to the QML engine (which takes ownership) before loading QML.
    ImageProvider* takeImageProvider();
    void setStartup(const QVariantMap& startup) { startup_ = startup; }

    bool hasDocument() const { return hasDocument_; }
    QString appName() const;
    QString filePath() const { return path_; }
    QString fileName() const;
    bool dirty() const { return dirty_; }
    bool autosave() const { return autosave_; }
    void setAutosave(bool on);
    bool wheelZooms() const { return wheelZooms_; }
    void setWheelZooms(bool on);
    bool canUndo() const { return !undo_.empty(); }
    bool canRedo() const { return !redo_.empty(); }
    int revision() const { return revision_; }
    QString startScreen() const;
    int screenCount() const { return int(doc_.screens.size()); }
    int linkCount() const { return int(doc_.links.size()); }
    QStringList recentFiles() const { return recent_; }
    QObject* screens() { return &screenModel_; }
    QObject* links() { return &linkModel_; }
    QVariantMap startup() const { return startup_; }
    QString version() const;

    // --- files ---
    Q_INVOKABLE bool newApp(const QString& name, const QString& path);
    Q_INVOKABLE bool openApp(const QString& path);
    Q_INVOKABLE bool save();                         // false + saveAsRequested() if never saved
    Q_INVOKABLE bool saveAs(const QString& path);
    Q_INVOKABLE bool exportMarkdown(const QString& path);
    Q_INVOKABLE void closeApp();
    Q_INVOKABLE QString localPath(const QUrl& url) const;
    Q_INVOKABLE QUrl fileUrl(const QString& path) const;
    Q_INVOKABLE QString suggestedFile(const QString& extension, const QString& baseName = QString()) const;
    Q_INVOKABLE void forgetRecent(const QString& path);

    // --- screens ---
    Q_INVOKABLE QString addImages(const QList<QUrl>& urls, qreal x, qreal y, bool atPosition);
    Q_INVOKABLE QString pasteImage(qreal x, qreal y, bool atPosition);
    Q_INVOKABLE bool canPasteImage() const;
    Q_INVOKABLE bool replaceImage(const QString& screenId, const QUrl& url);
    Q_INVOKABLE void beginChange();
    Q_INVOKABLE void moveScreen(const QString& id, qreal x, qreal y);              // live
    Q_INVOKABLE void setScreenScale(const QString& id, qreal scale);               // live
    Q_INVOKABLE void setScreenName(const QString& id, const QString& name);
    Q_INVOKABLE void setScreenNotes(const QString& id, const QString& notes);
    Q_INVOKABLE void setStartScreen(const QString& id);
    Q_INVOKABLE void setAppName(const QString& name);
    Q_INVOKABLE void deleteScreen(const QString& id);
    Q_INVOKABLE QString duplicateScreen(const QString& id);

    // --- hotspots (image pixel coordinates) ---
    Q_INVOKABLE QString addHotspot(const QString& screenId, qreal x, qreal y, qreal w, qreal h);
    Q_INVOKABLE void setHotspotRect(const QString& screenId, const QString& id, qreal x, qreal y, qreal w,
                                    qreal h);  // live
    Q_INVOKABLE void setHotspotName(const QString& screenId, const QString& id, const QString& name);
    Q_INVOKABLE void deleteHotspot(const QString& screenId, const QString& id);

    // --- links ---
    Q_INVOKABLE QString addLink(const QString& from, const QString& hotspot, const QString& to,
                                const QString& message);
    Q_INVOKABLE void setLinkMessage(const QString& id, const QString& message);
    Q_INVOKABLE void setLinkTarget(const QString& id, const QString& to);
    Q_INVOKABLE void deleteLink(const QString& id);

    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    // --- queries (bind to `revision` to stay current) ---
    Q_INVOKABLE bool hasScreen(const QString& id) const;
    Q_INVOKABLE bool hasLink(const QString& id) const;
    Q_INVOKABLE QVariantMap screen(const QString& id) const;
    Q_INVOKABLE QVariantList hotspots(const QString& screenId) const;
    Q_INVOKABLE QVariantMap hotspot(const QString& screenId, const QString& id) const;
    Q_INVOKABLE QVariantList linksFrom(const QString& screenId, bool screenLevelOnly = false) const;
    Q_INVOKABLE QVariantList linksTo(const QString& screenId) const;
    Q_INVOKABLE QVariantMap link(const QString& id) const;
    Q_INVOKABLE QVariantList screenList() const;
    Q_INVOKABLE QVariantList overview() const;
    Q_INVOKABLE QVariantMap stats() const;
    Q_INVOKABLE QString pathTo(const QString& screenId) const;
    Q_INVOKABLE QString screenAt(qreal x, qreal y) const;
    Q_INVOKABLE QString linkAt(qreal x, qreal y, qreal tolerance) const;
    Q_INVOKABLE QString hotspotAt(const QString& screenId, qreal x, qreal y) const;  // image px
    Q_INVOKABLE QRectF bounds() const;
    Q_INVOKABLE QPointF nextFreeSpot() const;

signals:
    void documentChanged();
    void revisionChanged();
    void fileChanged();
    void dirtyChanged();
    void undoChanged();
    void recentChanged();
    void settingsChanged();
    void errorOccurred(const QString& message);
    void toast(const QString& message);
    void saveAsRequested();
    void screenAdded(const QString& id);

private:
    void resetDocument(Document doc, const QString& path, bool dirty);
    void commit();          // after a structural edit: analysis, models, revision, dirty
    void markDirty();
    void setDirty(bool d);
    bool writeTo(const QString& path);
    void addRecent(const QString& path);
    void registerImages();
    QString addScreenFromBytes(std::vector<std::uint8_t> bytes, const QString& fileName, QPointF pos,
                               bool atPosition);
    QVariantMap linkToVariant(const Link& l) const;

    Document doc_;
    FlowAnalysis analysis_;
    QString path_;
    bool hasDocument_ = false;
    bool dirty_ = false;
    bool autosave_ = true;
    bool wheelZooms_ = true;
    int revision_ = 0;
    std::deque<Document> undo_, redo_;
    QStringList recent_;
    QVariantMap startup_;
    QTimer autosaveTimer_;
    ScreenModel screenModel_;
    LinkModel linkModel_;
    ImageProvider* provider_ = nullptr;
    bool providerTaken_ = false;
};

} // namespace uiflow
