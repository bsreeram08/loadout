import SwiftUI

enum LiquidGlass {
    static var isAvailable: Bool {
        if #available(macOS 26, *) {
            return true
        }
        return false
    }
}

extension View {
    @ViewBuilder
    func glassSurface(
        cornerRadius: CGFloat = 12,
        material: Material = .ultraThinMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func glassSurfaceProminent(
        cornerRadius: CGFloat = 12,
        material: Material = .thinMaterial
    ) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(.accentColor.opacity(0.15)), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func glassInteractiveCapsule() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
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

struct GlassIconBadge: View {
    let systemImage: String
    var size: CGFloat = 72

    var body: some View {
        if #available(macOS 26, *) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .glassEffect(.regular, in: .circle)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

struct GlassCodePanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassSurface(cornerRadius: 10)
    }
}