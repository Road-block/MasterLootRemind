MasterLootRemind = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "FuBarPlugin-2.0")
local D = AceLibrary("Dewdrop-2.0")
local DF = AceLibrary("Deformat-2.0")
local T = AceLibrary("Tablet-2.0")
local BB = AceLibrary("Babble-Boss-2.2")
local parser = ParserLib:GetInstance("1.1")
local L = AceLibrary("AceLocale-2.2"):new("MasterLootRemind")

MasterLootRemind._visible = false
MasterLootRemind._resetVisible = false
MasterLootRemind._bossName = "_NONE_"
MasterLootRemind._lastLootMethod = "group"
MasterLootRemind._roster = { }
MasterLootRemind._blacklist = {
	[BB["Gurubashi Berserker"]] = true,
	[BB["Anubisath Guardian"]] = true,
	[BB["Anubisath Defender"]] = true,
	[BB["Anubisath Warder"]] = true,
	[BB["Deathsworn Captain"]] = true,
	[BB["Obsidian Sentinel"]] = true,
	[BB["Ancient Core Hound"]] = true,
	[BB["Stoneskin Gargoyle"]] = true
}
MasterLootRemind._whitelist = {
	[BB["Lieutenant General Andorov"]] = true
}
MasterLootRemind._ignored = { }
local lootMethodDesc = {
	["freeforall"] = string.gsub(LOOT_FREE_FOR_ALL,LOOT,""),
	["roundrobin"] = string.gsub(LOOT_ROUND_ROBIN,LOOT,""),
	["master"] = string.gsub(LOOT_MASTER_LOOTER,LOOT,""),
	["group"] = string.gsub(LOOT_GROUP_LOOT,LOOT,""),
	["needbeforegreed"] = string.gsub(LOOT_NEED_BEFORE_GREED,LOOT,""),
}
local groupTypeDesc = {
	[1] = L["Party Only"],
	[2] = L["Raid Only"],
	[3] = L["Party/Raid"],
}
local combatEvents = {
	'CHAT_MSG_COMBAT_SELF_HITS',
	'CHAT_MSG_COMBAT_SELF_MISSES',
	'CHAT_MSG_COMBAT_PET_HITS',
	'CHAT_MSG_COMBAT_PET_MISSES',
	'CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS',
	'CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES',
	'CHAT_MSG_COMBAT_PARTY_HITS',
	'CHAT_MSG_COMBAT_PARTY_MISSES',	
	'CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS',
	'CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES',
	'CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS',
	'CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES',
	'CHAT_MSG_COMBAT_FRIENDLY_DEATH',
	'CHAT_MSG_COMBAT_HOSTILE_DEATH',
	'CHAT_MSG_SPELL_SELF_DAMAGE',
	'CHAT_MSG_SPELL_PET_DAMAGE',
	'CHAT_MSG_SPELL_PARTY_DAMAGE',
	'CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE',
	'CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE',
	'CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE',
	'CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE',
	'CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF',
	'CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS',
	'CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE',
	'CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE',	
	'CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF',	
	'CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF',
}
local raidUnit,partyUnit = {},{}
do
	for i=1,MAX_PARTY_MEMBERS do
		partyUnit[i] = {"party"..i, "partypet"..i}
	end
	for i=1,MAX_RAID_MEMBERS do
		raidUnit[i] = {"raid"..i, "raidpet"..i}
	end
