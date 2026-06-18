import SwiftUI

enum LiquidGlass {
    /// Reserved for a future macOS 26+ glass build lane when CI ships that SDK.
    static var isAvailable: Bool { false }
}

extension View {
    @ViewBuilder
    func glassSurface(
        cornerRadius: CGFloat = 12,
        material: Material = .ultraThinMaterial
    ) -> some View {
        background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func glassSurfaceProminent(
        cornerRadius: CGFloat = 12,
        material: Material = .thinMaterial
    ) -> some View {
        background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func glassInteractiveCapsule() -> some View {
        background(.ultraThinMaterial, in: Capsule())
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