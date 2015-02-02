--====================================================================--
-- component/load_screen.lua
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2011-2015 David McCuskey. All Rights Reserved.
-- Copyright (C) 2010 ANSCA Inc. All Rights Reserved.
--====================================================================--


--====================================================================--
--== Ghost vs Monsters : Load Screen
--====================================================================--


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "0.2.0"



--====================================================================--
--== Imports


local Objects = require 'lib.dmc_corona.dmc_objects'



--====================================================================--
--== Setup, Constants


local newClass = Objects.newClass
local ComponentBase = Objects.ComponentBase



--====================================================================--
--== Load Screen class
--====================================================================--


local LoadScreen = newClass( ComponentBase, {name="Load Screen"} )

--== Class Constants

LoadScreen.BAR_WIDTH = 300
LoadScreen.BAR_HEIGHT = 10

--== Event Constants

LoadScreen.EVENT = 'load-screen-event'
LoadScreen.COMPLETE = 'loading-complete'


--======================================================--
-- Start: Setup DMC Objects

-- __init__()
--
-- one of the base methods to override for dmc_objects
--
function LoadScreen:__init__()
	self:superCall( '__init__' )
	--==--

	--== Properties

	self._percent_complete = 0

	--== Display Objects

	self._bg = nil 
	self._load_bar = nil 
	self._outline = nil 
end

-- __undoInit__()
--
-- function LoadScreen:__undoInit__()
-- 	--==--
-- 	self:superCall( '__undoInit__' )
-- end


-- __createView__()
--
-- one of the base methods to override for dmc_objects
--
function LoadScreen:__createView__()
	self:superCall( '__createView__' )
	--==--

	local BAR_Y = 100
	local o

	-- create background

	o = display.newImageRect( 'assets/backgrounds/loading.png', 480, 320 )

	self:insert( o )
	self._bg = o 

	-- loading bar

	o = display.newRect( 0, 0, LoadScreen.BAR_WIDTH, LoadScreen.BAR_HEIGHT )
	o.strokeWidth = 0
	o:setStrokeColor( 0, 0, 0, 0 )
	o:setFillColor( 255, 255, 255, 255 )
	o.anchorX, o.anchorY = 0, 0.5
	o.y = BAR_Y

	self:insert( o )
	self._load_bar = o

	-- loading bar outline

	o = display.newRect( 0, 0, LoadScreen.BAR_WIDTH, LoadScreen.BAR_HEIGHT )
	o.strokeWidth = 2
	o:setStrokeColor( 200, 200, 200, 255 )
	o:setFillColor( 0, 0, 0, 0 )
	o.x, o.y = 0, BAR_Y

	self:insert( o )
	self._outline = o

end

-- __undoCreateView__()
--
function LoadScreen:__undoCreateView__()
	local o 

	o = self._outline
	o:removeSelf()
	self._outline = nil

	o = self._load_bar
	o:removeSelf()
	self._load_bar = nil 

	o = self._bg
	o:removeSelf()
	self._bg = nil 

	--==--
	self:superCall( '__undoCreateView__' )
end

-- __initComplete__()
--
function LoadScreen:__initComplete__()
	self:superCall( '__initComplete__' )
	--==--
	self:clear()
end


-- __undoInitComplete__()
--
-- function LoadScreen:__undoInitComplete__()
--
-- 	--==--
-- 	self:superCall( '__undoCreateView__' )
-- end

-- END: Setup DMC Objects
--======================================================--



--====================================================================--
--== Public Methods


function LoadScreen.__getters:percent_complete()
	return self._percent_complete
end

function LoadScreen.__setters:percent_complete( value )
	assert( type(value)=='number' )
	if value < 0 then value = 0 end
	if value > 100 then value = 100 end
	--==--
	local bar = self._load_bar
	local width = 480

	-- sanitize

	self._percent_complete = value

	-- calculate bar coords
	local width = LoadScreen.BAR_WIDTH * ( value / 100 )

	if width == 0 then
		bar.isVisible = false
	else
		bar.isVisible = true
		bar.width = width

		bar.x = - (LoadScreen.BAR_WIDTH / 2 ) -- - ( LoadScreen.BAR_WIDTH - bar.width ) / 2
	end

	if self._percent_complete >= 100 then
		self:dispatchEvent( self.COMPLETE )
	end
end


-- clear()
--
-- initialize load screen to beginnings
--
function LoadScreen:clear()
	self.percent_complete = 0 -- setter
end


--====================================================================--
--== Private Methods




return LoadScreen
