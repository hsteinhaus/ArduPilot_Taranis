--
-- telem1 lua
--
-- Copyright (C) 2014 Luis Vale Gonçalves
--   https://github.com/lvale/MavLink_FrSkySPort
--
--  Improved by:
--    (2015) Michael Wolkstein
--   https://github.com/wolkstein/MavLink_FrSkySPort
--
--    (2015) Jochen Kielkopf
--    https://github.com/Clooney82/MavLink_FrSkySPort
--
--    (2016) Holger Steinhuaus
--    https://github.com/hsteinhaus/dc_taranis
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
--
-- Auxiliary files on github under dir BMP and SOUNDS/en
-- https://github.com/Clooney82/MavLink_FrSkySPort/tree/s-c-l-v-rc-opentx2.1/Lua_Telemetry/DisplayApmPosition
--

--Init Variables
local LCD_WIDTH = 212
local LCD_HEIGHT = 64

local border = 3

local cell_min = 9
local cell_avg = 0
local cell_max = 0

local curr_min = 0
local curr_avg = 0
local curr_max = 0

local powr_min = 0
local powr_avg = 0
local powr_max = 0


local alpha = 0.1
local volt = 0
local curr = 0
local power = 0

local batt_capacity = 0
local batt_warning = 0
local watthours = 0

local localtime = 0
local oldlocaltime= 0

-----------------------------------
	local SumFlight = 0
	local lastarmed = 0
	local apmarmed = 0
	local FmodeNr = 13 -- This is an invalid flight number when no data available
	local last_flight_mode = 1
	local last_apm_message_played = 0
	local mult = 0
	local consumption = 0
	local vspd = 0
 	local xposCons = 0
	local t2 = 0
	local prearmheading = 0
	local radarx = 0
	local radary = 0
	local radarxtmp = 0
	local radarytmp = 0
	local hdop = 0

	local lastconsumption = 0
	local localtimetwo = 0
	local oldlocaltimetwo= 0
	local pilotlat = 0
	local pilotlon = 0
	local curlat = 0
	local curlon = 0
	local telem_sats = 0
	local telem_lock = 0
	local telem_t1 = 0
	local status_severity = 0
	local status_textnr = 0
	local hypdist = 0
	local battWhmax = 0
	local maxconsume = 0
	local whconsumed = 0
	local batteryreachmaxWH = 0

	-- Temporary text attribute
	local FORCE = 0x02 -- draw ??? line or rectangle
	local X1 = 0
	local Y1 = 0
	local X2 = 0
	local Y2 = 0
	local sinCorr = 0
	local cosCorr = 0
	local radTmp = 0
	local CenterXcolArrow = 189
	local CenterYrowArrow = 41
	local offsetX = 0
	local offsetY = 0
	local divtmp = 1
	local upppp = 20480
	local divvv = 2048 --12 mal teilen
	local power_ofs = 13

        -- gps
        local gpsLatLon = {}
        local LocationLat = 0
        local LocationLon = 0

	--Timer 0 is time while vehicle is armed

	model.setTimer(0, {mode=0, start=0, value=0, countdownBeep=0, minuteBeep=true, persistent=1})

	--Timer 1 is accumulated time per flight mode

	--model.setTimer(1, {mode=0, start=0, value=0, countdownBeep=0, minuteBeep=false, persistent=1})

--Init Flight Tables
	local FlightMode = {
			    "Stabilize",
			    "Acro",
			    "Altitude Hold",
			    "Auto",
			    "Guided",
			    "Loiter",
			    "Return to launch",
			    "Circle",
			    "Invalid Mode",
			    "Land",
			    "Optical Loiter",
			    "Drift",
			    "Invalid Mode",
			    "Sport",
			    "Flip Mode",
			    "Auto Tune",
			    "Position Hold",
                "Brake"}

	local apm_status_message = {severity = 0, textnr = 0, timestamp=0}

	local arrowLine = {
	  {-4, 5, 0, -4},
	  {-3, 5, 0, -3},

	  {3, 5, 0, -3},
	  {4, 5, 0, -4}
	}

-- Telemetry helper function
        local function getTelemetryId(name)
          field = getFieldInfo(name)
          if field then
            return field.id
          else
            return -1
          end
        end

