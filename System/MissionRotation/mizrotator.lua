MizRot = {}
local mizrot = {}
local rotationStateFile = lfs.writedir() .. [[Logs/]] ..'wwxRotation.txt'
local mission_number = 1
local enabled = false

function mizrot.fileExists(filepath)
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
        env.info("Loading next mission: " .. next_mission .. "\nRotation table: " Utils.dump(ROTATION))
        net.load_mission(next_mission)
    end
end

if mizrot.fileExists("System/MissionRotation/config/rotation.lua") then
    assert(loadfile("System/MissionRotation/config/rotation.lua"))()
    enabled = true
end