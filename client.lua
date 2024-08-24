local playersData = {}
local playerGamerTags = {}
local originalRelationshipGroupHash = nil
local uion = false

function InitializePlayerRelationshipGroup()
  if not originalRelationshipGroupHash then
      originalRelationshipGroupHash = GetPedRelationshipGroupHash(PlayerPedId())
  end
end

function SetRelationDamage(id)
  InitializePlayerRelationshipGroup()

  local retval, hash
  if id and (not mySquadHash or not DoesRelationshipGroupExist(mySquadHash)) then
      retval, hash = AddRelationshipGroup(("squad_%s"):format(id))
      mySquadHash = hash
  else
      hash = mySquadHash
  end

  if hash then
      SetPedRelationshipGroupHash(PlayerPedId(), hash)
      SetRelationshipBetweenGroups(0, hash, hash)
      SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), false, hash)
  end
end

function ResetPlayerRelationshipGroup()
  if originalRelationshipGroupHash then
      SetPedRelationshipGroupHash(PlayerPedId(), 0x6F0783F5)
      SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), true,  originalRelationshipGroupHash)
      RemoveRelationshipGroup(originalRelationshipGroupHash)
      --SetPedRelationshipGroupHash(PlayerPedId(), originalRelationshipGroupHash)
  end
end

lib.registerContext({
  id = 'crew',
  title = 'KaunoPVP.LT Crew',
  options = {
    {
      title = 'Create Crew',
      icon = 'circle',
      onSelect = function()
        lib.showContext('CreateCrew')
      end,
    },
    {
      title = 'Join Public Crew',
      icon = 'circle',
      onSelect = function()
        local publicCrews = lib.callback.await("One-Codes:Crew:GetPublicCrews", false)

        print(json.encode(publicCrews))
    
        local options = {}
        for _, crew in ipairs(publicCrews) do
            table.insert(options, {
                title = crew.crewName,
                description = 'Members: ' .. crew.currentMembers .. '/' .. crew.maxMembers,
                onSelect = function()
                    local joinSuccess, errorMsg = lib.callback.await("One-Codes:Crew:JoinCrewById", false, crew.Code)
                    if joinSuccess then
                        print("Joined crew: " .. crew.crewName)
                        ExecuteCommand("clearcrewtags")
                        SetRelationDamage(crew.Code)
                        lib.notify({title = "Joined crew: " .. crew.crewName..""})
                    else
                        print(errorMsg or "Unable to join crew.")
                        lib.notify({title = errorMsg or "Unable to join crew."})
                    end
                end,
                image = crew.crewLogo
            })
        end
        
        lib.registerContext({
            id = 'public_crews_menu',
            title = 'Public Crews',
            options = options
        })
    
        lib.showContext('public_crews_menu')
      end,
    },    
    {
      title = 'Join Invited Crew',
      icon = 'circle',
      onSelect = function()
        local invitations = lib.callback.await("One-Codes:Crew:GetPlayerInvitations", false)
    
        local options = {}
        for _, invitation in ipairs(invitations) do
            table.insert(options, {
                title = invitation.crewName,
                description = 'Invited by: ' .. invitation.inviterId .. ', Members: ' .. invitation.currentMembers,
                onSelect = function()
                    local joinSuccess, errorMsg = lib.callback.await("One-Codes:Crew:JoinCrewById", false, invitation.Code)
                    if joinSuccess then
                        print("Joined crew: " .. invitation.crewName)
                        lib.notify({title = "Joined crew: " .. invitation.crewName..""})

                        ExecuteCommand("clearcrewtags")
                        --SetRelationDamage(invitation.Code)
                    else
                        lib.notify({title = errorMsg or "Unable to join crew."})
                        print(errorMsg or "Unable to join crew.")
                    end
                end,
            })
        end
        
        lib.registerContext({
            id = 'invitations_menu',
            title = 'Crew Invitations',
            options = options
        })
    
        lib.showContext('invitations_menu')
      end,
    },
    {
      title = 'Join Crew Via Code',
      icon = 'circle',
      onSelect = function()
        local input = lib.inputDialog('Basic dialog', {'Crew Code'})
        if not input then return end
        local status, msg = lib.callback.await("One-Codes:Crew:JoinCrewById", false, input[1])
        if status then
          print("You have joined the crew.")
          lib.notify({title = "You have joined the crew."})
          ExecuteCommand("clearcrewtags")
          --SetRelationDamage(input[1])
        else
          lib.notify({title = msg or "Unable to join crew."})
          print(msg or "Unable to join crew.")
        end
      end,
    },
  }
})


