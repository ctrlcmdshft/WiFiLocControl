import SwiftUI

struct OverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderView(title: "WiFiLocControl", subtitle: model.message)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    StatusItem(title: "Current Wi-Fi", value: model.systemStatus.currentWiFi.isEmpty ? "Unavailable" : model.systemStatus.currentWiFi)
                    StatusItem(title: "Network Location", value: model.systemStatus.currentLocation.isEmpty ? "Unknown" : model.systemStatus.currentLocation)
                }
                GridRow {
                    StatusItem(title: "Core Script", value: model.systemStatus.coreInstalled ? "Installed" : "Missing", ok: model.systemStatus.coreInstalled)
                    StatusItem(title: "LaunchAgent", value: model.systemStatus.launchAgentLoaded ? "Loaded" : "Not loaded", ok: model.systemStatus.launchAgentLoaded)
                }
            }

            GroupBox("Service") {
                HStack(spacing: 12) {
                    Button {
                        model.installCore()
                    } label: {
                        Label("Install or Repair", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.save()
                    } label: {
                        Label("Save Configuration", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        model.runNow()
                    } label: {
                        Label("Run Check Now", systemImage: "play")
                    }
                    .disabled(!model.systemStatus.coreInstalled)

                    Button {
                        model.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        model.openConfigFolder()
                    } label: {
                        Label("Open Config", systemImage: "folder")
                    }
                }
                .controlSize(.large)
                .padding(.vertical, 4)
            }

            GroupBox("Optional Tools") {
                VStack(alignment: .leading, spacing: 10) {
                    ToolRow(name: "SwitchAudioSource", installed: model.systemStatus.switchAudioInstalled, detail: "Audio output switching")
                    ToolRow(name: "brightness", installed: model.systemStatus.brightnessInstalled, detail: "Display brightness control")
                    ToolRow(name: "terminal-notifier", installed: model.systemStatus.terminalNotifierInstalled, detail: "Switch notifications")

                    Button {
                        model.installOptionalTools()
                    } label: {
                        Label("Install Missing Homebrew Tools", systemImage: "shippingbox")
                    }
                    .disabled(model.isBusy)
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(24)
        .toolbar {
            ProgressView()
                .opacity(model.isBusy ? 1 : 0)
        }
    }
}

struct HeaderView: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusItem: View {
    var title: String
    var value: String
    var ok: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if let ok {
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ok ? .green : .orange)
                }
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ToolRow: View {
    var name: String
    var installed: Bool
    var detail: String

    var body: some View {
        HStack {
            Image(systemName: installed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(installed ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(name)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(installed ? "Installed" : "Missing")
                .foregroundStyle(installed ? .green : .secondary)
        }
    }
}
