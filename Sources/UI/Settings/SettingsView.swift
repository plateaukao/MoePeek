import Defaults
import SwiftUI

struct SettingsView: View {
    let registry: TranslationProviderRegistry

    @Default(.selectedSettingsTab) private var selectedTab

    private var tabHeight: CGFloat {
        switch selectedTab {
        case .general: return 680
        case .actions: return 560
        case .excludedApps: return 480
        case .services: return 580
        case .providerOrder: return 520
        case .about: return 420
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            ActionsSettingsView()
                .tabItem {
                    Label("Actions", systemImage: "sparkles")
                }
                .tag(SettingsTab.actions)

            ExcludedAppsSettingsView()
                .tabItem {
                    Label("Excluded Apps", systemImage: "xmark.app")
                }
                .tag(SettingsTab.excludedApps)

            ServiceSettingsView(registry: registry)
                .tabItem {
                    Label("Services", systemImage: "globe")
                }
                .tag(SettingsTab.services)

            ProviderOrderSettingsView(registry: registry)
                .tabItem {
                    Label("Order", systemImage: "list.number")
                }
                .tag(SettingsTab.providerOrder)

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 820, idealWidth: 820, minHeight: tabHeight, idealHeight: tabHeight)
    }
}
