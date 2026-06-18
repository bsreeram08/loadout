import Foundation

enum LoadoutWindowTab: String, CaseIterable, Identifiable {
    case services
    case export
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .services: return "Services"
        case .export: return "Export"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .services: return "server.rack"
        case .export: return "terminal"
        case .about: return "info.circle"
        }
    }
}