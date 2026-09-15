local TOCNAME,EC=...

-- Backwards/compatibility: some bundled Option libs expose their API
-- under different addon locals (GBB, Addon) or a plain `Options` table.
-- Ensure `EC.OptionsBuilder` is set so calls to it do not fail.
if not EC.OptionsBuilder then
	if type(GBB) == "table" and GBB.OptionsBuilder then
		EC.OptionsBuilder = GBB.OptionsBuilder
	elseif type(Addon) == "table" and Addon.OptionsBuilder then
		EC.OptionsBuilder = Addon.OptionsBuilder
	elseif type(Options) == "table" and Options.Init then
		EC.OptionsBuilder = Options
	end
end

--Options
-------------------------------------------------------------------------------------
-- Minimal legacy shim: provide `EC.Options.DoOk/DoCancel/DoDefault` so
-- existing calls that expect an `Options` table don't fail while using
-- the newer `OptionsBuilder` implementation.
if not EC.Options then
	EC.Options = {}
	function EC.Options.DoOk()
		EC.OptionsUpdate()
	end
	function EC.Options.DoCancel()
		EC.OptionsUpdate()
	end
	function EC.Options.DoDefault()
		EC.Default()
		EC.OptionsUpdate()
		if EC.OptionsBuilder and EC.OptionsBuilder.DefaultRegisteredVariables then
			EC.OptionsBuilder.DefaultRegisteredVariables()
		end
	end
end

function EC.UpdateTags()
	for k, _ in pairs(EC.DBChar.RecipeList) do
		if EC.DB.Custom[k] ~= nil and EC.DB.Custom[k] ~= "" then
			EC.DBChar.RecipeList[k] = EC.Tool.Split(EC.DB.Custom[k]:lower(),",")
		end
	end
end

local function SplitAliases(value)
	local result, seen = {}, {}
	for part in tostring(value or ""):gmatch("[^,]+") do
		local trimmed = part:match("^%s*(.-)%s*$")
		local key = trimmed:lower()
		if trimmed ~= "" and not seen[key] then
			seen[key] = true
			table.insert(result, trimmed)
		end
	end
	return result, seen
end

-- Merge newly shipped aliases into SavedVariables without replacing anything the
-- player has added themselves. This runs on every load, making alias improvements
-- upgrade-safe across addon versions.
function EC.MergeDefaultCustomTags()
	EC.RecipeTags = EC.DefaultRecipeTags
	for recipeName, defaults in pairs(EC.RecipeTags["enGB"] or {}) do
		local existing, seen = SplitAliases(EC.DB.Custom[recipeName])
		for _, alias in ipairs(defaults) do
			local trimmed = tostring(alias):match("^%s*(.-)%s*$")
			local key = trimmed:lower()
			if trimmed ~= "" and not seen[key] then
				seen[key] = true
				table.insert(existing, trimmed)
			end
		end
		EC.DB.Custom[recipeName] = table.concat(existing, ",")
	end
end

function EC.DefaultCustomTags()
	EC.RecipeTags = EC.DefaultRecipeTags
	for k,v in pairs(EC.RecipeTags["enGB"]) do
		EC.DB.Custom[k] = EC.Tool.Combine(v,",")
	end
end

function EC.Default()
	EC.EnchanterTags = EC.DefaultEnchanterTags
	EC.PrefixTags = EC.DefaultPrefixTags
	EC.RecipeTags = EC.DefaultRecipeTags
	EC.DefaultCustomTags()
end

function EC.OptionsUpdate() 

	EC.UpdateTags()
	EC.BlackList = EC.Tool.Split(tostring(EC.DB.Custom.BlackList or ""):lower(), ",")
	EC.PrefixTags = EC.Tool.Split(tostring(EC.DB.Custom.SearchPrefix or ""):lower(), ",")
	EC.EnchanterTags = EC.Tool.Split(tostring(EC.DB.Custom.GenericPrefix or ""):lower(), ",")
	EC.ManualRejectPhrases = EC.Tool.Split(tostring(EC.DB.Custom.ManualRejectPhrases or "sorry i dont have that"):lower(), ",")
	if EC.Initialized and EC.InitPatterns then EC.InitPatterns() end
end

