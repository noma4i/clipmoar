@testable import ClipMoar
import XCTest

final class ClipboardRuleEngineTests: XCTestCase {
    private func apply(_ type: ClipboardTransformType, to text: String, pattern: String = "", replacement: String = "") -> String {
        let transform = ClipboardTransform(type: type, pattern: pattern, replacement: replacement)
        let rule = ClipboardRule(name: "Test", transforms: [transform])
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        return engine.apply(to: text).text
    }

    func testTrimWhitespace() {
        XCTAssertEqual(apply(.trimWhitespace, to: "  hello  \n"), "hello")
    }

    func testFlattenMultiline() {
        XCTAssertEqual(apply(.flattenMultiline, to: "curl -X POST \\\n  http://api.com"), "curl -X POST http://api.com")
    }

    func testStripShellPrompts() {
        let input = "$ git status\n$ git add ."
        let output = apply(.stripShellPrompts, to: input)
        XCTAssertEqual(output, "git status\ngit add .")
    }

    func testRemoveBoxDrawing() {
        let result = apply(.removeBoxDrawing, to: "Name \u{2502} Value")
        XCTAssertFalse(result.contains("\u{2502}"))
    }

    func testRepairWrappedURL() {
        XCTAssertEqual(apply(.repairWrappedURL, to: "https://example\n.com/path"), "https://example.com/path")
    }

    func testQuotePathsWithSpaces() {
        XCTAssertEqual(apply(.quotePathsWithSpaces, to: "/Users/me/My Documents/file.txt"), "\"/Users/me/My Documents/file.txt\"")
    }

    func testRegexReplace() {
        XCTAssertEqual(apply(.regexReplace, to: "foo123bar", pattern: "\\d+", replacement: ""), "foobar")
    }

    func testNormalizeQuotes() {
        XCTAssertEqual(apply(.normalizeQuotes, to: "\u{201C}hello\u{201D}"), "\"hello\"")
        XCTAssertEqual(apply(.normalizeQuotes, to: "\u{2018}world\u{2019}"), "'world'")
    }

    func testTabsToSpaces() {
        XCTAssertEqual(apply(.tabsToSpaces, to: "\tline"), "    line")
    }

    func testDedent() {
        XCTAssertEqual(apply(.dedent, to: "    a\n    b"), "a\nb")
    }

    func testJoinParagraphs() {
        XCTAssertEqual(apply(.joinParagraphs, to: "hello\nworld"), "hello world")
    }

    func testCollapseBlankLines() {
        XCTAssertEqual(apply(.collapseBlankLines, to: "a\n\n\n\nb"), "a\n\nb")
    }

    func testSortLines() {
        XCTAssertEqual(apply(.sortLines, to: "zebra\napple\nmoon"), "apple\nmoon\nzebra")
    }

    func testUniqueLines() {
        XCTAssertEqual(apply(.uniqueLines, to: "apple\nbanana\napple"), "apple\nbanana")
    }

    func testCommentLines() {
        XCTAssertEqual(apply(.commentLines, to: "a\nb"), "# a\n# b")
    }

    func testEscapeJSON() {
        let result = apply(.escapeJSON, to: "he said \"hi\"\nnext")
        XCTAssertTrue(result.contains("\\\""))
        XCTAssertTrue(result.contains("\\n"))
    }

    func testUnescapeJSON() {
        let result = apply(.unescapeJSON, to: "he said \\\"hi\\\"\\nnext")
        XCTAssertTrue(result.contains("\"hi\""))
        XCTAssertTrue(result.contains("\n"))
    }

    func testEscapeShell() {
        XCTAssertEqual(apply(.escapeShell, to: "My File.txt"), "'My File.txt'")
    }

    func testURLEncode() {
        let result = apply(.urlEncode, to: "hello world")
        XCTAssertTrue(result.contains("%20") || result.contains("+"))
    }

    func testURLDecode() {
        XCTAssertEqual(apply(.urlDecode, to: "hello%20world"), "hello world")
    }

    func testBase64Encode() {
        XCTAssertEqual(apply(.base64Encode, to: "hello"), "aGVsbG8=")
    }

    func testBase64Decode() {
        XCTAssertEqual(apply(.base64Decode, to: "aGVsbG8="), "hello")
        XCTAssertEqual(apply(.base64Decode, to: "  aGVsbG8=\n"), "hello")
        XCTAssertEqual(apply(.base64Decode, to: "aGVs\nbG8="), "hello")
    }

