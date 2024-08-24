local lastCrewID = 0
local crews = {
    Private = {}, -- Keeping for structure, even if not used in this example
    Public = {
        -- ["Crew1"] = {
        --     crewname = "Alpha Team",
        --     Owner = 1, -- Simulated owner ID, replace with actual player identifiers as needed
        --     Private = false,
        --     Max = 5,
        --     Current = 3,
        --     Code = 12345,
        --     CrewLogo = "",
        --     CrewMembers = {
        --         ["1"] = {Name = "LeaderOne", Health = 100, Armour = 100, Position = vector2(0, 0), Rank = "leader", serverID = 1},
        --         ["2"] = {Name = "MemberTwo", Health = 100, Armour = 100, Position = vector2(1, 1), Rank = "user", serverID = 2},
        --         ["3"] = {Name = "MemberThree", Health = 100, Armour = 100, Position = vector2(2, 2), Rank = "user", serverID = 3},
        --     }
        -- },
        -- ["Crew2"] = {
        --     crewname = "Bravo Squad",
        --     Owner = 4,
        --     Private = false,
        --     Max = 4,
        --     Current = 2,
        --     Code = 67890,
        --     CrewLogo = "",
        --     CrewMembers = {
        --         ["4"] = {Name = "LeaderFour", Health = 100, Armour = 100, Position = vector2(3, 3), Rank = "leader", serverID = 4},
        --         ["5"] = {Name = "MemberFive", Health = 100, Armour = 100, Position = vector2(4, 4), Rank = "user", serverID = 5},
        --     }
        -- }
    }
}

local playerCrewMap = {}
local crewInvitations = {}

local function generateCrewID()
    lastCrewID = lastCrewID + 1
    return tostring(lastCrewID)
end

-- local function getPlayerDynamicData(playerServerID)
--     local player = GetPlayerServerId(playerServerID)
--     if player then
--         local playerPed = GetPlayerPed(player)
--         local health = GetEntityHealth(playerPed)
--         local armor = GetPedArmour(playerPed)
--         local position = GetEntityCoords(playerPed)
--         local playerName = GetPlayerName(player)
--         return { Name = playerName, Health = health, Armour = armor, Position = position }
--     else
--         return nil
--     end
-- end


local function GetAvatarAsync(source, callback)
    local steamhex = GetPlayerIdentifier(source, 0)
    if steamhex then
        local steamid = tonumber(string.gsub(steamhex, 'steam:', ''), 16)
        PerformHttpRequest('http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='.. GetConvar('steam_webApiKey') ..'&steamids='.. steamid, function(err, data, headers)
            if err == 200 then -- HTTP OK
                local decodedData = json.decode(data)
                if decodedData and decodedData.response and decodedData.response.players and decodedData.response.players[1] then
                    callback(decodedData.response.players[1].avatarfull)
                else
                    callback(nil)
                end
            else
                callback(nil)
            end
        end)
    else
        callback(nil)
    end
end

local function findCrewByMember(playerServerID)
    local playerCrewInfo = playerCrewMap[tostring(playerServerID)]
    if not playerCrewInfo then return nil end
    local crew = crews[playerCrewInfo.crewType][playerCrewInfo.crewID]
    return playerCrewInfo.crewType, crew
end


local function broadcastCrewData(crewID, crewType)
    local crew = crews[crewType][crewID]
    if not crew then return end

    Citizen.CreateThread(function()
        while true do
            local crewData = {}
            for playerServerID, memberData in pairs(crew.CrewMembers) do
                table.insert(crewData, memberData)
            end

            for playerServerID, _ in pairs(crew.CrewMembers) do
                TriggerClientEvent("One-Codes:Crew:UpdateCrewData", tonumber(playerServerID), crewData, crew.Code)
            end

            Citizen.Wait(5000)
        end
    end)
end



function addCrewInvitation(source, targetPlayerId, crewID)
    local crewType, crew = findCrewByMember(source)
    if crew then
        crewInvitations[targetPlayerId] = {
            crewID = crewID,
            crewName = crew.crewname,
            inviterId = source,
            currentMembers = crew.Current,
            exists = true
        }
    end
end

