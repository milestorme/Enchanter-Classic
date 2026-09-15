local MAJOR, MINOR = "CallbackHandler-1.0", 8
local CH = LibStub:NewLibrary(MAJOR, MINOR); if not CH then return end
function CH:New(target)
 local events={}
 function target.RegisterCallback(self,event,method)
  events[event]=events[event] or {}; local f=method or event
  if type(f)=="string" then events[event][self]=function(...) self[f](self,...) end else events[event][self]=f end
 end
 function target.UnregisterCallback(self,event) if events[event] then events[event][self]=nil end end
 function target.UnregisterAllCallbacks(self) for _,t in pairs(events) do t[self]=nil end end
 return {Fire=function(_,event,...) if events[event] then for _,f in pairs(events[event]) do securecallfunction(f,event,...) end end end}
end
