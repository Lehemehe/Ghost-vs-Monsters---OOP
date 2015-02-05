--====================================================================--
-- scene/game/game_view.lua
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2011-2015 David McCuskey. All Rights Reserved.
-- Copyright (C) 2010 ANSCA Inc. All Rights Reserved.
--====================================================================--


--====================================================================--
--== Ghost vs Monsters : Game Main View
--====================================================================--


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "0.2.0"



--====================================================================--
--== Imports


local physics = require 'physics'

local Objects = require 'lib.dmc_corona.dmc_objects'
local StatesMixModule = require 'lib.dmc_corona.dmc_states_mix'
local Utils = require 'lib.dmc_corona.dmc_utils'

--== Components

local ObjectFactory = require 'component.object_factory'
local PauseOverlay = require 'component.pause_overlay'



--====================================================================--
--== Setup, Constants


local newClass = Objects.newClass
local ComponentBase = Objects.ComponentBase
local StatesMix = StatesMixModule.StatesMix

local LOCAL_DEBUG = true



--====================================================================--
--== Support Functions


local function DisplayReferenceFactory( name )

	if name == 'TopLeft' then
		return ComponentBase.TopLeftReferencePoint
	elseif name == 'CenterLeft' then
		return ComponentBase.CenterLeftReferencePoint
	elseif name == 'BottomLeft' then
		return ComponentBase.BottomLeftReferencePoint
	else
		return ComponentBase.TopLeftReferencePoint
	end

end

-- comma_value()
--
local function comma_value( amount )
	local formatted = amount
	while true do
		formatted, k = string.gsub( formatted, "^(-?%d+)(%d%d%d)", '%1,%2' )
		if ( k==0 ) then
			break
		end
	end

	return formatted
end



-- saveValue() --> used for saving high score, etc.

local saveValue = function( strFilename, strValue )
	-- will save specified value to specified file
	local theFile = strFilename
	local theValue = strValue

	local path = system.pathForFile( theFile, system.DocumentsDirectory )

	-- io.open opens a file at path. returns nil if no file found
	local file = io.open( path, "w+" )
	if file then
		-- write game score to the text file
		file:write( theValue )
		io.close( file )
	end
end


-- loadValue() --> load saved value from file (returns loaded value as string)

local loadValue = function( strFilename )
	-- will load specified file, or create new file if it doesn't exist

	local theFile = strFilename

	local path = system.pathForFile( theFile, system.DocumentsDirectory )

	-- io.open opens a file at path. returns nil if no file found
	local file = io.open( path, "r" )
	if file then
		-- read all contents of file into a string
		local contents = file:read( "*a" )
		io.close( file )
		return contents
	else
		-- create file b/c it doesn't exist yet
		file = io.open( path, "w" )
		file:write( "0" )
		io.close( file )
		return "0"
	end
end






--====================================================================--
--== Game Engine class
--====================================================================--


local GameView = newClass( { ComponentBase, StatesMix }, {name="Game View"} )

--== Class Constants

GameView.RIGHT_POS = 'right'
GameView.LEFT_POS = 'left'

GameView.WIN_GAME = 'win-game'
GameView.LOSE_GAME = 'lose-game'

--== State Constants

GameView.STATE_CREATE = 'state_create'
GameView.STATE_INIT = 'state_init'

GameView.TO_NEW_ROUND = 'trans_new_round'
GameView.STATE_NEW_ROUND = 'state_new_round'

GameView.TO_AIMING_SHOT = 'trans_aiming_shot'
GameView.AIMING_SHOT = 'state_aiming_shot'

GameView.TO_SHOT_IN_PLAY = 'trans_shot_in_play'
GameView.STATE_SHOT_IN_PLAY = 'state_shot_in_play'

GameView.TO_END_ROUND = 'trans_end_round'
GameView.STATE_END_ROUND = 'state_end_round'

GameView.TO_CALL_ROUND = 'trans_call_round'
GameView.STATE_END_GAME = 'state_end_game'

--== Event Constants

GameView.EVENT = 'game-view-event'

GameView.GAME_ISACTIVE = 'game-is-active'
GameView.GAME_OVER_EVENT = 'game-is-over'
GameView.GAME_EXIT_EVENT = 'game-exit'
GameView.CHARACTER_REMOVED = 'character-removed'


--======================================================--
-- Start: Setup DMC Objects

-- __init__()
--
-- one of the base methods to override for dmc_objects
-- put on our object properties
--
function GameView:__init__( params )
	--print( "GameView:__init__", params )
	self:superCall( StatesMix, '__init__', params )
	self:superCall( ComponentBase, '__init__', params )
	--==--

	--== Sanity Check

	assert( params.width and params.height, "Game View requires params 'width' & 'height'")
	assert( params.level_data==nil or type(params.level_data)=='table', "Game View wrong type for 'level_data'")

	--== Properties

	self._width = params.width
	self._height = params.height

	self._level_data = params.level_data
	self.__game_is_active = false	-- our saved value

	self._screen_position = ""	-- "left" or "right"

	-- if we are panning the scene
	self._is_panning = false

	self.lifeIcons = {}
	self.__game_lives = 0
	self._enemy_count = 0

	self.__best_score = -1
	self.__game_score = -1

	self._sound_mgr = gService.sound_mgr

	--== Display Groups

	self._dg_game = nil -- all game items items
	self._dg_overlay = nil -- all game items items

	-- DG Game items
	self._dg_bg = nil -- background items
	self._dg_ph_bg = nil -- physics background items
	self._dg_shot = nil -- shot feedback items
	self._dg_ph_game = nil -- physics game items
	self._dg_ph_fore = nil -- physics foreground items
	self._dg_ph_trail = nil -- physics foreground items

	--== Display Objects

	self._shot_orb = nil
	self._shot_arrow = nil

	self._character = nil
	self._character_f = nil

	self._pause_overlay = nil
	self._pause_overlay_f = nil

	self._txt_continue = nil
	self._continueTextTimer = nil

	self._txt_score = nil

	self._trackingTimer = nil

	-- start physics engine here, so it doesn't crash
	self:_startPhysics( true )
	physics.setDrawMode( "normal" )	-- set to "normal" "debug" or "hybrid" to see collision boundaries
	physics.setGravity( 0, 11 )	--> 0, 9.8 = Earth-like gravity

	self:setState( GameView.STATE_CREATE )
