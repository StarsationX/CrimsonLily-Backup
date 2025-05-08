local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RS = ReplicatedStorage:WaitForChild("RS")

local function InitNavyInfluence(tab)
    local navyInfluence = RS.NavyInfluence
    local maxNavyInfluence = 1000000
    local inf = tab:NewLabel()
   
    local function update()
        local percentage = navyInfluence.Value / maxNavyInfluence
        inf:Text(string.format("Grand Navy influence: %.2f", percentage * 100).. "%")
    end

    update()
    ODYSSEY.Maid:GiveTask(navyInfluence.Changed:Connect(update))
end

local function InitChangelogs(tab)
    local changelogs = load("src/ui/changelogs.lua")

    tab:NewSection("Changelogs")
    for _, bigEntry in ipairs(changelogs) do
        tab:NewLabel(string.format("<b>%s</b>", bigEntry.Date))

        for _, smallEntry in ipairs(bigEntry.Entries) do
            tab:NewLabel("- ".. smallEntry)
        end
    end
end

return function(UILib, window)
	local tab = window:NewTab("Info")

	InitNavyInfluence(tab)
    InitChangelogs(tab)
end