local function addPlayerToCrew(source, crewID, crewType, rank)
    local playerServerID = tostring(source)
    local crew = crews[crewType][crewID]

    if crew and crew.Current < crew.Max then
        crew.CrewMembers[playerServerID] = {
            Name = GetPlayerName(source),
            Health = 100,
            Armour = 100,
            Position = vector2(0, 0),
            Rank = rank or "user",
            serverID = source
        }
        crew.Current = crew.Current + 1
        playerCrewMap[playerServerID] = {crewID = crewID, crewType = crewType}

        broadcastCrewData(crewID, crewType)

        for playerServerID, _ in pairs(crew.CrewMembers) do
            TriggerClientEvent("One-Codes:Crew:UpdateGamerTags", tonumber(playerServerID))
        end

        return true
    else
        return false, "Crew is full or does not exist."
    end
end


local function removePlayerFromCrew(source)
    local playerServerID = tostring(source)
    local playerCrewInfo = playerCrewMap[playerServerID]

    if playerCrewInfo then
        local crew = crews[playerCrewInfo.crewType][playerCrewInfo.crewID]
        if crew then
            local isLeaderLeaving = crew.CrewMembers[playerServerID].Rank == "leader"

            crew.CrewMembers[playerServerID] = nil
            crew.Current = math.max(0, crew.Current - 1)

            playerCrewMap[playerServerID] = nil

            if isLeaderLeaving then
                for remainingPlayerServerID, _ in pairs(crew.CrewMembers) do
                    TriggerClientEvent("One-Codes:Crew:UpdateGamerTags", tonumber(remainingPlayerServerID))
                    TriggerClientEvent('ox_lib:notify', tonumber(remainingPlayerServerID), {title = 'Crew disbanded', message = 'The leader has left the crew.', type = 'error', position = "top"})
                    playerCrewMap[remainingPlayerServerID] = nil
                end
                crews[playerCrewInfo.crewType][playerCrewInfo.crewID] = nil
            else
                for remainingPlayerServerID, _ in pairs(crew.CrewMembers) do
                    TriggerClientEvent("One-Codes:Crew:UpdateGamerTags", tonumber(remainingPlayerServerID))
                    TriggerClientEvent('ox_lib:notify', tonumber(remainingPlayerServerID), {title = 'Member left', message = 'A member has left the crew.', type = 'info', position = "top"})
                end
            end
        end
    end
end



lib.callback.register("One-Codes:Crew:Data", function(source, crewID)
    local crewType, crew = findCrewByMember(source)
    if not crew then
        return false, "Crew not found"
    end

    local crewData = {}
    for serverID, member in pairs(crew.CrewMembers) do
        local health, armor, position = 100, 100, vector3(0, 0, 0)

        if crews[crewType] and crews[crewType][crewID] and crews[crewType][crewID].CrewMembers[serverID] then
            local playerData = crews[crewType][crewID].CrewMembers[serverID]
            health = playerData.Health or health
            armor = playerData.Armour or armor
            position = playerData.Position or position
        end

        table.insert(crewData, {
            serverID = serverID,
            health = health,
            armor = armor,
            position = position
        })
    end
    
    return true, crewData
end)


lib.callback.register("One-Codes:Crew:Create", function(source, name, maxMembers, isPrivate)
    local crewID = generateCrewID()
    local playerServerID = tostring(source)

    GetAvatarAsync(source, function(avatarUrl)
        local crewLogo = avatarUrl or "defaultAvatarUrl"
        local crewType = isPrivate and "Private" or "Public"
        local newCrew = {
            crewname = name,
            Owner = source,
            Private = isPrivate,
            Max = maxMembers,
            Current = 1,
            Code = math.random(100000, 999999),
            CrewLogo = crewLogo,
            CrewMembers = {
                [playerServerID] = {
                    Name = GetPlayerName(source),
                    Health = 100,
                    Armour = 100,
                    Position = vector2(0, 0),
                    Rank = "leader",
                    serverID = source
                }--,
                -- ["12"] = {
                --     Name = "test",
                --     Health = 100,
                --     Armour = 100,
                --     Position = vector2(0, 0),
                --     Rank = "user",
                --     serverID = 12
                -- },
            }
        }

        crews[crewType][crewID] = newCrew
        playerCrewMap[playerServerID] = {crewID = crewID, crewType = crewType}
        
        addPlayerToCrew(source, newCrew, crewType, "leader")
        broadcastCrewData(crewID, crewType)
        TriggerClientEvent("One-Codes:Crew:DisplayCrewData", source, newCrew, crewID)
    end)

    return true, crewID
end)

