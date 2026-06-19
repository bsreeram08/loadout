import AppKit
import LoadoutCore
import SwiftUI

@MainActor
struct LoadoutMenuView: View {
    @Bindable var model: LoadoutMenuModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if model.hasProdSelected {
                prodBanner
            }

            content

            Divider()
            footer
        }
        .frame(width: 296)
        .onAppear { model.refreshIfStale() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            LoadoutMark(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(LoadoutAppInfo.name)
                    .font(.system(size: 14, weight: .bold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var headerSubtitle: String {
        guard let summary = model.context?.summary else { return "Loading…" }
        let services = summary.selectedServiceCount
        let vars = summary.selectedVariableCount
        if services == 0 {
            let stored = model.context?.registry.count ?? 0
            return "\(stored) stored · none active"
        }
        let vNoun = vars == 1 ? "variable" : "variables"
        return "\(services) active · \(vars) \(vNoun)"
    }

    private var prodBanner: some View {
        Label(
            model.sensitiveActiveService.map { "prod variant active — \($0)" } ?? "prod variant active",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let error = model.context?.errorMessage {
            stateText("Keychain error — unlock and retry", help: error)
            MenuActionRow(title: "Retry loading…", systemImage: "arrow.clockwise") {
                model.refresh(force: true)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        } else if model.context == nil {
            if model.isRefreshing {
                stateText("Loading services…")
            } else {
                MenuActionRow(title: "Retry loading…", systemImage: "arrow.clockwise") {
                    model.refresh(force: true)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        } else if model.context?.registry.isEmpty == true {
            stateText("No services stored yet")
            MenuActionRow(title: "Add service…", systemImage: "plus") {
                openMainWindow(tab: .services)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        } else {
            activeSection
        }
    }

    @ViewBuilder
    private var activeSection: some View {
        let active = model.activeMenuEntries()
        VStack(alignment: .leading, spacing: 1) {
            sectionHeader("Active")
            if active.isEmpty {
                Text("No services active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(active) { item in
                            ActiveServiceRow(item: item, model: model)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Divider().padding(.vertical, 5)

            MenuActionRow(title: "Manage services…", systemImage: "slider.horizontal.3") {
                openMainWindow(tab: .services)
            }
            MenuActionRow(title: "Settings…", systemImage: "gearshape") {
                openMainWindow(tab: .settings)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }

    private var footer: some View {
        HStack {
            Text(footerLine)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var footerLine: String {
        let stored = model.context?.registry.count ?? 0
        let noun = stored == 1 ? "service" : "services"
        return "\(stored) \(noun) stored"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
    }

    private func stateText(_ text: String, help: String? = nil) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .help(help ?? "")
    }

    private func openMainWindow(tab: LoadoutWindowTab) {
        model.preferredWindowTab = tab
        openWindow(id: "loadout")
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Active service row (with variant switcher)

private struct ActiveServiceRow: View {
    let item: ActiveMenuEntry
    let model: LoadoutMenuModel
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            StatusDot(isActive: true)
            Text(item.service)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            variantMenu
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            isHovering ? Color.secondary.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var variantMenu: some View {
        if let entry = item.entry {
            Menu {
                ForEach(entry.variants, id: \.self) { variant in
                    Button {
                        model.select(service: entry.service, variant: variant)
                    } label: {
                        let count = entry.variableCounts[variant] ?? 0
                        if variant == item.variant {
                            Label("\(variant) (\(count) vars)", systemImage: "checkmark")
                        } else {
                            Text("\(variant) (\(count) vars)")
                        }
                    }
                }
                Divider()
                Button("Turn off") { model.deselect(service: entry.service) }
            } label: {
                VariantPill(variant: variantLabel)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            Menu {
                Button("Turn off") { model.deselect(service: item.service) }
            } label: {
                VariantPill(variant: "\(item.variant) ⚠")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var variantLabel: String {
        guard let entry = item.entry else { return item.variant }
        return entry.variants.contains(item.variant) ? item.variant : "\(item.variant) ⚠"
    }
}

// MARK: - Plain full-width menu action row

private struct MenuActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovering ? Color.accentColor.opacity(0.9) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .foregroundStyle(isHovering ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
