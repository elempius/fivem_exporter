local registry = ExporterRegistry
local http = ExporterHttp
local util = ExporterUtil

local function logError(operation, err)
    util.logError(operation, ' failed: ', err)
end

exports('PromRegisterCounter', function(metricName, help, labelNames, opts)
    local ok, resultOrErr = registry.registerMetric('counter', metricName, help, labelNames, opts)
    if not ok then
        logError('PromRegisterCounter', resultOrErr)
        return false, resultOrErr
    end
    return true, resultOrErr
end)

exports('PromRegisterGauge', function(metricName, help, labelNames, opts)
    local ok, resultOrErr = registry.registerMetric('gauge', metricName, help, labelNames, opts)
    if not ok then
        logError('PromRegisterGauge', resultOrErr)
        return false, resultOrErr
    end
    return true, resultOrErr
end)

exports('PromRegisterHistogram', function(metricName, help, labelNames, opts)
    local ok, resultOrErr = registry.registerMetric('histogram', metricName, help, labelNames, opts)
    if not ok then
        logError('PromRegisterHistogram', resultOrErr)
        return false, resultOrErr
    end
    return true, resultOrErr
end)

exports('PromIncCounter', function(metricName, labels)
    local ok, err = registry.incCounter(metricName, labels)
    if not ok then
        logError('PromIncCounter', err)
        return false, err
    end
    return true
end)

exports('PromAddCounter', function(metricName, delta, labels)
    local ok, err = registry.addCounter(metricName, delta, labels)
    if not ok then
        logError('PromAddCounter', err)
        return false, err
    end
    return true
end)

exports('PromSetGauge', function(metricName, value, labels)
    local ok, err = registry.setGauge(metricName, value, labels)
    if not ok then
        logError('PromSetGauge', err)
        return false, err
    end
    return true
end)

exports('PromIncGauge', function(metricName, labels)
    local ok, err = registry.incGauge(metricName, labels)
    if not ok then
        logError('PromIncGauge', err)
        return false, err
    end
    return true
end)

exports('PromDecGauge', function(metricName, labels)
    local ok, err = registry.decGauge(metricName, labels)
    if not ok then
        logError('PromDecGauge', err)
        return false, err
    end
    return true
end)

exports('PromObserveHistogram', function(metricName, value, labels)
    local ok, err = registry.observeHistogram(metricName, value, labels)
    if not ok then
        logError('PromObserveHistogram', err)
        return false, err
    end
    return true
end)

local internalMetricsOk = registry.initInternalMetrics()
if not internalMetricsOk then
    util.logWarn('continuing without internal exporter metrics')
end
util.logInfo(('initialized metrics exporter; endpoint: %s'):format(util.defaultMetricsPath()))
http.setup()