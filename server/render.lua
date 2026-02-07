ExporterRender = {}

local util = ExporterUtil

local function renderLabels(labelNames, labelValues)
    if #labelNames == 0 then
        return ''
    end

    local parts = {}
    for i = 1, #labelNames do
        parts[i] = ('%s="%s"'):format(labelNames[i], util.escapeLabelValue(labelValues[i]))
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

local function renderHistogramLabels(labelNames, labelValues, le)
    local parts = {}
    for i = 1, #labelNames do
        parts[#parts + 1] = ('%s="%s"'):format(labelNames[i], util.escapeLabelValue(labelValues[i]))
    end
    parts[#parts + 1] = ('le="%s"'):format(le)
    return '{' .. table.concat(parts, ',') .. '}'
end

function ExporterRender.render(metricsByName)
    local out = {}
    local metricNames = util.sortedKeys(metricsByName)

    for _, metricName in ipairs(metricNames) do
        local metric = metricsByName[metricName]
        local promType = util.metricTypeToProm(metric.type)

        out[#out + 1] = ('# HELP %s %s\n'):format(metric.name, util.escapeHelp(metric.help))
        out[#out + 1] = ('# TYPE %s %s\n'):format(metric.name, promType)

        local seriesKeys = util.sortedKeys(metric.series)

        if metric.type == 'counter' or metric.type == 'gauge' then
            for _, sk in ipairs(seriesKeys) do
                local series = metric.series[sk]
                local labels = renderLabels(metric.labelNames, series.labels)
                out[#out + 1] = ('%s%s %s\n'):format(metric.name, labels, util.formatNumber(series.value))
            end
        elseif metric.type == 'histogram' then
            for _, sk in ipairs(seriesKeys) do
                local series = metric.series[sk]
                for i = 1, #metric.buckets do
                    local bound = util.formatBucketBoundary(metric.buckets[i])
                    local labels = renderHistogramLabels(metric.labelNames, series.labels, bound)
                    out[#out + 1] = ('%s_bucket%s %s\n'):format(metric.name, labels, util.formatNumber(series.bucketCounts[i]))
                end

                local infLabels = renderHistogramLabels(metric.labelNames, series.labels, '+Inf')
                out[#out + 1] = ('%s_bucket%s %s\n'):format(metric.name, infLabels, util.formatNumber(series.count))

                local baseLabels = renderLabels(metric.labelNames, series.labels)
                out[#out + 1] = ('%s_sum%s %s\n'):format(metric.name, baseLabels, util.formatNumber(series.sum))
                out[#out + 1] = ('%s_count%s %s\n'):format(metric.name, baseLabels, util.formatNumber(series.count))
            end
        end
    end

    return table.concat(out)
end