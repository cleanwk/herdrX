import XCTest
@testable import HerdCore

final class HerdrConfigTests: XCTestCase {
    func testACCStyleConfigWithCommentsAndEscapedCommands() throws {
        let config = try HerdrConfig(#"""
        [theme]
        name = "light"
        [[ui.tab_bar_right]]
        type = "command"
        command = 'acc-herdr status --label' # trailing comment
        interval_seconds = 3
        timeout_seconds = 1
        [[keys.command]]
        key = "prefix+a"
        type = "popup"
        command = "exec \"$HOME/.local/bin/acc-herdr\" dashboard"
        description = "ACC devices"
        width = "80%"
        height = 30
        """#)
        XCTAssertEqual(config.status.first?.interval, 3)
        XCTAssertEqual(config.status.first?.timeout, 1)
        XCTAssertEqual(config.popups.first?.command, "exec \"$HOME/.local/bin/acc-herdr\" dashboard")
        XCTAssertEqual(config.popups.first?.title, "ACC devices")
        XCTAssertEqual(config.popups.first?.width.string, "80%")
    }
    func testInlineArrayAndMultilineLiteralCommands() throws {
        let config = try HerdrConfig("""
        [ui]
        tab_bar_right = [{type = 'command', command = 'printf "ACC ✓"'}, {type = 'hostname'}]
        tab_bar_right_separator = ' · '
        [[keys.command]]
        type = 'popup'
        command = '''
        printf '%s\\n' '# not a comment'
        exec sh
        '''
        """)
        XCTAssertEqual(config.status.count, 1); XCTAssertEqual(config.status[0].interval, 5); XCTAssertEqual(config.status[0].timeout, 2)
        XCTAssertEqual(config.separator, " · ")
        XCTAssertTrue(config.popups[0].command.contains("# not a comment"))
    }
    func testInvalidTOMLDoesNotExecutePartialConfiguration() {
        XCTAssertThrowsError(try HerdrConfig("[[keys.command]]\ncommand = 'echo'\nbroken = ["))
    }
    func testUnsupportedCommandsAndInvalidIntervalsAreIgnored() throws {
        let config = try HerdrConfig("""
        [ui]
        tab_bar_right = [{type = 'command', command = 'bad', interval_seconds = 0}]
        [keys]
        command = [{type = 'shell', command = 'no'}, {type = 'popup', command = ''}]
        """)
        XCTAssertTrue(config.status.isEmpty); XCTAssertTrue(config.popups.isEmpty)
    }
    func testStatusIsBoundedSingleLinePlainText() {
        XCTAssertEqual(HerdrConfig.statusText(Data("\u{1b}[32mACC ✓\u{1b}[0m\nignored".utf8)), "ACC ✓")
        XCTAssertEqual(HerdrConfig.statusText(Data(String(repeating: "a", count: 1000).utf8)).count, 256)
    }
}
