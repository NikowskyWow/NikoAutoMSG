-- [[ NIKO AUTOMSG - WRATH OF THE LICH KING 3.3.5a ]]
-- Author: Nikowsky (Kokotiar / Jebly)
-- Design System: Niko Addon Design System

local NIKO_VERSION = "1.2.0"
local ADDON_NAME = "NikoAutoMSG"

-- Inicializácia globálnej tabuľky sa robí až v ADDON_LOADED,
-- aby sme najprv mohli prevziať staré dáta zo SausageAutomsgDB (migrácia).

local currentTab = 1
local isMasterRunning = false
local timers = {0, 0, 0, 0}
local nextIntervals = {60, 60, 60, 60} -- aktualny interval s jitterom pre kazdy slot
local tabButtons = {}

-- Minimalny povoleny interval (ochrana proti spam-mute na serveri)
local MIN_INTERVAL = 30

-- Anti-Spam Fronta
local messageQueue = {}
local queueTimer = 0
local QUEUE_DELAY = 1.5 -- Čakanie 1.5 sekundy medzi jednotlivými správami

-- Predbezne deklaracie (definovane nizsie, referencovane skorej)
local LoadTab, UpdateSaveButtonState, ApplyMinimapShown, RefreshMinimapCB, UpdateCharCounter
local editBox, intervalInput, saveBtn
local cbCh1, cbCh2, cbCh3, cbCh4, cbCh5, cbCh6, cbSay, cbYell
local enableCheck

-- Vrati interval s nahodnym jitterom +/-10% (menej "botovity" vzhlad)
local function JitteredInterval(baseInterval)
    local base = tonumber(baseInterval) or 60
    if base < MIN_INTERVAL then base = MIN_INTERVAL end
    local jitter = base * 0.1
    return base + (math.random() * 2 - 1) * jitter
end

-- Helper funkcia na generovanie čistého slotu
local function GetDefaultSlot()
    return {
        enabled = false,
        text = "",
        interval = 60,
        channels = { SAY = false, YELL = false, CH1 = false, CH2 = false, CH3 = false, CH4 = false, CH5 = false, CH6 = false }
    }
end

-- Vizuálna funkcia na prefarbovanie Tabov
local function UpdateTabVisuals()
    if not NikoAutoMSGDB.slots then return end
    for i = 1, 4 do
        if NikoAutoMSGDB.slots[i] and NikoAutoMSGDB.slots[i].enabled then
            tabButtons[i]:SetText("|cff00ff00Msg " .. i .. "|r")
        else
            tabButtons[i]:SetText("|cffffd200Msg " .. i .. "|r")
        end
    end
end

-- [[ UI UTILS ]]
local function CreateNikoBackdrop(frame, borderType)
    local borderColor = {0.6, 0.6, 0.6, 1}
    if borderType == "GOLD" then borderColor = {1, 0.8, 0, 1}
    elseif borderType == "BLUE" then borderColor = {0, 0.7, 1, 1} end

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(unpack(borderColor))
end

local function GetActiveChannelName(index)
    local channels = {GetChannelList()}
    for i = 1, #channels, 2 do
        if channels[i] == index then
            return channels[i] .. ". " .. channels[i+1]
        end
    end
    return index .. ". (Not connected)"
end

-- [[ MAIN FRAME ]]
local MainFrame = CreateFrame("Frame", "NikoAutoMSGFrame", UIParent)
MainFrame:SetSize(420, 545)
MainFrame:SetPoint("CENTER")
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
MainFrame:SetBackdropColor(1, 1, 1, 1)
tinsert(UISpecialFrames, "NikoAutoMSGFrame")
MainFrame:Hide()

-- Header
local header = MainFrame:CreateTexture(nil, "OVERLAY")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(320, 64)
header:SetPoint("TOP", 0, 12)

local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("Niko Automsg")

local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -8, -8)

-- [[ SHOW MINIMAP BUTTON CHECKBOX (hore) ]]
local minimapCheck = CreateFrame("CheckButton", "NikoAutoMSGMinimapCheck", MainFrame, "UICheckButtonTemplate")
minimapCheck:SetSize(22, 22)
minimapCheck:SetPoint("TOPLEFT", 18, -34)
local minimapCheckText = minimapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
minimapCheckText:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
minimapCheckText:SetText("Show Minimap Button")
minimapCheck:SetScript("OnClick", function(self)
    NikoAutoMSGDB.minimapShown = self:GetChecked() and true or false
    ApplyMinimapShown()
end)

