local TOCNAME,EC=...
Enchanter_Addon=EC


EC.Initialized = false
EC.PlayerList = {}
EC.LfRecipeList = {}
EC.PendingLfWhispers = {}
EC.ManualRejectCooldowns = {}
EC.ManualRejectPhrasesCompiled = {}
EC.SessionGold = 0
EC.SessionTrades = 0
local preTradeGold = nil
local targetTradeGold = 0
local pendingTradeGold = 0
local tradeRecorded = false
local tradeEnchantDetected = false
local tradeEnchantName = nil
local tradePartnerName = nil
local tradePartnerClass = nil
local tradeActive = false
local tradeSequence = 0
local tradeBothAccepted = false
local PLAYER_RESPONSE_COOLDOWN = 60

-- Persistent earnings use aggregate totals plus a fixed-size session history.
-- We never store one record per trade, keeping SavedVariables small long-term.
local MAX_EARNINGS_SESSIONS = 100
local MAX_ENCHANT_TRADES = 1000

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
	if type(db.TradeHistory) ~= "table" then db.TradeHistory = {} end
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

local function RecordEarnings(delta, playerName, enchantName, playerClass)
	delta = math.max(0, tonumber(delta) or 0)
	local db = EnsureEarningsDB()
	db.TotalGold = db.TotalGold + delta
	db.TotalTrades = db.TotalTrades + 1
	db.Current.Gold = db.Current.Gold + delta
	db.Current.Trades = db.Current.Trades + 1
	EC.SessionGold = db.Current.Gold
	EC.SessionTrades = db.Current.Trades
	table.insert(db.TradeHistory, 1, {Time=time(), Gold=delta, Player=playerName or "Unknown", Class=playerClass, Enchant=enchantName or "Unknown enchant"})
	while #db.TradeHistory > MAX_ENCHANT_TRADES do table.remove(db.TradeHistory) end
	if EC.RefreshJournal then EC.RefreshJournal() end
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
EC.PrefixTagsCompiled = {}
EC.BlacklistCompiled = {}
EC.RecipeTagsMap = {}
EC.RecipeTagList = {}
-- All configured Classic enchant aliases, including recipes this character does not know.
-- Used only to distinguish a specific enchant request from a generic "LF enchanter" request.
EC.AllRecipeTagList = {}
EC.EnchanterTagsCompiled = {}
-- Scans the users known recipes and stores them
-- Additionally it also stores the recipes clickable link, that will be used when messaging the user (for those people asks what are the mats?)
-- NOTE: GetCraftRecipeLink() can return nil for a recipe if the client hasn't
-- finished loading that recipe's link data yet - but for a small number of
-- recipes (older/superseded formulas) it can also just never return a link
-- at all, no matter how long you wait. When that happens we fall back to a
-- plain-text materials list built from the reagent API (see below), which
-- doesn't depend on the same caching quirk, so mats still get whispered
-- correctly even without a clickable formula link.
local function GetReagentData(index, reagentIndex)
	if type(GetCraftReagentItemLink) ~= "function" then
		return nil, nil
	end

	local ok, itemLink = pcall(GetCraftReagentItemLink, index, reagentIndex)
	if not ok or type(itemLink) ~= "string" or itemLink == "" then
		return nil, nil
	end

	local itemID = tonumber(itemLink:match("|Hitem:(%d+)"))
	local itemName

	if itemID and C_Item and type(C_Item.GetItemNameByID) == "function" then
		itemName = C_Item.GetItemNameByID(itemID)
	end

	if (not itemName or itemName == "") and itemID and type(GetItemInfo) == "function" then
		itemName = GetItemInfo(itemID)
	end

	if not itemName or itemName == "" then
		itemName = itemLink:match("%[(.-)%]")
	end

	if not itemName or itemName == "" then
		return nil, nil
	end

	return itemName, itemLink
end

