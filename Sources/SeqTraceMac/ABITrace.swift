import Foundation

struct ABITrace: Sendable, Equatable {
    var fileName: String
    var samplesA: [UInt16]
    var samplesC: [UInt16]
    var samplesG: [UInt16]
    var samplesT: [UInt16]

    var bases: String?
    var peakLocations: [Int]?
    var qualities: [UInt8]?

    var sampleCount: Int {
        min(samplesA.count, samplesC.count, samplesG.count, samplesT.count)
    }
}

