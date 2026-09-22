# waiusage — Waybar OpenUsage Telemetry Module (◕‿◕) ★

Dynamic Waybar `custom` module that queries the **OpenUsage telemetry daemon** over its
Unix socket and shows each provider's credit/usage as `provider: current/total`
(e.g. `copilot: 1465/1500`, `openrouter: 5.4/10`).

## What it reports

| Provider  | Metric                     | Meaning                          |
|-----------|----------------------------|----------------------------------|
| copilot   | premium_interactions_quota | used / monthly limit (interactions) |
| deepseek  | total_balance              | \$ balance (no separate cap)     |
| hermes    | total_cost_usd             | \$ spent (ledger, no credit pool)|
| openrouter| credit_balance             | \$ used / \$ lifetime credit pool |

Quota-style metrics show whole numbers (interactions/tokens), money keeps one decimal.
Copilot's quota resets on the 1st; OpenRouter's key expires 2026-12-21.

**Look & feel:** the bar uses icons per provider (`copilot ◆ · deepseek 🐋 · hermes 🎩 ·
openrouter 🟠`) for a compact readout, with full provider names + units + reset/expiry
dates shown on hover (tooltip). Glyphs/names are easy to swap — edit the `META` table at
the top of the script's Python block. `--plain` prints names instead of icons.

## Install
```bash
git clone git@github.com:y0uCeF/waiusage.git
cp waiusage/openusage-telemetry.sh ~/.config/waybar/
chmod +x ~/.config/waybar/openusage-telemetry.sh
```
The script queries the daemon socket directly — no DB access, no root needed.

## Use

Add a `custom/openusage` block to `~/.config/waybar/config` (full snippet in
`config-snippet.jsonc`, `exec` pointing at the installed copy):
```json
"custom/openusage": {
  "exec": "$HOME/.config/waybar/openusage-telemetry.sh",
  "return-type": "json",
  "interval": 300,
  "signal": 4,             // live refresh: pkill -RTMIN+4
  "format": "{}",
  "tooltip": true
}
```
Then reload Waybar. It polls every 300s; force a refresh with `pkill -RTMIN+4`. ♪

## Configure which providers to show

By default every supported provider found is shown. To restrict the bar to a subset
(often to drop `hermes`, a cost ledger), set `OPENUSAGE_PROVIDERS` in the exec line —
order is preserved, and names missing from the telemetry are skipped:
```json
"custom/openusage": {
  "exec": "OPENUSAGE_PROVIDERS=copilot,openrouter $HOME/.config/waybar/openusage-telemetry.sh",
  "return-type": "json",
  "interval": 300,
  "signal": 4,             // live refresh: pkill -RTMIN+4
  "format": "{}",
  "tooltip": false
}
```
Alternatively pass the list as an argument: `./openusage-telemetry.sh --providers copilot,openrouter`
(the flag beats the env var). Note: the list only selects among the supported providers
(`copilot`, `openrouter`, `deepseek`, `hermes`), and a bare `"providers"` key inside the
Waybar module block won't reach the script — Waybar forwards only `exec` to custom modules.

## Manual run
```bash
./openusage-telemetry.sh                                      # Waybar JSON (default), all providers
./openusage-telemetry.sh --plain                              # human-readable "provider: current/total" lines
./openusage-telemetry.sh --providers copilot,openrouter       # only those, in list order (flag beats env)
```

## Options
- `OPENUSAGE_SOCK` env var — override the socket path (default `$HOME/.local/state/openusage/telemetry.sock`)
- `OPENUSAGE_PROVIDERS` env var — comma-separated provider list to show (e.g. `copilot,openrouter`)
- `--plain` flag — print readable lines instead of JSON (shown above)
- `--providers "a,b"` flag — provider list via argument (overrides the env var)

## Requirements
`curl` and `python3` (used only for parsing the JSON response).