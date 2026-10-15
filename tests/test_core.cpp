// Unit tests of the core library (model, file format, flow analysis, geometry).
#include "core/flow.h"
#include "core/geometry.h"
#include "core/image.h"
#include "core/io.h"

#include <cmath>
#include <cstdio>
#include <functional>
#include <stdexcept>
#include <string>
#include <vector>

using namespace uiflow;

namespace {

int g_failed = 0;
int g_checks = 0;

#define CHECK(cond)                                                                    \
    do {                                                                               \
        ++g_checks;                                                                    \
        if (!(cond)) {                                                                 \
            ++g_failed;                                                                \
            std::printf("  FAILED %s:%d: %s\n", __FILE__, __LINE__, #cond);            \
        }                                                                              \
    } while (0)

// 1x1 PNG
const char* kPng1x1 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";

ImagePtr testImage(const std::string& id, int w, int h)
{
    auto img = std::make_shared<ImageAsset>();
    img->id = id;
    img->fileName = id + ".png";
    img->mime = "image/png";
    base64Decode(kPng1x1, img->bytes);
    img->width = w;
    img->height = h;
    return img;
}

// Login --(Sign in)--> Home --("user types command help")--> Help ;  Orphan unreachable
Document sampleDoc()
{
    Document d;
    d.name = "Sample";
    const char* names[] = {"Login", "Home", "Help", "Orphan"};
    for (int i = 0; i < 4; ++i) {
        ImagePtr img = testImage(d.newId("img"), 400, 800);
        d.images[img->id] = img;
        Screen s;
        s.id = d.newId("screen");
        s.name = names[i];
        s.imageId = img->id;
        s.scale = 0.5f;
        s.x = float(i) * 400;
        s.y = 0;
        d.screens.push_back(s);
    }
    Hotspot signIn{d.newId("hotspot"), "Sign in", {50, 600, 300, 60}};
    Hotspot forgot{d.newId("hotspot"), "Forgot password", {50, 700, 300, 40}};
    d.screens[0].hotspots = {signIn, forgot};
    d.startScreen = d.screens[0].id;
    d.links.push_back({d.newId("link"), d.screens[0].id, signIn.id, d.screens[1].id, ""});
    d.links.push_back({d.newId("link"), d.screens[1].id, "", d.screens[2].id, "user types command help"});
    return d;
}

void testBase64()
{
    for (std::string s : {"", "f", "fo", "foo", "foob", "fooba", "foobar", "\xff\x00\x10 binary"}) {
        std::vector<std::uint8_t> in(s.begin(), s.end()), out;
        std::string enc = base64Encode(in.data(), in.size());
        CHECK(enc.size() % 4 == 0);
        CHECK(base64Decode(enc, out));
        CHECK(out == in);
    }
    std::vector<std::uint8_t> out;
    CHECK(base64Encode(reinterpret_cast<const std::uint8_t*>("foobar"), 6) == "Zm9vYmFy");
    CHECK(base64Decode("Zm9v\nYmFy", out) && std::string(out.begin(), out.end()) == "foobar");
    CHECK(!base64Decode("Zm9v!", out));
}

void testImages()
{
    std::vector<std::uint8_t> png;
    base64Decode(kPng1x1, png);
    int w = 0, h = 0;
    CHECK(probeImage(png, w, h) && w == 1 && h == 1);
    CHECK(guessMime(png) == "image/png");
    DecodedImage dec;
    CHECK(decodeImage(png, dec) && dec.rgba.size() == 4);
    ImagePtr asset;
    CHECK(makeImageAsset("img-1", "a.png", png, asset) && asset->width == 1);
    std::string err;
    CHECK(!makeImageAsset("img-2", "notes.txt", {'h', 'i'}, asset, &err) && !err.empty());
}

void testJsonRoundTrip()
{
    Document d = sampleDoc();
    d.screens[1].notes = "Main screen";
    std::string json = toJson(d);
    CHECK(json.find("\"format\": \"ui-flow\"") != std::string::npos);
    // Structure comes before the (long) image data.
    CHECK(json.find("\"screens\"") < json.find("\"images\""));

    Document r = fromJson(json);
    CHECK(r.name == "Sample");
    CHECK(r.screens.size() == 4);
    CHECK(r.links.size() == 2);
    CHECK(r.images.size() == 4);
    CHECK(r.startScreen == d.startScreen);
    CHECK(r.screens[1].notes == "Main screen");
    CHECK(r.screens[0].hotspots.size() == 2);
    CHECK(r.screens[0].hotspots[0].rect.w == 300);
    CHECK(r.screens[0].scale == 0.5f);
    CHECK(r.links[1].message == "user types command help");
    CHECK(r.links[0].hotspot == d.links[0].hotspot);
    CHECK(r.images.begin()->second->bytes == d.images.begin()->second->bytes);
    CHECK(r.nextId >= d.nextId);  // new ids never collide with loaded ones
    CHECK(toJson(r) == json);     // stable output

    // Images no screen uses are not written.
    Document u = sampleDoc();
    u.screens[1].notes = "Main screen";
    u.images["img-unused"] = testImage("img-unused", 10, 10);
    CHECK(toJson(u) == json);
}

void testJsonErrors()
{
    auto throws = [](const std::string& text) {
        try {
            fromJson(text);
        } catch (const std::runtime_error&) {
            return true;
        }
        return false;
    };
    CHECK(throws("not json"));
    CHECK(throws("[]"));
    CHECK(throws("{\"format\": \"something-else\"}"));
    CHECK(throws("{\"format\": \"ui-flow\", \"version\": 99}"));
    CHECK(throws("{\"format\": \"ui-flow\", \"screens\": [{\"name\": \"no id\"}]}"));

    // Dangling links are dropped, not fatal.
    Document d = fromJson(R"({"format": "ui-flow", "screens": [{"id": "screen-1"}],
        "links": [{"id": "link-7", "from": "screen-1", "to": "screen-9"}]})");
    CHECK(d.screens.size() == 1);
    CHECK(d.links.empty());
    CHECK(d.newId("x") == "x-2");
}

void testEditing()
{
    Document d = sampleDoc();
    Screen& login = d.screens[0];
    d.removeHotspot(login, login.hotspots[0].id);
    CHECK(login.hotspots.size() == 1);
    CHECK(d.links.size() == 1);  // the Sign in link went with it

    Document e = sampleDoc();
    std::string home = e.screens[1].id;
    e.removeScreen(home);
    CHECK(e.screens.size() == 3);
    CHECK(e.links.empty());
    CHECK(e.images.size() == 3);  // its image is pruned

    Document f = sampleDoc();
    f.removeScreen(f.startScreen);
    CHECK(f.startScreen.empty());
    CHECK(f.startScreenId() == f.screens.front().id);
}

void testFlowAnalysis()
{
    Document d = sampleDoc();
    FlowAnalysis fa = analyzeFlow(d);
    const std::string login = d.screens[0].id, home = d.screens[1].id, help = d.screens[2].id,
                      orphan = d.screens[3].id;
    CHECK(fa.start == login);
    CHECK(fa.pathTo.at(login).empty());
    CHECK(fa.pathTo.at(home).size() == 1);
    CHECK(fa.pathTo.at(help).size() == 2);
    CHECK(fa.pathTo.count(orphan) == 0);
    CHECK(fa.unreachable == std::vector<std::string>{orphan});
    CHECK(fa.deadEnds.size() == 2);  // Help and Orphan
    CHECK(fa.idleHotspots.size() == 1 && fa.idleHotspots[0].first == login);

    CHECK(linkAction(d, d.links[0]) == "Click \"Sign in\"");
    CHECK(linkAction(d, d.links[1]) == "user types command help");
    CHECK(describePath(d, login, fa.pathTo.at(help), " > ") ==
          "Login > Click \"Sign in\" > Home > user types command help > Help");

    std::string md = exportMarkdown(d);
    CHECK(md.find("# Sample") == 0);
    CHECK(md.find("How to reach: Login → Click \"Sign in\" → Home → user types command help → Help") !=
          std::string::npos);
    CHECK(md.find("\"Orphan\" cannot be reached") != std::string::npos);
    CHECK(md.find("Hotspot \"Forgot password\" on \"Login\" does not lead anywhere") != std::string::npos);
}

void testGeometry()
{
    Document d = sampleDoc();
    // Login at x 0..200, Home at x 400..600 (scale 0.5 of 400x800).
    Curve c = linkCurve(d, d.links[0]);
    const Hotspot& h = d.screens[0].hotspots[0];
    CHECK(std::fabs(c.p0.x - (h.rect.x + h.rect.w) * 0.5f) < 0.01f);  // right edge of the hotspot
    CHECK(std::fabs(c.p1.x - 400) < 0.01f);                          // left edge of Home
    CHECK(!c.selfLoop);
    Point mid = c.at(0.5f);
    CHECK(linkAt(d, mid, 3) == d.links[0].id);
    CHECK(linkAt(d, {1000, -500}, 3).empty());
    CHECK(screenAt(d, {450, 100}) == d.screens[1].id);
    CHECK(screenAt(d, {300, 100}).empty());

    Rect b = documentBounds(d);
    CHECK(b.x == 0 && b.y == 0 && b.w == 1400 && b.h == 400);

    Link self{"link-x", d.screens[2].id, "", d.screens[2].id, "refresh"};
    CHECK(linkCurve(d, self).selfLoop);
}

} // namespace

int main()
{
    const std::pair<const char*, std::function<void()>> tests[] = {
        {"base64", testBase64},           {"images", testImages},     {"json round trip", testJsonRoundTrip},
        {"json errors", testJsonErrors},  {"editing", testEditing},   {"flow analysis", testFlowAnalysis},
        {"geometry", testGeometry},
    };
    for (const auto& [name, fn] : tests) {
        int before = g_failed;
        fn();
        std::printf("%s %s\n", g_failed == before ? "ok  " : "FAIL", name);
    }
    std::printf("%d checks, %d failed\n", g_checks, g_failed);
    return g_failed == 0 ? 0 : 1;
}
