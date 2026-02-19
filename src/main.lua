local WGTNAME = "showal0.9"  -- max 9 characters
local fullVersion = "0.9.19"

--[[
HISTORY
=======
Author Mike Shellim http://www.rc-soar.com/opentx/lua
2026-02-14  v0.9.19	Refactored; added support for 800 pixel wide screens (TX16S Mk3)
2025-07-24  v0.9.18	Radios without T5/T6: fixed 'Error in create(): /WIDGETS/ShowAll/main.lua:187:"
2024-12-25  v0.9.17	Changed two unintended global declarations to local.
2024-12-24  v0.9.16	Fixed occasional double outputting of trims. Tidied up trims format.
2024-12-14  v0.9.15	Added trims for A, E, T, R
2024-11-05  v0.9.14	Added support for UNI firmware, refactored ELRS support
2024-04-23  v0.9.13	Added ELRS sensors (1RSS/2RSS, RQly, TQly)
2023-10-06  v0.9.12	Added T5 and T6 
2023-01-05  v0.9.11	Min pane height for full info decreased to 168px (for EdgeTX 2.9)
2022-10-17  v0.9.10	Min pane height for full info decreased to 169px (for EdgeTX 2.8)
2022-02-05  v0.9.9	Min pane height for full info decreased to 170px (for EdgeTX)
2021-10-09  v0.9.8 	Workaround for https://github.com/opentx/opentx/issues/6201
					Support for additional battery telemetry (batsens table)
2021-10-09  v0.9.7 	Display o/s name correctly when running EdgeTX
2021-02-21  v0.9.6 	Looks for A1, A2 if no RxBt telemetry found
2021-02-21  v0.9.5 	refactored hms
2021-01-04  v0.9.4 	Fixed negative timer values shown incorrectly
					Negative timer values rendered with INVERS font
					Increased font size of timers
					Layout improved for single column panels
2020-05-22  v0.9.3 	Added opentx version
					Cleaned up color assignment in Refresh()
2020-05-22  v0.9.2 	Fixed 'disabled' message when displaying full screen
2020-05-16  v0.9.1 	Added option to show undefined LS's as dots
					Displays at all pane sizes
					Cosmetic improvements
2019-11-23  v0.9.0 	First release

DESCRIPTION
===========
Displays basic info about active model.
At startup looks for output named 'armed'. If found, flashes
  'motor armed' when output value > 0.

REQUIREMENTS
============
Transmitter with colour screen 480x272 or 800x480. 
Other screens are not supported.
OpenTX v 2.2 or later

INSTRUCTIONS
============
Please read instructions in the zip package, or download from :
https://rc-soar.com/opentx/lua/showitall/ShowItAll_09.pdf


DISCLAIMER
==========
CHECK FOR CORRECT OPERATION BEFORE USE. IF IN DOUBT DO NOT FLY!!

USER SETTABLE VARIABLES
=======================
MAX_LS = maximum number of logical switches to display
A value of 20 is recommended for good performance in general use
If not using other scripts, you can increase this value
to a suggested max of 32 --]]

local MAX_LS = 20

--[[
SHOW_UNDEF_LS_AS_DOT determines how undefined logical switches
are rendered
If false (default), undefined logical switches are treated as 'off'.
If true, then undefined ls's are rendered as dots (nice!), but involves a cache
look up and a power cycle to refresh cache - best used only if logical switches
have been finalised.
 --]]

local SHOW_UNDEF_LS_AS_DOT = false

--[[
END OF USER SETTABLE VARIABLES
============================== --]]


-- ========= LOCAL VARIABLES =============
-- Field ids
local idSA
local idTmr1
local idLS1
local idTxV
local idchArmed
local idCh1
local strVer

-- voltage telemetry sensors in priority order
local batsens = {"Cels", "RxBt", "A1", "A2", "A3", "A4"}

-- item counts
local nLS
local nTmr