    func testPrettyJSON() {
        let result = apply(.prettyJSON, to: "{\"a\":1}")
        XCTAssertTrue(result.contains("\n"))
        XCTAssertTrue(result.contains("  "))
    }

    func testMinifyJSON() {
        let result = apply(.minifyJSON, to: "{\n  \"a\": 1\n}")
        XCTAssertFalse(result.contains("\n"))
        XCTAssertTrue(result.contains("\"a\""))
    }

    func testJSONToYAML() {
        let result = apply(.jsonToYAML, to: "{\"debug\":true}")
        XCTAssertTrue(result.contains("debug: true"))
    }

    func testHTMLToMarkdown() {
        XCTAssertEqual(apply(.htmlToMarkdown, to: "<strong>Bold</strong>"), "**Bold**")
        XCTAssertTrue(apply(.htmlToMarkdown, to: "<a href=\"#\">link</a>").contains("[link]"))
    }

    func testStripTrackingParams() {
        let result = apply(.stripTrackingParams, to: "https://site.com/page?utm_source=x&id=42")
        XCTAssertFalse(result.contains("utm_source"))
        XCTAssertTrue(result.contains("id=42"))
    }

    func testExtractURLs() {
        let result = apply(.extractURLs, to: "Visit https://example.com for info")
        XCTAssertTrue(result.contains("https://example.com"))
    }

    func testMultipleRulesApplySequentially() {
        let t1 = ClipboardTransform(type: .trimWhitespace)
        let t2 = ClipboardTransform(type: .base64Encode)
        let rule = ClipboardRule(name: "Chain", transforms: [t1, t2])
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        let result = engine.apply(to: "  hello  ")
        XCTAssertEqual(result.text, "aGVsbG8=")
    }

    func testAppBoundRuleSkipsOtherApps() {
        let transform = ClipboardTransform(type: .trimWhitespace)
        var rule = ClipboardRule(name: "iTerm only", transforms: [transform])
        rule.appBundleId = "com.googlecode.iterm2"
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        let result = engine.apply(to: "  hello  ", sourceAppBundleId: "com.apple.Safari")
        XCTAssertEqual(result.text, "  hello  ")
    }

    func testCollapseMultilineBashWithoutBackslash() {
        let input = "docker run -it\n  --name mycontainer\n  ubuntu:latest"
        let expected = "docker run -it --name mycontainer ubuntu:latest"
        XCTAssertEqual(apply(.collapseMultilineBash, to: input), expected)
    }

    func testCollapseMultilineBashWithBackslash() {
        let input = "curl -X POST \\\n  -H \"Content-Type: json\" \\\n  http://api.com"
        let expected = "curl -X POST -H \"Content-Type: json\" http://api.com"
        XCTAssertEqual(apply(.collapseMultilineBash, to: input), expected)
    }

    func testCollapseMultilineBashWithSudo() {
        let input = "sudo docker run -it\n  --name test\n  alpine"
        let expected = "sudo docker run -it --name test alpine"
        XCTAssertEqual(apply(.collapseMultilineBash, to: input), expected)
    }

    func testCollapseMultilineBashUnknownCommand() {
        let input = "foobarqux something\nanother line"
        XCTAssertEqual(apply(.collapseMultilineBash, to: input), input)
    }

    func testCollapseMultilineBashSingleLine() {
        let input = "git status"
        XCTAssertEqual(apply(.collapseMultilineBash, to: input), input)
    }

    func testCollapseMultilineBashPlainText() {
        let input = "Hello world\nThis is just text"
        XCTAssertEqual(apply(.collapseMultilineBash, to: input), input)
    }

    func testAppBoundRuleAppliesForMatchingApp() {
        let transform = ClipboardTransform(type: .trimWhitespace)
        var rule = ClipboardRule(name: "iTerm only", transforms: [transform])
        rule.appBundleId = "com.googlecode.iterm2"
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        let result = engine.apply(to: "  hello  ", sourceAppBundleId: "com.googlecode.iterm2")
        XCTAssertEqual(result.text, "hello")
    }

    // MARK: - Smart Join Lines

