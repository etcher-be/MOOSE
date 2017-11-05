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
-- @field #boolean flare Flare units when they get hit or die.
-- @field #boolean smoke Smoke places to which the group retreats, falls back or hides.
-- @field #string Type Type of the group.
-- @field Core.Controllable#CONTROLLABLE Controllable Controllable of the FSM. Must be a ground group.
-- @field #number Tsuppress_ave Average time in seconds a group gets suppressed. Actual value is sampled randomly from a Gaussian distribution.
-- @field #number Tsuppress_min Minimum time in seconds the group gets suppressed.
-- @field #number Tsuppress_max Maximum time in seconds the group gets suppressed.
-- @field #number TsuppressionOver Time at which the suppression will be over.
-- @field #number IniGroupStrength Number of units in a group at start.
-- @field #number Nhit Number of times the group was hit.
-- @field #string Formation Formation which will be used when falling back, taking cover or retreating. Default "Vee".
-- @field #number Speed Speed the unit will use when falling back, taking cover or retreating. Default 999.
-- @field #boolean FallbackON If true, group can fall back, i.e. move away from the attacking unit.
-- @field #number FallbackWait Time in seconds the unit will wait at the fall back point before it resumes its mission.
-- @field #number FallbackDist Distance in meters the unit will fall back.
-- @field #number FallbackHeading Heading in degrees to which the group should fall back. Default is directly away from the attacking unit.
-- @field #boolean TakecoverON If true, group can hide at a nearby scenery object.
-- @field #number TakecoverWait Time in seconds the group will hide before it will resume its mission.
-- @field #number TakecoverRange Range in which the group will search for scenery objects to hide at.
-- @field #number NhitAction Number of hits after which the group falls back or takes cover.
-- @field Core.Zone#ZONE RetreatZone Zone to which a group retreats.
-- @field #number LifeThreshold Life of group in percent at which the group will be ordered to retreat.
-- @field #number GroupThreshold Threshold of group strength before retreat is ordered.
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
  flare = true,
  smoke = true,
  Type = nil,
  Tsuppress_ave = 15,
  Tsuppress_min = 5,
  Tsuppress_max = 25,
  TsuppressOver = nil,
  IniGroupStrength = nil,
  Nhit = 0,
  Formation = "Vee",
  Speed = 999,
  FallbackON = true,
  FallbackWait = 60,
  FallbackDist = 100,
  FallbackHeading = nil,
  TakecoverON = true,
  TakecoverWait = 120,
  TakecoverRange = 300,
  NhitAction = 3,
  RetreatZone = nil,
  LifeThreshold = 50,
  GroupThreshold = 50,
  CurrentAlarmState = "unknown",
  CurrentROE = "unknown",
  DefaultAlarmState = "Auto",
  DefaultROE = "Weapon Free",
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

--- Main F10 menu for suppresion, i.e. F10/Suppression.
-- @field #string MenuF10
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
  
  -- Type of group.
  self.Type=Group:GetTypeName()
  
  -- Initial group strength.
  self.IniGroupStrength=#Group:GetUnits()
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  
  -- Create main F10 menu if it is not there yet.
  if not SUPPRESSION.MenuF10 then
    SUPPRESSION.MenuF10 = MENU_MISSION:New("Suppression")
  end
  
  -- Create submenu for this group.
  self:_CreateMenuGroup()
  
  
  -- Transitions
  self:AddTransition("*", "Start", "CombatReady")
  
  self:AddTransition("*", "Hit", "*")
  
  self:AddTransition("*", "Suppress", "*")
  
  self:AddTransition("*", "Recovered", "*")
  
  self:AddTransition("*", "FallBack", "FallingBack")
  
  self:AddTransition("*", "TakeCover", "TakingCover")
  
  self:AddTransition("*", "Retreat", "Retreating")
  
  self:AddTransition("*", "FightBack", "CombatReady")
  
  self:AddTransition("*", "Dead", "*")
  
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
  MENU_MISSION_COMMAND:New("Report Status", self.MenuGroup, self.Status, self, true)
end

--- Status of group. Current ROE, alarm state, life.
-- @param #SUPPRESSION self
-- @param #boolean message Send message to all players.
function SUPPRESSION:Status(message)

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
  
  MESSAGE:New(text, 10):ToAllIf(message or self.debug)
  env.info(SUPPRESSION.id..text)
end


