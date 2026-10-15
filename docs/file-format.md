# ui-flow file format (version 1)

A ui-flow *app* is one UTF-8 JSON file, usually named `<something>.json`. It contains
everything: the screens, their clickable areas, the flow between them, and the images
themselves (base64). ui-flow writes it pretty-printed with 2-space indentation and a fixed
key order, so saving an unchanged app produces an identical file and diffs stay small.

The machine-readable schema is [`ui-flow.schema.json`](ui-flow.schema.json)
(JSON Schema 2020-12). This page explains what the schema cannot say: how the ids
reference each other, the coordinate systems, and how a reader must treat imperfect files.

## Overview

```
app
├── format, version, name, startScreen
├── screens[]          one per image on the canvas
│   └── hotspots[]     clickable rectangles, in image pixels
├── links[]            arrows: screen (or one of its hotspots) → screen
└── images[]           the embedded image files, referenced by screens[].image
```

```json
{
  "format": "ui-flow",
  "version": 1,
  "name": "Demo app",
  "startScreen": "screen-1",
  "screens": [
    {
      "id": "screen-1",
      "name": "Login",
      "image": "img-1",
      "x": 0,
      "y": 0,
      "scale": 0.4265,
      "hotspots": [
        { "id": "hotspot-1", "name": "Sign in", "x": 60, "y": 860, "w": 660, "h": 110 }
      ]
    },
    {
      "id": "screen-2",
      "name": "Home",
      "image": "img-2",
      "x": 600,
      "y": 0,
      "scale": 0.4265,
      "notes": "Shown after a successful login.",
      "hotspots": []
    }
  ],
  "links": [
    { "id": "link-1", "from": "screen-1", "hotspot": "hotspot-1", "to": "screen-2", "message": "" },
    { "id": "link-2", "from": "screen-2", "to": "screen-1", "message": "user types command logout" }
  ],
  "images": [
    { "id": "img-1", "file": "login.png", "mime": "image/png", "width": 780, "height": 1688, "data": "iVBORw0KGgo..." },
    { "id": "img-2", "file": "home.png",  "mime": "image/png", "width": 780, "height": 1688, "data": "iVBORw0KGgo..." }
  ]
}
```

## Top level

| Key | Type | Required | Meaning |
|---|---|---|---|
| `format` | `"ui-flow"` | yes | Identifies the file. Anything else is rejected. |
| `version` | integer | no (1) | Format version. A reader rejects files with a version newer than it knows. |
| `name` | string | no (`"Untitled"`) | Name of the app. |
| `startScreen` | string | no | Id of the screen where the flow starts. Empty or not a screen id: the first screen in `screens`. ui-flow always writes the effective start screen. |
| `screens` | array | no (`[]`) | The screens, in drawing order: later screens are drawn on top. |
| `links` | array | no (`[]`) | The interactions. |
| `images` | array | no (`[]`) | The embedded images. |

ui-flow always writes every key above (in this order) except where noted as omitted.

## Screens

| Key | Type | Meaning |
|---|---|---|
| `id` | string, **required** | Unique among screens. A duplicate id makes the file invalid. |
| `name` | string | Display name. Missing: the id is shown. |
| `image` | string | Id of an entry of `images`. If it does not exist, a grey placeholder is shown. |
| `x`, `y` | number | Canvas position of the image's top-left corner, in canvas units. ui-flow writes whole numbers. |
| `scale` | number > 0 | Canvas units per image pixel. On the canvas the screen measures `image.width × scale` by `image.height × scale`. New screens get a scale that makes their longest side 720 units. Missing or ≤ 0: 1. |
| `notes` | string | Free text. Omitted when empty. |
| `hotspots` | array | Clickable areas, see below. |

## Hotspots

A hotspot is a rectangle on a screen that the user can click.

| Key | Type | Meaning |
|---|---|---|
| `id` | string, **required** | Unique within its screen (links name a hotspot together with its screen). ui-flow makes them unique in the whole file. |
| `name` | string | What it is, e.g. `"Sign in"`. Used in the export: `Click "Sign in"`. |
| `x`, `y`, `w`, `h` | number | The rectangle in **image pixels**, origin at the image's top-left corner. It does not depend on the screen's `scale`. ui-flow writes whole numbers and keeps the rectangle inside the image. |