-- [[ TABS ]]
for i = 1, 4 do
    local btn = CreateFrame("Button", "NikoAutoMSGTab"..i, MainFrame, "UIPanelButtonTemplate")
    btn:SetSize(80, 25)
    btn:SetPoint("TOPLEFT", 18 + ((i-1)*90), -64)
    btn:SetText("|cffffd200Msg " .. i .. "|r")
    btn:SetScript("OnClick", function() LoadTab(i) end)
    tabButtons[i] = btn
end

-- NEZÁVISLÝ VYPÍNAČ (Enable Checkbox)
enableCheck = CreateFrame("CheckButton", "NikoAutoMSGEnableCheck", MainFrame, "UICheckButtonTemplate")
enableCheck:SetPoint("TOPLEFT", 25, -99)
local enableCheckText = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableCheckText:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)

enableCheck:SetScript("OnClick", function(self)
    if NikoAutoMSGDB.slots and NikoAutoMSGDB.slots[currentTab] then
        local isChecked = self:GetChecked() and true or false
        NikoAutoMSGDB.slots[currentTab].enabled = isChecked
        
        UpdateTabVisuals()
        
        local stateText = isChecked and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cff33ff99Niko AutoMSG:|r Broadcasting for Msg " .. currentTab .. " is " .. stateText)
    end
end)

-- [[ CONTENT BOXES ]]
-- Message Input Box
local msgContainer = CreateFrame("Frame", nil, MainFrame)
msgContainer:SetSize(370, 120)
msgContainer:SetPoint("TOP", 0, -134)
CreateNikoBackdrop(msgContainer, "BLUE")
msgContainer:EnableMouse(true)

local scrollFrame = CreateFrame("ScrollFrame", "NikoAutoMSGScroll", msgContainer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)

editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetMaxLetters(255)
editBox:SetFontObject(ChatFontNormal)
editBox:SetWidth(330)
editBox:SetAutoFocus(false)
scrollFrame:SetScrollChild(editBox)

msgContainer:SetScript("OnMouseDown", function() editBox:SetFocus() end)
editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Pocitadlo znakov (napr. 123/255) pod textovym polom
local charCounter = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
charCounter:SetPoint("TOPRIGHT", msgContainer, "BOTTOMRIGHT", -2, -2)
UpdateCharCounter = function()
    local len = editBox:GetText():len()
    local r, g, b = 0.7, 0.7, 0.7
    if len >= 240 then r, g, b = 1, 0.4, 0.4 end -- blizko limitu -> cervena
    charCounter:SetText(len .. "/255")
    charCounter:SetTextColor(r, g, b)
end

-- Zmena textu -> aktualizuj pocitadlo aj "unsaved" indikator
editBox:SetScript("OnTextChanged", function()
    UpdateCharCounter()
    UpdateSaveButtonState()
end)

-- Settings Box (Interval & Channels)
local settingsBox = CreateFrame("Frame", nil, MainFrame)
settingsBox:SetSize(370, 180)
settingsBox:SetPoint("TOP", msgContainer, "BOTTOM", 0, -16) -- priestor pre pocitadlo znakov
CreateNikoBackdrop(settingsBox, "GRAY")

-- Interval
local intervalLabel = settingsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
intervalLabel:SetPoint("TOPLEFT", 15, -15)
intervalLabel:SetText("Interval (seconds):")

intervalInput = CreateFrame("EditBox", "NikoAutoMSGIntervalInput", settingsBox, "InputBoxTemplate")
intervalInput:SetSize(60, 20)
intervalInput:SetPoint("LEFT", intervalLabel, "RIGHT", 10, 0)
intervalInput:SetNumeric(true)
intervalInput:SetAutoFocus(false)
intervalInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Channels Checkboxes Setup
local function CreateChannelCheck(name, defaultLabel, x, y)
    local cb = CreateFrame("CheckButton", "NikoAutoMSGCB_"..name, settingsBox, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName().."Text"]:SetText(defaultLabel)
    return cb
end

-- 2 Stĺpce kanálov
cbCh1 = CreateChannelCheck("CH1", "Channel 1", 15, -45)
cbCh2 = CreateChannelCheck("CH2", "Channel 2", 15, -70)
cbCh3 = CreateChannelCheck("CH3", "Channel 3", 15, -95)
cbCh4 = CreateChannelCheck("CH4", "Channel 4", 15, -120)

