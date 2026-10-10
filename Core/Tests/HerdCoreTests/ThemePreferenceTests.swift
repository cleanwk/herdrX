import XCTest
@testable import HerdCore

final class ThemePreferenceTests: XCTestCase {
    func testHerdrThemeSectionAndAliases() {
        XCTAssertEqual(ThemePreference.herdrFamily(in: "name = 'nord'\n[theme]\nname = \"Tokyo Night Day\" # chosen\n[other]\nname='gruvbox'"), "tokyo-night")
        XCTAssertEqual(ThemePreference.herdrFamily(in: "[theme] # style\nname = 'rose-pine-dawn'"), "rose-pine")
        XCTAssertEqual(ThemePreference.herdrFamily(in: "[theme]\nname='Solarized Light'"), "solarized")
        XCTAssertEqual(ThemePreference.herdrFamily(in: "[other]\nname='nord'"), "catppuccin")
        XCTAssertEqual(ThemePreference.family("not-a-theme"), "catppuccin")
    }
}