local function BuildReagentText(index)
	if type(GetCraftNumReagents) ~= "function" or type(GetCraftReagentInfo) ~= "function" then
		return nil, nil, false
	end

	local ok, numReagents = pcall(GetCraftNumReagents, index)
	if not ok or not numReagents or numReagents == 0 then
		return nil, nil, false
	end

	local plainParts = {}
	local linkedParts = {}
	local pending = false

	for reagentIndex = 1, numReagents do
		-- GetCraftReagentInfo supplies the reagent name/count even when the
		-- clickable item link is not cached yet. Never make the mats list
		-- depend on GetCraftReagentItemLink succeeding.
		local okReagent, apiName, _, numRequired = pcall(GetCraftReagentInfo, index, reagentIndex)
		if okReagent and type(apiName) == "string" and apiName ~= "" then
			local linkedName, reagentLink = GetReagentData(index, reagentIndex)
			local reagentName = linkedName or apiName
			local amount = tonumber(numRequired) or 0
			local plainPart = amount > 0 and (amount .. "x " .. reagentName) or reagentName
			local displayReagent = reagentLink or reagentName
			local linkedPart = amount > 0 and (amount .. "x " .. displayReagent) or displayReagent

			table.insert(plainParts, plainPart)
			table.insert(linkedParts, linkedPart)

			-- A later scan can upgrade this reagent from plain text to a clickable
			-- item link, but the current scan is already safe to use for whispers.
			if not reagentLink then
				pending = true
			end
		else
			pending = true
		end
	end

	-- Only withhold the list when the reagent API itself failed to identify a
	-- reagent. Missing item links are harmless because linkedParts falls back
	-- to the reagent name for that individual slot.
	if #plainParts ~= numReagents or #linkedParts ~= numReagents then
		return nil, nil, true
	end

	return table.concat(plainParts, ", "), table.concat(linkedParts, ", "), pending
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
			local reagentText, reagentLinks, reagentPending = BuildReagentText(i)
			if reagentText then
				EC.DBChar.RecipeMats[craftName] = reagentText
			else
				EC.DBChar.RecipeMats[craftName] = nil
			end
			if reagentLinks then
				EC.DBChar.RecipeMatsLinks[craftName] = reagentLinks
			else
				EC.DBChar.RecipeMatsLinks[craftName] = nil
			end
			if reagentPending then
				stillPending = true
			end
			if link then
				EC.DBChar.RecipeLinks[craftName] = link
			else
				stillPending = true
				table.insert(linkless, craftName)
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
	if EC.Initialized and EC.InitPatterns then
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
		RecipeMatsLinks = EC.DBChar.RecipeMatsLinks,
	}

	EC.DBChar.RecipeList = {}
	EC.DBChar.RecipeLinks = {}
	EC.DBChar.RecipeMats = {}
	EC.DBChar.RecipeMatsLinks = {}
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
				EC.DBChar.RecipeMatsLinks = EC.PreScanRecipeData.RecipeMatsLinks or {}
			end
			EC.PreScanRecipeData = nil
			EC.PreScanRecipeList = nil
			print("|cFFFF1C1C Enchanter:|r couldn't detect the Enchanting window opening. Previous scan preserved; make sure Enchanting is open and run /ec scan again.")
		end
	end)
end

function EC.StartListening(showMessage)
	EC.DBChar.Stop = false
	if showMessage ~= false then print("|cFFFFD100Enchanter:|r Started - listening for enchant requests.") end
end

function EC.StopListening(showMessage)
	EC.DBChar.Stop = true
	if showMessage ~= false then print("|cFFFFD100Enchanter:|r Paused - automatic request matching stopped.") end
end