cbCh5 = CreateChannelCheck("CH5", "Channel 5", 180, -45)
cbCh6 = CreateChannelCheck("CH6", "Channel 6", 180, -70)
cbSay = CreateChannelCheck("SAY", "Say", 180, -95)
cbYell = CreateChannelCheck("YELL", "Yell", 180, -120)

-- MASTER SAVE TLAČIDLO
saveBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(100, 25)
saveBtn:SetPoint("TOPRIGHT", msgContainer, "TOPRIGHT", 0, 30)
saveBtn:SetText("Save Text")

-- Zisti, ci sa aktualny UI stav lisi od ulozeneho slotu (unsaved changes)
local function IsSlotDirty()
    if type(NikoAutoMSGDB.slots) ~= "table" or not NikoAutoMSGDB.slots[currentTab] then return false end
    local slot = NikoAutoMSGDB.slots[currentTab]
    if editBox:GetText() ~= (slot.text or "") then return true end
    if (tonumber(intervalInput:GetText()) or 60) ~= (tonumber(slot.interval) or 60) then return true end
    local ui = {
        CH1 = cbCh1:GetChecked() and true or false, CH2 = cbCh2:GetChecked() and true or false,
        CH3 = cbCh3:GetChecked() and true or false, CH4 = cbCh4:GetChecked() and true or false,
        CH5 = cbCh5:GetChecked() and true or false, CH6 = cbCh6:GetChecked() and true or false,
        SAY = cbSay:GetChecked() and true or false, YELL = cbYell:GetChecked() and true or false,
    }
    for k, v in pairs(ui) do
        if (slot.channels[k] and true or false) ~= v then return true end
    end
    return false
end

-- Vizualne oznac "Save Text" ak su neulozene zmeny
UpdateSaveButtonState = function()
    if IsSlotDirty() then
        saveBtn:SetText("Save Text |cffffd200*|r")
    else
        saveBtn:SetText("Save Text")
    end
end

saveBtn:SetScript("OnClick", function()
    if NikoAutoMSGDB.slots and NikoAutoMSGDB.slots[currentTab] then
        local slot = NikoAutoMSGDB.slots[currentTab]

        -- Interval floor: minimum MIN_INTERVAL sekund (ochrana proti spam-mute)
        local newInterval = tonumber(intervalInput:GetText()) or 60
        if newInterval < MIN_INTERVAL then
            newInterval = MIN_INTERVAL
            intervalInput:SetText(MIN_INTERVAL)
            print("|cff33ff99Niko AutoMSG:|r Interval raised to " .. MIN_INTERVAL .. "s minimum (anti-spam).")
        end

        slot.text = editBox:GetText()
        slot.interval = newInterval
        slot.channels.CH1 = cbCh1:GetChecked() and true or false
        slot.channels.CH2 = cbCh2:GetChecked() and true or false
        slot.channels.CH3 = cbCh3:GetChecked() and true or false
        slot.channels.CH4 = cbCh4:GetChecked() and true or false
        slot.channels.CH5 = cbCh5:GetChecked() and true or false
        slot.channels.CH6 = cbCh6:GetChecked() and true or false
        slot.channels.SAY = cbSay:GetChecked() and true or false
        slot.channels.YELL = cbYell:GetChecked() and true or false

        editBox:ClearFocus()
        intervalInput:ClearFocus()
        UpdateSaveButtonState() -- zmaze "unsaved" oznacenie

        -- Upozorni, ak je vybrany kanal, ku ktoremu nie sme pripojeni
        local activeChannels = {GetChannelList()}
        for chNum = 1, 6 do
            if slot.channels["CH"..chNum] then
                local connected = false
                for i = 1, #activeChannels, 2 do
                    if activeChannels[i] == chNum then connected = true break end
                end
                if not connected then
                    print("|cff33ff99Niko AutoMSG:|r |cffff8800Warning:|r Channel " .. chNum ..
                        " is selected but you are not connected to it - it will be skipped.")
                end
            end
        end

        print("|cff33ff99Niko AutoMSG:|r Settings and text for Msg " .. currentTab .. " successfully saved.")
    end
end)

