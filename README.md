# fivem_exporter

## Overview
Lightweight FiveM server-side Prometheus exporter resource.

## Requirements
- `ox_lib`

## Configuration
- Auth: optional HTTP Basic auth via `Config.BasicAuth`
- Endpoint: `https://<host>:30120/<resource_name>/metrics`

## Built-in Metrics
- `<resource>_metrics_registered`
- `<resource>_series_total`

## Example: Player Count Gauge
Add this to a server script in your own resource (not inside `fivem_exporter`):

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