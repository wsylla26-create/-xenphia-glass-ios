import Foundation

enum VoiceLanguage: String, CaseIterable, Identifiable {
    case english = "en-US", spanish = "es-ES", french = "fr-FR", italian = "it-IT"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .italian: return "Italiano"
        }
    }
    var greeting: String {
        switch self {
        case .english: return "Welcome. How can I help you?"
        case .spanish: return "Bienvenido. ¿Cómo puedo ayudarte?"
        case .french: return "Bienvenue. Comment puis-je vous aider ?"
        case .italian: return "Benvenuto. Come posso aiutarti?"
        }
    }
    func opening(_ label: String) -> String {
        switch self {
        case .english: return "Opening \(label)."
        case .spanish: return "Abriendo \(label)."
        case .french: return "J’ouvre \(label)."
        case .italian: return "Apro \(label)."
        }
    }
}