--- Order group to fall back between 100 and 150 meters in a random direction.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderFallBack()
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  local vicinity=group:GetCoordinate():GetRandomVec2InRadius(150, 100)
  local coord=COORDINATE:NewFromVec2(vicinity)
  self:FallBack(self.Controllable)
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
  self.RetreatZone=zone
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Retreat zone for group %s is %s.", self.Controllable:GetName(), self.RetreatZone:GetName()))
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Start" event. Initialized ROE and alarm state. Starts the event handler.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterStart(Controllable, From, Event, To)
  self:_EventFromTo("onafterStart", Event, From, To)
  
  local text=string.format("Started SUPPRESSION for group %s.", Controllable:GetName())
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  
  local rzone="not defined"
  if self.RetreatZone then
    rzone=self.RetreatZone:GetName()
  end
  
  -- Set the current ROE and alam state.
  self:_SetAlarmState(self.DefaultAlarmState)
  self:_SetROE(self.DefaultROE)
  
  local text=string.format("\n******************************************************\n")
  text=text..string.format("Suppressed group   = %s\n", Controllable:GetName())
  text=text..string.format("Type               = %s\n", self.Type)
  text=text..string.format("Group strength     = %d\n", self.IniGroupStrength)
  text=text..string.format("Average time       = %5.1f seconds\n", self.Tsuppress_ave)
  text=text..string.format("Minimum time       = %5.1f seconds\n", self.Tsuppress_min)
  text=text..string.format("Maximum time       = %5.1f seconds\n", self.Tsuppress_max)
  text=text..string.format("Default ROE        = %s\n", self.DefaultROE)
  text=text..string.format("Default AlarmState = %s\n", self.DefaultAlarmState)
  text=text..string.format("Fall back ON       = %s\n", tostring(self.FallbackON))
  text=text..string.format("Fall back distance = %5.1f m\n", self.FallbackDist)
  text=text..string.format("Fall back wait     = %5.1f seconds\n", self.FallbackWait)
  text=text..string.format("Fall back heading  = %s degrees\n", tostring(self.FallbackHeading))
  text=text..string.format("Take cover ON      = %s\n", tostring(self.TakecoverON))
  text=text..string.format("Take cover search  = %5.1f m\n", self.TakecoverRange)
  text=text..string.format("Take cover wait    = %5.1f seconds\n", self.TakecoverWait)  
  text=text..string.format("FB/TC hits action  = %d\n", self.NhitAction)  
  text=text..string.format("Retreat zone       = %s\n", rzone)
  text=text..string.format("Life threshold     = %5.1f %%\n", self.LifeThreshold)
  text=text..string.format("Group threshold    = %5.1f %%\n", self.GroupThreshold)
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
-- @param Wrapper.Unit#UNIT Unit Unit that was hit.
-- @param Wrapper.Unit#UNIT AttackUnit Unit that attacked.
-- @param Core.Point#COORDINATE Fallback Fallback coordinates (or nil if no attacker could be found).
function SUPPRESSION:onbeforeHit(Controllable, From, Event, To, Unit, AttackUnit)
  self:_EventFromTo("onbeforeHit", Event, From, To)
  
  -- Increase Hit counter.
  self.Nhit=self.Nhit+1
  
  -- Info on hit times.
  env.info(SUPPRESSION.id..string.format("Group %s has just been hit %d times.", Controllable:GetName(), self.Nhit))
  
end

--- After "Hit" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT Unit Unit that was hit.
-- @param Wrapper.Unit#UNIT AttackUnit Unit that attacked.
function SUPPRESSION:onafterHit(Controllable, From, Event, To, Unit, AttackUnit)
  self:_EventFromTo("onafterHit", Event, From, To)
  
  -- Flare unit that was hit.
  if self.flare or self.debug then
    if Unit then
      Unit:FlareRed()
    end
  end
  
  -- Suppress unit.
  self:Suppress(Unit)
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, groupstrength=self:_GetLife()
  
  -- Conditions for retreat.
  local RetreatConditionGroup = groupstrength < self.GroupThreshold
  local RetreatConditionUnit  = self.IniGroupStrength==1 and life_min < self.LifeThreshold
  
  if RetreatConditionGroup or RetreatConditionUnit then
  
    -- Trigger Retreat event.
    self:Retreat()
    
  elseif self.Nhit==self.NhitAction then
  
    if self.FallbackON and AttackUnit:IsGround() then
    
      -- Trigger FallBack event.
      self:FallBack(AttackUnit)
      
    elseif self.TakecoverON then
    
      -- Trigger TakeCover event.
      self:TakeCover()
      
    end
  end
  
  -- Give info on current status.
  if self.debug then
    self:Status()
  end
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Suppress" event. Group will be suppressed be setting its ROE to weapon hold.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT Unit Unit that was hit.
function SUPPRESSION:onafterSuppress(Controllable, From, Event, To, Unit)
  self:_EventFromTo("onafterSuppress", Event, From, To)
  
  -- Suppress unit.
  self:_Suppress()

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "Recovered" event. Check if suppression time is over.
-- @param #SUPPRESSION self
function SUPPRESSION:onbeforeRecovered(Controllable, From, Event, To)
  self:_EventFromTo("onbeforeRecovered", Event, From, To)
  
  -- Current time.
  local Tnow=timer.getTime()
  
  -- Debug info
  if self.debug then
    env.info(SUPPRESSION.id..string.format("onbeforeRecovered: Time now: %d  - Time over: %d", Tnow, self.TsuppressionOver))
  end
  
  -- Recovery is only possible if enough time since the last hit has passed.
  if Tnow >= self.TsuppressionOver then
    return true
  else
    return false
  end
  