    func testSmartJoinPlainLines() {
        let input = "This is a long\nparagraph that was\nwrapped."
        let expected = "This is a long paragraph that was wrapped."
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesBlankLineSeparators() {
        let input = "First paragraph\nstill first.\n\nSecond paragraph\nstill second."
        let expected = "First paragraph still first.\n\nSecond paragraph still second."
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesBulletList() {
        let input = "Some text\n- item one\n- item two\n- item three"
        let expected = "Some text\n- item one\n- item two\n- item three"
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesNumberedList() {
        let input = "Header:\n1. first\n2. second\n3. third"
        let expected = "Header:\n1. first\n2. second\n3. third"
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesCodeFence() {
        let input = "Text before\n```\nlet x = 1\n```\nText after"
        let expected = "Text before\n```\nlet x = 1\n```\nText after"
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesIndentedCode() {
        let input = "Description:\n    let x = 1\n    let y = 2"
        let expected = "Description:\n    let x = 1\n    let y = 2"
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesTable() {
        let input = "Table:\n| A | B |\n| 1 | 2 |"
        let expected = "Table:\n| A | B |\n| 1 | 2 |"
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesHeadings() {
        let input = "# Heading\nSome text\nthat wraps."
        let expected = "# Heading\nSome text that wraps."
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesBlockquotes() {
        let input = "> quote line\nText after\nwrapped."
        let expected = "> quote line\nText after wrapped."
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinTerminalOutputSmallIndent() {
        let input = "  Понял - пресет должен быть привязан к\n  правилу как ссылка (выбирается через\n  Picker), а"
        let expected = "Понял - пресет должен быть привязан к правилу как ссылка (выбирается через Picker), а"
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }

    func testSmartJoinPreservesDeepIndentedLines() {
        let input = "    line one\n    line two\n    line three"
        XCTAssertEqual(apply(.smartJoinLines, to: input), input)
    }

    // MARK: - Preset integration

    func testRuleWithPresetAppliesPresetTransforms() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let presetStore = PresetStore(defaults: defaults)
        let preset = try XCTUnwrap(presetStore.presets.first { $0.name == "Claude Code" })

        var rule = ClipboardRule(name: "Test", presetId: preset.id.uuidString)
        rule.transforms = []
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]), presetStore: presetStore)
        let input = "  hello  \n\n\n\nworld  "
        let result = engine.apply(to: input)
        XCTAssertNotEqual(result.text, input, "Preset transforms must modify text")
    }

    func testRuleWithPresetAndAppBundleAppliesWhenMatching() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let presetStore = PresetStore(defaults: defaults)
        let preset = try XCTUnwrap(presetStore.presets.first { $0.name == "Claude Code" })

        var rule = ClipboardRule(name: "iTerm", appBundleId: "com.googlecode.iterm2", presetId: preset.id.uuidString)
        rule.transforms = []
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]), presetStore: presetStore)

        let input = "  hello  \n\n\n\nworld  "
        let withApp = engine.apply(to: input, sourceAppBundleId: "com.googlecode.iterm2")
        XCTAssertNotEqual(withApp.text, input, "Must apply when bundleId matches")

        let withoutApp = engine.apply(to: input, sourceAppBundleId: nil)
        XCTAssertEqual(withoutApp.text, input, "Must skip when bundleId is nil")

        let wrongApp = engine.apply(to: input, sourceAppBundleId: "com.apple.Safari")
        XCTAssertEqual(wrongApp.text, input, "Must skip when bundleId doesn't match")
    }

    func testRuleWithoutPresetAppliesOnlyTransforms() {
        let rule = ClipboardRule(name: "Test", transforms: [ClipboardTransform(type: .trimWhitespace)])
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        XCTAssertEqual(engine.apply(to: "  hello  ").text, "hello")
    }

    func testPresetStoreReloadsOnApply() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let presetStore = PresetStore(defaults: defaults)
        let preset = try XCTUnwrap(presetStore.presets.first { $0.name == "Claude Code" })

        var rule = ClipboardRule(name: "Test", presetId: preset.id.uuidString)
        rule.transforms = []
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]), presetStore: presetStore)

        let idx = try XCTUnwrap(presetStore.presets.firstIndex(where: { $0.id == preset.id }))
        presetStore.presets[idx].transformTypes = [.base64Encode]
        presetStore.save()

        let staleStore = PresetStore(defaults: defaults)
        let engine2 = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]), presetStore: staleStore)
        let result = engine2.apply(to: "hello")
        XCTAssertEqual(result.text, "aGVsbG8=", "apply() must reload presets and see base64Encode")
    }

    func testSmartJoinPreservesCodeLines() {
        let input = "Text that wraps\nacross lines.\n    func foo() {\n    }\nMore text\nthat wraps."
        let expected = "Text that wraps across lines.\n    func foo() {\n    }\nMore text that wraps."
        XCTAssertEqual(apply(.smartJoinLines, to: input), expected)
    }
}