-- options table
local defaultOptions = {
	{"Use dflt clrs", BOOL, 1},
	{"BackColor", COLOR, WHITE},
	{"ForeColor", COLOR, BLACK},
	}
local colorFlags
local sticks = {}
local trims

-- Logical switch bitmap
local LSDefLo -- bitmap of definition state for LS's 0-31
local LSDefHi -- bitmap of definition state for LS's 32-63

local propsSwitchSymbols = {
	[480] = {w=5, h=8, weight=2},
	[800] = {w=5, h=10, weight=2},
}

local propsSwitches = {
	[480] = {x=6, y=36, dx=40, dy=12, font=SMLSIZE, symXOffset=22, symYOffset=4	},
	[800] = {x=6, y=58, dx=70, dy=18, font=SMLSIZE, symXOffset=25, symYOffset=6	},
}

local propFM = {
	[480] = {x=130, y=105, font=MIDSIZE},
	[800] = {x=245, y=180, font=MIDSIZE},
}

local propModelName = {
	[480] = {x=2, y=0, font=MIDSIZE},
	[800] = {x=2, y=2, font=MIDSIZE},
}

local propTelemetry = {
	[480] = {x=106, y=29, font=0, xPitch = 90, xValOffset=50, lineHt = 18},
	[800] = {x=200, y=58, font=0, xPitch = 120, xValOffset=70, lineHt = 25},
}

local propTimers = {
	[480] = {x=288, y=100, font=0, xOffset = 22, dy=20},
	[800] = {x=520, y=180, font=0, xOffset = 22, dy=25},
}

local propLS = {
	[480] = {x=288, y=39, w=6, h=7, xPitch=8, xSep=12, yPitch=9, font=SMLSIZE},
	[800] = {x=520, y=58, w=8, h=9, xPitch=10, xSep=14, yPitch=12, font=SMLSIZE},
}

local propSticks = {
	[480] = {x=6, y=105, dy=12},
	[800] = {x=6, y=180, dy=18},
}

local propTrims = {
	[480] = {x=144, y=135, dx = 52, dy=12, font=SMLSIZE},
	[800] = {x=265, y=230, dx = 52, dy=20, font=SMLSIZE},
}

local propChans = {
	[480] = {x=65, y=105, dy=8, charLtOffset = -3, charRtOffset = 38, yTxtOff = -5, wRect = 36,  barHt = 5,font=SMLSIZE},
	[800] = {x=90, y=185, dy=12, charLtOffset = -3, charRtOffset = 65, yTxtOff = -5, wRect = 60,  barHt = 9,font=SMLSIZE},
}

local propInfo = {
	[480] = {xArmed = 233, yArmed = 0, xVer = 287, yVer1 = 0, yVer2 = 13, fontArmed=MIDSIZE, fontVer=SMLSIZE},
	[800] = {xArmed = 466, yArmed = 5, xVer = 520, yVer1 = 10, yVer2=28,fontArmed=MIDSIZE, fontVer=SMLSIZE},
}
	
-- ========= F U N C T I O N S =============

--[[
FUNCTION: initLSDefs
Populate logical switch bitmap cache where 1=defined, 0=undefined.
Cache needed as getLogicalSwitch is slow.
--]]
local function initLSDefs ()
	LSDefLo = 0
	LSDefHi = 0
	for i = 0, 31 do
		local vLo = (model.getLogicalSwitch(i).func > 0) and 1 or 0
		local vHi = (model.getLogicalSwitch(i+32).func >0) and 1 or 0
		LSDefLo = bit32.replace (LSDefLo, vLo, i)
		LSDefHi = bit32.replace (LSDefHi, vHi, i)
	end
end

--[[
FUNCTION: getLSVal
Get logical switch value.
	@param i number - logical switch index
	@return number - 1024 (true), -1024 (false), or nil (undefined)
--]]
local function getLSVal (i)
	local val = getValue (idLS1 + i)
	if SHOW_UNDEF_LS_AS_DOT then
		local long = i>31 and LSDefHi or LSDefLo
		if bit32.extract (long, i%32) == 0 then
			val = nil
		end
	end
	return val
