// Image probing/decoding (stb_image): PNG, JPEG, BMP, GIF (first frame), TGA, PSD, PNM.
#pragma once

#include "core/model.h"

#include <cstdint>
#include <string>
#include <vector>

namespace uiflow {

struct DecodedImage {
    int width = 0;
    int height = 0;
    std::vector<std::uint8_t> rgba;  // width * height * 4
};

bool probeImage(const std::vector<std::uint8_t>& bytes, int& width, int& height);
bool decodeImage(const std::vector<std::uint8_t>& bytes, DecodedImage& out, std::string* error = nullptr);
std::string guessMime(const std::vector<std::uint8_t>& bytes);
bool isImageExtension(const std::string& ext);

// Builds an asset from an encoded file; fails if it cannot be decoded.
bool makeImageAsset(std::string id, std::string fileName, std::vector<std::uint8_t> bytes, ImagePtr& out,
                    std::string* error = nullptr);

} // namespace uiflow