-- Zmena intervalu / kanalov -> aktualizuj "unsaved" indikator
intervalInput:HookScript("OnTextChanged", function() UpdateSaveButtonState() end)
for _, cb in ipairs({cbCh1, cbCh2, cbCh3, cbCh4, cbCh5, cbCh6, cbSay, cbYell}) do
    cb:HookScript("OnClick", function() UpdateSaveButtonState() end)
end

-- Linkovanie itemov (Shift-Click do EditBoxu)
hooksecurefunc("ChatEdit_InsertLink", function(text)
    if MainFrame:IsShown() and editBox:HasFocus() then
        editBox:Insert(text)
        return true
    end
end)

-- Obnova UI pri prepnutí Tabu
LoadTab = function(index)
    if type(NikoAutoMSGDB.slots) ~= "table" or not NikoAutoMSGDB.slots[index] then return end

    currentTab = index
    local slot = NikoAutoMSGDB.slots[index]

    for i=1, 4 do
        if i == index then tabButtons[i]:LockHighlight() else tabButtons[i]:UnlockHighlight() end
    end

    enableCheckText:SetText("|cffffd200Msg " .. index .. "|r - Enable broadcasting")
    enableCheck:SetChecked(slot.enabled)

    editBox:SetText(slot.text or "")
    intervalInput:SetText(slot.interval or 60)

    _G["NikoAutoMSGCB_CH1Text"]:SetText(GetActiveChannelName(1))
    _G["NikoAutoMSGCB_CH2Text"]:SetText(GetActiveChannelName(2))
    _G["NikoAutoMSGCB_CH3Text"]:SetText(GetActiveChannelName(3))
    _G["NikoAutoMSGCB_CH4Text"]:SetText(GetActiveChannelName(4))
    _G["NikoAutoMSGCB_CH5Text"]:SetText(GetActiveChannelName(5))
    _G["NikoAutoMSGCB_CH6Text"]:SetText(GetActiveChannelName(6))

    cbCh1:SetChecked(slot.channels.CH1)
    cbCh2:SetChecked(slot.channels.CH2)
    cbCh3:SetChecked(slot.channels.CH3)
    cbCh4:SetChecked(slot.channels.CH4)
    cbCh5:SetChecked(slot.channels.CH5)
    cbCh6:SetChecked(slot.channels.CH6)
    cbSay:SetChecked(slot.channels.SAY)
    cbYell:SetChecked(slot.channels.YELL)

    UpdateCharCounter()      -- obnov pocitadlo znakov
    UpdateSaveButtonState()  -- vynuluj "unsaved" indikator (UI == ulozeny stav)
end

MainFrame:SetScript("OnShow", function() LoadTab(currentTab) end)

-- [[ ENGINE - LOGIKA ODOSIELANIA (ANTI-SPAM QUEUE) ]]
local function EnqueueMessage(msgText, chatType, channelIndex)
    table.insert(messageQueue, {
        text = msgText,
        chatType = chatType,
        channelIndex = channelIndex
    })
end

local function SendSlotAdvert(slotIndex)
    local slot = NikoAutoMSGDB.slots[slotIndex]
    local text = slot.text
    if text == "" then return end

    -- Namiesto okamžitého odoslania, zaradíme správy do fronty
    if slot.channels.SAY then EnqueueMessage(text, "SAY") end
    if slot.channels.YELL then EnqueueMessage(text, "YELL") end
    
    local activeChannels = {GetChannelList()}
    for chNum = 1, 6 do
        if slot.channels["CH"..chNum] then
            for i = 1, #activeChannels, 2 do
                if activeChannels[i] == chNum then
                    EnqueueMessage(text, "CHANNEL", chNum)
                    break
                end
            end
        end
    end
end

local EngineFrame = CreateFrame("Frame")

-- Zapne OnUpdate iba ked je co robit (master bezi alebo je fronta neprazdna)
local function StartEngineLoop()
    EngineFrame:Show()
end
local function StopEngineLoopIfIdle()
    if not isMasterRunning and #messageQueue == 0 then
        EngineFrame:Hide() -- ziadna praca -> ziadny OnUpdate kazdy frame
    end
end