end
local options  = {
	type = "group",
	handler = MasterLootRemind,
	args =
	{
		Active =
		{
			name = L["Active"],
			desc = L["Activate/Suspend 'MasterLoot Remind'"],
			type = "toggle",
			get  = "GetActiveStatusOption",
			set  = "SetActiveStatusOption",
			order = 1,
		},
		GroupType =
		{
			name = L["Group Type"],
			desc = L["1 = Party only, 2 = Raid only, 3 = Both"],
			type = "range",
			get  = "GetGroupTypeOption",
			set  = "SetGroupTypeOption",
			disabled = function() return not MasterLootRemind.db.profile.Active end,
			min = 1,
			max = 3,
			step = 1,
			order = 2
		},
		BossCombat = 
		{
			name = L["Boss Engage"],
			desc = L["On Boss Combat"],
			type = "toggle",
			get  = "GetBossCombatStatusOption",
			set  = "SetBossCombatStatusOption",
			disabled = function() return not MasterLootRemind.db.profile.Active end,
			order = 3
		},
		ResetLoot = 
		{
			name = L["Reset Loot"],
			desc = L["Prompt to Reset Loot Method"],
			type = "toggle",
			get  = "GetResetLootStatusOption",
			set  = "SetResetLootStatusOption",
			disabled = function() return not MasterLootRemind.db.profile.Active end,
			order = 4
		},
		spacer1 = {name = L["List Options"], desc = L["List Options"], type = "header", order = 5},
		IgnoreTarget =
		{
			name = L["Permanently Ignore"],
			desc = L["Add current target to Permanent ignore list"],
			type = "execute",
			func = "IgnoreTarget",
			order = 6
		},
		pIgnore =
		{
			type = 'group',
			name = L["Permanent Ignore Options"],
			desc = L["Permanent ignore list options"],
			order = 7,
			args =
			{
				Reset =
				{
					name = L["Reset Permanent Ignore"],
					desc = L["Reset permanent ignore list"],
					type = "execute",
					func = function()
						MasterLootRemind:ResetIgnoreList("Permanent")
					end,
				},
				List =
				{
					name = L["View Permanent Ignore"],
					desc = L["View permanent ignore list"],
					type = "execute",
					func = function()
						MasterLootRemind:ViewIgnoreList("Permanent")
					end,
				},
				Del =
				{
					name = L["Delete from Permanent Ignore"],
					desc = L["Delete name from permanent ignore list"],
					type = "text",
					usage = "<name>",
					get = false,
					set = function(name)
						MasterLootRemind:DelFromIgnore(name, "Permanent")
					end,
				},
			},
		},
		sIgnore =
		{
			type = 'group',
			name = L["Session Ignore"],
			desc = L["Session ignore list options"],
			order = 8,
			args =
			{
				Reset =
				{
					name = L["Reset Session Ignore"],
					desc = L["Reset ignore list"],
					type = "execute",
					func = function()
						MasterLootRemind:ResetIgnoreList("Session")
					end,
				},
				List =
				{
					name = L["View Session Ignore"],
					desc = L["View ignore list"],
					type = "execute",
					func = function()
						MasterLootRemind:ViewIgnoreList("Session")
					end,
				},
				Del =
				{
					name = L["Delete from Session Ignore"],
					desc = L["Delete name from ignore list"],
					type = "text",
					usage = "<name>",
					get = false,
					set = "RemoveSessionIgnore",
				},
			},
		},
	},
}

---------
-- FuBar
---------
MasterLootRemind.hasIcon = "Interface\\Icons\\INV_Misc_Head_Kobold_01"
MasterLootRemind.title = L["ML Remind"]
MasterLootRemind.defaultMinimapPosition = 285
MasterLootRemind.defaultPosition = "CENTER"
MasterLootRemind.cannotDetachTooltip = true
MasterLootRemind.tooltipHiddenWhenEmpty = false
MasterLootRemind.hideWithoutStandby = true
MasterLootRemind.independentProfile = true

function MasterLootRemind:OnInitialize() -- ADDON_LOADED (1)
	self:RegisterDB("MasterLootRemindDB")
	self:RegisterDefaults("profile", {
    Active = true,
    GroupType = 2,
    BossCombat = false,
    ResetLoot = true,
	} )
	self:RegisterChatCommand( { "/mlr", "/masterlootremind" }, options )
	self.OnMenuRequest = options
	if not FuBar then
		self.OnMenuRequest.args.hide.guiName = L["Hide minimap icon"]
		self.OnMenuRequest.args.hide.desc = L["Hide minimap icon"]
	end	
end

function MasterLootRemind:OnEnable() -- PLAYER_LOGIN (2)
	MasterLootRemindDB.Ignored = MasterLootRemindDB.Ignored or {}
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("RAID_ROSTER_UPDATE","Roster")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED","Roster")
	if self.db.profile.BossCombat then
		self:ToggleCombatEvents(true)
	end
	if self.db.profile.ResetLoot then
		self:ToggleLootStatusEvents(true)
	end
end

function MasterLootRemind:OnDisable()
	self:UnregisterAllEvents()
	self:ToggleCombatEvents(false)
	self:ToggleLootStatusEvents(false)
end