end

function GameView:_undoInit()

	if self._character ~= nil then
		self._character = nil
	end
	if self._continueTextTimer then
		timer.cancel( self._continueTextTimer )
		self._continueTextTimer = nil
	end
	if self._trackingTimer then
		timer.cancel( self._trackingTimer )
		self._trackingTimer = nil
	end

	self.level_data = nil -- setter

	--==--
	self:superCall( '__undoCreateView__' )
end



-- __createView__()
--
-- one of the base methods to override for dmc_objects
--
function GameView:__createView__()
	--print( "GameView:__createView__" )
	self:superCall( '__createView__' )
	--==--
	local W, H = self._width , self._height
	local H_CENTER, V_CENTER = W*0.5, H*0.5
	local H_MARGIN, V_MARGIN = 15, 10

	local dg, o, tmp

	-- setup display primer

	o = display.newRect( 0, 0, W, 10)
	o.anchorX, o.anchorY = 0, 0
	o:setFillColor(0,0,0,0)
	if LOCAL_DEBUG then
		o:setFillColor(1,0,0,0.75)
	end
	o.x, o.y = 0, 0

	self:insert( o )
	self._primer = o

	-- main game group

	o = display.newGroup()
	self:insert( o )
	self._dg_game = o

	-- overlay group

	o = display.newGroup()
	self:insert( o )
	self._dg_overlay = o


	dg = self._dg_game -- temp for display group

	-- background items group

	o = display.newGroup()
	dg:insert( o )
	self._dg_bg = o

	-- physics background items
	o = display.newGroup()
	dg:insert( o )
	self._dg_ph_bg = o

	-- shot feedback items

	o = display.newGroup()
	dg:insert( o )
	self._dg_shot = o

	self:_createShotFeedback()

	-- physics game items

	o = display.newGroup()
	dg:insert( o )
	self._dg_ph_game = o

	-- TODO:
	-- self:_createPhysicsGameItems()

	-- physics forground game items

	o = display.newGroup()
	dg:insert( o )
	self._dg_ph_fore = o

	-- TODO:
	-- self:_createPhysicsForegroundItems()

	-- physics trailgroup items

	o = display.newGroup()
	dg:insert( o )
	self._dg_ph_trail = o

	--== Setup Overlay Items

	dg = self._dg_overlay -- temp for display group

	-- score display

	o = display.newText( "0", 470, 22, "Helvetica-Bold", 52 )
	o:setTextColor( 1,1,1,1 )	--> white
	o.xScale, o.yScale = 0.5, 0.5  --> for clear retina display text

	dg:insert( o )
	self._txt_score = o

	-- "tap to continue" display

	o = display.newText( "TAP TO CONTINUE", 240, 18, "Helvetica", 36 )
	o.anchorX, o.anchorY = 0.5, 0
	o:setTextColor( 249/255, 203/255, 64/255 )
	o.xScale, o.yScale = 0.5, 0.5
	o.x, o.y = H_CENTER, V_MARGIN

	dg:insert( o )
	self._txt_continue = o

	-- pause button overlay

	o = PauseOverlay:new{
		width=W, height=H
	}
	o.x, o.y = H_CENTER, 0

	dg:insert( o.view )
	self._pause_overlay = o

end

function GameView:__undoCreateView__()
	print( "GameView:__undoCreateView__" )

	local obj, group
	local layer = self.layer
	local gameGroup = layer.gameGroup

	-- Game Details HUD
	self:_removeGameDetailsHUD()
	gameGroup:remove( layer.details )

	-- Tracking Group
	group = layer.trailGroup
	for i = group.numChildren, 1, -1 do
		group:remove( i )
	end
	gameGroup:remove( layer.trailGroup )

	-- physics forground items
	self:_removeDataItems( layer.physicsBackgroundGroup, { is_physics=true } )
	gameGroup:remove( layer.physicsBackgroundGroup )

	-- physics game group
	self:_removeDataItems( layer.physicsGameGroup, { is_physics=true } )
	gameGroup:remove( layer.physicsGameGroup )

	-- shot feedback items
	group = layer.shot
	for i = group.numChildren, 1, -1 do
		group:remove( i )
	end
	gameGroup:remove( layer.shot )

	-- physics background items
	self:_removeDataItems( layer.physicsBackgroundGroup, { is_physics=true } )
	gameGroup:remove( layer.physicsBackgroundGroup )

	-- background items
	self:_removeDataItems( layer.backgroundGroup )
	gameGroup:remove( layer.backgroundGroup )

	layer.gameGroup:removeSelf()

	--==--
	self:superCall( '__undoCreateView__' )
end


