--
-- Offset lua
--
-- Copyright (C) 2014 Michael Wolkstein
-- 
-- https://github.com/Clooney82/MavLink_FrSkySPort
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

local inputs = { {"O-SET mAh% ", VALUE,-100,100,0}, {"O-SET Wh%", VALUE, -100, 100, 0}, {"BatCap Wh", VALUE, 0, 250, 30} }

local oldoffsetmah=0
local oldoffsetwatth=0
local oldbatcapa=0

local function run_func(offsetmah, offsetwatth, batcapa)
  if oldoffsetmah ~= offsetmah or oldoffsetwatth ~= offsetwatth or oldbatcapa~=batcapa then
    model.setGlobalVariable(8, 0, offsetmah) --mA/h
    model.setGlobalVariable(8, 1, offsetwatth) --Wh
    model.setGlobalVariable(8, 2, batcapa) --Wh
    oldoffsetmah = offsetmah
    oldoffsetwatth = offsetwatth
    oldbatcapa = batcapa
  end

end

return {run=run_func, input=inputs}
