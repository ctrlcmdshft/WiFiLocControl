import Foundation
import Observation

@Observable
public final class AppModel {
    public var profiles: [LocationProfile] = []
    public var aliases: [AliasRule] = []
    public var addonState = AddonState()
    public var systemStatus = SystemStatus()
    public var logText = ""
    public var logInfo = LogInfo()
    public var message = "Ready"
    public var isBusy = false

    private let shell = ShellClient()
    private let store = ConfigStore()

    public init() {
        refresh()
    }

    public func refresh() {
        isBusy = true
        defer { isBusy = false }

        let locations = loadNetworkLocations()
        profiles = store.loadProfiles(locations: locations.isEmpty ? ["Automatic"] : locations)
        aliases = store.loadAliases()
        addonState = store.loadAddonState(locations: profiles.map(\.name))
        logText = store.readLogTail()
        logInfo.byteCount = store.logByteCount()
        systemStatus = loadSystemStatus()
        message = "Refreshed"
    }

    public func save() {
        do {
            try store.save(profiles: profiles, aliases: aliases, addonState: addonState)
            try installVPNLaunchAgent()
            message = "Configuration saved"
            refresh()
        } catch {
            message = "Save failed: \(error.localizedDescription)"
        }
    }

    public func installCore() {
        isBusy = true
        defer { isBusy = false }

        do {
            try store.save(profiles: profiles, aliases: aliases, addonState: addonState)
            try installPrivilegedCoreScript()
            try installLaunchAgent()
            try installVPNLaunchAgent()
            message = "Core service installed"
            refresh()
        } catch {
            message = "Install failed: \(error.localizedDescription)"
        }
    }

    public func runNow() {
        let result = shell.run("/usr/local/bin/wifi-loc-control.sh")
        message = result.status == 0 ? "Location check ran" : "Location check failed: \(result.error)"
        logText = store.readLogTail()
        logInfo.byteCount = store.logByteCount()
    }

    public func clearLog() {
        do {
            try store.clearLog()
            logText = ""
            logInfo.byteCount = 0
            message = "Log cleared"
        } catch {
            message = "Clear log failed: \(error.localizedDescription)"
        }
    }

    public func openConfigFolder() {
        _ = shell.run("/usr/bin/open", [store.configURL.path])
    }

    public func addAlias() {
        aliases.append(AliasRule(location: profiles.first?.name ?? "Automatic"))
    }

    public func removeAliases(at offsets: IndexSet) {
        aliases.remove(atOffsets: offsets)
    }

    public func installOptionalTools() {
        let missing = [
            systemStatus.switchAudioInstalled ? nil : "switchaudio-osx",
            systemStatus.brightnessInstalled ? nil : "brightness",
            systemStatus.terminalNotifierInstalled ? nil : "terminal-notifier",
        ].compactMap(\.self)

        guard !missing.isEmpty else {
            message = "Optional tools are already installed"
            return
        }

        let result = shell.run("/usr/bin/env", ["bash", "-lc", "brew install \(missing.map(shellQuote).joined(separator: " "))"])
        message = result.status == 0 ? "Installed optional tools" : "Tool install failed: \(result.error)"
        refresh()
    }

    private func loadSystemStatus() -> SystemStatus {
        var status = SystemStatus()
        status.currentWiFi = currentWiFiName()
        status.currentLocation = currentNetworkLocation()
        status.coreInstalled = FileManager.default.isExecutableFile(atPath: "/usr/local/bin/wifi-loc-control.sh")
        status.launchAgentLoaded = shell.run("/bin/launchctl", ["print", "gui/\(getuid())/application.com.wifi-loc-control"]).status == 0
        status.switchAudioInstalled = shell.existsInPath("SwitchAudioSource")
        status.brightnessInstalled = shell.existsInPath("brightness")
        status.terminalNotifierInstalled = shell.existsInPath("terminal-notifier")
        status.audioOutputDevices = loadAudioOutputDevices()
        status.vpnProfiles = loadVPNProfiles()
        return status
    }

    private func loadNetworkLocations() -> [String] {
        shell.run("/usr/sbin/scselect").output
            .split(separator: "\n")
            .compactMap { line in
                guard let open = line.lastIndex(of: "("), let close = line.lastIndex(of: ")"), open < close else {
                    return nil
                }
                return String(line[line.index(after: open)..<close])
            }
    }

