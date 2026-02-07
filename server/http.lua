ExporterHttp = {}

local util = ExporterUtil
local registry = ExporterRegistry

local BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64Encode(input)
    local out = {}
    local len = #input
    local i = 1

    while i <= len do
        local b1 = string.byte(input, i) or 0
        local b2 = string.byte(input, i + 1) or 0
        local b3 = string.byte(input, i + 2) or 0
        local n = b1 * 65536 + b2 * 256 + b3

        local c1 = math.floor(n / 262144) % 64 + 1
        local c2 = math.floor(n / 4096) % 64 + 1
        local c3 = math.floor(n / 64) % 64 + 1
        local c4 = n % 64 + 1

        out[#out + 1] = BASE64_CHARS:sub(c1, c1)
        out[#out + 1] = BASE64_CHARS:sub(c2, c2)

        if i + 1 <= len then
            out[#out + 1] = BASE64_CHARS:sub(c3, c3)
        else
            out[#out + 1] = '='
        end

        if i + 2 <= len then
            out[#out + 1] = BASE64_CHARS:sub(c4, c4)
        else
            out[#out + 1] = '='
        end

        i = i + 3
    end

    return table.concat(out)
end

local function secureStringEquals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' then
        return false
    end
    if #a ~= #b then
        return false
    end

    local diff = 0
    for i = 1, #a do
        if string.byte(a, i) ~= string.byte(b, i) then
            diff = diff + 1
        end
    end
    return diff == 0
end

local function getHeader(req, key)
    if type(req) ~= 'table' or type(req.headers) ~= 'table' then
        return nil
    end

    local direct = req.headers[key] or req.headers[string.lower(key)] or req.headers[string.upper(key)]
    if direct ~= nil then
        return direct
    end

    local target = string.lower(key)
    for headerKey, headerValue in pairs(req.headers) do
        if type(headerKey) == 'string' and string.lower(headerKey) == target then
            return headerValue
        end
    end
    return nil
end

local function escapedRealm(realm)
    return tostring(realm):gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function unauthorized(res, realm)
    res.writeHead(401, {
        ['Content-Type'] = 'text/plain; charset=utf-8',
        ['WWW-Authenticate'] = ('Basic realm="%s"'):format(escapedRealm(realm))
    })
    res.send('unauthorized\n')
end

local function normalizePath(path)
    local normalized = tostring(path or '/')
    if normalized == '' then
        return '/'
    end
    local queryStart = normalized:find('?', 1, true)
    if queryStart then
        normalized = normalized:sub(1, queryStart - 1)
    end
    if #normalized > 1 then
        normalized = normalized:gsub('/+$', '')
        if normalized == '' then
            normalized = '/'
        end
    end
    return normalized
end

function ExporterHttp.setup()
    util.logInfo('registering HTTP handler for metrics endpoint')
    local basicAuthConfig = Config.BasicAuth or {}
    local authEnabled = basicAuthConfig.Enabled == true
    local authRealm = basicAuthConfig.Realm or GetCurrentResourceName()
    local expectedAuthorization = nil
    local authConfigValid = true

    if authEnabled then
        local username = basicAuthConfig.Username
        local password = basicAuthConfig.Password

        if type(username) ~= 'string' or username == '' or type(password) ~= 'string' or password == '' then
            authConfigValid = false
            util.logError('basic auth is enabled but username/password are missing or invalid')
        else
            expectedAuthorization = 'Basic ' .. base64Encode(username .. ':' .. password)
            util.logInfo('basic auth enabled for metrics endpoint')
        end
    end

    SetHttpHandler(function(req, res)
        local path = normalizePath(req.path)
        local metricsPath = normalizePath(util.defaultMetricsPath())
        local localMetricsPath = '/metrics'

        if path ~= metricsPath and path ~= localMetricsPath then
            res.writeHead(404, {
                ['Content-Type'] = 'text/plain; charset=utf-8'
            })
            res.send('not found\n')
            return
        end

        if authEnabled then
            if not authConfigValid then
                res.writeHead(500, {
                    ['Content-Type'] = 'text/plain; charset=utf-8'
                })
                res.send('exporter auth misconfigured\n')
                return
            end

            local authorization = getHeader(req, 'authorization')
            if not secureStringEquals(authorization, expectedAuthorization) then
                util.logDebug('unauthorized scrape request path=', path)
                unauthorized(res, authRealm)
                return
            end
        end

        local body = registry.renderMetrics()
        util.logVerbose('scrape served path=', path)

        res.writeHead(200, {
            ['Content-Type'] = 'text/plain; version=0.0.4; charset=utf-8',
            ['Cache-Control'] = 'no-store'
        })
        res.send(body)
    end)
end