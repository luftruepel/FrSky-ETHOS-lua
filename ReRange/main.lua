--[[ 
  Source: ReRange
  Author: luftruepel
  Date: 15.4.2025

  Description: 
    Remaps the output of a selected input source to a custom range (e.g. -50% to 100%). 

  Important Note: 
    This script does not work when using decimal values if the source is used directly in a mixer — in that case, you must route the source through VARS. The reason is that mixers operate on the rawValue, which differs from the value used by VARS. Specifically, rawValue is larger than value by a factor of 10^n, where n is the number of decimal places.

  TODO:
    - Translations: Quelle, Wertebereich
]]

local name = "ReRange"
local key = "lrRR1"

local MIN_DEFAULT = -100
local MAX_DEFAULT = 100
local MIN_RANGE = -100
local MAX_RANGE = 100

local DECIMALS_DEFAULT = 1
local DECIMALS_MIN = 0
local DECIMALS_MAX = 2

local inputSource
local min
local max
local decimals
local a
local b

local function calcCoefficients()
  a = inputSource:minimum() - inputSource:maximum()

  if a == 0 then
    a = 0
    b = 0
  else
    b = a
    a = (min - max)/a
    b = (max*inputSource:minimum() - min*inputSource:maximum())/b
  end
end

local function sourceInit(source)
  inputSource = nil
  min = MIN_DEFAULT
  max = MAX_DEFAULT
  decimals = DECIMALS_DEFAULT

  source:unit(UNIT_PERCENT)
  source:decimals(decimals)
end

local function sourceWakeup(source)
  if inputSource ~= nil then source:value(a*inputSource:value() + b) end
end

local function sourceRead(source)
  local tmpValue = storage.read("min")
  if tmpValue ~= nil then min = tmpValue end

  tmpValue = storage.read("max")
  if tmpValue ~= nil then max = tmpValue end

  tmpValue = storage.read("decimals")
  if tmpValue ~= nil then 
    decimals = tmpValue 
    source:decimals(decimals)
  end

  tmpValue = storage.read("SourceName")
  if tmpValue ~= nil then inputSource = system.getSource(tmpValue) calcCoefficients() end
end

local function sourceWrite(source)
  storage.write("min", min)
  storage.write("max", max)
  storage.write("decimals", decimals)
  if inputSource ~= nil then storage.write("SourceName", inputSource:name()) end
end

local function sourceConfigure(source)
  local tmpLine = form.addLine("Quelle", nil, false)
  form.addSourceField(tmpLine, nil, function() return inputSource end, function(newValue) inputSource = newValue calcCoefficients() end)

  local tmpLine = form.addLine("Wertebereich", nil, false)
  local tmpSlots = form.getFieldSlots(tmpLine, {0, " - ", 0})

  local tmpField = form.addNumberField(tmpLine, tmpSlots[1], MIN_RANGE, MAX_RANGE, function() return min end, function(value) min = value calcCoefficients() end)
  tmpField:suffix("%")
  tmpField:default(MIN_DEFAULT)

  form.addStaticText(tmpLine, tmpSlots[2], "-")

  tmpField = form.addNumberField(tmpLine, tmpSlots[3], MIN_RANGE, MAX_RANGE, function() return max end, function(value) max = value calcCoefficients() end)
  tmpField:suffix("%")
  tmpField:default(MAX_DEFAULT)

  local tmpLine = form.addLine("Dezimalstellen", nil, false)
  tmpField = form.addNumberField(tmpLine, nil, DECIMALS_MIN, DECIMALS_MAX, function() return decimals end, function(value) decimals = value source:decimals(decimals) end)
  tmpField:default(DECIMALS_DEFAULT)
end

local function init()
  system.registerSource({key=key, name=name, init=sourceInit, wakeup=sourceWakeup, read=sourceRead, write=sourceWrite, configure=sourceConfigure})
end

return {init=init}