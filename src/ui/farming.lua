local Farming = ODYSSEY.Data.Farming

local function InitRockSalt(tab)
    ODYSSEY.InitData("Rocksalt", false, Farming)
    ODYSSEY.InitData("RocksaltSpeed", 20, Farming)
    ODYSSEY.InitData("RocksaltGems", true, Farming)

    tab:NewSection("Rocksalt farm")
    tab:NewToggle("Rocksalt farm", Farming.Rocksalt, function(value)
        Farming.Rocksalt = value
        ODYSSEY.Farming.RocksaltFarm()
    end)
    tab:NewToggle("Pick up gems only", Farming.RocksaltGems, function(value)
        Farming.RocksaltGems = value
    end)
    tab:NewSlider("Speed", "times/s", false, "", {min = 1, max = 60, default = Farming.RocksaltSpeed}, function(value)
        Farming.RocksaltSpeed = value
    end)
end

local function InitAutofish(window)
    local AutofishData = ODYSSEY.Data.Autofish

    ODYSSEY.InitData("AutofishToggle", false, AutofishData)
    ODYSSEY.InitData("FishingRod", "", AutofishData)
    
    window:NewSection("Autofish")
    window:NewToggle("Autofish", AutofishData.AutofishToggle, function(value)
        AutofishData.AutofishToggle = value
    end)

    --
    local rods = ODYSSEY.Autofish.GetFishingRods()
    local rodNames = {}
    local rodMap = {}

    if #rods > 0 then
        local lastSavedRod = AutofishData.FishingRod

        for _, rodData in ipairs(rods) do
            table.insert(rodNames, rodData[1].ResolvedName)
            rodMap[rodData[1].ResolvedName] = rodData
        end
    
        if not rodMap[lastSavedRod] then
            AutofishData.FishingRod = rodNames[math.random(1, #rodNames)]
        end
        
        window:NewSelector("Fishing rod", AutofishData.FishingRod, rodNames, function(value)
            AutofishData.FishingRod = value
        end)
    else
        ODYSSEY.SendNotification(nil, "Crimson Lily", "You don't have any fishing rods. Get a rod and try again.", Color3.new(1, 0, 0))
    end

    --
    local player = ODYSSEY.GetLocalPlayer()
    local character = player.Character

    local function getPos()
        local pos = character.PrimaryPart.Position
        return pos.X, pos.Y, pos.Z
    end
    
    window:NewLabel("Set the position to fish at to your character's position", "le")
    window:NewLabel("Move to a body of water and press the button to set the position there", "le")
    window:NewLabel("This affects your fishes", "le")

    local posLabel = window:NewLabel(string.format("Current position: %.2f, %.2f, %.2f", getPos()))

    window:NewButton("Record position", function()
        character = player.Character
        AutofishData.Position = {getPos()}

        posLabel:Text(string.format("Current position: %.2f, %.2f, %.2f", getPos()))
    end)
    window:NewButton("Teleport to position", function()
        character = player.Character
        character:SetPrimaryPartCFrame(CFrame.new(table.unpack(AutofishData.Position)))
    end)
end

return function(UILib, window)
    local tab = window:NewTab("Farming")

    InitRockSalt(tab)
    InitAutofish(tab)
end