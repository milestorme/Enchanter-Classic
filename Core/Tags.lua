local TOCNAME,EC=...

local function langSplit(source)
	local ret={}
	for lang,pat in pairs(source) do
		ret[lang]=EC.Tool.Split(pat:lower(),",")
	end
	return ret
end

EC.DefaultPrefixTags = {"lf", "wtb", "looking for"}
EC.DefaultEnchanterTags = {"lf enchanter", "looking for enchanter", "any enchanters online", "need enchanter"}

-- Classic Era 1.15.9 only.
-- This list intentionally contains Classic Era equipment enchants only.
-- TBC-only recipes have been removed so they cannot appear in Options or be matched in chat.
EC.DefaultRecipeTags={
	enGB = langSplit({
		["Enchant Boots - Minor Agility"] = "Enchant Boots - Minor Agility",
		["Enchant Boots - Minor Stamina"] = "Enchant Boots - Minor Stamina",
		["Enchant Boots - Lesser Agility"] = "Enchant Boots - Lesser Agility",
		["Enchant Boots - Lesser Stamina"] = "Enchant Boots - Lesser Stamina",
		["Enchant Boots - Lesser Spirit"] = "Enchant Boots - Lesser Spirit",
		["Enchant Boots - Stamina"] = "Enchant Boots - Stamina",
		["Enchant Boots - Minor Speed"] = "Enchant Boots - Minor Speed,minor speed,speed to boots,speed to feet",
		["Enchant Boots - Agility"] = "Enchant Boots - Agility",
		["Enchant Boots - Greater Stamina"] = "Enchant Boots - Greater Stamina",
		["Enchant Boots - Spirit"] = "Enchant Boots - Spirit",
		["Enchant Boots - Greater Agility"] = "Enchant Boots - Greater Agility,greater agility boots,7 agi boots",
		["Enchant Bracer - Minor Health"] = "Enchant Bracer - Minor Health",
		["Enchant Bracer - Minor Deflect"] = "Enchant Bracer - Minor Deflect",
		["Enchant Bracer - Minor Stamina"] = "Enchant Bracer - Minor Stamina",
		["Enchant Bracer - Minor Spirit"] = "Enchant Bracer - Minor Spirit",
		["Enchant Bracer - Minor Agility"] = "Enchant Bracer - Minor Agility",
		["Enchant Bracer - Minor Strength"] = "Enchant Bracer - Minor Strength",
		["Enchant Bracer - Lesser Spirit"] = "Enchant Bracer - Lesser Spirit",
		["Enchant Bracer - Lesser Stamina"] = "Enchant Bracer - Lesser Stamina",
		["Enchant Bracer - Lesser Strength"] = "Enchant Bracer - Lesser Strength",
		["Enchant Bracer - Lesser Intellect"] = "Enchant Bracer - Lesser Intellect",
		["Enchant Bracer - Spirit"] = "Enchant Bracer - Spirit",
		["Enchant Bracer - Lesser Deflection"] = "Enchant Bracer - Lesser Deflection",
		["Enchant Bracer - Stamina"] = "Enchant Bracer - Stamina",
		["Enchant Bracer - Strength"] = "Enchant Bracer - Strength",
		["Enchant Bracer - Intellect"] = "Enchant Bracer - Intellect",
		["Enchant Bracer - Greater Spirit"] = "Enchant Bracer - Greater Spirit",
		["Enchant Bracer - Deflection"] = "Enchant Bracer - Deflection",
		["Enchant Bracer - Greater Strength"] = "Enchant Bracer - Greater Strength,7 strength bracer,7 str bracer",
		["Enchant Bracer - Greater Stamina"] = "Enchant Bracer - Greater Stamina,7 stamina bracer,7 stam bracer",
		["Enchant Bracer - Greater Intellect"] = "Enchant Bracer - Greater Intellect,7 intellect bracer,7 int bracer",
		["Enchant Bracer - Superior Spirit"] = "Enchant Bracer - Superior Spirit",
		["Enchant Bracer - Mana Regeneration"] = "Enchant Bracer - Mana Regeneration",
		["Enchant Bracer - Superior Strength"] = "Enchant Bracer - Superior Strength,9 strength bracer,9 str bracer",
		["Enchant Bracer - Healing Power"] = "Enchant Bracer - Healing Power,healing power bracer,24 healing bracer",
		["Enchant Bracer - Superior Stamina"] = "Enchant Bracer - Superior Stamina,9 stamina bracer,9 stam bracer",
		["Enchant Chest - Minor Health"] = "Enchant Chest - Minor Health",
		["Enchant Chest - Minor Mana"] = "Enchant Chest - Minor Mana",
		["Enchant Chest - Minor Absorption"] = "Enchant Chest - Minor Absorption",
		["Enchant Chest - Lesser Health"] = "Enchant Chest - Lesser Health",
		["Enchant Chest - Health"] = "Enchant Chest - Health",
		["Enchant Chest - Lesser Absorption"] = "Enchant Chest - Lesser Absorption",
		["Enchant Chest - Mana"] = "Enchant Chest - Mana",
		["Enchant Chest - Minor Stats"] = "Enchant Chest - Minor Stats",
		["Enchant Chest - Greater Health"] = "Enchant Chest - Greater Health",
		["Enchant Chest - Greater Mana"] = "Enchant Chest - Greater Mana",
		["Enchant Chest - Lesser Stats"] = "Enchant Chest - Lesser Stats",
		["Enchant Chest - Superior Health"] = "Enchant Chest - Superior Health",
		["Enchant Chest - Superior Mana"] = "Enchant Chest - Superior Mana",
		["Enchant Chest - Stats"] = "Enchant Chest - Stats,3 stats chest,3 all stats,stats chest",
		["Enchant Chest - Major Health"] = "Enchant Chest - Major Health,100 health chest,100 hp chest",
		["Enchant Chest - Major Mana"] = "Enchant Chest - Major Mana",
		["Enchant Chest - Greater Stats"] = "Enchant Chest - Greater Stats,4 stats chest,4 all stats,greater stats chest",
		["Enchant Cloak - Minor Resistance"] = "Enchant Cloak - Minor Resistance",
		["Enchant Cloak - Minor Protection"] = "Enchant Cloak - Minor Protection",
		["Enchant Cloak - Lesser Protection"] = "Enchant Cloak - Lesser Protection",
		["Enchant Cloak - Lesser Fire Resistance"] = "Enchant Cloak - Lesser Fire Resistance",
		["Enchant Cloak - Minor Agility"] = "Enchant Cloak - Minor Agility",
		["Enchant Cloak - Defense"] = "Enchant Cloak - Defense",
		["Enchant Cloak - Lesser Shadow Resistance"] = "Enchant Cloak - Lesser Shadow Resistance",
		["Enchant Cloak - Fire Resistance"] = "Enchant Cloak - Fire Resistance",
		["Enchant Cloak - Greater Defense"] = "Enchant Cloak - Greater Defense",
		["Enchant Cloak - Resistance"] = "Enchant Cloak - Resistance",
		["Enchant Cloak - Lesser Agility"] = "Enchant Cloak - Lesser Agility",
		["Enchant Cloak - Greater Resistance"] = "Enchant Cloak - Greater Resistance,greater resistance cloak",
		["Enchant Cloak - Superior Defense"] = "Enchant Cloak - Superior Defense,70 armor cloak,70 armour cloak",
		["Enchant Cloak - Dodge"] = "Enchant Cloak - Dodge,dodge cloak",
		["Enchant Cloak - Greater Fire Resistance"] = "Enchant Cloak - Greater Fire Resistance,greater fire resistance cloak",
		["Enchant Cloak - Greater Nature Resistance"] = "Enchant Cloak - Greater Nature Resistance,greater nature resistance cloak",
		["Enchant Cloak - Stealth"] = "Enchant Cloak - Stealth,stealth cloak",
		["Enchant Cloak - Subtlety"] = "Enchant Cloak - Subtlety,subtlety cloak",
		["Enchant Gloves - Fishing"] = "Enchant Gloves - Fishing",
		["Enchant Gloves - Herbalism"] = "Enchant Gloves - Herbalism",
		["Enchant Gloves - Mining"] = "Enchant Gloves - Mining",
		["Enchant Gloves - Agility"] = "Enchant Gloves - Agility",
		["Enchant Gloves - Skinning"] = "Enchant Gloves - Skinning",
		["Enchant Gloves - Strength"] = "Enchant Gloves - Strength",
		["Enchant Gloves - Advanced Mining"] = "Enchant Gloves - Advanced Mining",
		["Enchant Gloves - Advanced Herbalism"] = "Enchant Gloves - Advanced Herbalism",
		["Enchant Gloves - Minor Haste"] = "Enchant Gloves - Minor Haste,1% haste gloves,haste gloves",
		["Enchant Gloves - Riding Skill"] = "Enchant Gloves - Riding Skill,riding skill gloves,riding speed gloves",
		["Enchant Gloves - Greater Agility"] = "Enchant Gloves - Greater Agility,7 agi gloves,7 agility gloves",
		["Enchant Gloves - Greater Strength"] = "Enchant Gloves - Greater Strength,7 strength gloves,7 str gloves",
		["Enchant Gloves - Fire Power"] = "Enchant Gloves - Fire Power,20 fire gloves,fire power gloves",
		["Enchant Gloves - Frost Power"] = "Enchant Gloves - Frost Power,20 frost gloves,frost power gloves",
		["Enchant Gloves - Healing Power"] = "Enchant Gloves - Healing Power,30 healing gloves,healing power gloves",
		["Enchant Gloves - Shadow Power"] = "Enchant Gloves - Shadow Power,20 shadow gloves,shadow power gloves",
		["Enchant Gloves - Superior Agility"] = "Enchant Gloves - Superior Agility,15 agi gloves,15 agility gloves",
		["Enchant Gloves - Threat"] = "Enchant Gloves - Threat,threat gloves",
		["Enchant Shield - Minor Stamina"] = "Enchant Shield - Minor Stamina",
		["Enchant Shield - Lesser Spirit"] = "Enchant Shield - Lesser Spirit",
		["Enchant Shield - Lesser Protection"] = "Enchant Shield - Lesser Protection",
		["Enchant Shield - Lesser Stamina"] = "Enchant Shield - Lesser Stamina",
		["Enchant Shield - Spirit"] = "Enchant Shield - Spirit",
		["Enchant Shield - Lesser Block"] = "Enchant Shield - Lesser Block",
		["Enchant Shield - Greater Spirit"] = "Enchant Shield - Greater Spirit",
		["Enchant Shield - Stamina"] = "Enchant Shield - Stamina",
		["Enchant Shield - Frost Resistance"] = "Enchant Shield - Frost Resistance",
		["Enchant Shield - Superior Spirit"] = "Enchant Shield - Superior Spirit",
		["Enchant Shield - Greater Stamina"] = "Enchant Shield - Greater Stamina,7 stamina shield,7 stam shield",
		["Enchant Weapon - Minor Striking"] = "Enchant Weapon - Minor Striking",
		["Enchant Weapon - Minor Beastslayer"] = "Enchant Weapon - Minor Beastslayer",
		["Enchant Weapon - Lesser Striking"] = "Enchant Weapon - Lesser Striking",
		["Enchant Weapon - Striking"] = "Enchant Weapon - Striking",
		["Enchant Weapon - Lesser Beastslayer"] = "Enchant Weapon - Lesser Beastslayer",
		["Enchant Weapon - Lesser Elemental Slayer"] = "Enchant Weapon - Lesser Elemental Slayer",
		["Enchant Weapon - Winter's Might"] = "Enchant Weapon - Winter's Might",
		["Enchant Weapon - Greater Striking"] = "Enchant Weapon - Greater Striking",
		["Enchant Weapon - Demonslaying"] = "Enchant Weapon - Demonslaying",
		["Enchant Weapon - Fiery Weapon"] = "Enchant Weapon - Fiery Weapon,fiery weapon,fiery",
		["Enchant Weapon - Icy Chill"] = "Enchant Weapon - Icy Chill,icy chill,icy",
		["Enchant Weapon - Strength"] = "Enchant Weapon - Strength",
		["Enchant Weapon - Agility"] = "Enchant Weapon - Agility",
		["Enchant Weapon - Unholy Weapon"] = "Enchant Weapon - Unholy Weapon",
		["Enchant Weapon - Superior Striking"] = "Enchant Weapon - Superior Striking,5 damage weapon,5 weapon damage,superior striking",
		["Enchant Weapon - Spell Power"] = "Enchant Weapon - Spell Power,30 spell power,30 sp weapon,spell power weapon",
		["Enchant Weapon - Mighty Spirit"] = "Enchant Weapon - Mighty Spirit,20 spirit,20 spirit weapon,20 spirit wep,mighty spirit",
		["Enchant Weapon - Mighty Intellect"] = "Enchant Weapon - Mighty Intellect,22 intellect,22 int,22 intellect weapon,22 int weapon,mighty intellect",
		["Enchant Weapon - Lifestealing"] = "Enchant Weapon - Lifestealing,lifesteal,life steal",
		["Enchant Weapon - Healing Power"] = "Enchant Weapon - Healing Power,55 healing weapon,55 healing",
		["Enchant Weapon - Crusader"] = "Enchant Weapon - Crusader,crusader",
		["Enchant 2H Weapon - Minor Impact"] = "Enchant 2H Weapon - Minor Impact",
		["Enchant 2H Weapon - Lesser Intellect"] = "Enchant 2H Weapon - Lesser Intellect",
		["Enchant 2H Weapon - Lesser Spirit"] = "Enchant 2H Weapon - Lesser Spirit",
		["Enchant 2H Weapon - Lesser Impact"] = "Enchant 2H Weapon - Lesser Impact",
		["Enchant 2H Weapon - Impact"] = "Enchant 2H Weapon - Impact",
		["Enchant 2H Weapon - Greater Impact"] = "Enchant 2H Weapon - Greater Impact",
		["Enchant 2H Weapon - Agility"] = "Enchant 2H Weapon - Agility,25 agi 2h,25 agility 2h,25 agi two hand,25 agility two hand",
		["Enchant 2H Weapon - Superior Impact"] = "Enchant 2H Weapon - Superior Impact",
		["Enchant 2H Weapon - Major Spirit"] = "Enchant 2H Weapon - Major Spirit,9 spirit 2h,9 spirit two hand",
		["Enchant 2H Weapon - Major Intellect"] = "Enchant 2H Weapon - Major Intellect,9 intellect 2h,9 intellect two hand",
	}),
}

