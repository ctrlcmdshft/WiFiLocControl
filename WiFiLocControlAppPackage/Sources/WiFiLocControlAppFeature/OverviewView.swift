import SwiftUI

struct OverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Current Wi-Fi", value: model.systemStatus.currentWiFi.isEmpty ? "Unavailable" : model.systemStatus.currentWiFi)
                LabeledContent("Network Location", value: model.systemStatus.currentLocation.isEmpty ? "Unknown" : model.systemStatus.currentLocation)
                StatusRow("Core Script", isOK: model.systemStatus.coreInstalled, okText: "Installed", missingText: "Missing")
                StatusRow("LaunchAgent", isOK: model.systemStatus.launchAgentLoaded, okText: "Loaded", missingText: "Not Loaded")
            }

            Section("Service") {
                HStack {
                    Button {
                        model.installCore()
                    } label: {
                        Label("Install or Repair", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.runNow()
                    } label: {
                        Label("Run Check Now", systemImage: "play")
                    }
                    .disabled(!model.systemStatus.coreInstalled)

                    Button {
                        model.openConfigFolder()
                    } label: {
                        Label("Open Config", systemImage: "folder")
                    }
                }
            }

            Section("Optional Tools") {
                ToolRow(name: "SwitchAudioSource", installed: model.systemStatus.switchAudioInstalled, detail: "Audio output")
                ToolRow(name: "brightness", installed: model.systemStatus.brightnessInstalled, detail: "Display brightness")
                ToolRow(name: "terminal-notifier", installed: model.systemStatus.terminalNotifierInstalled, detail: "Notifications")

                Button {
                    model.installOptionalTools()
                } label: {
                    Label("Install Missing Tools", systemImage: "shippingbox")
                }
                .disabled(model.isBusy)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 10)
        .frame(maxWidth: 620, alignment: .leading)
        .navigationTitle("Overview")
    }
}

private struct StatusRow: View {
    var title: String
    var isOK: Bool
    var okText: String
    var missingText: String

    init(_ title: String, isOK: Bool, okText: String, missingText: String) {
        self.title = title
        self.isOK = isOK
        self.okText = okText
        self.missingText = missingText
    }

    var body: some View {
        LabeledContent(title) {
            Label(isOK ? okText : missingText, systemImage: isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isOK ? .green : .orange)
        }
    }
}

private struct ToolRow: View {
    var name: String
    var installed: Bool
    var detail: String

    var body: some View {
        LabeledContent {
            Text(installed ? "Installed" : "Missing")
                .foregroundStyle(installed ? .primary : .secondary)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: installed ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(installed ? .green : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