-- draw arrow
	local function drawArrow()

	  sinCorr = math.sin(math.rad(getValue("Hdg")-prearmheading))
	  cosCorr = math.cos(math.rad(getValue("Hdg")-prearmheading))
	  -- working but without good gps a lot of movments// sinCorr = math.sin(math.rad(getValue("Hdg"))-headfromh)
	  -- working but without good gps a lot of movments// cosCorr = math.cos(math.rad(getValue("Hdg"))-headfromh)
	  for index, point in pairs(arrowLine) do
	    X1 = CenterXcolArrow + offsetX + math.floor(point[1] * cosCorr - point[2] * sinCorr + 0.5)
	    Y1 = CenterYrowArrow + offsetY + math.floor(point[1] * sinCorr + point[2] * cosCorr + 0.5)
	    X2 = CenterXcolArrow + offsetX + math.floor(point[3] * cosCorr - point[4] * sinCorr + 0.5)
	    Y2 = CenterYrowArrow + offsetY + math.floor(point[3] * sinCorr + point[4] * cosCorr + 0.5)

	    if X1 == X2 and Y1 == Y2 then
	      lcd.drawPoint(X1, Y1, SOLID, FORCE)
	    else
	      lcd.drawLine (X1, Y1, X2, Y2, SOLID, FORCE)
	    end
	  end
	end

	-- mapValue  to map a value from to to an new value from to ( inputvalue, in_minimum, in maximum, out_min, out maximum)
	-- example your input value is an integer from 0 - 200 and you need an linear expression from -100 - 0 analog to your input
	-- Local new_value = mapvalue(value, 0,200,-100,0) //result for value = 100 is "-50"

	--local function mapvalue(x, in_min, in_max, out_min, out_max)
	  --return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
	--end



--Aux Display functions and panels


	local function round(num, idp)
		mult = 10^(idp or 0)
		return math.floor(num * mult + 0.5) / mult
	end


