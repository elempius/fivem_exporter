ExporterRegistry = {}

local util = ExporterUtil
local validate = ExporterValidate
local render = ExporterRender

local state = {
    metricsByName = {},
    dirty = true,
    cachedBody = '',
    internal = {
        initialized = false,
        metricsGauge = nil,
        seriesGauge = nil
    }
}

local function markDirty()
    state.dirty = true
end

local function buildLabelMap(labelNames)
    local map = {}
    for i = 1, #labelNames do
        map[labelNames[i]] = true
    end
    return map
end

local function buildSeriesSignature(labelValues)
    return table.concat(labelValues, '\31')
end

local function definitionsMatch(a, b)
    if a.type ~= b.type then
        return false
    end
    if a.help ~= b.help then
        return false
    end
    if #a.labelNames ~= #b.labelNames then
        return false
    end

    for i = 1, #a.labelNames do
        if a.labelNames[i] ~= b.labelNames[i] then
            return false
        end
    end

    if a.type == 'histogram' then
        if #a.buckets ~= #b.buckets then
            return false
        end
        for i = 1, #a.buckets do
            if a.buckets[i] ~= b.buckets[i] then
                return false
            end
        end
    end

    return true
end

local function getMetric(metricName)
    local owner = util.nowResource()
    local metric = state.metricsByName[metricName]

    if not metric then
        return nil, ('metric "%s" is not registered'):format(metricName)
    end

    if not metric.owners[owner] then
        return nil, ('resource "%s" is not allowed to modify metric "%s"'):format(owner, metric.name)
    end

    return metric, nil
end

local function setGaugeDirect(metricName, value)
    local metric = state.metricsByName[metricName]
    if not metric then
        return
    end

    local signature = ''
    local series = metric.series[signature]
    if not series then
        series = { labels = {}, value = 0 }
        metric.series[signature] = series
        metric.seriesCount = metric.seriesCount + 1
    end

    series.value = value
end

local function recalcInternalGauges()
    if not state.internal.initialized then
        return
    end

    local metricCount = 0
    local seriesCount = 0
    for _, metric in pairs(state.metricsByName) do
        metricCount = metricCount + 1
        seriesCount = seriesCount + metric.seriesCount
    end

    setGaugeDirect(state.internal.metricsGauge, metricCount)
    setGaugeDirect(state.internal.seriesGauge, seriesCount)
end

local function getOrCreateSeries(metric, labelValues)
    local signature = buildSeriesSignature(labelValues)
    local series = metric.series[signature]
    if series then
        return true, series
    end

    if metric.seriesCount >= Config.MaxSeriesPerMetric then
        return false, nil, ('metric "%s" reached max series (%d)'):format(metric.name, Config.MaxSeriesPerMetric)
    end

    if metric.type == 'counter' or metric.type == 'gauge' then
        series = {
            labels = labelValues,
            value = 0
        }
    elseif metric.type == 'histogram' then
        local bucketCounts = {}
        for i = 1, #metric.buckets do
            bucketCounts[i] = 0
        end
        series = {
            labels = labelValues,
            count = 0,
            sum = 0,
            bucketCounts = bucketCounts
        }
    else
        return false, nil, 'unknown metric type'
    end

    metric.series[signature] = series
    metric.seriesCount = metric.seriesCount + 1
    recalcInternalGauges()
    markDirty()

    return true, series
end

function ExporterRegistry.registerMetric(metricType, metricName, help, labelNames, opts)
    local owner = util.nowResource()
    local fullName = metricName
    local ok, err = validate.validateMetricName(fullName)
    if not ok then
        return false, err
    end

    if type(help) ~= 'string' or help == '' then
        return false, 'help must be a non-empty string'
    end

    local validLabels, normalizedLabelsOrErr = validate.validateLabelNames(labelNames)
    if not validLabels then
        return false, normalizedLabelsOrErr
    end
    local normalizedLabels = normalizedLabelsOrErr

    local buckets = nil
    if metricType == 'histogram' then
        local bucketOk, bucketsOrErr = validate.normalizeBuckets(opts and opts.buckets or nil)
        if not bucketOk then
            return false, bucketsOrErr
        end
        buckets = bucketsOrErr
    end

    local definition = {
        name = fullName,
        owner = owner,
        owners = { [owner] = true },
        type = metricType,
        help = help,
        labelNames = normalizedLabels,
        labelNameSet = buildLabelMap(normalizedLabels),
        buckets = buckets,
        series = {},
        seriesCount = 0
    }

    local existing = state.metricsByName[fullName]
    if existing then
        if existing.owner == owner then
            if not definitionsMatch(existing, definition) then
                return false, ('metric "%s" already exists with a different definition'):format(fullName)
            end
            util.logDebug('metric already registered by same owner: ', fullName, ' owner=', owner)
            return true, fullName
        end

        if not Config.AllowSharedMetricsWhenDefinitionMatches then
            return false, ('metric "%s" already owned by resource "%s"'):format(fullName, existing.owner)
        end

        if not definitionsMatch(existing, definition) then
            return false, ('metric "%s" conflict: shared metrics require identical definitions'):format(fullName)
        end

        existing.owners[owner] = true
        util.logDebug('metric shared by owner: ', fullName, ' owner=', owner)
        return true, fullName
    end

    state.metricsByName[fullName] = definition
    util.logDebug('registered metric: ', fullName, ' type=', metricType, ' owner=', owner)
    recalcInternalGauges()
    markDirty()
    return true, fullName
