debug = false
local capsitter = {}

function capsitter.checkCap(param)
    env.info("Checking interceptor group " .. param.groupName, debug)
    local group = Group.getByName(param.groupName)
    local target = Unit.getByName(param.target)
    if group ~= nil then
        if group:getSize() == 0 or group:getUnit(1) == nil or group:getUnit(1):inAir() == false then
            env.info("Interceptor group " .. param.groupName .. " has been destroyed or is on the ground", debug)
            group:destroy()
        elseif target ~= nil then
            local controller = Group.getByName(param.groupName):getController()
            if controller then
                if not controller:isTargetDetected(target) then -- if target is no longer detected, check if it's still on bulls and update task to new position if so
                    if intr.detectedOnBulls(param.coalitionId, param.target) and not INTERCEPTORS.noGci then
                        env.info("Target " .. param.target .. " still detected on bulls, updating interceptor task", debug)
                        local targetPoint = target:getPoint()
                        if targetPoint == nil then
                            env.info("Could not get target point for interceptor task update, aborting task update", debug)
                            timer.scheduleFunction(intr.checkInterceptor, param, timer.getTime() + updateInterval)
                            return
                        end
                        local interceptPoint = {
                        id = 'Orbit',
                            params = {
                            pattern = 'Circle',
                            point = targetPoint,
                            speed = 1000,
                            altitude = targetPoint.y,
                            } 
                        }
                        local interceptTask = {
                            id = "EngageUnit",
                            params = {
                                unitId = target:getID(),
                            }
                        }
                        controller:pushTask(interceptPoint)
                        controller:setTask(interceptTask)
                    end
                end
            else
                env.info("Target " .. param.target .. " no longer detected on bulls, interceptor will continue to last known position", debug)
            end
            timer.scheduleFunction(intr.checkInterceptor, param, timer.getTime() + updateInterval)
        else
            timer.scheduleFunction(intr.checkInterceptor, param, timer.getTime() + updateInterval)
        end
    else
        if param.target then
            currentlyIntercepting[param.coalitionId][param.target] = nil
        end
        totalIntercepting[param.coalitionId] = totalIntercepting[param.coalitionId] - 1
        lastInterceptorTime[param.coalitionId][param.number] = timer:getTime()
    end
end