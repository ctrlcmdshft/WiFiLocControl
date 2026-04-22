import Foundation

public enum AddonKind: String, CaseIterable, Identifiable {
    case guardTools
    case wallpaper
    case audio
    case display

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .guardTools: "Location Guard"
        case .wallpaper: "Wallpaper"
        case .audio: "Audio"
        case .display: "Display"
        }
    }

    var hookName: String {
        switch self {
        case .guardTools: "01-loc-guard"
        case .wallpaper: "02-wallpaper"
        case .audio: "03-audio"
        case .display: "04-display"
        }
    }
}

public enum ThreeWaySetting: String, CaseIterable, Identifiable {
    case leave = ""
    case on
    case off

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .leave: "Leave"
        case .on: "On"
        case .off: "Off"
        }
    }
}

public struct AliasRule: Identifiable, Hashable {
    public var id = UUID()
    public var ssid: String
    public var location: String

    public init(ssid: String = "", location: String = "Automatic") {
        self.ssid = ssid
        self.location = location
    }
}

public struct LocationProfile: Identifiable, Hashable {
    public var id: String { name }
    public var name: String

    public var firewall = false
    public var stealthMode = false
    public var airDrop = true
    public var vpn = false
    public var vpnTunnel = ""
    public var killApps = ""
    public var notification = true

    public var wallpaperPath = ""
    public var audioDevice = ""
    public var audioVolume = ""
    public var brightness = ""
    public var nightShift: ThreeWaySetting = .leave

    public init(name: String) {
        self.name = name
    }
}

public struct AddonState: Hashable {
    public var guardTools = true
    public var wallpaper = true
    public var audio = true
    public var display = true

    subscript(kind: AddonKind) -> Bool {
        get {
            switch kind {
            case .guardTools: guardTools
            case .wallpaper: wallpaper
            case .audio: audio
            case .display: display
            }
        }
        set {
            switch kind {
            case .guardTools: guardTools = newValue
            case .wallpaper: wallpaper = newValue
            case .audio: audio = newValue
            case .display: display = newValue
            }
        }
    }
}

public struct SystemStatus: Hashable {
    public var currentWiFi = ""
    public var currentLocation = ""
    public var coreInstalled = false
    public var launchAgentLoaded = false
    public var switchAudioInstalled = false
    public var brightnessInstalled = false
    public var terminalNotifierInstalled = false
    public var vpnProfiles: [String] = []
}
