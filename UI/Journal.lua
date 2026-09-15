local EC = Enchanter_Addon
if not EC then return end

local ROWS = 18
local ROW_HEIGHT = 24
local journal, rows, offset = nil, {}, 0

local function MoneyText(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

local function PlayerText(entry)
    local name = entry.Player or "Unknown"
    local classToken = entry.Class
    local colors = classToken and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
    local color = colors and colors[classToken]
    if color then
        local hex
        if color.colorStr then
            hex = color.colorStr:sub(-6)
        else
            hex = string.format("%02x%02x%02x", math.floor((color.r or 1)*255+.5), math.floor((color.g or 1)*255+.5), math.floor((color.b or 1)*255+.5))
        end
        return "|cff" .. hex .. name .. "|r"
    end
    return name
end

local function History()
    return EC.DBChar and EC.DBChar.Earnings and EC.DBChar.Earnings.TradeHistory or {}
end

local function UpdateJournal()
    if not journal then return end
    local history = History()
    local maxOffset = math.max(0, #history - ROWS)
    offset = math.max(0, math.min(offset, maxOffset))
    journal.count:SetText(string.format("Showing latest %d of 1,000 trades", #history))

    local totalGold, totalTrades = 0, 0
    if EC.DBChar and EC.DBChar.Earnings then
        totalGold = EC.DBChar.Earnings.TotalGold or 0
        totalTrades = EC.DBChar.Earnings.TotalTrades or 0
    end
    journal.summary:SetText(string.format("Lifetime: %d trades  •  %s", totalTrades, MoneyText(totalGold)))

    for i = 1, ROWS do
        local row = rows[i]
        local entry = history[offset + i]
        if entry then
            row.entry = entry
            row.date:SetText(date("%d/%m/%y %H:%M", entry.Time or time()))
            row.player:SetText(PlayerText(entry))
            row.enchant:SetText(entry.Enchant or "Unknown enchant")
            row.gold:SetText(MoneyText(entry.Gold))
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    journal.scrollbar:SetMinMaxValues(0, maxOffset)
    journal.scrollbar:SetValue(offset)
    journal.scrollbar:SetShown(maxOffset > 0)
end

local function CreateJournal()
    if journal then return journal end
    local f = CreateFrame("Frame", "EnchanterJournalFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 570)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11}})

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Enchanter Journal")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.summary:SetPoint("TOPLEFT", 28, -50)
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("TOPRIGHT", -34, -52)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 24, -78); header:SetPoint("TOPRIGHT", -40, -78); header:SetHeight(26)
    local function H(text, x, width, justify)
        local fs=header:CreateFontString(nil,"OVERLAY","GameFontNormal"); fs:SetPoint("LEFT",x,0); fs:SetWidth(width); fs:SetJustifyH(justify or "LEFT"); fs:SetText(text)
    end
    H("Date / Time", 8, 130); H("Player", 148, 150); H("Enchant", 308, 285); H("Gold Made", 603, 95, "RIGHT")

    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 24, -106); list:SetPoint("BOTTOMRIGHT", -40, 34)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 3
        UpdateJournal()
    end)

    for i=1,ROWS do
        local r=CreateFrame("Button",nil,list)
        r:SetHeight(ROW_HEIGHT); r:SetPoint("TOPLEFT",0,-(i-1)*ROW_HEIGHT); r:SetPoint("RIGHT",0,0)
        if i % 2 == 0 then local bg=r:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,1,1,0.035) end
        local function C(x,w,justify)
            local fs=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); fs:SetPoint("LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH(justify or "LEFT"); fs:SetWordWrap(false); return fs
        end
        r.date=C(8,130); r.player=C(148,150); r.enchant=C(308,285); r.gold=C(603,95,"RIGHT")
        r:SetScript("OnEnter", function(self)
            if self.entry and self.entry.Enchant then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.entry.Enchant,1,1,1,true); GameTooltip:AddLine((self.entry.Player or "Unknown").." • "..MoneyText(self.entry.Gold),.8,.8,.8); GameTooltip:Show() end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i]=r
    end

    local sb=CreateFrame("Slider",nil,f,"UIPanelScrollBarTemplate")
    sb:SetPoint("TOPRIGHT",-20,-112); sb:SetPoint("BOTTOMRIGHT",-20,42); sb:SetValueStep(1); sb:SetObeyStepOnDrag(true)
    sb:SetScript("OnValueChanged",function(_,value) local n=math.floor(value+.5); if n~=offset then offset=n; UpdateJournal() end end)
    f.scrollbar=sb

    local hint=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); hint:SetPoint("BOTTOMLEFT",28,18); hint:SetText("Mouse wheel to scroll • /ec history or middle-click the minimap button to open")
    f:SetScript("OnShow",UpdateJournal)
    f:Hide(); journal=f; return f
end

function EC.OpenJournal()
    local f=CreateJournal()
    if f:IsShown() then f:Hide() else offset=0; f:Show(); UpdateJournal() end
end

function EC.RefreshJournal()
    if journal and journal:IsShown() then UpdateJournal() end
end
