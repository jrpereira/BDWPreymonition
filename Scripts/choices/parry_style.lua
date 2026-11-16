-- Omens Overlay -> Parry & Block Indicator -> Style: after Off, the pictures in images/
-- (Chevron, Fancy and Solid ship), each omen_<style>.png (glow and core side by side, made by
-- tools/make_omen_layers.py), listed each time the settings page is built. A picture the
-- Omens cannot draw is left out: one that is not a PNG, or not WIDTH by HEIGHT (two
-- halves laid out like Fancy's art). Self-contained: it runs in the menu's Lua state as
-- well as the templates'.
local WIDTH,HEIGHT=1774,1774
local SIGNATURE='\137PNG\r\n\26\n'

-- Whether a picture's header says it is a WIDTH by HEIGHT PNG. Without context.head (an
-- older ModCore Settings) it cannot tell, and the picture is listed.
local function drawable(context,name)
    if type(context.head)~='function' then return true end
    local bytes=context.head('images/'..name,24)
    if type(bytes)~='string' or #bytes<24 or bytes:sub(1,8)~=SIGNATURE or bytes:sub(13,16)~='IHDR' then return false end
    local width,height=string.unpack('>I4>I4',bytes,17)
    return width==WIDTH and height==HEIGHT
end

return function(context)
    local names,why=context.files('images')
    if not names then return nil,why end
    local keys,seen={},{}
    for _,name in ipairs(names) do
        local key=name:lower():match('^omen_([%w_]+)%.png$')
        if key and not seen[key] and drawable(context,name) then seen[key]=true; keys[#keys+1]=key end
    end
    table.sort(keys)
    local out={}
    for index,key in ipairs(keys) do
        out[index]={key=key,label=(key:gsub('_',' '):gsub('(%a)(%w*)',function(a,b) return a:upper()..b end))}
    end
    return out
end
