--- **Core** - BASE forms **the basis of the MOOSE framework**. Each class within the MOOSE framework derives from BASE.
-- 
-- ![Banner Image](..\Presentations\BASE\Dia1.JPG)
-- 
-- ===
-- 
-- # 1) @{#BASE} class
-- 
-- All classes within the MOOSE framework are derived from the @{#BASE} class. 
--  
-- BASE provides facilities for :
-- 
--   * The construction and inheritance of MOOSE classes.
--   * The class naming and numbering system.
--   * The class hierarchy search system.
--   * The tracing of information or objects during mission execution for debuggin purposes.
--   * The subscription to DCS events for event handling in MOOSE objects.
-- 
-- Note: The BASE class is an abstract class and is not meant to be used directly.
-- 
-- ## 1.1) BASE constructor
-- 
-- Any class derived from BASE, will use the @{Base#BASE.New} constructor embedded in the @{Base#BASE.Inherit} method. 
-- See an example at the @{Base#BASE.New} method how this is done.
-- 
-- ## 1.2) Trace information for debugging
-- 
-- The BASE class contains trace methods to trace progress within a mission execution of a certain object.
-- These trace methods are inherited by each MOOSE class interiting BASE, soeach object created from derived class from BASE can use the tracing methods to trace its execution.
-- 
-- Any type of information can be passed to these tracing methods. See the following examples:
-- 
--     self:E( "Hello" )
-- 
-- Result in the word "Hello" in the dcs.log.
-- 
--     local Array = { 1, nil, "h", { "a","b" }, "x" }
--     self:E( Array )
--     
-- Results with the text [1]=1,[3]="h",[4]={[1]="a",[2]="b"},[5]="x"} in the dcs.log.   
-- 
--     local Object1 = "Object1"
--     local Object2 = 3
--     local Object3 = { Object 1, Object 2 }
--     self:E( { Object1, Object2, Object3 } )
--     
-- Results with the text [1]={[1]="Object",[2]=3,[3]={[1]="Object",[2]=3}} in the dcs.log.
--     
--     local SpawnObject = SPAWN:New( "Plane" )
--     local GroupObject = GROUP:FindByName( "Group" )
--     self:E( { Spawn = SpawnObject, Group = GroupObject } )
-- 
-- Results with the text [1]={Spawn={....),Group={...}} in the dcs.log.  
-- 
-- Below a more detailed explanation of the different method types for tracing.
-- 
-- ### 1.2.1) Tracing methods categories
--
-- There are basically 3 types of tracing methods available:
-- 
--   * @{#BASE.F}: Used to trace the entrance of a function and its given parameters. An F is indicated at column 44 in the DCS.log file.
--   * @{#BASE.T}: Used to trace further logic within a function giving optional variables or parameters. A T is indicated at column 44 in the DCS.log file.
--   * @{#BASE.E}: Used to always trace information giving optional variables or parameters. An E is indicated at column 44 in the DCS.log file.
-- 
-- ### 1.2.2) Tracing levels
--
-- There are 3 tracing levels within MOOSE.  
-- These tracing levels were defined to avoid bulks of tracing to be generated by lots of objects.
-- 
-- As such, the F and T methods have additional variants to trace level 2 and 3 respectively:
--
--   * @{#BASE.F2}: Trace the beginning of a function and its given parameters with tracing level 2.
--   * @{#BASE.F3}: Trace the beginning of a function and its given parameters with tracing level 3.
--   * @{#BASE.T2}: Trace further logic within a function giving optional variables or parameters with tracing level 2.
--   * @{#BASE.T3}: Trace further logic within a function giving optional variables or parameters with tracing level 3.
-- 
-- ### 1.2.3) Trace activation.
-- 
-- Tracing can be activated in several ways:
-- 
--   * Switch tracing on or off through the @{#BASE.TraceOnOff}() method.
--   * Activate all tracing through the @{#BASE.TraceAll}() method.
--   * Activate only the tracing of a certain class (name) through the @{#BASE.TraceClass}() method.
--   * Activate only the tracing of a certain method of a certain class through the @{#BASE.TraceClassMethod}() method.
--   * Activate only the tracing of a certain level through the @{#BASE.TraceLevel}() method.
-- 
-- ### 1.2.4) Check if tracing is on.
-- 
-- The method @{#BASE.IsTrace}() will validate if tracing is activated or not.
-- 
-- ## 1.3 DCS simulator Event Handling
-- 
-- The BASE class provides methods to catch DCS Events. These are events that are triggered from within the DCS simulator, 
-- and handled through lua scripting. MOOSE provides an encapsulation to handle these events more efficiently.
-- 
-- ### 1.3.1 Subscribe / Unsubscribe to DCS Events
-- 
-- At first, the mission designer will need to **Subscribe** to a specific DCS event for the class.
-- So, when the DCS event occurs, the class will be notified of that event.
-- There are two methods which you use to subscribe to or unsubscribe from an event.
-- 
--   * @{#BASE.HandleEvent}(): Subscribe to a DCS Event.
--   * @{#BASE.UnHandleEvent}(): Unsubscribe from a DCS Event.
-- 
-- ### 1.3.2 Event Handling of DCS Events
-- 
-- Once the class is subscribed to the event, an **Event Handling** method on the object or class needs to be written that will be called
-- when the DCS event occurs. The Event Handling method receives an @{Event#EVENTDATA} structure, which contains a lot of information
-- about the event that occurred.
-- 
-- Find below an example of the prototype how to write an event handling function for two units: 
--
--      local Tank1 = UNIT:FindByName( "Tank A" )
--      local Tank2 = UNIT:FindByName( "Tank B" )
--      
--      -- Here we subscribe to the Dead events. So, if one of these tanks dies, the Tank1 or Tank2 objects will be notified.
--      Tank1:HandleEvent( EVENTS.Dead )
--      Tank2:HandleEvent( EVENTS.Dead )
--      
--      --- This function is an Event Handling function that will be called when Tank1 is Dead.
--      -- @param Wrapper.Unit#UNIT self 
--      -- @param Core.Event#EVENTDATA EventData
--      function Tank1:OnEventDead( EventData )
--
--        self:SmokeGreen()
--      end
--
--      --- This function is an Event Handling function that will be called when Tank2 is Dead.
--      -- @param Wrapper.Unit#UNIT self 
--      -- @param Core.Event#EVENTDATA EventData
--      function Tank2:OnEventDead( EventData )
--
--        self:SmokeBlue()
--      end
-- 
-- 
-- 
-- See the @{Event} module for more information about event handling.
-- 
-- ## 1.4) Class identification methods
-- 
-- BASE provides methods to get more information of each object:
-- 
--   * @{#BASE.GetClassID}(): Gets the ID (number) of the object. Each object created is assigned a number, that is incremented by one.
--   * @{#BASE.GetClassName}(): Gets the name of the object, which is the name of the class the object was instantiated from.
--   * @{#BASE.GetClassNameAndID}(): Gets the name and ID of the object.
-- 
-- ## 1.5) All objects derived from BASE can have "States"
-- 
-- A mechanism is in place in MOOSE, that allows to let the objects administer **states**.  
-- States are essentially properties of objects, which are identified by a **Key** and a **Value**.  
-- 
-- The method @{#BASE.SetState}() can be used to set a Value with a reference Key to the object.  
-- To **read or retrieve** a state Value based on a Key, use the @{#BASE.GetState} method.  
-- 
-- These two methods provide a very handy way to keep state at long lasting processes.
-- Values can be stored within the objects, and later retrieved or changed when needed.
-- There is one other important thing to note, the @{#BASE.SetState}() and @{#BASE.GetState} methods
-- receive as the **first parameter the object for which the state needs to be set**.
-- Thus, if the state is to be set for the same object as the object for which the method is used, then provide the same
-- object name to the method.
-- 
-- ## 1.10) Inheritance
-- 
-- The following methods are available to implement inheritance
-- 
--   * @{#BASE.Inherit}: Inherits from a class.
--   * @{#BASE.GetParent}: Returns the parent object from the object it is handling, or nil if there is no parent object.
--   
-- ====
-- 
-- # **API CHANGE HISTORY**
-- 
-- The underlying change log documents the API changes. Please read this carefully. The following notation is used:
-- 
--   * **Added** parts are expressed in bold type face.
--   * _Removed_ parts are expressed in italic type face.
-- 
-- YYYY-MM-DD: CLASS:**NewFunction**( Params ) replaces CLASS:_OldFunction_( Params )
-- YYYY-MM-DD: CLASS:**NewFunction( Params )** added
-- 
-- Hereby the change log:
-- 
-- ===
-- 
-- # **AUTHORS and CONTRIBUTIONS**
-- 
-- ### Contributions: 
-- 
--   * None.
-- 
-- ### Authors: 
-- 
--   * **FlightControl**: Design & Programming
-- 
-- @module Base



local _TraceOnOff = true
local _TraceLevel = 1
local _TraceAll = false
local _TraceClass = {}
local _TraceClassMethod = {}

local _ClassID = 0

--- The BASE Class
-- @type BASE
-- @field ClassName The name of the class.
-- @field ClassID The ID number of the class.
-- @field ClassNameAndID The name of the class concatenated with the ID number of the class.
BASE = {
  ClassName = "BASE",
  ClassID = 0,
  _Private = {},
  Events = {},
  States = {}
}

--- The Formation Class
-- @type FORMATION
-- @field Cone A cone formation.
FORMATION = {
  Cone = "Cone" 
}



--- BASE constructor.  
-- 
-- This is an example how to use the BASE:New() constructor in a new class definition when inheriting from BASE.
--  
--     function EVENT:New()
--       local self = BASE:Inherit( self, BASE:New() ) -- #EVENT
--       return self
--     end
--       
-- @param #BASE self
-- @return #BASE
function BASE:New()
  local self = routines.utils.deepCopy( self ) -- Create a new self instance
	local MetaTable = {}
	setmetatable( self, MetaTable )
	self.__index = self
	_ClassID = _ClassID + 1
	self.ClassID = _ClassID

	
	return self
end

function BASE:_Destructor()
  --self:E("_Destructor")

  --self:EventRemoveAll()
end

function BASE:_SetDestructor()

  -- TODO: Okay, this is really technical...
  -- When you set a proxy to a table to catch __gc, weak tables don't behave like weak...
  -- Therefore, I am parking this logic until I've properly discussed all this with the community.
  --[[
  local proxy = newproxy(true)
  local proxyMeta = getmetatable(proxy)

  proxyMeta.__gc = function ()
    env.info("In __gc for " .. self:GetClassNameAndID() )
    if self._Destructor then
        self:_Destructor()
    end
  end

  -- keep the userdata from newproxy reachable until the object
  -- table is about to be garbage-collected - then the __gc hook
  -- will be invoked and the destructor called
  rawset( self, '__proxy', proxy )
  --]]
end

--- This is the worker method to inherit from a parent class.
-- @param #BASE self
-- @param Child is the Child class that inherits.
-- @param #BASE Parent is the Parent class that the Child inherits from.
-- @return #BASE Child
function BASE:Inherit( Child, Parent )
	local Child = routines.utils.deepCopy( Child )
	--local Parent = routines.utils.deepCopy( Parent )
  --local Parent = Parent
	if Child ~= nil then
		setmetatable( Child, Parent )
		Child.__index = Child
		
		Child:_SetDestructor()
	end
	--self:T( 'Inherited from ' .. Parent.ClassName ) 
	return Child
end

--- This is the worker method to retrieve the Parent class.  
-- Note that the Parent class must be passed to call the parent class method.
-- 
--     self:GetParent(self):ParentMethod()
--     
--     
-- @param #BASE self
-- @param #BASE Child is the Child class from which the Parent class needs to be retrieved.
-- @return #BASE
function BASE:GetParent( Child )
	local Parent = getmetatable( Child )
--	env.info('Inherited class of ' .. Child.ClassName .. ' is ' .. Parent.ClassName )
	return Parent
end

--- Get the ClassName + ClassID of the class instance.
-- The ClassName + ClassID is formatted as '%s#%09d'. 
-- @param #BASE self
-- @return #string The ClassName + ClassID of the class instance.
function BASE:GetClassNameAndID()
  return string.format( '%s#%09d', self.ClassName, self.ClassID )
end

--- Get the ClassName of the class instance.
-- @param #BASE self
-- @return #string The ClassName of the class instance.
function BASE:GetClassName()
  return self.ClassName
end

--- Get the ClassID of the class instance.
-- @param #BASE self
-- @return #string The ClassID of the class instance.
function BASE:GetClassID()
  return self.ClassID
end

do -- Event Handling

  --- Returns the event dispatcher
  -- @param #BASE self
  -- @return Core.Event#EVENT
  function BASE:EventDispatcher()
  
    return _EVENTDISPATCHER
  end
  
  
  --- Get the Class @{Event} processing Priority.
  -- The Event processing Priority is a number from 1 to 10, 
  -- reflecting the order of the classes subscribed to the Event to be processed.
  -- @param #BASE self
  -- @return #number The @{Event} processing Priority.
  function BASE:GetEventPriority()
    return self._Private.EventPriority or 5
  end
  
  --- Set the Class @{Event} processing Priority.
  -- The Event processing Priority is a number from 1 to 10, 
  -- reflecting the order of the classes subscribed to the Event to be processed.
  -- @param #BASE self
  -- @param #number EventPriority The @{Event} processing Priority.
  -- @return self
  function BASE:SetEventPriority( EventPriority )
    self._Private.EventPriority = EventPriority
  end
  
  --- Remove all subscribed events
  -- @param #BASE self
  -- @return #BASE
  function BASE:EventRemoveAll()
  
    self:EventDispatcher():RemoveAll( self )
    
    return self
  end
  
  --- Subscribe to a DCS Event.
  -- @param #BASE self
  -- @param Core.Event#EVENTS Event
  -- @param #function EventFunction (optional) The function to be called when the event occurs for the unit.
  -- @return #BASE
  function BASE:HandleEvent( Event, EventFunction )
  
    self:EventDispatcher():OnEventGeneric( EventFunction, self, Event )
    
    return self
  end
  
  --- UnSubscribe to a DCS event.
  -- @param #BASE self
  -- @param Core.Event#EVENTS Event
  -- @return #BASE
  function BASE:UnHandleEvent( Event )
  
    self:EventDispatcher():Remove( self, Event )
    
    return self
  end
  
  -- Event handling function prototypes
  
  --- Occurs whenever any unit in a mission fires a weapon. But not any machine gun or autocannon based weapon, those are handled by EVENT.ShootingStart.
  -- @function [parent=#BASE] OnEventShot
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs whenever an object is hit by a weapon.
  -- initiator : The unit object the fired the weapon
  -- weapon: Weapon object that hit the target
  -- target: The Object that was hit. 
  -- @function [parent=#BASE] OnEventHit
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when an aircraft takes off from an airbase, farp, or ship.
  -- initiator : The unit that tookoff
  -- place: Object from where the AI took-off from. Can be an Airbase Object, FARP, or Ships 
  -- @function [parent=#BASE] OnEventTakeoff
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when an aircraft lands at an airbase, farp or ship
  -- initiator : The unit that has landed
  -- place: Object that the unit landed on. Can be an Airbase Object, FARP, or Ships 
  -- @function [parent=#BASE] OnEventLand
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any aircraft crashes into the ground and is completely destroyed.
  -- initiator : The unit that has crashed 
  -- @function [parent=#BASE] OnEventCrash
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when a pilot ejects from an aircraft
  -- initiator : The unit that has ejected 
  -- @function [parent=#BASE] OnEventEjection
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when an aircraft connects with a tanker and begins taking on fuel.
  -- initiator : The unit that is receiving fuel. 
  -- @function [parent=#BASE] OnEventRefueling
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when an object is completely destroyed.
  -- initiator : The unit that is was destroyed. 
  -- @function [parent=#BASE] OnEvent
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when the pilot of an aircraft is killed. Can occur either if the player is alive and crashes or if a weapon kills the pilot without completely destroying the plane.
  -- initiator : The unit that the pilot has died in. 
  -- @function [parent=#BASE] OnEventPilotDead
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when a ground unit captures either an airbase or a farp.
  -- initiator : The unit that captured the base
  -- place: The airbase that was captured, can be a FARP or Airbase. When calling place:getCoalition() the faction will already be the new owning faction. 
  -- @function [parent=#BASE] OnEventBaseCaptured
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when a mission starts 
  -- @function [parent=#BASE] OnEventMissionStart
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when a mission ends
  -- @function [parent=#BASE] OnEventMissionEnd
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when an aircraft is finished taking fuel.
  -- initiator : The unit that was receiving fuel. 
  -- @function [parent=#BASE] OnEventRefuelingStop
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any object is spawned into the mission.
  -- initiator : The unit that was spawned 
  -- @function [parent=#BASE] OnEventBirth
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any system fails on a human controlled aircraft.
  -- initiator : The unit that had the failure 
  -- @function [parent=#BASE] OnEventHumanFailure
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any aircraft starts its engines.
  -- initiator : The unit that is starting its engines. 
  -- @function [parent=#BASE] OnEventEngineStartup
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any aircraft shuts down its engines.
  -- initiator : The unit that is stopping its engines. 
  -- @function [parent=#BASE] OnEventEngineShutdown
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any player assumes direct control of a unit.
  -- initiator : The unit that is being taken control of. 
  -- @function [parent=#BASE] OnEventPlayerEnterUnit
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any player relieves control of a unit to the AI.
  -- initiator : The unit that the player left. 
  -- @function [parent=#BASE] OnEventPlayerLeaveUnit
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any unit begins firing a weapon that has a high rate of fire. Most common with aircraft cannons (GAU-8), autocannons, and machine guns.
  -- initiator : The unit that is doing the shooing.
  -- target: The unit that is being targeted. 
  -- @function [parent=#BASE] OnEventShootingStart
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

  --- Occurs when any unit stops firing its weapon. Event will always correspond with a shooting start event.
  -- initiator : The unit that was doing the shooing. 
  -- @function [parent=#BASE] OnEventShootingEnd
  -- @param #BASE self
  -- @param Core.Event#EVENTDATA EventData The EventData structure.

end
 

--- Creation of a Birth Event.
-- @param #BASE self
-- @param Dcs.DCSTypes#Time EventTime The time stamp of the event.
-- @param Dcs.DCSWrapper.Object#Object Initiator The initiating object of the event.
-- @param #string IniUnitName The initiating unit name.
-- @param place
-- @param subplace
function BASE:CreateEventBirth( EventTime, Initiator, IniUnitName, place, subplace )
	self:F( { EventTime, Initiator, IniUnitName, place, subplace } )

	local Event = {
		id = world.event.S_EVENT_BIRTH,
		time = EventTime,
		initiator = Initiator,
		IniUnitName = IniUnitName,
		place = place,
		subplace = subplace
		}

	world.onEvent( Event )
end

--- Creation of a Crash Event.
-- @param #BASE self
-- @param Dcs.DCSTypes#Time EventTime The time stamp of the event.
-- @param Dcs.DCSWrapper.Object#Object Initiator The initiating object of the event.
function BASE:CreateEventCrash( EventTime, Initiator )
	self:F( { EventTime, Initiator } )

	local Event = {
		id = world.event.S_EVENT_CRASH,
		time = EventTime,
		initiator = Initiator,
		}

	world.onEvent( Event )
end

-- TODO: Complete Dcs.DCSTypes#Event structure.                       
--- The main event handling function... This function captures all events generated for the class.
-- @param #BASE self
-- @param Dcs.DCSTypes#Event event
function BASE:onEvent(event)
  --self:F( { BaseEventCodes[event.id], event } )

	if self then
		for EventID, EventObject in pairs( self.Events ) do
			if EventObject.EventEnabled then
				--env.info( 'onEvent Table EventObject.Self = ' .. tostring(EventObject.Self) )
				--env.info( 'onEvent event.id = ' .. tostring(event.id) )
				--env.info( 'onEvent EventObject.Event = ' .. tostring(EventObject.Event) )
				if event.id == EventObject.Event then
					if self == EventObject.Self then
						if event.initiator and event.initiator:isExist() then
							event.IniUnitName = event.initiator:getName()
						end
						if event.target and event.target:isExist() then
							event.TgtUnitName = event.target:getName()
						end
						--self:T( { BaseEventCodes[event.id], event } )
						--EventObject.EventFunction( self, event )
					end
				end
			end
		end
	end
end

--- Set a state or property of the Object given a Key and a Value.
-- Note that if the Object is destroyed, nillified or garbage collected, then the Values and Keys will also be gone.
-- @param #BASE self
-- @param Object The object that will hold the Value set by the Key.
-- @param Key The key that is used as a reference of the value. Note that the key can be a #string, but it can also be any other type!
-- @param Value The value to is stored in the object.
-- @return The Value set.
-- @return #nil The Key was not found and thus the Value could not be retrieved.
function BASE:SetState( Object, Key, Value )

  local ClassNameAndID = Object:GetClassNameAndID()

  self.States[ClassNameAndID] = self.States[ClassNameAndID] or {}
  self.States[ClassNameAndID][Key] = Value
  self:T2( { ClassNameAndID, Key, Value } )
  
  return self.States[ClassNameAndID][Key]
end


--- Get a Value given a Key from the Object.
-- Note that if the Object is destroyed, nillified or garbage collected, then the Values and Keys will also be gone.
-- @param #BASE self
-- @param Object The object that holds the Value set by the Key.
-- @param Key The key that is used to retrieve the value. Note that the key can be a #string, but it can also be any other type!
-- @param Value The value to is stored in the Object.
-- @return The Value retrieved.
function BASE:GetState( Object, Key )

  local ClassNameAndID = Object:GetClassNameAndID()

  if self.States[ClassNameAndID] then
    local Value = self.States[ClassNameAndID][Key] or false
    self:T2( { ClassNameAndID, Key, Value } )
    return Value
  end
  
  return nil
end

function BASE:ClearState( Object, StateName )

  local ClassNameAndID = Object:GetClassNameAndID()
  if self.States[ClassNameAndID] then
    self.States[ClassNameAndID][StateName] = nil
  end
end

-- Trace section

-- Log a trace (only shown when trace is on)
-- TODO: Make trace function using variable parameters.

--- Set trace on or off
-- Note that when trace is off, no debug statement is performed, increasing performance!
-- When Moose is loaded statically, (as one file), tracing is switched off by default.
-- So tracing must be switched on manually in your mission if you are using Moose statically.
-- When moose is loading dynamically (for moose class development), tracing is switched on by default.
-- @param #BASE self
-- @param #boolean TraceOnOff Switch the tracing on or off.
-- @usage
-- -- Switch the tracing On
-- BASE:TraceOnOff( true )
-- 
-- -- Switch the tracing Off
-- BASE:TraceOnOff( false )
function BASE:TraceOnOff( TraceOnOff )
  _TraceOnOff = TraceOnOff
end


--- Enquires if tracing is on (for the class).
-- @param #BASE self
-- @return #boolean
function BASE:IsTrace()

  if debug and ( _TraceAll == true ) or ( _TraceClass[self.ClassName] or _TraceClassMethod[self.ClassName] ) then
    return true
  else
    return false
  end
end

--- Set trace level
-- @param #BASE self
-- @param #number Level
function BASE:TraceLevel( Level )
  _TraceLevel = Level
  self:E( "Tracing level " .. Level )
end

--- Trace all methods in MOOSE
-- @param #BASE self
-- @param #boolean TraceAll true = trace all methods in MOOSE.
function BASE:TraceAll( TraceAll )
  
  _TraceAll = TraceAll
  
  if _TraceAll then
    self:E( "Tracing all methods in MOOSE " )
  else
    self:E( "Switched off tracing all methods in MOOSE" )
  end
end

--- Set tracing for a class
-- @param #BASE self
-- @param #string Class
function BASE:TraceClass( Class )
  _TraceClass[Class] = true
  _TraceClassMethod[Class] = {}
  self:E( "Tracing class " .. Class )
end

--- Set tracing for a specific method of  class
-- @param #BASE self
-- @param #string Class
-- @param #string Method
function BASE:TraceClassMethod( Class, Method )
  if not _TraceClassMethod[Class] then
    _TraceClassMethod[Class] = {}
    _TraceClassMethod[Class].Method = {}
  end
  _TraceClassMethod[Class].Method[Method] = true
  self:E( "Tracing method " .. Method .. " of class " .. Class )
end

--- Trace a function call. This function is private.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:_F( Arguments, DebugInfoCurrentParam, DebugInfoFromParam )

  if debug and ( _TraceAll == true ) or ( _TraceClass[self.ClassName] or _TraceClassMethod[self.ClassName] ) then

    local DebugInfoCurrent = DebugInfoCurrentParam and DebugInfoCurrentParam or debug.getinfo( 2, "nl" )
    local DebugInfoFrom = DebugInfoFromParam and DebugInfoFromParam or debug.getinfo( 3, "l" )
    
    local Function = "function"
    if DebugInfoCurrent.name then
      Function = DebugInfoCurrent.name
    end
    
    if _TraceAll == true or _TraceClass[self.ClassName] or _TraceClassMethod[self.ClassName].Method[Function] then
      local LineCurrent = 0
      if DebugInfoCurrent.currentline then
        LineCurrent = DebugInfoCurrent.currentline
      end
      local LineFrom = 0
      if DebugInfoFrom then
        LineFrom = DebugInfoFrom.currentline
      end
      env.info( string.format( "%6d(%6d)/%1s:%20s%05d.%s(%s)" , LineCurrent, LineFrom, "F", self.ClassName, self.ClassID, Function, routines.utils.oneLineSerialize( Arguments ) ) )
    end
  end
end

--- Trace a function call. Must be at the beginning of the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:F( Arguments )

  if debug and _TraceOnOff then
    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
  
    if _TraceLevel >= 1 then
      self:_F( Arguments, DebugInfoCurrent, DebugInfoFrom )
    end
  end  
end


--- Trace a function call level 2. Must be at the beginning of the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:F2( Arguments )

  if debug and _TraceOnOff then
    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
  
    if _TraceLevel >= 2 then
      self:_F( Arguments, DebugInfoCurrent, DebugInfoFrom )
    end
  end  
end

--- Trace a function call level 3. Must be at the beginning of the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:F3( Arguments )

  if debug and _TraceOnOff then
    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
  
    if _TraceLevel >= 3 then
      self:_F( Arguments, DebugInfoCurrent, DebugInfoFrom )
    end
  end  
end

--- Trace a function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:_T( Arguments, DebugInfoCurrentParam, DebugInfoFromParam )

	if debug and ( _TraceAll == true ) or ( _TraceClass[self.ClassName] or _TraceClassMethod[self.ClassName] ) then

    local DebugInfoCurrent = DebugInfoCurrentParam and DebugInfoCurrentParam or debug.getinfo( 2, "nl" )
    local DebugInfoFrom = DebugInfoFromParam and DebugInfoFromParam or debug.getinfo( 3, "l" )
		
		local Function = "function"
		if DebugInfoCurrent.name then
			Function = DebugInfoCurrent.name
		end

    if _TraceAll == true or _TraceClass[self.ClassName] or _TraceClassMethod[self.ClassName].Method[Function] then
      local LineCurrent = 0
      if DebugInfoCurrent.currentline then
        LineCurrent = DebugInfoCurrent.currentline
      end
  		local LineFrom = 0
  		if DebugInfoFrom then
  		  LineFrom = DebugInfoFrom.currentline
  	  end
  		env.info( string.format( "%6d(%6d)/%1s:%20s%05d.%s" , LineCurrent, LineFrom, "T", self.ClassName, self.ClassID, routines.utils.oneLineSerialize( Arguments ) ) )
    end
	end
end

--- Trace a function logic level 1. Can be anywhere within the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:T( Arguments )

  if debug and _TraceOnOff then
    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
  
    if _TraceLevel >= 1 then
      self:_T( Arguments, DebugInfoCurrent, DebugInfoFrom )
    end
  end    
end


--- Trace a function logic level 2. Can be anywhere within the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:T2( Arguments )

  if debug and _TraceOnOff then
    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
  
    if _TraceLevel >= 2 then
      self:_T( Arguments, DebugInfoCurrent, DebugInfoFrom )
    end
  end
end

--- Trace a function logic level 3. Can be anywhere within the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:T3( Arguments )

  if debug and _TraceOnOff then
    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
  
    if _TraceLevel >= 3 then
      self:_T( Arguments, DebugInfoCurrent, DebugInfoFrom )
    end
  end
end

--- Log an exception which will be traced always. Can be anywhere within the function logic.
-- @param #BASE self
-- @param Arguments A #table or any field.
function BASE:E( Arguments )

  if debug then
  	local DebugInfoCurrent = debug.getinfo( 2, "nl" )
  	local DebugInfoFrom = debug.getinfo( 3, "l" )
  	
  	local Function = "function"
  	if DebugInfoCurrent.name then
  		Function = DebugInfoCurrent.name
  	end
  
  	local LineCurrent = DebugInfoCurrent.currentline
    local LineFrom = -1 
  	if DebugInfoFrom then
  	  LineFrom = DebugInfoFrom.currentline
  	end
  
  	env.info( string.format( "%6d(%6d)/%1s:%20s%05d.%s(%s)" , LineCurrent, LineFrom, "E", self.ClassName, self.ClassID, Function, routines.utils.oneLineSerialize( Arguments ) ) )
  end
  
end



