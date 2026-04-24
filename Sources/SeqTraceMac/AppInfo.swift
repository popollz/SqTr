import Foundation

/// Release metadata. Update `marketingVersion` and `build` for each drop.
enum AppInfo {
    /// Menu bar, About window, and Finder display name.
    static let name = "Swift SeqTrace"

    /// User-visible version (e.g. 0.1.0).
    static let marketingVersion = "0.1.2"

    /// Increment per release (shown in About as the build).
    static let build = "2"

    /// Short product description (About panel, docs).
    static let marketingDescription =
        "A native, Swift-based sequence trace editor for fast and reliable DNA data analysis. Inspired by the classic SeqTrace project (https://github.com/stuckyb/seqtrace)."

    /// Feedback email for testers.
    static let feedbackContact = "yulandi80@gmail.com"
}
