-- Where the shield sits, shared by the templates that line up on it: the
-- Background draws it, the Omens centre their arrows and skull on it.
local M={}

-- The cue box, as a share of the shorter screen side. The shield image fills it
-- before its Size scales it to its share of the screen height.
M.SHARE=0.4
-- Position keeps the shield this share of the screen height from the bottom
-- (Below) or top (Above) edge; Middle centres it.
M.MARGIN=0.1
-- The shield's default drawn height, as a share of the screen height: the
-- Omens line up on a shield this size.
M.SIZE=0.5

-- The shield's vertical centre for a Position (0 Below, 1 Middle, 2 Above),
-- given its drawn size in screen units.
function M.centre(position,height,size)
    if position==1 then return height/2 end
    if position==2 then return height*M.MARGIN+size/2 end
    return height*(1-M.MARGIN)-size/2
end

-- The cue box's side and the top of the box for a Position, for a shield
-- drawn at share of the screen height.
function M.box(screen,position,share)
    local side=math.min(screen.width,screen.height)*M.SHARE
    local centre=M.centre(position or 1,screen.height,screen.height*share)
    return side,math.max(0,centre-side/2)
end

return M
