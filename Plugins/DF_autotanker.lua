-- Plan:
-- Get track location 1/3 of the way from rear airfield to the front depots.
-- Spawn a tanker unit at that location, with optional unit type override. 
-- waypoints should be generated dynamically to be roughly the length of the front depending on size. with a minimum size that equates to 10m of travel on each leg at 250kts
-- boom and drogue tanker will spawn 180 degrees offset from each other with only drouge tankers on red
-- the tanker will not use a clonegroup it will be fully generated in script, with tanker type overrie available
-- tankers will be registerd in the respawngroups loop

local DF_autotanker = {}
local defaultHeight = env.mission.weather.clouds.base - 300 or 15000

function DF_autotanker.generateTrackPoints(altitude)
    if not altitude then altitude = defaultHeight end

    local mainAirbases = DF_autotanker.getMainAirbases()
    local airbasePoints = {
        [1] = DF_autotanker.getAirbasePoints(mainAirbases[1]),
        [2] = DF_autotanker.getAirbasePoints(mainAirbases[2])
    }
    local forwardDepots = DF_autotanker.getForwardDepotPoints()
    local rearPointRed = DF_autotanker.averagePosition(airbasePoints[1])
    local rearPointBlue = DF_autotanker.averagePosition(airbasePoints[2])
    local forwardPointRed = DF_autotanker.averagePosition(forwardDepots[1])
    local forwardPointBlue = DF_autotanker.averagePosition(forwardDepots[2])

    local trackPointRed = {
        x = rearPointRed.x + (forwardPointRed.x - rearPointRed.x) / 3,
        y = altitude,
        z = rearPointRed.z + (forwardPointRed.z - rearPointRed.z) / 3
    }
    local trackPointBlue = {
        x = rearPointBlue.x + (forwardPointBlue.x - rearPointBlue.x) / 3,
        y = altitude,
        z = rearPointBlue.z + (forwardPointBlue.z - rearPointBlue.z) / 3
    }

    return {[1] = trackPointRed, [2] = trackPointBlue}
end

function DF_autotanker.generateTrackWps(trackPoints)
end
function DF_autotanker.getAirbasePoint(airbaseName)
    local airbase = Airbase.getByName(airbaseName)
    if airbase and airbase:isExist() then
        return airbase:getPoint()
    end
    return nil
end

function DF_autotanker.getAirbasePoints(airbaseList)
    local points = {}
    for i, airbaseName in ipairs(airbaseList) do
        local point = DF_autotanker.getAirbasePoint(airbaseName)
        if point then
            table.insert(points, point)
        end
    end
    return points
end

function DF_autotanker.getForwardDepotPoints()
    local forwardDepots = {
        [1] = {},
        [2] = {}
    }
    for c = 1,2 do
        local i = 1
        while trigger.misc.getZone(DFS.spawnNames[c].depot..i) do
            local zonePoint = trigger.misc.getZone(DFS.spawnNames[c].depot..i).point
            table.insert(forwardDepots[c], zonePoint)
            i = i + 1
        end 
    end
    return forwardDepots
end

function DF_autotanker.averagePosition(postList)
    local avgX, avgY, avgZ = 0, 0, 0
    local count = #postList
    for i = 1, count do
        avgX = avgX + postList[i].x
        avgY = avgY + postList[i].y
        avgZ = avgZ + postList[i].z
    end
    return {x = avgX / count, y = avgY / count, z = avgZ / count}
end

function DF_autotanker.getMainAirbases()
    local mainAirbases = {
        [1] = {},
        [2] = {}
    }
    local airbaseList = world.getAirbases()
    for i = 1, #airbaseList do
        local airbase = airbaseList[i]
        if airbase and airbase:isExist() then
            local airbaseCoalition = airbase:getCoalition()
            local airbaseName = airbase:getName()
            local airbaseCategory = airbase:getDesc().category
            if airbaseCoalition == 1 or airbaseCoalition == 2 then
                if IgnoreAirbases[airbaseName] == nil then
                    env.info("Managing airfield: " .. airbaseName, false)
                    env.info("Airfield category: " .. tostring(airbaseCategory), false)
                    if airbaseCategory == 0 and ForwardAirbases[airbaseCoalition][airbaseName] == nil and FARPAirfields[airbaseCoalition][airbaseName] == nil then
                        env.info("Main Airbase", false)
                        if airbaseCoalition == 1 then
                            table.insert(mainAirbases[1], airbaseName)
                        else
                            table.insert(mainAirbases[2], airbaseName)
                        end
                    end
                end
            end
        end
    end
    return mainAirbases
end