-- __initComplete__()
--
function GameView:__initComplete__()
	print( "GameView:__initComplete__" )
	self:superCall( '__initComplete__' )
	--==--
	local o, f

	f = self:createCallback( self._ghostEvent_handler )
	self._character_f = f

	o = self._pause_overlay
	f = self:createCallback( self._pauseOverlayEvent_handler )
	o:addEventListener( o.EVENT, f )
	self._pause_overlay_f = f

	-- self.level_data = self._level_data -- setter

	self:_pausePhysics()

	Runtime:addEventListener( 'touch', self )
	Runtime:addEventListener( 'enterFrame', self )
end
function GameView:__undoInitComplete__()
	--print( "GameView:__undoInitComplete__" )
	Runtime:removeEventListener( 'touch', self )
	Runtime:removeEventListener( 'enterFrame', self )

	self:_stopPhysics()
	--==--
	self:superCall( '__undoCreateView__' )
end

-- END: Setup DMC Objects
--======================================================--



--====================================================================--
--== Public Methods


function GameView:startGamePlay()
	print( "GameView:startGamePlay" )
	self:gotoState( GameView.STATE_INIT )
end
function GameView:pauseGamePlay()
	print( "GameView:pauseGamePlay" )
	self._game_is_active = false -- setter
end



--====================================================================--
--== Private Methods


--== Getters / Setters ==--


-- _best_score
--
function GameView.__getters:_best_score()
	local bestScoreFilename = self._level_data.info.restartLevel .. ".data"
	if self.__best_score == -1 then
		self.__best_score = tonumber( loadValue( bestScoreFilename ) )
	end
	return self.__best_score
end
function GameView.__setters:_best_score( value )
	assert( type(value)=='number' )
	--==--
	if value < self.__best_score then return end

	local bestScoreFilename = self._level_data.info.restartLevel .. ".data"

	-- clean up value
	if value < 0 then value = 0 end
	self.__best_score = value

	saveValue( bestScoreFilename, tostring( self._best_score ) )
end



-- getter/setter: _game_score
--
function GameView.__getters:_game_score()
	return self.__game_score
end
function GameView.__setters:_game_score( value )
	assert( type(value)=='number' )
	--==--
	if self.__game_score == value then return end

	local W, H = self._width , self._height
	local H_CENTER, V_CENTER = W*0.5, H*0.5
	local H_MARGIN, V_MARGIN = 15, 10

	if value < 0 then value = 0 end
	self.__game_score = value

	-- update scoreboard
	local o = self._txt_score
	o.text = comma_value( value )
	o.anchorX, o.anchorY = 1, 0
	o.x, o.y = W-H_MARGIN, V_MARGIN
end


-- _game_lives
--
function GameView.__getters:_game_lives()
	return self.__game_lives
end
function GameView.__setters:_game_lives( value )

	-- clean up value
	if value < 0 then value = 0 end
	self.__game_lives = value

	-- update icons
	for i, item in ipairs( self.lifeIcons ) do
		if i > self.__game_lives then
			item.alpha = 0.3
		end
	end
end


-- _game_is_active
--
function GameView.__getters:_game_is_active()
	return self.__game_is_active
end
function GameView.__setters:_game_is_active( value )
	assert( type(value)=='boolean', "wrong type for game is active")
	--==--
	if self.__game_is_active == value then return end

	self.__game_is_active = value

	if value == true then
		self:_startPhysics()
	else
		self:_pausePhysics()
	end

	self:dispatchEvent( GameView.GAME_ISACTIVE, {value=value} )
end


-- getter/setter: _text_is_blinking()
--
function GameView.__getters:_text_is_blinking()
	return ( self._continueTextTimer ~= nil )
end
function GameView.__setters:_text_is_blinking( value )
	--print("GameView.__setters:_text_is_blinking")

	local o = self._txt_continue

	-- stop any flashing currently happening
	if self._continueTextTimer ~= nil then
		timer.cancel( self._continueTextTimer )
		self._continueTextTimer = nil
	end

	if not value then
		o.isVisible = false
	else
		local continueBlink = function()

			local startBlinking = function()
				o.isVisible = not o.isVisible
			end
			self._continueTextTimer = timer.performWithDelay( 350, startBlinking, 0 )
		end
		timer.performWithDelay( 300, continueBlink, 1 )
	end

end


--== Methods ==--

-- _addDataItems()
--
-- loop through game data items and put on stage
--
function GameView:_addDataItems( data, group, params )
	print( "GameView:_addDataItems" )
	params = params or {}
	if params.is_physics==nil then params.is_physics=false end
	--==--

	local is_physics = params.is_physics
	local o, d

	for _, item in ipairs( data ) do
		print( _, item.name, item )
		-- item is one of the entries in our data file

		-- most of the creation magic happens in this line
		-- game objects are created from level data entries
		o = ObjectFactory.create( item.name, {game_engine=self} )
		assert( o, "object not created" )

		-- process attributes found in the level data
		if item.reference then
			o.anchorX, o.anchorY = unpack( DisplayReferenceFactory( item.reference )  )
		end
		-- TODO: process special properties and layer the rest
		if item.rotation then o.rotation = item.rotation end
		if item.alpha then o.alpha = item.alpha end
		if item.x then o.x = item.x end
		if item.y then o.y = item.y end

		-- add new object to the display group and physics engine
		d = o
		if o.view then
			-- type is of dmc_object
			d = o.view
		elseif o.display then
			d = o.display
		end
		if is_physics then
			physics.addBody( d, o.physicsType, o.physicsProperties )
		end
		group:insert( d )

		-- count enemies being place on screen
		if o.myName == self._level_data.info.enemyName then
			self._enemy_count = self._enemy_count + 1
			o:addEventListener( o.UPDATE_EVENT, self )
		end
	end

