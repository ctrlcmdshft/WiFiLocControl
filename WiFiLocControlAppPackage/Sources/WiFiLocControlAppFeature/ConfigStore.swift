import Foundation

struct ConfigStore {
    let homeURL: URL
    private let fileManager = FileManager.default

    init(homeURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeURL = homeURL
    }

    var configURL: URL { homeURL.appending(path: ".wifi-loc-control", directoryHint: .isDirectory) }
    var launchAgentsURL: URL { homeURL.appending(path: "Library/LaunchAgents", directoryHint: .isDirectory) }
    var logURL: URL { homeURL.appending(path: "Library/Logs/WiFiLocControl.log") }

    func loadProfiles(locations: [String]) -> [LocationProfile] {
        let guardValues = readConfig("settings.conf")
        let wallpaperValues = readConfig("wallpaper.conf")
        let audioValues = readConfig("audio.conf")
        let displayValues = readConfig("display.conf")

        return locations.map { location in
            let key = locationKey(location)
            var profile = LocationProfile(name: location)
            profile.firewall = guardValues["\(key)_firewall"] == "on"
            profile.stealthMode = guardValues["\(key)_stealth_mode"] == "on"
            profile.airDrop = guardValues["\(key)_airdrop"].map { $0 == "on" } ?? true
            profile.vpn = guardValues["\(key)_wireguard"] == "on"
            profile.vpnTunnel = guardValues["\(key)_wireguard_tunnel"] ?? ""
            profile.killApps = guardValues["\(key)_kill_apps"] ?? ""
            profile.notification = guardValues["\(key)_notification"].map { $0 == "on" } ?? true
            profile.wallpaperPath = wallpaperValues["\(key)_wallpaper"] ?? ""
            profile.audioDevice = audioValues["\(key)_device"] ?? ""
            profile.audioVolume = audioValues["\(key)_volume"] ?? ""
            profile.brightness = displayValues["\(key)_brightness"] ?? ""
            profile.nightShift = ThreeWaySetting(rawValue: displayValues["\(key)_night_shift"] ?? "") ?? .leave
            return profile
        }
    }

    func loadAliases() -> [AliasRule] {
        let values = readConfig("alias.conf")
        return values.keys.sorted().map { AliasRule(ssid: $0, location: values[$0] ?? "Automatic") }
    }

    func loadAddonState(locations: [String]) -> AddonState {
        var state = AddonState()
        for kind in AddonKind.allCases {
            let enabled = locations.contains { location in
                fileManager.isExecutableFile(atPath: hookURL(location: location, kind: kind).path)
            }
            state[kind] = enabled || !hooksExist(kind: kind, locations: locations)
        }
        return state
    }

    func save(profiles: [LocationProfile], aliases: [AliasRule], addonState: AddonState) throws {
        try fileManager.createDirectory(at: configURL, withIntermediateDirectories: true)
        try writeAliases(aliases)
        try writeGuard(profiles)
        try writeWallpaper(profiles)
        try writeAudio(profiles)
        try writeDisplay(profiles)
        try installHookFiles(profiles: profiles, addonState: addonState)
    }

    func readLogTail(maxBytes: Int = 50_000) -> String {
        guard let data = try? Data(contentsOf: logURL) else { return "" }
        let suffix = data.count > maxBytes ? data.suffix(maxBytes) : data[...]
        return String(data: Data(suffix), encoding: .utf8) ?? ""
    }

    func logByteCount() -> Int {
        guard let values = try? fileManager.attributesOfItem(atPath: logURL.path),
              let size = values[.size] as? NSNumber else {
            return 0
        }
        return size.intValue
    }