lib.registerContext({
  id = 'CreateCrew',
  title = 'KaunoPVP.LT Crew',
  options = {
    {
      title = 'Create Crew',
      icon = 'circle',
      onSelect = function()
        local getname = lib.callback.await("One-Codes:Crew:GetLocalName", false)
        local input = lib.inputDialog('Crew Creation Menu', {
          {type = 'input', label = 'Crew Name', required = true, default = getname, min = 4, max = 16, required = true},
          {type = 'slider', label = 'How many players can join the crew', min = 2, max = 12, required = true},
          {type = 'checkbox', label = 'Private Crew?', required = false},
        })
         

        if not input then return end
        if Config.DEV then
          print(json.encode(input))
        end
        local sucess = lib.callback.await("One-Codes:Crew:Create", false, input[1], input[2], input[3])
        if sucess then
          lib.notify({title = "Created Crew with name "..input[1]..""})
          print("done")
          ExecuteCommand("clearcrewtags")
        else
          lib.notify({title = "something was wrong?"})
          print("something was wrong?")
        end
      end,
    },
  }
})



RegisterNetEvent('One-Codes:Crew:DisplayCrewData', function(crewData, crewId)
  --SetRelationDamage(crewData.Code)
  print(json.encode(crewData))
  local crewOptions = {
    {
      title = 'Crew Info',
      image = crewData.CrewLogo,
      metadata = {
        { label = 'Crew Code',       value = crewData.Code },
        { label = 'Crew Name',       value = crewData.crewname },
        { label = 'Crew Private ',   value = crewData.Private },
        { label = 'Joined Members ', value = crewData.Current },
      },
    },
    -- {
    --   title = 'Vault',
    --   onSelect = function()
    --     local success, errorMsg = lib.callback.await("One-Codes:Crew:Leave", false, crewId)
    --     if success then
    --       print("You have left the crew.")
    --       lib.notify({title = "You have left the crew."})
    --       ExecuteCommand("clearcrewtags")
    --       ResetPlayerRelationshipGroup()
    --     else
    --       lib.notify({title = errorMsg or "Unable to leave crew."})
    --       print(errorMsg or "Unable to leave crew.")
    --     end
    --   end,
    --   icon = 'vault',
    -- },
    {
      title = 'Leave Crew',
      onSelect = function()
        local success, errorMsg = lib.callback.await("One-Codes:Crew:Leave", false, crewId)
        if success then
          print("You have left the crew.")
          lib.notify({title = "You have left the crew."})
          ExecuteCommand("clearcrewtags")
          ResetPlayerRelationshipGroup()
        else
          lib.notify({title = errorMsg or "Unable to leave crew."})
          print(errorMsg or "Unable to leave crew.")
        end
      end,
      icon = 'door-open',
    },
    {
      title = 'Invite To Crew',
      onSelect = function()
        local targetPlayerId = lib.inputDialog('Invite Player', {'Enter Player ID'})
        if targetPlayerId then
          lib.callback.await("One-Codes:Crew:Invite", false, crewId, tonumber(targetPlayerId[1]), function(success, errorMsg)
            if success then
              lib.notify({title = "Invitation sent."})
              print("Invitation sent.")
            else
              lib.notify({title = errorMsg or "Unable to send invitation."})
              print(errorMsg or "Unable to send invitation.")
            end
          end)
        end
      end,
      icon = 'user-plus',
      disabled = crewData.CrewMembers[tostring(GetPlayerServerId(PlayerId()))].Rank ~= "leader" and crewData.CrewMembers[tostring(GetPlayerServerId(PlayerId()))].Rank ~= "co-leader",
    }    
  }

  for _, member in pairs(crewData.CrewMembers) do
    local memberOption = {
      title = member.Name,
      description = 'Rank: ' .. member.Rank,
      icon = 'user',
      metadata = {
        { label = 'Health', value = member.Health },
        { label = 'Armor',  value = member.Armour },
      },
      onSelect = function()
        TriggerEvent("One-Codes:Crew:HandleMemberActions", member, crewData, crewId)
      end,
    }
    table.insert(crewOptions, memberOption)
  end

  lib.registerContext({
    id = 'crew_menu',
    title = crewData.crewname,
    options = crewOptions
  })

  lib.showContext('crew_menu')
end)

