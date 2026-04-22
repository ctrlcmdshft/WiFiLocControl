import SwiftUI

struct AddonsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderView(title: "Add-ons", subtitle: "Enable or disable add-on hooks by group.")

            GroupBox("Hook Groups") {
                VStack(spacing: 14) {
                    AddonToggleRow(
                        title: "Location Guard",
                        detail: "Firewall, stealth mode, AirDrop, VPN trigger, app quitting, notifications",
                        symbol: "lock.shield",
                        isOn: $model.addonState.guardTools
                    )
                    AddonToggleRow(
                        title: "Wallpaper",
                        detail: "Switch desktop wallpaper per network location",
                        symbol: "photo",
                        isOn: $model.addonState.wallpaper
                    )
                    AddonToggleRow(
                        title: "Audio",
                        detail: "Switch output device and volume",
                        symbol: "speaker.wave.2",
                        isOn: $model.addonState.audio
                    )
                    AddonToggleRow(
                        title: "Display",
                        detail: "Set brightness and Night Shift",
                        symbol: "display",
                        isOn: $model.addonState.display
                    )
                }
                .padding(.vertical, 4)
            }

            GroupBox("VPN") {
                VStack(alignment: .leading, spacing: 10) {
                    if model.systemStatus.vpnProfiles.isEmpty {
                        Text("No VPN profiles were detected from System Settings.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.systemStatus.vpnProfiles, id: \.self) { profile in
                            Label(profile, systemImage: "network.badge.shield.half.filled")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            HStack {
                Text(model.message)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { model.refresh() }
                Button("Save Hooks") { model.save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

private struct AddonToggleRow: View {
    var title: String
    var detail: String
    var symbol: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
    }
}