function MasterLootRemind:OnTooltipUpdate()
  local hint = L["|cffFFA500Click:|r Cycle Group Mode|r\n|cffFFA500Right-Click:|r Options\n|cffFFFF00    \"You no take Candle!\"|r"]
  T:SetHint(hint)
end

function MasterLootRemind:OnTextUpdate()
	local groupType = self.db.profile.GroupType
	local active = self.db.profile.Active
	if (not active) then
		self:SetText(L["Suspended"])
	else
		self:SetText(groupTypeDesc[groupType] or L["ML Remind"])
	end
end

function MasterLootRemind:OnClick()
	local groupType = self.db.profile.GroupType
	if tonumber(groupType) == nil then
		return self:SetGroupTypeOption(2)
	end
	local newType = groupType + 1
	if newType > 3 then
		newType = 1
	end
	return self:SetGroupTypeOption(newType)
end

function MasterLootRemind:GetGroupTypeOption()
	self._skipNotification = true
	return self.db.profile.GroupType
end

function MasterLootRemind:SetGroupTypeOption(newType)
	self.db.profile.GroupType = newType
	--[[if (self._skipNotification) then
		self._skipNotification = false
	else
		self:Print(groupTypeDesc[self.db.profile.GroupType])
	end]]
	self:UpdateText()
end

function MasterLootRemind:GetActiveStatusOption()
	return self.db.profile.Active
end

function MasterLootRemind:SetActiveStatusOption(newStatus)
	self.db.profile.Active = newStatus
	self:UpdateText()
end

function MasterLootRemind:GetBossCombatStatusOption()
	return self.db.profile.BossCombat
end

function MasterLootRemind:SetBossCombatStatusOption(newStatus)
	self.db.profile.BossCombat = newStatus
	self:ToggleCombatEvents(self.db.profile.BossCombat)
end

function MasterLootRemind:GetResetLootStatusOption()
	return self.db.profile.ResetLoot
end
function MasterLootRemind:SetResetLootStatusOption(newStatus)
	self.db.profile.ResetLoot = newStatus
	self:ToggleLootStatusEvents(self.db.profile.ResetLoot)
end

function MasterLootRemind:IgnoreTarget()
	local targetName = UnitName("target")
	if targetName == nil then
		MasterLootRemind:Print(L["No target found."])
		return
	end
	if not BB:HasTranslation(targetName) then
		MasterLootRemind:Print(targetName .. L[" is not a known boss."])
		return
	end
	if MasterLootRemind:inTable(MasterLootRemindDB.Ignored, targetName) then
		MasterLootRemind:Print(targetName .. L[" is already being ignored."])
		return
	end
	table.insert(MasterLootRemindDB.Ignored, targetName)
	MasterLootRemind:Print(targetName .. L[" now permanently ignored!"])
end

function MasterLootRemind:RemoveSessionIgnore(name)
	local target = UnitExists("target") and UnitName("target") or nil
	if name == "%t" or name == "" and (target) then
		name = target
	end
	self:DelFromIgnore(name,"Session")
end

function MasterLootRemind:ResetIgnoreList(typeoflist)
	local tableName
	if typeoflist == "Permanent" then
		tableName = MasterLootRemindDB.Ignored
	elseif typeoflist == "Session" then
		tableName = MasterLootRemind._ignored
	end
	for i=table.getn(tableName),1, -1 do
		tableName[i]=nil
	end
	MasterLootRemind:Print(typeoflist .. L[" ignore list reset!"])
end

function MasterLootRemind:ViewIgnoreList(typeoflist)
	local tableName
	if typeoflist == "Permanent" then
		tableName = MasterLootRemindDB.Ignored
	elseif typeoflist == "Session" then
		tableName = MasterLootRemind._ignored
	end	
	if table.getn(tableName) == 0 then
		self:Print(typeoflist .. L[" ignore list is empty!"])
		return
	end
	self:Print(typeoflist .. L[" ignore list:"])
	for index, value in pairs(tableName) do
		self:Print(value)
	end
end