-- public crews
lib.callback.register("One-Codes:Crew:GetPublicCrews", function(source)
    local publicCrews2 = {}
    for crewID, crew in pairs(crews["Public"]) do
        table.insert(publicCrews2, {
            crewID = crewID,
            crewName = crew.crewname,
            currentMembers = crew.Current,
            maxMembers = crew.Max,
            Code = crew.Code,
            crewLogo = crew.CrewLogo
        })
    end
    return publicCrews2
end)

lib.callback.register("One-Codes:Crew:JoinPublic", function(source, crewID)
    local crew = crews.Public[crewID]
    if crew and crew.Current < crew.Max then
        addPlayerToCrew(source, crew, "Public", "user")
        return true
    else
        return false, "Crew is full or does not exist."
    end
end)

-- invited crews
lib.callback.register("One-Codes:Crew:GetPlayerInvitations", function(source)
    local playerId = tostring(source)
    local playerInvitations = crewInvitations[playerId] or {}
    local validInvitations = {}

    for _, invitation in ipairs(playerInvitations) do
        if crews["Private"][invitation.crewID] or crews["Public"][invitation.crewID] then
            table.insert(validInvitations, invitation)
        end
    end
    
    return validInvitations
end)







-- lib.callback.register("One-Codes:Crew:JoinInvited", function(source)
--     return true
-- end)

-- join via code crew
lib.callback.register("One-Codes:Crew:JoinCrewById", function(source, inputCode)
    local found = false
    local message = "Crew not found with the provided code."

    local codeToCheck = tonumber(inputCode) or inputCode

    for crewType, crewList in pairs(crews) do
        for crewID, crew in pairs(crewList) do
            if tonumber(crew.Code) == codeToCheck then
                found = true
                if crew.Current < crew.Max then
                    local success, errMsg = addPlayerToCrew(source, crewID, crewType, "user")
                    if success then
                        return true, "Joined crew successfully."
                    else
                        return false, errMsg or "Failed to join the crew."
                    end
                else
                    message = "Crew is full."
                end
            end
        end
    end

    return found, message
end)

-- Kick a member from the crew
lib.callback.register("One-Codes:Crew:KickMember", function(source, crewID, memberServerID)
    local crewType, crew = findCrewByMember(source)
    if not crew or crew.CrewMembers[tostring(source)].Rank ~= "leader" then
        return false, "You are not the leader."
    end

    if crew.CrewMembers[memberServerID].Rank == "leader" then
        return false, "You cannot kick the crew leader."
    end

    crew.CrewMembers[memberServerID] = nil
    crew.Current = crew.Current - 1
    playerCrewMap[memberServerID] = nil

    broadcastCrewData(crewID, crewType)
    removePlayerFromCrew(memberServerID)
    TriggerClientEvent('ox_lib:notify', memberServerID, {title = 'You have been kicked from the crew',type = 'warning',position = "top"})
    return true
end)


-- Promote a member in the crew
lib.callback.register("One-Codes:Crew:PromoteMember", function(source, crewID, memberServerID)
    local crewType, crew = findCrewByMember(source)
    if not crew or not crew.CrewMembers[tostring(source)] or crew.CrewMembers[tostring(source)].Rank ~= "leader" then
        TriggerClientEvent('ox_lib:notify', source, {title = 'Error', message = 'You are not the leader.', type = 'error', position = "top"})
        return false, "You are not the leader."
    end

    if crew.CrewMembers[memberServerID].Rank == "leader" then
        return false, "You cannot promote the crew leader."
    end

    local memberKey = tostring(memberServerID)

    for playerServerID, _ in pairs(crew.CrewMembers) do
        TriggerClientEvent("One-Codes:UpdateGamerTags", tonumber(playerServerID))
    end

    if crew.CrewMembers[memberKey] then
        crew.CrewMembers[memberKey].Rank = "co-leader"
        broadcastCrewData(crewID, crewType)
        TriggerClientEvent('ox_lib:notify', memberServerID, {title = 'You have promoted to co-leader.', type = 'info', position = "top"})
        return true
    else
        TriggerClientEvent('ox_lib:notify', source, {title = 'Member not found.', type = 'error', position = "top"})
        return false, "Member not found."
    end
end)

