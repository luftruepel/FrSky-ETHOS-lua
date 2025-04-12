--[[ 
  Script: Graupner Servo Converter
  Author: luftruepel
  Date: 12.4.2025

  TODO:
    - Centering of End-Message
    - Add support for other languages
]]

local reqEthosVersion="1.6.2"

local icon = lcd.loadMask("icon.png")

local ChannelChoiceField

local GraupnerConstants = {
    PWM_SCALE      = 400,
    PWM_CENTER     = 1500,
    PWM_MAX_LIMIT  = 2100,
    PWM_MIN_LIMIT  = 900
}

local PWM_SCALE_ETHOS = 512

local selectedChannel
local channelList
local correctDirection
local GraupnerDirection
local GraupnerTrim
local GraupnerTravelPlus
local GraupnerTravelMinus

function addStaticTextCentered(line, rect, text, font)

    font = font or FONT_STD

    local tmpFont = lcd.font()

    lcd.font(font)

    local x = math.floor(rect.x + (rect.w  - lcd.getTextSize(text))/2)

    lcd.font(tmpFont)

    form.addStaticText(line, {x = x,
                              y = rect.y,
                              w = rect.w,
                              h = rect.h}, text)
end

function getLineSlots(line, n, space, margin_left, margin_right)

    if n < 1 then
        return {}
    end

    local w, h = lcd.getWindowSize()

    local Slots = form.getFieldSlots(line, {0, 0})

    margin_left = margin_left or 0

    margin_right = margin_right or w - (Slots[2].x + Slots[2].w)

    space = space or Slots[2].x - (Slots[1].x + Slots[1].w)

    w = (w - margin_left - margin_right - (n-1)*space)/n

    Slots = {Slots[1]}

    Slots[1].w = math.floor(w)
    Slots[1].x = margin_left

    for i = 2, n do
        table.insert(Slots, {x = math.floor(Slots[i-1].x + Slots[i-1].w + space),
                             y = Slots[1].y,
                             w = Slots[1].w,
                             h = Slots[1].h})
    end

    return Slots
end

function round(x, n)
    n = n or 0
    local factor = 10 ^ n
    return math.floor(x * factor + 0.5) / factor
end

local function showErrorDialog(label, expected, current)
    form.openDialog({
        title = "Hinweis", 
        message = label .. "-Wert falsch\n  Soll = " .. expected .. "\n Ist = " .. current,
        width = 500,
        height = 600,
        buttons = {{ label = "OK", action = function() return true end }},
        options = TEXT_LEFT,
        wakeup = function() end,
        paint = function() end
    })
end

local function isVersionOk(requiredString)
    local reqMajor, reqMinor, reqRevision = string.match(requiredString, "(%d+)%.(%d+)%.(%d+)")
    reqMajor, reqMinor, reqRevision = tonumber(reqMajor), tonumber(reqMinor), tonumber(reqRevision)
    local version = system.getVersion()
    
    local reqComponents = {reqMajor, reqMinor, reqRevision}
    local currentComponents = {version.major, version.minor, version.revision}
    
    for i = 1, 3 do
        if currentComponents[i] > reqComponents[i] then
            return true
        elseif currentComponents[i] < reqComponents[i] then
            return false
        end
    end
    return true
end

local function initServoParameters()
    correctDirection = 1
    GraupnerDirection = 1
    GraupnerTrim = 0
    GraupnerTravelPlus = 100
    GraupnerTravelMinus = 100
end

local function handleChannelAction(apply)

    if apply then
        local pwmCenter
        local min
        local max

        if (GraupnerDirection == 1) then
            pwmCenter = 1
            min = GraupnerTravelMinus
            max = GraupnerTravelPlus
        else
            pwmCenter = -1
            min = GraupnerTravelPlus
            max = GraupnerTravelMinus
        end

        pwmCenter = pwmCenter*(GraupnerTrim/100)*GraupnerConstants.PWM_SCALE + GraupnerConstants.PWM_CENTER

        min = pwmCenter - (min/100)*GraupnerConstants.PWM_SCALE
        max = pwmCenter + (max/100)*GraupnerConstants.PWM_SCALE

        min = math.max(math.min(min, GraupnerConstants.PWM_MAX_LIMIT), GraupnerConstants.PWM_MIN_LIMIT)
        max = math.max(math.min(max, GraupnerConstants.PWM_MAX_LIMIT), GraupnerConstants.PWM_MIN_LIMIT)  

        min = round((min - pwmCenter)/PWM_SCALE_ETHOS*100, 1)
        max = round((max - pwmCenter)/PWM_SCALE_ETHOS*100, 1)

        pwmCenter = round(pwmCenter, 0)

        local channel = model.getChannel(selectedChannel)        

        channel:pwmCenter(pwmCenter)

        if correctDirection == 0 then
            channel:direction(channel:direction()*-1)
        end         

        channel:min(min-0.01) -- The ±0.01 offset is applied to compensate for minor rounding errors during conversion. Without this adjustment, the computed value could deviate by up to 0.1. This correction ensures that the target value is reached as precisely as possible. Additionally, a control mechanism is in place that alerts the user if the value remains incorrect despite the offset.        
        channel:max(max+0.01)

        if channel:min() ~= min then
            showErrorDialog("Min", min, channel:min())
        end
        
        if channel:max() ~= max then
            showErrorDialog("Max", max, channel:max())
        end
    end

    for i = #channelList, 1, -1 do
        if channelList[i][2] == selectedChannel then
            table.remove(channelList, i)
            break
        end
    end

    if #channelList > 0 then
        selectedChannel = channelList[1][2]
        ChannelChoiceField:values(channelList)
        initServoParameters()
    else
        form.clear()
        form.addStaticText(nil, nil, "Alle Kanäle programmiert!")
    end
