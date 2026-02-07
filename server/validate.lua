ExporterValidate = {}

local util = ExporterUtil

function ExporterValidate.validateMetricName(name)
    if type(name) ~= 'string' or name == '' then
        return false, 'metric name must be a non-empty string'
    end
    if not name:match(util.metricNamePattern()) then
        return false, ('invalid metric name "%s"'):format(name)
    end
    return true
end

function ExporterValidate.validateLabelNames(labelNames)
    if labelNames == nil then
        return true, {}
    end
    if type(labelNames) ~= 'table' then
        return false, 'label names must be an array of strings'
    end

    local normalized = {}
    local seen = {}
    if #labelNames > Config.MaxLabelsPerMetric then
        return false, ('too many labels; max is %d'):format(Config.MaxLabelsPerMetric)
    end

    for i = 1, #labelNames do
        local labelName = labelNames[i]
        if type(labelName) ~= 'string' or labelName == '' then
            return false, 'label names must be non-empty strings'
        end
        if not labelName:match(util.labelNamePattern()) then
            return false, ('invalid label name "%s"'):format(labelName)
        end
        if labelName:sub(1, 2) == '__' then
            return false, ('reserved label name "%s"'):format(labelName)
        end
        if labelName == 'le' then
            return false, 'label name "le" is reserved for histogram buckets'
        end
        if seen[labelName] then
            return false, ('duplicate label name "%s"'):format(labelName)
        end

        seen[labelName] = true
        normalized[#normalized + 1] = labelName
    end

    return true, normalized
end

function ExporterValidate.normalizeBuckets(buckets)
    local inBuckets = buckets or Config.DefaultHistogramBuckets
    if type(inBuckets) ~= 'table' or #inBuckets == 0 then
        return false, 'histogram buckets must be a non-empty numeric array'
    end

    local out = {}
    local seen = {}
    for i = 1, #inBuckets do
        local b = inBuckets[i]
        if not util.isFiniteNumber(b) then
            return false, 'histogram bucket boundaries must be finite numbers'
        end
        if seen[b] then
            return false, ('duplicate histogram bucket boundary %s'):format(tostring(b))
        end
        seen[b] = true
        out[#out + 1] = b
    end

    table.sort(out, function(a, b)
        return a < b
    end)

    return true, out
end

function ExporterValidate.normalizeLabelValues(metric, labels)
    if labels == nil then
        labels = {}
    end
    if type(labels) ~= 'table' then
        return false, nil, 'labels must be a table keyed by declared label names'
    end

    local labelValues = {}
    for i = 1, #metric.userLabelNames do
        local key = metric.userLabelNames[i]
        local val = labels[key]
        if val == nil then
            return false, nil, ('missing required label "%s"'):format(key)
        end

        local stringVal = tostring(val)
        if #stringVal > Config.MaxLabelValueLength then
            return false, nil, ('label value too long for "%s" (max %d)'):format(key, Config.MaxLabelValueLength)
        end

        labelValues[i] = stringVal
    end

    for i = 1, #metric.globalLabelNames do
        labelValues[#labelValues + 1] = metric.globalLabelValues[i]
    end

    for key, _ in pairs(labels) do
        if metric.globalLabelNameSet[key] then
            return false, nil, ('label "%s" is reserved as a configured global label'):format(tostring(key))
        end
        if not metric.userLabelNameSet[key] then
            return false, nil, ('unknown label "%s" for metric "%s"'):format(tostring(key), metric.name)
        end
    end

    return true, labelValues, nil
end

function ExporterValidate.normalizeGlobalLabels(globalLabels)
    if globalLabels == nil then
        return true, {}, {}
    end
    if type(globalLabels) ~= 'table' then
        return false, nil, nil, 'global labels must be a table keyed by label name'
    end

    local names = {}
    local valuesByName = {}

    for labelName, labelValue in pairs(globalLabels) do
        if type(labelName) ~= 'string' or labelName == '' then
            return false, nil, nil, 'global label names must be non-empty strings'
        end
        if not labelName:match(util.labelNamePattern()) then
            return false, nil, nil, ('invalid global label name "%s"'):format(labelName)
        end
        if labelName:sub(1, 2) == '__' then
            return false, nil, nil, ('reserved global label name "%s"'):format(labelName)
        end
        if labelName == 'le' then
            return false, nil, nil, 'global label name "le" is reserved for histogram buckets'
        end
        if labelValue == nil then
            return false, nil, nil, ('global label "%s" cannot be nil'):format(labelName)
        end

        local stringVal = tostring(labelValue)
        if #stringVal > Config.MaxLabelValueLength then
            return false, nil, nil, ('global label value too long for "%s" (max %d)'):format(labelName, Config.MaxLabelValueLength)
        end

        names[#names + 1] = labelName
        valuesByName[labelName] = stringVal
    end

    table.sort(names)
    if #names > Config.MaxLabelsPerMetric then
        return false, nil, nil, ('too many global labels; max is %d'):format(Config.MaxLabelsPerMetric)
    end

    local values = {}
    for i = 1, #names do
        local name = names[i]
        values[i] = valuesByName[name]
    end

    return true, names, values, nil
end