function EC.IsListening()
	return EC.DBChar and EC.DBChar.Stop ~= true
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
	if not EC.DBChar.RecipeMatsLinks then EC.DBChar.RecipeMatsLinks = {} end
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
		{{"stop", "pause"},"Pauses addon",function() EC.StopListening(true) end},
		{"start","Starts the addon. It will begin parsing chat looking for requests",function() EC.StartListening(true) end},
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
		{"history","Opens the Enchanter trade journal",function()
			if EC.OpenJournal then EC.OpenJournal() else print("|cFFFF1C1CEnchanter:|r Journal is unavailable.") end
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
	if EC.InitMinimap then EC.InitMinimap() end
	EC.Initialized = true

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

local function NormalizeManualRejectText(value)
	if type(value) ~= "string" then return "" end
	value = value:lower():gsub("[^%w]+", " ")
	return value:match("^%s*(.-)%s*$") or ""
end

local RECIPE_MATCH_IGNORED_WORDS = {
	["to"] = true,
	["on"] = true,
}

local RECIPE_MATCH_WORD_ALIASES = {
	["bracers"] = "bracer",
	["chests"] = "chest",
	["cloaks"] = "cloak",
	["shields"] = "shield",
	["weapons"] = "weapon",
}

local function NormalizeRecipeMatchText(value)
	if type(value) ~= "string" then return "" end

	-- Players commonly run numbers and stat abbreviations together (100hp,
	-- 9stam, 7agi, etc.). Split digit/letter boundaries before normalising so
	-- those forms match aliases such as "100 hp chest" and "9 stam bracer".
	local normalized = value:lower()
	normalized = normalized:gsub("(%d)(%a)", "%1 %2")
	normalized = normalized:gsub("(%a)(%d)", "%1 %2")
	normalized = normalized:gsub("[^%w]+", " ")
	local words = {}

	for word in normalized:gmatch("%S+") do
		if not RECIPE_MATCH_IGNORED_WORDS[word] then
			table.insert(words, RECIPE_MATCH_WORD_ALIASES[word] or word)
		end
	end

	return table.concat(words, " ")
end

function EC.InitPatterns()
	-- Rebuild from scratch. Store normalized *literal* strings rather than Lua
	-- patterns so custom text containing %, [, -, etc. can never break matching.
	wipe(EC.PrefixTagsCompiled)
	wipe(EC.BlacklistCompiled)
	wipe(EC.RecipeTagsMap)
	wipe(EC.RecipeTagList)
	wipe(EC.AllRecipeTagList)
	wipe(EC.EnchanterTagsCompiled)
	wipe(EC.ManualRejectPhrasesCompiled)

	for _, v in pairs(EC.PrefixTags or {}) do
		v = TrimText(v)
		if v then table.insert(EC.PrefixTagsCompiled, v:lower()) end
	end

	for _, v in pairs(EC.EnchanterTags or {}) do
		v = TrimText(v)
		if v then table.insert(EC.EnchanterTagsCompiled, v:lower()) end
	end

	for _, v in pairs(EC.BlackList or {}) do
		v = TrimText(v)
		if v then table.insert(EC.BlacklistCompiled, v:lower()) end
	end

	local manualRejectPhrases = EC.ManualRejectPhrases
	if not manualRejectPhrases then
		manualRejectPhrases = EC.Tool.Split(tostring(EC.DB.Custom.ManualRejectPhrases or "sorry i dont have that"):lower(), ",")
		EC.ManualRejectPhrases = manualRejectPhrases
	end
	for _, v in pairs(manualRejectPhrases) do
		v = TrimText(v)
		if v then
			local normalized = NormalizeManualRejectText(v)
			if normalized ~= "" then table.insert(EC.ManualRejectPhrasesCompiled, normalized) end
		end
	end

	-- Build a separate alias list from every configured Classic recipe, not just
	-- recipes known by this character.  Without this, a specific request for an
	-- unknown enchant (for example +55 healing) can fall through to the generic
	-- "LF enchanter" response and incorrectly ask the player what they need.
	local allSeen = {}
	for recipeName in pairs((EC.DefaultRecipeTags and EC.DefaultRecipeTags.enGB) or {}) do
		local aliases = EC.DB.Custom and EC.DB.Custom[recipeName]
		local tags = EC.Tool.Split(tostring(aliases or ""):lower(), ",")
		for _, tag in pairs(tags) do
			tag = TrimText(tag)
			if tag then
				tag = NormalizeRecipeMatchText(tag)
				if tag ~= "" and not allSeen[tag] then
					allSeen[tag] = true
					table.insert(EC.AllRecipeTagList, tag)
				end
			end
		end
	end
	table.sort(EC.AllRecipeTagList, function(a, b)
		if #a == #b then return a < b end
		return #a > #b
	end)

	for recipe, storedTags in pairs(EC.DBChar.RecipeList or {}) do
		-- RecipeList tells us which enchants this character actually knows, but its
		-- stored alias table can be stale after an addon update. Always compile the
		-- CURRENT aliases from Options/DB.Custom for known recipes. This is important
		-- for multi-enchant requests where one alias may have been added after the
		-- player's last /ec scan (for example "+7 agi gloves and minor speed").
		local tags = nil
		if EC.DB.Custom and type(EC.DB.Custom[recipe]) == "string" and EC.DB.Custom[recipe] ~= "" then
			tags = EC.Tool.Split(EC.DB.Custom[recipe]:lower(), ",")
		elseif type(storedTags) == "table" then
			tags = storedTags
		end

		if type(tags) == "table" then
			for _, tag in pairs(tags) do
				tag = TrimText(tag)
				if tag then
					tag = NormalizeRecipeMatchText(tag)
					if tag ~= "" then
						if not EC.RecipeTagsMap[tag] then
							EC.RecipeTagsMap[tag] = {}
							table.insert(EC.RecipeTagList, tag)
						end
						-- Avoid duplicate recipe entries when two configured aliases normalize
						-- to the same literal phrase (e.g. punctuation-only variants).
						local alreadyMapped = false
						for _, mappedRecipe in ipairs(EC.RecipeTagsMap[tag]) do
							if mappedRecipe == recipe then alreadyMapped = true break end
						end
						if not alreadyMapped then table.insert(EC.RecipeTagsMap[tag], recipe) end
					end
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

-- Recipe aliases without a numeric value must not match inside a request that
-- explicitly qualifies that same phrase with a number. Example: a character
-- who knows "Strength bracer" must NOT treat "+9 strength to bracer" as
-- that lower enchant. The +9 request belongs to Superior Strength and should
-- only match its explicit numeric alias if the character actually knows it.
local function ContainsRecipeTag(text, tag)
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

		if leftOK and rightOK then
			-- Normalization turns +9 into the token "9". If this alias has no
			-- number but the immediately preceding token is numeric, this is a
			-- more-specific numeric request, not a match for the generic alias.
			if not tag:find("%d") then
				local before = text:sub(1, first - 1)
				local previous = before:match("(%S+)%s*$")
				if previous and previous:match("^%d+$") then
					from = first + 1
				else
					return true
				end
			else
				return true
			end
		end
		from = first + 1
	end
end


local function SendWhisper(message, playerName)
	if type(message) ~= "string" or message == "" then return end
	if type(playerName) ~= "string" or playerName == "" then return end

	if C_ChatInfo and C_ChatInfo.SendChatMessage then
		C_ChatInfo.SendChatMessage(message, "WHISPER", nil, playerName)
	elseif SendChatMessage then
		SendChatMessage(message, "WHISPER", nil, playerName)
	else
		print("|cFFFF1C1CEnchanter:|r Unable to send whisper; chat API unavailable.")
	end
end

local function NormalizePlayerName(name)
	if type(name) ~= "string" then return "" end
	return name:lower()
end

local function IsBlacklistedPlayer(name)
	local normalizedName = NormalizePlayerName(name)
	if normalizedName == "" then return false end

	local baseName = normalizedName:match("^([^%-]+)") or normalizedName
	for _, blockedName in ipairs(EC.BlacklistCompiled) do
		if normalizedName == blockedName or baseName == blockedName then
			return true
		end
	end
	return false
end

local function HasRecentResponse(name)
	local key = NormalizePlayerName(name)
	local rejectUntil = EC.ManualRejectCooldowns[key]
	if type(rejectUntil) == "number" then
		if GetTime() < rejectUntil then return true end
		EC.ManualRejectCooldowns[key] = nil
	end

	local lastResponse = EC.PlayerList[name]
	if type(lastResponse) ~= "number" then return false end

	if GetTime() - lastResponse >= PLAYER_RESPONSE_COOLDOWN then
		EC.PlayerList[name] = nil
		return false
	end
	return true
end

local function MarkPlayerResponded(name)
	EC.PlayerList[name] = GetTime()
end

local function IsManualRejectPhrase(message)
	local normalized = NormalizeManualRejectText(message)
	if normalized == "" then return false end
	for _, phrase in ipairs(EC.ManualRejectPhrasesCompiled or {}) do
		if normalized == phrase then return true end
	end
	return false
end

local function ApplyManualRejectCooldown(name)
	local key = NormalizePlayerName(name)
	if key == "" then return end
	local minutes = tonumber(EC.DB.ManualRejectCooldownMinutes) or 5
	minutes = math.max(0, minutes)
	if minutes <= 0 then return end
	EC.ManualRejectCooldowns[key] = GetTime() + (minutes * 60)
	-- The pending follow-up is finished once the enchanter manually declines it.
	EC.PendingLfWhispers[key] = nil
	if EC.DBChar.Debug == true then
		print(string.format("Manual rejection cooldown: %s for %.1f minute(s)", name, minutes))
	end
end

local function IsGenericEnchantRequest(message)
	if type(message) ~= "string" then return false end
	local normalized = message:lower()
	for _, phrase in ipairs(EC.EnchanterTagsCompiled or {}) do
		if ContainsLiteralTag(normalized, phrase) then return true end
	end
	return false
end

local function HasSpecificEnchantAlias(message)
	local normalized = NormalizeRecipeMatchText(message or "")
	if normalized == "" then return false end
	for _, tag in ipairs(EC.AllRecipeTagList or {}) do
		if ContainsLiteralTag(normalized, tag) then return true end
	end
	return false
end

local LF_WHISPER_REPLY_TIMEOUT = 180

local function PendingWhisperKey(name)
	local normalizedName = NormalizePlayerName(name)
	if normalizedName == "" then return "" end
	return normalizedName
end

local function MarkPendingLfWhisper(name)
	local key = PendingWhisperKey(name)
	if key == "" then return end
	EC.PendingLfWhispers[key] = {
		Name = name,
		AskedAt = GetTime(),
	}
end

local function TakePendingLfWhisper(name)
	local key = PendingWhisperKey(name)
	if key == "" then return nil end

	local pending = EC.PendingLfWhispers[key]
	if not pending then return nil end

	if type(pending.AskedAt) ~= "number" or GetTime() - pending.AskedAt > LF_WHISPER_REPLY_TIMEOUT then
		EC.PendingLfWhispers[key] = nil
		return nil
	end

	-- A pending prompt is single-use: the next whisper is treated as their
	-- answer to "what do you need?" and cannot repeatedly trigger invites.
	EC.PendingLfWhispers[key] = nil
	return pending
end

local function FindKnownRecipeMatches(message)
	local matches = {}
	local matchCount = 0
	local recipeMatchText = NormalizeRecipeMatchText(message or "")

	for _, tag in ipairs(EC.RecipeTagList) do
		if ContainsRecipeTag(recipeMatchText, tag) then
			local recipes = EC.RecipeTagsMap[tag]
			if recipes then
				for _, recipe in ipairs(recipes) do
					if not matches[recipe] then
						matches[recipe] = tag
						matchCount = matchCount + 1
					end
				end
			end
		end
	end

	return matches, matchCount
end


local function SendRecipeResponse(name, recipeName)
	local recipeDisplay = EC.DBChar.RecipeLinks[recipeName] or recipeName
	local linkedMats = EC.DBChar.RecipeMatsLinks and EC.DBChar.RecipeMatsLinks[recipeName]
	local plainMats = EC.DBChar.RecipeMats and EC.DBChar.RecipeMats[recipeName]

	if linkedMats and linkedMats ~= "" then
		local combinedMessage = EC.DB.MsgPrefix .. recipeDisplay .. " - Mats: " .. linkedMats

		-- Hyperlinks are much longer internally than their visible text.
		if #combinedMessage <= 240 then
			SendWhisper(combinedMessage, name)
		else
			SendWhisper(EC.DB.MsgPrefix .. recipeDisplay, name)
			SendWhisper("Mats: " .. linkedMats, name)
		end
		return
	end

	if plainMats and plainMats ~= "" then
		SendWhisper(EC.DB.MsgPrefix .. recipeDisplay .. " - Mats: " .. plainMats, name)
		return
	end

	SendWhisper(EC.DB.MsgPrefix .. recipeDisplay .. " - Mats unavailable; please ask me to rescan.", name)
end

-- Sends a msg with the enchanting links that enchanter is capable of doing
function EC.SendMsg(name)
	if EC.LfRecipeList[name] == nil then
		return
	end

	for recipeName in pairs(EC.LfRecipeList[name]) do
		if EC.DBChar.Debug == true then
			local linkedMats = EC.DBChar.RecipeMatsLinks and EC.DBChar.RecipeMatsLinks[recipeName]
			local plainMats = EC.DBChar.RecipeMats and EC.DBChar.RecipeMats[recipeName]
			print("Debug mode: would whisper to " .. name .. ": " .. recipeName
				.. " | Mats: " .. tostring(linkedMats or plainMats))
		else
			SendRecipeResponse(name, recipeName)
		end
	end

	EC.LfRecipeList[name] = nil
end

-- For a message it will attempt to filter the request based on any of the words in EC.PrefixTags
-- If the message contains any of those words it will then attempt to check if any of the users recipes(tags) are contained in the message
-- If their is, it will then invite and message the user with a link to all desired recipes that the enchanter is capable of doing
function EC.ParseMessage(msg, name)
	if EC.Initialized==false or name==nil or name=="" or msg==nil or msg=="" or string.len(msg)<4 or EC.DBChar.Stop == true then
		return
	end
	local msgParse = msg:lower()
	local isGenericEnchantRequest = IsGenericEnchantRequest(msgParse)
	local isRequestValid = isGenericEnchantRequest
	if not isRequestValid then
		for _, v in ipairs(EC.PrefixTagsCompiled) do
			if ContainsLiteralTag(msgParse, v) then -- prevents LF matching LFW, etc.
				isRequestValid = true
				break
			end
		end
	end

	if IsBlacklistedPlayer(name) then
		if EC.DBChar.Debug == true then
			print("Ignoring blacklisted player: " .. name)
		end
		return
	end

	if isRequestValid == false then return end
	local shouldInvite = false
	local recipeMatchText = NormalizeRecipeMatchText(msgParse)
	-- use precomputed tag list/map for faster lookup
	-- iterate over every known tag rather than scanning each recipe
	for _, tag in ipairs(EC.RecipeTagList) do
		if ContainsRecipeTag(recipeMatchText, tag) then
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

			end
		end
	end
	
	if shouldInvite == true then
		-- This check is in case there is a bug and it wrongly matches we don't continue spamming invite to the same user every time they post
		if not HasRecentResponse(name) then 
			if EC.DBChar.Debug == true then
				print("Inviting Player: " .. name .. " for request: " .. msg)
			end

			MarkPlayerResponded(name)
			local responseStamp = EC.PlayerList[name]

			if EC.DBChar.Debug ~= true then
				-- Whisper first so grouped players still receive the response.
				EC.SendMsg(name)
				if EC.DB.AutoInvite then
					local delay = math.max(0, tonumber(EC.DB.InviteTimeDelay) or 0)
					C_Timer.After(delay, function()
						if EC.Initialized
							and not EC.DBChar.Stop
							and EC.DB.AutoInvite
							and EC.PlayerList[name] == responseStamp then
							C_PartyInfo.InviteUnit(name)
						end
					end)
				end
			else
				print("Debug mode: suppressed Invite and Whisper to " .. name)
			end
		else
			-- Due to the laziness of keeping the whole recipe storage thing, this is an optimization to clear it for users that have already been invited
			EC.LfRecipeList[name] = nil
		end
	elseif EC.DB.WhisperLfRequests and isRequestValid and not HasRecentResponse(name) then
		-- A message can contain both a generic phrase ("LF enchanter") and a
		-- specific enchant alias. If the specific enchant is not known, do not
		-- fall back to the generic "what do you need?" whisper.
		local hasSpecificEnchant = HasSpecificEnchantAlias(msgParse)
		if hasSpecificEnchant then
			if EC.DBChar.Debug == true then
				print("Ignoring specific enchant request for an unknown recipe from " .. name .. ": " .. msg)
			end
			return
		end

		if isGenericEnchantRequest then
			MarkPlayerResponded(name)
			local responseStamp = EC.PlayerList[name]
			local delay = math.max(0, tonumber(EC.DB.WhisperTimeDelay) or 0)
			C_Timer.After(delay, function()
				if EC.Initialized
					and not EC.DBChar.Stop
					and EC.DB.WhisperLfRequests
					and EC.PlayerList[name] == responseStamp then
					SendWhisper(EC.DB.LfWhisperMsg, name)
					MarkPendingLfWhisper(name)
				end
			end)
		end
	end
end

local function HandleLfWhisperReply(msg, name)
	if not EC.Initialized or EC.DBChar.Stop == true then return end
	if type(msg) ~= "string" or msg == "" or type(name) ~= "string" or name == "" then return end
	if IsBlacklistedPlayer(name) then return end

	local pending = TakePendingLfWhisper(name)
	if not pending then return end

	local matches, matchCount = FindKnownRecipeMatches(msg)
	if matchCount == 0 then
		-- Do not auto-reply when the player's wording does not match a known recipe.
		-- Enchant names are often abbreviated or misspelled, so leave unmatched
		-- replies for the enchanter to answer manually instead of falsely saying
		-- the enchant is unavailable.
		if EC.DBChar.Debug == true then
			print("Whisper reply from " .. name .. " did not match a known enchant; leaving for manual response: " .. msg)
		end
		return
	end

	EC.LfRecipeList[name] = matches

	if EC.DBChar.Debug == true then
		print("Whisper reply from " .. name .. " matched " .. matchCount .. " known enchant(s): " .. msg)
		EC.LfRecipeList[name] = nil
		return
	end

	-- The normal recipe response starts with the configured "I can do" prefix
	-- and includes the recipe link/materials where available.
	EC.SendMsg(name)

	if EC.DB.AutoInvite then
		local delay = math.max(0, tonumber(EC.DB.InviteTimeDelay) or 0)
		C_Timer.After(delay, function()
			if EC.Initialized and not EC.DBChar.Stop and EC.DB.AutoInvite then
				C_PartyInfo.InviteUnit(name)
			end
		end)
	end
end

local function GetTradePartnerName()
	if type(UnitName) ~= "function" then return nil end
	local name, realm = UnitName("NPC")
	if not name then name, realm = UnitName("target") end
	if name and realm and realm ~= "" then return name .. "-" .. realm end
	return name
end

local function CaptureTradeEnchant()
	-- Classic exposes the enchant currently being applied in the trade window
	-- as the sixth return from GetTradeTargetItemInfo(). This is more reliable
	-- than inspecting the target item link, which may not change until later.
	if type(GetTradeTargetItemInfo) == "function" then
		for slot = 1, 7 do
			local ok, _, _, _, _, _, enchant = pcall(GetTradeTargetItemInfo, slot)
			if ok and type(enchant) == "string" and enchant ~= "" then
				tradeEnchantDetected = true
				tradeEnchantName = enchant
				return
			end
		end
	end

	-- Fallback for clients that expose the applied permanent enchant in the
	-- target item link during the trade.
	if type(GetTradeTargetItemLink) == "function" then
		for slot = 1, 7 do
			local ok, link = pcall(GetTradeTargetItemLink, slot)
			if ok and type(link) == "string" then
				local enchantID = tonumber(link:match("|Hitem:%d+:(%d+)"))
				if enchantID and enchantID > 0 then
					tradeEnchantDetected = true
					if not tradeEnchantName then tradeEnchantName = "Enchant ID " .. enchantID end
					return
				end
			end
		end
	end
end

local function FindKnownEnchantBySpellID(spellID)
	spellID = tonumber(spellID)
	if not spellID then return nil end
	for recipeName, link in pairs(EC.DBChar.RecipeLinks or {}) do
		if type(link) == "string" then
			local recipeSpellID = tonumber(link:match("|Henchant:(%d+)"))
			if recipeSpellID == spellID then return recipeName end
		end
	end
	return nil
end

local function Event_UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellID)
	if unitTarget ~= "player" or not tradeActive then return end
	local recipeName = FindKnownEnchantBySpellID(spellID)
	if recipeName then
		tradeEnchantDetected = true
		tradeEnchantName = recipeName
	end
end

local function Event_TRADE_TARGET_ITEM_CHANGED()
	CaptureTradeEnchant()
end

local function CaptureTargetTradeMoney()
	if type(GetTargetTradeMoney) ~= "function" then return end
	local amount = tonumber(GetTargetTradeMoney()) or 0
	if amount > targetTradeGold then
		targetTradeGold = amount
	end
end

local function Event_TRADE_SHOW()
	tradeSequence = tradeSequence + 1
	preTradeGold = GetMoney()
	targetTradeGold = 0
	pendingTradeGold = 0
	tradeRecorded = false
	tradeEnchantDetected = false
	tradeEnchantName = nil
	tradePartnerName = GetTradePartnerName()
	tradePartnerClass = nil
	-- During a trade Blizzard exposes the other player through the NPC unit token.
	-- Save the class token with the journal entry so class colouring still works
	-- after the player has left or logged out. Fall back to target when needed.
	if type(UnitClass) == "function" then
		local _, classToken = UnitClass("NPC")
		if classToken then
			tradePartnerClass = classToken
		elseif UnitExists and UnitExists("target") and UnitName and UnitName("target") == tradePartnerName then
			local _, targetClass = UnitClass("target")
			tradePartnerClass = targetClass
		end
	end
	tradeBothAccepted = false
	tradeActive = true
	CaptureTargetTradeMoney()
	CaptureTradeEnchant()
end

local function Event_TRADE_MONEY_CHANGED()
	CaptureTargetTradeMoney()
end

local function Event_TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted)
	CaptureTargetTradeMoney()
	CaptureTradeEnchant()
	-- Remember that both sides accepted. This gives zero-tip enchant trades a
	-- reliable completion path even when there is no wallet change to detect.
	if tonumber(playerAccepted) == 1 and tonumber(targetAccepted) == 1 then
		tradeBothAccepted = true
	end
