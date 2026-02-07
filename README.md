# fivem_exporter

## Overview
Lightweight FiveM server-side Prometheus exporter resource.

## Requirements
- `ox_lib`

## Configuration
- Auth: optional HTTP Basic auth via `Config.BasicAuth`
- Endpoint: `https://<host>:30120/<resource_name>/metrics`
- Global labels: optional static labels via `Config.GlobalLabels` (added to every metric series)

## Built-in Metrics
- `<resource>_metrics_registered`
- `<resource>_series_total`

## Example: Player Count Gauge
Add this to a server script in your own resource.

```lua
local exporter = exports['fivem_exporter']
local METRIC_NAME = 'my_resource_players_online'

CreateThread(function()
    exporter:PromRegisterGauge(
        METRIC_NAME,
        'Current number of connected players',
        {},
        nil
    )

    -- Initialize once, then track join/leave deltas.
    exporter:PromSetGauge(METRIC_NAME, #GetPlayers())
end)

AddEventHandler('playerJoining', function()
    exporter:PromIncGauge(METRIC_NAME)
end)

AddEventHandler('playerDropped', function()
    exporter:PromDecGauge(METRIC_NAME)
end)
```

This will expose:
- `my_resource_players_online` metric that will report the count of players in the server.

## Global Labels
Set static labels in `config.lua`:

```lua
GlobalLabels = {
    environment = 'production',
    server = 'main'
}
```

Behavior:
- The labels are appended to every metric series automatically.
- Exported resources cannot provide or override these keys.
- Declared metric labels cannot reuse a global label name.