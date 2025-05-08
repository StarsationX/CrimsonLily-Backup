local Autofish = {}
ODYSSEY.Autofish = Autofish

local AutofishData = ODYSSEY.Data.Autofish or {}
ODYSSEY.Data.Autofish = AutofishData

--

ODYSSEY.InitData("Position", {3979.5, 396.1, 256.2}, AutofishData)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryScr = ReplicatedStorage.RS.Modules.Inventory
local FishingScr = ReplicatedStorage.RS.Modules.Fishing

local FishState = ReplicatedStorage.RS.Remotes.Misc.FishState
local FishClock = ReplicatedStorage.RS.Remotes.Misc.FishClock

local Fishing = require(FishingScr)
local Inventory = require(InventoryScr)

local Maid = load("src/lib/Maid.lua")
local AutofishMaid = Maid.new()

function Autofish.GetFishingRods()
    local getInvRemote = ReplicatedStorage.RS.Remotes.UI.GetInventoryItems
    local items = getInvRemote:InvokeServer()

    local rods = {}

    for _, item in ipairs(items) do
        if item == "FILLER" then continue end
        local metadata, data = Inventory.GetItemValueInfo(item)

        if not data then continue end -- wtf
        if data.SubType ~= "Fishing Rod" then continue end

        local resolvedName = Inventory.ResolveItemName(metadata)
        metadata.ResolvedName = resolvedName

        table.insert(rods, {metadata, data})
    end

    return rods
end

function Autofish.FindRod(rodName)
    local player = ODYSSEY.GetLocalPlayer()
    local character = player.Character
    local backpack = player.Backpack

    local rod = (character:FindFirstChild(rodName)) or (backpack:FindFirstChild(rodName))
    return rod
end

ODYSSEY.Maid:GiveTask(AutofishMaid)

function Autofish.Update()
    if AutofishData.AutofishToggle then
        local character = ODYSSEY.GetLocalPlayer().Character
        local hum = character:WaitForChild("Humanoid")

        if character:FindFirstChild("FishClock") then
            return
        end
        if hum.Health <= 0 then
            return AutofishMaid:Destroy()
        end
       
        AutofishMaid:GiveTask(hum.Died:Connect(function()
            AutofishMaid:Destroy()
        end))

        local rod = Autofish.FindRod(AutofishData.FishingRod)

        -- cast
        task.wait(2)
        FishState:FireServer("StopClock")
        FishClock:FireServer(rod, nil, Vector3.new(table.unpack(AutofishData.Position)))
       
        -- wait for something to bite
        AutofishMaid:GiveTask(character.ChildAdded:Connect(function(c)
            if c.Name == "FishBiteProgress" then
                while c.Parent do
                    FishState:FireServer("Reel")
                    task.wait(1/20)
                end

                -- repeat!
                AutofishMaid:Destroy()
            end
        end))
    else
        AutofishMaid:Destroy()
    end
end

ODYSSEY.Timer(1, Autofish.Update)