end

local function RecordCompletedTrade(amount)
	amount = tonumber(amount) or 0
	if tradeRecorded then return false end
	if not tradeEnchantDetected then
		if EC.DBChar and EC.DBChar.Debug then print("|cFFFFD100Enchanter:|r Ignored completed gold trade: no enchanted trade item detected.") end
		return false
	end
	tradeRecorded = true
	pendingTradeGold = 0
	RecordEarnings(amount, tradePartnerName, tradeEnchantName, tradePartnerClass)
	if EC.DBChar and EC.DBChar.Debug then
		print("|cFFFFD100Enchanter:|r Recorded completed trade earnings: " .. FormatMoney(amount))
	end
	return true
end

local function Event_TRADE_CLOSED()
	CaptureTargetTradeMoney()
	CaptureTradeEnchant()
	tradeActive = false
	local closedSequence = tradeSequence
	local completedByAcceptance = tradeBothAccepted
	tradeBothAccepted = false
	local snapshot = preTradeGold
	preTradeGold = nil
	pendingTradeGold = targetTradeGold or 0
	targetTradeGold = 0

	-- TRADE_CLOSED also fires on cancelled trades, so do not commit the
	-- remembered target offer here. The UI_INFO_MESSAGE handler below waits
	-- for Blizzard's ERR_TRADE_COMPLETE confirmation. Keep wallet-delta
	-- checks as a fallback in case that confirmation is unavailable.
	if snapshot ~= nil then
		local function CheckTradeGold()
			-- Ignore delayed callbacks from an older trade after a new trade has opened.
			if tradeSequence ~= closedSequence or tradeRecorded then return end
			local delta = GetMoney() - snapshot
			if delta > 0 then
				RecordCompletedTrade(delta)
			end
		end

		CheckTradeGold()
		C_Timer.After(0.2, CheckTradeGold)
		C_Timer.After(0.75, CheckTradeGold)
		C_Timer.After(1.5, CheckTradeGold)
		C_Timer.After(3.0, CheckTradeGold)
	end

	-- Do not immediately assume an accepted enchant trade was a zero-tip trade.
	-- WoW can update the player's wallet a little after TRADE_CLOSED, so an early
	-- 0c fallback can beat the real gold-delta checks. Give every wallet check a
	-- chance to run first; only then record 0c if no payment was observed.
	if completedByAcceptance then
		C_Timer.After(3.25, function()
			if tradeSequence ~= closedSequence or tradeRecorded then return end
			RecordCompletedTrade(pendingTradeGold or 0)
		end)
	end

	-- Do not let a cancelled trade's remembered offer leak into a later
	-- unrelated UI message. A successful completion message is immediate.
	C_Timer.After(5.0, function()
		if tradeSequence == closedSequence and not tradeRecorded then pendingTradeGold = 0 end
	end)