local function EngineTick(self, elapsed)
    -- 1. Spracovanie Queue (Odosielanie s oneskorením 1.5s)
    if #messageQueue > 0 then
        queueTimer = queueTimer + elapsed
        if queueTimer >= QUEUE_DELAY then
            local msg = table.remove(messageQueue, 1)
            -- msg.channelIndex je nil pre SAY/YELL, inak číslo kanálu
            SendChatMessage(msg.text, msg.chatType, nil, msg.channelIndex)
            queueTimer = 0
        end
    else
        queueTimer = 0
    end

    -- 2. Kontrola intervalov a pridávanie do Queue
    if isMasterRunning and NikoAutoMSGDB and type(NikoAutoMSGDB.slots) == "table" then
        for i = 1, 4 do
            local slot = NikoAutoMSGDB.slots[i]
            if slot and slot.enabled and slot.text ~= "" then
                timers[i] = timers[i] + elapsed
                if timers[i] >= nextIntervals[i] then
                    SendSlotAdvert(i)
                    timers[i] = 0
                    nextIntervals[i] = JitteredInterval(slot.interval) -- novy jitter pre dalsi cyklus
                end
            end
        end
    end

    -- Ak uz nie je co robit, vypni OnUpdate slucku
    StopEngineLoopIfIdle()
end
EngineFrame:SetScript("OnUpdate", EngineTick)
EngineFrame:Hide() -- default: nic nebezi, slucka je vypnuta

-- [[ MASTER START/STOP BUTTON ]]
local startBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
startBtn:SetSize(140, 35)
startBtn:SetPoint("BOTTOMLEFT", 25, 45)
startBtn:SetText("MASTER START")

-- Zisti, ci existuje aspon jeden pouzitelny slot (enabled + text)
local function HasActiveSlot()
    if type(NikoAutoMSGDB.slots) ~= "table" then return false end
    for i = 1, 4 do
        local slot = NikoAutoMSGDB.slots[i]
        if slot and slot.enabled and slot.text ~= "" then return true end
    end
    return false
end

startBtn:SetScript("OnClick", function(self)
    if not isMasterRunning then
        -- Pred spustenim over, ci je vobec co vysielat
        if not HasActiveSlot() then
            print("|cff33ff99Niko AutoMSG:|r |cffff8800Nothing to broadcast|r - enable a message with text first.")
            return
        end
        isMasterRunning = true
        self:SetText("|cff00ff00MASTER STOP|r")
        self:LockHighlight()
        -- Prvy cyklus okamzite, potom jitterovany interval
        for i = 1, 4 do
            timers[i] = 999
            if NikoAutoMSGDB.slots and NikoAutoMSGDB.slots[i] then
                nextIntervals[i] = JitteredInterval(NikoAutoMSGDB.slots[i].interval)
            end
        end
        StartEngineLoop()
        print("|cff33ff99Niko AutoMSG:|r Automsg Engine |cff00ff00STARTED|r")
    else
        isMasterRunning = false
        self:SetText("MASTER START")
        self:UnlockHighlight()
        messageQueue = {} -- Fail-safe: Vycistí frontu akonáhle zastavíš engine
        StopEngineLoopIfIdle()
        print("|cff33ff99Niko AutoMSG:|r Automsg Engine |cffff0000STOPPED|r")
    end
end)

-- [[ UPDATE / GITHUB CUSTOM FRAME ]]
local GitFrame = CreateFrame("Frame", "NikoAutoMSGGitFrame", UIParent)
GitFrame:SetSize(320, 130)
GitFrame:SetPoint("CENTER")
GitFrame:SetFrameStrata("DIALOG")
GitFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
tinsert(UISpecialFrames, "NikoAutoMSGGitFrame")
GitFrame:Hide()

local gitHeader = GitFrame:CreateTexture(nil, "OVERLAY")
gitHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
gitHeader:SetSize(250, 64)
gitHeader:SetPoint("TOP", 0, 12)

local gitTitle = GitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gitTitle:SetPoint("TOP", gitHeader, "TOP", 0, -14)
gitTitle:SetText("UPDATE LINK")

local gitClose = CreateFrame("Button", nil, GitFrame, "UIPanelCloseButton")
gitClose:SetPoint("TOPRIGHT", -8, -8)

local gitDesc = GitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gitDesc:SetPoint("TOP", 0, -35)
gitDesc:SetText("Press Ctrl+C to copy the GitHub link:")

local gitEditBox = CreateFrame("EditBox", nil, GitFrame, "InputBoxTemplate")
gitEditBox:SetSize(260, 20)
gitEditBox:SetPoint("TOP", gitDesc, "BOTTOM", 0, -15)
gitEditBox:SetAutoFocus(true)

