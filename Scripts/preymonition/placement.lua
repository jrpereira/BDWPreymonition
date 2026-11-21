-- Where the omens' cue area sits, shared by the templates that line up on it:
-- the Omens centre their arrows on it. The Countdown has positions of its own.
local M={}

-- The cue box, as a share of the shorter screen side.
M.SHARE=0.4
-- Position keeps the cue area this share of the screen height from the bottom
-- (Below) or top (Above) edge; Middle centres it.
M.MARGIN=0.1
-- The cue area's height, as a share of the screen height: the Omens line up
-- on an area this size.
M.SIZE=0.5

-- The cue area's vertical centre for each Position key, given the screen
-- height and the area's size in screen units.
local CENTRES={
    below=function(height,size) return height*(1-M.MARGIN)-size/2 end,
    middle=function(height) return height/2 end,
    above=function(height,size) return height*M.MARGIN+size/2 end,
}

-- A Position setting as one of its keys: an unknown value is Middle, the default.
function M.position(key)
    return CENTRES[key] and key or 'middle'
end

-- The cue area's vertical centre for a Position, given its size in screen units.
function M.centre(position,height,size)
    return CENTRES[M.position(position)](height,size)
end

-- The cue box's side and the top of the box for a Position, for a cue area
-- share of the screen height tall.
function M.box(screen,position,share)
    local side=math.min(screen.width,screen.height)*M.SHARE
    local centre=M.centre(position,screen.height,screen.height*share)
    return side,math.max(0,centre-side/2)
end

return M