end

--- After "Recovered" event. Group has recovered and its ROE is set back to the "normal" unsuppressed state. Optionally the group is flared green.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable of the group.
function SUPPRESSION:onafterRecovered(Controllable, From, Event, To)
  self:_EventFromTo("onafterRecovered", Event, From, To)
  
  if Controllable and Controllable:IsAlive() then
  
    -- Debug message.
    local text=string.format("Group %s has recovered!", Controllable:GetName())
    MESSAGE:New(text, 10):ToAllIf(self.debug)
    env.info(SUPPRESSION.id..text)
    
    -- Set ROE back to default.
    self:_SetROE()
    
    -- Flare unit green.
    if self.flare then
      Controllable:FlareGreen()
    end
    
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "FallBack" event. We check that group is not already falling back.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT AttackUnit Attacking unit. We will move away from this.
function SUPPRESSION:onbeforeFallBack(Controllable, From, Event, To, AttackUnit)
  self:_EventFromTo("onbeforeFallBack", Event, From, To)
  
  --TODO: Add retreat?
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
-- @param Wrapper.Unit#UNIT AttackUnit Attacking unit. We will move away from this.
function SUPPRESSION:onafterFallBack(Controllable, From, Event, To, AttackUnit)
  self:_EventFromTo("onafterFallback", Event, From, To)
  
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Group %s is falling back after %d hits.", Controllable:GetName(), self.Nhit))
  end
  
  -- Coordinate of the attacker and attacked unit.
  local ACoord=AttackUnit:GetCoordinate()
  local DCoord=Controllable:GetCoordinate()
  
  -- Heading from attacker to attacked unit.
  local heading=self:_Heading(ACoord, DCoord)
  
  -- Create a coordinate ~ 100 m in opposite direction of the attacking unit.
  local Coord=DCoord:Translate(self.FallbackDist, heading)
  
  -- Place marker
  local MarkerID=Coord:MarkToAll("Fall back position for group "..Controllable:GetName())
  
  -- Smoke the coordinate.
  if self.debug or self.smoke then
    Coord:SmokeBlue()
  end
  
  -- Set alarm state to GREEN and let the unit run away.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)

  -- Make the group run away.
  self:_Run(Coord, 99, "Vee", 60)
  
end

