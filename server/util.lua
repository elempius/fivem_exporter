local METRIC_NAME_PATTERN = '^[a-zA-Z_:][a-zA-Z0-9_:]*$'
local LABEL_NAME_PATTERN = '^[a-zA-Z_][a-zA-Z0-9_]*$'

ExporterUtil = {}

function ExporterUtil.nowResource()
    local invoking = GetInvokingResource()
    if invoking and invoking ~= '' then
        return invoking
    end
    return GetCurrentResourceName()
end

function ExporterUtil.defaultMetricsPath()
    return '/' .. GetCurrentResourceName() .. '/metrics'
end

function ExporterUtil.isFiniteNumber(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

function ExporterUtil.escapeHelp(s)
    return tostring(s):gsub('\\', '\\\\'):gsub('\n', '\\n')
end

function ExporterUtil.escapeLabelValue(s)
    return tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
end

function ExporterUtil.sortedKeys(map)
    local keys = {}
    for k, _ in pairs(map) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

function ExporterUtil.formatNumber(v)
    if math.type and math.type(v) == 'integer' then
        return tostring(v)
    end
    return string.format('%.17g', v)
end

function ExporterUtil.formatBucketBoundary(v)
    if math.type and math.type(v) == 'integer' then
        return tostring(v)
    end
    return string.format('%.15g', v)
end

function ExporterUtil.metricTypeToProm(metricType)
    if metricType == 'counter' then
        return 'counter'
    end
    if metricType == 'gauge' then
        return 'gauge'
    end
    if metricType == 'histogram' then
        return 'histogram'
    end
    return nil
end

function ExporterUtil.metricNamePattern()
    return METRIC_NAME_PATTERN
end

function ExporterUtil.labelNamePattern()
    return LABEL_NAME_PATTERN
end

function ExporterUtil.normalizeResourceNameForMetric(name)
    local normalized = string.lower(name or ''):gsub('[^a-zA-Z0-9_]', '_')
    if normalized == '' then
        normalized = 'resource'
    end
    if not normalized:match('^[a-zA-Z_:]') then
        normalized = 'resource_' .. normalized
    end
    return normalized
end

function ExporterUtil.log(level, ...)
    if not lib or not lib.print then
        return
    end

    local logger = lib.print[level] or lib.print.info
    logger(...)
end

function ExporterUtil.logError(...)
    ExporterUtil.log('error', ...)
end

function ExporterUtil.logWarn(...)
    ExporterUtil.log('warn', ...)
end

function ExporterUtil.logInfo(...)
    ExporterUtil.log('info', ...)
end

function ExporterUtil.logVerbose(...)
    ExporterUtil.log('verbose', ...)
end

function ExporterUtil.logDebug(...)
    ExporterUtil.log('debug', ...)
end