-- Build a richer set of safe, natural-language aliases for every Classic enchant.
-- These are generated from the official recipe name so even low-level enchants get
-- useful forms such as "minor stamina boots", "boots minor stam", "minor stam boot",
-- "greater str bracers", "spell power wep", etc.  We deliberately keep the slot in
-- generated aliases to avoid ambiguous matches between enchants sharing the same stat.
local function ExpandDefaultRecipeAliases()
	local recipes = EC.DefaultRecipeTags and EC.DefaultRecipeTags.enGB
	if type(recipes) ~= "table" then return end

	local slotVariants = {
		["Boots"] = {"boots", "boot"},
		["Bracer"] = {"bracer", "bracers", "wrist"},
		["Chest"] = {"chest"},
		["Cloak"] = {"cloak", "cape"},
		["Gloves"] = {"gloves", "glove"},
		["Shield"] = {"shield"},
		["Weapon"] = {"weapon", "wep"},
		["2H Weapon"] = {"2h", "2h weapon", "2h wep", "two hand", "two handed"},
	}
	local wordAliases = {
		agility = "agi", stamina = "stam", strength = "str", intellect = "int",
		resistance = "resist", health = "hp", regeneration = "regen",
	}

	local function addUnique(list, seen, value)
		value = tostring(value or ""):lower():match("^%s*(.-)%s*$")
		if value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(list, value)
		end
	end

	local function abbreviated(effect)
		local changed = false
		local words = {}
		for word in effect:lower():gmatch("%S+") do
			local replacement = wordAliases[word]
			if replacement then changed = true end
			table.insert(words, replacement or word)
		end
		return changed and table.concat(words, " ") or nil
	end

	for recipeName, aliases in pairs(recipes) do
		if type(aliases) == "table" then
			local seen = {}
			for _, alias in ipairs(aliases) do seen[tostring(alias):lower()] = true end

			local slot, effect = recipeName:match("^Enchant (2H Weapon) %- (.+)$")
			if not slot then slot, effect = recipeName:match("^Enchant ([^-]+) %- (.+)$") end
			if slot and effect and slotVariants[slot] then
				local effects = {effect:lower()}
				local shortEffect = abbreviated(effect)
				if shortEffect then table.insert(effects, shortEffect) end

				for _, effectText in ipairs(effects) do
					for _, slotText in ipairs(slotVariants[slot]) do
						addUnique(aliases, seen, effectText .. " " .. slotText)
						addUnique(aliases, seen, slotText .. " " .. effectText)
					end
				end
			end

			-- A leading + is common player shorthand. Keep it visible in Options for
			-- existing numeric aliases even though the matcher itself ignores punctuation.
			local snapshot = {}
			for _, alias in ipairs(aliases) do table.insert(snapshot, alias) end
			for _, alias in ipairs(snapshot) do
				if alias:match("^%d+%s") then addUnique(aliases, seen, "+" .. alias) end
			end
		end
	end
end

ExpandDefaultRecipeAliases()
