import AppKit
import SwiftUI

struct LocationsView: View {
    @Bindable var model: AppModel
    @State private var selectedLocation = ""
    @State private var selectedSection: LocationEditorSection = .network

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
        VStack(spacing: 0) {
            LocationHeader(
                profiles: model.profiles,
                currentLocation: model.systemStatus.currentLocation,
                selection: locationSelection
            )

            Divider()

            if let profile = selectedProfileBinding {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Section", selection: $selectedSection) {
                        ForEach(LocationEditorSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 420)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    LocationSectionForm(
                        section: selectedSection,
                        model: model,
                        profile: profile,
                        vpnProfiles: model.systemStatus.vpnProfiles,
                        outputDevices: model.systemStatus.audioOutputDevices,
                        switchAudioInstalled: model.systemStatus.switchAudioInstalled
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                EmptyLocationsView(refresh: model.refresh)
            }
        }
        .navigationTitle("Locations")
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

private enum LocationEditorSection: String, CaseIterable, Identifiable {
    case network
    case appearance
    case audio
    case aliases

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network: "Network"
        case .appearance: "Appearance"
        case .audio: "Audio"
        case .aliases: "Aliases"
        }
    }
}

private struct LocationHeader: View {
    var profiles: [LocationProfile]
    var currentLocation: String
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 16) {
            Picker("Location", selection: $selection) {
                ForEach(profiles) { profile in
                    Text(profile.name).tag(profile.name)
                }
            }
            .frame(width: 300)
            .help("Select the macOS network location to configure.")

            InfoButton("Select the macOS network location to configure.")

            if !currentLocation.isEmpty {
                Label("Current: \(currentLocation)", systemImage: "location.fill")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("Current active macOS network location.")
                InfoButton("Current active macOS network location.")
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct LocationSectionForm: View {
    var section: LocationEditorSection
    @Bindable var model: AppModel
    @Binding var profile: LocationProfile
    var vpnProfiles: [String]
    var outputDevices: [String]
    var switchAudioInstalled: Bool

    var body: some View {
        Form {
            switch section {
            case .network:
                SecuritySection(profile: $profile, vpnProfiles: vpnProfiles)
            case .appearance:
                WallpaperSection(profile: $profile)
                DisplaySection(profile: $profile)
            case .audio:
                AudioSection(
                    profile: $profile,
                    outputDevices: outputDevices,
                    switchAudioInstalled: switchAudioInstalled
                )
            case .aliases:
                AliasSection(model: model, location: profile.name)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 6)
        .frame(maxWidth: 620, alignment: .leading)
    }
}

private struct EmptyLocationsView: View {
    var refresh: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.slash")
                .font(.system(size: 42))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text("No Network Locations")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Create macOS network locations in System Settings, then refresh this view.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AliasSection: View {
    @Bindable var model: AppModel
    var location: String

    private var aliasesForLocation: [Binding<AliasRule>] {
        $model.aliases.filter { $0.wrappedValue.location == location }
    }

    var body: some View {
        Section("Wi-Fi Aliases") {
            if aliasesForLocation.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            }

            ForEach(aliasesForLocation) { $alias in
                HStack(spacing: 8) {
                    TextField("SSID", text: $alias.ssid)
                        .help("Wi-Fi network name that should map to this location.")

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
                model.aliases.append(AliasRule(location: location))
            } label: {
                Label("Add Alias", systemImage: "plus")
            }
            .help("Add a Wi-Fi SSID alias for this location.")
        }
    }

    private func removeAlias(_ id: UUID) {
        model.aliases.removeAll { $0.id == id }
    }
}

private struct SecuritySection: View {
    @Binding var profile: LocationProfile
    var vpnProfiles: [String]

    var body: some View {
        Section("Network") {
            HelpToggle(
                "Firewall",
                help: "Enable or disable the macOS application firewall for this location.",
                isOn: $profile.firewall
            )
                .help("Enable or disable the macOS application firewall for this location.")
            HelpToggle(
                "Stealth Mode",
                help: "Hide this Mac from unsolicited network probes when the firewall is on.",
                isOn: $profile.stealthMode
            )
                .help("Hide this Mac from unsolicited network probes when the firewall is on.")
            HelpToggle(
                "AirDrop",
                help: "Allow or disable AirDrop for this location.",
                isOn: $profile.airDrop
            )
                .help("Allow or disable AirDrop for this location.")
            HelpToggle(
                "Notifications",
                help: "Show a notification after applying this location.",
                isOn: $profile.notification
            )
                .help("Show a notification after applying this location.")
            HelpToggle(
                "VPN",
                help: "Start or stop the selected VPN when this location is applied.",
                isOn: $profile.vpn
            )
                .help("Start or stop the selected VPN when this location is applied.")

            if profile.vpn {
                if vpnProfiles.isEmpty {
                    TextField("VPN Profile", text: $profile.vpnTunnel)
                        .help("VPN service name from System Settings.")
                } else {
                    Picker("VPN Profile", selection: $profile.vpnTunnel) {
                        Text("None").tag("")
                        ForEach(vpnProfiles, id: \.self) { profile in
                            Text(profile).tag(profile)
                        }
                    }
                    .help("VPN service to start when VPN is enabled.")
                }
            }

            TextField("Apps to Quit", text: $profile.killApps)
                .help("Comma-separated app process names to quit when this location is applied.")
            InfoButton("Use comma-separated process names, for example Safari, Music.")
        }
    }
}

private struct WallpaperSection: View {
    @Binding var profile: LocationProfile

    var body: some View {
        Section("Wallpaper") {
            HStack {
                TextField("Image Path", text: $profile.wallpaperPath)
                    .help("Leave blank to keep the current wallpaper.")
                InfoButton("Leave blank to keep the current wallpaper.")
                Button {
                    pickWallpaper()
                } label: {
                    Label("Choose", systemImage: "folder")
                }
                .help("Choose a wallpaper image.")
            }
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
    var outputDevices: [String]
    var switchAudioInstalled: Bool

    private var selectableOutputDevices: [String] {
        if profile.audioDevice.isEmpty || outputDevices.contains(profile.audioDevice) {
            return outputDevices
        }
        return [profile.audioDevice] + outputDevices
    }

    var body: some View {
        Section("Audio") {
            HelpToggle(
                "Set Volume",
                help: "Set output volume for this location. Turn off to keep the current volume.",
                isOn: stringSettingEnabled($profile.audioVolume, defaultValue: "50")
            )
                .help("Set output volume for this location. Turn off to keep the current volume.")

            if !profile.audioVolume.isEmpty {
                SliderRow(
                    title: "Volume",
                    value: numericStringBinding($profile.audioVolume, defaultValue: 50),
                    minimumImage: "speaker",
                    maximumImage: "speaker.wave.3"
                )
                .help("Volume percentage to apply.")
            }

            Picker("Output Device", selection: $profile.audioDevice) {
                Text("Keep Current").tag("")
                ForEach(selectableOutputDevices, id: \.self) { device in
                    Text(device).tag(device)
                }
            }
            .disabled(selectableOutputDevices.isEmpty)
            .help("Audio output device to select. Keep Current leaves it unchanged.")
            InfoButton("Keep Current leaves the output device unchanged. Device switching requires SwitchAudioSource.")

            if !switchAudioInstalled {
                Text("SwitchAudioSource is not installed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if selectableOutputDevices.isEmpty {
                Text("No output devices detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DisplaySection: View {
    @Binding var profile: LocationProfile

    var body: some View {
        Section("Display") {
            HelpToggle(
                "Set Brightness",
                help: "Set display brightness for this location. Turn off to keep the current brightness.",
                isOn: stringSettingEnabled($profile.brightness, defaultValue: "50")
            )
                .help("Set display brightness for this location. Turn off to keep the current brightness.")

            if !profile.brightness.isEmpty {
                SliderRow(
                    title: "Brightness",
                    value: numericStringBinding($profile.brightness, defaultValue: 50),
                    minimumImage: "sun.min",
                    maximumImage: "sun.max"
                )
                .help("Brightness percentage to apply.")
            }

            Picker("Night Shift", selection: $profile.nightShift) {
                ForEach(ThreeWaySetting.allCases) { setting in
                    Text(setting.title).tag(setting)
                }
            }
            .pickerStyle(.segmented)
            .help("Choose whether to enable, disable, or leave Night Shift unchanged.")
            InfoButton("Leave keeps the current Night Shift setting unchanged.")
        }
    }
}

private struct HelpToggle: View {
    var title: String
    var help: String
    @Binding var isOn: Bool

    init(_ title: String, help: String, isOn: Binding<Bool>) {
        self.title = title
        self.help = help
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            Toggle(title, isOn: $isOn)
            InfoButton(help)
        }
    }
}

private struct InfoButton: View {
    var text: String
    @State private var isPresented = false

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(text)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .padding(12)
                .frame(width: 240, alignment: .leading)
        }
    }
}

private struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var minimumImage: String
    var maximumImage: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                Image(systemName: minimumImage)
                    .foregroundStyle(.secondary)
                Slider(value: $value, in: 0...100, step: 1)
                Image(systemName: maximumImage)
                    .foregroundStyle(.secondary)
                Text("\(Int(value.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        } label: {
            Text(title)
        }
    }
}

private func stringSettingEnabled(_ value: Binding<String>, defaultValue: String) -> Binding<Bool> {
    Binding {
        !value.wrappedValue.isEmpty
    } set: { isEnabled in
        value.wrappedValue = isEnabled ? defaultValue : ""
    }
}

private func numericStringBinding(_ value: Binding<String>, defaultValue: Double) -> Binding<Double> {
    Binding {
        guard let number = Double(value.wrappedValue) else { return defaultValue }
        return min(max(number, 0), 100)
    } set: { newValue in
        value.wrappedValue = String(Int(newValue.rounded()))
    }
}
