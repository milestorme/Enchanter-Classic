local TOCNAME,EC=...
Enchanter_Addon=EC


EC.Initalized = false
EC.PlayerList = {}
EC.LfRecipeList = {}
EC.SessionGold = 0
EC.SessionTrades = 0
local preTradeGold = nil

-- Persistent earnings use aggregate totals plus a fixed-size session history.
-- We never store one record per trade, keeping SavedVariables small long-term.
local MAX_EARNINGS_SESSIONS = 100

local function FormatMoney(copper)
	copper = math.max(0, math.floor(copper or 0))
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local copperOnly = copper % 100
	return string.format("|cFFFFD700%dg|r |cFFC0C0C0%ds|r |cFFB87333%dc|r", gold, silver, copperOnly)
end

local function EnsureEarningsDB()
	if type(EC.DBChar.Earnings) ~= "table" then EC.DBChar.Earnings = {} end
	local db = EC.DBChar.Earnings
	if type(db.TotalGold) ~= "number" then db.TotalGold = 0 end
	if type(db.TotalTrades) ~= "number" then db.TotalTrades = 0 end
	if type(db.Sessions) ~= "table" then db.Sessions = {} end
	if type(db.Current) ~= "table" then db.Current = {Gold = 0, Trades = 0, Started = time()} end
	if type(db.Current.Gold) ~= "number" then db.Current.Gold = 0 end
	if type(db.Current.Trades) ~= "number" then db.Current.Trades = 0 end
	if type(db.Current.Started) ~= "number" then db.Current.Started = time() end
	return db
end

local function CommitCurrentSession()
	if not EC.DBChar then return end
	local db = EnsureEarningsDB()
	local current = db.Current
	if (current.Gold or 0) <= 0 and (current.Trades or 0) <= 0 then
		db.Current = {Gold = 0, Trades = 0, Started = time()}
		EC.SessionGold, EC.SessionTrades = 0, 0
		return
	end
	table.insert(db.Sessions, 1, {
		Started = current.Started or time(),
		Ended = time(),
		Gold = current.Gold or 0,
		Trades = current.Trades or 0,
	})
	while #db.Sessions > MAX_EARNINGS_SESSIONS do table.remove(db.Sessions) end
	db.Current = {Gold = 0, Trades = 0, Started = time()}
	EC.SessionGold, EC.SessionTrades = 0, 0
end

local function RecordEarnings(delta)
	if delta <= 0 then return end
	local db = EnsureEarningsDB()
	db.TotalGold = db.TotalGold + delta
	db.TotalTrades = db.TotalTrades + 1
	db.Current.Gold = db.Current.Gold + delta
	db.Current.Trades = db.Current.Trades + 1
	EC.SessionGold = db.Current.Gold
	EC.SessionTrades = db.Current.Trades
end

