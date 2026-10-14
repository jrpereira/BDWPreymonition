-- The templates' leveled loggers, from the vendored mc_log. It is loaded by
-- path: MCT's Scripts come first on package.path, so a require would find
-- MCT's copy. The level comes from log_level.txt in the mod folder; WARN
-- without it.
local source=assert(debug.getinfo(1,'S').source:match('^@(.+)$'))
local scripts=assert(source:match('^(.*)[/\\][^/\\]+[/\\][^/\\]+$'),'logging.lua is not under Scripts')
local Log=assert(loadfile(scripts..'/vendor/mc_log.lua'))()

-- root is the mod folder, where mod.json and the developer markers live.
local M={root=scripts:match('^(.*)[/\\][^/\\]+$') or '.'}

function M.new(name)
    return Log.new({name=name,path=M.root..'/log_level.txt'})
end

return M
