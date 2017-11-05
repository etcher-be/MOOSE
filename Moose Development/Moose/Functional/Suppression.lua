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
-- @module Suppression

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- SUPPRESSION class
-- @type SUPPRESSION
-- @field #string ClassName Name of the class.
-- @field #boolean debug Write debug messages to DCS log file and send debug messages to all players.
-- @field Core.Controllable#CONTROLLABLE Controllable of the FSM. Must be a ground group.
-- @field #number Tsuppress_ave Average time in seconds a group gets suppressed. Actual value is sampled randomly from a Gaussian distribution.
-- @field #number Tsuppress_min Minimum time in seconds the group gets suppressed.
-- @field #number Tsuppress_max Maximum time in seconds the group gets suppressed.
-- @field #number TsuppressionOver Time at which the suppression will be over.
-- @field #number Nhit Number of times the unit was hit since it last was in state "CombatReady".
-- @field Core.Zone#ZONE Zone_Retreat Zone into which a group retreats.
-- @field #number LifeThreshold Life of group in percent at which the group will be ordered to retreat.
-- @field #number IniGroupStrength Number of units in a group at start.
-- @field #number GroupStrengthThreshold Threshold of group strength before retreat is ordered.
-- @field #string CurrentAlarmState Alam state the group is currently in.
-- @field #string CurrentROE ROE the group currently has.
-- @field #string DefaultAlarmState Alarm state the group will go to when it is changed back from another state. Default is "Auto".
-- @field #string DefaultROE ROE the group will get once suppression is over. Default is "Free".
-- @extends Core.Fsm#FSM_CONTROLLABLE
-- 

---# SUPPRESSION class, extends @{Core.Fsm#FSM_CONTROLLABLE}
-- Mimic suppressive fire and make ground units take cover.
-- 
-- ## Some Example...
-- 
-- @field #SUPPRESSION
SUPPRESSION={
  ClassName = "SUPPRESSION",
  debug = false,
  Tsuppress_ave = 180,
  Tsuppress_min = 5,
  Tsuppress_max = 25,
  TsuppressOver = nil,
  Nhit = 0,
  Zone_Retreat = nil,
  LifeThreshold = 30,
  IniGroupStrength = nil,
  GroupStrengthThreshold=50,
  CurrentAlarmState="unknown",
  CurrentROE="unknown",
  DefaultAlarmState="Auto",
  DefaultROE="Weapon Free",
}

--- Enumerator of possible rules of engagement.
-- @field #list ROE
SUPPRESSION.ROE={
  Hold="Weapon Hold",
  Free="Weapon Free",
  Return="Return Fire",  
}

--- Enumerator of possible alarm states.
-- @field #list ROE
SUPPRESSION.AlarmState={
  Auto="Auto",
  Green="Green",
  Red="Red",
}

SUPPRESSION.MenuF10=nil

--- Some ID to identify who we are in output of the DCS.log file.
-- @field #string id
SUPPRESSION.id="SFX | "

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--TODO: Figure out who was shooting and move away from him.
--TODO: Move behind a scenery building if there is one nearby.
--TODO: Retreat to a given zone or point.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Creates a new AI_suppression object.
-- @param #SUPPRESSION self
-- @param Wrapper.Group#GROUP Group The GROUP object for which suppression should be applied.
-- @return #SUPPRESSION
function SUPPRESSION:New(Group)

  -- Check that group is present.
  if Group then
    env.info(SUPPRESSION.id.."Suppressive fire for group "..Group:GetName())
  else
    env.info(SUPPRESSION.id.."Suppressive fire: Requested group does not exist! (Has to be a MOOSE group.)")
    return nil
  end
  
  -- Check that we actually have a GROUND group.
  if Group:IsGround()==false then
    env.error(SUPPRESSION.id.."SUPPRESSION fire group "..Group:GetName().." has to be a GROUND group!")
    return nil
  end

  -- Inherits from FSM_CONTROLLABLE
  local self=BASE:Inherit(self, FSM_CONTROLLABLE:New()) -- #SUPPRESSION
  
  -- Set the controllable for the FSM.
  self:SetControllable(Group)
  
    -- Initial group strength.
  self.IniGroupStrength=#Group:GetUnits()
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  
  if not SUPPRESSION.MenuF10 then
    SUPPRESSION.MenuF10 = MENU_MISSION:New("Suppression")
  end
  self:_CreateMenuGroup()
  
  -- Transition from anything to "Suppressed" after event "Hit".
  self:AddTransition("*", "Start", "CombatReady")
  
  self:AddTransition("*", "Hit", "*")
  
  self:AddTransition("*", "Suppress", "*")
  
  self:AddTransition("*", "Recovered", "*")
  
  self:AddTransition("*", "FallBack", "FallingBack")
  
  self:AddTransition("*", "TakeCover", "TakingCover")
  
  self:AddTransition("*", "Retreat", "Retreating")
  
  self:AddTransition("*", "Fight", "CombatReady")
  
  return self
