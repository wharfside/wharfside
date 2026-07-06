// Views/Sidebar.swift

import SwiftUI

private enum SidebarMetrics {
    static let width: CGFloat = 160
}

struct Sidebar: View {
    @Binding var selection: NavigationSection

    var body: some View {
        List(NavigationSection.allCases, selection: $selection) { section in
            NavigationLink(value: section) {
                Label(section.rawValue, systemImage: section.systemImage)
            }
        }
        .navigationSplitViewColumnWidth(SidebarMetrics.width)
        .listStyle(.sidebar)
    }
}

// Views/Shared/PlaceholderView.swift

/// Empty-state placeholder used until each section's real view lands.
struct PlaceholderView: View {
    let section: NavigationSection
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(section.rawValue, systemImage: section.systemImage)
        } description: {
            Text(message)
        }
    }
}

// Views/Settings/SettingsPlaceholderView.swift

struct SettingsPlaceholderView: View {
    var body: some View {
        Form {
            Text("Settings arrive with the preferences service.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 180)
    }
}

#Preview {
    Sidebar(selection: .constant(.containers))
        .frame(width: SidebarMetrics.width, height: 400)
}
