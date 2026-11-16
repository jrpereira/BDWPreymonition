-- The list files MCT runs to build the Style and cue sound pickers, with a fake
-- host context as MCT passes it.
local function context(files)
    return {directory='Preymonition',files=function(sub)
        local listed=files[sub]
        if listed==false then return nil,'listing failed' end
        return listed or {}
    end}
end
local style=dofile('Preymonition/Scripts/choices/unblockable_style.lua')
local cues=dofile('Preymonition/Scripts/choices/cue_sounds.lua')
local unblockables=dofile('Preymonition/Scripts/choices/unblockable_sounds.lua')
local function keys(list) local out={} for i,c in ipairs(list) do out[i]=c.key..'='..c.label..(c.note and '/'..c.note or '') end return table.concat(out,' ') end

-- The shipped files, as the repo holds them.
local function folder(path)
    local out={}
    for line in io.popen('ls -1 Preymonition/'..path):lines() do out[#out+1]=line end
    return out
end
local shipped=context({images=folder('images'),sounds=folder('sounds')})
shipped.head=function(path,count)
    local file=io.open('Preymonition/'..path,'rb'); if not file then return nil,'missing' end
    local bytes=file:read(count); file:close(); return bytes
end
-- What a list should hold for a folder: each <prefix><x>.<ext>, sorted, labelled by word.
local function expected(path,prefix,ext)
    local out={}
    for _,name in ipairs(folder(path)) do
        local key=name:match('^'..prefix..'([%w_]+)%.'..ext..'$')
        if key then out[#out+1]=key end
    end
    table.sort(out)
    for i,key in ipairs(out) do out[i]=key..'='..key:gsub('_',' '):gsub('(%a)(%w*)',function(a,b) return a:upper()..b end) end
    return table.concat(out,' ')
end
assert(keys(style(shipped))=='cracked=Cracked ember=Ember fiend=Fiend gore=Gore shattered=Shattered splatter=Splatter',
    'the shipped pictures, sorted')
assert(keys(cues(shipped))==expected('sounds','cue_','wav'),'the shipped cue sounds, sorted, without notes')
for _,choice in ipairs(cues(shipped)) do
    assert(choice.sound=='sounds/cue_'..choice.key..'.wav','each plays its own file when selected')
end
for _,choice in ipairs(unblockables(shipped)) do
    assert(choice.sound=='sounds/unblockable_'..choice.key..'.wav','each plays its own file when selected')
end

assert(keys(unblockables(shipped))==expected('sounds','unblockable_','wav'),'the shipped unblockable sounds; cue sounds are not among them')
assert(keys(unblockables(shipped)):find('growl=Growl',1,true),'Growl, the default, ships')
-- Only matching names, lowercase keys, once each, labels from words.
local live=context({images={'unblockable_Fiend.png','omen_fancy.png','unblockable_burning_skull.png',
    'unblockable_bad name.png','unblockable_old.jpg','UNBLOCKABLE_fiend.PNG'},sounds={'cue_ping.wav','ping.wav','cue_x.ogg'}})
assert(keys(style(live))=='burning_skull=Burning Skull fiend=Fiend','prefix and extension match; others skipped')
assert(keys(cues(live))=='ping=Ping','only cue_<x>.wav')
-- A missing folder lists nothing; a failed listing is reported for MCT to keep the last good list.
assert(keys(style(context({})))=='' and keys(cues(context({})))=='','a missing folder lists nothing')
local none,why=style(context({images=false}))
assert(none==nil and why=='listing failed','a failed listing is reported')
for _,choice in ipairs(style(shipped)) do
    assert(choice.key:match('^[%w_.-]+$') and not tonumber(choice.key) and not choice.label:find('[%c|;%[%]]'),'menu rules')
end
-- Parry & Block Indicator -> Style: each omen_<x>.png.
local parry=dofile('Preymonition/Scripts/choices/parry_style.lua')
assert(keys(parry(shipped))=='chevron=Chevron fancy=Fancy solid=Solid','the shipped picture styles')
assert(keys(parry(context({images={'omen_Glass_Wing.png','omen_glass_wing.PNG','omen_bad name.png','omen_x.jpg',
    'edge_soft_v.png'}})))=='glass_wing=Glass Wing','omen_<x>.png only, lowercase keys, once each')
-- A picture the Omens cannot draw is left out: not a PNG, or not 1774 by 1774.
local function png(w,h) return '\137PNG\r\n\26\n'..string.pack('>I4','13')..'IHDR'..string.pack('>I4>I4',w,h) end
local heads={['images/omen_good.png']=png(1774,1774),['images/omen_small.png']=png(887,1774),
    ['images/omen_text.png']='not a picture at all, just text'}
local checked=context({images={'omen_good.png','omen_small.png','omen_text.png','omen_gone.png'}})
checked.head=function(path,count) local b=heads[path]; if not b then return nil,'missing' end return b:sub(1,count) end
assert(keys(parry(checked))=='good=Good','only pictures the Omens can draw are listed')
assert(keys(parry(context({images={'omen_unchecked.png'}})))=='unchecked=Unchecked','without head, a picture is listed')
-- Edges Flash -> Gradient: each edge_<x>_v.png with its edge_<x>_h.png, sorted, labelled by word.
local gradients=dofile('Preymonition/Scripts/choices/edge_gradients.lua')
assert(keys(gradients(shipped))=='linear=Linear soft=Soft','the shipped gradients, sorted')
assert(keys(gradients(context({images={'edge_Deep_glow_v.png','edge_deep_glow_h.png','edge_lonely_v.png',
    'edge_half_h.png','edge_bad name_v.png','edge_bad name_h.png','edge_old_v.jpg','edge_old_h.jpg','unblockable_fiend.png'}})))
    =='deep_glow=Deep Glow','only complete pairs, lowercase keys, labels from words')
assert(keys(gradients(context({})))=='','a missing folder lists nothing')
assert(gradients(context({images=false}))==nil,'a failed listing is reported')
print('PASS: the Style, Gradient and cue sound list files list the mod\'s pictures and sounds by prefix')
