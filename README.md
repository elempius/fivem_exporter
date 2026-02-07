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