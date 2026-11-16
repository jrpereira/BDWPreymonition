-- Edges Flash -> Visuals -> Style: the pictures images/edge_<x>_v.png that have a
-- matching images/edge_<x>_h.png, listed by MCT each time the settings page is
-- built. Self-contained: it runs in the menu's Lua state as well as the templates'.
return function(context)
    local names,why=context.files('images')
    if not names then return nil,why end
    local found={}
    for _,name in ipairs(names) do
        local key,side=name:lower():match('^edge_([%w_]+)_([vh])%.png$')
        if key then
            found[key]=found[key] or {}
            found[key][side]=true
        end
    end
    local keys={}
    for key,sides in pairs(found) do
        if sides.v and sides.h then keys[#keys+1]=key end
    end
    table.sort(keys)
    local out={}
    for index,key in ipairs(keys) do
        out[index]={key=key,label=(key:gsub('_',' '):gsub('(%a)(%w*)',function(a,b) return a:upper()..b end))}
    end
    return out
end