end

-- _removeDataItems()
--
-- loop through display groups and remove their items
--
function GameView:_removeDataItems( group, params )
	print( "GameView:_removeDataItems" )
	local params = params or {}
	if params.is_physics==nil then params.is_physics=false end
	--==--

	local is_physics = params.is_physics
	local o, d

	for i = group.numChildren, 1, -1 do
		o = group[ i ]
		-- TODO: make this a little cleaner. need API for it

		o = getDMCObject( o )
		-- if o.__dmcRef then
		-- 	o = o.__dmcRef
		-- end
		if is_physics then
			d = o
			if o.isa ~= nil and o:isa( CoronaBase ) then
				d = o.display
			end
			if physics.removeBody and not physics.removeBody( d ) then
				print( "\n\nERROR: COULD NOT REMOVE BODY FROM PHYSICS ENGINE\n\n")
			end
		end
		if o.myName ~= self._level_data.info.enemyName then
			o:removeSelf()
		else
			o:removeEventListener( o.UPDATE_EVENT, self )
			-- let the character know that GE is done, can remove itself
			-- self:dispatchEvent( GameView.CHARACTER_REMOVED, {item=o} )
		end
	end

end



-- _createBackground()
--
function GameView:_createBackgroundItems()
	local data = self._level_data.backgroundItems
	if data then
		self:_addDataItems( data, self._dg_bg )
	end
end
function GameView:_destroyBackgroundItems()
	self:_removeDataItems( self._dg_bg )
end

-- _createPhysicsBackgroundItems()
--
function GameView:_createPhysicsBackgroundItems()
	local data = self._level_data.physicsBackgroundItems
	if data then
		self:_addDataItems( data, self._dg_ph_bg, {is_physics=true} )
	end
end
function GameView:_destroyPhysicsBackgroundItems()
	self:_removeDataItems( self._dg_bg, {is_physics=true} )
end

-- _createPhysicsGameItems()
--
function GameView:_createPhysicsGameItems()
	local data = self._level_data.physicsGameItems
	if data then
		self:_addDataItems( data, self._dg_ph_game, {is_physics=true} )
	end
end
function GameView:_destroyPhysicsGameItems()
	self:_removeDataItems( self._dg_ph_game, {is_physics=true} )
end


-- _createPhysicsForegroundItems()
--
function GameView:_createPhysicsForegroundItems()
	if self._level_data.physicsForgroundItems then
		self:_addDataItems( self._level_data.physicsForgroundItems, self.layer.physicsForegroundGroup, { is_physics=true } )
	end
end


-- _createLevelObjects()
--
function GameView:_createLevelObjects()

	-- cleanup
	self:_destroyLevelObjects()

	self:_createBackgroundItems()
	self:_createPhysicsBackgroundItems()
	-- self:_createPhysicsGameItems()
	-- self:_createPhysicsForegroundItems()

end

-- _destroyLevelObjects()
--
function GameView:_destroyLevelObjects()
	-- self:_destroyPhysicsForegroundItems()
	-- self:_destroyPhysicsGameItems()
	self:_destroyPhysicsBackgroundItems()
	self:_destroyBackgroundItems()
end





-- _createShotFeedback()
--
function GameView:_createShotFeedback()
	local dg = self._dg_shot
	local o

	-- shot orb
	o = display.newImageRect( 'assets/game_objects/orb.png', 96, 96 )
	o.xScale, o.yScale = 1.0, 1.0
	o.isVisible = false
	o.alpha = 0.75

	dg:insert( o )
	self._shot_orb = o

	-- shot arrow
	o = display.newImageRect( 'assets/game_objects/arrow.png', 240, 240 )
	o.x, o.y = 150, 195
	o.isVisible = false

	dg:insert( o )
	self._shot_arrow = o
end




-- _panCamera()
--
-- direction, string 'left'/'right'
-- duration, number of milliseconds
-- params, table of options
-- - callback
-- - transition
--
function GameView:_panCamera( direction, duration, params )
	--print( "GameView:_panCamera" )
	local params = params or {}
	--==--
	local dg, f, p
	local xvalue

	if direction == 'left' then
		xvalue = 0
	else
		xvalue = -480
	end

	self._is_panning = true

	dg = self._dg_game
	f = function()
		local cb = params.callback
		self._is_panning = false
		self._screen_position = direction
		if cb then cb() end
	end
	p = {
		time=duration,
		x=xvalue,
		transition=params.transition,
		onComplete=f
	}
	transition.to( dg, p )

end


function GameView:_startPhysics( param )
	--print( "GameView:_startPhysics" )
	self.physicsIsActive = true
	physics.start( param )
end

function GameView:_pausePhysics()
	--print( "GameView:_pausePhysics" )
	self.physicsIsActive = false
	physics.pause()
end

function GameView:_stopPhysics()
	--print( "GameView:_stopPhysics" )
	self.physicsIsActive = false
	physics.stop()
end



--== Game Character Creation and Event Handlers ==--

function GameView:_createGhost()
	--print( "GameView:_createGhost" )
	local dg, o, item

	dg = self._dg_ph_fore
	item = self._level_data.info.characterName
	o = ObjectFactory.create( item, {game_engine=self} )

	dg:insert( o.view )
	self._character = o

	o:addEventListener( o.EVENT, self._character_f )

	-- TODO: move to ghost
	physics.addBody( o.view, o.physicsType, o.physicsProperties )
	o.isBodyActive = false

	return o
