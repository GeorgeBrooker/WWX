-- sling loading baby sitter to stand in until ED fixes slinging (lol)
-- initiate babysitting once a cargo object has moved from its initial point
env.info("loading palletised", false)
PT = {}
local pt = {}
local loopTime = 0.5
pt.trackedTorps = {

}
--coalition, cargo, supplyType, spawnTime, seaPickup , frontPickup , groupId, modifier, groupName, successfulDeployChecks
function PT.watchCargo(param)
    --add torp to tracking table, begin loop
    env.info("Loading torp: " .. param.cargo, false)
    local cargo = StaticObject.getByName(param.cargo)
    if cargo then
        local cargoPoint = cargo:getPoint()
        if cargoPoint then
            pt.trackedTorps[param.cargo] = param
            pt.trackedTorps[param.cargo].lastPoint = cargoPoint
            pt.trackedTorps[param.cargo].lastAGL = Utils.getAGL(cargoPoint)
            PT.watchLoop(param.cargo)
        end
    end
end
function PT.watchLoop(cargoName)
    -- monitor torp position and speed and catch when it goes missing (implies it has hit the water and died)
    -- if torp is missing, check the player is still alive, if so they havent crashed and we can spawn a torpedo.
    if pt.trackedTorps[cargoName] then
        local cargo = StaticObject.getByName(cargoName)
        if cargo then
            local cargoPoint = cargo:getPoint()
            pt.trackedTorps[cargoName].lastPoint = cargoPoint
            pt.trackedTorps[cargoName].lastAGL = Utils.getAGL(cargoPoint)
        else --torp lost, player still alive?
            local droppingGroup = Group.getByName(pt.trackedTorps[cargoName].groupName)
            if droppingGroup then
                local droppingUnit = droppingGroup:getUnit(1)
                if droppingUnit then
                    env.info("Torpedo is lost, player alive, spawning active torpedo in last known position", false)
                    PT.fireTorpedo(cargoName)
                end
            else
                PT.endWatch(cargoName)
            end
        end
        timer.scheduleFunction(PT.watchLoop, cargoName, timer:getTime() + loopTime)
    end
end
function PT.endWatch(cargoName)
    pt.trackedTorps[cargoName] = nil
end
function PT.fireTorpedo(cargoName)
    -- if slinger group exists, spawn a new cargo of the same type at the ground beneath the slinger
    -- stop tracking old cargo
    local oldCargo = pt.trackedTorps[cargoName]
    if oldCargo then
        PT.endWatch(cargoName)
        local droppingGroup = Group.getByName(oldCargo.groupName)
        if droppingGroup then
            local droppingUnit = droppingGroup:getUnit(1)
            if droppingUnit then
                local droppingPoint = droppingUnit:getPoint()
                if droppingPoint then
                    --coalition, country, spawnPoint, supplyType, spawnTime, seaPickup, frontPickup, isSlung, groupId, modifier, groupName
                    local respawnParams = {
                        coalition = droppingGroup:getCoalition(),
                        country = droppingUnit:getCountry(),
                        spawnPoint = {x = droppingPoint.x, y = land.getHeight({x = droppingPoint.x, y = droppingPoint.z}), z = droppingPoint.z},
                        seaPickup = oldCargo.seaPickup,
                        frontPickup = oldCargo.frontPickup,
                        isSlung = true,
                        groupId = droppingGroup:getID(),
                        modifier = oldCargo.modifier,
                        groupName = oldCargo.groupName,
                        supplyType = oldCargo.supplyType
                    }
                    DFS.spawnCargo(respawnParams)
                end
            end
        end
    end
end