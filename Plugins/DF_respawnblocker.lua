sblocker = {}
SBLOCKER = {}

SBLOCKER.blockedGroups = {}
sblocker.tolerance = 0.1 -- 10% of initial size

local missionName = env.mission["date"]["Year"]
local spawnState = lfs.writedir() .. [[Logs/]] .. 'spawns'..missionName..'.txt'
function sblocker.loop()
    for groupName, _ in pairs(PERSISTENTDEATH) do
        local checkgroup = Group.getByName(groupName)
        local groupDead = false
        if checkgroup then
            if checkgroup:getSize() / checkgroup:getInitialSize() <= sblocker.tolerance then
                groupDead = true
            end
        else
            groupDead = true
        end
        if groupDead then
            SBLOCKER.blockedGroups[groupName] = true
            env.info("SBLOCKER: Group " .. groupName .. " is dead and in the persistent death list, adding to blocked respawn groups.")
            sblocker.savePersistance()
        end
    end
    timer.scheduleFunction(sblocker.loop, nil, timer.getTime() + 60) -- check every 60 seconds
end
function sblocker.killOnRestart()
    for groupName, _ in pairs(SBLOCKER.blockedGroups) do
        local checkgroup = Group.getByName(groupName)
        if checkgroup then
            checkgroup:destroy()
            env.info("SBLOCKER: Group " .. groupName .. " is blocked and has been destroyed on mission restart.")
        end
    end
end
function sblocker.loadPersistance()
    if Utils.fileExists(spawnState) then
        local f = io.open(spawnState)
        local spawnData = dofile(spawnState)
        for k,v in pairs(spawnData) do
            SBLOCKER.blockedGroups[k] = v
        end
        f:close()
    end
end
function sblocker.savePersistance()
    local spawnFile = spawnState
    local f = io.open(spawnFile, 'w')
    f:write("return " .. Utils.saveToString(SBLOCKER.blockedGroups))
    f:close()
end

env.info("SBLOCKER: Persistent Respawn Blocker loaded.", false)
sblocker.loadPersistance()
sblocker.killOnRestart()
sblocker.loop()