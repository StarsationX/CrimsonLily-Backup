local UILib = load("src/lib/xsxLib.lua")
UILib.title = "The Crimson Lily"
UILib:Introduction()

task.wait(0.5)
local window = UILib:Init()

ODYSSEY.Maid:GiveTask(function()
	window:Remove()
end)

if game.PlaceId ~= 3272915504 then
	load("src/ui/combat.lua")(UILib, window)
	load("src/ui/teleport.lua")(UILib, window)
	load("src/ui/farming.lua")(UILib, window)
	load("src/ui/money.lua")(UILib, window)
	load("src/ui/trackers.lua")(UILib, window)
end

load("src/ui/gameplay.lua")(UILib, window)
load("src/ui/info.lua")(UILib, window)