end

function GameView:_destroyGhost()
	print( "GameView:_destroyGhost" )
	local o

	o = self._character

	assert( physics.removeBody( o.view ) )
	o:removeEventListener( o.EVENT, self._character_f )

	o:removeSelf()
	self._character = nil
end



-- _createGameDetailsHUD()
--
function GameView:_createGameDetailsHUD()

	local W, H = self._width , self._height
	local H_CENTER, V_CENTER = W*0.5, H*0.5

	local dg, o, tmp

	local dg = self._dg_overlay
	local hudRefs = self.hudRefs
	local o

	-- TWO BLACK RECTANGLES AT TOP AND BOTTOM (for those viewing from iPad)
	img = display.newRect( 0, -160, 480, 160 )
	img:setFillColor( 0, 0, 0, 255 )
	dg:insert( img )

	img = display.newRect( 0, 320, 480, 160 )
	img:setFillColor( 0, 0, 0, 255 )
	dg:insert( img )


	-- LIVES DISPLAY
	local y_base = 18
	local x_offset = 25
	local prev

	o = ObjectFactory.create( "life-icon" )
	o.x = 20; o.y = y_base
	dg:insert( o )
	table.insert( self.lifeIcons, img )
	prev = img

	img = ObjectFactory.create( "life-icon" )
	img.x = prev.x + x_offset; img.y = y_base
	dg:insert( img )
	table.insert( self.lifeIcons, img )
	prev = img

	img = ObjectFactory.create( "life-icon" )
	img.x = prev.x + x_offset; img.y = y_base
	dg:insert( img )
	table.insert( self.lifeIcons, img )
	prev = img

	img = ObjectFactory.create( "life-icon" )
	img.x = prev.x + x_offset; img.y = y_base
	dg:insert( img )
	table.insert( self.lifeIcons, img )



end

function GameView:_removeGameDetailsHUD()

	local hudRefs = self.hudRefs
	local group = self.layer.details
	local o

	-- Pause Button HUD
	o = hudRefs[ "pause-hud" ]
	hudRefs[ "pause-hud" ] = nil
	o:removeEventListener( "change", Utils.createObjectCallback( self, self.pauseScreenTouchHandler ) )
	--obj:removeSelf() TODO: after removeSelf is done in pause hud
	o:removeSelf()

	-- continue text
	o = self._txt_continue
	o:removeSelf()
	self._txt_continue = nil

	-- score text
	o = self._txt_score
	o:removeSelf()
	self._txt_score= nil


	-- life icons
	local t = self.lifeIcons
	for i = #t, 1, -1 do
		t[i]:removeSelf()
		table.remove( t, i )
	end
	self.lifeIcons = nil

	-- black rectangles
	for i = group.numChildren, 1, -1 do
		group:remove( i )
	end

end



--======================================================--
-- START: STATE MACHINE

--== State Create ==--

function GameView:state_create( next_state, params )
	print( "GameView:state_create: >> ", next_state )
	if next_state == GameView.STATE_INIT then
		self:do_state_init( params )
	else
		print( "[WARNING] GameView::state_create : " .. tostring( next_state ) )
	end
end


--== State Init ==--

function GameView:do_state_init( params )
	print( "GameView:do_state_init" )
	-- params = params or {}
	--==--
	self:setState( GameView.STATE_INIT )

	self:_createLevelObjects()

	self._game_is_active = true

	self._game_lives = 4 -- DEBUG
	self._game_score = 0

	self._dg_game.x = -480
	self._screen_position = GameView.RIGHT_POS

	self._pause_overlay.isVisible = false
	self._text_is_blinking = false

	self:gotoState( GameView.TO_NEW_ROUND )
end

function GameView:state_init( next_state, params )
	print( "GameView:state_init: >> ", next_state )
	if next_state == GameView.TO_NEW_ROUND then
		self:do_trans_new_round( params )
	else
		print( "[WARNING] GameView::state_create : " .. tostring( next_state ) )
	end
end


--== State To New Round ==--

function GameView:do_trans_new_round( params )
	print( "GameView:do_trans_new_round" )
	-- params = params or {}
	--==--
	self:setState( GameView.TO_NEW_ROUND )

	local step1, step2

	step1 = function( e )
		-- pan camera to left
		self:_panCamera( GameView.LEFT_POS, 1000, { callback=step2, transition=easing.inOutExpo } )
	end

	step2 = function( e )

		self._screen_position = GameView.LEFT_POS

		-- create new ghost
		local o = self:_createGhost()
		o:toBack()

		self._sound_mgr:play( self._sound_mgr.NEW_ROUND )
	end

	timer.performWithDelay( 1000, step1, 1 )
end

function GameView:trans_new_round( next_state, params )
	print( "GameView:trans_new_round: >> ", next_state )
	if next_state == GameView.STATE_NEW_ROUND then
		self:do_state_new_round( params )
	else
		print( "[WARNING] GameView::trans_new_round : " .. tostring( next_state ) )
	end
end


--== State New Round ==--

function GameView:do_state_new_round( params )
	print( "GameView:do_state_new_round" )
	-- params = params or {}
	--==--
	self:setState( GameView.STATE_NEW_ROUND )

	self._pause_overlay.isVisible = true
	self._character:toFront()
end

function GameView:state_new_round( next_state, params )
	print( "GameView:state_new_round: >> ", next_state )
	if next_state == GameView.TO_AIMING_SHOT then
		self:do_trans_aiming_shot( params )
	else
		print( "[WARNING] GameView::state_new_round : " .. tostring( next_state ) )
	end
