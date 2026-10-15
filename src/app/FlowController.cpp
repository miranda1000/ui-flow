#include "FlowController.h"

#include "core/geometry.h"
#include "core/image.h"
#include "core/io.h"

#include <QBuffer>
#include <QClipboard>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJSEngine>
#include <QMimeData>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>
#include <cmath>

#ifndef UIFLOW_VERSION
#define UIFLOW_VERSION "dev"
#endif

namespace uiflow {

namespace {

constexpr size_t kUndoLimit = 200;
constexpr float kMaxScreenSide = 720.0f;   // canvas size of a new screen's longest side
constexpr float kScreenGap = 120.0f;

FlowController* s_instance = nullptr;

QString qs(const std::string& s) { return QString::fromStdString(s); }
std::string ss(const QString& s) { return s.toStdString(); }

QString imageUrl(const std::string& imageId) { return QStringLiteral("image://uiflow/") + qs(imageId); }

QString displayName(const Screen& s) { return qs(s.name.empty() ? s.id : s.name); }

QString screenName(const Document& doc, const std::string& id)
{
    const Screen* s = doc.findScreen(id);
    return s ? displayName(*s) : QStringLiteral("?");
}

QPointF pt(Point p) { return {p.x, p.y}; }

QVariantList hotspotList(const Document& doc, const Screen& s, bool canvasUnits)
{
    QVariantList out;
    const float k = canvasUnits ? s.scale : 1.0f;
    for (const auto& h : s.hotspots) {
        QVariantMap m;
        m["id"] = qs(h.id);
        m["name"] = qs(h.name);
        m["x"] = h.rect.x * k;
        m["y"] = h.rect.y * k;
        m["w"] = h.rect.w * k;
        m["h"] = h.rect.h * k;
        m["linked"] = !doc.linksFromHotspot(s.id, h.id).empty();
        out.push_back(m);
    }
    return out;
}

} // namespace

// ------------------------------------------------------------------ ImageProvider

ImageProvider::ImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

void ImageProvider::add(const ImageAsset& img)
{
    QMutexLocker lock(&mutex_);
    QString id = qs(img.id);
    if (!data_.contains(id))
        data_.insert(id, QByteArray(reinterpret_cast<const char*>(img.bytes.data()), qsizetype(img.bytes.size())));
}

QImage ImageProvider::requestImage(const QString& id, QSize* size, const QSize& requested)
{
    QByteArray bytes;
    {
        QMutexLocker lock(&mutex_);
        bytes = data_.value(id);
    }
    QImage img;
    if (!img.loadFromData(bytes)) {
        // Formats Qt has no plugin for (TGA, PSD...): the core decoder accepted them on import.
        DecodedImage dec;
        std::vector<std::uint8_t> raw(bytes.begin(), bytes.end());
        if (decodeImage(raw, dec))
            img = QImage(dec.rgba.data(), dec.width, dec.height, dec.width * 4, QImage::Format_RGBA8888).copy();
    }
    if (img.isNull()) {
        img = QImage(360, 640, QImage::Format_RGB32);
        img.fill(QColor(0xE6, 0xE6, 0xE6));
    }
    if (size)
        *size = img.size();
    const int rw = requested.width(), rh = requested.height();
    if (rw > 0 && rh > 0 && (rw < img.width() || rh < img.height()))
        img = img.scaled(requested, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    else if (rw > 0 && rh <= 0 && rw < img.width())
        img = img.scaledToWidth(rw, Qt::SmoothTransformation);
    else if (rh > 0 && rw <= 0 && rh < img.height())
        img = img.scaledToHeight(rh, Qt::SmoothTransformation);
    return img;
}

// ------------------------------------------------------------------ IdListModel

void IdListModel::resetTo(const QStringList& ids)
{
    beginResetModel();
    ids_ = ids;
    endResetModel();
}

void IdListModel::applyIds(const QStringList& next)
{
    if (next == ids_)
        return;
    const int n = int(ids_.size());
    if (next.size() == n + 1 && next.mid(0, n) == ids_) {
        beginInsertRows({}, n, n);
        ids_ = next;
        endInsertRows();
        return;
    }
    if (next.size() + 1 == n) {
        for (int i = 0; i < n; ++i) {
            QStringList candidate = ids_;
            candidate.removeAt(i);
            if (candidate == next) {
                beginRemoveRows({}, i, i);
                ids_ = next;
                endRemoveRows();
                return;
            }
        }
    }
    resetTo(next);
}

// ------------------------------------------------------------------ ScreenModel

QHash<int, QByteArray> ScreenModel::roleNames() const
{
    return {{IdRole, "screenId"},       {NameRole, "name"},          {ImageUrlRole, "imageUrl"},
            {PosXRole, "posX"},         {PosYRole, "posY"},          {WidthRole, "screenWidth"},
            {HeightRole, "screenHeight"}, {ImageWidthRole, "imageWidth"}, {ImageHeightRole, "imageHeight"},
            {IsStartRole, "isStart"},   {ReachableRole, "reachable"}, {HotspotsRole, "hotspots"}};
}

QVariant ScreenModel::data(const QModelIndex& index, int role) const
{
    if (!doc_ || !index.isValid() || index.row() >= ids_.size())
        return {};
    const Screen* s = doc_->findScreen(ss(ids_[index.row()]));
    if (!s)
        return {};
    const ImageAsset* img = doc_->image(s->imageId);
    switch (role) {
    case IdRole: return qs(s->id);
    case NameRole: return displayName(*s);
    case ImageUrlRole: return imageUrl(s->imageId);
    case PosXRole: return s->x;
    case PosYRole: return s->y;
    case WidthRole: return doc_->screenRect(*s).w;
    case HeightRole: return doc_->screenRect(*s).h;
    case ImageWidthRole: return img ? img->width : 0;
    case ImageHeightRole: return img ? img->height : 0;
    case IsStartRole: return doc_->startScreenId() == s->id;
    case ReachableRole: return fa_ && fa_->pathTo.count(s->id) > 0;
    case HotspotsRole: return hotspotList(*doc_, *s, true);
    default: return {};
    }
}

void ScreenModel::sync()
{
    QStringList next;
    for (const auto& s : doc_->screens)
        next << qs(s.id);
    applyIds(next);
    if (!ids_.isEmpty())
        emit dataChanged(index(0), index(int(ids_.size()) - 1));
}

void ScreenModel::rowChanged(const QString& id, bool geometry)
{
    int row = int(ids_.indexOf(id));
    if (row < 0)
        return;
    if (geometry)
        emit dataChanged(index(row), index(row), {PosXRole, PosYRole, WidthRole, HeightRole, HotspotsRole});
    else
        emit dataChanged(index(row), index(row), {PosXRole, PosYRole});
}

// ------------------------------------------------------------------ LinkModel

QHash<int, QByteArray> LinkModel::roleNames() const
{
    return {{IdRole, "linkId"},      {FromRole, "fromId"},      {ToRole, "toId"},
            {HotspotRole, "hotspotId"}, {IsHotspotLinkRole, "isHotspotLink"}, {MessageRole, "message"},
            {LabelRole, "label"},    {P0Role, "p0"},            {C0Role, "c0"},
            {C1Role, "c1"},          {P1Role, "p1"},            {MidRole, "mid"},
            {SelfLoopRole, "selfLoop"}};
}

QVariant LinkModel::data(const QModelIndex& index, int role) const
{
    if (!doc_ || !index.isValid() || index.row() >= ids_.size())
        return {};
    const Link* l = doc_->findLink(ss(ids_[index.row()]));
    if (!l)
        return {};
    switch (role) {
    case IdRole: return qs(l->id);
    case FromRole: return qs(l->from);
    case ToRole: return qs(l->to);
    case HotspotRole: return qs(l->hotspot);
    case IsHotspotLinkRole: return !l->hotspot.empty();
    case MessageRole: return qs(l->message);
    case LabelRole: return qs(linkAction(*doc_, *l));
    case SelfLoopRole: return l->from == l->to;
    default: break;
    }
    const Curve c = linkCurve(*doc_, *l);
    switch (role) {
    case P0Role: return pt(c.p0);
    case C0Role: return pt(c.c0);
    case C1Role: return pt(c.c1);
    case P1Role: return pt(c.p1);
    case MidRole: return pt(c.at(0.5f));
    default: return {};
    }
}

void LinkModel::sync()
{
    QStringList next;
    for (const auto& l : doc_->links)
        next << qs(l.id);
    applyIds(next);
    if (!ids_.isEmpty())
        emit dataChanged(index(0), index(int(ids_.size()) - 1));
}

void LinkModel::geometryChanged(const QString& screenId)
{
    const std::string id = ss(screenId);
    for (int row = 0; row < ids_.size(); ++row) {
        const Link* l = doc_->findLink(ss(ids_[row]));
        if (l && (l->from == id || l->to == id))
            emit dataChanged(index(row), index(row), {P0Role, C0Role, C1Role, P1Role, MidRole});
    }
}

// ------------------------------------------------------------------ FlowController

FlowController::FlowController(QObject* parent) : QObject(parent), provider_(new ImageProvider)
{
    s_instance = this;
    screenModel_.setSource(&doc_, &analysis_);
    linkModel_.setSource(&doc_);

    QSettings settings;
    recent_ = settings.value("recentFiles").toStringList();
    autosave_ = settings.value("autosave", true).toBool();
    wheelZooms_ = settings.value("wheelZooms", true).toBool();

    autosaveTimer_.setSingleShot(true);
    autosaveTimer_.setInterval(900);
    connect(&autosaveTimer_, &QTimer::timeout, this, [this] {
        if (autosave_ && dirty_ && !path_.isEmpty())
            writeTo(path_);
    });
}

FlowController* FlowController::instance() { return s_instance; }

FlowController* FlowController::create(QQmlEngine*, QJSEngine*)
{
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

ImageProvider* FlowController::takeImageProvider()
{
    providerTaken_ = true;
    return provider_;
}

QString FlowController::appName() const { return qs(doc_.name); }

QString FlowController::fileName() const { return path_.isEmpty() ? QString() : QFileInfo(path_).fileName(); }

QString FlowController::startScreen() const { return qs(doc_.startScreenId()); }

QString FlowController::version() const { return QStringLiteral(UIFLOW_VERSION); }

void FlowController::setAutosave(bool on)
{
    if (autosave_ == on)
        return;
    autosave_ = on;
    QSettings().setValue("autosave", on);
    emit settingsChanged();
    if (on && dirty_ && !path_.isEmpty())
        autosaveTimer_.start();
}

void FlowController::setWheelZooms(bool on)
{
    if (wheelZooms_ == on)
        return;
    wheelZooms_ = on;
    QSettings().setValue("wheelZooms", on);
    emit settingsChanged();
}

// --- document lifecycle

void FlowController::resetDocument(Document doc, const QString& path, bool dirty)
{
    doc_ = std::move(doc);
    path_ = path;
    hasDocument_ = true;
    undo_.clear();
    redo_.clear();
    registerImages();
    analysis_ = analyzeFlow(doc_);
    screenModel_.resetTo({});
    linkModel_.resetTo({});
    screenModel_.sync();
    linkModel_.sync();
    ++revision_;
    emit documentChanged();
    emit fileChanged();
    emit revisionChanged();
    emit undoChanged();
    setDirty(dirty);
}

void FlowController::registerImages()
{
    for (const auto& [id, img] : doc_.images)
        provider_->add(*img);
}

void FlowController::commit()
{
    analysis_ = analyzeFlow(doc_);
    screenModel_.sync();
    linkModel_.sync();
    ++revision_;
    emit revisionChanged();
    emit undoChanged();
    markDirty();
}

void FlowController::markDirty()
{
    setDirty(true);
    if (autosave_ && !path_.isEmpty())
        autosaveTimer_.start();
}

void FlowController::setDirty(bool d)
{
    if (dirty_ == d)
        return;
    dirty_ = d;
    emit dirtyChanged();
}

bool FlowController::writeTo(const QString& path)
{
    std::string err;
    if (!writeFileAtomic(ss(path), toJson(doc_), &err)) {
        emit errorOccurred(qs(err));
        return false;
    }
    if (path_ != path) {
        path_ = path;
        emit fileChanged();
    }
    setDirty(false);
    addRecent(path);
    return true;
}

void FlowController::addRecent(const QString& path)
{
    if (!recent_.isEmpty() && recent_.front() == path)
        return;
    recent_.removeAll(path);
    recent_.prepend(path);
    while (recent_.size() > 10)
        recent_.removeLast();
    QSettings().setValue("recentFiles", recent_);
    emit recentChanged();
}

void FlowController::forgetRecent(const QString& path)
{
    if (recent_.removeAll(path) > 0) {
        QSettings().setValue("recentFiles", recent_);
        emit recentChanged();
    }
}

bool FlowController::newApp(const QString& name, const QString& path)
{
    Document doc;
    doc.name = ss(name.trimmed().isEmpty() ? QStringLiteral("Untitled") : name.trimmed());
    resetDocument(std::move(doc), QString(), true);
    if (!path.isEmpty())
        return writeTo(path);
    return true;
}

bool FlowController::openApp(const QString& path)
{
    std::string text, err;
    if (!readTextFile(ss(path), text, &err)) {
        emit errorOccurred(qs(err));
        forgetRecent(path);
        return false;
    }
    try {
        Document doc = fromJson(text);
        resetDocument(std::move(doc), path, false);
    } catch (const std::exception& e) {
        emit errorOccurred(tr("Cannot open %1:\n%2").arg(QFileInfo(path).fileName(), QString::fromUtf8(e.what())));
        return false;
    }
    addRecent(path);
    return true;
}

bool FlowController::save()
{
    if (path_.isEmpty()) {
        emit saveAsRequested();
        return false;
    }
    autosaveTimer_.stop();
    if (!writeTo(path_))
        return false;
    emit toast(tr("Saved"));
    return true;
}

bool FlowController::saveAs(const QString& path)
{
    QString p = path;
    if (QFileInfo(p).suffix().isEmpty())
        p += QStringLiteral(".json");
    if (!writeTo(p))
        return false;
    emit toast(tr("Saved as %1").arg(QFileInfo(p).fileName()));
    return true;
}

bool FlowController::exportMarkdown(const QString& path)
{
    QString p = path;
    if (QFileInfo(p).suffix().isEmpty())
        p += QStringLiteral(".md");
    std::string err;
    if (!writeFileAtomic(ss(p), uiflow::exportMarkdown(doc_), &err)) {
        emit errorOccurred(qs(err));
        return false;
    }
    emit toast(tr("Exported %1").arg(QFileInfo(p).fileName()));
    return true;
}

void FlowController::closeApp()
{
    autosaveTimer_.stop();
    doc_ = Document();
    path_.clear();
    hasDocument_ = false;
    undo_.clear();
    redo_.clear();
    analysis_ = {};
    screenModel_.resetTo({});
    linkModel_.resetTo({});
    ++revision_;
    setDirty(false);
    emit documentChanged();
    emit fileChanged();
    emit revisionChanged();
    emit undoChanged();
}

QString FlowController::localPath(const QUrl& url) const
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

QUrl FlowController::fileUrl(const QString& path) const { return QUrl::fromLocalFile(path); }

QString FlowController::suggestedFile(const QString& extension, const QString& baseName) const
{
    QString dir = path_.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
                                  : QFileInfo(path_).absolutePath();
    QString base = !baseName.isEmpty() ? baseName
                   : path_.isEmpty()   ? qs(doc_.name)
                                       : QFileInfo(path_).completeBaseName();
    base.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|]")), QStringLiteral("_"));
    if (base.isEmpty())
        base = QStringLiteral("app");
    return QUrl::fromLocalFile(QDir(dir).filePath(base + QLatin1Char('.') + extension)).toString();
}

// --- screens

QPointF FlowController::nextFreeSpot() const
{
    if (doc_.screens.empty())
        return {0, 0};
    const Screen* right = &doc_.screens.front();
    float maxX = -1e30f;
    for (const auto& s : doc_.screens) {
        Rect r = doc_.screenRect(s);
        if (r.x + r.w > maxX) {
            maxX = r.x + r.w;
            right = &s;
        }
    }
    return {maxX + kScreenGap, right->y};
}

QString FlowController::addScreenFromBytes(std::vector<std::uint8_t> bytes, const QString& fileName, QPointF pos,
                                           bool atPosition)
{
    if (!hasDocument_)
        newApp(tr("Untitled"), QString());

    ImagePtr img;
    std::string err;
    if (!makeImageAsset("img-" + std::to_string(doc_.nextId), ss(fileName), std::move(bytes), img, &err)) {
        emit errorOccurred(qs(err));
        return {};
    }
    beginChange();
    doc_.nextId++;
    Screen s;
    s.id = doc_.newId("screen");
    s.name = stemOf(ss(fileName));
    s.imageId = img->id;
    s.scale = std::min(1.0f, kMaxScreenSide / float(std::max(img->width, img->height)));
    QPointF p = atPosition ? pos : nextFreeSpot();
    s.x = float(std::round(p.x()));
    s.y = float(std::round(p.y()));
    provider_->add(*img);
    doc_.images[img->id] = img;
    doc_.screens.push_back(s);
    if (doc_.startScreen.empty())
        doc_.startScreen = s.id;
    commit();
    emit screenAdded(qs(s.id));
    return qs(s.id);
}

QString FlowController::addImages(const QList<QUrl>& urls, qreal x, qreal y, bool atPosition)
{
    QString last;
    qreal offset = 0;
    for (const QUrl& url : urls) {
        const QString path = localPath(url);
        if (QFileInfo(path).suffix().compare(QLatin1String("json"), Qt::CaseInsensitive) == 0) {
            openApp(path);
            return {};
        }
        std::vector<std::uint8_t> bytes;
        std::string err;
        if (!readFile(ss(path), bytes, &err)) {
            emit errorOccurred(qs(err));
            continue;
        }
        QString id = addScreenFromBytes(std::move(bytes), QFileInfo(path).fileName(), {x + offset, y}, atPosition);
        if (id.isEmpty())
            continue;
        last = id;
        if (const Screen* s = doc_.findScreen(ss(id)))
            offset += doc_.screenRect(*s).w + 60;
    }
    return last;
}

bool FlowController::canPasteImage() const
{
    const QMimeData* md = QGuiApplication::clipboard()->mimeData();
    return md && (md->hasImage() || md->hasUrls());
}

QString FlowController::pasteImage(qreal x, qreal y, bool atPosition)
{
    const QMimeData* md = QGuiApplication::clipboard()->mimeData();
    if (md && md->hasUrls()) {
        QString id = addImages(md->urls(), x, y, atPosition);
        if (!id.isEmpty())
            return id;
    }
    QImage image = QGuiApplication::clipboard()->image();
    if (image.isNull()) {
        emit toast(tr("The clipboard does not contain an image"));
        return {};
    }
    QByteArray png;
    QBuffer buf(&png);
    buf.open(QIODevice::WriteOnly);
    image.save(&buf, "PNG");
    std::vector<std::uint8_t> bytes(png.begin(), png.end());
    return addScreenFromBytes(std::move(bytes), tr("Pasted screen") + QStringLiteral(".png"), {x, y}, atPosition);
}

bool FlowController::replaceImage(const QString& screenId, const QUrl& url)
{
    if (!doc_.findScreen(ss(screenId)))
        return false;
    const QString path = localPath(url);
    std::vector<std::uint8_t> bytes;
    std::string err;
    if (!readFile(ss(path), bytes, &err)) {
        emit errorOccurred(qs(err));
        return false;
    }
    ImagePtr img;
    if (!makeImageAsset("img-" + std::to_string(doc_.nextId), ss(QFileInfo(path).fileName()), std::move(bytes), img,
                        &err)) {
        emit errorOccurred(qs(err));
        return false;
    }
    beginChange();
    doc_.nextId++;
    Screen* s = doc_.findScreen(ss(screenId));
    const ImageAsset* old = doc_.image(s->imageId);
    if (old && old->width > 0 && old->height > 0) {
        // Hotspots keep their relative place; the screen keeps its width on the canvas.
        float fx = float(img->width) / float(old->width), fy = float(img->height) / float(old->height);
        for (auto& h : s->hotspots)
            h.rect = {h.rect.x * fx, h.rect.y * fy, h.rect.w * fx, h.rect.h * fy};
        s->scale /= fx;
    }
    s->imageId = img->id;
    provider_->add(*img);
    doc_.images[img->id] = img;
    doc_.pruneImages();
    commit();
    emit toast(tr("Image replaced"));
    return true;
}

void FlowController::beginChange()
{
    undo_.push_back(doc_);
    if (undo_.size() > kUndoLimit)
        undo_.pop_front();
    redo_.clear();
    emit undoChanged();
}

void FlowController::moveScreen(const QString& id, qreal x, qreal y)
{
    Screen* s = doc_.findScreen(ss(id));
    if (!s)
        return;
    s->x = float(x);
    s->y = float(y);
    screenModel_.rowChanged(id, false);
    linkModel_.geometryChanged(id);
    markDirty();
}

void FlowController::setScreenScale(const QString& id, qreal scale)
{
    Screen* s = doc_.findScreen(ss(id));
    if (!s)
        return;
    s->scale = std::clamp(float(scale), 0.02f, 8.0f);
    screenModel_.rowChanged(id, true);
    linkModel_.geometryChanged(id);
    markDirty();
}

void FlowController::setScreenName(const QString& id, const QString& name)
{
    const Screen* s = doc_.findScreen(ss(id));
    if (!s || qs(s->name) == name)
        return;
    beginChange();
    doc_.findScreen(ss(id))->name = ss(name);
    commit();
}

void FlowController::setScreenNotes(const QString& id, const QString& notes)
{
    const Screen* s = doc_.findScreen(ss(id));
    if (!s || qs(s->notes) == notes)
        return;
    beginChange();
    doc_.findScreen(ss(id))->notes = ss(notes);
    commit();
}

void FlowController::setStartScreen(const QString& id)
{
    if (!doc_.findScreen(ss(id)) || doc_.startScreenId() == ss(id))
        return;
    beginChange();
    doc_.startScreen = ss(id);
    commit();
}

void FlowController::setAppName(const QString& name)
{
    QString n = name.trimmed();
    if (n.isEmpty() || qs(doc_.name) == n)
        return;
    beginChange();
    doc_.name = ss(n);
    commit();
}

void FlowController::deleteScreen(const QString& id)
{
    if (!doc_.findScreen(ss(id)))
        return;
    beginChange();
    doc_.removeScreen(ss(id));
    commit();
}

QString FlowController::duplicateScreen(const QString& id)
{
    const Screen* src = doc_.findScreen(ss(id));
    if (!src)
        return {};
    beginChange();
    Screen copy = *src;
    copy.id = doc_.newId("screen");
    copy.name += " copy";
    copy.x += 40;
    copy.y += 40;
    for (auto& h : copy.hotspots)
        h.id = doc_.newId("hotspot");
    doc_.screens.push_back(copy);
    commit();
    emit screenAdded(qs(copy.id));
    return qs(copy.id);
}

// --- hotspots

static Rect clampToImage(const Document& doc, const Screen& s, qreal x, qreal y, qreal w, qreal h)
{
    if (w < 0) {
        x += w;
        w = -w;
    }
    if (h < 0) {
        y += h;
        h = -h;
    }
    Rect r{float(std::round(x)), float(std::round(y)), float(std::round(w)), float(std::round(h))};
    if (const ImageAsset* img = doc.image(s.imageId)) {
        r.w = std::clamp(r.w, 1.0f, float(img->width));
        r.h = std::clamp(r.h, 1.0f, float(img->height));
        r.x = std::clamp(r.x, 0.0f, float(img->width) - r.w);
        r.y = std::clamp(r.y, 0.0f, float(img->height) - r.h);
    }
    return r;
}

QString FlowController::addHotspot(const QString& screenId, qreal x, qreal y, qreal w, qreal h)
{
    Screen* s = doc_.findScreen(ss(screenId));
    if (!s)
        return {};
    beginChange();
    s = doc_.findScreen(ss(screenId));
    Hotspot hs;
    hs.id = doc_.newId("hotspot");
    hs.name = ss(tr("Hotspot %1").arg(s->hotspots.size() + 1));
    hs.rect = clampToImage(doc_, *s, x, y, w, h);
    s->hotspots.push_back(hs);
    commit();
    return qs(hs.id);
}

void FlowController::setHotspotRect(const QString& screenId, const QString& id, qreal x, qreal y, qreal w, qreal h)
{
    Screen* s = doc_.findScreen(ss(screenId));
    Hotspot* hs = s ? findHotspot(*s, ss(id)) : nullptr;
    if (!hs)
        return;
    hs->rect = clampToImage(doc_, *s, x, y, w, h);
    screenModel_.rowChanged(screenId, true);
    linkModel_.geometryChanged(screenId);
    ++revision_;
    emit revisionChanged();
    markDirty();
}

void FlowController::setHotspotName(const QString& screenId, const QString& id, const QString& name)
{
    Screen* s = doc_.findScreen(ss(screenId));
    Hotspot* hs = s ? findHotspot(*s, ss(id)) : nullptr;
    if (!hs || qs(hs->name) == name)
        return;
    beginChange();
    findHotspot(*doc_.findScreen(ss(screenId)), ss(id))->name = ss(name);
    commit();
}

void FlowController::deleteHotspot(const QString& screenId, const QString& id)
{
    Screen* s = doc_.findScreen(ss(screenId));
    if (!s || !findHotspot(*s, ss(id)))
        return;
    beginChange();
    doc_.removeHotspot(*doc_.findScreen(ss(screenId)), ss(id));
    commit();
}

// --- links

QString FlowController::addLink(const QString& from, const QString& hotspot, const QString& to,
                                const QString& message)
{
    const Screen* src = doc_.findScreen(ss(from));
    if (!src || !doc_.findScreen(ss(to)))
        return {};
    if (!hotspot.isEmpty() && !findHotspot(*src, ss(hotspot)))
        return {};
    beginChange();
    Link l;
    l.id = doc_.newId("link");
    l.from = ss(from);
    l.hotspot = ss(hotspot);
    l.to = ss(to);
    l.message = ss(message.trimmed());
    doc_.links.push_back(l);
    commit();
    return qs(l.id);
}

void FlowController::setLinkMessage(const QString& id, const QString& message)
{
    const Link* l = doc_.findLink(ss(id));
    if (!l || qs(l->message) == message)
        return;
    beginChange();
    doc_.findLink(ss(id))->message = ss(message);
    commit();
}

void FlowController::setLinkTarget(const QString& id, const QString& to)
{
    const Link* l = doc_.findLink(ss(id));
    if (!l || qs(l->to) == to || !doc_.findScreen(ss(to)))
        return;
    beginChange();
    doc_.findLink(ss(id))->to = ss(to);
    commit();
}

void FlowController::deleteLink(const QString& id)
{
    if (!doc_.findLink(ss(id)))
        return;
    beginChange();
    doc_.removeLink(ss(id));
    commit();
}

void FlowController::undo()
{
    if (undo_.empty())
        return;
    redo_.push_back(std::move(doc_));
    doc_ = std::move(undo_.back());
    undo_.pop_back();
    commit();
}

void FlowController::redo()
{
    if (redo_.empty())
        return;
    undo_.push_back(std::move(doc_));
    doc_ = std::move(redo_.back());
    redo_.pop_back();
    commit();
}

// --- queries

bool FlowController::hasScreen(const QString& id) const { return !id.isEmpty() && doc_.findScreen(ss(id)); }

bool FlowController::hasLink(const QString& id) const { return !id.isEmpty() && doc_.findLink(ss(id)); }

QVariantMap FlowController::screen(const QString& id) const
{
    QVariantMap m;
    const Screen* s = doc_.findScreen(ss(id));
    if (!s)
        return m;
    const ImageAsset* img = doc_.image(s->imageId);
    const Rect r = doc_.screenRect(*s);
    m["id"] = qs(s->id);
    m["name"] = qs(s->name);
    m["displayName"] = displayName(*s);
    m["notes"] = qs(s->notes);
    m["scale"] = s->scale;
    m["x"] = s->x;
    m["y"] = s->y;
    m["width"] = r.w;
    m["height"] = r.h;
    m["imageUrl"] = imageUrl(s->imageId);
    m["imageWidth"] = img ? img->width : 0;
    m["imageHeight"] = img ? img->height : 0;
    m["fileName"] = img ? qs(img->fileName) : QString();
    m["isStart"] = doc_.startScreenId() == s->id;
    m["reachable"] = analysis_.pathTo.count(s->id) > 0;
    m["path"] = pathTo(id);
    m["hotspotCount"] = int(s->hotspots.size());
    return m;
}

QVariantList FlowController::hotspots(const QString& screenId) const
{
    const Screen* s = doc_.findScreen(ss(screenId));
    if (!s)
        return {};
    QVariantList out = hotspotList(doc_, *s, false);
    for (auto& v : out) {
        QVariantMap m = v.toMap();
        QVariantList links;
        for (const Link* l : doc_.linksFromHotspot(s->id, ss(m["id"].toString())))
            links.push_back(linkToVariant(*l));
        m["links"] = links;
        v = m;
    }
    return out;
}

QVariantMap FlowController::hotspot(const QString& screenId, const QString& id) const
{
    for (const auto& v : hotspots(screenId))
        if (v.toMap()["id"].toString() == id)
            return v.toMap();
    return {};
}

QVariantMap FlowController::linkToVariant(const Link& l) const
{
    QVariantMap m;
    m["id"] = qs(l.id);
    m["from"] = qs(l.from);
    m["fromName"] = screenName(doc_, l.from);
    m["to"] = qs(l.to);
    m["toName"] = screenName(doc_, l.to);
    m["hotspot"] = qs(l.hotspot);
    QString hname;
    if (const Screen* s = doc_.findScreen(l.from))
        if (const Hotspot* h = findHotspot(*s, l.hotspot))
            hname = qs(h->name.empty() ? h->id : h->name);
    m["hotspotName"] = hname;
    m["message"] = qs(l.message);
    m["label"] = qs(linkAction(doc_, l));
    m["isHotspotLink"] = !l.hotspot.empty();
    return m;
}

QVariantList FlowController::linksFrom(const QString& screenId, bool screenLevelOnly) const
{
    QVariantList out;
    for (const Link* l : doc_.linksFrom(ss(screenId)))
        if (!screenLevelOnly || l->hotspot.empty())
            out.push_back(linkToVariant(*l));
    return out;
}

QVariantList FlowController::linksTo(const QString& screenId) const
{
    QVariantList out;
    for (const Link* l : doc_.linksTo(ss(screenId)))
        out.push_back(linkToVariant(*l));
    return out;
}

QVariantMap FlowController::link(const QString& id) const
{
    const Link* l = doc_.findLink(ss(id));
    return l ? linkToVariant(*l) : QVariantMap();
}

QVariantList FlowController::screenList() const
{
    QVariantList out;
    for (const auto& s : doc_.screens) {
        QVariantMap m;
        m["id"] = qs(s.id);
        m["name"] = displayName(s);
        out.push_back(m);
    }
    return out;
}

QVariantList FlowController::overview() const
{
    QVariantList out;
    for (const auto& s : doc_.screens) {
        QVariantMap m;
        m["id"] = qs(s.id);
        m["name"] = displayName(s);
        m["imageUrl"] = imageUrl(s.imageId);
        m["isStart"] = doc_.startScreenId() == s.id;
        m["reachable"] = analysis_.pathTo.count(s.id) > 0;
        m["path"] = pathTo(qs(s.id));
        // Last hop of the shortest path: "Home · Click "Settings"".
        auto it = analysis_.pathTo.find(s.id);
        if (it != analysis_.pathTo.end() && !it->second.empty())
            if (const Link* last = doc_.findLink(it->second.back()))
                m["via"] = screenName(doc_, last->from) + QStringLiteral(" · ") + qs(linkAction(doc_, *last));
        m["deadEnd"] = std::find(analysis_.deadEnds.begin(), analysis_.deadEnds.end(), s.id) !=
                       analysis_.deadEnds.end();
        int idle = 0;
        for (const auto& [sid, hid] : analysis_.idleHotspots)
            idle += sid == s.id;
        m["idleHotspots"] = idle;
        m["hotspotCount"] = int(s.hotspots.size());
        m["outCount"] = int(doc_.linksFrom(s.id).size());
        out.push_back(m);
    }
    return out;
}

QVariantMap FlowController::stats() const
{
    QVariantMap m;
    m["screens"] = int(doc_.screens.size());
    m["links"] = int(doc_.links.size());
    m["unreachable"] = int(analysis_.unreachable.size());
    m["deadEnds"] = int(analysis_.deadEnds.size());
    m["idleHotspots"] = int(analysis_.idleHotspots.size());
    return m;
}

QString FlowController::pathTo(const QString& screenId) const
{
    auto it = analysis_.pathTo.find(ss(screenId));
    if (it == analysis_.pathTo.end())
        return {};
    return qs(describePath(doc_, analysis_.start, it->second, " \xE2\x86\x92 "));
}

QString FlowController::screenAt(qreal x, qreal y) const { return qs(uiflow::screenAt(doc_, {float(x), float(y)})); }

QString FlowController::linkAt(qreal x, qreal y, qreal tolerance) const
{
    return qs(uiflow::linkAt(doc_, {float(x), float(y)}, float(tolerance)));
}

QString FlowController::hotspotAt(const QString& screenId, qreal x, qreal y) const
{
    const Screen* s = doc_.findScreen(ss(screenId));
    if (!s)
        return {};
    for (auto it = s->hotspots.rbegin(); it != s->hotspots.rend(); ++it)
        if (it->rect.contains(float(x), float(y)))
            return qs(it->id);
    return {};
}

QRectF FlowController::bounds() const
{
    Rect r = documentBounds(doc_);
    return {r.x, r.y, r.w, r.h};
}

} // namespace uiflow
