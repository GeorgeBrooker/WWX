-- track a group, allow configuration of what kind of coordinator is present (none v jtac) and what designation is available (none, pave penny, LGB guidance)-- function to follow a group

CAS = {}
CAS.JTACType = {
    NONE = 1,
    JTAC = 2,
    JTAC_DESIGNATOR = 3,
}
local cas = {}
local casGroups = {
    [1] = {},
    [2] = {},
}
local groups = {

}
local busyFrequencies = {
    [1] = { -- Red
        [0] = {CASFREQS[1][0]["main"], RADIOFREQS[1]["EWR"], RADIOFREQS[1]["MUSIC"]} , -- AM
        [1] = {CASFREQS[2][1]["main"], }, -- FM
    },
    [2] = { -- Blue
        [0] = {CASFREQS[2][0]["main"], RADIOFREQS[2]["AIRFIELD"], RADIOFREQS[2]["EWR"], RADIOFREQS[2]["MUSIC"]}, -- AM
        [1] = {CASFREQS[2][1]["main"], }, -- FM
    },

}
-- I cannot believe LUA dosn't have a way to do this natively.
for airfieldFreq in RADIOFREQS[1]["AIRFIELD"] do
    table.insert(busyFrequencies[1][0], airfieldFreq) -- Red AM
end
for airfieldFreq in RADIOFREQS[2]["AIRFIELD"] do
    table.insert(busyFrequencies[2][0], airfieldFreq) -- Blue AM
end

local stoppedGroups = {

}
local smokeColors = {
    [1] = 0,
    [2] = 2,
    [3] = 3,
}
local smokeNames = {
    [0] = " green ",
    [2] = " white ",
    [3] = " orange "
}
local stackZones = {
    [1] = "RedCas",
    [2] = "BlueCas"
}
local stackPoints = {
    [1] = {},
    [2] = {}
}

cas.loopInterval = 5
cas.battleLoopInterval = 9
cas.engagementDistance = 3000
cas.dangerClose = 1200
cas.casHeight = 1000
cas.casRadius = 4000

function CAS.followGroup(coalitionId, groupName, callsign, jtacType, frequency, modulation)
    local amFreq = cas.generateFrequency(coalitionId, 0) -- AM Frequency
    local fmFreq = cas.generateFrequency(coalitionId, 1) -- FM Frequency
    groups[groupName] = { amFreq = amFreq, fmFreq = fmFreq, currentPoint = {}, heading = 0, coalitionId = coalitionId, groupName = groupName, callsign = callsign, jtacType = jtacType, followStartTime = timer:getTime(), inContact = false, contactStartTime = -1, isMoving = false, targetGroups = {}, smokeTime = -1, smokeColor = -1, markups = {radio = {}, bearings = {}}, lasers = {} }
    local follwingGroup = Group.getByName(groupName)
    if follwingGroup then
        local followingController = follwingGroup:getController()
        if followingController and frequency and modulation then
            local cmd = {}
            cmd.id = "SetFrequency"
            cmd.params = {}
            cmd.params.frequency = tonumber(frequency) * 1000000
            cmd.params.modulation = modulation
            cmd.params.power = 120
            followingController:setCommand(cmd)
        end
    end
end
function cas.generateFrequency(coalitionId, modulation)
    local frequency = math.random(CASFREQS[coalitionId][modulation]["min"], CASFREQS[coalitionId][modulation]["max"])
    if math.random(0, 1) == 1 then
        frequency = frequency + 0.5
    end

    local iters = 0 -- Stop this from fucking everything up if it dosn't work for some reason.
    while cas.isFreqBusy(frequency, coalitionId, modulation) and iters < 10 do
        frequency = math.random(CASFREQS[coalitionId][modulation]["min"], CASFREQS[coalitionId][modulation]["max"])
        if math.random(0, 1) == 1 then
            frequency = frequency + 0.5
            iters = iters + 1
        end
    end

    return frequency
end
function cas.isFreqBusy(frequency, coalitionId, modulation)
    local isBusy = false
    for _, busyFreq in pairs(busyFrequencies[coalitionId][modulation]) do
        if math.abs(frequency - busyFreq) < 0.5 then
            isBusy = true
            break
        end
    end
    return isBusy
end
function cas.loop()
    for groupName, groupInfo in pairs(groups) do
        local group = Group.getByName(groupName)
        if group then
            -- ASSIGN THE FREQUENCIES HERE DUM DUM!
            cas.checkGroup(groupName)
        else
            if groups[groupName].markups.radio then
                for i = 1, #groups[groupName].markups.radio do
                    trigger.action.removeMark(groups[groupName].markups.radio[i])
                end
            end
            groups[groupName] = nil
        end
    end
    timer.scheduleFunction(cas.loop, nil, timer:getTime() + cas.loopInterval)