function EC.OptionsInit ()
	-- Upgrade aliases before building the edit boxes so users immediately see new
	-- defaults alongside all of their existing custom aliases.
	EC.MergeDefaultCustomTags()
	EC.OptionsBuilder.Init(
		function() -- ok button
			EC.Options.DoOk()
		end,
		function() -- Chancel/init button
			EC.Options.DoCancel() 
		end, 
		function() -- default button
			EC.Options.DoDefault()
		end
		)
	
	EC.OptionsBuilder.SetScale(0.85)

	-- helper for quickly creating editboxes that write their contents back
	-- whenever the player leaves the field.  The default OptionsBuilder
	-- implementation only reads the saved value once, so text edits weren't
	-- being persisted until the panel was reopened.  We also trigger a full
	-- OptionsUpdate() so that Enchanter's cached tag lists stay in sync.
	local function MakeEditBoxSaved(db, key, default, label, width, height, numeric)
		local eb = EC.OptionsBuilder.AddEditBoxToCurrentPanel(db, key, default, label, width, height, numeric)
		eb:SetText(eb:GetSavedValue())
		-- mirror what the library normally does on EnterPressed: update the
		-- saved value stored inside the frame so that OnEditFocusLost doesn’t
		-- immediately overwrite our change with the old one.
		eb:HookScript("OnEnterPressed", function(self)
			local text = self:GetText()
			self:SetSavedValue(text)
			self:ClearFocus()
			EC.OptionsUpdate()
		end)
		-- replace the built-in focus‑lost handler so our save logic runs first.
		-- the original script simply synced the editbox text from its saved value,
		-- so call it after updating the saved value.
		local origLost = eb:GetScript("OnEditFocusLost")
		eb:SetScript("OnEditFocusLost", function(self)
			local text = self:GetText()
			self:SetSavedValue(text)
			EC.OptionsUpdate()
			if origLost then
				origLost(self)
			end
		end)
		return eb
	end

	-- Tags Tab
	EC.OptionsBuilder.AddNewCategoryPanel("Enchanter",false,true)
	
	EC.OptionsBuilder.AddHeaderToCurrentPanel("General Options")
	EC.OptionsBuilder.Indent(10)
	EC.OptionsBuilder.InLine()
	EC.OptionsBuilder.AddCheckBoxToCurrentPanel(EC.DB, "AutoInvite", true, "Auto Invite")
	EC.OptionsBuilder.AddCheckBoxToCurrentPanel(EC.DB, "WhisperLfRequests", false, "Reply to LF Enchanter requests")
	EC.OptionsBuilder.EndInLine()
	EC.OptionsBuilder.Indent(-10)
	EC.OptionsBuilder.AddSpacerToPanel()

	-- Delay timers for auto behavior
	MakeEditBoxSaved(EC.DB, "WhisperTimeDelay", 0, "WhisperTimeDelay", 50, nil, true)
	MakeEditBoxSaved(EC.DB, "InviteTimeDelay", 0, "InviteTimeDelay", 50, nil, true)

	EC.OptionsBuilder.AddHeaderToCurrentPanel("Search Patterns")
	EC.OptionsBuilder.Indent(10)
	EC.OptionsBuilder.AddTextToCurrentPanel('Enter your own unique search patterns here. You must use "," (comma) as the separator with no space after it', 450+200)
	EC.OptionsBuilder.AddSpacerToPanel()

	-- Message String
	MakeEditBoxSaved(EC.DB, "MsgPrefix", "I can do ", "Message Prefix", 365, 280, false)

	-- LF Enchanter Msg String
	MakeEditBoxSaved(EC.DB, "LfWhisperMsg", "What you looking for?", "Generic request whisper message", 365, 280, false)
	MakeEditBoxSaved(EC.DB.Custom, "ManualRejectPhrases", "sorry i dont have that", "Manual no-enchant phrases (comma separated)", 365, 280, false)
	MakeEditBoxSaved(EC.DB, "ManualRejectCooldownMinutes", 5, "Manual rejection cooldown (minutes)", 70, 280, true)
	EC.OptionsBuilder.AddTextToCurrentPanel("When you whisper one of these phrases, that player will not receive another automatic LF Enchanter response until this cooldown expires.", 645)
	EC.OptionsBuilder.AddSpacerToPanel()

	local prefixTags = EC.Tool.Combine(EC.PrefixTags, ",")
	MakeEditBoxSaved(EC.DB.Custom, "SearchPrefix", prefixTags, "Prefix to search for", 365, 280, false)

	local genericSearchWords = EC.Tool.Combine(EC.EnchanterTags, ",")
	MakeEditBoxSaved(EC.DB.Custom, "GenericPrefix", genericSearchWords, "Generic request match phrases", 365, 280, false)

	-- Blacklist
	MakeEditBoxSaved(EC.DB.Custom, "BlackList", "", "Blacklisted player names", 365, 280, false)
	EC.OptionsBuilder.AddSpacerToPanel()

	-- Recipe Tags - grouped by equipment slot and alphabetized within each group.
	-- Lua pairs() has no defined order, which made this section appear random.
	local slotOrder = {"Boots", "Bracer", "Chest", "Cloak", "Gloves", "Shield", "Weapon", "2H Weapon", "Other"}
	local groupedRecipes = {}
	for _, slot in ipairs(slotOrder) do groupedRecipes[slot] = {} end

	local function GetRecipeSlot(recipeName)
		if recipeName:find("^Enchant Boots %- ") then return "Boots" end
		if recipeName:find("^Enchant Bracer %- ") then return "Bracer" end
		if recipeName:find("^Enchant Chest %- ") then return "Chest" end
		if recipeName:find("^Enchant Cloak %- ") then return "Cloak" end
		if recipeName:find("^Enchant Gloves %- ") then return "Gloves" end
		if recipeName:find("^Enchant Shield %- ") then return "Shield" end
		if recipeName:find("^Enchant 2H Weapon %- ") then return "2H Weapon" end
		if recipeName:find("^Enchant Weapon %- ") then return "Weapon" end
		return "Other"
	end

	for recipeName in pairs(EC.RecipeTags["enGB"]) do
		table.insert(groupedRecipes[GetRecipeSlot(recipeName)], recipeName)
	end

	for _, slot in ipairs(slotOrder) do
		local recipes = groupedRecipes[slot]
		table.sort(recipes, function(a, b) return a:lower() < b:lower() end)
		if #recipes > 0 then
			EC.OptionsBuilder.AddSpacerToPanel()
			EC.OptionsBuilder.AddHeaderToCurrentPanel(slot .. " Enchants")
			for _, recipeName in ipairs(recipes) do
				local txt = EC.Tool.Combine(EC.RecipeTags["enGB"][recipeName], ",")
				MakeEditBoxSaved(EC.DB.Custom, recipeName, txt, recipeName, 345, 300, false)
			end
		end
	end

	EC.OptionsUpdate() 
end
