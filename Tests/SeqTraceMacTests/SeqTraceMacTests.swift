import Testing
@testable import SeqTraceMac

@Suite("ABITraceReader.parseFWO")
struct ParseFWOTests {
    @Test("classic ACGT order")
    func parsesClassicOrder() {
        #expect(ABITraceReader.parseFWO("ACGT") == ["A", "C", "G", "T"])
    }

    @Test("non-standard GATC order (the common case FWO_1 exists to cover)")
    func parsesGATCOrder() {
        #expect(ABITraceReader.parseFWO("GATC") == ["G", "A", "T", "C"])
    }

    @Test("another non-standard order, TGCA")
    func parsesTGCAOrder() {
        #expect(ABITraceReader.parseFWO("TGCA") == ["T", "G", "C", "A"])
    }

    @Test("strips leading and trailing whitespace and newlines")
    func trimsSurroundingWhitespace() {
        #expect(ABITraceReader.parseFWO("  ACGT\n") == ["A", "C", "G", "T"])
        #expect(ABITraceReader.parseFWO("\tGATC  ") == ["G", "A", "T", "C"])
    }

    @Test("filters out non-ACGT characters inside the string")
    func filtersInteriorNoise() {
        #expect(ABITraceReader.parseFWO("A-C-G-T") == ["A", "C", "G", "T"])
        #expect(ABITraceReader.parseFWO("A C G T") == ["A", "C", "G", "T"])
    }

    @Test("returns nil for empty or whitespace-only input")
    func emptyInputReturnsNil() {
        #expect(ABITraceReader.parseFWO("") == nil)
        #expect(ABITraceReader.parseFWO("   ") == nil)
    }

    @Test("returns nil when fewer than 4 valid bases are present")
    func tooFewReturnsNil() {
        #expect(ABITraceReader.parseFWO("A") == nil)
        #expect(ABITraceReader.parseFWO("ACG") == nil)
        #expect(ABITraceReader.parseFWO("xyz") == nil)
    }

    @Test("returns nil when more than 4 valid bases remain after filtering")
    func tooManyReturnsNil() {
        #expect(ABITraceReader.parseFWO("ACGTA") == nil)
        #expect(ABITraceReader.parseFWO("AACCGGTT") == nil)
    }

    @Test("current behavior: input is case-sensitive; lowercase is rejected")
    func lowercaseIsRejected() {
        #expect(ABITraceReader.parseFWO("acgt") == nil)
    }
}
