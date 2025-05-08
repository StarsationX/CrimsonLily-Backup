local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locations = require(ReplicatedStorage.RS.Modules.Locations)

local UnloadedIslands = ReplicatedStorage.RS.UnloadIslands

local Teleports = {}
ODYSSEY.Teleports = Teleports

function Teleports.GetRegions()
	local regions = {}

	--
	for regionName, regionData in pairs(Locations.Regions) do
		local copy = table.clone(regionData)
		local areas = {}
		copy.Name = regionName

		--
		local regionModel = workspace.Map:FindFirstChild(regionName)
		local unloadedModel = UnloadedIslands:FindFirstChild(regionName)

		local regionDescs = regionModel:GetDescendants()

		if unloadedModel then
			for _, v in ipairs(unloadedModel:GetDescendants()) do
				table.insert(regionDescs, v)
			end
		end
		--

		-- areas
		if regionData.Areas then
			for areaName, areaData in pairs(regionData.Areas) do
				local areaCopy = table.clone(areaData)
				areaCopy.Name = areaName
				areaCopy.Region = copy
	
				if not areaData.Center then
					-- area has no Center, but detected through raycast
					for _, v in ipairs(regionDescs) do
						if v:IsA("StringValue") and v.Name == "DisplayName" and v.Value == areaName then
							local possiblePart1 = regionModel:FindFirstChildWhichIsA("BasePart", true)
							local possiblePart2 = possiblePart1

							if unloadedModel then
								possiblePart2 = unloadedModel:FindFirstChildWhichIsA("BasePart", true)
							end
							
							areaCopy.Center = (possiblePart1 and possiblePart1.Position) or (possiblePart2 and possiblePart2.Position)
							areaCopy.Model = v.Parent
							break
						end
					end
				end

				-- gah
				if not areaCopy.Center then
					areaCopy.Center = copy.Center
					areaCopy.Model = regionModel
				end

				table.insert(areas, areaCopy)
			end
		end

		copy.Areas = areas
		table.insert(regions, copy)
	end

	table.sort(regions, function(a, b)
		return a.Name < b.Name
	end)
	--

	return regions
end

function Teleports.TeleportToRegion(place)
	local character = ODYSSEY.GetLocalCharacter()
	if not character then return end

	local region = (place.Region and place.Region.Name) or place.Name
	local regionModel = workspace.Map:FindFirstChild(region)
	local center = regionModel:FindFirstChild("Center")

	character:SetPrimaryPartCFrame(center.CFrame)
	character.HumanoidRootPart.Anchored = true

	task.wait(0.15)
	ODYSSEY.Gameplay.ForceLoad()
	
	while not regionModel:FindFirstChild("Fragmentable") do
		regionModel.ChildAdded:Wait()
	end

	--------------------------------------------------------
	local model = place.Model or regionModel

	local destinationPart = nil
	local highestY = -9e9

	local finalPos = nil

	for _, v in ipairs(model:GetDescendants()) do
		if not v:IsA("BasePart") then continue end
		if not v.CanCollide then continue end

		if v.Position.Y + v.Size.Y/2 > highestY then
			highestY = v.Position.Y + v.Size.Y/2
			destinationPart = v
		end
	end

	if destinationPart then
		finalPos = Vector3.new(
			destinationPart.Position.X,
			highestY,
			destinationPart.Position.Z
		)
	else
		finalPos = regionModel.Center.Position
		ODYSSEY.SendNotification(nil, "Crimson Lily", "Failed to find an appropriate teleport destination.", Color3.new(1, 0, 0))
	end
	
	character:SetPrimaryPartCFrame(CFrame.new(finalPos))
	character.HumanoidRootPart.Anchored = false
end

Teleports.Regions = Teleports.GetRegions()

--
function Teleports.ToShip()
	local boat = workspace.Boats:FindFirstChild(ODYSSEY.GetLocalPlayer().Name.. "Boat")
	if not boat then
		ODYSSEY.SendNotification(nil, "Crimson Lily", "You don't have a ship spawned.", Color3.new(1, 0, 0))
		return
	end

	local character = ODYSSEY.GetLocalCharacter()
	character:SetPrimaryPartCFrame(boat.PrimaryPart.CFrame * CFrame.new(0, 10, 0))
end

function Teleports.ToMarker(markerName)
	local marker = workspace.CurrentCamera:FindFirstChild(markerName)
	if marker then
		local character = ODYSSEY.GetLocalCharacter()
		character:SetPrimaryPartCFrame(marker.CFrame)
	else
		ODYSSEY.SendNotification(nil, "Crimson Lily", "This marker does not exist.", Color3.new(1, 0, 0))
	end
end