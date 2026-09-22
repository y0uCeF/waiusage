# Waybar OpenUsage Telemetry Module Plan (◕‿◕) ★

## Module Design
- Type: `custom/openusage`
- Script: `~/.config/waybar/openusage-telemetry.sh`
- Source: SQLite `telemetry.db` (`usage_events` table)
- Output: JSON `{"text":"...", "tooltip":"...", "class":"..."}`

## Script Behavior
1. Query `SELECT provider_id, agent_name, event_type, total_tokens, occurred_at FROM usage_events ORDER BY occurred_at DESC LIMIT 1;`
2. Aggregate counts per provider via `SELECT provider_id, COUNT(*) FROM usage_events GROUP BY provider_id;`
3. Emit JSON for waybar `custom/openusage` module.

## Waybar Config Addition
```json
"custom/openusage": {
  "exec": "~/.config/waybar/openusage-telemetry.sh",
  "return-type": "json",
  "interval": 60,
  "format": "{icon} {text}"
}
```

## Next Steps
- Write script, update `~/.config/waybar/config`, restart waybar.
