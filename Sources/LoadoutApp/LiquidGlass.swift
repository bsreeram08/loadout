import SwiftUI

enum LiquidGlass {
    /// `true` when running on macOS 26+ from a build made with an SDK that
    /// exposes the Liquid Glass APIs.
    static var isAvailable: Bool {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) { return true }
#endif
        return false
    }
}

extension View {
    /// A floating surface: real Liquid Glass on macOS 26+, a translucent
    /// material elsewhere.
    @ViewBuilder
    func glassSurface(
        cornerRadius: CGFloat = 12,
        material: Material = .ultraThinMaterial
    ) -> some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
#else
        background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
#endif
    }

    @ViewBuilder
    func glassSurfaceProminent(
        cornerRadius: CGFloat = 12,
        material: Material = .thinMaterial
    ) -> some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
#else
        background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
#endif
    }

    @ViewBuilder
    func glassInteractiveCapsule() -> some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
#else
        background(.ultraThinMaterial, in: Capsule())
#endif
    }

    /// Tinted, interactive glass for selected/active controls; falls back to a
    /// tinted material fill.
    @ViewBuilder
    func glassTinted(_ tint: Color, cornerRadius: CGFloat) -> some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            glassEffect(.regular.tint(tint.opacity(0.55)).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
#else
        background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: cornerRadius))
#endif
    }

    /// Prominent capsule button: `.glassProminent` when available, else `.borderedProminent`.
    @ViewBuilder
    func glassProminentButton() -> some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
#else
        buttonStyle(.borderedProminent)
#endif
    }

    /// Standard capsule button: `.glass` when available, else `.bordered`.
    @ViewBuilder
    func glassButton() -> some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
#else
        buttonStyle(.bordered)
#endif
    }
}

/// Groups nearby glass elements so they blend/morph together when the build SDK
/// supports it; a transparent passthrough otherwise.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
#if compiler(>=6.2) && !LOADOUT_FORCE_LEGACY_GLASS
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
#else
        content()
#endif
    }
}

struct GlassSegmentedPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    let icon: (Option) -> String

    var body: some View {
        Picker("Section", selection: $selection) {
            ForEach(options) { option in
                Label(label(option), systemImage: icon(option))
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
