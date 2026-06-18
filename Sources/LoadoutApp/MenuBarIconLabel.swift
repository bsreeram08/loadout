import AppKit
import SwiftUI

struct MenuBarIconLabel: View {
    var showsProdWarning = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            icon
            if showsProdWarning {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: -3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(showsProdWarning ? "Loadout, prod selected" : "Loadout")
    }

    @ViewBuilder
    private var icon: some View {
        if let image = Self.menuBarImage {
            Image(nsImage: image)
        } else {
            Image(systemName: "slider.horizontal.3")
        }
    }

    private static var menuBarImage: NSImage? {
        let image = NSImage(named: "MenuBarIcon")
            ?? bundleImage(named: "MenuBarIcon", scale: 2)
            ?? bundleImage(named: "MenuBarIcon", scale: 1)
        image?.isTemplate = true
        return image
    }

    private static func bundleImage(named name: String, scale: Int) -> NSImage? {
        let suffix = scale > 1 ? "@2x" : ""
        guard let url = Bundle.main.url(forResource: "\(name)\(suffix)", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}