local function PrintEarningsSummary()
	local db = EnsureEarningsDB()
	local current = db.Current
	print("|cFFFF1C1CEnchanter|r Earnings Summary")
	print("  Session:  " .. FormatMoney(current.Gold) .. " | " .. current.Trades .. " trade(s)")
	print("  Lifetime: " .. FormatMoney(db.TotalGold) .. " | " .. db.TotalTrades .. " trade(s)")
	print("  History:  " .. #db.Sessions .. " saved session(s), retaining the latest " .. MAX_EARNINGS_SESSIONS)
end

local function PrintEarningsHistory(limit)
	local db = EnsureEarningsDB()
	limit = math.max(1, math.min(20, tonumber(limit) or 10))
	print("|cFFFF1C1CEnchanter|r Earnings History (latest " .. math.min(limit, #db.Sessions) .. ")")
	if #db.Sessions == 0 then
		print("  No completed sessions recorded yet.")
		return
	end
	for i = 1, math.min(limit, #db.Sessions) do
		local session = db.Sessions[i]
		local dateText = date("%d/%m/%y %H:%M", session.Ended or session.Started or time())
		print(string.format("  #%d %s - %s | %d trade(s)", i, dateText, FormatMoney(session.Gold), session.Trades or 0))
	end
end
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

local function IsClickableEnchantLink(link)
	-- A real clickable enchant/formula link contains an enchant hyperlink payload, e.g.
	-- |cffffffff|Henchant:20024|h[Enchant Boots - Spirit]|h|r
	return type(link) == "string" and link:find("|Henchant:", 1, true) ~= nil and link:find("|h", 1, true) ~= nil
end

local function GetClickableCraftLink(index)
	-- Classic Era exposes both APIs. GetCraftRecipeLink() is the obvious choice,
	-- but on some 1.15.x clients it can return nil while GetCraftItemLink() still
	-- returns the same clickable enchantLink. Only accept an actual enchant hyperlink.
	local link
	if type(GetCraftRecipeLink) == "function" then
		local ok, value = pcall(GetCraftRecipeLink, index)
		if ok and IsClickableEnchantLink(value) then link = value end
	end
	if not link and type(GetCraftItemLink) == "function" then
		local ok, value = pcall(GetCraftItemLink, index)
		if ok and IsClickableEnchantLink(value) then link = value end
	end
	return link
end

local function ScanCraftLinksOnce(verbose)
	local stillPending = false -- recipes that might just need more time
	local linkless = {}        -- recipes for which neither Classic API produced a real enchant hyperlink

	for i = 1, GetNumCrafts(), 1 do
		local craftName = GetCraftInfo(i)
		local tag = EC.RecipeTags["enGB"][craftName]
		if tag ~= nil then
			local link = GetClickableCraftLink(i)
			if not link then
				TryForceCraftSelect(i)
				link = GetClickableCraftLink(i)
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
			EC.DBChar.RecipeLinks[v] = nil
			EC.DBChar.RecipeMats[v] = nil
		end
	end

	-- Restore whatever recipe was actually selected before we started
	-- force-selecting rows to coax their link data loose.
	if EC.PreScanSelection then
		TryForceCraftSelect(EC.PreScanSelection)
		EC.PreScanSelection = nil
	end

	-- Summarise the scan instead of dumping every recipe/linkless recipe into chat.
	local totalCount, newCount, removedCount = 0, 0, 0
	for recipe in pairs(EC.DBChar.RecipeList) do
		totalCount = totalCount + 1
		if not EC.PreScanRecipeList or not EC.PreScanRecipeList[recipe] then
			newCount = newCount + 1
		end
	end
	if EC.PreScanRecipeList then
		for recipe in pairs(EC.PreScanRecipeList) do
			if not EC.DBChar.RecipeList[recipe] then
				removedCount = removedCount + 1
			end
		end
	end

	-- Make newly learned enchants available to chat matching immediately.
	if EC.Initalized and EC.InitPatterns then
		EC.InitPatterns()
	end

	local summary = string.format("|cFFFFD100Enchanter:|r Scan complete - %d enchant(s) found, %d new", totalCount, newCount)
	if removedCount > 0 then
		summary = summary .. string.format(", %d removed", removedCount)
	end
	EC.LastLinklessRecipes = linkless or {}
	if #EC.LastLinklessRecipes > 0 then
		summary = summary .. string.format(", %d without clickable recipe link(s)", #EC.LastLinklessRecipes)
	end
	print(summary .. ".")

	-- Keep the normal scan compact. If only a few truly lack a link, show them
	-- immediately; for a larger list /ec links can be used on demand.
	if #EC.LastLinklessRecipes > 0 and #EC.LastLinklessRecipes <= 8 then
		print("|cFFFFD100Enchanter:|r No clickable recipe link: " .. table.concat(EC.LastLinklessRecipes, ", "))
	elseif #EC.LastLinklessRecipes > 8 then
		print("|cFFFFD100Enchanter:|r Use /ec links to list the affected enchants.")
	end

	EC.PreScanRecipeList = nil
	EC.PreScanRecipeData = nil
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
	-- Snapshot the previous scan so the completion message can report genuinely new enchants.
	EC.PreScanRecipeList = {}
	for recipe in pairs(EC.DBChar.RecipeList or {}) do
		EC.PreScanRecipeList[recipe] = true
	end
	-- Keep a complete snapshot until the scan succeeds. If Enchanting fails to
	-- open, we restore the previous working scan instead of leaving the addon
	-- with an empty recipe database.
	EC.PreScanRecipeData = {
		RecipeList = EC.DBChar.RecipeList,
		RecipeLinks = EC.DBChar.RecipeLinks,
		RecipeMats = EC.DBChar.RecipeMats,
	}

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
			if EC.PreScanRecipeData then
				EC.DBChar.RecipeList = EC.PreScanRecipeData.RecipeList or {}
				EC.DBChar.RecipeLinks = EC.PreScanRecipeData.RecipeLinks or {}
				EC.DBChar.RecipeMats = EC.PreScanRecipeData.RecipeMats or {}
			end
			EC.PreScanRecipeData = nil
			EC.PreScanRecipeList = nil
			print("|cFFFF1C1C Enchanter:|r couldn't detect the Enchanting window opening. Previous scan preserved; make sure Enchanting is open and run /ec scan again.")
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
	EnsureEarningsDB()
	EC.SessionGold = EC.DBChar.Earnings.Current.Gold or 0
	EC.SessionTrades = EC.DBChar.Earnings.Current.Trades or 0

	EC.Tool.SlashCommand({"/ec", "/enchanter", "/e"},{
		{"scan","MUST BE RAN PRIOR TO /ec start. Scans and stores your enchanting recipes for request matching. NOTE: You need to rerun this when you learn new recipes",function()
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
		{"summary","Shows current session and lifetime earnings",function()
			PrintEarningsSummary()
		end},
		{"history","Shows previous earnings sessions. Optional: /ec history 20",function(msg)
			PrintEarningsHistory(msg)
		end},
		{"links","Lists enchants from the last scan that do not have a real clickable recipe link",function()
			local missing = EC.LastLinklessRecipes or {}
			if #missing == 0 then
				print("|cFFFFD100Enchanter:|r Last scan found no enchants missing a clickable recipe link.")
			else
				print(string.format("|cFFFFD100Enchanter:|r %d enchant(s) without a clickable recipe link:", #missing))
				for i = 1, #missing do
					print("  - " .. missing[i])
				end
			end
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

local function TrimText(value)
	if type(value) ~= "string" then return nil end
	value = value:match("^%s*(.-)%s*$")
	if not value or value == "" then return nil end
	return value
end

function EC.InitPatterns()
	-- Rebuild from scratch. Store normalized *literal* strings rather than Lua
	-- patterns so custom text containing %, [, -, etc. can never break matching.
	wipe(EC.PrefixTagsCompiled)
	wipe(EC.BlacklistCompiled)
	wipe(EC.RecipeTagsMap)
	wipe(EC.RecipeTagList)

	for _, v in pairs(EC.PrefixTags or {}) do
		v = TrimText(v)
		if v then table.insert(EC.PrefixTagsCompiled, v:lower()) end
	end

	for _, v in pairs(EC.BlackList or {}) do
		v = TrimText(v)
		if v then table.insert(EC.BlacklistCompiled, v:lower()) end
	end

	for recipe, tags in pairs(EC.DBChar.RecipeList or {}) do
		if type(tags) == "table" then
			for _, tag in pairs(tags) do
				tag = TrimText(tag)
				if tag then
					tag = tag:lower()
					if not EC.RecipeTagsMap[tag] then
						EC.RecipeTagsMap[tag] = {}
						table.insert(EC.RecipeTagList, tag)
					end
					table.insert(EC.RecipeTagsMap[tag], recipe)
				end
			end
		end
	end

	-- Longer phrases first makes debug output/matches deterministic and avoids a
	-- short alias winning simply because pairs() happened to enumerate it first.
	table.sort(EC.RecipeTagList, function(a, b)
		if #a == #b then return a < b end
		return #a > #b
	end)
end

local function IsWordChar(ch)
	return ch ~= nil and ch ~= "" and ch:match("[%w_]") ~= nil
end

local function ContainsLiteralTag(text, tag)
	if type(text) ~= "string" or type(tag) ~= "string" or tag == "" then return false end
	local from = 1
	while true do
		local first, last = text:find(tag, from, true)
		if not first then return false end

		local leftOK = true
		local rightOK = true
		if IsWordChar(tag:sub(1, 1)) and first > 1 then
			leftOK = not IsWordChar(text:sub(first - 1, first - 1))
		end
		if IsWordChar(tag:sub(-1)) and last < #text then
			rightOK = not IsWordChar(text:sub(last + 1, last + 1))
		end

		if leftOK and rightOK then return true end
		from = first + 1
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
	for _, v in ipairs(EC.PrefixTagsCompiled) do
		if ContainsLiteralTag(msgParse, v) then -- prevents LF matching LFW, etc.
			isRequestValid = true
			break
		end
	end

	for _, v in ipairs(EC.BlacklistCompiled) do
		if ContainsLiteralTag(msgParse, v) then
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
		if ContainsLiteralTag(msgParse, tag) then
			local recipes = EC.RecipeTagsMap[tag]
			if recipes then
				if not EC.LfRecipeList[name] then EC.LfRecipeList[name] = {} end
				for _, recipe in ipairs(recipes) do
					if EC.DBChar.Debug == true then
						print("User should be invited for msg: " .. msg)
						print("Due to tag: " .. tag .. " -> recipe " .. tostring(recipe))
					end
					shouldInvite = true
					EC.LfRecipeList[name][recipe] = tag
				end

				if alreadyInvited == false and EC.PlayerList[name] == nil and EC.DBChar.Debug ~= true and EC.DB.AutoInvite then
					local delay = math.max(0, tonumber(EC.DB.InviteTimeDelay) or 0)
					C_Timer.After(delay, function()
						-- Re-check settings at execution time so /ec stop or disabling
						-- Auto Invite during the delay cannot fire a stale invite.
						if EC.Initalized and not EC.DBChar.Stop and EC.DB.AutoInvite then
							C_PartyInfo.InviteUnit(name)
						end
					end)
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
			local delay = math.max(0, tonumber(EC.DB.WhisperTimeDelay) or 0)
			C_Timer.After(delay, function()
				if EC.Initalized and not EC.DBChar.Stop and EC.DB.WhisperLfRequests then
					SendChatMessage(EC.DB.LfWhisperMsg, "WHISPER", nil, name)
				end
			end)
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
				RecordEarnings(delta)
			end
		end)
	end
end

-- Parse chat from ChatFrame message filters, NOT from the raw CHAT_MSG_*
-- events.  Raw events are delivered even for messages Blizzard later hides
-- (spam/filtering), which caused invisible messages to trigger whispers and
-- party invites.  A ChatFrame filter only sees messages as they pass through
-- the normal chat display pipeline.
local SeenChatLineIDs = {}
local LastSeenCleanup = 0

local function WasChatLineHandled(lineID)
	if not lineID then return false end
	if SeenChatLineIDs[lineID] then return true end
	SeenChatLineIDs[lineID] = GetTime()

	local now = GetTime()
	if now - LastSeenCleanup > 60 then
		LastSeenCleanup = now
		for id, stamp in pairs(SeenChatLineIDs) do
			if now - stamp > 120 then SeenChatLineIDs[id] = nil end
		end
	end
	return false
end

local function EnchanterChatFilter(self, event, msg, name, languageName, channelName,
	playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName,
	unused, lineID, guid, ...)
	if not EC.Initalized or EC.DBChar.Stop == true then return false end

	-- For numbered channels keep the original scope: General/Trade/local
	-- channel IDs plus custom channels (0). Say/Yell do not use zoneChannelID.
	if event == "CHAT_MSG_CHANNEL" and zoneChannelID ~= 0 and zoneChannelID ~= 1 and zoneChannelID ~= 2 then
		return false
	end

	-- The same line can be routed to more than one chat frame. Parse it once.
	if WasChatLineHandled(lineID) then return false end

	EC.ParseMessage(msg, name)
	return false -- never hide or alter the player's chat message
end


local function Event_ADDON_LOADED(arg1)
	if arg1 == TOCNAME then
		EC.Init()
	end
end

local function Event_PLAYER_LOGOUT()
	CommitCurrentSession()
end



function EC.OnLoad()
    EC.Tool.RegisterEvent("ADDON_LOADED",Event_ADDON_LOADED)
	-- Do not register raw CHAT_MSG_* events here. See EnchanterChatFilter above.
	if ChatFrame_AddMessageEventFilter then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", EnchanterChatFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", EnchanterChatFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", EnchanterChatFilter)
	else
		print("|cFFFF1C1CEnchanter:|r Chat filtering API unavailable; automatic chat matching disabled for safety.")
	end
	EC.Tool.RegisterEvent("TRADE_SHOW",Event_TRADE_SHOW)
	EC.Tool.RegisterEvent("TRADE_CLOSED",Event_TRADE_CLOSED)
	EC.Tool.RegisterEvent("PLAYER_LOGOUT",Event_PLAYER_LOGOUT)
	EC.Tool.RegisterEvent("CRAFT_SHOW",Event_CRAFT_SHOW)
	EC.Tool.RegisterEvent("GET_ITEM_INFO_RECEIVED",Event_GET_ITEM_INFO_RECEIVED)
end