end
function cas.checkGroup(groupName)
    local checkingGroup = Group.getByName(groupName)
    if checkingGroup then
        local checkingUnit = checkingGroup:getUnit(1)
        if checkingUnit then
            local checkingPoint = checkingUnit:getPoint()
            groups[groupName].isMoving = Utils.getSpeed(checkingUnit:getVelocity()) > 0.1
            if checkingPoint then
                groups[groupName].currentPoint = checkingPoint
                local cgController = checkingGroup:getController()
                if cgController then
                    local detectedEnemies = cgController:getDetectedTargets(Controller.Detection.VISUAL,Controller.Detection.OPTIC)
                    local detectedGroups = {}
                    if #detectedEnemies > 0 then
                        for i = 1, #detectedEnemies do
                            local detectedObject = detectedEnemies[i].object
                            if detectedObject then
                                if detectedObject:getDesc().category == 2 and detectedObject:hasAttribute("Armed vehicles") then
                                    local detectedEnemyObject = detectedEnemies[i].object
                                    if detectedEnemyObject then
                                        local detectedEnemyGroup = detectedEnemyObject:getGroup()
                                        if detectedEnemyGroup then
                                            detectedGroups[detectedEnemyGroup:getName()] = 1
                                        end
                                    end
                                end
                            end
                        end
                        for k,v in pairs(detectedGroups) do
                            local detectedGroup = Group.getByName(k)
                            if detectedGroup then
                                local leadDetectedUnit = detectedGroup:getUnit(1)
                                if leadDetectedUnit then
                                    local leadPoint = leadDetectedUnit:getPoint()
                                    local leadPos = leadDetectedUnit:getPosition()
                                    if leadPos then
                                        groups[groupName].heading = Utils.getDegBearingFromPosition(leadPos)
                                    end
                                    if leadPoint then
                                        local detectedDistance = Utils.PointDistance(checkingPoint, leadPoint)
                                        local bearingToTgt = Utils.GetBearingDeg(checkingPoint, leadPoint)
                                        if detectedDistance <= cas.engagementDistance then
                                            groups[groupName].targetGroups[k] = { distanceToTgt = detectedDistance, bearingToTgt = bearingToTgt, onRoad = (land.getSurfaceType({x = leadPoint.x, y = leadPoint.z}) == 4)}
                                            if detectedDistance < cas.dangerClose then
                                                if stoppedGroups[groupName] == nil then
                                                    cas.stopGroup(groupName)
                                                    timer.scheduleFunction(cas.startGroup, groupName, timer:getTime() + 30)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function cas.designationLoop()
    for k,v in pairs(groups) do
        local casMessage = "This is " .. v.callsign .. ". We are in contact with enemy forces!"
        local locationMessage = "\nWe are located at "
        local groupLat, groupLong, groupAlt = coord.LOtoLL(v.currentPoint)
        local groupMGRS = coord.LLtoMGRS(groupLat, groupLong)
        local eastingString = tostring(groupMGRS.Easting)
        local northingString = tostring(groupMGRS.Northing)
        for i = 1, 5 - #eastingString do
            eastingString = tostring(0)..eastingString
        end
        for i = 1, 5 - #northingString do
            northingString = tostring(0)..northingString
        end
        local location = groupMGRS.MGRSDigraph .. eastingString:sub(1,v.jtacType)..northingString:sub(1,v.jtacType)
        locationMessage = locationMessage .. location
        if v.isMoving then
                locationMessage = locationMessage .. "\nWe are moving " .. Utils.degToCompass(v.heading)
        end
        casMessage = casMessage .. locationMessage
        local groupCount = 0
        for group, targetInfo in pairs(v.targetGroups) do
            local tgtGroup = Group.getByName(group)
            if tgtGroup then
                groupCount = groupCount + 1
                local bearingToTgt = math.floor(targetInfo.bearingToTgt)
                local compassBearingToTgt = Utils.degToCompass(bearingToTgt)
                local bearingString = tostring(bearingToTgt)
                if v.jtacType == CAS.JTACType.NONE then bearingString = compassBearingToTgt end
                local distanceToTgt = targetInfo.distanceToTgt / 1000
                casMessage = casMessage .. "\nGroup " .. groupCount .. ": " .. bearingString .. " for " .. string.format("%.1f", distanceToTgt) .. "km"
                if targetInfo.onRoad then casMessage = casMessage .. " on the road." end
                if v.isMoving == false and distanceToTgt < cas.dangerClose then
                    if v.smokeColor == -1 then
                            v.smokeColor = smokeColors[math.random(1,3)]
                    end
                    casMessage = casMessage .. "\nEnemy is danger close! Our position is marked with".. smokeNames[v.smokeColor] .."smoke."
                    if v.smokeTime == -1 or timer:getTime() - v.smokeTime > 300 then
                        trigger.action.smoke(Utils.VectorAdd(v.currentPoint, Utils.ScalarMult(atmosphere.getWind(v.currentPoint), 10 + math.random(5))), v.smokeColor)
                        v.smokeTime = timer:getTime()
                    end
                end
                v.inContact = true
            else
                groupCount = groupCount - 1
                casMessage = "Target destroyed!"
                v.targetGroups[group] = nil
            end
        end
        if v.inContact then
            if groupCount < 1 then v.inContact = false end
            local casGroup = Group.getByName(k)
            if casGroup then
                cas.groupMarkups(v.currentPoint, k, v.inContact)
                local casController = casGroup:getController()
                if casController then
                    cas.transmitMessages(casController, casMessage)
                    for groupName, active in pairs(casGroups[v.coalitionId]) do
                        local group = Group.getByName(groupName)
                        if group then
                            local groupId = group:getID()
                            if groupId then
                                trigger.action.outTextForGroup(groupId, casMessage, 30, false)
                            end
                        else
                            casGroups[groupName] = nil
                        end
                    end
                end
            end
        end
    end
    timer.scheduleFunction(cas.designationLoop, nil, timer:getTime() + 30)
