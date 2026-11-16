-- Unblockable Attack Indicator -> Style: the pictures images/unblockable_<x>.png,
-- listed by MCT each time the settings page is built. Self-contained: it runs in
-- the menu's Lua state as well as the templates'.
return function(context)
    local names,why=context.files('images')
    if not names then return nil,why end
    local keys,seen={},{}
    for _,name in ipairs(names) do
        local key=name:lower():match('^unblockable_([%w_]+)%.png$')
        if key and not seen[key] then seen[key]=true; keys[#keys+1]=key end
    end
    table.sort(keys)
    local out={}
    for index,key in ipairs(keys) do
        out[index]={key=key,label=(key:gsub('_',' '):gsub('(%a)(%w*)',function(a,b) return a:upper()..b end))}
    end
    return out
end
