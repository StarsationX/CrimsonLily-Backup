local function InitDamage(tab)
	local CombatData = ODYSSEY.Data.Combat

	ODYSSEY.InitData("DamageReflect", false, CombatData)
	ODYSSEY.InitData("DamageNull", true, CombatData)
	ODYSSEY.InitData("DamageAmp", false, CombatData)
	ODYSSEY.InitData("DamageAmpValue", 5, CombatData)
	
	tab:NewSection("Damage tamper")
	tab:NewLabel("All the damage tampers only work against NPCs", "left")
	tab:NewToggle("Damage Nullification", CombatData.DamageNull, function(value)
		CombatData.DamageNull = value
	end)
	tab:NewToggle("Damage Reflection", CombatData.DamageReflect, function(value)
		CombatData.DamageReflect = value
	end)
	tab:NewToggle("Damage Amplification", CombatData.DamageAmp, function(value)
		CombatData.DamageAmp = value
	end)

	tab:NewSlider("Damage Amp", "", true, "/", {min = 1, max = 100, default = CombatData.DamageAmpValue}, function(value)
		CombatData.DamageAmpValue = value
	end)
end

local function InitKillaura(tab)
	local KillauraData = ODYSSEY.Data.Killaura

	ODYSSEY.InitData("Active", false, KillauraData)
	ODYSSEY.InitData("KillPlayers", false, KillauraData)
	ODYSSEY.InitData("Radius", 100, KillauraData)

	tab:NewSection("Killaura")
	tab:NewSlider("Radius", "m", true, "/", {min = 1, max = 300, default = KillauraData.Radius}, function(value)
		KillauraData.Radius = value
	end)
	tab:NewToggle("Killaura", KillauraData.Active, function(value)
		KillauraData.Active = value
	end)
	tab:NewToggle("Kill players", KillauraData.KillPlayers, function(value)
		KillauraData.KillPlayers = value
	end)
	tab:NewButton("Kill once", function()
		ODYSSEY.Killaura.KillOnce()
	end)
	tab:NewButton("Kill all sharks", function()
		ODYSSEY.Killaura.KillSharks()
	end)
end

local function InitOther(tab)
	local CombatData = ODYSSEY.Data.Combat

	ODYSSEY.InitData("NoStamina", true, CombatData)
	ODYSSEY.InitData("BreakAI", true, CombatData)
	ODYSSEY.InitData("NoKnockback", true, CombatData)

	tab:NewSection("Miscellaneous")
	tab:NewToggle("Infinite stamina", CombatData.NoStamina, function(value)
		CombatData.NoStamina = value
		ODYSSEY.Combat.UpdateStamina()
	end)
	tab:NewToggle("No knockback", CombatData.NoKnockback, function(value)
		CombatData.NoKnockback = value
	end)

	tab:NewToggle("Break AI targeting", CombatData.BreakAI, function(value)
		CombatData.BreakAI = value
	end)
end

return function(UILib, window)
	local tab = window:NewTab("Combat")
	
	InitDamage(tab)
	InitKillaura(tab)
	InitOther(tab)
end