-- GPS Panel
	local function gpspanel()

      tmp2 = getValue("Tmp2")
	  telem_t1 = bit32.band(tmp2, 0xFFFF)
	  telem_lock = 0
	  telem_sats = 0
	  telem_lock = telem_t1%10
	  telem_sats = (telem_t1 - telem_lock)/10

      local line = 11

	  if telem_lock >= 3 then
	    lcd.drawText (167, line, "3D",SMLSIZE)
	    lcd.drawNumber (198, line, telem_sats, SMLSIZE+LEFT)
	    lcd.drawText (lcd.getLastPos(), line, "S", SMLSIZE)

	  elseif telem_lock>1 then
	    lcd.drawText (167, line, "2D", SMLSIZE)
	    lcd.drawNumber (198, line, telem_sats, SMLSIZE+LEFT )
	    lcd.drawText (lcd.getLastPos(), line, "S", SMLSIZE)
	  else
	    lcd.drawText (167, line, "NO", 0+BLINK+INVERS+SMLSIZE)
	    lcd.drawText (198, line, "S",SMLSIZE)
	  end

	  hdop = round(bit32.rshift(tmp2, 16))
	  if hdop <250 then
	    lcd.drawNumber (180, line, hdop, PREC2+LEFT+SMLSIZE )
	  else
	    lcd.drawNumber (180, line, hdop, PREC2+LEFT+BLINK+INVERS+SMLSIZE)
	  end

	  -- pilot lat  52.027536, 8.513764
	  -- flieger   52.027522, 8.515386
	  -- 110,75 mm
	  --pilotlat = math.rad(52.027536) --getValue("pilot-latitude")
	  --pilotlon = math.rad(8.513764)--getValue("pilot-longitude")
	  --curlat = math.rad(52.027522)--getValue("latitude")
	  --curlon = math.rad(8.515386)--getValue("longitude")

	  --pilotlat = math.rad(getValue("pilot-latitude")) --not use taranis first lat and long here
	  --pilotlon = math.rad(getValue("pilot-longitude"))
	  curlat = math.rad(LocationLat)
	  curlon = math.rad(LocationLon)


	  if pilotlat~=0 and curlat~=0 and pilotlon~=0 and curlon~=0 then

	    z1 = math.sin(curlon - pilotlon) * math.cos(curlat)
	    z2 = math.cos(pilotlat) * math.sin(curlat) - math.sin(pilotlat) * math.cos(curlat) * math.cos(curlon - pilotlon)
	    -- headfromh =  math.floor(math.deg(math.atan2(z1, z2)) + 0.5) % 360 --not needed if we use prearmheading
	    -- headtoh = (headfromh - 180) % 360 --not needed if we use prearmheading

	    -- use prearmheading later to rotate cordinates relative to copter.
	    radarx=z1*6358364.9098634 -- meters for x absolut to center(homeposition)
	    radary=z2*6358364.9098634 -- meters for y absolut to center(homeposition)
	    hypdist =  math.sqrt( math.pow(math.abs(radarx),2) + math.pow(math.abs(radary),2) )

	    radTmp = math.rad( prearmheading ) --work!!
	    --radTmp = math.rad( headfromh )--  work, but need good gps signal.
	    radarxtmp = radarx * math.cos(radTmp) - radary * math.sin(radTmp)
	    radarytmp = radarx * math.sin(radTmp) + radary * math.cos(radTmp)

	    if math.abs(radarxtmp) >= math.abs(radarytmp) then --divtmp
	      for i = 13 ,1,-1 do
		if math.abs(radarxtmp) >= upppp then
		  divtmp=divvv
		  break
		end
		divvv = divvv/2
		upppp = upppp/2
	      end
	    else
	      for i = 13 ,1,-1 do
		if math.abs(radarytmp) >= upppp then
		  divtmp=divvv
		  break
		end
		divvv = divvv/2
		upppp = upppp/2
	      end
	    end

	    upppp = 20480
	    divvv = 2048 --12 mal teilen

	    offsetX = radarxtmp / divtmp
	    offsetY = (radarytmp / divtmp)*-1
	  end
	  --lcd.drawText(171,25,"X=",SMLSIZE )
	  --lcd.drawNumber(lcd.getLastPos(),25,offsetX,SMLSIZE + LEFT)
	  --lcd.drawText(171,47,"Y=", SMLSIZE)
	  --lcd.drawNumber(lcd.getLastPos(),47,offsetY,SMLSIZE + LEFT)
	  --lcd.drawText(190,57,"",SMLSIZE )
	  --lcd.drawNumber(lcd.getLastPos(),57,headtoh,SMLSIZE + LEFT)

	  lcd.drawText(187,37,"o",0)
	  --lcd.drawRectangle(167, 19, 45, 45)
      lcd.drawLine(165, 9, 165, 63, SOLID, FORCE)
      lcd.drawLine(165, 19, 211, 19, SOLID, FORCE)
	  
	  for j=169, 209, 4 do
	    lcd.drawPoint(j, 19+22)
	  end
	  for j=21, 61, 4 do
	    lcd.drawPoint(167+22, j)
	  end
	  lcd.drawNumber(189, 57,hypdist, SMLSIZE)
	  lcd.drawText(lcd.getLastPos(), 57, "m", SMLSIZE)
	end


-- Alt/Att panel
local function htsapanel(offset)
	lcd.drawLine (offset-1, 9, offset-1, 63, SOLID, 0)

	--timer
	local line = 12
	lcd.drawTimer(offset+border,line,model.getTimer(0).value,MIDSIZE)

	--altitude
	local alt = getValue("Alt")
	lcd.drawNumber(offset+border+51,line,alt,MIDSIZE)
	lcd.drawText(lcd.getLastPos(),line,"m", MIDSIZE)	

	local crs = getValue("Hdg")
	local spd = getValue("GSpd")
	local att = getValue("A3")*100
	local roll = (bit32.rshift(att, 16)-18000)/100
	local pitch = (bit32.band(att, 0xFFFF)-18000)/100
	local lean = math.sqrt(roll*roll+pitch*pitch)

	line = 30
	lcd.drawText(offset+border,line,"GCrs", SMLSIZE)	
	lcd.drawNumber(offset+border+44,line, crs*10, SMLSIZE+PREC1)	
	lcd.drawText(lcd.getLastPos(),line,"\64", SMLSIZE)	

	line = line + 11
	lcd.drawText(offset+border,line,"Lean", SMLSIZE)	
	lcd.drawNumber(offset+border+44,line, lean*10, SMLSIZE+PREC1)	
	lcd.drawText(lcd.getLastPos(),line,"\64", SMLSIZE)	

	line = line + 11
	lcd.drawText(offset+border,line,"GSpd", SMLSIZE)	
	lcd.drawNumber(offset+border+44,line, spd*10, SMLSIZE+PREC1)	
	lcd.drawText(lcd.getLastPos()+1,line,"m/s", SMLSIZE)	
