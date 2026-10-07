-- Small bounded FIFO used to defer native hook work safely onto the game thread.
local M = {}

function M.new(capacity)
    assert(type(capacity) == 'number' and capacity >= 1, 'Invalid event capacity')
    local queue = { items = {}, capacity = capacity, sequence = 0, dropped = 0 }

    -- data travels with the event; a coalesced event keeps the latest.
    function queue:push(kind, path, data)
        self.sequence = self.sequence + 1
        local event = { kind = kind, path = path, data = data, sequence = self.sequence }
        if kind == 'combat_end' then
            self.items = { event }
            return event
        end
        local last = self.items[#self.items]
        if last and last.kind == kind and last.path == path then
            self.items[#self.items] = event
            return event
        end
        if #self.items >= self.capacity then
            local remove_at = self.items[1].kind == 'combat_end' and 2 or 1
            if remove_at > #self.items then
                self.dropped = self.dropped + 1
                return event
            end
            table.remove(self.items, remove_at)
            self.dropped = self.dropped + 1
        end
        self.items[#self.items + 1] = event
        return event
    end

    function queue:drain()
        local items = self.items
        self.items = {}
        return items
    end

    function queue:clear()
        self.items = {}
    end

    return queue
end

return M
