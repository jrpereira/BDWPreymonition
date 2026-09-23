local previous = rawget(_G, 'PremonitionRuntime')
PremonitionRuntime = { stop = function() error('simulated unregister failure') end }
local ok, error_message = pcall(dofile, 'Scripts/main.lua')
assert(not ok and tostring(error_message):match('Cannot replace the previous Premonition runtime'),
    'reload must refuse to add hooks when the previous runtime cannot stop cleanly')
PremonitionRuntime = previous
print('PASS: reload refuses duplicate active hook ownership')
