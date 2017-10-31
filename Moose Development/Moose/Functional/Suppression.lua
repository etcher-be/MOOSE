-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- **Functional** - Suppress fire of ground units when they get hit.
-- 
-- ====
-- 
-- When ground units get hit by (suppressive) enemy fire, they will not be able to shoot back for a certain amount of time.
-- 
-- The implementation is based on an idea and script by MBot. See DCS forum threat https://forums.eagle.ru/showthread.php?t=107635 for details.
-- 
-- ====
-- 
-- # Demo Missions
--
-- ### [ALL Demo Missions pack of the last release](https://github.com/FlightControl-Master/MOOSE_MISSIONS/releases)
-- 
-- ====
-- 
-- # YouTube Channel
-- 
-- ### [MOOSE YouTube Channel](https://www.youtube.com/playlist?list=PL7ZUrU4zZUl1jirWIo4t4YxqN-HxjqRkL)
-- 
-- ===
-- 
-- ### Author: **[funkyfranky](https://forums.eagle.ru/member.php?u=115026)**
-- 
-- ### Contributions: **Sven van de Velde ([FlightControl](https://forums.eagle.ru/member.php?u=89536))**
-- 
-- ====
-- @module suppression

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Suppression class
-- @type Suppression
-- @field #string ClassName Name of the class.
-- @field Core.Controllable#CONTROLLABLE Controllable of the FSM. Must be a ground group.
-- @field #number Tsuppress_min Minimum time in seconds the group gets suppressed.
-- @field #number Tsuppress_max Maximum time in seconds the group gets suppressed.
-- @field #number life Relative life in precent of the group.
-- @field #number TsuppressionStart Time at which the suppression started.
-- @field #number TsuppressionOver Time at which the suppression will be over.
-- @field #number Thit Last time the unit was hit.
-- @field #number Nhit Number of times the unit was hit since it last was in state "CombatReady".
-- @field Core.Zone#ZONE Zone_Retreat Zone into which a group retreats.
-- @field #number LifeThreshold Life of group in percent at which the group will be ordered to retreat.
-- @field #number IniGroupStrength Number of units in a group at start.
-- @field #number GroupStrengthThreshold Threshold of group strength before retreat is ordered.
-- @extends Core.Fsm#FSM
-- 

---# Suppression class, extends @{Core.Fsm#FSM_CONTROLLABLE}
-- Mimic suppressive fire and make ground units take cover.
-- 
-- ## Some Example...
-- 
-- @field #Suppression
Suppression={
  ClassName = "Suppression",
  Tsuppress_min = 5,
  Tsuppress_max = 20,
  TsuppressStart = nil,
  TsuppressOver = nil,
  Thit = nil,
  Nhit = 0,
  Zone_Retreat = nil,
  LifeThreshold = 30,
  IniGroupStrength = nil,
  GroupStrengthThreshold=50,
}

--- Some ID to identify who we are in output of the DCS.log file.
-- @field #string id
Suppression.id="SFX | "

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--TODO: Figure out who was shooting and move away from him.
--TODO: Move behind a scenery building if there is one nearby.
--TODO: Retreat to a given zone or point.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Creates a new AI_suppression object.
-- @param #Suppression self
-- @param Wrapper.Group#GROUP Group The GROUP object for which suppression should be applied.
-- @return #Suppression
function Suppression:New(Group)

  -- Check that group is present.
  if Group then
    env.info(Suppression.id.."Suppressive fire for group "..Group:GetName())
  else
    env.info(Suppression.id.."Suppressive fire: Requested group does not exist! (Has to be a MOOSE group.)")
    return nil
  end
  
  -- Check that we actually have a GROUND group.
  if Group:IsGround()==false then
    env.error(Suppression.id.."Suppression fire group "..Group:GetName().." has to be a GROUND group!")
    return nil
  end

  -- Inherits from FSM_CONTROLLABLE
  local self=BASE:Inherit(self, FSM_CONTROLLABLE:New()) -- #Suppression
  
  -- Set the controllable for the FSM.
  self:SetControllable(Group)
  
    -- Initial group strength.
  self.IniGroupStrength=#Group:GetUnits()
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  
  
  -- Transition from anything to "Suppressed" after event "Hit".
  self:AddTransition("*", "Start", "CombatReady")
  
  self:AddTransition("*", "Hit", "*")
  
  self:AddTransition("*", "Suppress", "*")
  
  self:AddTransition("*", "Recovered", "*")
  
  self:AddTransition("*", "Retreat", "Retreating")
  
  self:SetEventPriority(1)
  
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set minimum and (optionally) maximum time a unit is suppressed each time it gets hit.
-- @param #Suppression self
-- @param #number Tmin Minimum time in seconds.
-- @param #number Tmax (Optional) Maximum suppression time. If no value is given, the is set to Tmin.
function Suppression:SetSuppressionTime(Tmin, Tmax)
  self.Tsuppress_min=Tmin or 1
  self.Tsuppress_max=Tmax or Tmin
  env.info(Suppression.id..string.format("Min suppression time %d seconds.", self.Tsuppress_min))
  env.info(Suppression.id..string.format("Max suppression time %d seconds.", self.Tsuppress_max))
