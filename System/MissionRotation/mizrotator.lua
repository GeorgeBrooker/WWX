MizRot = {}
local mizrot = {}
local root = [[C:\WWX\System\MissionRotation]]

local rotationStateFile = lfs.writedir() .. [[Logs\]] ..'wwxRotation.txt'
local mission_number = 1
local enabled = false
local MISSION_ID_TO_PATH = {
    [1] = [[C:\WWX\Missions\Pacific WW2 - Battle of Tinian v1.2.3.miz]],
    [2] = [[C:\WWX\Missions\WWX2 - Battle of Cyprus Part 2 v1.0.9.miz]],
    [3] = [[C:\WWX\Missions\WWX2 - Battle of Germany v1.3.4.miz]],
    [4] = [[C:\WWX\Missions\Eastern Front WW2  - Battle of Kuban 1946 v1.2.1.miz]],
    [5] = [[C:\WWX\Missions\WWX2 - Battle of Lebanon v1.9.11.miz]],
    [7] = [[C:\WWX\Missions\WWX2 - Battle of Aleppo 1.0.8.miz]],
    [8] = [[C:\WWX\Missions\WWX2 - Battle of Guam65 v1.0.4a.miz]],
    [9] = [[C:\WWX\Missions\WWX2 - Battle of Marianas44 v1.0.2.miz]],
    [10] = [[C:\WWX\Missions\WWX2 - Battle of Fulda87 v1.1.8.miz]],
    [12] = [[C:\WWX\Missions\WWX2 - Battle of The Baltic45 v1.0.2.miz]],
    [15] = [[C:\WWX\Missions\WWX2 - Battle of Fulda58 v1.0.3.miz]],
    [101] = [[C:\WWX\Missions\Korean War - Caucasus 1951 v1.0.8.miz]],
    [102] = [[C:\WWX\Missions\WWX2 - Battle of Hatay v1.0.8.miz]],
    [211] = [[C:\WWX\Missions\WWX2 - Area88 1.0.2.miz]],
}

function mizrot.getCurrentRotationIndex()
    local missionId = tonumber(trigger.misc.getUserFlag("MISSION_ID"))
    if missionId == nil then
        return nil
    end

    local missionPath = MISSION_ID_TO_PATH[missionId]
    if missionPath == nil then
        return nil
    end

    for index, rotationPath in ipairs(ROTATION) do
        if rotationPath == missionPath then
            return index
        end
    end

    return nil
end
function mizrot.fileExists(filepath)
    env.info("Checking if file exists: " .. filepath)
    local f = io.open(filepath, "rb")
    if f then f:close() end
    return f ~= nil
end
function mizrot.loadData()
    if mizrot.fileExists(rotationStateFile) then
        local f = io.open(rotationStateFile, 'r')
        if f ~= nil then
            local lines = {}
            for line in io.lines(f) do
                lines[#lines+1] = line
            end
            mission_number = tonumber(lines[1])
        end
    end
end
function mizrot.saveData()
    local f = io.open(rotationStateFile, 'w')
    if f ~= nil then
        f:write(mission_number)
        f:close()
    end
end
function MizRot.endMission()
    if enabled then
        mizrot.loadData()
        env.info("Current mission is " .. mission_number)

        if mission_number >= #ROTATION then
            env.info("End of missions reached, rotation back to mission 1...")
            mission_number = 1
        else
            mission_number = mission_number + 1
        end
        mizrot.saveData()
        
        local next_mission = ROTATION[mission_number]
        env.info("Loading next mission: " .. next_mission .. "\nRotation table: " .. Utils.dump(ROTATION))
        net.load_mission(next_mission)
    end
end

env.info("Mission rotation script loaded.")
local rotation_config_path = root .. [[\config\rotation.lua]]
if mizrot.fileExists(rotation_config_path) then
    env.info("Mission rotation config file found! loading...")
    assert(loadfile(rotation_config_path))()
    enabled = true

    mizrot.loadData()
    local currentMission = mizrot.getCurrentRotationIndex()
    if currentMission ~= nil and currentMission ~= mission_number then
        env.info("Mission index mismatch: saved = " .. tostring(mission_number) .. ", current = " .. tostring(currentMission) .. ". Loading saved mission.")
        net.load_mission(ROTATION[mission_number])
    end
end

local debug = true
if debug then
    timer.scheduleFunction(MizRot.endMission, nil, timer:getTime() + 30)
end