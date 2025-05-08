local Money = {}
ODYSSEY.Money = Money

--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local SellItems = ReplicatedStorage.RS.Remotes.Misc.SellItems
local BuyItem = ReplicatedStorage.RS.Remotes.Misc.BuyItem

function Money.MassSell(quantity)
    local ok, gui = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.ShopGui
    end)
    if not ok then
        return ODYSSEY.SendNotification(nil, "Crimson Lily", "You are not in a shop GUI.", Color3.new(1, 0, 0))
    end

    local vendor = gui.NPC.Value
    local ok, selectedItem = pcall(function()
        local jsonData = gui.Frame.SellFrame.SumFrame.Selected.Value
        return HttpService:JSONDecode(jsonData)
    end)
    if not ok then
        return ODYSSEY.SendNotification(nil, "Crimson Lily", "The item you selected is invalid.", Color3.new(1, 0, 0))
    end

    local itemsToSell = {}
    for i = 0, quantity - 1 do
        local copy = table.clone(selectedItem)
        copy.Amount -= i

        table.insert(itemsToSell, HttpService:JSONEncode(copy))
    end

    SellItems:InvokeServer(vendor, itemsToSell, "One")
end

function Money.Buy(quantity)
    local ok, gui = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.ShopGui
    end)
    if not ok then
        return ODYSSEY.SendNotification(nil, "Crimson Lily", "You are not in a shop GUI.", Color3.new(1, 0, 0))
    end

    local vendor = gui.NPC.Value
    local ok, selectedItem = pcall(function()
        local jsonData = gui.Frame.ShopFrame.BuyFrame.Selected.Value
        return HttpService:JSONDecode(jsonData)
    end)
    if not ok then
        return ODYSSEY.SendNotification(nil, "Crimson Lily", "The item you selected is invalid.", Color3.new(1, 0, 0))
    end

    BuyItem:InvokeServer(vendor, HttpService:JSONEncode(selectedItem), "", quantity)
end