    func clearLog() throws {
        try fileManager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: logURL, options: .atomic)
    }

    private func readConfig(_ fileName: String) -> [String: String] {
        let url = configURL.appending(path: fileName)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parseShellConfig(text)
    }

    private func writeAliases(_ aliases: [AliasRule]) throws {
        let body = aliases
            .filter { !$0.ssid.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "\($0.ssid)=\($0.location)" }
            .joined(separator: "\n")
        try write(body + (body.isEmpty ? "" : "\n"), to: "alias.conf")
    }

    private func writeGuard(_ profiles: [LocationProfile]) throws {
        var lines = ["# Location Guard settings - managed by WiFiLocControl"]
        for profile in profiles {
            let key = locationKey(profile.name)
            lines += [
                "",
                "# \(profile.name)",
                "\(key)_firewall=\(profile.firewall ? "on" : "off")",
                "\(key)_stealth_mode=\(profile.stealthMode ? "on" : "off")",
                "\(key)_airdrop=\(profile.airDrop ? "on" : "off")",
                "\(key)_wireguard=\(profile.vpn ? "on" : "off")",
                "\(key)_wireguard_tunnel=\(shellConfigValue(profile.vpnTunnel))",
                "\(key)_kill_apps=\(shellConfigValue(profile.killApps))",
                "\(key)_notification=\(profile.notification ? "on" : "off")",
            ]
        }
        try write(lines.joined(separator: "\n") + "\n", to: "settings.conf")
    }

    private func writeWallpaper(_ profiles: [LocationProfile]) throws {
        let lines = ["# Wallpaper settings - managed by WiFiLocControl"] + profiles.map {
            "\(locationKey($0.name))_wallpaper=\(shellConfigValue($0.wallpaperPath))"
        }
        try write(lines.joined(separator: "\n") + "\n", to: "wallpaper.conf")
    }

    private func writeAudio(_ profiles: [LocationProfile]) throws {
        var lines = ["# Audio settings - managed by WiFiLocControl"]
        for profile in profiles {
            let key = locationKey(profile.name)
            lines += ["", "\(key)_device=\(shellConfigValue(profile.audioDevice))", "\(key)_volume=\(shellConfigValue(profile.audioVolume))"]
        }
        try write(lines.joined(separator: "\n") + "\n", to: "audio.conf")
    }

    private func writeDisplay(_ profiles: [LocationProfile]) throws {
        var lines = ["# Display settings - managed by WiFiLocControl"]
        for profile in profiles {
            let key = locationKey(profile.name)
            lines += ["", "\(key)_brightness=\(shellConfigValue(profile.brightness))", "\(key)_night_shift=\(shellConfigValue(profile.nightShift.rawValue))"]
        }
        try write(lines.joined(separator: "\n") + "\n", to: "display.conf")
    }

    private func write(_ text: String, to fileName: String) throws {
        try text.write(to: configURL.appending(path: fileName), atomically: true, encoding: .utf8)
    }

    private func installHookFiles(profiles: [LocationProfile], addonState: AddonState) throws {
        try write(CoreScripts.guardApply, to: "guard-apply.sh")
        try write(CoreScripts.wallpaperApply, to: "wallpaper-apply.sh")
        try write(CoreScripts.audioApply, to: "audio-apply.sh")
        try write(CoreScripts.displayApply, to: "display-apply.sh")
        try write(CoreScripts.vpnApply, to: "vpn-apply.sh")

        for script in ["guard-apply.sh", "wallpaper-apply.sh", "audio-apply.sh", "display-apply.sh", "vpn-apply.sh"] {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: configURL.appending(path: script).path)
        }

        for profile in profiles {
            try write(CoreScripts.dispatcher, to: profile.name)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: configURL.appending(path: profile.name).path)

            let hookDirectory = configURL.appending(path: "hooks/\(profile.name)", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: hookDirectory, withIntermediateDirectories: true)
            try writeHook(kind: .guardTools, location: profile.name, target: "guard-apply.sh", enabled: addonState.guardTools)
            try writeHook(kind: .wallpaper, location: profile.name, target: "wallpaper-apply.sh", enabled: addonState.wallpaper)
            try writeHook(kind: .audio, location: profile.name, target: "audio-apply.sh", enabled: addonState.audio)
            try writeHook(kind: .display, location: profile.name, target: "display-apply.sh", enabled: addonState.display)
        }
    }

    private func writeHook(kind: AddonKind, location: String, target: String, enabled: Bool) throws {
        let url = hookURL(location: location, kind: kind)
        let text = """
        #!/usr/bin/env bash
        exec 2>&1
        "$HOME/.wifi-loc-control/\(target)" "$1"

        """
        try text.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: enabled ? 0o755 : 0o644], ofItemAtPath: url.path)
    }

    private func hookURL(location: String, kind: AddonKind) -> URL {
        configURL.appending(path: "hooks/\(location)/\(kind.hookName)")
    }

    private func hooksExist(kind: AddonKind, locations: [String]) -> Bool {
        locations.contains { fileManager.fileExists(atPath: hookURL(location: $0, kind: kind).path) }
    }
}
