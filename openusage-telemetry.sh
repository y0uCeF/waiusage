#!/usr/bin/env bash
# openusage-telemetry.sh
# Query the OpenUsage telemetry Unix socket and report per-provider credit/usage.
# Default output is a single Waybar JSON object: {"text":...,"class":...,"tooltip":...}
#
# Semantics per provider (map in METRICS below):
#   copilot    -> premium_interactions_quota : used/limit  (interactions, resets monthly)
#   openrouter -> credit_balance             : used/limit  ($, lifetime credit pool)
#   deepseek   -> total_balance              : remaining/total  ($, no separate cap)
#   hermes     -> total_cost_usd             : spent cost (no credit pool; shown as-is)
#
# Provider list filters which of the ABOVE supported providers are shown
# (any listed name not present in the telemetry is simply skipped).
# Unset / empty => show all supported providers found.
#
# Usage:
#   ./openusage-telemetry.sh                          # Waybar JSON (default), all providers
#   ./openusage-telemetry.sh --plain                  # human-readable lines
#   ./openusage-telemetry.sh --providers copilot,openrouter   # only those, in list order
#   OPENUSAGE_PROVIDERS=copilot,deepseek ./script     # same via env var (flag wins)
#
# Env vars:
#   OPENUSAGE_SOCK       socket path override (default $HOME/.local/state/openusage/telemetry.sock)
#   OPENUSAGE_PROVIDERS  comma-separated provider list to show (e.g. "copilot,openrouter")
set -euo pipefail

SOCK="${OPENUSAGE_SOCK:-$HOME/.local/state/openusage/telemetry.sock}"
ENDPOINT="http://localhost/v1/read-model"

# ---- arg parsing: --plain, --providers list ----
plain_mode=0
providers="${OPENUSAGE_PROVIDERS:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --plain)          plain_mode=1; shift ;;
    --providers)      providers="$2"; shift 2 ;;
    --providers=*)    providers="${1#--providers=}"; shift ;;
    *) shift ;;       # ignore unknown args
  esac
done

raw="$(curl --unix-socket "$SOCK" -X POST -d '{"test":true}' -s \
      -H 'Content-Type: application/json' "$ENDPOINT")" || {
    echo "openusage: socket-error" >&2
    exit 1
}

python3 - "$raw" "$plain_mode" "$providers" <<'PY'
import json, sys

raw, plain, providers_arg = sys.argv[1], sys.argv[2] == "1", (sys.argv[3] if len(sys.argv) > 3 else "")
try:
    snaps = json.loads(raw).get("snapshots", {})
except json.JSONDecodeError:
    print('{"text":"openusage: parse-error"}')
    sys.exit(1)

# metric_key -> (kind) ; kind "quota" (has used+limit), "balance" (has remaining), "ledger" (cost only)
METRICS = {
    "copilot":   ("premium_interactions_quota", "quota"),
    "openrouter":("credit_balance",             "quota"),
    "deepseek":  ("total_balance",              "balance"),
    "hermes":    ("total_cost_usd",             "ledger"),
}

def fmt(v, decimals):
    if v is None:
        return ""
    v = float(v)
    if decimals == 0:
        return str(int(round(v)))
    return f"{v:.{decimals}f}"       # currency: keep the full precision, don't strip zeros

def ndigits(unit):
    """Quota-like units are whole numbers; money keeps 2 decimal places."""
    return 0 if (unit or "").lower() in (
        "requests", "interactions", "tokens", "sessions", "calls", "messages") else 2

def current_total(m, kind):
    """Return (current, total) strings for a metric dict."""
    used, lim, rem = m.get("used"), m.get("limit"), m.get("remaining")
    nd = ndigits(m.get("unit"))
    if kind == "quota":
        if lim is None:
            return fmt(used, nd), ""
        return fmt(used, nd), fmt(lim, nd)
    if kind == "balance":
        cur, tot = fmt(rem, nd), fmt(lim, nd)
        if not tot:
            tot = fmt(rem, nd)    # no separate cap -> total = remaining
        return cur, tot
    return fmt(used, nd), ""      # ledger: no credits to spend

# Provider selection: an explicit list (kept in user order) restricts which supported
# providers show; otherwise every supported provider found in the telemetry is shown (alphabetical).
allowed = [p.strip() for p in providers_arg.replace(";", ",").split(",") if p.strip()] \
          if providers_arg else None
order = allowed if allowed is not None else sorted(snaps)

# ---- Presentation: icons (bar) + human names (tooltip). Edit glyphs/names to taste. ----
META = {
    "copilot":   ("◆",    "Copilot"),
    "deepseek":  ("🐋",   "DeepSeek"),
    "hermes":    ("🎩",   "Hermes"),
    "openrouter":("🟠",   "OpenRouter"),
}
# Reset/expiry note per provider (field name -> label), pulled from the snapshot's resets.
RESET_NOTES = {"quota_reset": "resets", "key_expires": "key expires"}

def tooltip_note(prov):
    res = snaps[prov].get("resets") or {}
    for field, label in RESET_NOTES.items():
        if res.get(field):
            raw = res[field][:10]
            try:
                from datetime import datetime as _dt
                pretty = _dt.strptime(raw, "%Y-%m-%d").strftime("%b %d")
            except ValueError:
                pretty = raw
            return f"{label} {pretty}"
    return ""

names, widgets, tips = [], [], []
degraded = False
for prov in order:
    cfg = METRICS.get(prov)
    if not cfg or prov not in snaps:
        continue            # unknown provider, or absent from this telemetry snapshot
    key, kind = cfg
    icon, disp = META.get(prov, (prov, prov))
    m = (snaps[prov].get("metrics") or {}).get(key) or {}
    cur, tot = current_total(m, kind)
    if not cur:
        degraded = True     # present but unusable (e.g. AUTH_REQUIRED, no metric) -> flag it
        names.append(f"{prov}: ⚠")
        widgets.append(f"{icon} ⚠".strip())
        tips.append(f"{disp}: {snaps[prov].get('status') or 'unavailable'}")
        continue
    unit = (m.get("unit") or "").lower()
    val = f"{cur}/{tot}" if tot and tot != cur else f"{cur}"
    names.append(f"{prov}: {val}")
    widgets.append(f"{icon} {val}".strip())
    t = f"{disp}: {val}"
    if unit and unit != "usd":
        t += f" {unit}"
    note = tooltip_note(prov)
    if note:
        t += f" · {note}"
    tips.append(t)

css_class = "openusage warning" if degraded else "openusage"
if plain:
    for ln in names:
        print(ln)
else:
    print(json.dumps({"text": "  ·  ".join(widgets), "class": css_class, "tooltip": "\n".join(tips)}))
PY