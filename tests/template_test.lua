local template = dofile('Scripts/preymonition.lua')

assert(template.collection == 'Preymonition')
assert(template.category == 'npc.attacks')
assert(type(template.settings) == 'table')
assert(template.settings.enabled == false, 'Preymonition template must default to disabled')
assert(type(template.attach) == 'function')
assert(type(template.render) == 'function')
assert(type(template.detach) == 'function')

local subscriptions = template.subscribe
assert(type(subscriptions) == 'table' and #subscriptions == 1)
assert(subscriptions[1].events[1] == 'created')
assert(subscriptions[1].contexts[1] == 'combat')

print('template_test: passed')
