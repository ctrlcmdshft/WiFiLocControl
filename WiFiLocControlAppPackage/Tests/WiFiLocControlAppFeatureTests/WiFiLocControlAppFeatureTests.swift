import Testing
@testable import WiFiLocControlAppFeature

@Test func locationKeyMatchesShellConvention() {
    #expect(locationKey("Home Office") == "HOME_OFFICE")
    #expect(locationKey("Automatic") == "AUTOMATIC")
}

@Test func shellConfigParserReadsQuotedValues() {
    let values = parseShellConfig("""
    # comment
    HOME_firewall=on
    HOME_wallpaper="/Users/me/Pictures/Home Desk.jpg"
    HOME_empty=""
    """)

    #expect(values["HOME_firewall"] == "on")
    #expect(values["HOME_wallpaper"] == "/Users/me/Pictures/Home Desk.jpg")
    #expect(values["HOME_empty"] == "")
}

@Test func shellConfigValueEscapesQuotesAndBackslashes() {
    #expect(shellConfigValue(#"/Users/me/Pictures/a "nice" shot.jpg"#) == #""/Users/me/Pictures/a \"nice\" shot.jpg""#)
}

@Test func vpnProfileParserStripsProviderSuffix() {
    let line = #"*  "MacBook_Air_Automatic-US-NY-465 [VPN:com.wireguard.macos]""#
    #expect(parseVPNProfileName(line) == "MacBook_Air_Automatic-US-NY-465")
}
