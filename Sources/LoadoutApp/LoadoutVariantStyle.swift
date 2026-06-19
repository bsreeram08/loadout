import SwiftUI

/// Color semantics for variants. The whole point of Loadout is knowing *which*
/// variant is active at a glance — so `prod` always reads as dangerous (red),
/// `test` as safe (blue), and so on, consistently across the sidebar, the
/// variant selector, and the menu bar.
enum LoadoutVariantStyle {
    static func color(for variant: String) -> Color {
        switch normalized(variant) {
        case "prod", "production", "live": return .red
        case "test", "testing", "sandbox", "qa": return .blue
        case "beta", "preview": return .purple
        case "stage", "staging", "uat": return .orange
        case "dev", "development", "local": return .teal
        default: return .accentColor
        }
    }

    /// `true` for variants that warrant a "double-check before exporting" warning.
    static func isSensitive(_ variant: String) -> Bool {
        switch normalized(variant) {
        case "prod", "production", "live": return true
        default: return false
        }
    }

    private static func normalized(_ variant: String) -> String {
        variant.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

/// Small colored capsule showing a variant name (or "off").
struct VariantPill: View {
    let variant: String?
    var compact = false

    var body: some View {
        let text = variant ?? "off"
        let color = variant.map(LoadoutVariantStyle.color(for:)) ?? Color.secondary
        Text(text)
            .font(.system(size: compact ? 10 : 10.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 7 : 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 0.5))
            .lineLimit(1)
    }
}

/// Filled green dot when a service is in the active set; a hollow ring otherwise.
struct StatusDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.clear)
            .overlay(
                Circle().strokeBorder(
                    isActive ? Color.green.opacity(0.0) : Color.secondary.opacity(0.55),
                    lineWidth: 1.5
                )
            )
            .frame(width: 7, height: 7)
            .shadow(color: isActive ? Color.green.opacity(0.35) : .clear, radius: 2)
    }
}