end

local function Event_UI_INFO_MESSAGE(errorType, message)
	if message == ERR_TRADE_COMPLETE then
		-- Prefer the amount the customer actually placed into the trade. This
		-- is available before the wallet itself necessarily refreshes.
		if pendingTradeGold > 0 then
			RecordCompletedTrade(pendingTradeGold)
		elseif targetTradeGold > 0 then
			RecordCompletedTrade(targetTradeGold)
		else
			-- Do not commit 0c here. ERR_TRADE_COMPLETE can arrive before the
			-- player's wallet reflects the customer's payment. TRADE_CLOSED has
			-- already scheduled wallet-delta checks and a delayed zero-tip fallback.
		end
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
	if not EC.Initialized or EC.DBChar.Stop == true then return false end

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


local function EnchanterWhisperFilter(self, event, msg, name, ...)
	-- Unlike public chat parsing, whisper handling is gated by a short-lived
	-- prompt record, so only someone we just asked "what do you need?" can
	-- enter this follow-up flow. The whisper is never hidden or modified.
	HandleLfWhisperReply(msg, name)
	return false
end

local function EnchanterOutgoingWhisperFilter(self, event, msg, name, ...)
	-- If the enchanter manually sends one of their configured decline phrases,
	-- suppress further LF auto-responses to that recipient for the configured time.
	if EC.Initialized and EC.DBChar.Stop ~= true and IsManualRejectPhrase(msg) then
		ApplyManualRejectCooldown(name)
	end
	return false
