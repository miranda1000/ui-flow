#include "core/io.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <set>
#include <stdexcept>

namespace uiflow {

namespace fs = std::filesystem;
using ojson = nlohmann::ordered_json;

namespace {

fs::path toPath(const std::string& utf8)
{
#if defined(__cpp_char8_t)
    return fs::path(std::u8string(utf8.begin(), utf8.end()));
#else
    return fs::u8path(utf8);
#endif
}

// Positions are stored as whole canvas units / image pixels: keeps the file diffable.
long rounded(float v) { return std::lround(v); }

double roundedScale(float v) { return std::round(double(v) * 10000.0) / 10000.0; }

std::string getString(const ojson& j, const char* key, const std::string& fallback = {})
{
    auto it = j.find(key);
    if (it == j.end() || it->is_null())
        return fallback;
    if (!it->is_string())
        throw std::runtime_error(std::string("\"") + key + "\" must be a string");
    return it->get<std::string>();
}

float getNumber(const ojson& j, const char* key, float fallback = 0)
{
    auto it = j.find(key);
    if (it == j.end() || it->is_null())
        return fallback;
    if (!it->is_number())
        throw std::runtime_error(std::string("\"") + key + "\" must be a number");
    return it->get<float>();
}

const ojson& getArray(const ojson& j, const char* key)
{
    static const ojson empty = ojson::array();
    auto it = j.find(key);
    if (it == j.end() || it->is_null())
        return empty;
    if (!it->is_array())
        throw std::runtime_error(std::string("\"") + key + "\" must be an array");
    return *it;
}

// Highest numeric suffix of "<prefix>-<n>" ids, so new ids never collide.
void bumpNextId(int& nextId, const std::string& id)
{
    auto dash = id.rfind('-');
    if (dash == std::string::npos || dash + 1 >= id.size())
        return;
    int n = 0;
    for (size_t i = dash + 1; i < id.size(); ++i) {
        if (id[i] < '0' || id[i] > '9')
            return;
        n = n * 10 + (id[i] - '0');
        if (n > 100000000)
            return;
    }
    nextId = std::max(nextId, n + 1);
}

} // namespace

std::string toJson(const Document& doc)
{
    ojson root;
    root["format"] = kFormatName;
    root["version"] = kFormatVersion;
    root["name"] = doc.name;
    root["startScreen"] = doc.startScreenId();

    ojson screens = ojson::array();
    for (const auto& s : doc.screens) {
        ojson js;
        js["id"] = s.id;
        js["name"] = s.name;
        js["image"] = s.imageId;
        js["x"] = rounded(s.x);
        js["y"] = rounded(s.y);
        js["scale"] = roundedScale(s.scale);
        if (!s.notes.empty())
            js["notes"] = s.notes;
        ojson hs = ojson::array();
        for (const auto& h : s.hotspots) {
            ojson jh;
            jh["id"] = h.id;
            jh["name"] = h.name;
            jh["x"] = rounded(h.rect.x);
            jh["y"] = rounded(h.rect.y);
            jh["w"] = rounded(h.rect.w);
            jh["h"] = rounded(h.rect.h);
            hs.push_back(std::move(jh));
        }
        js["hotspots"] = std::move(hs);
        screens.push_back(std::move(js));
    }
    root["screens"] = std::move(screens);

    ojson links = ojson::array();
    for (const auto& l : doc.links) {
        ojson jl;
        jl["id"] = l.id;
        jl["from"] = l.from;
        if (!l.hotspot.empty())
            jl["hotspot"] = l.hotspot;
        jl["to"] = l.to;
        jl["message"] = l.message;
        links.push_back(std::move(jl));
    }
    root["links"] = std::move(links);

    // Only images some screen uses (undo snapshots may keep others alive in memory).
    std::set<std::string> used;
    for (const auto& sc : doc.screens)
        used.insert(sc.imageId);
    ojson images = ojson::array();
    for (const auto& [id, img] : doc.images) {
        if (!used.count(id))
            continue;
        ojson ji;
        ji["id"] = id;
        ji["file"] = img->fileName;
        ji["mime"] = img->mime;
        ji["width"] = img->width;
        ji["height"] = img->height;
        if (img->base64.empty())
            img->base64 = base64Encode(img->bytes.data(), img->bytes.size());
        ji["data"] = img->base64;
        images.push_back(std::move(ji));
    }
    root["images"] = std::move(images);

    return root.dump(2) + "\n";
}

Document fromJson(const std::string& text)
{
    ojson root;
    try {
        root = ojson::parse(text);
    } catch (const nlohmann::json::parse_error& e) {
        throw std::runtime_error(std::string("Not valid JSON: ") + e.what());
    }
    if (!root.is_object())
        throw std::runtime_error("The file does not contain a JSON object");
    if (getString(root, "format") != kFormatName)
        throw std::runtime_error("Not a ui-flow app file (missing \"format\": \"ui-flow\")");
    if (getNumber(root, "version", 1) > kFormatVersion)
        throw std::runtime_error("The file was written by a newer version of ui-flow");

    Document doc;
    doc.nextId = 1;
    doc.name = getString(root, "name", "Untitled");
    doc.startScreen = getString(root, "startScreen");

    for (const auto& ji : getArray(root, "images")) {
        auto img = std::make_shared<ImageAsset>();
        img->id = getString(ji, "id");
        img->fileName = getString(ji, "file");
        img->mime = getString(ji, "mime");
        img->width = int(getNumber(ji, "width"));
        img->height = int(getNumber(ji, "height"));
        img->base64 = getString(ji, "data");
        if (!base64Decode(img->base64, img->bytes))
            throw std::runtime_error("Image \"" + img->id + "\" has invalid base64 data");
        bumpNextId(doc.nextId, img->id);
        doc.images[img->id] = std::move(img);
    }

    for (const auto& js : getArray(root, "screens")) {
        Screen s;
        s.id = getString(js, "id");
        if (s.id.empty() || doc.findScreen(s.id))
            throw std::runtime_error("Every screen needs a unique \"id\"");
        s.name = getString(js, "name", s.id);
        s.imageId = getString(js, "image");
        s.notes = getString(js, "notes");
        s.x = getNumber(js, "x");
        s.y = getNumber(js, "y");
        s.scale = getNumber(js, "scale", 1);
        if (!(s.scale > 0))
            s.scale = 1;
        for (const auto& jh : getArray(js, "hotspots")) {
            Hotspot h;
            h.id = getString(jh, "id");
            if (h.id.empty())
                throw std::runtime_error("A hotspot of screen \"" + s.id + "\" has no \"id\"");
            h.name = getString(jh, "name");
            h.rect = {getNumber(jh, "x"), getNumber(jh, "y"), getNumber(jh, "w"), getNumber(jh, "h")};
            bumpNextId(doc.nextId, h.id);
            s.hotspots.push_back(std::move(h));
        }
        bumpNextId(doc.nextId, s.id);
        doc.screens.push_back(std::move(s));
    }

    for (const auto& jl : getArray(root, "links")) {
        Link l;
        l.id = getString(jl, "id");
        l.from = getString(jl, "from");
        l.hotspot = getString(jl, "hotspot");
        l.to = getString(jl, "to");
        l.message = getString(jl, "message");
        // Dangling links (hand-edited files) are dropped rather than rejected.
        const Screen* from = doc.findScreen(l.from);
        if (l.id.empty() || !from || !doc.findScreen(l.to))
            continue;
        if (!l.hotspot.empty() && !findHotspot(*from, l.hotspot))
            continue;
        bumpNextId(doc.nextId, l.id);
        doc.links.push_back(std::move(l));
    }
    return doc;
}

bool readFile(const std::string& path, std::vector<std::uint8_t>& out, std::string* error)
{
    std::ifstream in(toPath(path), std::ios::binary);
    if (!in) {
        if (error)
            *error = "Cannot open " + path;
        return false;
    }
    in.seekg(0, std::ios::end);
    auto size = in.tellg();
    in.seekg(0, std::ios::beg);
    if (size < 0) {
        if (error)
            *error = "Cannot read " + path;
        return false;
    }
    out.resize(size_t(size));
    if (size > 0 && !in.read(reinterpret_cast<char*>(out.data()), size)) {
        if (error)
            *error = "Cannot read " + path;
        return false;
    }
    return true;
}

bool readTextFile(const std::string& path, std::string& out, std::string* error)
{
    std::vector<std::uint8_t> bytes;
    if (!readFile(path, bytes, error))
        return false;
    out.assign(bytes.begin(), bytes.end());
    return true;
}

bool writeFileAtomic(const std::string& path, const std::string& data, std::string* error)
{
    fs::path target = toPath(path);
    fs::path tmp = target;
    tmp += ".tmp";
    {
        std::ofstream out(tmp, std::ios::binary | std::ios::trunc);
        if (!out || !out.write(data.data(), std::streamsize(data.size())) || !out.flush()) {
            if (error)
                *error = "Cannot write " + path;
            return false;
        }
    }
    std::error_code ec;
    fs::rename(tmp, target, ec);
    if (ec) {
        fs::remove(tmp, ec);
        if (error)
            *error = "Cannot replace " + path;
        return false;
    }
    return true;
}

std::string fileNameOf(const std::string& path)
{
    auto pos = path.find_last_of("/\\");
    return pos == std::string::npos ? path : path.substr(pos + 1);
}

std::string stemOf(const std::string& path)
{
    std::string name = fileNameOf(path);
    auto dot = name.rfind('.');
    return dot == std::string::npos || dot == 0 ? name : name.substr(0, dot);
}

std::string extensionOf(const std::string& path)
{
    std::string name = fileNameOf(path);
    auto dot = name.rfind('.');
    if (dot == std::string::npos)
        return {};
    std::string ext = name.substr(dot + 1);
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    return ext;
}

std::string base64Encode(const std::uint8_t* data, size_t size)
{
    static const char* table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve((size + 2) / 3 * 4);
    size_t i = 0;
    for (; i + 2 < size; i += 3) {
        std::uint32_t v = (std::uint32_t(data[i]) << 16) | (std::uint32_t(data[i + 1]) << 8) | data[i + 2];
        out += table[(v >> 18) & 63];
        out += table[(v >> 12) & 63];
        out += table[(v >> 6) & 63];
        out += table[v & 63];
    }
    if (i < size) {
        std::uint32_t v = std::uint32_t(data[i]) << 16;
        if (i + 1 < size)
            v |= std::uint32_t(data[i + 1]) << 8;
        out += table[(v >> 18) & 63];
        out += table[(v >> 12) & 63];
        out += i + 1 < size ? table[(v >> 6) & 63] : '=';
        out += '=';
    }
    return out;
}

bool base64Decode(const std::string& text, std::vector<std::uint8_t>& out)
{
    out.clear();
    out.reserve(text.size() / 4 * 3);
    std::uint32_t acc = 0;
    int bits = 0;
    bool padding = false;
    for (unsigned char c : text) {
        int v;
        if (c >= 'A' && c <= 'Z')
            v = c - 'A';
        else if (c >= 'a' && c <= 'z')
            v = c - 'a' + 26;
        else if (c >= '0' && c <= '9')
            v = c - '0' + 52;
        else if (c == '+' || c == '-')
            v = 62;
        else if (c == '/' || c == '_')
            v = 63;
        else if (c == '=') {
            padding = true;
            continue;
        } else if (c == '\n' || c == '\r' || c == ' ' || c == '\t')
            continue;
        else
            return false;
        if (padding)
            return false;  // data after padding
        acc = (acc << 6) | std::uint32_t(v);
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out.push_back(std::uint8_t((acc >> bits) & 0xFF));
        }
    }
    return true;
}

} // namespace uiflow