end

local function setCounter(metricName, delta, labels)
    local metric, err = getMetric(metricName)
    if not metric then
        return false, err
    end
    if metric.type ~= 'counter' then
        return false, ('metric "%s" is not a counter'):format(metricName)
    end
    if not util.isFiniteNumber(delta) or delta < 0 then
        return false, 'counter increments must be finite numbers greater than or equal to 0'
    end

    local ok, labelValues, labelErr = validate.normalizeLabelValues(metric, labels)
    if not ok then
        return false, labelErr
    end

    local seriesOk, series, seriesErr = getOrCreateSeries(metric, labelValues)
    if not seriesOk then
        return false, seriesErr
    end

    series.value = series.value + delta
    markDirty()
    return true
end

local function setGauge(metricName, op, amount, labels)
    local metric, err = getMetric(metricName)
    if not metric then
        return false, err
    end
    if metric.type ~= 'gauge' then
        return false, ('metric "%s" is not a gauge'):format(metricName)
    end

    local ok, labelValues, labelErr = validate.normalizeLabelValues(metric, labels)
    if not ok then
        return false, labelErr
    end

    local seriesOk, series, seriesErr = getOrCreateSeries(metric, labelValues)
    if not seriesOk then
        return false, seriesErr
    end

    if op == 'set' then
        if not util.isFiniteNumber(amount) then
            return false, 'gauge set value must be a finite number'
        end
        series.value = amount
    elseif op == 'add' then
        if not util.isFiniteNumber(amount) then
            return false, 'gauge delta must be a finite number'
        end
        series.value = series.value + amount
    else
        return false, 'unknown gauge operation'
    end

    markDirty()
    return true
end

local function observeHistogram(metricName, value, labels)
    local metric, err = getMetric(metricName)
    if not metric then
        return false, err
    end
    if metric.type ~= 'histogram' then
        return false, ('metric "%s" is not a histogram'):format(metricName)
    end
    if not util.isFiniteNumber(value) then
        return false, 'histogram observations must be finite numbers'
    end

    local ok, labelValues, labelErr = validate.normalizeLabelValues(metric, labels)
    if not ok then
        return false, labelErr
    end

    local seriesOk, series, seriesErr = getOrCreateSeries(metric, labelValues)
    if not seriesOk then
        return false, seriesErr
    end

    series.count = series.count + 1
    series.sum = series.sum + value

    for i = 1, #metric.buckets do
        if value <= metric.buckets[i] then
            series.bucketCounts[i] = series.bucketCounts[i] + 1
        end
    end

    markDirty()
    return true
end

function ExporterRegistry.incCounter(metricName, labels)
    return setCounter(metricName, 1, labels)
end

function ExporterRegistry.addCounter(metricName, delta, labels)
    return setCounter(metricName, delta, labels)
end

function ExporterRegistry.setGauge(metricName, value, labels)
    return setGauge(metricName, 'set', value, labels)
end

function ExporterRegistry.incGauge(metricName, labels)
    return setGauge(metricName, 'add', 1, labels)
end

function ExporterRegistry.decGauge(metricName, labels)
    return setGauge(metricName, 'add', -1, labels)
end

function ExporterRegistry.observeHistogram(metricName, value, labels)
    return observeHistogram(metricName, value, labels)
end

function ExporterRegistry.renderMetrics()
    if not state.dirty then
        return state.cachedBody
    end

    state.cachedBody = render.render(state.metricsByName)
    state.dirty = false
    return state.cachedBody
end

function ExporterRegistry.initInternalMetrics()
    if state.internal.initialized then
        return true
    end

    local prefix = util.normalizeResourceNameForMetric(GetCurrentResourceName())
    local metricCount = prefix .. '_metrics_registered'
    local seriesCount = prefix .. '_series_total'

    local ok1 = ExporterRegistry.registerMetric('gauge', metricCount, 'Number of registered metrics', {}, nil)
    local ok2 = ExporterRegistry.registerMetric('gauge', seriesCount, 'Number of active metric series', {}, nil)
    if not ok1 or not ok2 then
        util.logWarn('failed to initialize one or more internal exporter metrics')
        return false
    end

    state.internal.metricsGauge = metricCount
    state.internal.seriesGauge = seriesCount
    state.internal.initialized = true

    recalcInternalGauges()
    markDirty()
    util.logInfo('internal exporter metrics initialized')
    return true
end