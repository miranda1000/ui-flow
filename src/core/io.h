// Reading/writing the app file (a single, pretty-printed JSON document) and small file
// helpers. All paths are UTF-8, also on Windows.
#pragma once

#include "core/model.h"

#include <cstdint>
#include <string>
#include <vector>

namespace uiflow {

constexpr const char* kFormatName = "ui-flow";
constexpr int kFormatVersion = 1;

// Structure first, embedded images (base64) last, so the top of the file stays readable.
std::string toJson(const Document& doc);
// Throws std::runtime_error with a readable message on malformed input.
Document fromJson(const std::string& text);

bool readFile(const std::string& path, std::vector<std::uint8_t>& out, std::string* error = nullptr);
bool readTextFile(const std::string& path, std::string& out, std::string* error = nullptr);
// Writes to "<path>.tmp" first and renames it over the target.
bool writeFileAtomic(const std::string& path, const std::string& data, std::string* error = nullptr);

std::string fileNameOf(const std::string& path);   // "C:\a\b.png" -> "b.png"
std::string stemOf(const std::string& path);       // "C:\a\b.png" -> "b"
std::string extensionOf(const std::string& path);  // lower-case, without dot: "png"

std::string base64Encode(const std::uint8_t* data, size_t size);
bool base64Decode(const std::string& text, std::vector<std::uint8_t>& out);

} // namespace uiflow