RegisterNetEvent('One-Codes:Crew:HandleMemberActions', function(member, crewData, crewId)
  local options = {
    {
      title = 'Promote to Co-Leader',
      onSelect = function()
        lib.callback.await("One-Codes:Crew:PromoteMember", false, crewId, member.serverID, function(success, errorMsg)
          if success then
            lib.notify({title = ""..member.Name .. " has been promoted."})
              print(member.Name .. " has been promoted.")
          else
              lib.notify({title = errorMsg or "Unable to promote member."})
              print(errorMsg or "Unable to promote member.")
          end
      end)
      end,
      icon = 'arrow-up',
      disabled = crewData.CrewMembers[tostring(GetPlayerServerId(PlayerId()))].Rank == "user" or member.Rank == "leader",
    },
    {
      title = 'Demote to user',
      onSelect = function()
        lib.callback.await("One-Codes:Crew:DemoteMember", false, crewId, member.serverID, function(success, errorMsg)
          if success then
            lib.notify({title = ""..member.Name .. " has been demoted."})
              print(member.Name .. " has been demoted.")
          else
              lib.notify({title = errorMsg or "Unable to demote member."})
              print(errorMsg or "Unable to demote member.")
          end
      end)
      end,
      icon = 'arrow-down',
      disabled = crewData.CrewMembers[tostring(GetPlayerServerId(PlayerId()))].Rank ~= "leader" or member.Rank == "leader",
    },
    {
      title = 'Kick from Crew',
      onSelect = function()
        lib.callback.await("One-Codes:Crew:KickMember", false, crewId, member.serverID, function(success, errorMsg)
          if success then
              lib.notify({title = ""..member.Name .. " has been kicked."})
              print(member.Name .. " has been kicked.")
              ExecuteCommand("clearcrewtags")
          else
              lib.notify({title = errorMsg or "Unable to kick member."})
              print(errorMsg or "Unable to kick member.")
          end
      end)
      end,
      icon = 'user-slash',
      disabled = crewData.CrewMembers[tostring(GetPlayerServerId(PlayerId()))].Rank == "user" or member.Rank == "leader",
    }
  }

  local menuId = 'member_actions_' .. tostring(member.serverID)
  lib.registerContext({
    id = menuId,
    title = member.Name .. ' Actions',
    options = options
  })

  lib.showContext(menuId)
end)


RegisterNetEvent("One-Codes:Crew:ShowMainCrewMenu", function()
  ResetPlayerRelationshipGroup()
  lib.showContext('crew')
end)

local function populatePlayerGamerTags(playerData)
  for _, data in ipairs(playerData) do
    local playerId = data.serverID
    local playerName = data.Name
    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
    if playerPed and playerName then
        --print("Creating gamer tag for:", playerName, "Ped:", playerPed)
        local gamerTag = CreateMpGamerTag(playerPed, playerName, false, false, "", 0)
        if gamerTag == -1 then
            --print("Failed to create GamerTag for player:", playerName)
        else
            --print("GamerTag created:", gamerTag, "for player:", playerName)
            playerGamerTags[playerId] = { Name = playerName, gamerTag = gamerTag, Rank = data.Rank}
        end
    else
       -- print("Invalid data for gamer tag creation:", playerName, playerPed)
    end
end
end


RegisterNetEvent("One-Codes:Crew:UpdateCrewData")
AddEventHandler("One-Codes:Crew:UpdateCrewData", function(crewData, code)
  if Config.DEV then
    print(json.encode(crewData))
    print(code)
  end
    playersData = crewData 
    SetRelationDamage(code)
    populatePlayerGamerTags(crewData)
end)


local fivemGamerTagCompsEnum = {
    GamerName = 0,
    CrewTag = 1,
    HealthArmour = 2,
    BigText = 3,
    AudioIcon = 4,
    UsingMenu = 5,
    PassiveMode = 6,
    WantedStars = 7,
    Driver = 8,
    CoDriver = 9,
    Tagged = 12,
    GamerNameNearby = 13,
    Arrow = 14,
    Packages = 15,
    InvIfPedIsFollowing = 16,
    RankText = 17,
    Typing = 18
}

local function setGamerTagFivem(targetTag, pid, playerName, playerServerId, role)
  -- Existing setup for name, health, and audio icon

  -- Determine role and adjust gamer tag appearance
  if role == "leader" then
      -- Example: Set the tag color to gold for the leader
      SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.GamerName, 46) -- Gold color for leader
      -- Optionally add a text component if the API allows, to show "Leader"
  elseif role == "co-leader" then
      -- Example: Set the tag color to silver for the co-leader
      SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.GamerName, 44) -- Silver color for co-leader
      -- Optionally add a text component if the API allows, to show "Co-Leader"
  else
      -- Default color or style for regular members
      SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.GamerName, 1)
  end

  -- Setup AudioIcon (optional, adjust as needed)
  SetMpGamerTagAlpha(targetTag, fivemGamerTagCompsEnum.HealthArmour, 255)
  SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.HealthArmour, 1)

  SetMpGamerTagAlpha(targetTag, fivemGamerTagCompsEnum.AudioIcon, 255)
  if NetworkIsPlayerTalking(pid) then
      SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.AudioIcon, true)
      SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.AudioIcon, 12) --HUD_COLOUR_YELLOW
  else
      SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.AudioIcon, false)
  end
