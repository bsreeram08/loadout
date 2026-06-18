import SwiftUI

struct LoadoutWindowView: View {
    @Bindable var model: LoadoutMenuModel
    @State private var tab: LoadoutWindowTab = .services

    var body: some View {
        VStack(spacing: 0) {
            LoadoutWindowHeader(tab: $tab)

            Divider()

            Group {
                switch tab {
                case .services:
                    ManageView(model: model)
                case .export:
                    ExportSettingsTab(model: model)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open preferences (⌘,)")
            }
        }
        .onAppear {
            tab = model.preferredWindowTab
            refreshForTab(tab)
        }
        .onChange(of: model.preferredWindowTab) { _, newTab in
            tab = newTab
        }
        .onChange(of: tab) { _, newTab in
            model.preferredWindowTab = newTab
            refreshForTab(newTab)
        }
    }

    private func refreshForTab(_ tab: LoadoutWindowTab) {
        model.refresh(includeExportPreview: tab == .export)
    }
}

struct SettingsSceneView: View {
    @Bindable var model: LoadoutMenuModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                LoadoutMark(size: LoadoutChrome.headerMarkSize)
                Text("Settings")
                    .font(.headline)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LoadoutChrome.contentPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            TabView {
                GeneralSettingsTab(model: model)
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                PathsSettingsTab(model: model)
                    .tabItem {
                        Label("Storage", systemImage: "externaldrive")
                    }
            }
            .padding(.top, 4)
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}