    private func currentNetworkLocation() -> String {
        shell.run("/usr/sbin/scselect").output
            .split(separator: "\n")
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("*") }
            .flatMap { line -> String? in
                guard let open = line.lastIndex(of: "("), let close = line.lastIndex(of: ")"), open < close else {
                    return nil
                }
                return String(line[line.index(after: open)..<close])
            } ?? ""
    }

    private func currentWiFiName() -> String {
        let command = """
        ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2}' | tr -d '\\n'
        """
        let result = shell.run("/usr/bin/env", ["bash", "-lc", command])
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadVPNProfiles() -> [String] {
        let output = shell.run("/usr/sbin/scutil", ["--nc", "list"]).output
        return output.split(separator: "\n").compactMap { parseVPNProfileName(String($0)) }
    }

    private func loadAudioOutputDevices() -> [String] {
        guard shell.existsInPath("SwitchAudioSource") else { return [] }
        let result = shell.run("/usr/bin/env", ["bash", "-lc", "SwitchAudioSource -a -t output"])
        guard result.status == 0 else { return [] }
        return result.output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func installPrivilegedCoreScript() throws {
        let tempURL = FileManager.default.temporaryDirectory.appending(path: "wifi-loc-control.sh")
        try CoreScripts.coreAgent.write(to: tempURL, atomically: true, encoding: .utf8)

        let user = NSUserName()
        let sudoers = """
        \(user) ALL=(ALL) NOPASSWD: /usr/sbin/ipconfig
        \(user) ALL=(ALL) NOPASSWD: /usr/libexec/ApplicationFirewall/socketfilterfw
        """
        let sudoersURL = FileManager.default.temporaryDirectory.appending(path: "wifi-loc-control.sudoers")
        try sudoers.write(to: sudoersURL, atomically: true, encoding: .utf8)

        let command = [
            "mkdir -p /usr/local/bin",
            "cp \(shellQuote(tempURL.path)) /usr/local/bin/wifi-loc-control.sh",
            "chmod 755 /usr/local/bin/wifi-loc-control.sh",
            "cp \(shellQuote(sudoersURL.path)) /etc/sudoers.d/wifi-loc-control",
            "chmod 440 /etc/sudoers.d/wifi-loc-control",
            "visudo -c -f /etc/sudoers.d/wifi-loc-control",
        ].joined(separator: " && ")

        let script = "do shell script \(appleScriptString(command)) with administrator privileges"
        let result = shell.run("/usr/bin/osascript", ["-e", script])
        if result.status != 0 {
            throw NSError(domain: "Installer", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: result.error])
        }
    }

    private func installLaunchAgent() throws {
        try FileManager.default.createDirectory(at: store.launchAgentsURL, withIntermediateDirectories: true)
        let plistURL = store.launchAgentsURL.appending(path: "WiFiLocControl.plist")
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>application.com.wifi-loc-control</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/wifi-loc-control.sh</string>
            </array>
            <key>WatchPaths</key>
            <array>
                <string>/Library/Preferences/SystemConfiguration/</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(store.logURL.path)</string>
            <key>StandardErrorPath</key>
            <string>\(store.logURL.path)</string>
        </dict>
        </plist>
        """
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)
        _ = shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
        let result = shell.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
        if result.status != 0 {
            throw NSError(domain: "LaunchAgent", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: result.error])
        }
    }

    private func installVPNLaunchAgent() throws {
        try FileManager.default.createDirectory(at: store.launchAgentsURL, withIntermediateDirectories: true)
        let triggerURL = store.configURL.appending(path: "vpn-trigger")
        if !FileManager.default.fileExists(atPath: triggerURL.path) {
            try "off::0\n".write(to: triggerURL, atomically: true, encoding: .utf8)
        }

        let plistURL = store.launchAgentsURL.appending(path: "com.github.wifiloccontrol.vpn-helper.plist")
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.github.wifiloccontrol.vpn-helper</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(store.configURL.appending(path: "vpn-apply.sh").path)</string>
            </array>
            <key>WatchPaths</key>
            <array>
                <string>\(triggerURL.path)</string>
            </array>
            <key>RunAtLoad</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(store.homeURL.appending(path: "Library/Logs/WiFiLocControlVPN.log").path)</string>
            <key>StandardErrorPath</key>
            <string>\(store.homeURL.appending(path: "Library/Logs/WiFiLocControlVPN.log").path)</string>
        </dict>
        </plist>
        """
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)
        _ = shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())", plistURL.path])
        _ = shell.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
    }
}

private func appleScriptString(_ value: String) -> String {
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

func parseVPNProfileName(_ line: String) -> String? {
    guard line.contains("[VPN") else { return nil }
    let parts = line.split(separator: "\"", omittingEmptySubsequences: false)
    guard parts.count >= 2 else { return nil }
    let name = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    return name.replacingOccurrences(
        of: #"\s+\[[^\]]+\]$"#,
        with: "",
        options: .regularExpression
    )
}
