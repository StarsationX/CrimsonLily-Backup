local Trackers = {}
ODYSSEY.Trackers = Trackers

local TrackersData = ODYSSEY.Data.Trackers or {}
ODYSSEY.Data.Trackers = TrackersData

ODYSSEY.InitData("ShipESP", true, TrackersData)
ODYSSEY.InitData("UnloadedShipESP", false, TrackersData)
ODYSSEY.InitData("PlayerESP", true, TrackersData)
ODYSSEY.InitData("PlayerMarkers", true, TrackersData)

local islandsESP = TrackersData.Islands or {}
TrackersData.Islands = islandsESP

for _, region in ipairs(ODYSSEY.Teleports.Regions) do
    ODYSSEY.InitData(region.Name, false, islandsESP)
end

--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnloadedBoats = ReplicatedStorage.RS.UnloadBoats
local UnloadedBoats2 = ReplicatedStorage.RS.UnloadNPCShips

local BoatsModule = require(ReplicatedStorage.RS.Modules.Boats)

local Maid = load("src/lib/Maid.lua")

--
local ESP = load("src/lib/ESP.lua")
ESP.Enabled = true

ODYSSEY.Maid:GiveTask(function()
    for _, object in pairs(ESP.Objects) do
        object:Remove()
    end
    ESP.Objects = {}
end)

ESP.Overrides.UpdateAllow = function(self)
    -- players
    if self.Player then
        return TrackersData.PlayerESP
    end

    -- boats
    if self.Object:FindFirstChild("BoatHandler") then
        if not TrackersData.UnloadedShipESP then
            if self.Object.Parent ~= workspace.Boats then
                return false
            end
        end

        return TrackersData.ShipESP
    end
   
    -- regions
    if self.RegionName then
        return TrackersData.Islands[self.RegionName]
    end

    return true
end

--
local function TrackCharacter(character)
    if ESP:GetBox(character) then return end
    ESP:Add(character, {
        Player = Players:GetPlayerFromCharacter(character),
        RenderInNil = true
    })
end

local function TrackBoat(boat)
    if ESP:GetBox(boat) then return end
    
    local isNPC = boat:FindFirstChild("NPCShip") ~= nil
    local type = boat:WaitForChild("Type").Value
    local equips = boat:WaitForChild("Equips").Value

    local title, titleColor = BoatsModule.GetBoatTitle(type, equips)
    local data = title

    if title == "" then
        title = type
    end
    if isNPC then
        local faction = boat.NPCShip.Value
        data = string.format("%s %s", faction, title)
    else
        data = title
    end

    ESP:Add(boat, {
        Color = titleColor,
        Size = Vector3.new(1, 1, 1),
        Data = data,
        RenderInNil = true
    })
end

--
for _, island in ipairs(workspace.Map:GetChildren()) do
    if not island:FindFirstChild("Center") then continue end
   
    local box = ESP:Add(island.Center, {
        Color = Color3.fromRGB(76, 42, 135),
        RenderInNil = true,
        Name = "",
        Size = Vector3.new(1, 1, 1),
        Data = island.Name
    })
    box.RegionName = island.Name
end

--
ODYSSEY.Timer(1, function()
    -- players
    for _, player in ipairs(Players:GetPlayers()) do
        if not player.Character then continue end
        if player == ODYSSEY.GetLocalPlayer() then continue end

        TrackCharacter(player.Character)
    end

    -- botes
    for _, boat in ipairs(workspace.Boats:GetChildren()) do
        TrackBoat(boat)
    end

    for _, boat in ipairs(UnloadedBoats:GetChildren()) do
        TrackBoat(boat)
    end

    for _, boat in ipairs(UnloadedBoats2:GetChildren()) do
        TrackBoat(boat)
    end
	
	-- cleanup
	for _, esp in pairs(ESP.Objects) do
		if (not esp.Object) or (not esp.Object:IsDescendantOf(game)) then
			esp:Remove()
		end
	end
end)


--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

