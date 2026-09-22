#!/bin/bash
DB="$HOME/.local/state/openusage/telemetry.db"
RESULT=$(sqlite3 -separator ' ' "$DB" "SELECT provider_id, COUNT(*) FROM usage_events GROUP BY provider_id ORDER BY COUNT(*) DESC LIMIT 1;" 2>/dev/null)
provider=$(echo "$RESULT" | awk '{print $1}')
count=$(echo "$RESULT" | awk '{print $2}')
provider=${provider:-none}
count=${count:-0}
echo '{"text":"'"$provider:$count"'","tooltip":"OpenUsage telemetry: '"$provider"' ('"$count"' events)","class":"telemetry"}'
