-- File-backed toggles. DMM owns saving; this module never writes user settings.
local M = {}
function M.parse(text)
    local result = { Enabled = 1, Debug = 0 }
    if text == nil then return result end
    assert(type(text) == 'string', 'Configuration must be text')
    local section
    for line in text:gmatch('[^\r\n]+') do
        line = line:gsub('^%s+', ''):gsub('%s+$', '')
        local heading = line:match('^%[([^%]]+)%]$')
        if heading then section = heading end
        if section == 'General' then
            local key, value = line:match('^([%w_]+)%s*=%s*([^;#]*)')
            if key and result[key] ~= nil then
                local number = tonumber(value)
                assert(number == 0 or number == 1, 'Invalid toggle: '..key)
                result[key] = number
            end
        end
    end
    assert(text:match('%[General%]'), 'Missing General section')
    return result
end
return M
