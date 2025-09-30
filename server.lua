local departments = {
    ["lsmpd"] = {
        acePermission = "lsmpd.hours",
        Name = "Los Santos Metro Police Department",
        webhook = "WEBHOOK_HERE"
    },
    ["bcso"] = {
        acePermission = "bcso.hours",
        Name = "Blaine County Sheriff's Office",
        webhook = "WEBHOOK_HERE"
    },
    ["safr"] = {
        acePermission = "safr.hours",
        Name = "San Andreas Fire & Rescue",
        webhook = "WEBHOOK_HERE"
    },
    ["sasp"] = {
        acePermission = "sasp.hours",
        Name = "San Andreas State Police",
        webhook = "WEBHOOK_HERE"
    }
}

local playerData = {}

local function getJsonFilePath()
    return GetResourcePath(GetCurrentResourceName()) .. "/shift_data.json"
end

local function loadData()
    local filePath = getJsonFilePath()
    local file = io.open(filePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        playerData = json.decode(content) or {}
    else
        print("Error: Unable to open file for reading. File path: " .. filePath)
    end
end

local function saveData()
    local filePath = getJsonFilePath()
    local file = io.open(filePath, "w")
    if file then
        local success, err = pcall(function()
            file:write(json.encode(playerData))
        end)
        if not success then
            print("Error encoding JSON: " .. err)
        end
        file:close()
    else
        print("Error: Unable to open file for writing. File path: " .. filePath)
    end
end

local function getPlayerDiscordId(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.find(id, "discord:") then
            return string.sub(id, 9) 
        end
    end
    return nil
end

local function sendWebhook(department, discordId, message)
    local webhookUrl = departments[department].webhook
    local timestamp = os.date("%c")
    if webhookUrl then
        local mention = discordId and ("<@" .. discordId .. ">") or "Unknown User"
        PerformHttpRequest(webhookUrl, function(err, text, headers)
            --[[if err then
                print("Error sending webhook: " .. err)
                if text then print("Response text: " .. text) end
            end]]
        end, 'POST', json.encode({
            embeds = {
                {
                    title = "Shift Update",
                    description = string.format("%s\n%s", mention, message),
                    color = 3447003,
                    footer = {
                        text = timestamp.." | C3 Shift Tracking"
                    }
                }
            }
        }), { ['Content-Type'] = 'application/json' })
    end
end

-- Define the formatDuration function
local function formatDurationWeekly(totalHours)
    local hours = math.floor(totalHours)
    local minutes = math.floor((totalHours - hours) * 60)
    return string.format("%02d:%02d", hours, minutes)
end

--[[local function resetWeeklyHours()
    loadData()
    for department, players in pairs(playerData) do
        local webhookMessage = "Weekly hour totals:\n"
        for discordId, player in pairs(players) do
            webhookMessage = webhookMessage .. string.format("<@%s>: %s\n", discordId, formatDurationWeekly(player.totalHours))
            player.totalHours = 0
        end

        -- Send the webhook for each department with the weekly hour totals, one player per line
        sendWebhook(department, nil, webhookMessage)
    end

    saveData()
end]]
local function resetWeeklyHours()
    loadData()
    for department, players in pairs(playerData) do
        local webhookMessage = "Weekly hour totals:\n"
        for discordId, player in pairs(players) do
            webhookMessage = webhookMessage .. string.format("<@%s>: %s\n", discordId, formatDurationWeekly(player.totalHours))
            player.totalHours = 0
        end

        -- Send the webhook for each department with the weekly hour totals, one player per line
        sendWebhook(department, nil, webhookMessage)
    end

    -- Clear all data from playerData after webhook is sent
    playerData = {}

    -- Save the cleared data to the file
    saveData()
end


-- Function to check if it's Saturday at 12:00 AM and reset weekly hours
local function checkForWeeklyReset()
    local time = os.date("*t")  -- Get the current date and time
    if time.wday == 7 and time.hour == 0 and time.min == 0 then
        resetWeeklyHours()
    end
end

-- Schedule the check for weekly reset every minute
Citizen.CreateThread(function()
    while true do
        checkForWeeklyReset()
        Citizen.Wait(60000)  -- Wait 1 minute
    end
end)

-- Function to format the duration in hours and minutes
local function formatDuration(duration)
    local hours = math.floor(duration)
    local minutes = math.floor((duration - hours) * 60)
    return string.format("%d hours %d minutes", hours, minutes)
end

-- Function to log the player off and send a webhook
local function forceLogShiftOff(department, discordId)
    loadData()
    local player = department and playerData[department][discordId]
    if player and player.clockOnTime > 0 then
        local shiftDuration = (os.time() - player.clockOnTime) / 3600 
        player.totalHours = player.totalHours + shiftDuration
        player.clockOnTime = 0

        saveData()

        local formattedDuration = formatDuration(shiftDuration)
        local formattedTotalHours = formatDuration(player.totalHours)

        sendWebhook(department, discordId, string.format("Clocked off.\nShift Duration: %s\nTotal Weekly Hours: %s", formattedDuration, formattedTotalHours))
    elseif not player then
        print("Error: No data found for Discord ID: " .. discordId)
    end
end

-- Function to check if the player is already clocked on
local function clockOnCheck(department, discordId)
    loadData()
    local player = playerData[department] and playerData[department][discordId]
    if player then
        if player.clockOnTime > 0 and os.time() - player.clockOnTime < 604800 then -- Assuming 1 week is max shift duration
            return true
        end
    end
    return false
end

-- Event handler for player disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    local discordId = getPlayerDiscordId(playerId)  -- Assuming you have a function to get Discord ID from player ID

    -- Loop through all departments to find the player
    loadData()
    for department, players in pairs(playerData) do
        if players[discordId] then
            forceLogShiftOff(department, discordId)
            break
        end
    end
end)

-- Event handler for resource stop/restart
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Loop through all departments and force clock off all players
        loadData()
        for department, players in pairs(playerData) do
            for discordId, _ in pairs(players) do
                forceLogShiftOff(department, discordId)
            end
        end
    end
end)