end

-- Top Panel
local function toppanel()
	lcd.drawLine(0, 8, 211, 8, SOLID, FORCE)

	if apmarmed==1 then
	lcd.drawText(1, 1, (FlightMode[FmodeNr]), SMLSIZE)
	else
	lcd.drawText(1, 1, (FlightMode[FmodeNr]), SMLSIZE+BLINK)
	end

	local pos = 130
	lcd.drawText(pos, 1, "RSSI:", SMLSIZE)
	lcd.drawNumber(lcd.getLastPos()+14, 1, getValue("RSSI"),SMLSIZE)

	pos = 174
	lcd.drawText(pos, 1, "TX:", SMLSIZE)
	lcd.drawNumber(lcd.getLastPos()+ 18, 1, getValue(189)*100, SMLSIZE+PREC2)
	lcd.drawText(lcd.getLastPos()+1, 1, "V", SMLSIZE)
end


local function collect_data()
    volt = getValue("VFAS")
    curr = getValue("Curr")
	powr = volt*curr

	if volt>17 then
		cell = volt/6
	else
		cell = volt/4
	end

	if cell<cell_min then cell_min = cell end
	if cell>cell_max then cell_max = cell end
	cell_avg = alpha*cell + (1-alpha)*cell_avg

	if curr>curr_max then curr_max = curr end
	if powr>powr_max then powr_max = powr end

	if apmarmed then 
		if curr<curr_min then curr_min = curr end
		if powr<powr_min then powr_min = powr end

		curr_avg = alpha*curr + (1-alpha)*curr_avg
		powr_avg = alpha*powr + (1-alpha)*powr_avg
	end
end


--Power Panel
local function powerpanel(offset)
	-- large voltage display		
	lcd.drawNumber(offset+border+24,12,volt*10,MIDSIZE + PREC1)
	lcd.drawText(lcd.getLastPos(),12,"V",MIDSIZE)

	-- large power display		
	if powr < 1000 then
	 	lcd.drawNumber(offset+77,12,powr*10,MIDSIZE + PREC1)
	else 
		lcd.drawNumber(offset+77,12,powr,MIDSIZE)
	end
	lcd.drawText(lcd.getLastPos(),12,"W",MIDSIZE)

	-- details

	line = 30
	lcd.drawText(offset+border,line,"Min", SMLSIZE)	
	lcd.drawNumber(offset+border+36,line, cell_min*100, SMLSIZE+PREC2)	
	lcd.drawText(lcd.getLastPos(),line,"V", SMLSIZE)	
	lcd.drawNumber(offset+border+54,line, curr_min, SMLSIZE)	
	lcd.drawText(lcd.getLastPos(),line,"A", SMLSIZE)	
	lcd.drawNumber(offset+border+77,line, powr_min, SMLSIZE)	
	lcd.drawText(lcd.getLastPos(),line,"W", SMLSIZE)	

	line = line + 11
	lcd.drawText(offset+border,line,"Cur", SMLSIZE)	
	lcd.drawNumber(offset+border+36,line, cell*100, SMLSIZE+PREC2)	
	lcd.drawText(lcd.getLastPos(),line,"V", SMLSIZE)	
	lcd.drawNumber(offset+border+54,line, curr_avg, SMLSIZE)	
	lcd.drawText(lcd.getLastPos(),line,"A", SMLSIZE)	
	lcd.drawNumber(offset+border+77,line, powr_avg, SMLSIZE)	
	lcd.drawText(lcd.getLastPos(),line,"W", SMLSIZE)	

	line = line + 11
	lcd.drawText(offset+border,line,"Max", SMLSIZE)	
	lcd.drawNumber(offset+border+36,line, cell_max*100, SMLSIZE+PREC2)	
	lcd.drawText(lcd.getLastPos(),line,"V", SMLSIZE)	
	lcd.drawNumber(offset+border+54,line, curr_max, SMLSIZE)	
	lcd.drawText(lcd.getLastPos(),line,"A", SMLSIZE)	
	lcd.drawNumber(offset+border+77,line, powr_max, SMLSIZE)	
	lcd.drawText(lcd.getLastPos(),line,"W", SMLSIZE)	
