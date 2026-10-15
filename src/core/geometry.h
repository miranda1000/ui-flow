// Canvas geometry of links: each arrow is a cubic bezier, in canvas units.
#pragma once

#include "core/model.h"

namespace uiflow {

struct Point {
    float x = 0, y = 0;
};

struct Curve {
    Point p0, c0, c1, p1;
    bool selfLoop = false;

    Point at(float t) const;
    float distanceTo(Point p) const;  // approximate (polyline of 32 segments)
};

// Hotspot rectangle in canvas units.
Rect hotspotCanvasRect(const Screen& s, const Hotspot& h);

// Leaves the hotspot (or the screen) on the side facing the target and enters the target
// screen on the side facing the source.
Curve linkCurve(const Document& doc, const Link& link);

// Topmost screen / link at a canvas point ("" if none).
std::string screenAt(const Document& doc, Point p);
std::string linkAt(const Document& doc, Point p, float tolerance);

// Bounding box of all screens (zero rect when empty).
Rect documentBounds(const Document& doc);

} // namespace uiflow
