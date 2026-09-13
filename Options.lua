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
	-- Undecided if I should keep this in or not
	--[[ 
		for k, v in pairs(EC.DB.Custom) do 
		if v == nil or v == "" then
			local txt = EC.Tool.Combine(EC.RecipeTags["enGB"][k],",")
			EC.DB.Custom[k] = txt
		end
	end
--]]
	for k, _ in pairs(EC.DBChar.RecipeList) do
		if EC.DB.Custom[k] ~= nil and EC.DB.Custom[k] ~= "" then
			EC.DBChar.RecipeList[k] = EC.Tool.Split(EC.DB.Custom[k]:lower(),",")
		end
	end
end

function EC.DefaultCustomTags()

	EC.RecipeTags = EC.DefaultRecipeTags
	for k,v in pairs(EC.RecipeTags["enGB"]) do
		local txt = EC.Tool.Combine(EC.RecipeTags["enGB"][k],",")
		EC.DB.Custom[k] = txt
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
	EC.BlackList = EC.Tool.Split(EC.DB.Custom.BlackList:lower(), ",")
	EC.PrefixTags = EC.Tool.Split(EC.DB.Custom.SearchPrefix:lower(), ",")
	EC.EnchanterTags = EC.Tool.Split(EC.DB.Custom.GenericPrefix:lower(), ",")
end

function EC.OptionsInit ()
	EC.OptionsBuilder.Init(
		function() -- ok button			
			EC.Options.DoOk() 
			EC.OptionsUpdate()	
		end,
		function() -- Chancel/init button
			EC.Options.DoCancel() 
		end, 
		function() -- default button
			EC.Options.DoDefault()
			EC.OptionsUpdate()	
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
	EC.OptionsBuilder.AddTextToCurrentPanel('Enter your own unique search patterns here. You must use "," (comma) as the seperator with no space after it', 450+200)
	EC.OptionsBuilder.AddSpacerToPanel()

	-- Message String
	MakeEditBoxSaved(EC.DB, "MsgPrefix", "I can do ", "Message Prefix", 445, 200, false)

	-- LF Enchanter Msg String
	MakeEditBoxSaved(EC.DB, "LfWhisperMsg", "What you looking for?", "Generic request wisper message", 445, 200, false)
	EC.OptionsBuilder.AddSpacerToPanel()

	local prefixTags = EC.Tool.Combine(EC.PrefixTags, ",")
	MakeEditBoxSaved(EC.DB.Custom, "SearchPrefix", prefixTags, "Prefix to search for", 445, 200, false)

	local genericSearchWords = EC.Tool.Combine(EC.EnchanterTags, ",")
	MakeEditBoxSaved(EC.DB.Custom, "GenericPrefix", genericSearchWords, "Generic request match phrases", 445, 200, false)

	-- Blacklist
	MakeEditBoxSaved(EC.DB.Custom, "BlackList", "", "BlackList", 445, 200, false)
	EC.OptionsBuilder.AddSpacerToPanel()

	-- Recipe Tags
	for k,v in pairs(EC.RecipeTags["enGB"]) do
		local txt = EC.Tool.Combine(EC.RecipeTags["enGB"][k],",")
		MakeEditBoxSaved(EC.DB.Custom, k, txt, k, 445, 200, false)
	end

	EC.OptionsUpdate() 
end