end

local function create()

    if not isVersionOk(reqEthosVersion) then
          form.openDialog({
              title="Hinweis", 
              message="Es wird mindestens die Ethos-Version 1.6.2 \nbenötigt!",
              width=500,
              buttons={{label="OK", action=function() return true end}},
              options=TEXT_LEFT,
              wakeup=function()
                return
              end,
              paint=function()
                return
              end
          })

          system.exit()
          return
    end    

    form.clear()

    channelList = {}
   
    for i = 0, 31 do
        local channel = model.getChannel(i)
        if channel and channel:name() ~= "" then
            table.insert(channelList, {channel:name() .. " (" .. i+1 .. ")", i})
        end
    end

    table.sort(channelList, function(a, b) return a[1] < b[1] end)

    if #channelList == 0 then
        form.addStaticText(nil, nil, "Keine Kanäle gefunden.")
        return {}
    end

    selectedChannel = channelList[1][2]
    initServoParameters()

    local tmpLine = form.addLine("Kanal", nil, false)
    ChannelChoiceField = form.addChoiceField(tmpLine, nil, channelList, function() return selectedChannel end,
                                            function(value)
                                                selectedChannel = value
                                                initServoParameters()
                                            end)

    tmpLine = form.addLine("    Drehrichtung korrekt?", nil, true)
    form.addChoiceField(tmpLine, nil, {{"Ja", 1}, {"Nein", 0}}, function() return correctDirection end, function(value) correctDirection = value end)

    tmpLine = form.addLine("Graupner Servoeinstellungen", nil, false)

    if (false) then
        tmpLine = form.addLine("     Richtung", nil, false)
        form.addChoiceField(tmpLine, nil, {{"=>", 1}, {"<=", 0}}, function() return GraupnerDirection end, function(value) GraupnerDirection = value end)

        tmpLine = form.addLine("     Mitte", nil, false)
        local tmpField = form.addNumberField(tmpLine, nil, -1500, 1500, function() return GraupnerTrim*10 end, function(value) GraupnerTrim = value/10 end)
        tmpField:decimals(1)
        tmpField:suffix("%")
        tmpField:default(GraupnerTrim*10)

        tmpLine = form.addLine("     Weg -", nil, false)
        tmpField = form.addNumberField(tmpLine, nil, 0, 1500, function() return GraupnerTravelMinus*10 end, function(value) GraupnerTravelMinus = value/10 end)
        tmpField:decimals(1)
        tmpField:suffix("%")
        tmpField:default(GraupnerTravelMinus*10)   

        tmpLine = form.addLine("     Weg +", nil, true)
        tmpField = form.addNumberField(tmpLine, nil, 0, 1500, function() return GraupnerTravelPlus*10 end, function(value) GraupnerTravelPlus = value/10 end)
        tmpField:decimals(1)
        tmpField:suffix("%")
        tmpField:default(GraupnerTravelPlus*10)

        local tmpLine = form.addLine("", nil, false)
        local tmpSlots = form.getFieldSlots(tmpLine, {0, 0})

        form.addTextButton(tmpLine, tmpSlots[1], "Kanal ignorieren", function()
            handleChannelAction(false)
        end)

        form.addTextButton(tmpLine, tmpSlots[2], "Übernehmen", function()
            handleChannelAction(true)
        end)

    else
        local tmpLine = form.addLine(" ", nil, false)
        local tmpSlots = getLineSlots(tmpLine, 4)

        addStaticTextCentered(tmpLine, tmpSlots[1], "Richtung")
        addStaticTextCentered(tmpLine, tmpSlots[2], "Mitte")
        addStaticTextCentered(tmpLine, tmpSlots[3], "Weg -")
        addStaticTextCentered(tmpLine, tmpSlots[4], "Weg +")

        local tmpLine = form.addLine(" ", nil, true)

        form.addChoiceField(tmpLine, tmpSlots[1], {{"=>", 1}, {"<=", 0}}, function() return GraupnerDirection end, function(value) GraupnerDirection = value end)

        local tmpField = form.addNumberField(tmpLine, tmpSlots[2], -1500, 1500, function() return GraupnerTrim*10 end, function(value) GraupnerTrim = value/10 end)
        tmpField:decimals(1)
        tmpField:suffix("%")
        tmpField:default(GraupnerTrim*10)

        tmpField = form.addNumberField(tmpLine, tmpSlots[3], 0, 1500, function() return GraupnerTravelMinus*10 end, function(value) GraupnerTravelMinus = value/10 end)
        tmpField:decimals(1)
        tmpField:suffix("%")
        tmpField:default(GraupnerTravelMinus*10)   

        tmpField = form.addNumberField(tmpLine, tmpSlots[4], 0, 1500, function() return GraupnerTravelPlus*10 end, function(value) GraupnerTravelPlus = value/10 end)
        tmpField:decimals(1)
        tmpField:suffix("%")
        tmpField:default(GraupnerTravelPlus*10)

        local tmpLine = form.addLine("", nil, false)
        local tmpSlots = getLineSlots(tmpLine, 2)

        form.addTextButton(tmpLine, tmpSlots[1], "Kanal ignorieren", function()
            handleChannelAction(false)
        end)

        form.addTextButton(tmpLine, tmpSlots[2], "Übernehmen", function()
            handleChannelAction(true)
        end)
    end

    return {}
end

local function init()
    system.registerSystemTool({
        name = "Graupner Servo Converter",
        icon = icon,
        create = create,
    })
end

return { init = init }