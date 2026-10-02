local source=assert(debug.getinfo(1,'S').source:match('^@(.+)$'))
local folder=assert(source:match('^(.*)[/\\][^/\\]+$'))
if not package.path:find(folder..'/?.lua',1,true) then
    package.path=folder..'/?.lua;'..package.path
end

local Session=require('preymonition.session')

local template={
    name='Preymonition',
    description='Repeat the incoming attack direction near the bottom center of the screen.',

    category='player.notifications',
    -- MCT creates the cue layer on the HUD. The session builds the shield inside
    -- it and follows the game's attack indicator through its own native hooks.
    objects={hud={},cue={}},
    menu={{
        id='Cue', label='Visual Options', fields={
        {id='.S', label='Size',
            values={[15]='Small',[20]='Standard',[25]='Large'}, default=20},
    },
}}
}

template.loaded=Session.loaded

template.attach=function(objects,params,original)
    Session.attach(objects.hud,objects.cue,params,
        assert(params.onCleanup,'managed cleanup unavailable'))
    return original
end

return template