end

--- Set the zone to which a group retreats after being damaged too much.
-- @param #Suppression self
-- @param Core.Zone#ZONE zone MOOSE zone object.
function Suppression:SetRetreatZone(zone)
  self.Zone_Retreat=zone
  env.info(Suppression.id..string.format("Retreat zone for group %s is %s.", self.Controllable:GetName(), self.Zone_Retreat:GetName()))
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Start" event.
-- @param #Suppression self
function Suppression:onafterStart(Controllable, From, Event, To)
  env.info(Suppression.id..self:_EventFromTo("onafterStart", Event, From, To))
  
  --Handle DCS event hit.
  self:HandleEvent(EVENTS.Hit, self._OnHit)
  
  -- Handle DCS event dead.
  self:HandleEvent(EVENTS.Dead, self._OnDead)
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Hit" event.
-- @param #Suppression self
function Suppression:onafterHit(Controllable, From, Event, To, Unit)
  env.info(Suppression.id..self:_EventFromTo("onafterHit", Event, From, To))
  
  Unit:Flare(FLARECOLOR.Red)
  self:Suppress(Unit)
  
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  
  -- If life of one unit is below threshold, the group is ordered to retreat (if a zone has been specified).
  if not self:Is("Retreating") then
    if groupstrength<self.GroupStrengthThreshold or (self.IniGroupStrength==1 and life_min < self.LifeThreshold) then
      self.Controllable:ClearTasks()
      self:Retreat()
    end
  end
    
end

--- After "Suppress" event.
-- @param #Suppression self
function Suppression:onafterSuppress(Controllable, From, Event, To, Unit)
  env.info(Suppression.id..self:_EventFromTo("onafterSuppress", Event, From, To))
  
  Unit:Flare(FLARECOLOR.Green)
  self:_Suppress()
    
end

--[[
--- Before "Recovered" event.
-- @param #Suppression self
function Suppression:onbeforeRecovered(Controllable, From, Event, To)
  env.info(Suppression.id..self:_EventFromTo("onbeforeRecovered", Event, From, To))
  
  -- Current time.
  local Tnow=timer.getTime()
  
  -- Debug info
  env.info(Suppression.id..string.format("OnBeforeRecovered: Time: %d  - Time over: %d", Tnow, self.TsuppressionOver))
  
  -- Recovery is only possible if enough time since the last hit has passed.
  if Tnow >= self.TsuppressionOver then
    return true
  else
    return false
  end
  
end
]]

--- After "Recovered" event.
-- @param #Suppression self
function Suppression:onafterRecovered(Controllable, From, Event, To)
  env.info(Suppression.id..self:_EventFromTo("onafterRecovered", Event, From, To))
  
    -- Current time.
  local Tnow=timer.getTime()
  
  -- Send message.
  if Tnow >= self.TsuppressionOver then
    MESSAGE:New(string.format("Group %s has recovered. ROE Open Fire!", Controllable:GetName()), 30):ToAll()
  
    env.info(Suppression.id.."ROE Open Fire after recovered")
    self.Controllable:OptionROEOpenFire()  --Wrapper.Controllable#CONTROLLABLE
  else
    env.info(Suppression.id.."Suppression time not over yet.")
  end
  
end


--- Before "Retreat" event.
-- @param #Suppression self
function Suppression:onbeforeRetreat(Controllable, From, Event, To)
  env.info(Suppression.id..self:_EventFromTo("onbeforeRetreat", Event, From, To))
    
  -- Retreat is only possible if a zone has been defined by the user.
  if self.Zone_Retreat==nil then
    env.info(Suppression.id.."Retreat NOT possible! No Zone specified.")
    return false
  elseif self:Is("Retreating") then
    env.info(Suppression.id.."Group is already retreating.")
    return false
  else
    env.info(Suppression.id.."Retreat possible, zone specified.")
    return true
  end
  
end

