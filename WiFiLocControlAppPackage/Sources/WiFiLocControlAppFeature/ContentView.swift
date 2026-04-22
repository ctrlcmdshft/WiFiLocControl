import SwiftUI

public struct ContentView: View {
    @State private var model = AppModel()
    @State private var selection: AppSection? = .overview

    public init() {}

    public var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview:
                    OverviewView(model: model)
                case .locations:
                    LocationsView(model: model)
                case .addons:
                    AddonsView(model: model)
                case .logs:
                    LogsView(model: model)
                }
            }
            .frame(minWidth: 860, minHeight: 620)
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case locations
    case addons
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .locations: "Locations"
        case .addons: "Add-ons"
        case .logs: "Logs"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "network"
        case .locations: "location"
        case .addons: "puzzlepiece.extension"
        case .logs: "doc.text.magnifyingglass"
        }
    }
}
