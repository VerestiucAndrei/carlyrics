import XCTest
@testable import Core

final class LRCTests: XCTestCase {
    func testBasicAndMultiTag() {
        let lines = LRC.parse("[ti:Song]\n[00:01.50]first\n[00:10.00][00:20.00]chorus\n\n[00:05]second")
        XCTAssertEqual(lines.map(\.t), [1.5, 5, 10, 20])
        XCTAssertEqual(lines.map(\.text), ["first", "second", "chorus", "chorus"])
    }

    func testOffsetAppliedOnceAndAnywhere() {
        let lines = LRC.parse("[00:10.00]a\n[offset:+500]\n[00:20.00]b")
        XCTAssertEqual(lines.map(\.t), [9.5, 19.5])
    }

    func testEnhancedWordTagsStrippedAndEmptyBecomesNote() {
        let lines = LRC.parse("[00:01.00]<00:01.00>hello <00:01.50>world\n[00:03.00]\n[01:02:33]x")
        XCTAssertEqual(lines.map(\.text), ["hello world", "♪", "x"])
        XCTAssertEqual(lines[2].t, 62.33, accuracy: 1e-9)
    }
}
