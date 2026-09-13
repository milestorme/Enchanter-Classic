local TOCNAME,EC=...
Enchanter_Addon=EC


EC.Initalized = false
EC.PlayerList = {}
EC.LfRecipeList = {}
EC.SessionGold = 0
local preTradeGold = nil
EC.EnchanterTags = EC.DefaultEnchanterTags
EC.PrefixTags = EC.DefaultPrefixTags
EC.RecipeTags = EC.DefaultRecipeTags
EC.RecipesWithNether = {"Enchant Boots - Surefooted"}
EC.PrefixTagsCompiled = {}
EC.BlacklistCompiled = {}
EC.RecipeTagsMap = {}
EC.RecipeTagList = {}
-- Scans the users known recipes and stores them
-- Additionally it also stores the recipes clickable link, that will be used when messaging the user (for those people asks what are the mats?)
-- NOTE: GetCraftRecipeLink() can return nil for a recipe if the client hasn't
-- finished loading that recipe's link data yet - but for a small number of
-- recipes (older/superseded formulas) it can also just never return a link
-- at all, no matter how long you wait. When that happens we fall back to a
-- plain-text materials list built from the reagent API (see below), which
-- doesn't depend on the same caching quirk, so mats still get whispered
-- correctly even without a clickable formula link.
local function BuildReagentText(index)
	if type(GetCraftNumReagents) ~= "function" or type(GetCraftReagentInfo) ~= "function" then
		return nil
	end

	local ok, numReagents = pcall(GetCraftNumReagents, index)
	if not ok or not numReagents or numReagents == 0 then return nil end

	local parts = {}
	for r = 1, numReagents do
		local okR, reagentName, _, numRequired = pcall(GetCraftReagentInfo, index, r)
		if okR and reagentName then
			table.insert(parts, (numRequired and numRequired > 0) and (numRequired .. "x " .. reagentName) or reagentName)
		end
	end

	if #parts == 0 then return nil end
	return table.concat(parts, ", ")
end

local function TryForceCraftSelect(index)
	if type(CraftFrame_SelectCraft) == "function" then
		if pcall(CraftFrame_SelectCraft, index) then return end
	end
	if type(CraftFrame_SetSelection) == "function" then
		if pcall(CraftFrame_SetSelection, index) then return end
	end
	if CraftFrame and type(CraftFrame_Update) == "function" then
		pcall(function()
			CraftFrame.selectedSkill = index
			CraftFrame_Update()
		end)
	end
	if type(GetCraftItemLink) == "function" then
		pcall(GetCraftItemLink, index)
	end
end

