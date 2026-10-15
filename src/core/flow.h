// Graph questions about a document: how is each screen reached from the start screen,
// what is unreachable / a dead end, and a Markdown description of the whole flow.
#pragma once

#include "core/model.h"

#include <map>
#include <string>
#include <vector>

namespace uiflow {

struct FlowAnalysis {
    std::string start;
    // Shortest sequence of link ids from `start` to each reachable screen (start -> empty).
    std::map<std::string, std::vector<std::string>> pathTo;
    std::vector<std::string> unreachable;  // screen ids, document order
    std::vector<std::string> deadEnds;     // screens with no outgoing links
    std::vector<std::pair<std::string, std::string>> idleHotspots;  // (screen, hotspot) without links
};

// `start` defaults to the document's start screen.
FlowAnalysis analyzeFlow(const Document& doc, const std::string& start = {});

// What the user does to follow a link: `Click "Sign in"`, `user types command help`.
std::string linkAction(const Document& doc, const Link& link);

// "Login > Click "Sign in" > Home", with `sep` between the parts.
std::string describePath(const Document& doc, const std::string& start, const std::vector<std::string>& linkIds,
                         const char* sep);

std::string exportMarkdown(const Document& doc);

} // namespace uiflow
