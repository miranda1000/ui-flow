// export-md <app.json>: prints the Markdown export of an app file, the same text the app's
// "Export flow as Markdown..." writes (make-banners.sh shows it in a banner).
#include "core/flow.h"
#include "core/io.h"

#include <exception>
#include <iostream>

int main(int argc, char* argv[])
{
    if (argc != 2) {
        std::cerr << "usage: export-md <app.json>\n";
        return 2;
    }
    std::string text, error;
    if (!uiflow::readTextFile(argv[1], text, &error)) {
        std::cerr << error << '\n';
        return 1;
    }
    try {
        std::cout << uiflow::exportMarkdown(uiflow::fromJson(text));
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
    return 0;
}
