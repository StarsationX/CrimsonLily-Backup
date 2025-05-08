local Gameplay = {}
ODYSSEY.Gameplay = Gameplay

local GameplayData = ODYSSEY.Data.Gameplay or {}
ODYSSEY.Data.Gameplay = GameplayData

--

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = ODYSSEY.GetLocalPlayer()

function GetServers(placeId, limit)
    local servers = {}
    local cursor = nil

    ODYSSEY.SendNotification(nil, "Crimson Lily", string.format("Fetching %d servers, please wait.", limit), Color3.new(1, 1, 1))
    repeat
        local endpoint = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
            placeId
        )
        if cursor then
            endpoint ..= "&cursor=".. cursor
        end

        local resp = HttpService:JSONDecode(game:HttpGetAsync(endpoint))
        cursor = resp.nextPageCursor

        for _, server in ipairs(resp.data) do
            if not server.playing then continue end
            table.insert(servers, server)
        end

        if #servers >= limit then
            -- dont fetch more its gonna take forever lmao
            break
        end
    until cursor == nil

    return servers
end

function Gameplay.LoadSlot()
    local servers = GetServers(GameplayData.SelectedSeaId, 400)
    local server = servers[math.random(1, #servers)]

    TeleportService:TeleportToPlaceInstance(
        GameplayData.SelectedSeaId,
        server.id,
        nil,
        nil,
        tonumber(GameplayData.SelectedSlot)
    )
end

function Gameplay.ServerHop()
    local data = GetServers(GameplayData.SelectedSeaId, 100)
    table.sort(data, function(a, b)
        return a.playing < b.playing
    end)

    if not data[1] then
        ODYSSEY.SendNotification(nil, "Crimson Lily", "Couldn't find any server.", Color3.new(1, 0, 0))
        return
    end

    TeleportService:TeleportToPlaceInstance(
        GameplayData.SelectedSeaId,
        data[1].id,
        nil,
        nil,
        tonumber(GameplayData.SelectedSlot)
    )
end

function Gameplay.JoinFastestServer()
    local data = GetServers(GameplayData.SelectedSeaId, 400)
    table.sort(data, function(a, b)
        return a.ping < b.ping
    end)

    if not data[1] then
        ODYSSEY.SendNotification(nil, "Crimson Lily", "Couldn't find any server.", Color3.new(1, 0, 0))
        return
    end

    TeleportService:TeleportToPlaceInstance(
        GameplayData.SelectedSeaId,
        data[1].id,
        nil,
        nil,
        tonumber(GameplayData.SelectedSlot)
    )
end

function Gameplay.Rejoin()
    TeleportService:TeleportToPlaceInstance(
        game.PlaceId,
        game.JobId,
        nil,
        nil,
        tonumber(GameplayData.SelectedSlot)
    )
end

--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

function Gameplay.DiscoverAllRegions()
    local locations = require(ReplicatedStorage.RS.Modules.Locations)
    for regionName, _ in pairs(locations.Regions) do
        ReplicatedStorage.RS.Remotes.Misc.UpdateLastSeen:FireServer(regionName, "")
    end
end

local LoadRemote = ReplicatedStorage.RS.Remotes.NPC.LoadCheck
function Gameplay.ForceLoad()
    local character = ODYSSEY.GetLocalCharacter()
    local hrp = character.HumanoidRootPart
    ODYSSEY.LoadArea(hrp.Position, false)
    
    -- load NPCs
    for _, npc in ipairs(workspace.NPCs:GetChildren()) do
        local cf = npc:FindFirstChild("CF")
        if not cf then continue end
        if npc:FindFirstChild(npc.Name) then continue end
        
        cf = cf.Value
        if (cf.Position - hrp.Position).Magnitude <= 300 then
            LoadRemote:Fire(npc)
        end
    end

    -- load enemies
    for _, enemy in ipairs(ReplicatedStorage.RS.UnloadEnemies:GetChildren()) do
        local eHrp = enemy:FindFirstChild("HumanoidRootPart")
        if not eHrp then continue end
        if (eHrp.Position - hrp.Position).Magnitude > 300 then continue end

        enemy.Parent = workspace.Enemies
        LoadRemote:Fire(enemy)
    end
end

ODYSSEY.Timer(1, function()
    if not GameplayData.ForceLoad then return end
    Gameplay.ForceLoad()
end)


--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

local eatRemote = ReplicatedStorage.RS.Remotes.Misc.ToolAction

local InventoryScr = ReplicatedStorage.RS.Modules.Inventory
local Inventory = require(InventoryScr)

local function AutoEat()
    if not GameplayData.AutoEat then return end

    local ok, hungerBar = pcall(function()
        return Player:FindFirstChildOfClass("PlayerGui").MainGui:FindFirstChild("HungerBar", true)
    end)
    if not ok then return end

    local ok, hungerText = pcall(function()
        return hungerBar.Back.Amount
    end)
    if not ok then return end


    local hungerAmount = tonumber(hungerText.Text)
    if hungerAmount < 100 then
        local getInvRemote = ReplicatedStorage.RS.Remotes.UI.GetInventoryItems
        local items = getInvRemote:InvokeServer()

        -- to combat possible giant meals not working
        local foods = {}

        for _, item in ipairs(items) do
            if item == "FILLER" then continue end
            local metadata, data = Inventory.GetItemValueInfo(item)
    
            if not data then continue end -- wtf
            if data.SubType == "Fruit" or data.SubType == "Meal" then
                local name = Inventory.ResolveItemName(metadata)
                local tool = Player.Backpack:FindFirstChild(name)

                if not tool then continue end    
                table.insert(foods, tool)
            end
        end

        if #foods <= 0 then return end
        local food = foods[math.random(1, #foods)]

        eatRemote:FireServer(food)
    end
end

ODYSSEY.Timer(3, AutoEat)

--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

local lastSeenRemote = ReplicatedStorage.RS.Remotes.Misc.UpdateLastSeen

ODYSSEY.RemoteTamperer.TamperRemotes({lastSeenRemote}, function()
    if GameplayData.DisableLastSeen then
        return false
    end
end)

function Gameplay.SpoofLocation()
    lastSeenRemote:FireServer("The Dark Sea", "")
    task.wait(0.1)
    lastSeenRemote:FireServer("Frostmill Island", "")
end