end


--APM Armed and errors
	local function armed_status()


      -- opentx2.1.3 lua support for latitude and longitude
      -- added on opentx commit c0dee366c0ae3f9776b3ba305cc3eb6bdeec593a
      gpsLatLon = getValue("GPS")
      if (type(gpsLatLon) == "table") then
          if gpsLatLon["lat"] ~= NIL then
            LocationLat = gpsLatLon["lat"]
          end
          if gpsLatLon["lon"] ~= NIL then
            LocationLon = gpsLatLon["lon"]
          end
      end

	  if apmarmed ~=1 then -- report last heading bevor arming. this can used for display position relative to copter
	    prearmheading=getValue("Hdg")
	    pilotlat = math.rad(LocationLat)
	    pilotlon = math.rad(LocationLon)
	  end

	  if lastarmed~=apmarmed then
	    lastarmed=apmarmed
	    if apmarmed==1 then
	      model.setTimer(0,{ mode=1, start=0, value=SumFlight, countdownBeep=0, minuteBeep=true, persistent=1 })
              model.setTimer(1,{ mode=1, start=0, value=PersitentSumFlight, countdownBeep=0, minuteBeep=false, persistent=2 })
	      playFile("/SOUNDS/en/TELEM/SARM.wav")
	      playFile("/SOUNDS/en/TELEM/AVFM"..(FmodeNr-1).."A.wav")

	    else

	      SumFlight = model.getTimer(0).value
	      model.setTimer(0,{ mode=0, start=0, value=model.getTimer(0).value, countdownBeep=0, minuteBeep=true, persistent=1 })
              model.setTimer(1,{ mode=0, start=0, value=model.getTimer(1).value, countdownBeep=0, minuteBeep=false, persistent=2 })

	      playFile("/SOUNDS/en/TELEM/SDISAR.wav")
	    end

	  end

	  t2 = (t2-apmarmed)/0x02
	  status_severity = t2%0x10

	  t2 = (t2-status_severity)/0x10
	  status_textnr = t2%0x400

	  if(status_severity > 0)
	  then
	    if status_severity ~= apm_status_message.severity or status_textnr ~= apm_status_message.textnr then
	      apm_status_message.severity = status_severity
	      apm_status_message.textnr = status_textnr
	      apm_status_message.timestamp = getTime()
	    end
	  end

	  if apm_status_message.timestamp > 0 and (apm_status_message.timestamp + 2*100) < getTime() then
	    apm_status_message.severity = 0
	    apm_status_message.textnr = 0
	    apm_status_message.timestamp = 0
	    last_apm_message_played = 0
	  end

	  -- play sound
	  if apm_status_message.textnr >0 then
	    if last_apm_message_played ~= apm_status_message.textnr then
	      playFile("/SOUNDS/en/TELEM/MSG"..apm_status_message.textnr..".wav")
	      last_apm_message_played = apm_status_message.textnr
	    end
	  end
	end


--FlightModes
local function Flight_modes()
	tmp1 = getValue("Tmp1")
	apmarmed = bit32.rshift(tmp1, 8)
	FmodeNr = bit32.band(tmp1, 0xff) + 1

	if FmodeNr<1 or FmodeNr>18 then
		FmodeNr=13
	end

	if FmodeNr~=last_flight_mode then
		playFile("/SOUNDS/en/TELEM/AVFM"..(FmodeNr-1).."A.wav")
		last_flight_mode=FmodeNr
		curr_min = curr
		powr_min = powr
	end
end