When a screen's image is replaced by one of a different size, ui-flow scales the hotspot
rectangles by the size ratio so they stay on the same relative spot.

## Links

A link is an arrow on the canvas and a step in the player.

| Key | Type | Meaning |
|---|---|---|
| `id` | string, **required** | Unique among links. |
| `from` | string, **required** | Id of the source screen. |
| `hotspot` | string | Id of a hotspot of the `from` screen: clicking it follows the link (blue arrow). **Absent**: a *described transition* that is not tied to an area (purple arrow), such as typing a command or waiting. ui-flow omits the key for those. |
| `to` | string, **required** | Id of the target screen. It may equal `from` (a loop). |
| `message` | string | For described transitions: what the user does, e.g. `"user types command help"`. For hotspot links: an optional note (a condition, an input...). |

Several links may share the same `from` + `hotspot`. The player then asks which one to
follow, and the messages tell them apart (e.g. *valid password* / *wrong password*).

## Images

| Key | Type | Meaning |
|---|---|---|
| `id` | string, **required** | Unique among images, referenced by `screens[].image`. |
| `file` | string | Original file name. Informative only. |
| `mime` | string | Media type, e.g. `image/png`. Informative only: readers detect the format from the content. |
| `width`, `height` | integer | Pixel size of the decoded image. Readers use them for the layout without decoding, so they must match `data`. |
| `data` | string, **required** | The original image file in standard base64 (RFC 4648, with `=` padding). It is the dropped file unchanged, not re-encoded. Readers accept PNG, JPEG, BMP, GIF (first frame), TGA, PSD and PNM, and ignore line breaks inside the string. |

Images are never modified in place: replacing a screen's image adds a new image entry.
Images that no screen references are not written when saving.

## Ids

Ids are opaque strings, so readers must not parse them. ui-flow generates `<kind>-<n>`
(`screen-3`, `hotspot-7`, `link-2`, `img-4`) from a single counter for the whole file.
When it loads a file it continues after the highest `<n>` it finds, so new ids never collide
with existing ones. Hand-written files may use any non-empty ids that are unique among their kind.

## Reading rules

A reader must handle imperfect files (hand-edited, or written by other tools) like this:

* **Rejected:** text that is not JSON, a top level that is not an object, a missing or
  different `format`, a `version` above the supported one, a screen without an `id` or with
  a duplicate `id`, a hotspot without an `id`, a key with the wrong type (e.g. a string
  where a number is expected), or an image whose `data` is not valid base64.
* **Dropped silently:** links without an `id`, links whose `from` or `to` is not a screen,
  and links whose `hotspot` is not a hotspot of the `from` screen.
* **Defaulted:** every other missing key takes the default listed above.
* **Ignored:** unknown keys. They are not kept when ui-flow saves the file again.

## Coordinate systems

```
canvas units ──────────────────────────────►  x
   │   (screen.x, screen.y)
   │        ┌──────────────────────┐  ◄─ image.width  * screen.scale
   │        │  image pixels ─► x   │
   │        │   │  ┌────────┐      │
   │        │   ▼  │hotspot │      │
   │        │   y  └────────┘      │
   │        └──────────────────────┘
   ▼  y                               ▲ image.height * screen.scale
```

* The **canvas** has no fixed origin or size: screens are placed anywhere with `x`, `y`.
* A **hotspot** at image pixel `(hx, hy)` is at canvas position
  `(screen.x + hx × screen.scale, screen.y + hy × screen.scale)`.

## Versioning

The `version` key changes only for incompatible changes. A reader rejects a version it
does not know rather than silently losing data. Additions that older readers can safely
ignore (new optional keys) keep the version.

## Related: the Markdown export

*Export flow as Markdown* (app menu) writes a separate, read-only `.md` document. It is not
loadable and not covered by this schema. For each screen it gives the shortest path from
the start screen (e.g. `Login → Click "Sign in" → Home → user types command help → Help`),
its interactions and where it is reached from. Warnings about unreachable screens and
hotspots without links come last.
