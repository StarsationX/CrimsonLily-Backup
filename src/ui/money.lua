local function InitMassSell(tab)
    tab:NewSection("Mass selling")
    tab:NewLabel("Select an item in a shop GUI as normal, then use the mass sell button below", "le")

    local quantity = 0
    
    tab:NewTextbox("Quantity", "", "", "numbers", "small", true, false, function(value)
        quantity = tonumber(value)
    end)
    tab:NewButton("Sell", function()
        if not quantity or typeof(quantity) ~= "number" or math.floor(quantity) ~= quantity then
            return ODYSSEY.SendNotification(nil, "Crimson Lily", "You entered an invalid quantity.", Color3.new(1, 0, 0))
        end

        ODYSSEY.Money.MassSell(quantity)
    end)
end

local function InitBuy(tab)
    tab:NewSection("Cursed buying")
    tab:NewLabel("You can buy a non-integer amount of an item lmao", "le")

    local quantity = 0
    
    tab:NewTextbox("Quantity", "", "", "text", "small", true, false, function(value)
        quantity = tonumber(value)
    end)
    tab:NewButton("Buy", function()
        if not quantity or typeof(quantity) ~= "number" then
            return ODYSSEY.SendNotification(nil, "Crimson Lily", "You entered an invalid quantity.", Color3.new(1, 0, 0))
        end

        ODYSSEY.Money.Buy(quantity)
    end)
end

return function(UILib, window)
    local tab = window:NewTab("Money")

    InitBuy(tab)
    InitMassSell(tab)
end