end

--[[
FUNCTION: getNumItems
Determine the number of items in a field.
	@param field string - field name prefix (e.g., 'ls')
	@param maxitems number - maximum items to check
	@return number - count of items found
--]]
local function getNumItems (field, maxitems)
	local i = 1
	while true do
		if i > maxitems or not getFieldInfo(field ..i) then
			break
		end
		i = i + 1
	end
	return i-1
end

--[[
FUNCTION: create
Create the widget. Called by OpenTX during widget initialization.
Caches field IDs and initializes logical switch bitmaps.
	@param zone table - display zone
	@param options table - widget options
	@return table - widget state
--]]

local function create(zone, options)

	-- cache field id's 
	idSA = getFieldInfo('sa').id
	idLS1 = getFieldInfo('ls1').id
	idTmr1 = getFieldInfo('timer1').id
	idTxV = getFieldInfo('tx-voltage').id
	idCh1 = getFieldInfo('ch1').id
  
	-- cache trim ids
	local inf
	trims = {}
	inf = getFieldInfo('trim-ail'); if inf then trims [#trims + 1] = {'Ai', inf.id}; end
	inf = getFieldInfo('trim-ele'); if inf then trims [#trims + 1] = {'El', inf.id}; end
	inf = getFieldInfo('trim-thr'); if inf then trims [#trims + 1] = {'Th', inf.id}; end
	inf = getFieldInfo('trim-rud'); if inf then trims [#trims + 1] = {'Ru', inf.id}; end
	inf = getFieldInfo('trim-t5');  if inf then trims [#trims + 1] = {'T5', inf.id}; end
	inf = getFieldInfo('trim-t6');  if inf then trims [#trims + 1] = {'T6', inf.id}; end

  	-- o/s version
	local _, _, major, minor, rev, osname = getVersion()
	strVer = (osname or "OpenTX") .. " " .. major .. "." .. minor.. "." .. rev

	-- number of logical switches and timers to output
	nLS = getNumItems ('ls', MAX_LS)
	nTmr = getNumItems ('timer',3)

	-- Initialise LS bitmap
	initLSDefs ()

	-- search for output channel named 'armed'
	idchArmed = nil
	local i = 0
	while true do
		local o = model.getOutput (i)
		if not o then break end
		if string.lower (string.sub (o.name, 1,5)) == "armed" then
			idchArmed = getFieldInfo ("ch".. (i+1)).id
			break
		end
		i = i + 1
	end

  	-- stick labels and ids
	sticks={
		{name='A', id=getFieldInfo('ail').id},
		{name='E', id=getFieldInfo('ele').id},
		{name='T', id=getFieldInfo('thr').id},
		{name='R', id=getFieldInfo('rud').id},
  		}

	return {zone=zone, options=options}
end


--[[
FUNCTION: update
Update widget settings. Called by OpenTX when widget options change.
	@param wgt table - widget state
	@param newOptions table - new widget options
--]]
local function update(wgt, newOptions)
    wgt.options = newOptions
end

--[[
FUNCTION: background
Background update. Called periodically by OpenTX.
	@param wgt table - widget state
--]]
local function background(wgt)
end


--[[
FUNCTION: hms
Convert time in seconds to string format [-]hh:mm:ss.
	@param n number - time in seconds (may be negative)
	@return string - formatted as [-]hh:mm:ss
--]]
local function hms (n)

	local stSign
	if n < 0 then
		stSign = "-"
		n = -n
	else
		stSign = " "
	end

	local hh = math.floor (n/3600)
	n = n % 3600
	local mm = math.floor (n/60)
	local ss = n % 60

	-- replacement for buggy string.format()
	-- https://github.com/opentx/opentx/issues/6201
	local function fmt (v)
		return #(v .. "") >=2 and v or ("0" ..v)
	end
	return stSign .. fmt(hh) .. ':' .. fmt(mm) .. ':' .. fmt(ss)
end




--[[
FUNCTION: drawSwitchSymbol
Draw switch state symbol (up/middle/down).
	@param x number - x coordinate
	@param y number - y coordinate
	@param val number - switch value (-1=up, 0=middle, >0=down)
--]]
local function drawSwitchSymbol (x,y,val)
	local p = propsSwitchSymbols [LCD_W]
	local w=p.w
	local h=p.h
	local weight = p.weight
	if val==0 then
		lcd.drawFilledRectangle (x, y+h/2, w,1, colorFlags)
	elseif val > 0 then
		lcd.drawFilledRectangle (x+ w/2, y+h/2-1, 1,h/2+1,colorFlags)
		lcd.drawFilledRectangle (x, y+h, w,weight,colorFlags)
	else
		lcd.drawFilledRectangle (x+ w/2, y, 1,h/2+2,colorFlags)
		lcd.drawFilledRectangle (x, y, w,weight,colorFlags)
	end
end

--[[
FUNCTION: drawSwitches
Draw all switch states (SA-SH).
	@param zone table - display zone
--]]
local function drawSwitches (zone)
	-- Switches
	local p = propsSwitches [LCD_W]
	local x = zone.x + p.x
	local y0 = zone.y + p.y
	local y = y0
	for i = 0, 7 do
		lcd.drawText (x, y, "S".. string.char(string.byte('A')+i), p.font + colorFlags)
		drawSwitchSymbol (x + p.symXOffset, y + p.symYOffset, getValue (idSA+i))
		y = y + p.dy
		if i == 3 then
			x = x + p.dx
			y = y0
		end
	end
end

--[[
FUNCTION: drawFM
Draw current flight mode name.
	@param zone table - display zone
--]]
local function drawFM (zone)
	local p = propFM [LCD_W]
	local x = zone.x + p.x
	local y = zone.y + p.y
	local fmno, fmname = getFlightMode()
	if fmname == "" then
		fmname = "FM".. fmno
	end
	lcd.drawText (x, y, fmname, p.font + colorFlags)
end

--[[
FUNCTION: drawModelName
Draw the model name.
	@param zone table - display zone
--]]
local function drawModelName (zone)
	local p = propModelName [LCD_W]
	local strname = model.getInfo().name
	lcd.drawText (zone.x + p.x, zone.y + p.y, strname, p.font + colorFlags)
end

--[[
FUNCTION: to1DP
Format number with one decimal place. Equivalent to string.format("%.1f", val).
Workaround for buggy string.format() in OpenTX.
See: https://github.com/opentx/opentx/issues/6201
	@param val number - value to format
	@return string - formatted value (e.g., "12.3") or nil if invalid
--]]
local function to1DP (val)
	val = tonumber(val)
	if not val then return nil end
	local a = math.floor(math.abs(val) * 10 + 0.5)
	local intpart = math.floor(a / 10)
	local dec = a % 10
	return (val < 0 and "-" or "") .. intpart .. "." .. dec
end
--[[
FUNCTION: getCelsTotalVoltage
Sum cell voltages from cells table.
	@param tCells table - array of cell voltages
	@return number - total voltage
--]]
local function getCelsTotalVoltage (tCells)
	local volts = 0
	for i = 1, #tCells do
		volts = volts + tCells[i]
	end
	return volts
end

--[[
FUNCTION: getAirBatt
Get air battery sensor reading. Finds highest priority active sensor from batsens table.
	@return table - {sensor_name, voltage_string}
--]]
local function getAirBatt ()
	local val
	local sensor
	for i = 1, #batsens do
		sensor = batsens[i]
		val = getValue(sensor)
		print ("+++ Sensor", sensor, val)
		if sensor == "Cels" and type (val) == "table" then
			val = getCelsTotalVoltage(val)
		end
		if val and val > 0 then
			val = to1DP(val)
			return {sensor, val}
		end
	end
	return {'NoBat', nil}
end

--[[
FUNCTION: drawTelemetry
Draw telemetry values (battery, RSSI, etc.).
	@param zone table - display zone
--]]
local function drawTelemetry (zone)
	local p = propTelemetry [LCD_W]
	local x0 = zone.x + p.x
	local y0 = zone.y + p.y

	local fields = {}
	fields [#fields + 1] = {'TxBt:',to1DP(getValue(idTxV))}
	fields [#fields + 1] =  getAirBatt()
	fields [#fields + 1] = {'1RSS:', getValue('1RSS')}
	fields [#fields + 1] = {'2RSS:', getValue('2RSS')}
	fields [#fields + 1] = {'RQly:', getValue('RQly')}
	fields [#fields + 1] = {'RSSI:', getValue('RSSI')}
	fields [#fields + 1] = {'VFR:', getValue('VFR')}

	local flags = p.font + colorFlags
	local x = x0
	local y = y0
  	local cnt = 0
	for i = 1, #fields do
		local val = fields [i][2]
		if val and val ~= 0 then
			lcd.drawText (x, y, fields[i][1], flags)
			lcd.drawText (x + p.xValOffset, y, val, flags)
			cnt = cnt+1
			if cnt % 2 == 0 then
				x = x0
				y = y + p.lineHt
			else
				x = x + p.xPitch
			end
		end
	end
end

--[[
FUNCTION: drawTimers
Draw timer values.
	@param zone table - display zone
--]]
local function drawTimers(zone)
	local p = propTimers [LCD_W]
	local x = zone.x + p.x
	local y = zone.y + p.y
	for i = 0, nTmr-1 do
		local t = getValue (idTmr1 + i)
		lcd.drawText (x, y, "t" .. (i+1) ..":", p.font + colorFlags)
		lcd.drawText (x + p.xOffset, y, hms (t) , p.font + colorFlags + (t<0 and INVERS or 0))
		y = y + p.dy
	end
end

--[[
FUNCTION: drawLS
Draw logical switch states.
	@param zone table - display zone
--]]
local function drawLS (zone)
	local p = propLS [LCD_W]
	local x0 = zone.x + p.x
	local y = zone.y + p.y
	local w = p.w
	local h = p.h

	local i = 0
	local x = x0
	while i < nLS do
		local v = getLSVal (i)
		if not v then
			-- undefined
			lcd.drawFilledRectangle( (x + w/2 - 2), (y + h/2 - 1), 3, 3, colorFlags)
		elseif v > 0 then
			-- defined and true
			lcd.drawFilledRectangle(x, y, w, h, colorFlags)
		else
			-- anything else
			lcd.drawRectangle(x, y, w, h, colorFlags)
		end

		i = i + 1
		if i%10 == 0 then
			x = x0
			y = y + p.yPitch
		elseif i%5 == 0 then
			x = x + p.xSep
		else
			x = x + p.xPitch
		end
	end
	lcd.drawText (x, y - 4, "LS 01-"..nLS, p.font + colorFlags)
end

--[[
FUNCTION: drawSticks
Draw stick positions.
	@param zone table - display zone
--]]
local function drawSticks (zone)
	local p = propSticks [LCD_W]
	local x = zone.x + p.x
	local y = zone.y + p.y
	for _, st in ipairs (sticks) do
		lcd.drawText (x, y,
			st.name .. ":" .. math.floor (0.5 + getValue(st.id)/10.24),
			SMLSIZE + colorFlags
			)
		y = y + p.dy
	end
end

--[[
FUNCTION: drawTrims
Draw trim values.
	@param zone table - display zone
--]]
local function drawTrims (zone)

	local p= propTrims [LCD_W]
	local x0 = zone.x + p.x
	local y = zone.y + p.y
  	local x = x0

  	for i = 1, #trims do
		local tr = trims [i]
		local val = math.floor (0.5 + getValue(tr[2])/10.24)

		-- label right justified, then value
		lcd.drawText (x, y, tr[1] .. ":" , p.font + colorFlags + RIGHT)
		lcd.drawText (x, y, val, p.font + colorFlags)

		if i % 3 == 0 then
			x = x0
			y = y + p.dy
		else
			x = x + p.dx
		end
  	end
end

--[[
FUNCTION: drawChans
Draw output channel bars.
	@param zone table - display zone
--]]
local function drawChans (zone)
	local p = propChans [LCD_W]
	local x = zone.x + p.x
	local y = zone.y + p.y
	local yTxtOff = p.yTxtOff
	local wRect = p.wRect
	local wBar

	local charsLt = {[0]="1","","3","","5","","7"}
	local charsRt = {[0]="","2","","4","","6",""}
	for i = 0, 6 do
		-- label
		lcd.drawText (x+p.charLtOffset, y + yTxtOff, charsLt[i], p.font + colorFlags + RIGHT)
		lcd.drawText (x+p.charRtOffset, y + yTxtOff, charsRt[i], p.font + colorFlags)
		-- bar outline
		lcd.drawRectangle (x, y, wRect, p.barHt, colorFlags)
		local val = (getValue(idCh1 + i) + 1024)/2048
		wBar = 4
		if val < 0 then
			val  = 0
		elseif val > 1 then
			val = 1
		else
			wBar = 2
		end
		local xBar = val*wRect - wBar/2
		lcd.drawFilledRectangle (x + xBar, y, wBar, p.barHt, colorFlags)
		y = y + p.dy
	end
end

--[[
FUNCTION: drawInfo
Draw motor armed warning or version info.
	@param zone table - display zone
--]]
local function drawInfo (zone)
	local p = propInfo [LCD_W]
	-- draw motor armed' warning or OTX version.
	if idchArmed and getValue (idchArmed) > 0 then
		lcd.drawText (zone.x + p.xArmed, zone.y + p.yArmed, "motor armed!", p.fontArmed +  BLINK + INVERS)
	else
		-- lcd.drawText (x, y + p.yOffsetVer, strVer .. "/" .. fullVersion, p.fontVer + colorFlags)
		lcd.drawText (zone.x + p.xVer, zone.y + p.yVer1, strVer, p.fontVer + colorFlags)
		lcd.drawText (zone.x + p.xVer, zone.y + p.yVer2, "ShowAll " .. fullVersion, p.fontVer + colorFlags)
	end
end



--[[
FUNCTION: refresh
Refresh widget display. Called by OpenTX when the widget is displayed.
	@param wgt table - widget state
--]]
local function refresh(wgt)

	-- Colour option
	-- Check for LS bit (OpenTX Github #7059)
	if bit32.btest (wgt.options["Use dflt clrs"], 1) then
		colorFlags = 0
	else
		lcd.setColor (CUSTOM_COLOR, wgt.options.BackColor)
		lcd.drawFilledRectangle (
			wgt.zone.x,
			wgt.zone.y,
			wgt.zone.w,
			wgt.zone.h,
			CUSTOM_COLOR)
		lcd.setColor (CUSTOM_COLOR, wgt.options.ForeColor)
		colorFlags = CUSTOM_COLOR
	end

	-- check that it's a supported resolutoin
	if propFM [LCD_W] == nil then
		lcd.drawText (wgt.zone.x + 10, wgt.zone.y + 10, "Unsupported screen", MIDSIZE + colorFlags)
		return
	end

    drawModelName (wgt.zone)
    drawSwitches (wgt.zone)
    drawSticks (wgt.zone)
    drawChans (wgt.zone)
    drawFM (wgt.zone)
    drawTrims (wgt.zone)
    drawTelemetry (wgt.zone)
	drawTimers (wgt.zone)
    drawLS (wgt.zone)
    drawInfo (wgt.zone)
end

return { name=WGTNAME, options=defaultOptions, create=create, update=update, refresh=refresh, background=background }
