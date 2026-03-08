AiRec = {}
local aiRec = {}
aiRec.fighterInterval = 600

function aiRec.reconLoop()
    aiRec.spawnRecon(1)
    aiRec.spawnRecon(2)
end
function aiRec.spawnRecon(coalitionId)
    local cloneGroupName = "Red-Recon"
    if coalitionId == 2 then cloneGroupName = "Blue-Recon" end
    local groupName = mist.cloneGroup(cloneGroupName, true).name
    aiRec.checkRecon({groupName = groupName, coalitionId = coalitionId})
end
function aiRec.checkRecon(param)
    local group = Group.getByName(param.groupName)
    if group ~= nil then
        if group:getSize() == 0 or group:getUnit(1) == nil or group:getUnit(1):inAir() == false then
            group:destroy()
            timer.scheduleFunction(aiRec.spawnRecon, param.coalitionId, timer:getTime() + aiRec.reconInterval)
        else
            timer.scheduleFunction(aiRec.checkRecon, param, timer.getTime() + 30)
        end
    else
        timer.scheduleFunction(aiRec.spawnRecon, param.coalitionId, timer:getTime() + aiRec.reconInterval)
    end
end
