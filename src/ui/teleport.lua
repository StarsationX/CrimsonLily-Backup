local function InitMisc(tab)
	tab:NewSection("Misc teleports")
	tab:NewButton("Teleport to your ship", function()
		ODYSSEY.Teleports.ToShip()
	end)
	tab:NewButton("Teleport to current story quest", function()
		ODYSSEY.Teleports.ToMarker("StoryMarker1")
	end)
	tab:NewButton("Teleport to quest", function()
		ODYSSEY.Teleports.ToMarker("QuestMarker1")
	end)
end

local function InitPlaces(tab)
	tab:NewSection("Place teleports")
	
	local regions = ODYSSEY.Teleports.Regions
	for _, placeData in ipairs(regions) do
		tab:NewSection(placeData.Name)
		tab:NewButton(placeData.Name, function()
			ODYSSEY.Teleports.TeleportToRegion(placeData)
		end)

		if placeData.Areas then
			for _, areaData in pairs(placeData.Areas) do
				tab:NewButton(areaData.Name, function()
					ODYSSEY.Teleports.TeleportToRegion(areaData)
				end)
			end
		end
	end
end

return function(UILib, window)
	local tab = window:NewTab("Teleport")
	
	InitMisc(tab)
	InitPlaces(tab)
end