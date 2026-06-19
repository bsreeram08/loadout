import SwiftUI

@MainActor
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
                case .settings:
                    SettingsTabView(model: model)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 480)
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
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