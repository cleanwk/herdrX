import AppKit

// Volatile arguments override preferences only in this process; no user domain is written.
let benchmarkDefaults = UserDefaults(suiteName: "io.github.cleanwk.herdrx.ui-benchmark")!
func L(_ value: String) -> String { value }

@main
struct UIBenchmark {
    static var checksum: CGFloat = 0

    static func preferences(family: String, accent: String, herdr: String = "catppuccin") {
        benchmarkDefaults.setVolatileDomain(["palette": family, "accent": accent,
            "resolvedHerdrTheme": herdr], forName: UserDefaults.argumentDomain)
    }

    static func components(_ color: NSColor) -> [CGFloat] {
        let rgb = color.usingColorSpace(.sRGB)!
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent]
    }

    static func same(_ lhs: ThemeColors, _ rhs: ThemeColors) -> Bool {
        let a = [lhs.background, lhs.chrome, lhs.selection, lhs.foreground, lhs.secondary, lhs.accent] + lhs.surfaces
        let b = [rhs.background, rhs.chrome, rhs.selection, rhs.foreground, rhs.secondary, rhs.accent] + rhs.surfaces
        return zip(a, b).allSatisfy { components($0) == components($1) }
    }

    static func measure(iterations: Int = 20, samples sampleCount: Int = 7, _ action: () -> Void) -> Double {
        var samples: [Double] = []
        for _ in 0..<sampleCount {
            let start = ContinuousClock.now
            for _ in 0..<iterations { action() }
            let elapsed = start.duration(to: .now).components
            samples.append((Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15) / Double(iterations))
        }
        return samples.sorted()[samples.count / 2]
    }

    static func main() {
        setbuf(stdout, nil)
        var comparisons = 0
        for (family, _) in CandidateTheme.palettes {
            for accent in ["theme"] + CandidateTheme.accents {
                preferences(family: family, accent: accent)
                // Alternating appearances and repeating warm reads catches stale cache entries.
                for dark in [false, true, false, true] {
                    precondition(same(BaselineTheme.roles(dark: dark), CandidateTheme.roles(dark: dark)),
                                 "Role mismatch: \(family), \(accent), \(dark)")
                    comparisons += 1
                }
            }
        }
        for family in ["nord", "vesper", "catppuccin"] {
            preferences(family: "herdr", accent: "theme", herdr: family)
            for dark in [true, false] {
                precondition(same(BaselineTheme.roles(dark: dark), CandidateTheme.roles(dark: dark)))
                comparisons += 1
            }
        }
        print("PASS: \(comparisons) exact role comparisons across palettes, accents, appearances and Follow Herdr changes")

        preferences(family: "catppuccin", accent: "theme")
        let colorsBefore = [BaselineTheme.content, BaselineTheme.foreground, BaselineTheme.secondary,
                            BaselineTheme.chrome, BaselineTheme.selection, BaselineTheme.accent]
        let colorsAfter = [CandidateTheme.content, CandidateTheme.foreground, CandidateTheme.secondary,
                           CandidateTheme.chrome, CandidateTheme.selection, CandidateTheme.accent]
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            appearance.performAsCurrentDrawingAppearance {
                let before = measure {
                    for _ in 0..<20 { for color in colorsBefore { checksum += color.usingColorSpace(.sRGB)!.redComponent } }
                }
                let after = measure {
                    for _ in 0..<20 { for color in colorsAfter { checksum += color.usingColorSpace(.sRGB)!.redComponent } }
                }
                print(String(format: "120 dynamic role resolutions (%@), median: %.3f ms -> %.3f ms (%.2fx)",
                             dark ? "dark" : "light", before, after, before / after))
            }
        }
        print("checksum: \(checksum)")
        benchmarkIndex()
    }

    static func snapshot(panes count: Int, changed: Bool = false) -> Session {
        let spaces: [JSON] = (0..<max(1, count / 20)).map { .object([
            "workspace_id": .string("s\($0)"), "label": .string("Project \($0)"), "cwd": .string("/tmp/project-\($0)")]) }
        let tabs: [JSON] = (0..<max(1, count / 4)).map { .object([
            "workspace_id": .string("s\($0 / 5)"), "tab_id": .string("t\($0)"), "label": .string("Feature \($0)")]) }
        let panes: [JSON] = (0..<count).map { i in
            .object(["workspace_id": .string("s\(i / 20)"), "tab_id": .string("t\(i / 4)"),
                     "pane_id": .string("p\(i)"), "title": .string(i.isMultiple(of: 7) ? "" : "Task \(i)"),
                     "agent": i.isMultiple(of: 3) ? .null : .string("codex"),
                     "agent_status": .string(changed && i == 1 ? "blocked" : ["working", "done", "idle", "blocked", "unknown"][i % 5]),
                     "cwd": .string("/tmp/project-\(i / 20)")])
        }
        return try! Session(.object(["workspaces": .array(spaces), "tabs": .array(tabs), "panes": .array(panes)]))
    }

    static func benchmarkIndex() {
        for count in [100, 1_000] {
            let before = BaselineDesk(), after = CandidateDesk()
            let device = Device(id: "fixture", displayName: "Fixture", endpoint: .init(kind: "local", socketPath: "/tmp/unused"))
            before.devices = [device]; after.devices = [device]
            before.sessions = [device.id: snapshot(panes: count)]; after.sessions = before.sessions
            before.reindex(); after.reindex()
            func equivalent() {
                precondition(before.agents.map(\.id) == after.agents.map(\.id), "Agent order changed")
                let a = before.jumpRows.values.map { [$0.id, $0.label, $0.detail] }.sorted { $0[0] < $1[0] }
                let b = after.jumpRows.values.map { [$0.id, $0.label, $0.detail] }.sorted { $0[0] < $1[0] }
                precondition(a == b, "Search row content changed")
                for query in ["", "task", "codex", "feature", "project", "does-not-exist"] {
                    precondition(before.search.query(query) == after.search.query(query), "Search ordering changed")
                }
            }
            equivalent()
            before.publications = 0; after.publications = 0
            let old = measure(iterations: 2, samples: 3) { before.reindex() }
            let new = measure(iterations: 2, samples: 3) { after.reindex() }
            precondition(after.publications == 0, "Unchanged derived state was published")
            print(String(format: "Warm reindex (%d panes), median: %.3f ms -> %.3f ms (%.2fx); assignments %d -> %d",
                         count, old, new, old / new, before.publications, after.publications))
            before.sessions[device.id] = snapshot(panes: count, changed: true); after.sessions = before.sessions
            before.reindex(); after.reindex(); equivalent()
            before.searchActivity["pane|fixture|p11"] = 1234; after.searchActivity = before.searchActivity
            before.reindex(); after.reindex(); equivalent()
            before.branches["fixture|s0"] = "feature/ui"; after.branches = before.branches
            before.reindex(); after.reindex(); equivalent()
            // IDs only identify an object within its device; preserve that boundary.
            let second = Device(id: "other", displayName: "Other", endpoint: device.endpoint)
            before.devices = [second, device]; after.devices = before.devices
            before.sessions[second.id] = snapshot(panes: 20); after.sessions = before.sessions
            before.reindex(); after.reindex(); equivalent()
            before.sessions = [:]; after.sessions = [:]
            before.reindex(); after.reindex(); equivalent()
        }
        print("PASS: index content and order retained after status, recency, branch, device and removal changes")
    }
}
