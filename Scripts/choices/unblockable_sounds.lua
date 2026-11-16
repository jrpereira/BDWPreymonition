-- Audio Cues -> Sounds -> Unblockable Attack: the mod's unblockable sounds
-- sounds/unblockable_<x>.wav, listed by ModCore Settings each time the settings
-- page is built, after None. Self-contained: it runs in the menu's Lua state.
return function(context)
    local names,why=context.files('sounds')
    if not names then return nil,why end
    local keys,seen={},{}
    for _,name in ipairs(names) do
        local key=name:lower():match('^unblockable_([%w_]+)%.wav$')
        if key and not seen[key] then seen[key]=true; keys[#keys+1]=key end
    end
    table.sort(keys)
    local out={}
    for index,key in ipairs(keys) do
        -- The file itself plays when the choice is selected (centred).
        out[index]={key=key,sound='sounds/unblockable_'..key..'.wav',
            label=(key:gsub('_',' '):gsub('(%a)(%w*)',function(a,b) return a:upper()..b end))}
    end
    return out
end