end


--== State To Aiming Shot ==--

function GameView:do_trans_aiming_shot( params )
	print( "GameView:do_trans_aiming_shot" )
	-- params = params or {}
	--==--
	local orb = self._shot_orb
	local arrow = self._shot_arrow
	local char = self._character

	self:setState( GameView.TO_AIMING_SHOT )

	-- orb stuff
	orb.x, orb.y = char.x, char.y
	orb.xScale, orb.yScale = 0.1, 0.1
	orb.isVisible = true

	-- arrow stuff
	arrow.isVisible = true

	self:gotoState( GameView.AIMING_SHOT )
end

function GameView:trans_aiming_shot( next_state, params )
	print( "GameView:trans_aiming_shot: >> ", next_state )
	if next_state == GameView.AIMING_SHOT then
		self:do_state_aiming_shot( params )
	else
		print( "[WARNING] GameView::trans_aiming_shot : " .. tostring( next_state ) )
	end
end


--== State Aiming Shot ==--

function GameView:do_state_aiming_shot( params )
	print( "GameView:do_state_aiming_shot" )
	-- params = params or {}
	self:setState( GameView.AIMING_SHOT )
	self:dispatchEvent( GameView.AIMING_SHOT )
end
function GameView:state_aiming_shot( next_state, params )
	print( "GameView:state_aiming_shot: >> ", next_state )
	if next_state == GameView.TO_SHOT_IN_PLAY then
		self:do_trans_shot_in_play( params )
	else
		print( "[WARNING] GameView::state_aiming_shot : " .. tostring( next_state ) )
	end
end


--== State To Shot In Play ==--

function GameView:do_trans_shot_in_play( params )
	print( "GameView:do_trans_shot_in_play" )
	params = params or {}
	assert( params.shot )
	--==--
	local orb = self._shot_orb

	self:setState( GameView.TO_SHOT_IN_PLAY )
	self._sound_mgr:play( self._sound_mgr.BLAST_OFF )

	local step1 = function()
		self:gotoState( GameView.STATE_SHOT_IN_PLAY, params )
	end
	transition.to( orb, { time=175, xScale=0.1, yScale=0.1, onComplete=step1 })

end
function GameView:trans_shot_in_play( next_state, params )
	print( "GameView:trans_shot_in_play: >> ", next_state )
	if next_state == GameView.STATE_SHOT_IN_PLAY then
		self:do_state_shot_in_play( params )
	else
		print( "[WARNING] GameView::trans_shot_in_play : " .. tostring( next_state ) )
	end
end


--== State Shot In Play ==--

function GameView:do_state_shot_in_play( params )
	print( "GameView:do_state_shot_in_play" )
	params = params or {}
	assert( params.shot )
	--==--
	local orb = self._shot_orb
	local arrow = self._shot_arrow
	local char = self._character
	local shot = params.shot

	self:setState( GameView.STATE_SHOT_IN_PLAY )

	-- remove aiming feedback
	orb.isVisible = false
	arrow.isVisible = false

	char:applyForce( shot.xForce, shot.yForce, char.x, char.y )

	self._pause_overlay.isVisible = false

end
function GameView:state_shot_in_play( next_state, params )
	print( "GameView:state_shot_in_play: >> ", next_state )
	if next_state == GameView.TO_END_ROUND then
		self:do_trans_end_round( params )
	else
		print( "[WARNING] GameView::state_shot_in_play : " .. tostring( next_state ) )
	end
end


--== State To End Round ==--

function GameView:do_trans_end_round( params )
	print( "GameView:do_trans_end_round" )
	--==--
	self:setState( GameView.TO_END_ROUND )

	-- remove the character, after delay
	timer.performWithDelay( 1, function() self:_destroyGhost() end)
	-- self:_destroyGhost()
	-- self._character = nil

	local cb = function() self:gotoState( GameView.STATE_END_ROUND ) end

	-- move camera to see what we've done
	self:_panCamera( GameView.RIGHT_POS, 500, {callback=cb} )

end
function GameView:trans_end_round( next_state, params )
	print( "GameView:trans_end_round: >> ", next_state )
	if next_state == GameView.STATE_END_ROUND then
		self:do_state_end_round( params )
	else
		print( "[WARNING] GameView::trans_end_round : " .. tostring( next_state ) )
	end
end


--== State End Round ==--

function GameView:do_state_end_round( params )
	print( "GameView:do_state_end_round" )
	--==--
	self:setState( GameView.STATE_END_ROUND )

	self._text_is_blinking = true
end
function GameView:state_end_round( next_state, params )
	print( "GameView:state_end_round: >> ", next_state )
	if next_state == GameView.TO_CALL_ROUND then
		self:do_trans_call_round( params )
	else
		print( "[WARNING] GameView::state_end_round : " .. tostring( next_state ) )
	end
end


--== State To Call Round ==--

function GameView:do_trans_call_round( params )
	print( "GameView:do_trans_call_round" )
	--==--
	self:setState( GameView.TO_CALL_ROUND )

	self._text_is_blinking = false

	print( self._enemy_count, self._game_lives)
	if self._enemy_count == 0 then
		-- WIN
		timer.performWithDelay( 200, function() self:gotoState( GameView.STATE_END_GAME, {result=GameView.WIN_GAME} ) end, 1 )

	elseif self._enemy_count > 0 and self._game_lives == 0 then
		-- LOSE
		timer.performWithDelay( 200, function() self:gotoState( GameView.STATE_END_GAME, {result=GameView.LOSE_GAME} ) end, 1 )

	else
		-- NEXT ROUND
		timer.performWithDelay( 200, function() self:gotoState( GameView.TO_NEW_ROUND ) end, 1 )
	end

