import Foundation

enum LoadoutWindowTab: String, CaseIterable, Identifiable {
    case services
    case export
    case settings
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .services: return "Services"
        case .export: return "Export"
        case .settings: return "Settings"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .services: return "server.rack"
        case .export: return "terminal"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .storage: return "Storage"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .storage: return "externaldrive"
        }
    }
}