function MasterLootRemind:DelFromIgnore(name, typeoflist)
	local tableName
	if typeoflist == "Permanent" then
		tableName = MasterLootRemindDB.Ignored
	elseif typeoflist == "Session" then
		tableName = MasterLootRemind._ignored
	end
	if table.getn(tableName) == 0 then
		self:Print(typeoflist .. L[" ignore list is empty!"])
		return
	end
	local i
	i = MasterLootRemind:inTable(tableName, name)
	if i ~= nil then
		table.remove(tableName, i)
		self:Print(name .. L[" removed from "] .. typeoflist .. L[" ignore list!"])
	else
		self:Print(name .. L[" not found in "] .. typeoflist .. L[" ignore list!"])
	end
end

function MasterLootRemind:ToggleLootStatusEvents(enable)
	if (enable) then
		self:RegisterEvent("LOOT_CLOSED")
	else
		if self:IsEventRegistered("LOOT_CLOSED") then
			self:UnregisterEvent("LOOT_CLOSED")
		end
	end
end

function MasterLootRemind:ToggleCombatEvents(enable)
	if (enable) then
		for _,event in ipairs(combatEvents) do
			if not parser:IsEventRegistered("MasterLootRemind", event) then
				parser:RegisterEvent("MasterLootRemind", event, function(event, info) self:OnCombatEvent(event, info) end)
			end
		end
	else
		for _,event in ipairs(combatEvents) do
			if parser:IsEventRegistered("MasterLootRemind", event) then
				parser:UnregisterEvent("MasterLootRemind", event)
			end
		end
	end
end

function MasterLootRemind:PLAYER_TARGET_CHANGED()
	-- shortcircuit trivial cases
	if not (self.db.profile.Active) then return end
	if (self.db.profile.BossCombat) then return end
	if (MasterLootRemind._visible) then return end
	local lootmethod = GetLootMethod()
	if (lootmethod == "master") then return end
	-- check options
	local optType = self.db.profile.GroupType
	local getType = MasterLootRemind:GetGroupType()
	if (getType ~= 0 and (optType == 3 or getType == optType)) then
		local targetName, unitid
		if UnitIsPlayer("target") or UnitPlayerControlled("target") then
			unitid = "targettarget"
			targetName = UnitName(unitid)
		else
			unitid = "target"
			targetName = UnitName(unitid)
		end
		self:TestMLPopup(targetName,lootmethod,unitid)
	end
end

function MasterLootRemind:OnCombatEvent(event, info)
	-- shortcircuit trivial cases
	if not (self.db.profile.Active) then return end
	if not (self.db.profile.BossCombat) then return end
	if (MasterLootRemind._visible) then return end
	local lootmethod = GetLootMethod()
	if (lootmethod == "master") then return end
	local optType = self.db.profile.GroupType
	local getType = MasterLootRemind:GetGroupType()
	if (getType == 0) or (optType ~= 3 or getType ~= optType) then return end
	-- check for boss combat
	local source, victim = info.source, info.victim
	if source and (source ~= ParserLib_SELF and not self._roster[source]) then
		self:TestMLPopup(source,lootmethod)
	end
	if victim and (victim ~= ParserLib_SELF and not self._roster[victim]) then
		self:TestMLPopup(victim,lootmethod)
	end
end

function MasterLootRemind:Roster()
	self:Print(event)
	local numRaidMembers, numPartyMembers = GetNumRaidMembers(), GetNumPartyMembers()
	for name in pairs(self._roster) do
		-- this will grow to the players we've grouped with in the session but preferable to creating fresh tables
		self._roster[name]=false 
	end
	if numRaidMembers > 0 then
		for i=1,numRaidMembers do
			local player,pet = UnitName(raidUnit[i][1]),UnitName(raidUnit[i][2])
			if (player) and not BB:HasTranslation(player) then -- someone has named themselves as a boss
				self._roster[player] = true
			end
			if (pet) and not (BB:HasTranslation(pet)) then
				self._roster[pet] = true
			end
		end
	elseif numPartyMembers > 0 then
		for i=1,numPartyMembers do
			local player,pet = UnitName(partyUnit[i][1]),UnitName(partyUnit[i][2])
			if (player) and not BB:HasTranslation(player) then
				self._roster[player] = true
			end
			if (pet) and not BB:HasTranslation(pet) then
				self._roster[pet] = true
			end
		end
		pet = UnitName("pet")
		if (pet) and not BB:HasTranslation(pet) then
			self._roster[pet] = true
		end
	end
end

