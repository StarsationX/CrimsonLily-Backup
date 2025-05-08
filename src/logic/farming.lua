local Farming = {}
ODYSSEY.Farming = Farming

local FarmingData = ODYSSEY.Data.Farming or {}
ODYSSEY.Data.Farming = FarmingData

--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = load("src/lib/Maid.lua")

--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

local DamageStructureRemote = ReplicatedStorage.RS.Remotes.Combat.DamageStructure
local RocksaltMaid = Maid.new()

function Farming.RocksaltFarm()
    if not FarmingData.Rocksalt then
        return RocksaltMaid:Destroy()
    end

    -- find a random rock
    local rock
    for _, island in ipairs(workspace.Map:GetChildren()) do
        local natural = island:FindFirstChild("Natural")
        if not natural then continue end
        
        local rocks = natural:FindFirstChild("Rocks")
        if not rocks then continue end

        rock = rocks:FindFirstChild("RockPile")
        if not rock then continue end
    end

    if not rock then
        for _, island in ipairs(ReplicatedStorage.RS.UnloadIslands:GetChildren()) do
            local natural = island:FindFirstChild("Natural")
            if not natural then continue end
            
            local rocks = natural:FindFirstChild("Rocks")
            if not rocks then continue end
    
            rock = rocks:FindFirstChild("RockPile")
            if not rock then continue end
        end    
    end

    if not rock then
        return ODYSSEY.SendNotification(nil, "Crimson Lily", "Failed to find a RockPile.", Color3.new(1, 0, 0))
    end
    
    -- tp
    local player = ODYSSEY.GetLocalPlayer()
    local character = player.Character
    local hrp = character.PrimaryPart

    character:SetPrimaryPartCFrame(CFrame.new(rock.Position))
    RocksaltMaid:GiveTask(function()
        hrp.Anchored = false
    end)

    task.wait(0.1)
    hrp.Anchored = true

    -- destroy lmao
    local a1 = "Explosion Magic"
    local a2 = "1"
    local a3 = character
    local a4 = rock
    local a5 = "[\"Blast\",1,100,100,false,\"Right Hand Snap\",\"(None)\",\"Blast\",\"(None)\",\"Ash\"]"

    task.spawn(function()
        while FarmingData.Rocksalt do
            task.spawn(function()
                DamageStructureRemote:InvokeServer(a1, a2, a3, a4, a5)
            end)
            task.wait(1/FarmingData.RocksaltSpeed)
        end
    end)

    RocksaltMaid:GiveTask(workspace.Map.Temporary.ChildAdded:Connect(function(c)
        if c.Name == "RockDrop" then
            c.Anchored = true

            local pp = c:WaitForChild("Prompt", 10)
            if not pp then
                c:Destroy()
                return
            end

            local objectText = pp.ObjectText
            if objectText == "Rock salt" and FarmingData.RocksaltGems then
                c:Destroy()
                return
            end
            
            fireproximityprompt(pp, 0)
        end
    end))
end