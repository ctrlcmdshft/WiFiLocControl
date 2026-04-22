# WiFiLocControl

WiFiLocControl is a native macOS GUI for configuring automatic network-location switching from Wi-Fi SSIDs, plus grouped add-on settings for firewall/privacy, wallpaper, audio, display, notifications, and VPN triggers.

This app is a standalone project. It does not modify the original `wifi-loc-control` or `wifi-loc-control-addons` repositories, but it installs compatible scripts and configuration files under:

- `~/.wifi-loc-control`
- `~/Library/LaunchAgents/WiFiLocControl.plist`
- `/usr/local/bin/wifi-loc-control.sh`
- `/etc/sudoers.d/wifi-loc-control`

## Attribution

This app builds on the behavior and file conventions of:

- [`vborodulin/wifi-loc-control`](https://github.com/vborodulin/wifi-loc-control)
- [`ctrlcmdshft/wifi-loc-control-addons`](https://github.com/ctrlcmdshft/wifi-loc-control-addons)

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for license and attribution details.

## Requirements

- macOS 26+
- Xcode 26+ / Swift 6.2+
- Homebrew for optional add-on tools

Optional command-line tools:

- `SwitchAudioSource` from `brew install switchaudio-osx`
- `brightness` from `brew install brightness`
- `terminal-notifier` from `brew install terminal-notifier`

## Build

Open `WiFiLocControlApp.xcworkspace` in Xcode and build the `WiFiLocControlApp` scheme.

Command line:

```zsh
xcodebuild \
  -workspace WiFiLocControlApp.xcworkspace \
  -scheme WiFiLocControlApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## Use

1. Launch the app.
2. Use **Install or Repair** to install the background script, LaunchAgent, hook dispatcher, and sudoers rules.
3. Configure SSID aliases and per-location settings in **Locations**.
4. Enable or disable add-on hook groups in **Add-ons**.
5. Use **Save Configuration** after changes.

The app may prompt for an administrator password when installing `/usr/local/bin/wifi-loc-control.sh` and `/etc/sudoers.d/wifi-loc-control`.

## Release

For a local GitHub release zip:

```zsh
./scripts/build-release.sh
```

To sign with your Developer ID certificate:

```zsh
CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/build-release.sh
```

The script writes `dist/WiFiLocControl.zip`.

## Notes

VPN switching is implemented through a user LaunchAgent that watches `~/.wifi-loc-control/vpn-trigger` and calls `scutil --nc start/stop` in the user session.

This is intended for GitHub distribution, not App Store distribution. The app sandbox is disabled because it manages LaunchAgents, shell scripts, user configuration, and privileged installer steps.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