function MasterLootRemind:LOOT_CLOSED()
	-- shortcircuit trivial cases
	if not (self.db.profile.Active) then return end
	if not (self.db.profile.ResetLoot) then return end
	if (MasterLootRemind._resetVisible) then return end
	if (MasterLootRemind._visible) then return end
	local lootmethod = GetLootMethod()
	if (lootmethod ~= "master") then return end
	local optType = self.db.profile.GroupType
	local getType = MasterLootRemind:GetGroupType()
	if (getType == 0) or (optType ~= 3 or getType ~= optType) then return end
	-- check conditions
	local targetName = UnitExists("target") and UnitName("target") or nil
	if not (targetName) then return end
	if (not MasterLootRemind._bossName) or (MasterLootRemind._bossName == "_NONE_") then return end
	local lootDesc = lootMethodDesc[MasterLootRemind._lastLootMethod]
	if (string.lower(targetName) == string.lower(MasterLootRemind._bossName)) then
		StaticPopup_Show("MASTERLOOTREMIND_RESET_POPUP",lootDesc)
	end
end

function MasterLootRemind:GetGroupType()
	-- 1 = Party only, 2 = Raid only, 3 = Both
	if not IsPartyLeader() then
		return 0
	elseif UnitExists("party1") and not UnitInRaid("player") then
		return 1
	elseif UnitInRaid("player") then
		return 2
	end
end

function MasterLootRemind:isIgnored(UnitName)
	if MasterLootRemind:inTable(MasterLootRemindDB.Ignored, UnitName) or MasterLootRemind:inTable(MasterLootRemind._ignored, UnitName) then
		return true
	else
		return false
	end
end

function MasterLootRemind:Ignore()
	if (not MasterLootRemind._bossName) 
		or (MasterLootRemind._bossName == "_NONE_") 
		or (MasterLootRemind:inTable(MasterLootRemind._ignored, MasterLootRemind._bossName) ~= nil) then
		return
	end
	MasterLootRemind:Print(L["Now ignoring: "] .. MasterLootRemind._bossName)
	table.insert(MasterLootRemind._ignored, MasterLootRemind._bossName)
end

function MasterLootRemind:inTable(tableName, searchString)
	if not searchString then return false end
	for index, value in pairs(tableName) do
		if string.lower(value) == string.lower(searchString) then
			return index
		end
	end
	return nil
end

function MasterLootRemind:TestMLPopup(name,method,unit)
	if (name) 
		and (BB:HasTranslation(name) 
			and (MasterLootRemind._whitelist[name] or (unit == nil or UnitIsEnemy("player", unit))) 
			and (not MasterLootRemind._blacklist[name])) then
		if MasterLootRemind:isIgnored(name) == false then
			local dialog = StaticPopup_Show("MASTERLOOTREMIND_SET_POPUP",name)
			if (dialog) then
				MasterLootRemind._bossName = name
				dialog.data = name
				dialog.data2 = method
			end
		end
	end
end

StaticPopupDialogs["MASTERLOOTREMIND_SET_POPUP"] = {
	text = L["%s Detected!. Set yourself as Master Looter?"],
	button1 = TEXT(YES),
	button2 = TEXT(NO),
	OnShow = function()
		MasterLootRemind._visible = true
	end,
	OnAccept = function(name,method)
		MasterLootRemind._bossName = name
		MasterLootRemind._lastLootMethod = method
		SetLootMethod("master", UnitName("player"))
		MasterLootRemind._visible = false
	end,
	OnCancel = function()
		MasterLootRemind:Ignore(MasterLootRemind._bossName)
		MasterLootRemind._bossName = "_NONE_"
		MasterLootRemind._visible = false
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	notClosableByLogout = 1,
	cancels = "MASTERLOOTREMIND_RESET_POPUP"
}
StaticPopupDialogs["MASTERLOOTREMIND_RESET_POPUP"] = {
	text = L["Reset looting to %s?"],
	button1 = TEXT(YES),
	button2 = TEXT(NO),
	OnShow = function()
		MasterLootRemind._resetVisible = true
	end,
	OnAccept = function()
		SetLootMethod(MasterLootRemind._lastLootMethod)
		MasterLootRemind._resetVisible = false
		MasterLootRemind._bossName = "_NONE_"
	end,
	OnCancel = function()
		MasterLootRemind._resetVisible = false
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1
}