end
function GameView:trans_call_round( next_state, params )
	print( "GameView:trans_call_round: >> ", next_state )
	if next_state == GameView.STATE_END_GAME then
		self:do_state_end_game( params )
	else
		print("[WARNING] GameView::trans_call_round : " .. tostring( next_state ) )
	end
end


--== State End Game ==--

function GameView:do_state_end_game( params )
	print( "GameView:do_state_end_game" )
	params = params or {}
	assert( params.result )
	--==--
	self:setState( GameView.STATE_END_GAME )

	-- Give score bonus depending on how many ghosts left
	local ghostBonus = self._game_lives * 20000
	self._game_score = self._game_score + ghostBonus

	self._best_score = self._game_score

	self._pause_overlay.isVisible = false
	self._txt_continue.isVisible = false
	self._txt_score.isVisible = false

	-- stop game action, dispatches event
	self._game_is_active = false

	local data = {
		outcome = params.result,
		score = self._game_score,
		best_score = self._best_score,
	}
	self:dispatchEvent( GameView.GAME_OVER_EVENT, data )

end
function GameView:state_end_game( next_state, params )
	print( "GameView:state_end_game: >> ", next_state )
	if next_state == GameView.STATE_INIT then
		self:do_state_init( params )
	else
		print( "[WARNING] GameView::state_end_game : " .. tostring( next_state ) )
	end
end

-- END: STATE MACHINE
--======================================================--



function GameView:isTrackingCharacter( value )
	--print("GameView:isTrackingCharacter " .. tostring( value ))

	local trailGroup = self.layer.trailGroup

	if value then
		-- clear the last trail
		for i = trailGroup.numChildren,1,-1 do
			local child = trailGroup[i]
			child.parent:remove( child )
			child = nil
		end

		-- start making new dots
		local startDots = function()
			local odd = true
			local char = self._character
			local dotTimer

			local createDot = function()
				local trailDot
				local size = ( odd and 1.5 ) or 2.5
				trailDot = display.newCircle( trailGroup, char.x, char.y, size )
				trailDot:setFillColor( 255, 255, 255, 255 )

				--trailGroup:insert( trailDot )
				odd = not odd
			end

			self._trackingTimer = timer.performWithDelay( 50, createDot, 50 )
		end
		startDots()

	else
		if self._trackingTimer then timer.cancel( self._trackingTimer ) end
	end
end



--====================================================================--
--== Event Handlers

function GameView:_ghostEvent_handler( event )
	print( "GameView:_ghostEvent_handler", event.type )
	local target = event.target

	if event.type == target.STATE_BORN then
		-- pass

	elseif event.type == target.STATE_LIVING then
		self:gotoState( GameView.STATE_NEW_ROUND )

	elseif event.type == target.STATE_FLYING then
		self:isTrackingCharacter( true )

	elseif event.type == target.STATE_HIT then
		self._game_score = self._game_score + 500
		self:isTrackingCharacter( false )

	elseif event.type == target.STATE_DYING then
		self._game_lives = self._game_lives - 1

	elseif event.type == target.STATE_DEAD then

		-- if physics.removeBody and not physics.removeBody( target.display ) then
		-- 	print( "\n\nERROR: COULD NOT REMOVE BODY FROM PHYSICS ENGINE\n\n")
		-- end
		-- timer.performWithDelay( 1, function() self:_destroyGhost() end)
		-- self:_destroyGhost()

		-- target:removeEventListener( target.UPDATE_EVENT, self )
		-- self._character = nil

		-- -- let the character know that GE is done, can remove itself
		-- self:dispatchEvent( GameView.CHARACTER_REMOVED, {item=target} )
		self:gotoState( GameView.TO_END_ROUND )

	else
		print("WARNING: GameView:_ghostEvent_handler", event.type )
	end


end

function GameView:characterUpdateEvent( event )
	--print( "GameView:characterUpdateEvent " .. event.type )
	local target = event.target
	local mCeil = math.ceil

	-- Process Ghost
	if target.myName == self._level_data.info.characterName then

		if event.type == target.STATE_LIVING then
			self:gotoState( GameView.STATE_NEW_ROUND )

		elseif event.type == target.STATE_FLYING then
			self:isTrackingCharacter( true )

		elseif event.type == target.STATE_HIT then
			self._game_score = self._game_score + 500
			self:isTrackingCharacter( false )

		elseif event.type == target.STATE_DYING then
			self._game_lives = self._game_lives - 1

		elseif event.type == target.STATE_DEAD then

			if physics.removeBody and not physics.removeBody( target.display ) then
				print( "\n\nERROR: COULD NOT REMOVE BODY FROM PHYSICS ENGINE\n\n")
			end
			target:removeEventListener( target.UPDATE_EVENT, self )
			self._character = nil

			-- let the character know that GE is done, can remove itself
			self:dispatchEvent( GameView.CHARACTER_REMOVED, {item=target} )
			self:gotoState( GameView.TO_END_ROUND )

		end

		return true

	-- Process Monster
	elseif target.myName == self._level_data.info.enemyName then

		if event.type == target.STATE_LIVING then
			self:setState( GameView.STATE_NEW_ROUND )

		elseif event.type == target.STATE_DEAD then

			self._enemy_count = self._enemy_count - 1

			local newScore = self._game_score + mCeil( 5000 * event.force )
			self._game_score = newScore

			target:removeEventListener( target.UPDATE_EVENT, self )

			if physics.removeBody and not physics.removeBody( target.display ) then
				print( "\n\nERROR: COULD NOT REMOVE BODY FROM PHYSICS ENGINE\n\n")
			end

			-- let the character know that GE is done, can remove itself
			self:dispatchEvent( GameView.CHARACTER_REMOVED, {item=target} )
		end

		return true
	end
