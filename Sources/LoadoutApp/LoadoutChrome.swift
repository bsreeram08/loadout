import AppKit
import SwiftUI

enum LoadoutChrome {
    static let contentPadding: CGFloat = 16
    static let placeholderMarkSize: CGFloat = 56
    static let headerMarkSize: CGFloat = 22
}

struct LoadoutMark: View {
    var size: CGFloat = LoadoutChrome.headerMarkSize

    var body: some View {
        Group {
            if let image = Self.brandImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: size * 0.62, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static var brandImage: NSImage? {
        if let icon = NSImage(named: "AppIcon") {
            return sized(icon, dimension: 128)
        }
        if let menuBar = MenuBarIconLabel.menuBarImage {
            return sized(menuBar, dimension: 128)
        }
        return nil
    }

    private static func sized(_ image: NSImage, dimension: CGFloat) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: dimension, height: dimension)
        return copy
    }
}

struct LoadoutWindowHeader: View {
    @Binding var tab: LoadoutWindowTab

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                LoadoutMark(size: LoadoutChrome.headerMarkSize)
                Text(LoadoutAppInfo.name)
                    .font(.headline)
                Spacer(minLength: 0)
                Text("v\(LoadoutAppInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GlassSegmentedPicker(
                options: LoadoutWindowTab.allCases,
                selection: $tab,
                label: { $0.title },
                icon: { $0.icon }
            )
        }
        .padding(.horizontal, LoadoutChrome.contentPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

struct LoadoutPlaceholderState: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            LoadoutMark(size: LoadoutChrome.placeholderMarkSize)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(LoadoutChrome.contentPadding * 2)
    }
}

struct LoadoutPanelScaffold<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(LoadoutChrome.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension MenuBarIconLabel {
    static var menuBarImage: NSImage? {
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