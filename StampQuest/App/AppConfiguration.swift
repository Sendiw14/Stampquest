import Foundation

/// Release-time values that must be supplied by the app's owner. Rows that depend on a
/// value are hidden while it is nil, so the app never shows a dead link.
enum AppConfiguration {
    /// Where "Send feedback" should go. Set before release.
    static let supportEmail: String? = nil
    /// A hosted privacy policy. App Store Connect requires one.
    // TODO(owner): replace both placeholders with the real hosted pages before release. The Plus paywall's Terms and Privacy
    // links need them and fail a debug assert (and a test) if they are ever nil.
    static let privacyPolicyURL: URL? = URL(string: "https://example.com/stampquest/privacy")
    static let termsURL: URL? = URL(string: "https://example.com/stampquest/terms")

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
