local previous = rawget(_G, 'PreymonitionRuntime')
PreymonitionRuntime = { stop = function() error('simulated unregister failure') end }
local ok, error_message = pcall(dofile, 'Scripts/main.lua')
assert(not ok and tostring(error_message):match('Cannot replace the previous Preymonition runtime'),
    'reload must refuse to add hooks when the previous runtime cannot stop cleanly')
PreymonitionRuntime = previous
print('PASS: reload refuses duplicate active hook ownership')