--- After "Retreat" event.
-- @param #Suppression self
function Suppression:onafterRetreat(Controllable, From, Event, To)
  env.info(Suppression.id..self:_EventFromTo("onafterRetreat", Event, From, To))
    
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self.Controllable:OptionAlarmStateGreen()
  
  -- Route the group to a zone.
  local text=string.format("Group %s is retreating! Alarm state green.", self.Controllable:GetName())
  MESSAGE:New(text, 30):ToAll()
  env.info(Suppression.id..text)
  self:_RetreatToZone(self.Zone_Retreat, 50, "Vee")
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Event Handler
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Handle the DCS event hit.
-- @param #Suppression self
-- @param Core.Event#EVENTDATA EventData
function Suppression:_OnHit(EventData)
  env.info("oneventhit")
  self:E( {Suppression.id.."_OnHit", EventData })
  env.info(Suppression.id.."Initiator   : "..EventData.IniDCSGroupName)
  env.info(Suppression.id.."Target      : "..EventData.TgtDCSGroupName)
  
  if EventData.TgtDCSGroup then
  
    local TargetGroup=EventData.TgtGroup --Wrapper.Group#GROUP
    
    if EventData.TgtDCSGroupName==self.Controllable:GetName() then
    
      self:Hit(EventData.TgtUnit)
      
    end
  end
end

--- Handle the DCS event dead.
-- @param #Suppression self
-- @param Core.Event#EVENTDATA EventData
function Suppression:_OnDead(EventData)
  --self:E({Suppression.id.."_OnDead", EventData})
  
  if EventData.IniDCSUnit then
    if EventData.IniDCSGroupName==self.Controllable:GetName() then
    
      -- Number of units left in the group.
      local nunits=#self.Controllable:GetUnits()-1
      
      local text=string.format("A unit from group %s just died! %d units left.", self.Controllable:GetName(), nunits)
      MESSAGE:New(text, 10):ToAll()
      env.info(Suppression.id..text)
      
      -- Go to stop state.
      if nunits==0 then
        self:Stop()
      end
      
    end
  end
    
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Suppress fire of a unit.
-- @param #Suppression self
function Suppression:_Suppress()

  -- Current time.
  local Tnow=timer.getTime()
  
  -- Controllable
  local Controllable=self.Controllable
  
  -- Group will hold their weapons.
  env.info(Suppression.id.."ROE Hold fire!")
  Controllable:OptionROEHoldFire()
  
  -- Get randomized time the unit is suppressed.
  local Tsuppress=math.random(self.Tsuppress_min, self.Tsuppress_max)
  Tsuppress=10
  
  -- Time the suppression started
  self.TsuppressionStart=Tnow
  
  -- Time at which the suppression is over.
  local renew=true
  if self.TsuppressionOver ~= nil then
    if Tsuppress+Tnow > self.TsuppressionOver then
      self.TsuppressionOver=Tnow+Tsuppress
    else
      renew=false
    end
  else
    self.TsuppressionOver=Tnow+Tsuppress
  end
  
  -- Recovery event will be called in Tsuppress seconds.
  if renew then
    env.info(Suppression.id.."Tover-Tnow = "..self.TsuppressionOver-Tnow)
    self:__Recovered(self.TsuppressionOver-Tnow)
  end
  
  -- Debug message.
  local text=string.format("Group %s is suppressed for %d seconds. Suppression ends at %d:%02d.", Controllable:GetName(), Tsuppress, self.TsuppressionOver/60, self.TsuppressionOver%60)
  MESSAGE:New(text, 30):ToAll()
  env.info(Suppression.id..text)
  text=string.format("Suppression starts at %6.2f and ends at %6.2f.", Tnow, self.TsuppressionOver)
  env.info(Suppression.id..text)

end


--- Get (relative) life in percent of a group. Function returns the value of the units with the smallest and largest life. Also the average value of all groups is returned.
-- @param #Suppression self
-- @param Wrapper.Group#GROUP group Group of unit.
-- @return #number Smallest life value of all units.
-- @return #number Largest life value of all units.
-- @return #number Average life value.
function Suppression:_GetLife()
  local group=self.Controllable --Wrapper.Group#GROUP
  if group and group:IsAlive() then
    local life_min=100
    local life_max=0
    local life_ave=0
    local n=0
    local units=group:GetUnits()
    local groupstrength=#units/self.IniGroupStrength*100
    for _,unit in pairs(units) do
      local unit=unit -- Wrapper.Unit#UNIT
      if unit and unit:IsActive() then
        n=n+1
        local life=unit:GetLife()/(unit:GetLife0()+1)*100
        if life < life_min then
          life_min=life
        end
        if life > life_max then
          life_max=life
        end
        life_ave=life_ave+life
        local text=string.format("n=%02d: Life = %3.1f, Life0 = %3.1f, min=%3.1f, max=%3.1f, ave=%3.1f, group=%3.1f", n, unit:GetLife(), unit:GetLife0(), life_min, life_max, life_ave/n,groupstrength)
        --env.info(Suppression.id..text)
      end
    end
    life_ave=life_ave/n
    
    return life_min, life_max, life_ave, groupstrength
  else
    return 0, 0, 0, 0
  end