end

--- Create F10 main menu, i.e. F10/Suppression.
-- @param #SUPPRESSION self
function SUPPRESSION:_CreateMenuGroup()
  self.SubMenuName=self.Controllable:GetName()
  self.MenuGroup=MENU_MISSION:New(self.SubMenuName, SUPPRESSION.MenuF10)
  MENU_MISSION_COMMAND:New("Fallback!", self.MenuGroup, self.OrderFallBack, self)
  MENU_MISSION_COMMAND:New("Take Cover!", self.MenuGroup, self.OrderTakeCover, self)
  MENU_MISSION_COMMAND:New("Retreat!", self.MenuGroup, self.OrderRetreat, self)
  MENU_MISSION_COMMAND:New("Report Status", self.MenuGroup, self.Status, self)
end

--- Status of group. Current ROE, alarm state, life.
-- @param #SUPPRESSION self
function SUPPRESSION:Status()
  local name=self.Controllable:GetName()
  local nunits=#self.Controllable:GetUnits()
  local roe=self.CurrentROE
  local state=self.CurrentAlarmState
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  local text=string.format("Status of group %s\n", name)
  text=text..string.format("Number of units: %d of %d\n", nunits, self.IniGroupStrength)
  text=text..string.format("Current state: %s\n", self:GetState())
  text=text..string.format("ROE: %s\n", roe)  
  text=text..string.format("Alarm state: %s\n", state)
  text=text..string.format("Life min: %3.0f\n", life_min)
  text=text..string.format("Life max: %3.0f\n", life_max)
  text=text..string.format("Life ave: %3.0f\n", life_ave)
  text=text..string.format("Group strength: %3.0f", groupstrength)
  MESSAGE:New(text,30):ToAll()
  env.info(SUPPRESSION.id..text)
end


--- Order group to fall back between 100 and 150 meters in a random direction.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderFallBack()
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  local vicinity=group:GetCoordinate():GetRandomVec2InRadius(150, 100)
  local coord=COORDINATE:NewFromVec2(vicinity)
  self:FallBack(coord)
end

--- Order group to take cover at a nearby scenery object.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderTakeCover()
  self:TakeCover()
end

--- Order group to retreat to a pre-defined zone.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderRetreat()
  self:Retreat()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set average, minimum and maximum time a unit is suppressed each time it gets hit.
-- @param #SUPPRESSION self
-- @param #number T0 Average time [seconds] a group will be suppressed. Default is 15.
-- @param #number Tmin (Optional) Minimum time [seconds] a group will be suppressed. Default is 5 seconds.
-- @param #number Tmax (Optional) Maximum time a group will be suppressed. Default is 25 seconds.
function SUPPRESSION:SetSuppressionTime(T0, Tmin, Tmax)

  -- Minimum suppression time is input or default but at least 1 second.
  self.Tsuppress_min=Tmin or self.Tsuppress_min
  self.Tsuppress_min=math.max(self.Tsuppress_min, 1)
  
  -- Maximum suppression time is input or dault but at least Tmin.
  self.Tsuppress_max=Tmax or self.Tsuppress_max
  self.Tsuppress_max=math.max(self.Tsuppress_max, self.Tsuppress_min)
  
  -- Expected suppression time is input or default but at leat Tmin and at most Tmax.
  self.Tsuppress_ave=T0 or self.Tsuppress_ave
  self.Tsuppress_ave=math.max(self.Tsuppress_min)
  self.Tsuppress_ave=math.min(self.Tsuppress_max)
  
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Set ave suppression time to %d seconds.", self.Tsuppress_ave))
    env.info(SUPPRESSION.id..string.format("Set min suppression time to %d seconds.", self.Tsuppress_min))
    env.info(SUPPRESSION.id..string.format("Set max suppression time to %d seconds.", self.Tsuppress_max))
  end
