import Foundation

/// Maps BCP 47 language codes to provider-specific codes.
/// Each dictionary only lists codes that differ from BCP 47; unlisted codes pass through as-is.
enum LanguageCodeMapping {
    // MARK: - Google Translate

    static let google: [String: String] = [
        "zh-Hans": "zh-CN", "zh-Hant": "zh-TW", "pt-BR": "pt",
    ]

    // MARK: - Resolve

    /// Resolve an optional BCP 47 code using the given mapping. Returns `nil` if input is `nil`.
    static func resolve(_ bcp47: String?, using mapping: [String: String]) -> String? {
        guard let code = bcp47 else { return nil }
        return mapping[code] ?? code
    }

    /// Resolve a BCP 47 target code using the given mapping.
    static func resolveTarget(_ bcp47: String, using mapping: [String: String]) -> String {
        mapping[bcp47] ?? bcp47
    }

}