end


--- Retreat to a random point within a zone.
-- @param #Suppression self
-- @param Core.Zone#ZONE zone Zone to which the group retreats.
-- @param #number speed Speed of the group. Default max speed the specific group can do.
-- @param #string formation Formation of the Group. Default "Vee".
function Suppression:_RetreatToZone(zone, speed, formation)

  -- Set zone, speed and formation if they are not given
  zone=zone or self.Zone_Retreat
  speed = speed or 999
  formation = formation or "Vee"

  -- Name of zone.
  env.info(Suppression.id.."Retreat zone : "..zone:GetName())

  -- Get a random point in the retreat zone.
  local ZoneCoord=zone:GetRandomCoordinate() -- Core.Point#COORDINATE
  local ZoneVec2=ZoneCoord:GetVec2()

  -- Debug smoke zone and point.  
  ZoneCoord:SmokeBlue()
  zone:SmokeZone(SMOKECOLOR.Red, 12)
  
  -- Set task to go to zone.
  self.Controllable:TaskRouteToVec2(ZoneVec2, speed, formation)

end

--- Determine the coordinate to which a unit should fall back.
--@param #Suppression self
--@param Core.Point#COORDINATE a Coordinate of the defending group.
--@param Core.Point#COORDINATE b Coordinate of the attacking group.
--@return Core.Point#COORDINATE Fallback coordinates. 
function Suppression:_FallBackCoord(a, b, distance)
  local dx = b.x-a.x
  -- take the right value for y-coordinate (if we have "alt" then "y" if not "z")
  local ay
  if a.alt then
    ay=a.y
  else
    ay=a.z
  end
  local by
  if b.alt then
    by=b.y
  else
    by=b.z
  end
  local dy = by-ay
  local angle = math.deg(math.atan2(dy,dx))
  if angle < 0 then
    angle = 360 + angle
  end
  angle=angle-180
  local fbp=a:Translate(distance, angle)
  return fbp
end


--- Fall back (move away) from enemy who is shooting on the group.
--@param #Suppression self
--@param Core.Point#COORDINATE coord_fbp Coordinate of the fall back point.
function Suppression:_FallBack(coord_fbp)

  local group=self.Controllable -- Wrapper.Controllable#CONTROLLABLE

  local Waypoints = group:GetTemplateRoutePoints()
  
  local coord_grp = group:GetCoordinate()
  local wp1 = coord_grp:WaypointGround(99, "Vee")
  local wp2 = coord_fbp:WaypointGround(99, "Vee")
    
  table.insert(Waypoints, 1, wp1)
  table.insert(Waypoints, 2, wp2)
  
  -- Condition to wait.
  local ConditionWait=group:TaskCondition(nil, nil, nil, nil, 30, nil)
  
  -- Task to hold.
  local TaskHold = group:TaskHold()
  
  local TaskRoute1 = group:TaskFunction("Suppression._Passing_Waypoint", self, 0)
  local TaskCombo2 = {}
  TaskCombo2[#TaskCombo2+1] = group:TaskFunction("Suppression._Passing_Waypoint", self, 1)
  TaskCombo2[#TaskCombo2+1] = group:TaskControlled(TaskHold, ConditionWait)
  local TaskRoute2 = group:TaskCombo(TaskCombo2)
  
  group:SetTaskWaypoint(Waypoints[1], TaskRoute1)
  group:SetTaskWaypoint(Waypoints[2], TaskRoute2)
  
  group:Route(Waypoints)

end


--- Group has reached a waypoint.
--@param #Suppression self
--@param #number i Waypoint number that has been reached.
function Suppression._Passing_Waypoint(group, Fsm, i)
  local text
  if i==1 then
    text=string.format("Group %s has reached fallback point.", group:GetName())
  else
    text=string.format("Group %s passing waypoint %d.", group:GetName(), i)
  end
  MESSAGE:New(text,30):ToAll()
  env.info(Suppression.id..text)
end


--- Return event-from-to string. 
-- @param #Suppression self
-- @param #string BA
-- @param #string event
-- @param #string from
-- @param #string to
-- @return #string From-to info.
function Suppression:_EventFromTo(BA, Event, From, To)
  return string.format("%s: %s event %s %s --> %s", BA, self.Controllable:GetName(), Event, From, To)
end