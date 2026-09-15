assert(LibStub and LibStub("CallbackHandler-1.0",true),"LibDataBroker-1.1 requires LibStub and CallbackHandler-1.0")
local lib,old=LibStub:NewLibrary("LibDataBroker-1.1",4); if not lib then return end
lib.callbacks=lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib); lib.objects=lib.objects or {}
function lib:NewDataObject(name,obj) if self.objects[name] then return self.objects[name] end; obj=obj or {}; self.objects[name]=obj; self.callbacks:Fire("LibDataBroker_DataObjectCreated",name,obj); return obj end
function lib:GetDataObjectByName(name) return self.objects[name] end
function lib:DataObjectIterator() return pairs(self.objects) end
