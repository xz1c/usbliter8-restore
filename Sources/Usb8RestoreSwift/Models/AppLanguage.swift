import Foundation

enum AppLanguage: String, Equatable, Sendable {
    case russian
    case english
    case chinese

    var toggleTitle: String {
        switch self {
        case .russian: return "EN"
        case .english: return "中文"
        case .chinese: return "RU"
        }
    }

    mutating func toggle() {
        switch self {
        case .russian:
            self = .english
        case .english:
            self = .chinese
        case .chinese:
            self = .russian
        }
    }
}

func localized(
    _ language: AppLanguage,
    _ chinese: String,
    _ english: String,
    _ russian: String
) -> String {
    switch language {
    case .russian: return russian
    case .english: return english
    case .chinese: return chinese
    }
}
