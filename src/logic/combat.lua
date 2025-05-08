local Combat = {}
ODYSSEY.Combat = Combat

local CombatData = ODYSSEY.Data.Combat or {}
ODYSSEY.Data.Combat = CombatData

--

local RemoteTamperer = ODYSSEY.RemoteTamperer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- break targeting
local setTarget = ReplicatedStorage.RS.Remotes:FindFirstChild("SetTarget", true)

RemoteTamperer.TamperRemotes({setTarget}, function(remote, args, oldNamecall)
	if CombatData.BreakAI then
		return false
	end
end)

-- infinite stamina
local bin = ODYSSEY.GetLocalPlayer():WaitForChild("bin")
local staminaVal = bin:WaitForChild("Stamina")
local maxStaminaVal = bin:WaitForChild("MaxStamina")

local remote = ReplicatedStorage.RS.Remotes.Combat.StaminaCost

function Combat.UpdateStamina()
	local ratio = staminaVal.Value / maxStaminaVal.Value

	if CombatData.NoStamina then
		if ratio < 1 then
			remote:FireServer(-2, "Dodge")
		end
	else
		-- try to reset stamina back to normal
		if ratio > 1 then
			remote:FireServer(ratio - 1, "Dodge")
		end
	end
end

Combat.UpdateStamina()
ODYSSEY.Maid:GiveTask(staminaVal.Changed:Connect(Combat.UpdateStamina))
ODYSSEY.Maid:GiveTask(maxStaminaVal.Changed:Connect(Combat.UpdateStamina))

-- no knockback
local player = ODYSSEY.GetLocalPlayer()

local function OnCharacterAdded(character)
	local hrp = character:WaitForChild("HumanoidRootPart")

	ODYSSEY.Maid:GiveTask(hrp.ChildAdded:Connect(function(c)
		if not CombatData.NoKnockback then return end
		if not hrp.Parent then return end
		if c:IsA("BodyMover") and c.Name == "BodyVelocity" then
			local oldVel = c.Velocity
			c.Velocity = Vector3.new()

			task.defer(function()
				-- wait to see if it's a high jump or not
				-- then set its Velocity back
				if not hrp:FindFirstChild("Leap") then
					c:Destroy()
				else
					c.Velocity = oldVel
				end
			end)
		end
	end))
end

OnCharacterAdded(player.Character or player.CharacterAdded:Wait())
ODYSSEY.Maid:GiveTask(player.CharacterAdded:Connect(OnCharacterAdded))

-- damage tampers
local toBlacklist = {}
local toIntercept = {}

for _, remote in ipairs(ReplicatedStorage.RS.Remotes:GetDescendants()) do
	local name = remote.Name
	
	if string.match(name, "Take") and string.match(name, "Damage") then
		table.insert(toBlacklist, remote)
	end
	if string.match(name, "Deal") and string.match(name, "Damage") then
		table.insert(toIntercept, remote)
	end
	
	if name == "TouchDamage" then
		table.insert(toBlacklist, remote)
	end
end


ODYSSEY.RemoteTamperer.TamperRemotes(toBlacklist, function()
	if CombatData.DamageReflect or CombatData.DamageNull then
		return false
	end
end)

ODYSSEY.RemoteTamperer.TamperRemotes(toIntercept, function(remote, args, oldNamecall)
	-- idk why vetex loves putting random ass vars in remotes
	local modelTypes = {}
	for idx, arg in pairs(args) do
		if typeof(arg) == "Instance" and arg:IsA("Model") then
			table.insert(modelTypes, {Index = idx, Value = arg})
		end
	end

	local dealer, receiver = modelTypes[1], modelTypes[2]

	-- damage reflect
	if CombatData.DamageReflect then
		if receiver.Value == ODYSSEY.GetLocalCharacter() then
			args[dealer.Index] = receiver.Value
			args[receiver.Index] = dealer.Value
		end
	else
		-- only nullify if we are being attacked
		if CombatData.DamageNull and args[dealer.Index] ~= ODYSSEY.GetLocalCharacter() then
			return false
		end
	end

	-- damage amp
	if CombatData.DamageAmp then
		local amount = CombatData.DamageAmpValue
		local fireServer = remote.FireServer

		if args[dealer.Index] ~= ODYSSEY.GetLocalCharacter() then
			amount = 1 -- don't amp if we are being attacked
		end
		
		for _ = 1, amount do
			fireServer(remote, table.unpack(args))
		end

		return false
	end
end)