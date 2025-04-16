--[[ 
  Source: Modify Timer
  Author: luftruepel
  Date: 15.4.2025

  Description: Modifies the value of a timer. The timer must be stopped to modify it.

  TODO:
    - Translations
]]

local icon = lcd.loadMask("icon.png")

local timerList = {}
local selectedTimer
local h, m, s, time

local function secondsToHMS(time)
  local h = math.floor(time / 3600)
  local m = math.floor((time % 3600) / 60)
  local s = time % 60
  return h, m, s
end

local function hmsToSeconds(h, m, s)
  return (h * 3600) + (m * 60) + s
end

local function loadSelectedTimer()
  local timer = model.getTimer(selectedTimer)
  if timer then
    time = timer:value()
    h, m, s = secondsToHMS(time)
  end
end

local function checkChanges(applyButton, timer)
  if not timer then return end
  local newTime = hmsToSeconds(h, m, s)
  local loadedTime = timer:value()
  if newTime == loadedTime then
    applyButton:enable(false)
  else
    applyButton:enable(true)
  end
end

local function create()
  form.clear()
  timerList = {}

  local i = 0
  local timer = model.getTimer(i)
  while timer do
    if not timer:running() then
      local name = timer:name()
      if name == "" then
        name = "Stoppuhr " .. (i + 1)
      end 
      table.insert(timerList, {name, i})
    end
    i = i + 1
    timer = model.getTimer(i)
  end

  if #timerList == 0 then
    form.addStaticText(nil, nil, "Keine angehaltenen Stoppuhren gefunden.")
    return {}
  end

  local applyButton

  -- Auswahl der Timer
  local tmpLine = form.addLine("Stoppuhr", nil, false)
  selectedTimer = timerList[1][2]

  form.addChoiceField(tmpLine, nil, timerList,
    function() 
      return selectedTimer 
    end,
    function(value)
      selectedTimer = value
      local timer = model.getTimer(selectedTimer)
      if timer then
        time = timer:value()
        h, m, s = secondsToHMS(time)
      end
      if applyButton then
        applyButton:enable(false)
      end
    end)

  loadSelectedTimer()

  tmpLine = form.addLine("Wert", nil, false)
  local tmpSlots = form.getFieldSlots(tmpLine, {"00000", ":", "000", ":", "000", 0})

  form.addNumberField(tmpLine, tmpSlots[1], 0, 24, 
    function() 
      return h 
    end, 
    function(value)
      h = value
      local currentTimer = model.getTimer(selectedTimer)
      checkChanges(applyButton, currentTimer)
    end)

  form.addStaticText(tmpLine, tmpSlots[2], ":")

  form.addNumberField(tmpLine, tmpSlots[3], 0, 59, 
    function() 
      return m 
    end, 
    function(value)
      m = value
      local currentTimer = model.getTimer(selectedTimer)
      checkChanges(applyButton, currentTimer)
    end)

  form.addStaticText(tmpLine, tmpSlots[4], ":")

  form.addNumberField(tmpLine, tmpSlots[5], 0, 59, 
    function() 
      return s 
    end, 
    function(value)
      s = value
      local currentTimer = model.getTimer(selectedTimer)
      checkChanges(applyButton, currentTimer)
    end)

  applyButton = form.addTextButton(tmpLine, tmpSlots[6], "Übernehmen", 
    function() 
      local timer = model.getTimer(selectedTimer)
      if timer then
        timer:value(hmsToSeconds(h, m, s))
        applyButton:enable(false)
      end
    end)

  applyButton:enable(false)
  return {}
end

local function init()
  system.registerSystemTool({
    name = "Modify Timer",
    icon = icon,
    create = create,
  })
end

return { init = init }