local function ScanCraftLinksOnce(verbose)
	local stillPending = false -- recipes that might just need more time
	local linkless = {}        -- recipes recorded, but with no link (ever)

	for i = 1, GetNumCrafts(), 1 do
		local craftName = GetCraftInfo(i)
		local tag = EC.RecipeTags["enGB"][craftName]
		if tag ~= nil then
			local link = GetCraftRecipeLink(i)
			if not link then
				TryForceCraftSelect(i)
				link = GetCraftRecipeLink(i)
			end
			EC.DBChar.RecipeList[craftName] = tag
			if link then
				EC.DBChar.RecipeLinks[craftName] = link
				EC.DBChar.RecipeMats[craftName] = nil
			else
				stillPending = true
				table.insert(linkless, craftName)
				EC.DBChar.RecipeMats[craftName] = BuildReagentText(i)
			end
		end
	end

	if verbose and #linkless > 0 then
		print(string.format("|cFF00CCFF Enchanter debug:|r %d total crafts, %d without a clickable link.", GetNumCrafts(), #linkless))
		print("|cFF00CCFF Enchanter debug:|r no link: " .. table.concat(linkless, ", "))
	end

	return stillPending, linkless
end

local function FinishScan(linkless)
	if not EC.ScanPending then return end -- already finished
	EC.ScanPending = false

	if EC.DB.NetherRecipes then
		for _, v in pairs(EC.RecipesWithNether) do
			EC.DBChar.RecipeList[v] = nil
		end
	end

	-- Restore whatever recipe was actually selected before we started
	-- force-selecting rows to coax their link data loose.
	if EC.PreScanSelection then
		TryForceCraftSelect(EC.PreScanSelection)
		EC.PreScanSelection = nil
	end

	print("Scan Completed")
	if linkless and #linkless > 0 then
		print("|cFFFFD100 Enchanter:|r note: " .. #linkless .. " recipe(s) have no clickable formula link (will still work, just shown as plain text when whispering mats): " .. table.concat(linkless, ", "))
	end
end

local function PollScan(attemptsLeft)
	if not EC.ScanPending then return end

	local stillPending, linkless = false, {}
	if GetNumCrafts() > 0 then
		stillPending, linkless = ScanCraftLinksOnce()
	end

	if not stillPending then
		FinishScan(linkless)
		return
	end

	if attemptsLeft > 0 then
		C_Timer.After(0.5, function() PollScan(attemptsLeft - 1) end)
	else
		FinishScan(linkless) -- give up waiting on the stragglers, but still complete successfully
	end
end

local function CheckScan()
	if not EC.ScanPending then return end
	if GetNumCrafts() == 0 then return end
	local stillPending, linkless = ScanCraftLinksOnce()
	if not stillPending then
		FinishScan(linkless)
	end
end

local function Event_CRAFT_SHOW()
	if EC.ScanPending and not EC.ScanStarted then
		EC.ScanStarted = true
		PollScan(6) -- ~3 seconds of polling for any recipes that just need a moment
	end
end

local function Event_GET_ITEM_INFO_RECEIVED()
	CheckScan() -- data just arrived; check if that was the last piece we needed
end

function EC.GetItems()
	EC.DBChar.RecipeList = {}
	EC.DBChar.RecipeLinks = {}
	EC.DBChar.RecipeMats = {}
	EC.ScanPending = true
	EC.ScanStarted = false
	EC.PreScanSelection = (CraftFrame and CraftFrame.selectedSkill) or nil

	CastSpellByName("Enchanting")

	-- Covers the case where the Enchanting window is already open, since
	-- CRAFT_SHOW won't fire again for a window that's not re-opening.
	if GetNumCrafts() > 0 then
		EC.ScanStarted = true
		PollScan(6)
	end

	-- Safety net: if the window never opens at all (e.g. cast failed),
	-- CRAFT_SHOW never fires and nothing above would ever report back.
	C_Timer.After(8, function()
		if EC.ScanPending then
			EC.ScanPending = false
			print("|cFFFF1C1C Enchanter:|r couldn't detect the Enchanting window opening. Make sure it's open and run /ec scan again.")
		end
	end)
end

function EC.Init()

	-- Initalize options
	if not EnchanterDB then EnchanterDB = {} end -- fresh DB
	if not EnchanterDBChar then EnchanterDBChar = {} end -- fresh DB
	
	EC.DB=EnchanterDB
	EC.DBChar=EnchanterDBChar

	-- Initialize DB Variables if not set
	if not EC.DBChar.RecipeList then EC.DBChar.RecipeList = {} end
	if not EC.DBChar.RecipeLinks then EC.DBChar.RecipeLinks = {} end
	if not EC.DBChar.RecipeMats then EC.DBChar.RecipeMats = {} end
	if not EC.DB.Custom then EC.DB.Custom={} end
	if not EC.DBChar.Stop then EC.DBChar.Stop = false end
	if not EC.DBChar.Debug then EC.DBChar.Debug = false end

	EC.Tool.SlashCommand({"/ec", "/enchanter", "/e"},{
		{"scan","MUST BE RAN PRIOR TO /ee start. Scans and stores your enchanting recipes to be used when filter for requests. NOTE: You need to rerun this when you learn new recipes",function()
			EC.GetItems()
			end},
		{{"stop", "pause"},"Pauses addon",function()
			EC.DBChar.Stop = true
			print("Paused")
		end},
		{"start","Starts the addon. It will begin parsing chat looking for requests",function()
			EC.DBChar.Stop = false
			print("Started...")
		end},
		{{"default", "reset"},"Resets everything to default values",function()
			EC.Default()
			EC.UpdateTags()
			print("Reset complete")
		end},
		{{"config","setup","options"},"Settings",function()
			if EC.OptionsBuilder and EC.OptionsBuilder.OpenCategoryPanel then
				EC.OptionsBuilder.OpenCategoryPanel(1)
			end
		end,1},
		{"debug","Enables/Disabled debug messages",function()
			if EC.DBChar.Debug== true then
				EC.DBChar.Debug = false
				print("Debug mode is now off")
			else 
				EC.DBChar.Debug = true
				print("Debug mode is now on")
			end
		end},
		{"summary","Prints total gold earned from trades this session",function()
			local total = EC.SessionGold
			local gold   = math.floor(total / 10000)
			local silver = math.floor((total % 10000) / 100)
			local copper = total % 100
			print("|cFFFF1C1CEnchanter|r Session Earnings: "
				.. "|cFFFFD700" .. gold   .. "g|r "
				.. "|cFFC0C0C0" .. silver .. "s|r "
				.. "|cFFB87333" .. copper .. "c|r")
		end},
		{{"about", "usage"},"You need to first run /ec scan this will store your known recipes and will be parsing chat for them (only need to do it 1 time or if you learned new recipes) after run /e start to start looking for requests"},
	})

	EC.OptionsInit()
	EC.InitPatterns() 
	EC.Initalized = true

	local function safeMeta(key)
		if EC and EC.Metadata and EC.Metadata[key] then return EC.Metadata[key] end
		if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata(TOCNAME, key) end
		if GetAddOnMetadata then return GetAddOnMetadata(TOCNAME, key) end
		return ""
	end

	print("|cFFFF1C1C Loaded: " .. (safeMeta("Title") or TOCNAME) .. " " .. (safeMeta("Version") or "") .. " by " .. (safeMeta("Author") or ""))
end

function EC.InitPatterns() 
	for _, v in pairs(EC.PrefixTags) do 
		table.insert(EC.PrefixTagsCompiled, "%f[%w_]" .. v .. "%f[^%w_]")
	end

	for _, v in pairs (EC.BlackList) do 
		table.insert(EC.BlacklistCompiled, "%f[%w_]" .. v .. "%f[^%w_]")
	end

	for k, v in pairs(EC.DBChar.RecipeList) do
		for k2, v2 in pairs(v) do
			EC.RecipeTagsMap [v2] = k
			table.insert(EC.RecipeTagList, v2)
		end
	end
	
end

-- Sends a msg with the enchanting links that enchanter is capable of doing
function EC.SendMsg(name)
		if EC.LfRecipeList[name] ~= nil then
			local msg = EC.DB.MsgPrefix
			for k, _ in pairs(EC.LfRecipeList[name]) do
				-- Fall back to name + plain-text materials if the link wasn't
				-- cached (e.g. scanned before the craft window fully loaded,
				-- or a recipe whose formula link never resolves), or just the
				-- plain name if we couldn't get materials either.
				if EC.DBChar.RecipeLinks[k] then
					msg = msg .. EC.DBChar.RecipeLinks[k]
				elseif EC.DBChar.RecipeMats and EC.DBChar.RecipeMats[k] then
					msg = msg .. k .. " (mats: " .. EC.DBChar.RecipeMats[k] .. ")"
				else
					msg = msg .. k
				end
			end
			if EC.DBChar.Debug == true then
				print("Debug mode: would whisper to " .. name .. ": " .. msg)
			else
				SendChatMessage(msg, "WHISPER", nil, name)
				--print("Debug mode: would whisper to " .. name .. ": " .. msg)
			end
			EC.LfRecipeList[name] = nil -- Clearing it so it doesn't growing larger unnecessarily 
		end
end

-- For a message it will attempt to filter the request based on any of the words in EC.PrefixTags
-- If the message contains any of those words it will then attempt to check if any of the users recipes(tags) are contained in the message
-- If their is, it will then invite and message the user with a link to all desired recipes that the enchanter is capable of doing
function EC.ParseMessage(msg, name)
	if EC.Initalized==false or name==nil or name=="" or msg==nil or msg=="" or string.len(msg)<4 or EC.DBChar.Stop == true then
		return
	end
	local msgParse = msg:lower()
	local isRequestValid = false
	for _, v in pairs(EC.PrefixTagsCompiled) do 
		if string.find(msgParse, v) then -- Important so it doesn't match things like LFW
			isRequestValid = true
			break
		end
	end

	for _, v in pairs (EC.BlacklistCompiled) do 
		if string.find(msgParse, v) then
			if EC.DBChar.Debug == true then
				print("Request: " .. msg .. " is being blacklisted due to tag: " .. v)
			end
			isRequestValid = false
			break
		end
	end

	if isRequestValid == false then return end
	local shouldInvite = false
	local alreadyInvited = false
	-- use precomputed tag list/map for faster lookup
	-- iterate over every known tag rather than scanning each recipe
	for _, tag in ipairs(EC.RecipeTagList) do
		if string.find(msgParse, tag, 1, true) then
			local recipe = EC.RecipeTagsMap[tag]
			if recipe then
				if not EC.LfRecipeList[name] then EC.LfRecipeList[name] = {} end
				if EC.DBChar.Debug == true then
					print("User should be invited for msg: " .. msg)
					print("Due to tag: " .. tag .. " -> recipe " .. tostring(recipe))
				end
				shouldInvite = true
				EC.LfRecipeList[name][recipe] = tag
				if alreadyInvited == false and EC.PlayerList[name] == nil and EC.DBChar.Debug ~= true and EC.DB.AutoInvite then
					C_Timer.After(EC.DB.InviteTimeDelay, function()  C_PartyInfo.InviteUnit(name) end)
					alreadyInvited = true
				end
			end
		end
	end
	
	if shouldInvite == true then
		-- This check is in case there is a bug and it wrongly matches we don't continue spamming invite to the same user every time they post
		if EC.PlayerList[name] == nil then 
			if EC.DBChar.Debug == true then
				print("Inviting Player: " .. name .. " for request: " .. msg)
			end

			EC.PlayerList[name] = 1

			if EC.DBChar.Debug ~= true then
				--C_PartyInfo.InviteUnit(name)
				-- Reason for whispering them before the join the group is in case they are already in a group
				EC.SendMsg(name)
			else
				print("Debug mode: suppressed Invite and Whisper to " .. name)
			end
		else
			-- Due to the laziness of keeping the whole recipe storage thing, this is an optimization to clear it for users that have already been invited
			EC.LfRecipeList[name] = nil
		end
	elseif EC.DB.WhisperLfRequests and isRequestValid and EC.PlayerList[name] == nil then
	
		local isGenericEnchantRequest = false
		local stripedMsg = string.gsub(msgParse, "%s+", "")
		for _, v in pairs(EC.EnchanterTags) do
			local stripedTag = string.gsub(v:lower(), "%s+", "")
			if stripedTag == stripedMsg then
				isGenericEnchantRequest = true
			end
		end

		if isGenericEnchantRequest then 
			EC.PlayerList[name] = 1
			C_Timer.After(EC.DB.WhisperTimeDelay, function() SendChatMessage(EC.DB.LfWhisperMsg, "WHISPER", nil, name) end)
		end
	end
end

local function Event_TRADE_SHOW()
	preTradeGold = GetMoney()
end

local function Event_TRADE_CLOSED()
	if preTradeGold ~= nil then
		local snapshot = preTradeGold
		preTradeGold = nil
		-- Defer by one frame: PLAYER_MONEY fires after TRADE_CLOSED,
		-- so GetMoney() here still returns the pre-trade value.
		C_Timer.After(1, function()
			local delta = GetMoney() - snapshot
			if delta > 0 then
				EC.SessionGold = EC.SessionGold + delta
			end
		end)
	end
end

-- NOTE: the old Event_CHAT_MSG_CHANNEL function is no longer used,
-- but it's left here in case something else referenced it; the chat
-- events are now handled via the filter above.
local function Event_CHAT_MSG_CHANNEL(msg,name,_3,_4,_5,_6,zoneChannelID,channelID,channel,_10,_11,guid)
	-- kept for compatibility; no registration occurs
	if not EC.Initalized or (zoneChannelID ~= 0 and zoneChannelID ~= 1 and zoneChannelID ~= 2) then return end
	EC.ParseMessage(msg, name)
end


local function Event_ADDON_LOADED(arg1)
	if arg1 == TOCNAME then
		EC.Init()
	end
end



function EC.OnLoad()
    EC.Tool.RegisterEvent("ADDON_LOADED",Event_ADDON_LOADED)
	EC.Tool.RegisterEvent("CHAT_MSG_CHANNEL",Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_SAY",Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("CHAT_MSG_YELL",Event_CHAT_MSG_CHANNEL)
	EC.Tool.RegisterEvent("TRADE_SHOW",Event_TRADE_SHOW)
	EC.Tool.RegisterEvent("TRADE_CLOSED",Event_TRADE_CLOSED)
	EC.Tool.RegisterEvent("CRAFT_SHOW",Event_CRAFT_SHOW)
	EC.Tool.RegisterEvent("GET_ITEM_INFO_RECEIVED",Event_GET_ITEM_INFO_RECEIVED)
end

