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

struct GlassCodePanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassSurface(cornerRadius: 10)
    }
}