local MAJOR, MINOR="LibDBIcon-1.0", 100
local lib=LibStub:NewLibrary(MAJOR,MINOR); if not lib then return end
lib.objects=lib.objects or {}; lib.pending=lib.pending or {}
local function position(btn)
 local a=math.rad((btn.db and btn.db.minimapPos) or 225); btn:ClearAllPoints(); btn:SetPoint("CENTER",Minimap,"CENTER",math.cos(a)*80,math.sin(a)*80)
end
local function create(name,obj,db)
 local b=CreateFrame("Button","LibDBIcon10_"..name,Minimap); b:SetSize(31,31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8); b:RegisterForClicks("anyUp"); b:RegisterForDrag("LeftButton"); b.dataObject=obj; b.db=db
 local bg=b:CreateTexture(nil,"BACKGROUND"); bg:SetSize(20,20); bg:SetPoint("CENTER"); bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
 local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetSize(18,18); icon:SetPoint("CENTER"); icon:SetTexture(obj.icon); b.icon=icon
 local border=b:CreateTexture(nil,"OVERLAY"); border:SetSize(53,53); border:SetPoint("TOPLEFT"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
 b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
 b:SetScript("OnClick",function(self,button) if obj.OnClick then obj.OnClick(self,button) end end)
 b:SetScript("OnEnter",function(self) if obj.OnTooltipShow then GameTooltip:SetOwner(self,"ANCHOR_LEFT"); obj.OnTooltipShow(GameTooltip); GameTooltip:Show() elseif obj.OnEnter then obj.OnEnter(self) end end)
 b:SetScript("OnLeave",function(self) GameTooltip:Hide(); if obj.OnLeave then obj.OnLeave(self) end end)
 local function drag(self) local mx,my=Minimap:GetCenter(); local x,y=GetCursorPosition(); local s=Minimap:GetEffectiveScale(); x,y=x/s,y/s; self.db.minimapPos=math.deg(math.atan2(y-my,x-mx))%360; position(self) end
 b:SetScript("OnDragStart",function(self) self:SetScript("OnUpdate",drag); GameTooltip:Hide() end); b:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil) end)
 lib.objects[name]=b; position(b); if db and db.hide then b:Hide() else b:Show() end
end
function lib:Register(name,obj,db) if self.objects[name] then return end; create(name,obj,db or {}) end
function lib:Show(name) local b=self.objects[name]; if b then b.db.hide=false; b:Show(); position(b) end end
function lib:Hide(name) local b=self.objects[name]; if b then b.db.hide=true; b:Hide() end end
function lib:Refresh(name,db) local b=self.objects[name]; if b then b.db=db or b.db; position(b); if b.db.hide then b:Hide() else b:Show() end end end
function lib:IsRegistered(name) return self.objects[name]~=nil end
function lib:GetMinimapButton(name) return self.objects[name] end
