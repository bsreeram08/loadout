import AppKit
import SwiftUI

enum LoadoutChrome {
    static let contentPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let placeholderMarkSize: CGFloat = 56
    static let headerMarkSize: CGFloat = 22
    static let sidebarMinWidth: CGFloat = 160
    static let sidebarIdealWidth: CGFloat = 180
    static let sidebarMaxWidth: CGFloat = 220
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

struct LoadoutTabActions {
    var addTitle: String?
    var onAdd: (() -> Void)?
    var onRefresh: (() -> Void)?
}

struct LoadoutTabHeader: View {
    let title: String
    var subtitle: String?
    var actions: LoadoutTabActions?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let actions {
                HStack(spacing: 8) {
                    if let onRefresh = actions.onRefresh {
                        Button(action: onRefresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Refresh")
                    }
                    if let addTitle = actions.addTitle, let onAdd = actions.onAdd {
                        Button(action: onAdd) {
                            Label(addTitle, systemImage: "plus")
                        }
                    }
                }
                .buttonStyle(.borderless)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, LoadoutChrome.contentPadding)
        .padding(.vertical, 12)
    }
}

struct LoadoutTabContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(LoadoutChrome.contentPadding)
    }
}

struct LoadoutGroupedForm<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LoadoutChrome.cardSpacing, content: content)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct LoadoutTabLayout<Sidebar: View, Detail: View>: View {
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        HStack(alignment: .top, spacing: LoadoutChrome.cardSpacing) {
            LoadoutCard(padding: 8) {
                sidebar()
            }
            .frame(
                minWidth: LoadoutChrome.sidebarMinWidth,
                idealWidth: LoadoutChrome.sidebarIdealWidth,
                maxWidth: LoadoutChrome.sidebarMaxWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )

            detail()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(LoadoutChrome.contentPadding)
    }
}

/// Full-width tab: header, divider, then either split or single content.
struct LoadoutTabShell<Content: View>: View {
    let title: String
    var subtitle: String?
    var actions: LoadoutTabActions?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            LoadoutTabHeader(title: title, subtitle: subtitle, actions: actions)
            Divider()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct LoadoutSplitTabShell<Sidebar: View, Detail: View>: View {
    let title: String
    var subtitle: String?
    var actions: LoadoutTabActions?
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        LoadoutTabShell(title: title, subtitle: subtitle, actions: actions) {
            LoadoutTabLayout(sidebar: sidebar, detail: detail)
        }
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

struct LoadoutCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .glassSurface(cornerRadius: 12)
    }
}

struct LoadoutCardSection<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        LoadoutCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                content()
            }
        }
    }
}

struct LoadoutRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 10, content: content)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LoadoutActionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isDisabled ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isDisabled ? .green : .secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(isDisabled ? 0.14 : 0.28), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.72 : 1)
    }
}

struct LoadoutCodePanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassSurface(cornerRadius: 10)
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
