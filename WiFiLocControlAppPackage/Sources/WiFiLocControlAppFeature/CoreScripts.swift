import Foundation

enum CoreScripts {
    static let coreAgent = #"""
    #!/usr/bin/env bash
    LOGS_PATH="$HOME/Library/Logs/WiFiLocControl.log"
    LOG_MAX_BYTES=5242880
    DEFAULT_NETWORK_LOCATION="Automatic"
    CONFIG_DIR="$HOME/.wifi-loc-control"
    ALIAS_CONFIG_PATH="$CONFIG_DIR/alias.conf"

    mkdir -p "$(dirname "$LOGS_PATH")"
    if [[ -f "$LOGS_PATH" ]]; then
      log_size=$(wc -c < "$LOGS_PATH" | tr -d '[:space:]')
      if [[ "$log_size" =~ ^[0-9]+$ && "$log_size" -gt "$LOG_MAX_BYTES" ]]; then
        tail -c "$LOG_MAX_BYTES" "$LOGS_PATH" > "$LOGS_PATH.tmp" && mv "$LOGS_PATH.tmp" "$LOGS_PATH"
      fi
    fi
    exec >> "$LOGS_PATH" 2>&1
    sleep 3

    log() {
      current_date=$(date +"[%Y-%m-%d %H:%M:%S]")
      echo "$current_date $*"
    }

    get_wifi_name() {
      if command -v ipconfig >/dev/null 2>&1; then
        wifi_name_new=$(ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2}' | tr -d '\n')
        if [[ -n "$wifi_name_new" && "$wifi_name_new" != "<redacted>" && "$wifi_name_new" != "< redacted >" ]]; then
          echo "$wifi_name_new"
          return 0
        fi

        if sudo -n ipconfig setverbose 1 >/dev/null 2>&1; then
          sudo ipconfig setverbose 1 >/dev/null 2>&1
          wifi_name_verbose=$(ipconfig getsummary en0 2>/dev/null | awk -F ' SSID : ' '/ SSID : / {print $2}' | tr -d '\n')
          sudo ipconfig setverbose 0 >/dev/null 2>&1
          if [[ -n "$wifi_name_verbose" && "$wifi_name_verbose" != "<redacted>" && "$wifi_name_verbose" != "< redacted >" ]]; then
            echo "$wifi_name_verbose"
            return 0
          fi
        fi
      fi

      wifi_name_plist=$(/usr/libexec/PlistBuddy -c 'Print :0:_items:0:spairport_airport_interfaces:0:spairport_current_network_information:_name' /dev/stdin <<< "$(system_profiler SPAirPortDataType -xml)" 2>/dev/null)
      if [[ -n "$wifi_name_plist" && "$wifi_name_plist" != "<redacted>" && "$wifi_name_plist" != "< redacted >" ]]; then
        echo "$wifi_name_plist"
        return 0
      fi

      networksetup -listpreferredwirelessnetworks en0 | sed -n '2 p' | tr -d '\t'
    }

    wifi_name="$(get_wifi_name)"
    log "current wifi_name '$wifi_name'"

    if [[ -z "$wifi_name" || "$wifi_name" == "<redacted>" || "$wifi_name" == "< redacted >" ]]; then
      log "wifi_name is empty or redacted"
      exit 0
    fi

    network_locations=$(scselect | sed -n 's/^ .*(\(.*\))/\1/p' | xargs)
    current_network_location=$(scselect | sed -n 's/ \* .*(\(.*\))/\1/p')
    log "network locations: $network_locations"
    log "current network location '$current_network_location'"

    alias_location="$wifi_name"
    if [[ -f "$ALIAS_CONFIG_PATH" ]]; then
      alias=$(grep -F "$wifi_name=" "$ALIAS_CONFIG_PATH" | sed -nE 's/^[^=]+=(.*)/\1/p' | tail -1)
      if [[ -n "$alias" ]]; then
        alias_location="$alias"
        log "for wifi name '$wifi_name' found alias '$alias_location'"
      fi
    fi

    exec_location_script() {
      location="$1"
      script_file="$CONFIG_DIR/$location"
      log "finding script for location '$location'"
      if [[ -f "$script_file" ]]; then
        chmod +x "$script_file"
        log "running script '$script_file'"
        "$script_file"
      else
        log "script for location '$location' not found"
      fi
    }

    if ! echo " $network_locations " | grep -F " $alias_location " >/dev/null; then
      if [[ "$current_network_location" == "$DEFAULT_NETWORK_LOCATION" ]]; then
        log "switch location is not required"
        exit 0
      fi
      scselect "$DEFAULT_NETWORK_LOCATION"
      log "location switched to '$DEFAULT_NETWORK_LOCATION'"
      exec_location_script "$DEFAULT_NETWORK_LOCATION"
      exit 0
    fi

    if [[ "$alias_location" != "$current_network_location" ]]; then
      scselect "$alias_location"
      log "location switched to '$alias_location'"
      exec_location_script "$alias_location"
      exit 0
    fi

