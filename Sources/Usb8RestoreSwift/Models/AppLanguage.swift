import Foundation

enum AppLanguage: String, Equatable, Sendable {
    case chinese
    case english

    var toggleTitle: String {
        switch self {
        case .chinese: return "EN"
        case .english: return "中文"
        }
    }

    mutating func toggle() {
        self = self == .chinese ? .english : .chinese
    }
}

func localized(_ language: AppLanguage, _ chinese: String, _ english: String) -> String {
    language == .chinese ? chinese : english
}
