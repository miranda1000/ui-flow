#include "core/flow.h"

#include <deque>
#include <set>
#include <sstream>

namespace uiflow {

namespace {

std::string screenName(const Document& doc, const std::string& id)
{
    const Screen* s = doc.findScreen(id);
    if (!s)
        return "?";
    return s->name.empty() ? s->id : s->name;
}

std::string mdCell(std::string text)
{
    std::string out;
    for (char c : text) {
        if (c == '|')
            out += "\\|";
        else if (c == '\n' || c == '\r')
            out += ' ';
        else
            out += c;
    }
    return out;
}

} // namespace

FlowAnalysis analyzeFlow(const Document& doc, const std::string& startArg)
{
    FlowAnalysis fa;
    fa.start = startArg.empty() ? doc.startScreenId() : startArg;

    if (doc.findScreen(fa.start)) {
        fa.pathTo[fa.start] = {};
        std::deque<std::string> queue{fa.start};
        while (!queue.empty()) {
            std::string cur = queue.front();
            queue.pop_front();
            for (const auto& l : doc.links) {
                if (l.from != cur || fa.pathTo.count(l.to))
                    continue;
                auto path = fa.pathTo[cur];
                path.push_back(l.id);
                fa.pathTo[l.to] = std::move(path);
                queue.push_back(l.to);
            }
        }
    }

    std::set<std::pair<std::string, std::string>> linkedHotspots;
    std::set<std::string> hasOutgoing;
    for (const auto& l : doc.links) {
        hasOutgoing.insert(l.from);
        if (!l.hotspot.empty())
            linkedHotspots.insert({l.from, l.hotspot});
    }
    for (const auto& s : doc.screens) {
        if (!fa.pathTo.count(s.id))
            fa.unreachable.push_back(s.id);
        if (!hasOutgoing.count(s.id))
            fa.deadEnds.push_back(s.id);
        for (const auto& h : s.hotspots)
            if (!linkedHotspots.count({s.id, h.id}))
                fa.idleHotspots.push_back({s.id, h.id});
    }
    return fa;
}

std::string linkAction(const Document& doc, const Link& link)
{
    if (link.hotspot.empty())
        return link.message.empty() ? std::string("(no description)") : link.message;

    std::string name = "?";
    if (const Screen* s = doc.findScreen(link.from))
        if (const Hotspot* h = findHotspot(*s, link.hotspot))
            name = h->name.empty() ? h->id : h->name;
    std::string out = "Click \"" + name + "\"";
    if (!link.message.empty())
        out += " (" + link.message + ")";
    return out;
}

std::string describePath(const Document& doc, const std::string& start, const std::vector<std::string>& linkIds,
                         const char* sep)
{
    std::string out = screenName(doc, start);
    for (const auto& id : linkIds) {
        const Link* l = doc.findLink(id);
        if (!l)
            continue;
        out += sep;
        out += linkAction(doc, *l);
        out += sep;
        out += screenName(doc, l->to);
    }
    return out;
}

std::string exportMarkdown(const Document& doc)
{
    const FlowAnalysis fa = analyzeFlow(doc);
    std::ostringstream md;

    md << "# " << doc.name << "\n\n";
    if (doc.screens.empty()) {
        md << "_This app has no screens yet._\n";
        return md.str();
    }
    md << "- Start screen: **" << screenName(doc, fa.start) << "**\n";
    md << "- " << doc.screens.size() << " screen" << (doc.screens.size() == 1 ? "" : "s") << ", "
       << doc.links.size() << " interaction" << (doc.links.size() == 1 ? "" : "s") << "\n\n";

    md << "## Screens\n\n";
    for (const auto& s : doc.screens) {
        md << "### " << screenName(doc, s.id) << "\n\n";
        if (s.id == fa.start)
            md << "Start screen.\n\n";
        else if (auto it = fa.pathTo.find(s.id); it != fa.pathTo.end())
            md << "How to reach: " << describePath(doc, fa.start, it->second, " → ") << "\n\n";
        else
            md << "**Not reachable from the start screen.**\n\n";

        if (!s.notes.empty())
            md << "> " << s.notes << "\n\n";

        auto out = doc.linksFrom(s.id);
        if (out.empty()) {
            md << "No interactions (dead end).\n\n";
        } else {
            md << "| Interaction | Goes to |\n|---|---|\n";
            for (const Link* l : out)
                md << "| " << mdCell(linkAction(doc, *l)) << " | " << mdCell(screenName(doc, l->to)) << " |\n";
            md << "\n";
        }

        auto in = doc.linksTo(s.id);
        if (!in.empty()) {
            md << "Reached from: ";
            for (size_t i = 0; i < in.size(); ++i)
                md << (i ? ", " : "") << screenName(doc, in[i]->from) << " (" << linkAction(doc, *in[i]) << ")";
            md << "\n\n";
        }
    }

    if (!fa.unreachable.empty() || !fa.idleHotspots.empty()) {
        md << "## Warnings\n\n";
        for (const auto& id : fa.unreachable)
            md << "- \"" << screenName(doc, id) << "\" cannot be reached from the start screen.\n";
        for (const auto& [sid, hid] : fa.idleHotspots) {
            const Screen* s = doc.findScreen(sid);
            const Hotspot* h = s ? findHotspot(*s, hid) : nullptr;
            md << "- Hotspot \"" << (h && !h->name.empty() ? h->name : hid) << "\" on \"" << screenName(doc, sid)
               << "\" does not lead anywhere.\n";
        }
        md << "\n";
    }
    return md.str();
}

} // namespace uiflow
