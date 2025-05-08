local RemoteTamperer = {}
RemoteTamperer.Tampers = {}

-- hook game
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if checkcaller() then
        return oldNamecall(self, ...)
    end

    local args = {...}
    local method = getnamecallmethod()

    if (self.ClassName == "RemoteEvent") and (method == "FireServer") then
        local tamperHandler = RemoteTamperer.Tampers[self]
        if tamperHandler then
            local shouldFire = tamperHandler(self, args, oldNamecall)
            if shouldFire ~= false then
                return self.FireServer(self, table.unpack(args))
            end

            return nil
        end
    end

    return oldNamecall(self, ...)
end)

ODYSSEY.MetaHooks[oldNamecall] = {
    Object = game,
    Method = "__namecall"
}

-- API
function RemoteTamperer.TamperRemotes(remotes, tamperFunc)
    for _, remote in ipairs(remotes) do
        RemoteTamperer.Tampers[remote] = tamperFunc
    end
end

function RemoteTamperer.UntamperRemotes(remotes)
    for _, remote in ipairs(remotes) do
        RemoteTamperer.Tampers[remote] = nil
    end
end

return RemoteTamperer