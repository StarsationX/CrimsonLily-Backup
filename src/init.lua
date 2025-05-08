local env = assert(getgenv, "Unsupported exploit")()

if env.ODYSSEY then
    env.ODYSSEY.Maid:Destroy()
    env.ODYSSEY = nil
end

-- services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- modules
local Maid = load("src/lib/Maid.lua")

local ODYSSEY = {
    Hooks = {},
    MetaHooks = {},
	
	Data = {},
    Maid = Maid.new(),
}
env.ODYSSEY = ODYSSEY

-- overall cleanup task
ODYSSEY.Maid:GiveTask(function()
    for original, hook in pairs(ODYSSEY.Hooks) do
        hookfunction(hook, original)
    end

    for original, hookData in pairs(ODYSSEY.MetaHooks) do
        hookmetamethod(hookData.Object, hookData.Method, original)
    end

    table.clear(ODYSSEY)
end)

-- read config file
if isfile("CrimsonLily.json") then
    local config = HttpService:JSONDecode(readfile("CrimsonLily.json"))
    ODYSSEY.Data = config
end

-- helpers
function ODYSSEY.GetLocalPlayer()
	return Players.LocalPlayer
end

function ODYSSEY.GetLocalCharacter()
	return ODYSSEY.GetLocalPlayer().Character
end

function ODYSSEY.Timer(interval, func)
    local cancelled = false
    ODYSSEY.Maid:GiveTask(function()
        cancelled = true
    end)

    task.spawn(function()
        while not cancelled do
            local ok, err = pcall(func)
            if not ok then
                warn("[Crimson Lily] Timer error: ".. err)
            end
            task.wait(interval)
        end
    end)
    
    return function()
        cancelled = true
    end
end

function ODYSSEY.InitData(name, value, customPath)
    local path = customPath or ODYSSEY.Data
    if path[name] == nil then
        path[name] = value
    end
end


-- init
ODYSSEY.RemoteTamperer = load("src/logic/remote_tamper.lua")

-- logic
if game.PlaceId ~= 3272915504 then
    load("src/logic/core.lua")

    load("src/logic/combat.lua")
    load("src/logic/killaura.lua")

    load("src/logic/teleports.lua")
    load("src/logic/track.lua")
    
    load("src/logic/autofish.lua")
    load("src/logic/farming.lua")
    load("src/logic/money.lua")
end

load("src/logic/gameplay.lua")
load("src/ui/init.lua")

-- config saving
local json = load("src/lib/json.lua")

ODYSSEY.Timer(1, function()
    local config = json.encode(ODYSSEY.Data, {indent = true})
    writefile("CrimsonLily.json", config)
end)