-- play alarm wh reach maximum level
	local function playMaxWhReached()

	  if maxconsume > 0 and (watthours  + ( watthours * ( model.getGlobalVariable(8, 0)*10) ) ) >= maxconsume then
	    localtimetwo = localtimetwo + (getTime() - oldlocaltimetwo)
	    if localtimetwo >=800 then --8s
	      playFile("/SOUNDS/en/TELEM/ALARM3K.wav")
	      localtimetwo = 0
	    end
	    oldlocaltimetwo = getTime()
	  end
	end


--Init
local function init()
  -- set GV9/phase1 to Wh of battery, divided by 10
  -- set GV9/phase2 to Wh warning limit
  batt_capacity = model.getGlobalVariable(8, 0)*10
  batt_warning = model.getGlobalVariable(8, 1)
end


-- draw a popup with, title printed at xpos in the "window caption"
local function draw_popup(title, xpos)
	local hdist = 40
	local vdist = 6

	local width = LCD_WIDTH-2*hdist
	local height = LCD_HEIGHT-2*vdist
	lcd.drawRectangle(hdist, vdist, width, height, FORCE)
	lcd.drawFilledRectangle(hdist+1, vdist+1, LCD_WIDTH-2*hdist-2,LCD_HEIGHT-2*vdist-2, ERASE)
	lcd.drawLine(hdist+1, vdist+11, LCD_WIDTH-hdist-1, vdist+11, SOLID, FORCE)
	lcd.drawText(hdist+1+xpos, vdist+2, title)
	
	local startx = hdist+1
	local starty = vdist+2+10
	return startx, starty, width-2, height-13
end


-- Calculate watthours
local function calcWattHs()
	localtime = localtime + (getTime() - oldlocaltime)

	if localtime >=10 then --100 ms
		watthours = watthours + ( powr * (localtime/360000) )
		localtime = 0
	end
	oldlocaltime = getTime()
end


-- draw Wh Gauge
local function drawWhGauge()
	local wh_remaining = batt_capacity - watthours
	if wh_remaining < 0 then wh_remaining = 0 end

	offset = wh_remaining/batt_capacity*55
	lcd.drawNumber(85,1,watthours*100,0+SMLSIZE+PREC2)
	lcd.drawText(lcd.getLastPos()+1,1,"Wh",0+SMLSIZE)

	lcd.drawRectangle(0,8,12,57,FORCE)  -- bar: 9..63, full length:55
	if wh_remaining > batt_warning then
		lcd.drawFilledRectangle(1, 9+55-offset, 10, 55)
	else
		lcd.drawFilledRectangle(1, 9+55-offset, 10, 55, INVERS+BLINK) -- damn, not working
	end
end



local old_flags = 0

-- notify about motor failures
local function motors_popup()
	local xdist = 5
	local ydist = 2
	local flags = getValue("A4")*100

	if flags ~= old_flags then
		model.setGlobalVariable(1, 0, 1)
		old_flags = flags;
	else
		model.setGlobalVariable(1, 0, 0)
	end

	if flags~=0 then
		local hflags = bit32.rshift(flags,8)
		local lflags = bit32.band(flags,0xff)
		local x, y, w, h
		x, y, w, h = draw_popup("WARNING - Mixer Limit!", 11)	
		for r=0,1 do
			for c=0,3 do
				local motor = c+4*r
				local status = "-"
				if bit32.band(lflags, bit32.lshift(1, motor))~=0 then
					status = 'L'
				end
				if bit32.band(hflags, bit32.lshift(1, motor))~=0 then
					status = 'H'
				end
				lcd.drawText(x+xdist+r*(0.5*w+xdist), ydist+y+c*9, "Motor "..tostring(motor+1)..": ")
				lcd.drawText(lcd.getLastPos(), ydist+y+c*9, status)
			end
		end
		
	end
	
end



--Background
local function background()
	collect_data()
	armed_status()
	Flight_modes()
	calcWattHs()
	playMaxWhReached()
end



--Main
local function run(event)
	lcd.clear()
	background()
	toppanel()
	powerpanel(12)
	htsapanel(101)
	gpspanel()
	drawArrow()
	drawWhGauge()
	motors_popup()
end

return {init=init, run=run, background=background}
