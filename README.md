# fivem_exporter

FiveM server-side Prometheus exporter resource.
Dependency: `ox_lib`
Auth: optional HTTP Basic auth via `Config.BasicAuth`

Endpoint: `https://<host>:30120/<resource_name>/metrics`

Built-in exporter metrics include:
- `<resource>_metrics_registered`
- `<resource>_series_total`
