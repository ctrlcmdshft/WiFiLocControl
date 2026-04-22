import AppKit
import SwiftUI

struct LocationsView: View {
    @Bindable var model: AppModel
    @State private var selectedLocation = ""

    private var locationSelection: Binding<String> {
        Binding {
            if selectedLocation.isEmpty {
                model.profiles.first?.name ?? ""
            } else {
                selectedLocation
            }
        } set: { newValue in
            selectedLocation = newValue
        }
    }

    private var selectedProfileBinding: Binding<LocationProfile>? {
        let location = locationSelection.wrappedValue
        guard let index = model.profiles.firstIndex(where: { $0.name == location }) else {
            return nil
        }
        return $model.profiles[index]
    }

    var body: some View {
        Form {
            Section {
                Picker("Network Location", selection: locationSelection) {
                    ForEach(model.profiles.map(\.name), id: \.self) { location in
                        Text(location).tag(location)
                    }
                }
                Text("Settings below apply when WiFiLocControl switches to this macOS network location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Location")
            }

            AliasSection(model: model)

            if let profile = selectedProfileBinding {
                GuardSection(profile: profile, vpnProfiles: model.systemStatus.vpnProfiles)
                WallpaperSection(profile: profile)
                AudioSection(profile: profile)
                DisplaySection(profile: profile)
            } else {
                Section {
                    ContentUnavailableView(
                        "No Locations",
                        systemImage: "location.slash",
                        description: Text("Create locations in System Settings, then refresh.")
                    )
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(24)
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    model.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
        }
        .onAppear {
            if selectedLocation.isEmpty {
                selectedLocation = model.profiles.first?.name ?? ""
            }
        }
        .onChange(of: model.profiles.map(\.name)) { _, names in
            if !names.contains(selectedLocation) {
                selectedLocation = names.first ?? ""
            }
        }
    }
}

private struct AliasSection: View {
    @Bindable var model: AppModel

    var body: some View {
        Section {
            if model.aliases.isEmpty {
                Text("No Wi-Fi aliases configured.")
                    .foregroundStyle(.secondary)
            }

            ForEach($model.aliases) { $alias in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("Wi-Fi SSID", text: $alias.ssid)
                        .textFieldStyle(.roundedBorder)

                    Picker("Location", selection: $alias.location) {
                        ForEach(model.profiles.map(\.name), id: \.self) { location in
                            Text(location).tag(location)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)

                    Button(role: .destructive) {
                        removeAlias(alias.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove alias")
                }
            }

            Button {
                model.addAlias()
            } label: {
                Label("Add Wi-Fi Alias", systemImage: "plus")
            }
        } header: {
            Text("Wi-Fi Aliases")
        } footer: {
            Text("Use aliases when multiple SSIDs should map to the same network location.")
        }
    }

    private func removeAlias(_ id: UUID) {
        model.aliases.removeAll { $0.id == id }
    }
}

private struct GuardSection: View {
    @Binding var profile: LocationProfile
    var vpnProfiles: [String]

    var body: some View {
        Section {
            Toggle("Firewall", isOn: $profile.firewall)
            Toggle("Stealth Mode", isOn: $profile.stealthMode)
            Toggle("AirDrop", isOn: $profile.airDrop)
            Toggle("Notifications", isOn: $profile.notification)
            Toggle("VPN", isOn: $profile.vpn)

            if profile.vpn {
                if vpnProfiles.isEmpty {
                    TextField("VPN Profile", text: $profile.vpnTunnel)
                } else {
                    Picker("VPN Profile", selection: $profile.vpnTunnel) {
                        Text("None").tag("")
                        ForEach(vpnProfiles, id: \.self) { profile in
                            Text(profile).tag(profile)
                        }
                    }
                }
            }

            TextField("Apps to Quit", text: $profile.killApps)
        } header: {
            Label("Security & Network", systemImage: "lock.shield")
        } footer: {
            Text("Apps to quit should be comma-separated app process names.")
        }
    }
}

private struct WallpaperSection: View {
    @Binding var profile: LocationProfile

    var body: some View {
        Section {
            HStack {
                TextField("Image Path", text: $profile.wallpaperPath)
                Button {
                    pickWallpaper()
                } label: {
                    Label("Choose", systemImage: "folder")
                }
            }
        } header: {
            Label("Wallpaper", systemImage: "photo")
        } footer: {
            Text("Leave blank to keep the current wallpaper.")
        }
    }

    private func pickWallpaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            profile.wallpaperPath = url.path
        }
    }
}

private struct AudioSection: View {
    @Binding var profile: LocationProfile

    var body: some View {
        Section {
            TextField("Output Device", text: $profile.audioDevice)
            TextField("Volume", text: $profile.audioVolume)
        } header: {
            Label("Audio", systemImage: "speaker.wave.2")
        } footer: {
            Text("Volume accepts 0-100. Leave fields blank to keep current audio settings.")
        }
    }
}

private struct DisplaySection: View {
    @Binding var profile: LocationProfile

    var body: some View {
        Section {
            TextField("Brightness", text: $profile.brightness)

            Picker("Night Shift", selection: $profile.nightShift) {
                ForEach(ThreeWaySetting.allCases) { setting in
                    Text(setting.title).tag(setting)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("Display", systemImage: "display")
        } footer: {
            Text("Brightness accepts 0-100. Leave blank to keep the current brightness.")
        }
    }
}
