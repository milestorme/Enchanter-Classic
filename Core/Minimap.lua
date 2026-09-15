local EC = Enchanter_Addon
if not EC then return end

local BROKER_NAME = "Enchanter"
local ICON = "Interface\\AddOns\\Enchanter\\Media\\enchanter_icon"

local function OpenOptions()
    if EC.OptionsBuilder and EC.OptionsBuilder.OpenCategoryPanel then
        EC.OptionsBuilder.OpenCategoryPanel(1)
    end
end

local function Scan()
    if EC.ScanPending then
        print("|cFFFFD100Enchanter:|r A recipe scan is already in progress.")
        return
    end
    EC.GetItems()
end

function EC.InitMinimap()
    if EC.MinimapInitialized then return end
    local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    local DBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not LDB or not DBIcon then
        print("|cFFFF1C1CEnchanter:|r Minimap libraries failed to load.")
        return
    end

    EC.DB.Minimap = EC.DB.Minimap or { minimapPos = 220 }
    EC.DB.Minimap.hide = false
    if type(EC.DB.Minimap.minimapPos) ~= "number" then EC.DB.Minimap.minimapPos = 220 end

    local broker = LDB:NewDataObject(BROKER_NAME, {
        type = "launcher",
        icon = ICON,
        label = "Enchanter",
        OnClick = function(_, button)
            if button == "LeftButton" and IsShiftKeyDown() then
                Scan()
            elseif button == "LeftButton" then
                if EC.IsListening() then EC.StopListening(true) else EC.StartListening(true) end
            elseif button == "RightButton" then
                OpenOptions()
            elseif button == "MiddleButton" then
                if EC.OpenJournal then EC.OpenJournal() end
            end
        end,
        OnTooltipShow = function(tt)
            local listening = EC.IsListening()
            local status = listening and "|cFF33FF66Listening|r" or "|cFFFF5555Paused|r"
            local recipes = 0
            if EC.DBChar and EC.DBChar.RecipeList then
                for _ in pairs(EC.DBChar.RecipeList) do recipes = recipes + 1 end
            end
            tt:AddLine("Enchanter", 1, 0.82, 0)
            tt:AddLine("Status: " .. status, 1, 1, 1)
            tt:AddLine("Known enchants: |cFFFFFFFF" .. recipes .. "|r", 0.8, 0.8, 0.8)
            if EC.ScanPending then tt:AddLine("Recipe scan: |cFFFFFF00In progress|r", 1, 1, 1) end
            tt:AddLine(" ")
            tt:AddDoubleLine("Left-click", listening and "Stop listening" or "Start listening", 0.3, 1, 0.3, 1, 1, 1)
            tt:AddDoubleLine("Shift + Left-click", "Scan recipes", 0.3, 1, 0.3, 1, 1, 1)
            tt:AddDoubleLine("Middle-click", "Trade journal", 0.3, 1, 0.3, 1, 1, 1)
            tt:AddDoubleLine("Right-click", "Options", 0.3, 1, 0.3, 1, 1, 1)
            tt:AddLine("Drag to reposition", 0.65, 0.65, 0.65)
        end,
    })

    DBIcon:Register(BROKER_NAME, broker, EC.DB.Minimap)
    DBIcon:Show(BROKER_NAME)
    EC.MinimapBroker = broker
    EC.MinimapInitialized = true
end


-- Native AddOn Compartment support (Classic Era 1.15.9).  This is separate
-- from the LibDBIcon minimap button: users get both the normal draggable
-- minimap launcher and an entry in Blizzard's AddOn Compartment.
function Enchanter_OnAddonCompartmentClick(addonName, buttonName)
    if buttonName == "LeftButton" then
        if EC and EC.IsListening and EC.IsListening() then EC.StopListening(true) else EC.StartListening(true) end
    elseif buttonName == "RightButton" then
        OpenOptions()
    elseif buttonName == "MiddleButton" then
        if EC and EC.OpenJournal then EC.OpenJournal() end
    end
end

function Enchanter_OnAddonCompartmentEnter(addonName, menuButtonFrame)
    if not menuButtonFrame then return end
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:AddLine("Enchanter", 1, 0.82, 0)
    local listening = EC and EC.IsListening and EC.IsListening()
    GameTooltip:AddLine("Status: " .. (listening and "|cFF33FF66Listening|r" or "|cFFFF5555Paused|r"), 1, 1, 1)
    GameTooltip:AddLine("Left-click: Start / stop listening", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Middle-click: Trade journal", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Right-click: Options", 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function Enchanter_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- Defensive retry. Normally EC.Init() creates the button during ADDON_LOADED,
-- but this also recovers if another embedded library finishes initialising at login.
local minimapRetry = CreateFrame("Frame")
minimapRetry:RegisterEvent("PLAYER_LOGIN")
minimapRetry:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if EC and EC.DB and not EC.MinimapInitialized then EC.InitMinimap() end
end)