end

--- Set the zone to which a group retreats after being damaged too much.
-- @param #SUPPRESSION self
-- @param Core.Zone#ZONE zone MOOSE zone object.
function SUPPRESSION:SetRetreatZone(zone)
  self.Zone_Retreat=zone
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Retreat zone for group %s is %s.", self.Controllable:GetName(), self.Zone_Retreat:GetName()))
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Start" event.
-- @param #SUPPRESSION self
function SUPPRESSION:onafterStart(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterStart", Event, From, To))
  
  local text=string.format("Started SUPPRESSION for group %s.", Controllable:GetName())
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  
  local rzone="not defined"
  if self.Zone_Retreat then
    rzone=self.Zone_Retreat:GetName()
  end
  
  -- Set the current ROE and alam state.
  self:_SetAlarmState(self.DefaultAlarmState)
  self:_SetROE(self.DefaultROE)
  
  local text=string.format("\n******************************************************\n")
  text=text..string.format("Suppressed group   = %s\n", Controllable:GetName())
  text=text..string.format("Group strength     = %d\n", self.IniGroupStrength)
  text=text..string.format("Average time       = %5.1f seconds\n", self.Tsuppress_ave)
  text=text..string.format("Minimum time       = %5.1f seconds\n", self.Tsuppress_min)
  text=text..string.format("Maximum time       = %5.1f seconds\n", self.Tsuppress_max)
  text=text..string.format("Default ROE        = %s\n", self.DefaultROE)
  text=text..string.format("Default AlarmState = %s\n", self.DefaultAlarmState)
  text=text..string.format("Retreat zone       = %s\n", rzone)
  text=text..string.format("Life threshold     = %5.1f\n", self.LifeThreshold)
  text=text..string.format("Group threshold    = %5.1f\n", self.GroupStrengthThreshold)
  text=text..string.format("******************************************************\n")
  env.info(SUPPRESSION.id..text)
    
  -- Add event handler.
  world.addEventHandler(self)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "Hit" event. Counts number of hits. (Of course, this is not really before the group got hit.)
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT Unit 
-- @param Core.Point#COORDINATE Fallback Fallback coordinates (or nil if no attacker could be found).
function SUPPRESSION:onbeforeHit(Controllable, From, Event, To, Unit, Fallback)
  env.info(SUPPRESSION.id..self:_EventFromTo("onbeforeHit", Event, From, To))
  
  -- Increase Hit counter.
  self.Nhit=self.Nhit+1
  
  -- Info on hit times.
  env.info(SUPPRESSION.id..string.format("Group %s has just been hit %d times.", Controllable:GetName(), self.Nhit))
  
end

--- After "Hit" event.
-- @param #SUPPRESSION self
function SUPPRESSION:onafterHit(Controllable, From, Event, To, Unit, Fallback)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterHit", Event, From, To))
  
  if Unit then
    local unit=Unit --Wrapper.Unit#UNIT
    unit:FlareYellow()
  end
  self:Suppress(Unit)
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  
  local RetreatConditionGroup=groupstrength<self.GroupStrengthThreshold
  local RetreatConditionUnit=self.IniGroupStrength==1 and life_min < self.LifeThreshold
  
  if RetreatConditionGroup or RetreatConditionUnit then
  
    Controllable:ClearTasks()
    self:Retreat()
    
  elseif self.Nhit==3 then
  
    if Fallback ~= nil then
    
      Controllable:ClearTasks()
      self:FallBack(Fallback)
      
    else
    
      Controllable:ClearTasks()
      self:TakeCover()
      
    end
  end  
  

  --[[
  -- After three hits fall back a bit.
  local nfallback=99
  if self.Nhit==nfallback then
    env.info(SUPPRESSION.id..string.format("Group %s is falling back after %d hits.", Controllable:GetName(), nfallback))
    Fallback:SmokeGreen()
    local FallbackMarkerID=Fallback:MarkToAll("Fall back position for group "..Controllable:GetName())
    Controllable:OptionAlarmStateGreen()
    self:_FallBack(Fallback)
  end
  
  -- If life of one unit is below threshold, the group is ordered to retreat (if a zone has been specified).
  if not self:Is("Retreating") then
    local conditionGroup=groupstrength<self.GroupStrengthThreshold
    local conditionUnit=self.IniGroupStrength==1 and life_min < self.LifeThreshold
    if conditionGroup or conditionUnit then

    end
  end
  ]]
  
  self:Status()
  
end

--- After "Suppress" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterSuppress(Controllable, From, Event, To, Unit)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterSuppress", Event, From, To))
  
  if Unit then
    local unit=Unit --Wrapper.Unit#UNIT
    unit:FlareRed()
  end
  self:_Suppress()
    
end


--- Before "Recovered" event.
-- @param #SUPPRESSION self
function SUPPRESSION:onbeforeRecovered(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onbeforeRecovered", Event, From, To))
  
  -- Current time.
  local Tnow=timer.getTime()
  
  -- Debug info
  if self.debug then
    env.info(SUPPRESSION.id..string.format("OnBeforeRecovered: Time now: %d  - Time over: %d", Tnow, self.TsuppressionOver))
  end
  
  -- Recovery is only possible if enough time since the last hit has passed.
  if Tnow >= self.TsuppressionOver then
    return true
  else
    return false
  end
  
end

--- After "Recovered" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable
function SUPPRESSION:onafterRecovered(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterRecovered", Event, From, To))
  
  if Controllable and Controllable:IsAlive() then
    MESSAGE:New(string.format("Group %s has recovered. ROE Open Fire!", Controllable:GetName()), 10):ToAllIf(self.debug)
    self:_SetROE()
    Controllable:FlareGreen()
  end
end

--- Before "FallBack" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeFallBack(Controllable, From, Event, To, Coord)
  if From == "FallingBack" then
    return false
  else
    return true
  end
end

--- After "FallBack" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Core.Point#COORDINATE Coord Coordinate to fall back to.
function SUPPRESSION:onafterFallBack(Controllable, From, Event, To, Coord)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterFallback", Event, From, To))
  
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Group %s is falling back after %d hits.", Controllable:GetName(), self.Nhit))
    Coord:SmokeGreen()
  end
  
  local FallbackMarkerID=Coord:MarkToAll("Fall back position for group "..Controllable:GetName())
  
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  self:_FallBack(Coord)
  
end


--- Before "TakeCover" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeTakeCover(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onbeforeTakeCover", Event, From, To))
  
  -- We search objects in a zone with radius 100 m around the group.
  -- TODO: Maybe make the zone radius larger for vehicles.
  local Zone = ZONE_GROUP:New("Zone_Hiding", Controllable, 300)

  -- Scan for Scenery objects to run/drive to.
  Zone:Scan(Object.Category.SCENERY)
  
  local hideouts={}

  for SceneryTypeName, SceneryData in pairs(Zone:GetScannedScenery()) do
    for SceneryName, SceneryObject in pairs(SceneryData) do
    
      local SceneryObject = SceneryObject -- Wrapper.Scenery#SCENERY
      
      if self.debug then
        --local MarkerID=SceneryObject:GetCoordinate():MarkToAll(string.format("%s scenery object %s", Controllable:GetName(),SceneryObject:GetTypeName()))
        local text=string.format("%s scenery: %s, Coord %s", Controllable:GetName(), SceneryObject:GetTypeName(), SceneryObject:GetCoordinate():ToStringLLDMS())
        env.info(SUPPRESSION.id..text)
      end
      
      table.insert(hideouts, SceneryObject)
      -- TODO: Add check if scenery name matches a specific type like tree or building. This might be tricky though!
      
    end
  end
  
  self.hideout=nil
  local gothideout=false
  if #hideouts>0 then
    if self.debug then
      env.info(SUPPRESSION.id.."Number of hideouts "..#hideouts)
    end
    self.hideout=hideouts[math.random(#hideouts)]
    gothideout=true
  else
    env.info(SUPPRESSION.id.."No hideouts found!")
  end
  
  -- Only take cover if we found a hideout.
  return gothideout
  
end

--- After "TakeCover" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterTakeCover(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterTakeCover", Event, From, To))
  
  if self.debug then
    local text=string.format("Group %s is taking cover!", Controllable:GetName())
    MESSAGE:New(text, 30):ToAll()
  end
  
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  
  local hideout=self.hideout --Wrapper.Scenery#SCENERY
  
  if self.debug then
    local MarkerID=hideout:GetCoordinate():MarkToAll(string.format("%s scenery object %s", Controllable:GetName(), hideout:GetTypeName()))
    MESSAGE:New(string.format("Group %s is taking cover!", Controllable:GetName()), 30):ToAll()
  end
  
  Controllable:RouteGroundTo(hideout:GetCoordinate(), 99, "Vee", 0)
  --TODO: Search place to hide. For each unit (disperse) or same for all?
  
end



--- Before "Retreat" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeRetreat(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onbeforeRetreat", Event, From, To))
    
  -- Retreat is only possible if a zone has been defined by the user.
  if self.Zone_Retreat==nil then
    env.info(SUPPRESSION.id.."Retreat NOT possible! No Zone specified.")
    return false
  elseif self:Is("Retreating") then
    env.info(SUPPRESSION.id.."Group is already retreating.")
    return false
  else
    env.info(SUPPRESSION.id.."Retreat possible, zone specified.")
    return true
  end
  
end

--- After "Retreat" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterRetreat(Controllable, From, Event, To)
  env.info(SUPPRESSION.id..self:_EventFromTo("onafterRetreat", Event, From, To))
    
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  
  -- Route the group to a zone.
  local text=string.format("Group %s is retreating! Alarm state green.", Controllable:GetName())
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)
  self:_RetreatToZone(self.Zone_Retreat, 50, "Vee")
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Event Handler
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Event handler for suppressed groups.
--@param #SUPPRESSION self
function SUPPRESSION:onEvent(event)
  --self:E(event)
  
  local name=self.Controllable:GetName()
  local ini = event.initiator
  local tgt = event.target

  -- INITIATOR
  local IniUnit=nil        -- Wrapper.Unit#UNIT
  local IniGroup=nil       -- Wrapper.Group#GROUP
  local IniUnitName=nil
  local IniGroupName=nil  
  if ini ~= nil then
    IniUnitName = ini:getName()
    IniUnit=UNIT:FindByName(IniUnitName)
    if IniUnit then
      IniGroup=IniUnit:GetGroup()
      IniGroupName=IniGroup:GetName()
    end
  end
  
  -- TARGET
  local TgtUnit=nil        -- Wrapper.Unit#UNIT
  local TgtGroup=nil       -- Wrapper.Group#GROUP
  local TgtUnitName=nil
  local TgtGroupName=nil  
  if tgt ~= nil then
    TgtUnitName = tgt:getName()
    TgtUnit=UNIT:FindByName(TgtUnitName) 
    if TgtUnit then
      TgtGroup=TgtUnit:GetGroup()
      TgtGroupName=TgtGroup:GetName()
    end
  end    
  
  -- Event HIT
  if event.id == world.event.S_EVENT_HIT then
  
    if TgtGroupName==name then
    
      local Fallback=nil
      
      -- Get fallback coordinate if aggressor is a ground unit.
      if IniUnit and IniUnit:IsGround() then
              
        local TC=TgtGroup:GetCoordinate()
        local IC=IniGroup:GetCoordinate()
        
        -- Create a fall back point.
        Fallback=self:_FallBackCoord(TC, IC , 200) -- Core.Point#COORDINATE        
      end
    
      -- FSM Hit event.
      self:Hit(TgtUnit, Fallback)
    end
    
  end
  
  -- Event DEAD
  if event.id == world.event.S_EVENT_DEAD then
  
    if IniGroupName == name then
      
      -- Flare dead unit
      IniUnit:FlareWhite()
    
      -- Number of units left in the group.
      local nunits=#self.Controllable:GetUnits()-1
      
      local text=string.format("A unit from group %s just died! %d units left.", self.Controllable:GetName(), nunits)
      MESSAGE:New(text, 10):ToAll()
      env.info(SUPPRESSION.id..text)
      
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
-- @param #SUPPRESSION self
function SUPPRESSION:_Suppress()

  -- Current time.
  local Tnow=timer.getTime()
  
  -- Controllable
  local Controllable=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  
  -- Group will hold their weapons.
  env.info(SUPPRESSION.id..string.format("Group %s: ROE Hold fire!", Controllable:GetName()))
  self:_SetROE(SUPPRESSION.ROE.Hold)
  
  -- Get randomized time the unit is suppressed.
  local Tsuppress=math.random(self.Tsuppress_min, self.Tsuppress_max)
  Tsuppress=self.Tsuppress_ave
  
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
    self:__Recovered(self.TsuppressionOver-Tnow)
  end
  
  -- Debug message.
  local text=string.format("Group %s is suppressed for %d seconds. Suppression ends at %d:%02d.", Controllable:GetName(), Tsuppress, self.TsuppressionOver/60, self.TsuppressionOver%60)
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)

end


--- Get (relative) life in percent of a group. Function returns the value of the units with the smallest and largest life. Also the average value of all groups is returned.
-- @param #SUPPRESSION self
-- @return #number Smallest life value of all units.
-- @return #number Largest life value of all units.
-- @return #number Average life value.
-- @return #number Relative group strength.
function SUPPRESSION:_GetLife()

  local group=self.Controllable --Wrapper.Group#GROUP
  
  if group and group:IsAlive() then
  
    local life_min=1000
    local life_max=-1000
    local life_ave=0
    local n=0
    local units=group:GetUnits()
    local groupstrength=#units/self.IniGroupStrength*100
    
    for _,unit in pairs(units) do
    
      local unit=unit -- Wrapper.Unit#UNIT
      if unit and unit:IsAlive() then
        n=n+1
        local life=unit:GetLife()/(unit:GetLife0()+1)*100
        if life < life_min then
          life_min=life
        end
        if life > life_max then
          life_max=life
        end
        life_ave=life_ave+life
        if self.debug then
          local text=string.format("n=%02d: Life = %3.1f, Life0 = %3.1f, min=%3.1f, max=%3.1f, ave=%3.1f, group=%3.1f", n, unit:GetLife(), unit:GetLife0(), life_min, life_max, life_ave/n,groupstrength)
          env.info(SUPPRESSION.id..text)
        end
      end
      
    end
    life_ave=life_ave/n
    
    return life_min, life_max, life_ave, groupstrength
  else
    return 0, 0, 0, 0
  end
end


--- Retreat to a random point within a zone.
-- @param #SUPPRESSION self
-- @param Core.Zone#ZONE zone Zone to which the group retreats.
-- @param #number speed Speed of the group. Default max speed the specific group can do.
-- @param #string formation Formation of the Group. Default "Vee".
function SUPPRESSION:_RetreatToZone(zone, speed, formation)

  -- Set zone, speed and formation if they are not given
  zone=zone or self.Zone_Retreat
  speed = speed or 999
  formation = formation or "Vee"

  -- Get a random point in the retreat zone.
  local ZoneCoord=zone:GetRandomCoordinate() -- Core.Point#COORDINATE
  local ZoneVec2=ZoneCoord:GetVec2()

  -- Debug smoke zone and point.
  if self.debug then
    ZoneCoord:SmokeBlue()
    zone:SmokeZone(SMOKECOLOR.Red, 12)
  end
  
  -- Set task to go to zone.
  self.Controllable:TaskRouteToVec2(ZoneVec2, speed, formation)

end

--- Determine the coordinate to which a unit should fall back.
--@param #SUPPRESSION self
--@param Core.Point#COORDINATE a Coordinate of the defending group.
--@param Core.Point#COORDINATE b Coordinate of the attacking group.
--@param #number distance Distance the group will fall back.
--@return Core.Point#COORDINATE Fallback coordinates. 
function SUPPRESSION:_FallBackCoord(a, b, distance)
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
--@param #SUPPRESSION self
--@param Core.Point#COORDINATE coord_fbp Coordinate of the fall back point.
function SUPPRESSION:_FallBack(coord_fbp)

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
  
  local TaskRoute1 = group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, 0)
  local TaskCombo2 = {}
  TaskCombo2[#TaskCombo2+1] = group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, 1)
  TaskCombo2[#TaskCombo2+1] = group:TaskControlled(TaskHold, ConditionWait)
  local TaskRoute2 = group:TaskCombo(TaskCombo2)
  
  group:SetTaskWaypoint(Waypoints[1], TaskRoute1)
  group:SetTaskWaypoint(Waypoints[2], TaskRoute2)
  
  group:Route(Waypoints)

end


--- Group has reached a waypoint.
--@param #SUPPRESSION self
--@param #number i Waypoint number that has been reached.
function SUPPRESSION._Passing_Waypoint(group, Fsm, i)
  local text
  if i==1 then
    text=string.format("Group %s has reached fallback point.", group:GetName())
  else
    text=string.format("Group %s passing waypoint %d.", group:GetName(), i)
  end
  MESSAGE:New(text,10):ToAllIf(Fsm.debug)
  env.info(SUPPRESSION.id..text)
end


--- Generate Gaussian pseudo-random numbers.
-- @param #SUPPRESSION self
-- @param #number x0 Expectation value of distribution.
-- @param #number sigma (Optional) Standard deviation. Default 10.
-- @param #number xmin (Optional) Lower cut-off value.
-- @param #number xmax (Optional) Upper cut-off value.
-- @return #number Gaussian random number.
function SUPPRESSION:_Random_Gaussian(x0, sigma, xmin, xmax)

  -- Standard deviation. Default 10 if not given.
  sigma=sigma or 10
    
  local r
  local gotit=false
  local i=0
  while not gotit do
  
    -- Uniform numbers in [0,1). We need two.
    local x1=math.random()
    local x2=math.random()
  
    -- Transform to Gaussian exp(-(x-x0)²/(2*sigma²).
    r = math.sqrt(-2*sigma*sigma * math.log(x1)) * math.cos(2*math.pi * x2) + x0
    
    i=i+1
    if (r>=xmin and r<=xmax) or i>100 then
      gotit=true
    end
  end
  
  return r

end

--- Sets the ROE for the group and updates the current ROE variable.
-- @param #SUPPRESSION self
-- @param #string roe ROE the group will get. Possible "Free", "Hold", "Return". Default is self.DefaultROE.
function SUPPRESSION:_SetROE(roe)
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  
  -- If no argument is given, we take the default ROE.
  roe=roe or self.DefaultROE
  
  -- Update the current ROE.
  self.CurrentROE=roe
  
  -- Set the ROE.
  if roe==SUPPRESSION.ROE.Free then
    group:OptionROEWeaponFree()
  elseif roe==SUPPRESSION.ROE.Hold then
    group:OptionROEHoldFire()
  elseif roe==SUPPRESSION.ROE.Return then
    group:OptionROEReturnFire()
  else
    env.error(SUPPRESSION.id.."Unknown ROE requested: "..tostring(roe))
    group:OptionROEWeaponFree()
    self.CurrentROE=SUPPRESSION.ROE.Free
  end
end

--- Sets the alarm state of the group and updates the current alarm state variable.
-- @param #SUPPRESSION self
-- @param #string state Alarm state the group will get. Possible "Auto", "Green", "Red". Default is self.DefaultAlarmState.
function SUPPRESSION:_SetAlarmState(state)
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  
  -- Input or back to default alarm state.
  state=state or self.DefaultAlarmState
  
  -- Update the current alam state of the group.
  self.CurrentAlarmState=state
  
  -- Set the alarm state.
  if state==SUPPRESSION.AlarmState.Auto then
    group:OptionAlarmStateAuto()
  elseif state==SUPPRESSION.AlarmState.Green then
    group:OptionAlarmStateGreen()
  elseif state==SUPPRESSION.AlarmState.Red then
    group:OptionAlarmStateRed()
  else
    env.error(SUPPRESSION.id.."Unknown alarm state requested: "..tostring(state))
    group:OptionAlarmStateAuto()
    self.CurrentAlarmState=SUPPRESSION.AlarmState.Auto
  end
end

--- Return event-from-to string. 
-- @param #SUPPRESSION self
-- @param #string BA
-- @param #string event
-- @param #string from
-- @param #string to
-- @return #string From-to info.
function SUPPRESSION:_EventFromTo(BA, Event, From, To)
  return string.format("%s: %s event %s %s --> %s", BA, self.Controllable:GetName(), Event, From, To)
end