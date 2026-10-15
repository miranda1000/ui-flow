#include "core/geometry.h"

#include <algorithm>
#include <cmath>

namespace uiflow {

namespace {

float segmentDistance(Point p, Point a, Point b)
{
    float abx = b.x - a.x, aby = b.y - a.y;
    float len2 = abx * abx + aby * aby;
    float t = len2 > 0 ? std::clamp(((p.x - a.x) * abx + (p.y - a.y) * aby) / len2, 0.0f, 1.0f) : 0.0f;
    float dx = p.x - (a.x + abx * t), dy = p.y - (a.y + aby * t);
    return std::sqrt(dx * dx + dy * dy);
}

// Keeps the entry point inside the edge, away from the corners.
float clampInside(float v, float lo, float hi)
{
    float margin = std::min(24.0f, (hi - lo) * 0.25f);
    return std::clamp(v, lo + margin, hi - margin);
}

} // namespace

Point Curve::at(float t) const
{
    const float u = 1 - t;
    const float a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
    return {a * p0.x + b * c0.x + c * c1.x + d * p1.x, a * p0.y + b * c0.y + c * c1.y + d * p1.y};
}

float Curve::distanceTo(Point p) const
{
    float best = 1e30f;
    Point prev = p0;
    for (int i = 1; i <= 32; ++i) {
        Point cur = at(float(i) / 32.0f);
        best = std::min(best, segmentDistance(p, prev, cur));
        prev = cur;
    }
    return best;
}

Rect hotspotCanvasRect(const Screen& s, const Hotspot& h)
{
    return {s.x + h.rect.x * s.scale, s.y + h.rect.y * s.scale, h.rect.w * s.scale, h.rect.h * s.scale};
}

Curve linkCurve(const Document& doc, const Link& link)
{
    Curve c;
    const Screen* from = doc.findScreen(link.from);
    const Screen* to = doc.findScreen(link.to);
    if (!from || !to)
        return c;

    const Rect A = doc.screenRect(*from);
    const Rect T = doc.screenRect(*to);
    Rect S = A;
    const Hotspot* h = link.hotspot.empty() ? nullptr : findHotspot(*from, link.hotspot);
    if (h)
        S = hotspotCanvasRect(*from, *h);

    if (from == to) {
        // Loop out of the right side and back in from the top.
        c.selfLoop = true;
        c.p0 = {S.x + S.w, S.cy()};
        c.p1 = {A.x + A.w - std::min(40.0f, A.w * 0.2f), A.y};
        float k = std::max(60.0f, A.w * 0.25f);
        c.c0 = {A.x + A.w + k, c.p0.y};
        c.c1 = {c.p1.x + k * 0.3f, A.y - k};
        return c;
    }

    float dx0 = 0, dy0 = 0, dx1 = 0, dy1 = 0;
    if (T.x >= A.x + A.w) {             // target to the right
        c.p0 = {S.x + S.w, S.cy()};
        c.p1 = {T.x, clampInside(c.p0.y, T.y, T.y + T.h)};
        dx0 = 1;
        dx1 = -1;
    } else if (T.x + T.w <= A.x) {      // target to the left
        c.p0 = {S.x, S.cy()};
        c.p1 = {T.x + T.w, clampInside(c.p0.y, T.y, T.y + T.h)};
        dx0 = -1;
        dx1 = 1;
    } else if (T.cy() >= A.cy()) {      // overlapping columns, target below
        c.p0 = {S.cx(), S.y + S.h};
        c.p1 = {clampInside(c.p0.x, T.x, T.x + T.w), T.y};
        dy0 = 1;
        dy1 = -1;
    } else {                            // target above
        c.p0 = {S.cx(), S.y};
        c.p1 = {clampInside(c.p0.x, T.x, T.x + T.w), T.y + T.h};
        dy0 = -1;
        dy1 = 1;
    }
    float dx = c.p1.x - c.p0.x, dy = c.p1.y - c.p0.y;
    float dist = std::sqrt(dx * dx + dy * dy);  // not hypotf: glibc 2.35+
    float k = std::clamp(dist * 0.4f, 30.0f, 260.0f);
    c.c0 = {c.p0.x + dx0 * k, c.p0.y + dy0 * k};
    c.c1 = {c.p1.x + dx1 * k, c.p1.y + dy1 * k};
    return c;
}

std::string screenAt(const Document& doc, Point p)
{
    for (auto it = doc.screens.rbegin(); it != doc.screens.rend(); ++it)
        if (doc.screenRect(*it).contains(p.x, p.y))
            return it->id;
    return {};
}

std::string linkAt(const Document& doc, Point p, float tolerance)
{
    std::string best;
    float bestDist = tolerance;
    for (const auto& l : doc.links) {
        float d = linkCurve(doc, l).distanceTo(p);
        if (d <= bestDist) {
            bestDist = d;
            best = l.id;
        }
    }
    return best;
}

Rect documentBounds(const Document& doc)
{
    if (doc.screens.empty())
        return {};
    float x0 = 1e30f, y0 = 1e30f, x1 = -1e30f, y1 = -1e30f;
    for (const auto& s : doc.screens) {
        Rect r = doc.screenRect(s);
        x0 = std::min(x0, r.x);
        y0 = std::min(y0, r.y);
        x1 = std::max(x1, r.x + r.w);
        y1 = std::max(y1, r.y + r.h);
    }
    return {x0, y0, x1 - x0, y1 - y0};
}

} // namespace uiflow