    log "switch location is not required"
    """#

    static let dispatcher = #"""
    #!/usr/bin/env bash
    exec 2>&1
    LOCATION="$(basename "$0")"
    HOOKS_DIR="$(dirname "$0")/hooks/$LOCATION"
    [[ -d "$HOOKS_DIR" ]] || exit 0
    for hook in "$HOOKS_DIR"/[0-9][0-9]-*; do
      [[ -x "$hook" ]] || continue
      "$hook" "$LOCATION"
    done
    """#

    static let guardApply = #"""
    #!/usr/bin/env bash
    exec 2>&1
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    LOCATION="$1"
    CONFIG="$HOME/.wifi-loc-control/settings.conf"
    FIREWALL="/usr/libexec/ApplicationFirewall/socketfilterfw"
    [[ -f "$CONFIG" ]] || exit 0
    source "$CONFIG"

    KEY=$(echo "$LOCATION" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
    val() { local _v="${KEY}_${1}"; echo "${!_v}"; }

    if [[ "$(val firewall)" == "on" ]]; then
      sudo "$FIREWALL" --setglobalstate on
    else
      sudo "$FIREWALL" --setglobalstate off
    fi

    if [[ "$(val stealth_mode)" == "on" ]]; then
      sudo "$FIREWALL" --setstealthmode on
    else
      sudo "$FIREWALL" --setstealthmode off
    fi

    if [[ "$(val airdrop)" == "on" ]]; then
      defaults write com.apple.NetworkBrowser DisableAirDrop -bool false
    else
      defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
    fi

    echo "$(val wireguard):$(val wireguard_tunnel):$(date +%s)" > "$HOME/.wifi-loc-control/vpn-trigger"

    kill_apps="$(val kill_apps)"
    if [[ -n "$kill_apps" ]]; then
      IFS=',' read -ra apps <<< "$kill_apps"
      for app in "${apps[@]}"; do
        app="${app#"${app%%[![:space:]]*}"}"
        app="${app%"${app##*[![:space:]]}"}"
        [[ -n "$app" ]] && pkill -x "$app" 2>/dev/null || true
      done
    fi

    if [[ "$(val notification)" == "on" ]] && command -v terminal-notifier >/dev/null 2>&1; then
      terminal-notifier -title "WiFi Location" -subtitle "Switched to $LOCATION" -message "Location settings applied" -group "wifi-location" || true
    fi
    """#

    static let wallpaperApply = #"""
    #!/usr/bin/env bash
    LOCATION="$1"
    CONFIG="$HOME/.wifi-loc-control/wallpaper.conf"
    [[ -f "$CONFIG" ]] || exit 0
    source "$CONFIG"
    KEY=$(echo "$LOCATION" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
    _v="${KEY}_wallpaper"
    wallpaper="${!_v}"
    [[ -n "$wallpaper" && -f "$wallpaper" ]] || exit 0
    osascript -e "tell application \"System Events\" to set picture of every desktop to POSIX file \"$wallpaper\"" || true
    """#

    static let audioApply = #"""
    #!/usr/bin/env bash
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    LOCATION="$1"
    CONFIG="$HOME/.wifi-loc-control/audio.conf"
    [[ -f "$CONFIG" ]] || exit 0
    source "$CONFIG"
    KEY=$(echo "$LOCATION" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
    _v="${KEY}_device"; device="${!_v}"
    _v="${KEY}_volume"; volume="${!_v}"
    if [[ -n "$device" ]] && command -v SwitchAudioSource >/dev/null 2>&1; then
      SwitchAudioSource -s "$device" 2>/dev/null || true
    fi
    if [[ -n "$volume" ]]; then
      osascript -e "set volume output volume $volume" 2>/dev/null || true
    fi
    """#

    static let displayApply = #"""
    #!/usr/bin/env bash
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    LOCATION="$1"
    CONFIG="$HOME/.wifi-loc-control/display.conf"
    [[ -f "$CONFIG" ]] || exit 0
    source "$CONFIG"
    KEY=$(echo "$LOCATION" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
    _v="${KEY}_brightness"; brightness_value="${!_v}"
    _v="${KEY}_night_shift"; night_shift="${!_v}"
    if [[ -n "$brightness_value" ]] && command -v brightness >/dev/null 2>&1; then
      level=$(echo "scale=2; $brightness_value / 100" | bc)
      brightness "$level" 2>/dev/null || true
    fi
    if [[ "$night_shift" == "on" ]]; then
      osascript -e 'tell application "System Events" to tell appearance preferences to set night shift enabled to true' 2>/dev/null || true
    elif [[ "$night_shift" == "off" ]]; then
      osascript -e 'tell application "System Events" to tell appearance preferences to set night shift enabled to false' 2>/dev/null || true
    fi
    """#

    static let vpnApply = #"""
    #!/usr/bin/env bash
    TRIGGER="$HOME/.wifi-loc-control/vpn-trigger"
    [[ -f "$TRIGGER" ]] || exit 0
    IFS=':' read -r mode tunnel _ < "$TRIGGER"
    [[ -n "$tunnel" ]] || exit 0
    if [[ "$mode" == "on" ]]; then
      scutil --nc start "$tunnel" >/dev/null 2>&1 || true
    else
      scutil --nc stop "$tunnel" >/dev/null 2>&1 || true
    fi
    """#
}