end
function cas.stopGroup(groupName)
    if stoppedGroups[groupName] == nil then
        local group = Group.getByName(groupName)
        if group then
           trigger.action.groupStopMoving(group)
           stoppedGroups[groupName] = true
        end
    end
end
function cas.startGroup(groupName)
    if stoppedGroups[groupName] == true then
        local group = Group.getByName(groupName)
        if group then
            trigger.action.groupContinueMoving(group)
            stoppedGroups[groupName] = nil
        end
    end
end
function cas.groupMarkups(point, groupName, inContact)
    if groups[groupName].markups then
        if groups[groupName].markups.radio then
            for i = 1, #groups[groupName].markups.radio do
                trigger.action.removeMark(groups[groupName].markups.radio[i])
            end
        end
    end
    if inContact then
        groups[groupName].markups.radio = DrawingTools.drawRadio(groups[groupName].coalitionId, point)
    end
end
function cas.loadZones()
    local redZone = trigger.misc.getZone(stackZones[1])
    local blueZone = trigger.misc.getZone(stackZones[2])
    if redZone and blueZone then
        stackPoints[1] = {x=redZone.point.x, y = land.getHeight({x = redZone.point.x, y = redZone.point.z})+cas.casHeight, z = redZone.point.z}
        trigger.action.circleToAll(1, DrawingTools.newMarkId(), stackPoints[1], cas.casRadius, {1,0,0,0.6}, {0,0,0,0}, 4, true, nil)
        trigger.action.textToAll(1, DrawingTools.newMarkId(), stackPoints[1], {1,0,0,0.6}, {1,1,1,0.9}, 10, true, "CAS Stack")
        stackPoints[2] = {x=blueZone.point.x, y = land.getHeight({x = blueZone.point.x, y = blueZone.point.z})+cas.casHeight, z = blueZone.point.z}
        trigger.action.circleToAll(2, DrawingTools.newMarkId(), stackPoints[2], cas.casRadius, {0,0,1,0.6}, {0,0,0,0}, 4, true, nil)
        trigger.action.textToAll(2, DrawingTools.newMarkId(), stackPoints[2], {0,0,1,0.6}, {1,1,1,0.9}, 10, true, "CAS Stack")
        cas.stackLoop()
    end
end
function cas.stackLoop()
    cas.searchCasZones()
    cas.trackCas()
    timer.scheduleFunction(cas.stackLoop, nil, timer:getTime() + 25)
end
--[[ 
The purpose of this function is to have each CAS group send messages on multiple frequencies
This will allow a user to tune into a private frequency for each group and avoid being spammed by messages from other groups
each unit will also send a message on the main CAS frequency with their frequency and callsign so users can tune in. 
This does not supercede the CAS Stack which will enroll a user in all messages from all groups regardless of frequency.
The function sends out each message twice (one on the FM frequency for helicopters and one on the AM frequency for planes)
]]
function cas.transmitMessages(casController, casMessage)
    -- Save the custom frequency and modulation for the group & set the cas message
    local groupFreq = groups[casController:getGroup():getName()].frequency
    local groupModulation = groups[casController:getGroup():getName()].modulation
    local coalitionId = casController:getGroup().coalitionId
    local casMsg = {
        id = 'TransmitMessage',
        params = {
            duration = 30,
            subtitle = casMessage,
            loop = false,
            file = "l10n/DEFAULT/Alert.ogg",
        }
    }
    local freq = nil
    local mod = nil

    -- First transmit global message on the FM cas frequency
    cas.changeFreq(casController, CASFREQS[coalitionId][1]["main"], groupModulation)
    freq = groups[casController:getGroup():getName()].frequency
    mod = groups[casController:getGroup():getName()].modulation
    local msg = cas.generateCallForHelp(casController, groupFreq, groupModulation)
    casController:setCommand(msg)

    -- Then transmit global message on the AM cas frequency
    cas.changeFreq(casController, CASFREQS[coalitionId][0]["main"], groupModulation)
    freq = groups[casController:getGroup():getName()].frequency
    mod = groups[casController:getGroup():getName()].modulation
    msg = cas.generateCallForHelp(casController, groupFreq, groupModulation)
    casController:setCommand(msg)

    -- Transmit the cas message on the FM frequency
    cas.changeFreq(casController, groupFreq, groupModulation)
    casController:setCommand(casMsg)
    -- Transmit the cas message on the AM frequency via LUT
    cas.changeFreq(casController, cas.getAmFromFm(groupFreq), groupModulation == 0 and 1 or 0) -- Switch modulation
    casController:setCommand(casMsg)
