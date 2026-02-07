Config = {
    AllowSharedMetricsWhenDefinitionMatches = false,
    MaxSeriesPerMetric = 1000,
    MaxLabelsPerMetric = 10,
    MaxLabelValueLength = 128,

    BasicAuth = {
        Enabled = false,
        Username = 'metrics',
        Password = 'change_me',
        Realm = 'fivem_exporter'
    },
    DefaultHistogramBuckets = {
        0.005,
        0.01,
        0.025,
        0.05,
        0.1,
        0.25,
        0.5,
        1,
        2.5,
        5,
        10
    }
}