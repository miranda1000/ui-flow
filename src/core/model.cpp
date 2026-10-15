#include "core/model.h"

#include <algorithm>
#include <set>

namespace uiflow {

namespace {
constexpr float kPlaceholderW = 360;
constexpr float kPlaceholderH = 640;
}

std::string Document::newId(const char* prefix)
{
    return std::string(prefix) + "-" + std::to_string(nextId++);
}

Screen* Document::findScreen(const std::string& id)
{
    for (auto& s : screens)
        if (s.id == id)
            return &s;
    return nullptr;
}

const Screen* Document::findScreen(const std::string& id) const
{
    return const_cast<Document*>(this)->findScreen(id);
}

int Document::screenIndex(const std::string& id) const
{
    for (size_t i = 0; i < screens.size(); ++i)
        if (screens[i].id == id)
            return int(i);
    return -1;
}

Link* Document::findLink(const std::string& id)
{
    for (auto& l : links)
        if (l.id == id)
            return &l;
    return nullptr;
}

const Link* Document::findLink(const std::string& id) const
{
    return const_cast<Document*>(this)->findLink(id);
}

const ImageAsset* Document::image(const std::string& id) const
{
    auto it = images.find(id);
    return it == images.end() ? nullptr : it->second.get();
}

std::string Document::startScreenId() const
{
    if (findScreen(startScreen))
        return startScreen;
    return screens.empty() ? std::string() : screens.front().id;
}

Rect Document::screenRect(const Screen& s) const
{
    const ImageAsset* img = image(s.imageId);
    float w = img && img->width > 0 ? float(img->width) : kPlaceholderW / s.scale;
    float h = img && img->height > 0 ? float(img->height) : kPlaceholderH / s.scale;
    return {s.x, s.y, w * s.scale, h * s.scale};
}

void Document::removeScreen(const std::string& id)
{
    links.erase(std::remove_if(links.begin(), links.end(),
                               [&](const Link& l) { return l.from == id || l.to == id; }),
                links.end());
    screens.erase(std::remove_if(screens.begin(), screens.end(), [&](const Screen& s) { return s.id == id; }),
                  screens.end());
    if (startScreen == id)
        startScreen.clear();
    pruneImages();
}

void Document::removeHotspot(Screen& s, const std::string& id)
{
    links.erase(std::remove_if(links.begin(), links.end(),
                               [&](const Link& l) { return l.from == s.id && l.hotspot == id; }),
                links.end());
    s.hotspots.erase(std::remove_if(s.hotspots.begin(), s.hotspots.end(),
                                    [&](const Hotspot& h) { return h.id == id; }),
                     s.hotspots.end());
}

void Document::removeLink(const std::string& id)
{
    links.erase(std::remove_if(links.begin(), links.end(), [&](const Link& l) { return l.id == id; }),
                links.end());
}

void Document::pruneImages()
{
    std::set<std::string> used;
    for (const auto& s : screens)
        used.insert(s.imageId);
    for (auto it = images.begin(); it != images.end();) {
        if (used.count(it->first))
            ++it;
        else
            it = images.erase(it);
    }
}

std::vector<const Link*> Document::linksFrom(const std::string& screenId) const
{
    std::vector<const Link*> out;
    for (const auto& l : links)
        if (l.from == screenId)
            out.push_back(&l);
    return out;
}

std::vector<const Link*> Document::linksFromHotspot(const std::string& screenId, const std::string& hotspotId) const
{
    std::vector<const Link*> out;
    for (const auto& l : links)
        if (l.from == screenId && l.hotspot == hotspotId)
            out.push_back(&l);
    return out;
}

std::vector<const Link*> Document::linksTo(const std::string& screenId) const
{
    std::vector<const Link*> out;
    for (const auto& l : links)
        if (l.to == screenId)
            out.push_back(&l);
    return out;
}

const Hotspot* findHotspot(const Screen& s, const std::string& id)
{
    for (const auto& h : s.hotspots)
        if (h.id == id)
            return &h;
    return nullptr;
}

Hotspot* findHotspot(Screen& s, const std::string& id)
{
    return const_cast<Hotspot*>(findHotspot(static_cast<const Screen&>(s), id));
}

} // namespace uiflow
