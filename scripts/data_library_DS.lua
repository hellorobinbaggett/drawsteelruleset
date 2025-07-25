
aRecordOverrides = {
	-- CoreRPG overrides
	["npc"] = {
		bExport = true,
		bID = true,
		aDataMap = { "npc", "reference.npcs" },
		sListDisplayClass = "masterindexitem_id",
		-- sRecordDisplayClass = "npc",
		aGMEditButtons = { "button_add_npc_import" },
		aCustom = {
			tWindowMenu = { ["left"] = { "chat_speak" } },
		},
		aCustomFilters = {
			["Level"] = { sField = "level_name" },
			["Role"] = { sField = "role_name" },
			-- TODO: make npc keywords useful
			-- ["Keywords"] = { sField = "keywords_name" },
		},
	},
	["ancestry"] = {
		bExport = true,
		aDataMap = { "ancestry", "reference.ancestries" },
	},
	["class"] = {
		bExport = true,
		aDataMap = { "class", "reference.classes" },
	},
	-- ["feat"] = {
	-- 	nExport = 3,
	-- 	aDataMap = { "feat", "reference.features" },
	-- },

	-- new record types
	["ability"] = {
		sSidebarCategory = "create",
		bExport = true,
		aDataMap = { "ability", "reference.abilities" },
		aCustomFilters = {
			["Ancestry"] = { sField = "ancestry" },
			["Class"] = { sField = "class" },
			["Cost"] = { sField = "ability_cost" },
			["Level"] = { sField = "ability_level" },
			["Type"] = { sField = "abilitytype" },
		},
	},
	["kit"] = {
		sSidebarCategory = "create",
		bExport = true,
		aDataMap = { "kit", "reference.kit" },
	},
	-- TODO: implement careers
	["career"] = {
		sSidebarCategory = "create",
		bExport = true,
		aDataMap = { "career", "reference.career" },
	},
};

aListViews = {
	["ability"] = {
		["byclass"] = {
			aColumns = {
				{ sName = "cost", sType = "basicnumber", sHeadingRes = "ability_grouped_label_cost", nWidth=200 },
				{ sName = "name", sType = "basicnumber", sHeadingRes = "ability_grouped_label_name", nWidth=200 },
			},
			aFilters = {},
			aGroups = { { sDBField = "class" } },
			aGroupValueOrder = {},
		},
		["byancestry"] = {
			aColumns = {
				{ sName = "cost", sType = "basicnumber", sHeadingRes = "ability_grouped_label_cost", nWidth=200 },
				{ sName = "name", sType = "basicnumber", sHeadingRes = "ability_grouped_label_name", nWidth=200 },
			},
			aFilters = {},
			aGroups = { { sDBField = "ancestry" } },
			aGroupValueOrder = {},
		},
	},
};

function onInit()
	LibraryData.overrideRecordTypes(aRecordOverrides);
	LibraryData.setRecordViews(aListViews);
	LibraryData.setRecordTypeInfo("vehicle", nil);
end