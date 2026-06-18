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
}