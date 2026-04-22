import SwiftUI

struct AddonsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Hook Groups") {
                AddonToggleRow(
                    title: "Location Guard",
                    detail: "Firewall, stealth mode, AirDrop, VPN, app quitting, notifications",
                    symbol: "lock.shield",
                    isOn: $model.addonState.guardTools
                )
                AddonToggleRow(
                    title: "Wallpaper",
                    detail: "Desktop wallpaper per network location",
                    symbol: "photo",
                    isOn: $model.addonState.wallpaper
                )
                AddonToggleRow(
                    title: "Audio",
                    detail: "Output device and volume",
                    symbol: "speaker.wave.2",
                    isOn: $model.addonState.audio
                )
                AddonToggleRow(
                    title: "Display",
                    detail: "Brightness and Night Shift",
                    symbol: "display",
                    isOn: $model.addonState.display
                )
            }

            Section("VPN Profiles") {
                if model.systemStatus.vpnProfiles.isEmpty {
                    Text("None detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.systemStatus.vpnProfiles, id: \.self) { profile in
                        Label(profile, systemImage: "network.badge.shield.half.filled")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 10)
        .frame(maxWidth: 620, alignment: .leading)
        .navigationTitle("Add-ons")
    }
}

private struct AddonToggleRow: View {
    var title: String
    var detail: String
    var symbol: String
    @Binding var isOn: Bool

    var body: some View {
        LabeledContent {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
    }
}
