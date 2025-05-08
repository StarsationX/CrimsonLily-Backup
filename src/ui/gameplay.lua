local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Basic = require(ReplicatedStorage.RS.Modules.Basic)

local bin = ODYSSEY.GetLocalPlayer():WaitForChild("bin")

--
local GameplayData = ODYSSEY.Data.Gameplay

--
local seaNames = {}
local seaNameToIds = {}

for seaId, seaName in pairs(Basic.MainUniverse) do
    table.insert(seaNames, seaName)
    seaNameToIds[seaName] = seaId
end

ODYSSEY.InitData("SelectedSeaId", seaNameToIds["The Bronze Sea"], GameplayData)
ODYSSEY.InitData("SelectedSlot", bin:WaitForChild("File").Value, GameplayData)
ODYSSEY.InitData("ForceLoad", true, GameplayData)
ODYSSEY.InitData("DisableLastSeen", true, GameplayData)
ODYSSEY.InitData("AutoEat", true, GameplayData)

return function(UILib, window)
    local tab = window:NewTab("Gameplay")

    tab:NewSection("Region")
    tab:NewToggle("Force load around yourself", GameplayData.ForceLoad, function(value)
        GameplayData.ForceLoad = value
    end)
    tab:NewToggle("Disable last seen (also prevents Insanity 5 damage)", GameplayData.DisableLastSeen, function(value)
        GameplayData.DisableLastSeen = value
    end)

    tab:NewButton("Discover every region", function()
        ODYSSEY.Gameplay.DiscoverAllRegions()
    end)

    tab:NewLabel("Use in conjunction with Disable last seen to keep your location on bounty at Dark Sea at all times.")
    tab:NewButton("Spoof location to Dark Sea", function()
        ODYSSEY.Gameplay.SpoofLocation()
    end)

    tab:NewSection("Auto eat")
    tab:NewToggle("Auto eat", GameplayData.AutoEat, function(value)
        GameplayData.AutoEat = value
    end)

    tab:NewSection("Load slots")
    tab:NewSelector("Sea", Basic.MainUniverse[GameplayData.SelectedSeaId], seaNames, function(value)
        GameplayData.SelectedSeaId = seaNameToIds[value]
    end)

    tab:NewSelector("Slot", GameplayData.SelectedSlot, {"1", "2", "3", "4", "5", "6"}, function(value)
        GameplayData.SelectedSlot = value
    end)
    
    tab:NewButton("Join random server", function()
        ODYSSEY.Gameplay.LoadSlot()
    end)
    tab:NewButton("Join empty server", function()
        ODYSSEY.Gameplay.ServerHop()
    end)
    tab:NewButton("Join lowest ping server", function()
        ODYSSEY.Gameplay.JoinFastestServer()
    end)
    tab:NewButton("Rejoin", function()
        ODYSSEY.Gameplay.Rejoin()
    end)
end