lib.callback.register("One-Codes:Crew:DemoteMember", function(source, crewID, memberServerID)
    local crewType, crew = findCrewByMember(source)
    if not crew or not crew.CrewMembers[tostring(source)] or crew.CrewMembers[tostring(source)].Rank ~= "leader" then
        TriggerClientEvent('ox_lib:notify', source, {title = 'Error', message = 'You are not the leader.', type = 'error', position = "top"})
        return false, "You are not the leader."
    end

    local memberKey = tostring(memberServerID)

    if crew.CrewMembers[memberKey] then
        crew.CrewMembers[memberKey].Rank = "user"
        broadcastCrewData(crewID, crewType)
        TriggerClientEvent('ox_lib:notify', memberServerID, {title = 'You have demoted to user.', type = 'info', position = "top"})
        return true
    else
        TriggerClientEvent('ox_lib:notify', source, {title = 'Member not found.', type = 'error', position = "top"})
        return false, "Member not found."
    end
end)

lib.callback.register("One-Codes:Crew:Invite", function(source, crewID, targetPlayerId)
    local crewType, crew = findCrewByMember(source)
    if not crew or (crew.CrewMembers[tostring(source)].Rank ~= "leader" and crew.CrewMembers[tostring(source)].Rank ~= "co-leader") then
        return false, "You do not have permission to invite."
    end

    crewInvitations[tostring(targetPlayerId)] = crewInvitations[tostring(targetPlayerId)] or {}

    for _, invitation in ipairs(crewInvitations[tostring(targetPlayerId)]) do
        if invitation.crewID == crewID then
            return false, "Player already invited to this crew."
        end
    end

    table.insert(crewInvitations[tostring(targetPlayerId)], {
        crewID = crewID,
        crewName = crew.crewname,
        Code = crew.Code,
        Logo = crew.CrewLogo,
        inviterId = source,
        currentMembers = crew.Current,
    })

    TriggerClientEvent('ox_lib:notify', targetPlayerId, {title = 'You have been invited to '..crew.crewname..' crew', type = 'info', position = "top"})
    return true
end)

lib.callback.register("One-Codes:Crew:GetLocalName", function(source)
    return ""..GetPlayerName(source).." Crew"
end)

lib.callback.register("One-Codes:Crew:Leave", function(source, crewID, memberServerID)
    removePlayerFromCrew(source)
    return true
end)

RegisterNetEvent("One-Codes:Crew:SendPlayerData")
AddEventHandler("One-Codes:Crew:SendPlayerData", function(playerData)
    local source = source
    local playerServerID = tostring(source)
    
    local playerCrewInfo = playerCrewMap[playerServerID]
    if playerCrewInfo then
        local crew = crews[playerCrewInfo.crewType][playerCrewInfo.crewID]
        if crew and crew.CrewMembers[playerServerID] then
            crew.CrewMembers[playerServerID].PlayerPed = playerData.PlayerPed
            crew.CrewMembers[playerServerID].Health = playerData.Health
            crew.CrewMembers[playerServerID].Armour = playerData.Armour
            crew.CrewMembers[playerServerID].Position = playerData.Position
            broadcastCrewData(playerCrewInfo.crewID, playerCrewInfo.crewType)
        end
    end
end)

AddEventHandler("playerDropped", function(reason)
    local source = source
    removePlayerFromCrew(source)
end)

RegisterCommand("crew", function(source)
    local playerServerID = tostring(source)
    local playerCrewInfo = playerCrewMap[playerServerID]

    if playerCrewInfo then
        local crew = crews[playerCrewInfo.crewType][playerCrewInfo.crewID]
        if crew then
            TriggerClientEvent("One-Codes:Crew:DisplayCrewData", source, crew, playerCrewInfo.crewID)
        end
    else
        TriggerClientEvent("One-Codes:Crew:ShowMainCrewMenu", source)
    end
end, false)