--- After "FightBack" event. Alarm state is set back to default.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterFightBack(Controllable, From, Event, To)
  self:_EventFromTo("onafterFightBack", Event, From, To)
  
  -- Set alarm state back to default.
  self:_SetAlarmState()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "TakeCover" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeTakeCover(Controllable, From, Event, To)
  self:_EventFromTo("onbeforeTakeCover", Event, From, To)
  
  --TODO: Need to test this!
  -- If 
  if From=="TakingCover" then
    return false
  end
  
  -- We search objects in a zone with radius 300 m around the group.
  local Zone = ZONE_GROUP:New("Zone_Hiding", Controllable, self.TakecoverRange)

  -- Scan for Scenery objects to run/drive to.
  Zone:Scan(Object.Category.SCENERY)
  
  -- Array with all possible hideouts, i.e. scenery objects in the vicinity of the group.
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
    
    -- Pick a random location.
    self.hideout=hideouts[math.random(#hideouts)]
    gothideout=true
  else
    env.error(SUPPRESSION.id.."No hideouts found!")
  end
  
  -- Only take cover if we found a hideout.
  return gothideout
  
end

--- After "TakeCover" event. Group will run to a nearby scenery object and hide there for a certain time.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterTakeCover(Controllable, From, Event, To)
  self:_EventFromTo("onafterTakeCover", Event, From, To)
    
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  
  local hideout=self.hideout --Wrapper.Scenery#SCENERY
  local coord=hideout:GetCoordinate()
  
  if self.debug then
    local MarkerID=coord:MarkToAll(string.format("%s scenery object %s", Controllable:GetName(), hideout:GetTypeName()))    
    MESSAGE:New(string.format("Group %s is taking cover!", Controllable:GetName()), 30):ToAll()
  end
  
  -- Smoke place of hideout.
  if self.smoke or self.debug then
    coord:SmokeBlue()
  end
  
  -- Make the group run away.
  self:_Run(coord, self.Speed, self.Formation, self.TakecoverWait)
    
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "Retreat" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeRetreat(Controllable, From, Event, To)
  self:_EventFromTo("onbeforeRetreat", Event, From, To)
  
  -- Retreat is only possible if a zone has been defined by the user.
  if self.RetreatZone==nil then
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
  self:_EventFromTo("onafterRetreat", Event, From, To)
    
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  
  -- Route the group to a zone.
  local text=string.format("Group %s is retreating! Alarm state green.", Controllable:GetName())
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)
  
  -- Get a random point in the retreat zone.
  local ZoneCoord=self.RetreatZone:GetRandomCoordinate() -- Core.Point#COORDINATE
  local ZoneVec2=ZoneCoord:GetVec2()

  -- Debug smoke zone and point.
  if self.debug or self.smoke then
    ZoneCoord:SmokeBlue()
  end
  if self.debug then
    self.RetreatZone:SmokeZone(SMOKECOLOR.Red, 12)
  end
  
  -- Make unit run to retreat zone and wait there for two hours.
  local wait=60*120
  self:_Run(ZoneCoord, self.Speed, self.Formation, wait)
  
end


--- After "Dead" event, when a unit has died.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterDead(Controllable, From, Event, To)
  self:_EventFromTo("onafterDead", Event, From, To)
  
  -- Number of units left in the group.
  local nunits=#self.Controllable:GetUnits()
      
  local text=string.format("Unit from group %s just died! %d units left.", self.Controllable:GetName(), nunits)
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)
      
  -- Go to stop state.
  if nunits==0 then
    env.info(string.format("Stopping SUPPRESSION for group %s.", Controllable:GetName()))
    self:Stop()
    world.removeEventHandler(self)
  end
  
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
    
      -- FSM Hit event.
      self:Hit(TgtUnit, IniUnit)
    end
    
  end
  
  -- Event DEAD
  if event.id == world.event.S_EVENT_DEAD then
  
    if IniGroupName == name then
      
      -- Flare dead unit
      if self.debug or self.smoke then
        IniUnit:FlareWhite()
      end
      

      -- Call dead event.
      self:__Dead(1)
      
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
  self:_SetROE(SUPPRESSION.ROE.Hold)
  
  -- Get randomized time the unit is suppressed.
  local sigma=(self.Tsuppress_max-self.Tsuppress_min)/4
  local Tsuppress=self:_Random_Gaussian(self.Tsuppress_ave,sigma,self.Tsuppress_min, self.Tsuppress_max)
  --Tsuppress=self.Tsuppress_ave
  
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

