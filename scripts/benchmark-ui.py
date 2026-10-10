#!/usr/bin/env python3
"""Measure native derived UI work without opening the app or changing preferences.

Uses the production color code and pinned Ghostty palette sources. Terminal
controller setup is excluded because this benchmark never creates a terminal.
Run after package resolution: python3 scripts/benchmark-ui.py [--baseline REF]
"""
import argparse
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def theme_source(source, name):
    source = source.split("    @MainActor static func apply()", 1)[0] + "}\n"
    source = "\n".join(line for line in source.splitlines()
                       if not line.startswith("import ") or line == "import AppKit")
    return source.replace("enum Theme {", f"enum {name} {{").replace(
        "UserDefaults.standard", "benchmarkDefaults")


def desk_source(desk, navigation, name):
    # Extract complete methods, keeping production logic unchanged. The harness
    # replaces property publishers with counters and never constructs the real Desk.
    methods = navigation.split("    func title(device:", 1)[1].split("    func paneHelp(", 1)[0]
    reindex = desk.split("    private func rank(", 1)[1].split("    func jump(", 1)[0]
    return f"""
final class {name} {{
    var devices: [Device] = []
    var sessions: [String: Session] = [:]
    var branches: [String: String] = [:]
    var focused: PaneKey?
    var searchActivity: [String: TimeInterval] = [:]
    var publications = 0
    var agents: [AgentRow] = [] {{ didSet {{ publications += 1 }} }}
    var jumpRows: [String: JumpRow] = [:] {{ didSet {{ publications += 1 }} }}
    var search = Search([]) {{ didSet {{ publications += 1 }} }}
    private var indexedRows: [JumpRow] = []
    func title(device:{methods}
    private func rank({reindex}
}}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default="HEAD")
    args = parser.parse_args()
    palettes = ROOT / ".build/checkouts/libghostty-spm/Sources/GhosttyTheme"
    if not palettes.is_dir():
        raise SystemExit("Resolve Swift packages first; the pinned Ghostty palette sources are required.")
    before = subprocess.check_output(
        ["git", "show", f"{args.baseline}:App/Theme.swift"], cwd=ROOT, text=True)
    desk_before = subprocess.check_output(
        ["git", "show", f"{args.baseline}:App/Desk.swift"], cwd=ROOT, text=True)
    navigation_before = subprocess.check_output(
        ["git", "show", f"{args.baseline}:App/Navigation.swift"], cwd=ROOT, text=True)
    with tempfile.TemporaryDirectory(prefix="herdrx-ui-benchmark-") as directory:
        output = pathlib.Path(directory)
        generated = output / "Themes.swift"
        generated.write_text(theme_source(before, "BaselineTheme") + "\n" + theme_source(
            (ROOT / "App/Theme.swift").read_text(), "CandidateTheme"))
        desk = (ROOT / "App/Desk.swift").read_text()
        declarations = "\n".join(line for line in desk.splitlines()
                                 if line.startswith(("struct AgentRow:", "struct JumpRow:")))
        derived = output / "Derived.swift"
        derived.write_text("import Foundation\n" + declarations + "\n" +
                           desk_source(desk_before, navigation_before, "BaselineDesk") +
                           desk_source(desk, (ROOT / "App/Navigation.swift").read_text(), "CandidateDesk"))
        # These are the exact family definitions referenced by App/Theme.swift.
        families = [palettes / "Themes" / f"Themes_{letter}.swift"
                    for letter in "CDGIKNORTV"]
        command = ["xcrun", "swiftc", "-O", "-swift-version", "5", "-module-cache-path",
                   str(output / "module-cache"), str(palettes / "GhosttyThemeDefinition.swift"),
                   *map(str, families), str(ROOT / "App/ThemeColors.swift"), str(generated),
                   *map(str, (ROOT / "Core/Sources/HerdCore").glob("*.swift")), str(derived),
                   str(ROOT / "Tests/UIBenchmark.swift"), "-o", str(output / "benchmark")]
        subprocess.run(command, cwd=ROOT, check=True)
        subprocess.run([str(output / "benchmark")], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
