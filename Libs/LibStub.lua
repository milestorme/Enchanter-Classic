local MAJOR, MINOR = "LibStub", 2
local LibStub = _G[MAJOR]
if not LibStub or LibStub.minor < MINOR then
 LibStub = LibStub or {libs={}, minors={}}; _G[MAJOR]=LibStub; LibStub.minor=MINOR
 function LibStub:NewLibrary(major, minor) minor=assert(tonumber(tostring(minor):match("%d+"))); local old=self.minors[major]; if old and old>=minor then return nil end; self.minors[major]=minor; self.libs[major]=self.libs[major] or {}; return self.libs[major],old end
 function LibStub:GetLibrary(major,silent) if not self.libs[major] and not silent then error(("Cannot find a library instance of %q."):format(tostring(major)),2) end; return self.libs[major],self.minors[major] end
 function LibStub:IterateLibraries() return pairs(self.libs) end
 setmetatable(LibStub,{__call=LibStub.GetLibrary})
end