end

-- Modify the clearGamerTagFivem function to clear all components
local function clearGamerTagFivem(targetTag)
  for component, _ in pairs(fivemGamerTagCompsEnum) do
      SetMpGamerTagVisibility(targetTag, component, false)
  end
end

-- Update the setGamerTagFunc and clearGamerTagFunc based on the game platform
local setGamerTagFunc = setGamerTagFivem
local clearGamerTagFunc = clearGamerTagFivem

-- Modify the showGamerTags function to pass player name and server ID to setGamerTagFunc
local function showGamerTags()
 -- print("Updating gamer tags...") -- Debug print
  local curCoords = GetEntityCoords(PlayerPedId())
  local allActivePlayers = GetActivePlayers()

  for _, pid in ipairs(allActivePlayers) do
      local playerServerId = GetPlayerServerId(pid)
      if playerGamerTags[playerServerId] then -- Ensure we have a gamerTag for this player
          local targetPed = GetPlayerPed(pid)
          local targetTag = playerGamerTags[playerServerId].gamerTag
          local targetPedCoords = GetEntityCoords(targetPed)
          if #(targetPedCoords - curCoords) <= 150 then
              -- Use enhanced setGamerTagFivem with additional dynamic updates
              setGamerTagFivem(targetTag, pid, playerGamerTags[playerServerId].Name, playerServerId, playerGamerTags[playerServerId].Rank)
          else
              clearGamerTagFivem(targetTag)
          end
      end
  end
end


local playerBlips = {}

local function DrawPlayerInfo()
  local memberCounter = 0

  for _, memberData in ipairs(playersData or {}) do
      memberCounter = memberCounter + 1

      local blipId = playerBlips[memberData.serverID]

      if not blipId then
          local pos = memberData.Position
          blipId = AddBlipForCoord(pos.x, pos.y, pos.z)
          SetBlipSprite(blipId, 1)
          SetBlipColour(blipId, 2)
          SetBlipScale(blipId, 0.85)
          --ShowHeadingIndicatorOnBlip(blipId, true) -- Optionally show heading indicator on blip

          BeginTextCommandSetBlipName("STRING")
          AddTextComponentString(memberCounter .. "# Member: " .. memberData.Name)
          EndTextCommandSetBlipName(blipId)

          playerBlips[memberData.serverID] = blipId
      else
          local pos = memberData.Position
          SetBlipCoords(blipId, pos.x, pos.y, pos.z)
      end
  end

  for serverID, blipId in pairs(playerBlips) do
      local found = false
      for _, memberData in ipairs(playersData) do
          if memberData.serverID == serverID then
              found = true
              break
          end
      end

      if not found then
          RemoveBlip(blipId)
          playerBlips[serverID] = nil
      end
  end
end

local function collectAndSendPlayerData(playerPed)
    local health = GetEntityHealth(playerPed)
    local armor = GetPedArmour(playerPed)
    local position = GetEntityCoords(playerPed)
    local playerData = {
        PlayerPed = playerPed,
        Health = health,
        Armour = armor,
        Position = position
    }
    TriggerServerEvent("One-Codes:Crew:SendPlayerData", playerData)
end

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
      local playerPed = PlayerPedId()
      collectAndSendPlayerData(playerPed)
      DrawPlayerInfo()
      showGamerTags()
  end
end)

local function removePlayerGamerTag(playerId)
  local tagInfo = playerGamerTags[playerId]
  if tagInfo and tagInfo.gamerTag ~= -1 then
      RemoveMpGamerTag(tagInfo.gamerTag)
      playerGamerTags[playerId] = nil
  else
      print("GamerTag not found or already removed for player ID:", playerId)
  end
end

RegisterNetEvent("One-Codes:Crew:UpdateGamerTags", function()
    ExecuteCommand("clearcrewtags")
end)


AddEventHandler("onResourceStop", function(resource)
  if resource == GetCurrentResourceName() then
      for playerId, tagInfo in pairs(playerGamerTags) do
          if tagInfo.gamerTag ~= -1 then
              RemoveMpGamerTag(tagInfo.gamerTag)
              playerGamerTags[playerId] = nil
          end
      end
      ResetPlayerRelationshipGroup()
  end
end)

RegisterCommand("clearcrewtags", function(source, args, rawCommand)
  for playerId, tagInfo in pairs(playerGamerTags) do
      if tagInfo.gamerTag ~= -1 then
          RemoveMpGamerTag(tagInfo.gamerTag)
          playerGamerTags[playerId] = nil
          ResetPlayerRelationshipGroup()
          print("Manually cleared gamer tag for player ID:", playerId)
      end
  end
end, false)