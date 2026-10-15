#include "core/image.h"

#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#define STBI_NO_PIC
#include <stb_image.h>

#include <cstring>

namespace uiflow {

bool probeImage(const std::vector<std::uint8_t>& bytes, int& width, int& height)
{
    int comp = 0;
    return !bytes.empty() && stbi_info_from_memory(bytes.data(), int(bytes.size()), &width, &height, &comp) != 0;
}

bool decodeImage(const std::vector<std::uint8_t>& bytes, DecodedImage& out, std::string* error)
{
    int w = 0, h = 0, comp = 0;
    stbi_uc* pixels = bytes.empty() ? nullptr
                                    : stbi_load_from_memory(bytes.data(), int(bytes.size()), &w, &h, &comp, 4);
    if (!pixels) {
        if (error)
            *error = std::string("Unsupported or corrupt image (") + stbi_failure_reason() + ")";
        return false;
    }
    out.width = w;
    out.height = h;
    out.rgba.assign(pixels, pixels + size_t(w) * size_t(h) * 4);
    stbi_image_free(pixels);
    return true;
}

std::string guessMime(const std::vector<std::uint8_t>& b)
{
    auto starts = [&](const char* magic, size_t n) { return b.size() >= n && std::memcmp(b.data(), magic, n) == 0; };
    if (starts("\x89PNG", 4))
        return "image/png";
    if (starts("\xFF\xD8\xFF", 3))
        return "image/jpeg";
    if (starts("GIF8", 4))
        return "image/gif";
    if (starts("BM", 2))
        return "image/bmp";
    if (starts("8BPS", 4))
        return "image/vnd.adobe.photoshop";
    return "application/octet-stream";
}

bool isImageExtension(const std::string& ext)
{
    for (const char* e : {"png", "jpg", "jpeg", "bmp", "gif", "tga", "psd", "pnm", "ppm", "pgm"})
        if (ext == e)
            return true;
    return false;
}

bool makeImageAsset(std::string id, std::string fileName, std::vector<std::uint8_t> bytes, ImagePtr& out,
                    std::string* error)
{
    auto img = std::make_shared<ImageAsset>();
    if (!probeImage(bytes, img->width, img->height) || img->width <= 0 || img->height <= 0) {
        if (error)
            *error = "\"" + fileName + "\" is not an image ui-flow can read (PNG, JPEG, BMP, GIF, TGA, PSD)";
        return false;
    }
    img->id = std::move(id);
    img->fileName = std::move(fileName);
    img->mime = guessMime(bytes);
    img->bytes = std::move(bytes);
    out = std::move(img);
    return true;
}

} // namespace uiflow