local GITHUB_LINK = "https://github.com/NikowskyWow/NikoAutoMSG/releases"

gitEditBox:SetScript("OnTextChanged", function(self)
    if self:GetText() ~= GITHUB_LINK then
        self:SetText(GITHUB_LINK)
        self:HighlightText()
    end
end)

gitEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    GitFrame:Hide()
end)

GitFrame:SetScript("OnShow", function()
    gitEditBox:SetText(GITHUB_LINK)
    gitEditBox:SetFocus()
    gitEditBox:HighlightText()
end)

-- [[ FOOTER ]]
local verText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
verText:SetPoint("BOTTOMLEFT", 20, 15)
verText:SetText("v" .. NIKO_VERSION)

local creditText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
creditText:SetPoint("BOTTOM", 0, 15)
creditText:SetText("by Nikowsky")

local updateBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
updateBtn:SetSize(110, 25)
updateBtn:SetPoint("BOTTOMRIGHT", -20, 15)
updateBtn:SetText("Check Updates")
updateBtn:SetScript("OnClick", function()
    GitFrame:Show()
end)

-- [[ MINIMAP ICON ]]
local MinimapBtn = CreateFrame("Button", "NikoAutoMSGMinimap", Minimap)
MinimapBtn:SetSize(31, 31)
MinimapBtn:SetFrameStrata("MEDIUM")
MinimapBtn:SetFrameLevel(8)
MinimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = MinimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Inv_Misc_Food_54")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT")
border:SetVertexColor(1, 0.6, 0) -- oranzovy okraj ikony

local function UpdateMinimapPos()
    local angle = math.rad(NikoAutoMSGDB.minimapPos or 45)
    MinimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

-- Zobrazi/skryje minimap ikonu podla nastavenia
ApplyMinimapShown = function()
    if NikoAutoMSGDB.minimapShown == false then
        MinimapBtn:Hide()
    else
        MinimapBtn:Show()
    end
end

-- Zosynchronizuje checkbox v okne so stavom nastavenia
RefreshMinimapCB = function()
    minimapCheck:SetChecked(NikoAutoMSGDB.minimapShown ~= false)
end

MinimapBtn:RegisterForDrag("RightButton")
MinimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        local scale = Minimap:GetEffectiveScale()
        xpos = (xpos / scale) - xmin - 70
        ypos = (ypos / scale) - ymin - 70
        local angle = math.deg(math.atan2(ypos, xpos))
        if angle < 0 then angle = angle + 360 end
        NikoAutoMSGDB.minimapPos = angle
        UpdateMinimapPos()
    end)
end)
MinimapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)
MinimapBtn:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" then
        if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
    end
end)

-- [[ INITIALIZATION ]]
MainFrame:RegisterEvent("ADDON_LOADED")
MainFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == ADDON_NAME then
        -- Jednorazová migrácia zo starého SausageAutomsg na NikoAutoMSG (zachová nastavenia)
        if not NikoAutoMSGDB and SausageAutomsgDB then
            NikoAutoMSGDB = SausageAutomsgDB
            SausageAutomsgDB = nil
        end
        if not NikoAutoMSGDB then NikoAutoMSGDB = {} end

        NikoAutoMSGDB.minimapPos = NikoAutoMSGDB.minimapPos or 45
        if NikoAutoMSGDB.minimapShown == nil then NikoAutoMSGDB.minimapShown = true end

        if type(NikoAutoMSGDB.slots) ~= "table" then
            NikoAutoMSGDB.slots = { GetDefaultSlot(), GetDefaultSlot(), GetDefaultSlot(), GetDefaultSlot() }
        else
            for i = 1, 4 do
                if type(NikoAutoMSGDB.slots[i]) ~= "table" then
                    NikoAutoMSGDB.slots[i] = GetDefaultSlot()
                else
                    if type(NikoAutoMSGDB.slots[i].channels) ~= "table" then
                        NikoAutoMSGDB.slots[i].channels = GetDefaultSlot().channels
                    end
                end
            end
        end

        UpdateMinimapPos()
        ApplyMinimapShown()
        RefreshMinimapCB()
        UpdateTabVisuals()
        LoadTab(1)

        -- Slash command na prepnutie okna
        SLASH_NIKOAUTOMSG1 = "/nikoautomsg"
        SlashCmdList["NIKOAUTOMSG"] = function()
            if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
        end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)