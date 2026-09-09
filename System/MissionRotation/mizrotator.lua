local function file_exists(filepath)
    local f = io.open(filepath, "r")
    if f then
        io.close(f)
        return true
    else
        return false
    end
end
if file_exists("System/MissionRotation/config/rotation.lua") then
    assert(loadfile("System/MissionRotation/config/rotation.lua"))()
end