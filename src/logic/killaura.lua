local Killaura = {}
ODYSSEY.Killaura = Killaura

local KillauraData = ODYSSEY.Data.Killaura or {}
ODYSSEY.Data.Killaura = KillauraData

--

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local REMOTE = game:GetService("ReplicatedStorage").RS.Remotes.Combat.DealWeaponDamage

local WEAPON = HttpService:JSONEncode({
    Name = "Bronze Musket",
    Level = 120
})
local ATTACK = "Piercing Shot"
local AMMO = HttpService:JSONEncode({
	Name = "Golden Bullet",
	Level = 120,
	Amount = 999
})

local KILLING = {}

function KillModel(model, ignoreDistanceLimit)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")

    local function GetHealth() end

    if KILLING[model] then return end
	if model.Name ~= "Shark" then
		if not humanoid or not hrp then return end
		if humanoid.Health <= 0 then return end

        GetHealth = function() return humanoid.Health end
	else
		local healthVal = model.Attributes.Health
		if healthVal.Value <= 0 then return end

        GetHealth = function() return healthVal.Value end
	end

    local cond1 = ODYSSEY.GetLocalPlayer():DistanceFromCharacter(hrp.Position) <= KillauraData.Radius
    local cond2 = ignoreDistanceLimit
    if cond1 or cond2 then
        KILLING[model] = true

        task.spawn(function()
            local start = os.clock()

            while (GetHealth() > 0) and (os.clock() - start < 10) do
                for _ = 1, math.random(5, 10) do
					task.delay(math.random(0, 0.3), function()
						REMOTE:FireServer(0, ODYSSEY.GetLocalCharacter(), model, WEAPON, ATTACK, AMMO)
					end)
				end
                task.wait(0.3)
            end
			
            KILLING[model] = nil
        end)
    end
end

function Killaura.KillOnce()
    for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
        KillModel(enemy)
    end

    if ODYSSEY.Data.KillPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player == ODYSSEY.GetLocalPlayer() then continue end
            KillModel(player.Character)
        end
    end
end

function Killaura.KillSharks()
    for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
        if enemy.Name == "Shark" then
            KillModel(enemy, true)
        end
    end
end

ODYSSEY.Timer(2, function()
    if KillauraData.Active then
        Killaura.KillOnce()
    end
end)