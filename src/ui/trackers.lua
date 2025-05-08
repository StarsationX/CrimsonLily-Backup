local Trackers = ODYSSEY.Data.Trackers

return function(UILib, window)
    local tab = window:NewTab("Trackers")

    -- ship esp
    tab:NewSection("Ship ESP")
    tab:NewToggle("Track ships", Trackers.ShipESP, function(value)
        Trackers.ShipESP = value
    end)
    tab:NewToggle("Track unloaded ships", Trackers.UnloadedShipESP, function(value)
        Trackers.UnloadedShipESP = value
    end)

    -- player esp
    tab:NewSection("Player ESP")
    tab:NewToggle("Track players", Trackers.PlayerESP, function(value)
        Trackers.PlayerESP = value
    end)

    tab:NewToggle("Show player markers on Map", Trackers.PlayerMarkers, function(value)
        Trackers.PlayerMarkers = value
    end)

    -- island esp
    tab:NewSection("Islands ESP")
    local islandsESP = Trackers.Islands

    for _, region in ipairs(ODYSSEY.Teleports.Regions) do
        tab:NewToggle(region.Name, islandsESP[region.Name], function(value)
            islandsESP[region.Name] = value
        end)
    end
end