end

local function Event_ADDON_LOADED(arg1)
	if arg1 == TOCNAME then
		EC.Init()
	end
end

local function Event_PLAYER_LOGOUT()
	CommitCurrentSession()
end

local loginStatusShown = false
local function Event_PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	-- PLAYER_ENTERING_WORLD distinguishes a real login from /reload on Classic.
	-- Only announce once on an actual login, and only while listening is enabled.
	if loginStatusShown or not isInitialLogin or isReloadingUi then return end
	loginStatusShown = true
	if EC.Initialized and EC.IsListening and EC.IsListening() then
		print("|cFFFFD100Enchanter:|r Enabled and listening for enchanting requests.")
	end
end



function EC.OnLoad()
    EC.Tool.RegisterEvent("ADDON_LOADED",Event_ADDON_LOADED)
	-- Do not register raw CHAT_MSG_* events here. See EnchanterChatFilter above.
	if ChatFrame_AddMessageEventFilter then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", EnchanterChatFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", EnchanterChatFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", EnchanterChatFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", EnchanterWhisperFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", EnchanterOutgoingWhisperFilter)
	else
		print("|cFFFF1C1CEnchanter:|r Chat filtering API unavailable; automatic chat matching disabled for safety.")
	end
	EC.Tool.RegisterEvent("TRADE_SHOW",Event_TRADE_SHOW)
	EC.Tool.RegisterEvent("TRADE_ACCEPT_UPDATE",Event_TRADE_ACCEPT_UPDATE)
	EC.Tool.RegisterEvent("TRADE_MONEY_CHANGED",Event_TRADE_MONEY_CHANGED)
	EC.Tool.RegisterEvent("TRADE_TARGET_ITEM_CHANGED",Event_TRADE_TARGET_ITEM_CHANGED)
	EC.Tool.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",Event_UNIT_SPELLCAST_SUCCEEDED)
	EC.Tool.RegisterEvent("TRADE_CLOSED",Event_TRADE_CLOSED)
	EC.Tool.RegisterEvent("UI_INFO_MESSAGE",Event_UI_INFO_MESSAGE)
	EC.Tool.RegisterEvent("PLAYER_LOGOUT",Event_PLAYER_LOGOUT)
	EC.Tool.RegisterEvent("PLAYER_ENTERING_WORLD",Event_PLAYER_ENTERING_WORLD)
	EC.Tool.RegisterEvent("CRAFT_SHOW",Event_CRAFT_SHOW)
	EC.Tool.RegisterEvent("GET_ITEM_INFO_RECEIVED",Event_GET_ITEM_INFO_RECEIVED)
end