end
function cas.assignFrequencies(casController, frequency, modulation)
    if casController:getGroup() then
        local group = casController:getGroup()
        local groupProperties = groups[group:getName()]
        if casController:getGroup():getUnits() then
            local defaultBand = groupProperties.modulation
            local defaultFreq = groupProperties.amFreq and defaultBand == 0 or groupProperties.fmFreq
            local altBand = defaultBand == 0 and 1 or 0 -- Opposite of default band
            local altFreq = groupProperties.amFreq and altBand == 0 or groupProperties.fmFreq

            local units = casController:getGroup():getUnits()
            -- If the number of units is 4 or less we dont assign anything and just fallback on using the group global cas frequency
            if #units <= 4 then
                -- Do nothing, the group will use the global CAS frequency
                env.info("CAS2: TRANSMIT MESSAGES: Cas group " .. casController:getGroup():getName() .. " has 4 or less units, using global CAS frequency.", false)
            else
                for i = 1, 4 do
                    local unit = units[i]
                    if unit then
                        local unitController = unit:getController()
                        if unitController then
                            -- Assign the default frequency and modulation to the first 4 units
                            if i <= 2 then
                                cas.changeFreq(unitController, defaultFreq, defaultBand)
                            else
                                cas.changeFreq(unitController, altFreq, altBand)
                            end
                        end
                    end
                end
            end
        end
    end
end
function cas.generateCallForHelp(casController, groupFreq, groupModulation)
    local groupName = casController:getGroup():getName()
    local callsign = groups[groupName].callsign
    local message = "This is " .. callsign .. ". We are in contact with enemy forces! Our frequency is " .. groupFreq .. " MHz " .. (groupModulation == 0 and "AM" or "FM") .. "."
    local msg = {
        id = 'TransmitMessage',
        params = {
            duration = 30,
            subtitle = message,
            loop = false,
            file = "l10n/DEFAULT/Alert.ogg",
        }
    }
    return msg
end
function cas.changeFreq(controller, frequency, modulation)
    -- Handle text based modulation input
    if modulation == "AM" then
        modulation = 0
    elseif modulation == "FM" then
        modulation = 1
    end

    local cmd = {}
    cmd.id = "SetFrequency"
    cmd.params = {}
    cmd.params.frequency = tonumber(frequency) * 1000000
    cmd.params.modulation = modulation
    cmd.params.power = 120
    controller:setCommand(cmd)
end
function cas.searchCasZones()
    for c = 1,2 do
        local volS = {
            id = world.VolumeType.SPHERE,
            params = {
                point = stackPoints[c],
                radius = cas.casRadius
            }
        }
        local ifFound = function(foundItem, val)
            if (foundItem:getDesc().category == 0 or foundItem:getDesc().category == 1) and foundItem:isExist() and foundItem:isActive() and foundItem:getCoalition() == c then
                local foundPlayerName = foundItem:getPlayerName()
                local playerCoalition = foundItem:getCoalition()
                local playerGroup = foundItem:getGroup()
                if playerGroup then
                    local playerGroupID = playerGroup:getID()
                    if foundPlayerName and playerCoalition and playerGroupID then
                        if casGroups[c][playerGroup:getName()] == nil then
                            casGroups[c][playerGroup:getName()] = true
                            trigger.action.outTextForGroup(playerGroupID, "You are checked in for CAS. You will receive messages from the ground coordinator for any groups needing support.", 15, false)
                        end
                    end
                end
            end
        end
        world.searchObjects(Object.Category.UNIT, volS, ifFound)
    end
end
function cas.trackCas()
    for c = 1, 2 do
        for groupName, active in pairs(casGroups[c]) do
            local casGroup = Group.getByName(groupName)
            if casGroup == nil then
                casGroups[c][groupName] = nil
            end
        end
    end
end

cas.loop()
cas.designationLoop()
cas.loadZones()
cas.stackLoop()