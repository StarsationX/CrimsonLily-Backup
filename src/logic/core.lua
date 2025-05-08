local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- send notif funcc
do
	local rem = ReplicatedStorage.RS.Remotes.UI.Notification
	local upvalues = getupvalues(getconnections(rem.OnClientEvent)[1].Function)[1]
	local notifFunc = upvalues.Notification
	
	ODYSSEY.SendNotification = notifFunc
end

-- load area func
do
    local LoadArea
    for _, connection in next, getconnections(ReplicatedStorage.RS.Remotes.Misc.OnTeleport.OnClientEvent) do
        local env = connection.Function and getfenv(connection.Function)
        if env and tostring(rawget(env, "script")) == "Unloading" then
            LoadArea = debug.getupvalue(connection.Function, 2)
            break
        end
    end

    ODYSSEY.LoadArea = LoadArea
end

-- load npc func
do
    local LoadCheck
    for _, connection in pairs(getconnections(workspace.NPCs.ChildAdded)) do
        local env = getfenv(connection.Function)
        if rawget(env, "script").Name == "SetupNPCs" then
            LoadCheck = getupvalues(connection.Function)[2]
            break
        end
    end

    local upvalues = getupvalues(LoadCheck)
    
    ODYSSEY.NPCLoadCheck = upvalues[1]
    ODYSSEY.EnemyLoadCheck = upvalues[2]
end