end



function GameView:_pauseOverlayEvent_handler( event )
	print( "GameView:_pauseOverlayEvent_handler" )
	local target = event.target

	if event.type == target.ACTIVE then
		-- in this sense, "active" means "pause is activated"
		local pause_is_active = event.is_active
		self._game_is_active = ( not pause_is_active )

	elseif event.type == target.MENU then
		self:_stopPhysics()
		self:dispatchEvent( GameView.GAME_EXIT_EVENT )

	end
end




function GameView:touch( event )
	print( "GameView:touch", event.phase )

	local mCeil = math.ceil
	local mAtan2 = math.atan2
	local mPi = math.pi
	local mSqrt = math.sqrt

	local phase = event.phase
	local x, xStart = event.x, event.xStart
	local y, yStart = event.y, event.yStart

	local curr_state = self:getState()
	print( curr_state)

	local ghostObject = self._character

	--== TOUCH HANDLING, active game
	if self._game_is_active then
		-- BEGINNING OF AIM
		if phase == 'began' and curr_state == GameView.STATE_NEW_ROUND and xStart > 115 and xStart < 180 and yStart > 160 and yStart < 230 and self._screen_position == GameView.LEFT_POS then

			self:gotoState( GameView.TO_AIMING_SHOT )

		-- RELEASE THE DUDE
		elseif phase == 'ended' and curr_state == GameView.AIMING_SHOT then

			local x = event.x
			local y = event.y
			local xF = (-1 * (x - ghostObject.x)) * 2.15	--> 2.75
			local yF = (-1 * (y - ghostObject.y)) * 2.15	--> 2.75

			local data = { xForce=xF, yForce=yF  }
			self:gotoState( GameView.TO_SHOT_IN_PLAY, {shot=data} )

		-- SWIPE SCREEN
		elseif phase == 'ended' and curr_state == GameView.STATE_NEW_ROUND and not self._is_panning then

			local newPosition, diff

			-- check which direction we're swiping
			if event.xStart > event.x then
				newPosition = GameView.RIGHT_POS
			elseif event.xStart < event.x then
				newPosition = GameView.LEFT_POS
			end

			-- update screen
			if newPosition == GameView.RIGHT_POS and self._screen_position == "left" then
				diff = event.xStart - event.x
				if diff >= 100 then
					self:_panCamera( newPosition, 700 )
				else
					self:_panCamera( self._screen_position, 100 )
				end
			else
				diff = event.x - event.xStart
				if diff >= 100 then
					self:_panCamera( newPosition, 700 )
				else
					self:_panCamera( self._screen_position, 100 )
				end
			end

		-- PROCESS TAP during "Tap To Continue"
		elseif phase == 'ended' and curr_state == GameView.STATE_END_ROUND then
			self:gotoState( GameView.TO_CALL_ROUND )

		end
	end


	--== AIMING ORB and ARROW

	if curr_state == GameView.AIMING_SHOT then

		local orb = self._shot_orb
		local arrow = self._shot_arrow

		local xOffset = ghostObject.x
		local yOffset = ghostObject.y

		-- Formula math.sqrt( ((event.y - yOffset) ^ 2) + ((event.x - xOffset) ^ 2) )
		local distanceBetween = mCeil(mSqrt( ((event.y - yOffset) ^ 2) + ((event.x - xOffset) ^ 2) ))

		orb.xScale = -distanceBetween * 0.02
		orb.yScale = -distanceBetween * 0.02

		-- Formula: 90 + (math.atan2(y2 - y1, x2 - x1) * 180 / PI)
		local angleBetween = mCeil(mAtan2( (event.y - yOffset), (event.x - xOffset) ) * 180 / mPi) + 90

		ghostObject.rotation = angleBetween + 180
		arrow.rotation = ghostObject.rotation
	end

	--== SWIPE START

	if not self._is_panning and curr_state == GameView.STATE_NEW_ROUND then
		print("here")
		local dg = self._dg_game

		if self._screen_position == GameView.LEFT_POS then
			-- Swipe left to go right
			if xStart > 180 then
				dg.x = x - xStart
				if dg.x > 0 then dg.x = 0 end
			end

		elseif self._screen_position == GameView.RIGHT_POS then
			-- Swipe right to go to the left
			dg.x = (x - xStart) - 480
			if dg.x < -480 then dg.x = -480 end
		end
	end

	return true
end


function GameView:enterFrame( event )
	-- print( "GameView:enterFrame", event )

	local char = self._character
	local dg = self._dg_game
	local curr_state = self:getState()

	if self._game_is_active then

		if char then
			-- CAMERA CONTROL
			if char.x > 240 and char.x < 720 and curr_state == GameView.STATE_SHOT_IN_PLAY then
				dg.x = -char.x + 240
			end

			-- CHECK IF GHOST GOES PAST SCREEN
			if not char.is_offscreen and curr_state == GameView.STATE_SHOT_IN_PLAY and ( char.x < 0 or char.x >= 960 ) then
				char.is_offscreen = true
			end

		end

	end

	return true
end



return GameView

