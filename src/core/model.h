// Document model of a ui-flow "app": screens (an image each), hotspots on those
// screens, and links (arrows) from a hotspot or a whole screen to another screen.
#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace uiflow {

struct Rect {
    float x = 0, y = 0, w = 0, h = 0;

    bool contains(float px, float py) const { return px >= x && py >= y && px < x + w && py < y + h; }
    float cx() const { return x + w * 0.5f; }
    float cy() const { return y + h * 0.5f; }
};

// The original encoded file (PNG, JPEG, ...) as dropped by the user. Immutable once
// created: replacing a screen's image creates a new asset, which keeps undo cheap.
struct ImageAsset {
    std::string id;
    std::string fileName;
    std::string mime;
    std::vector<std::uint8_t> bytes;
    int width = 0;
    int height = 0;
    // base64 of `bytes`, filled on first save/load: autosave does not re-encode images.
    mutable std::string base64;
};
using ImagePtr = std::shared_ptr<const ImageAsset>;

// A clickable area of a screen, in image pixel coordinates.
struct Hotspot {
    std::string id;
    std::string name;
    Rect rect;
};

struct Screen {
    std::string id;
    std::string name;
    std::string imageId;
    std::string notes;
    float x = 0, y = 0;   // canvas position of the image's top-left corner
    float scale = 1;      // canvas units per image pixel
    std::vector<Hotspot> hotspots;
};

// An interaction. `hotspot` empty means a screen-level transition ("user types
// command help"), otherwise "click this hotspot".
struct Link {
    std::string id;
    std::string from;
    std::string hotspot;
    std::string to;
    std::string message;
};

struct Document {
    std::string name = "Untitled";
    std::string startScreen;
    std::vector<Screen> screens;
    std::vector<Link> links;
    std::map<std::string, ImagePtr> images;
    int nextId = 1;

    std::string newId(const char* prefix);

    Screen* findScreen(const std::string& id);
    const Screen* findScreen(const std::string& id) const;
    int screenIndex(const std::string& id) const;
    Link* findLink(const std::string& id);
    const Link* findLink(const std::string& id) const;
    const ImageAsset* image(const std::string& id) const;

    // The start screen if set and valid, else the first screen, else "".
    std::string startScreenId() const;

    // Canvas rectangle of a screen's image (placeholder size when the image is missing).
    Rect screenRect(const Screen& s) const;

    void removeScreen(const std::string& id);              // also removes its links
    void removeHotspot(Screen& s, const std::string& id);  // also removes its links
    void removeLink(const std::string& id);
    void pruneImages();                                    // drop unreferenced images

    // Links leaving `screenId` (optionally only those of one hotspot; "" = screen-level).
    std::vector<const Link*> linksFrom(const std::string& screenId) const;
    std::vector<const Link*> linksFromHotspot(const std::string& screenId, const std::string& hotspotId) const;
    std::vector<const Link*> linksTo(const std::string& screenId) const;
};

const Hotspot* findHotspot(const Screen& s, const std::string& id);
Hotspot* findHotspot(Screen& s, const std::string& id);

} // namespace uiflow