--[[
local localPlayer = ODYSSEY.GetLocalPlayer()
local playerGui = localPlayer:WaitForChild("PlayerGui")

local worldMapScr, mapGui = nil, nil
local newPoint, adjustPoint = nil

local TrackersMaid = Maid.new()
ODYSSEY.Maid:GiveTask(TrackersMaid)

local function onDescAdded(c)
    if c.Name == "WorldMap" and c:IsA("LocalScript") then
        local numChild = #c:GetChildren()
        while numChild < 11 do
            c.ChildAdded:Wait()
        end
        worldMapScr = c
        
        local regionVal = localPlayer:WaitForChild("bin"):WaitForChild("Region")
        local updateQM = nil

        for _, conn in next, getconnections(regionVal.Changed) do
            local env = getfenv(conn.Function)
            if rawget(env, "script") == worldMapScr then
                updateQM = getupvalues(conn.Function)[4]
            end
        end

        newPoint = getupvalues(updateQM)[4]
        adjustPoint = getupvalues(updateQM)[5]
    end
    if c.Name == "Map" then
        mapGui = c
    end
end

for _, c in ipairs(playerGui:GetDescendants()) do
    onDescAdded(c)
end
ODYSSEY.Maid:GiveTask(localPlayer.CharacterAdded:Connect(function()
    TrackersMaid:Destroy()
    task.wait(2)

    TrackersMaid:GiveTask(function()
        worldMapScr, mapGui = nil, nil
        newPoint, adjustPoint = nil, nil
    end)
    for _, c in ipairs(playerGui:GetDescendants()) do
        onDescAdded(c)
    end
end))

while not (worldMapScr and mapGui and newPoint and adjustPoint) do
    task.wait()
end

--------
local NAME_COLORS =
{
	Color3.new(253/255, 41/255, 67/255), -- BrickColor.new("Bright red").Color,
	Color3.new(1/255, 162/255, 255/255), -- BrickColor.new("Bright blue").Color,
	Color3.new(2/255, 184/255, 87/255), -- BrickColor.new("Earth green").Color,
	BrickColor.new("Bright violet").Color,
	BrickColor.new("Bright orange").Color,
	BrickColor.new("Bright yellow").Color,
	BrickColor.new("Light reddish violet").Color,
	BrickColor.new("Brick yellow").Color,
}

local function GetNameValue(pName)
	local value = 0
	for index = 1, #pName do
		local cValue = string.byte(string.sub(pName, index, index))
		local reverseIndex = #pName - index + 1
		if #pName%2 == 1 then
			reverseIndex = reverseIndex - 1
		end
		if reverseIndex%4 >= 2 then
			cValue = -cValue
	end
		value = value + cValue
	end
	return value
end

local color_offset = 0
local function ComputeNameColor(pName)
	return NAME_COLORS[((GetNameValue(pName) + color_offset) % #NAME_COLORS) + 1]
end
--------

function Trackers.CreatePlayerMarkers()
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        local character = player.Character
        if not character then continue end

        local hrp = character.PrimaryPart
        if not hrp then continue end

        if mapGui:FindFirstChild(player.Name, true) then continue end

        local image = (player == localPlayer and "12535015260") or "12637955397"
        local size = (player == localPlayer and UDim2.fromOffset(50, 50)) or nil

        local color = ComputeNameColor(player.Name)
        local name = string.format("%s (@%s)", player.DisplayName, player.Name)

        local _, a, b = pcall(newPoint, color, name, hrp.Position.X, hrp.Position.Z, nil, true, "rbxassetid://".. image, size, color)
        a.Name = player.Name
        b.Name = player.Name

        local smallMaid = Maid.new()
        TrackersMaid:GiveTask(smallMaid)

        smallMaid:GiveTask(game:GetService("RunService").Heartbeat:Connect(function()
            if not a.Parent or not b.Parent then
                return smallMaid:Destroy()
            end
            if not adjustPoint then
                return smallMaid:Destroy()
            end
            
            adjustPoint(a, b, hrp.Position.X, hrp.Position.Z)
        end))
        smallMaid:GiveTask(a)
        smallMaid:GiveTask(b)
    end
end


ODYSSEY.Timer(0.5, function()
    if not worldMapScr or not worldMapScr.Parent then
        return
    end

    if TrackersData.PlayerMarkers then
        Trackers.CreatePlayerMarkers()
    end
end)]]