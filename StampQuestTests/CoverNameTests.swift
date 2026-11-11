import Testing
import Foundation
@testable import StampQuest

struct CoverNameTests {
    @Test func sizeRuleMatchesTheSpecValues() {
        #expect(CoverName.sizeUnits(characterCount: 0) == 6.6)
        #expect(CoverName.sizeUnits(characterCount: 5) == 6.6)
        #expect(CoverName.sizeUnits(characterCount: 14) == 6.6)
        #expect(abs(CoverName.sizeUnits(characterCount: 15) - 6.16) < 0.001)
        #expect(abs(CoverName.sizeUnits(characterCount: 24) - 3.85) < 0.001)
        #expect(CoverName.sizeUnits(characterCount: 100) == 3.8, "never below 3.8")
    }

    @Test func whitespaceRunsCollapseAndLeadingSpaceIsDropped() {
        #expect(CoverName.sanitizeWhileTyping("   Alex    Rivera") == "Alex Rivera")
        #expect(CoverName.sanitizeWhileTyping("Alex \n\t Rivera") == "Alex Rivera")
        #expect(CoverName.sanitizeWhileTyping("Alex ") == "Alex ", "a trailing space is kept while typing")
        #expect(CoverName.committed("  Alex   Rivera  ") == "Alex Rivera")
    }

    @Test func aNameOfOnlySpacesIsEmpty() {
        #expect(CoverName.committed("      ") == "")
        #expect(CoverName.sanitizeWhileTyping("      ") == "")
    }

    @Test func theCapIsTwentyFourGraphemeClusters() {
        let long = String(repeating: "a", count: 40)
        #expect(CoverName.sanitizeWhileTyping(long).count == 24)
        let emoji = String(repeating: "👩🏽‍🚀", count: 30)
        #expect(CoverName.sanitizeWhileTyping(emoji).count == 24, "a cluster is never split")
        let accents = String(repeating: "é", count: 30)
        #expect(CoverName.sanitizeWhileTyping(accents).count == 24)
        #expect(CoverName.committed(String(repeating: "x", count: 23) + "  y").count <= 24)
    }

    @Test func wideCharactersKeepTheLimit() {
        #expect(CoverName.sanitizeWhileTyping(String(repeating: "漢", count: 40)).count == 24)
    }
}