--- Make group run/drive to a certain point. We put in several intermediate waypoints because sometimes the group stops before it arrived at the desired point.
--@param #SUPPRESSION self
--@param Core.Point#COORDINATE fin Coordinate where we want to go.
--@param #number speed Speed of group. Default is 999.
--@param #string formation Formation of group. Default is "Vee".
--@param #number wait Time the group will wait/hold at final waypoint. Default is 30 seconds.
function SUPPRESSION:_Run(fin, speed, formation, wait)

  speed=speed or 999
  formation=formation or "Vee"
  wait=wait or 30

  local group=self.Controllable -- Wrapper.Controllable#CONTROLLABLE
  group:ClearTasks()
  
  local ini=group:GetCoordinate()
  
  -- Distance between current and final point. 
  local dist=ini:Get2DDistance(fin)
  
  local heading=self:_Heading(ini, fin)
  
  -- Distance between intermedeate waypoints.
  local dx
  if dist < 100 then
    dx=25
  elseif dist < 500 then
    dx=50
  else
    dx=100
  end
  
  -- Number of intermediate waypoints.
  local nx=dist/dx
  if nx<1 then
    nx=0
  end
    
  -- Waypoint and task arrays.
  local wp={}
  local tasks={}
  
  -- First waypoint is the current position of the group.
  wp[1]=ini:WaypointGround(speed, formation)
  tasks[1]=group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, 1, false)
  
  for i=1,nx do
  
    local x=dx*i
    local coord=ini:Translate(x, heading)
    
    wp[#wp+1]=coord:WaypointGround(speed, formation)
    tasks[#tasks+1]=group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, #wp, false)
    
    env.info(SUPPRESSION.id..string.format("%d x = %4.1f", i, x))
    local MarkerID=coord:MarkToAll(string.format("Waypoing %d of group %s", #wp, self.Controllable:GetName()))
    
  end
  
  -- Final waypoint.
  wp[#wp+1]=fin:WaypointGround(speed, formation)
  
    -- Task to hold.
  local ConditionWait=group:TaskCondition(nil, nil, nil, nil, wait, nil)
  local TaskHold = group:TaskHold()
  
  -- Task combo to make group hold at final waypoint.
  local TaskComboFin = {}
  TaskComboFin[#TaskComboFin+1] = group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, #wp, true)
  TaskComboFin[#TaskComboFin+1] = group:TaskControlled(TaskHold, ConditionWait)

  -- Add final task.  
  tasks[#tasks+1]=group:TaskCombo(TaskComboFin)

  -- Original waypoints of the group.
  local Waypoints = group:GetTemplateRoutePoints()
  
  -- New points are added to the default route.
  for i,p in ipairs(wp) do
    table.insert(Waypoints, i, wp[i])
  end
  
  -- Set task for all waypoints.
  for i,wp in ipairs(Waypoints) do
    group:SetTaskWaypoint(Waypoints[i], tasks[i])
  end
  
  -- Submit task and route group along waypoints.
  group:Route(Waypoints)

end

--- Function called when group is passing a waypoint. At the last waypoint we set the group back to CombatReady.
--@param #SUPPRESSION self
--@param #number i Waypoint number that has been reached.
--@param #boolean final True if it is the final waypoint. Start Fightback.
function SUPPRESSION._Passing_Waypoint(group, Fsm, i, final)

  -- Debug message.
  local text=string.format("Group %s passing waypoint %d.", group:GetName(), i)
  MESSAGE:New(text,10):ToAllIf(Fsm.debug)
  if Fsm.debug then
    --env.info(SUPPRESSION.id..text)
  end
  env.info(SUPPRESSION.id..text)

  -- Some action.
  if final then
    Fsm:FightBack()
  end  
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


--- Heading from point a to point b in degrees.
--@param #SUPPRESSION self
--@param Core.Point#COORDINATE a Coordinate.
--@param Core.Point#COORDINATE b Coordinate.
--@return #number angle Angle from a to b in degrees.
function SUPPRESSION:_Heading(a, b, distance)
  local dx = b.x-a.x
  local dy = b.z-a.z
  local angle = math.deg(math.atan2(dy,dx))
  if angle < 0 then
    angle = 360 + angle
  end
  return angle
end

--- Generate Gaussian pseudo-random numbers.
-- @param #SUPPRESSION self
-- @param #number x0 Expectation value of distribution.
-- @param #number sigma (Optional) Standard deviation. Default 10.
-- @param #number xmin (Optional) Lower cut-off value.
-- @param #number xmax (Optional) Upper cut-off value.
-- @return #number Gaussian random number.
function SUPPRESSION:_Random_Gaussian(x0, sigma, xmin, xmax)

  -- Standard deviation. Default 5 if not given.
  sigma=sigma or 5
    
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
    group:OptionROEOpenFire()
  elseif roe==SUPPRESSION.ROE.Hold then
    group:OptionROEHoldFire()
  elseif roe==SUPPRESSION.ROE.Return then
    group:OptionROEReturnFire()
  else
    env.error(SUPPRESSION.id.."Unknown ROE requested: "..tostring(roe))
    group:OptionROEOpenFire()
    self.CurrentROE=SUPPRESSION.ROE.Free
  end
  
  local text=string.format("Group %s now has ROE %s.", self.Controllable:GetName(), self.CurrentROE)
  env.info(SUPPRESSION.id..text)
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
  
  local text=string.format("Group %s now has Alarm State %s.", self.Controllable:GetName(), self.CurrentAlarmState)
  env.info(SUPPRESSION.id..text)
end

--- Return event-from-to string. 
-- @param #SUPPRESSION self
-- @param #string BA Before/after info.
-- @param #string Event Event.
-- @param #string From From state.
-- @param #string To To state.
function SUPPRESSION:_EventFromTo(BA, Event, From, To)
  if self.debug then
    local text=string.format("%s: %s event %s %s --> %s", BA, self.Controllable:GetName(), Event, From, To)
    env.info(SUPPRESSION.id..text)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