-- Function to log off all players that were clocked in on resource start
function logOffAllClockedInPlayers()
    -- Load the data first
    loadData()

    -- Loop through all departments
    for department, players in pairs(playerData) do
        for discordId, playerInfo in pairs(players) do
            -- Check if the player was clocked on (clockOnTime > 0 indicates clocked in)
            if playerInfo.clockOnTime > 0 then
                forceLogShiftOff(department, discordId)
            end
        end
    end
end

-- Call this function when the resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        logOffAllClockedInPlayers()
    end
end)

RegisterCommand("clockon", function(source, args, rawCommand)
    local department = args[1]

    if not department then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "Usage: /clockon [department]" }
        })
        return
    end

    department = string.lower(department)

    if not departments[department] then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "Invalid department specified." }
        })
        return
    end

    local discordId = getPlayerDiscordId(source)

    if not IsPlayerAceAllowed(source, departments[department].acePermission) then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "You do not have permission to clock on for this department." }
        })
        return
    end

    -- Check if the player is already clocked on
    if clockOnCheck(department, discordId) then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "You are already clocked on for this department." }
        })
        return
    end

    loadData()
    if not playerData[department] then
        playerData[department] = {}
    end

    playerData[department][discordId] = playerData[department][discordId] or {
        totalHours = 0,
        clockOnTime = 0
    }

    local player = playerData[department][discordId]
    player.clockOnTime = os.time()
    saveData()

    sendWebhook(department, discordId, "Clocked on.")
    TriggerClientEvent('chat:addMessage', source, {
        args = { "Hour Tracker", "Successfully clocked on to " .. departments[department].Name }
    })
end, false)

RegisterCommand("clockoff", function(source, args, rawCommand)
    local department = args[1]

    if not department then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "Usage: /clockoff [department]" }
        })
        return
    end

    department = string.lower(department)

    if not departments[department] then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "Invalid department specified." }
        })
        return
    end

    local discordId = getPlayerDiscordId(source)

    if not playerData[department] then
        TriggerClientEvent('chat:addMessage', source, {
            args = { "Hour Tracker", "You are not clocked on for this department." }
        })
        return
    end

    forceLogShiftOff(department, discordId)
    TriggerClientEvent('chat:addMessage', source, {
        args = { "Hour Tracker", "Successfully clocked off from " .. departments[department].Name }
    })
end, false)



--[[RegisterCommand("HoursReset", function(source, args, rawCommand)
resetWeeklyHours()
end, false)]]