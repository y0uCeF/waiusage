# waiusage — Waybar OpenUsage Telemetry Module (◕‿◕) ★

Dynamic `custom` module that reads `~/`-relative `telemetry.db` from openusage-telemetry.

## Install
```bash
git clone git@github.com:y0uCeF/waiusage.git
cp openusage-telemetry.sh ~/.config/waybar/
chmod +x ~/.config/waybar/openusage-telemetry.sh
```

## Use
Add to `~/.config/waybar/config`:
```json
"custom/openusage": {
  "exec": "~/.config/waybar/openusage-telemetry.sh",
  "return-type": "json",
  "interval": 60,
  "format": "★ {text}"
}
```
Then `waybar` will show `openrouter:27` etc! ♪
