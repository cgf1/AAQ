local LD = LibDialog
local version = '1.5'
local chatters = {
   "ZO_ChatterOption1",
   "ZO_ChatterOption2",
   "ZO_ChatterOption3",
   "ZO_ChatterOption4",
   "ZO_ChatterOption5",
   "ZO_ChatterOption6",
   "ZO_ChatterOption7",
   "ZO_ChatterOption8",
   "ZO_ChatterOption9",
   "ZO_ChatterOption10"
}

local myname = 'AAQ'
local saved = nil
local SLASH_COMMANDS = SLASH_COMMANDS

local seen

local giver
local function accept(name, val)
    if not val then
	SelectChatterOption(1)
	saved.quests[name] = nil
    else
	LD:ShowDialog("AAQ", "AutoIt")
    end
end

local function quest_added(_, n, name)
    if giver then
	local repeatable = seen[giver]
	if repeatable == nil then
	    repeatable =  GetJournalQuestRepeatType(n)
	    seen[giver] = repeatable ~= QUEST_REPEAT_NOT_REPEATABLE
	end
	if repeatable or saved.nonrepeatable then
	    saved.quests[giver] = name
	end
	giver = nil
    end
end

local function affirmative()
    saved.quests[giver] = true -- for now
    SelectChatterOption(1)
end

local function negatory()
end

local function offered()
    local name = GetUnitName("interact")
    if saved.quests[name] then
	AcceptOfferedQuest()
    end
end

local function completed()
    local name = GetUnitName("interact")
    if saved.quests[name] then
	d("automatically completing " .. name)
	CompleteQuest()
    end
end

local function chatter(step, n)
    local name = GetUnitName("interact")
    -- d("CHATTER_HANDLER " .. tostring(step) .. ' ' .. tostring(n) .. ' ' .. name)
    local text
    local func
    if n > 1 or name:lower():find(' writ') ~= nil or (not saved.nonrepeatable and seen[name] == false) then
	return
    end
    if n == 0 and saved.quests[name] then
	text = "|cff0000Stop accepting this quest automatically|r"
	func = function() accept(name, false) end
    elseif saved.quests[name] then
	giver = name
	SelectChatterOption(1)
	return
    else
	local _, otype = GetChatterOption(1)
	if otype ~= CHATTER_START_NEW_QUEST_BESTOWAL then
	    return
	end
	text = "|c00ff00Accept this quest automatically from now on|r"
	func = function() accept(name, true) end
	giver = name
    end
    
    local option = _G[chatters[n + 2]]
    if option == nil then
	return
    end
    local iconc = option:GetChild()
    local iconcc = iconc:GetChild()

    option:SetText(text)
    option:SetMouseEnabled(true)
    option:SetHandler("OnMouseDown", func)
    option:SetHidden(false)
    iconc:SetHidden(true)
end

local function addmenu(x, y, z)
    d("X " .. tostring(x) .. ' Y ' .. tostring(y) .. ' Z ' .. tostring(z))
    AddMenuItem("Hello", function () d("HELLO!") end)
end

local function tracked(name)
    for issuer, qname in pairs(saved.quests) do
	if name == qname then
	    return issuer
	end
    end
end

local orig_ZO_QuestJournalNavigationEntry_OnMouseUp

local function journal_hook(label, button, upInside)
    orig_ZO_QuestJournalNavigationEntry_OnMouseUp(label, button, upInside)
    local ix = label.node.data.questIndex
    if ix and button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
	local name = tracked(GetJournalQuestName(ix))
	if name then
	    AddCustomMenuItem("Stop accepting automatically", function()
		saved.quests[name] = nil
	    end)
	    ShowMenu(label)
	end
    end
end

local function init_settings()
    local o = {
	{
	    type = "header",
	    name = "Options"
	},
	{
	    type = "checkbox",
	    name = "Apply to non-repeatable quests",
	    tooltip = "Add option to all quests, not just repeatable",
	    getFunc = function()
		return saved.nonrepeatable
	    end,
	    setFunc = function(x)
		saved.nonrepeatable = x
	    end,
	    default = false
	},
	{
	    type = "checkbox",
	    name = "Clear all saved quests?",
	    tooltip = "Click to forget all learned quests and start fresh",
	    getFunc = function(x) return false end,
	    setFunc = function(x)
		if x then
		    saved.quests = {}
		end
	    end,
	    default = false
	}
    }
    local LAM = LibAddonMenu2
    local m = GetAddOnManager()
    for i = 1, m:GetNumAddOns() do
	name, title, author, description = m:GetAddOnInfo(i)
	if name == myname then
	    break
	end
    end
    local paneldata = {
	    type = "panel",
	    name = title,
	    displayName = "|c00B50F" .. title .. "|r",
	    author = author,
	    description = description,
	    version = version,
	    registerForDefaults = true,
	    registerForRefresh = true
    }
    LAM:RegisterAddonPanel("AAQsettings", paneldata)
    LAM:RegisterOptionControls("AAQsettings", o)
end

local function init(_, name)
    if name ~= myname then
	return
    end
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
    if LD == nil then
	d("AAQ: Error: Couldn't load LibDialog")
	return
    end
    saved = ZO_SavedVars:NewAccountWide(name, 1, nil, {nonrepeatable = false, quests = {}, repeatable = {}})
    seen = saved.repeatable
    LD:RegisterDialog("AAQ", "AutoIt", "Automatically accept this quest from now on?", "Are you sure?", affirmative, negatory)

    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_CONFIRM_INTERACT, function() --[[ d("CONFIRM_INTERACT") --]] end)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_CHATTER_BEGIN, chatter)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_CONVERSATION_UPDATED, function(x, y) --[[ d("CONVERSATION_UPDATED") --]] end)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_QUEST_COMPLETE_DIALOG, completed)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_QUEST_OFFERED, offered)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_ADDED, quest_added)
    SLASH_COMMANDS["/aaqdump"] = function ()
	for n, v in pairs(saved.quests) do
	    d(string.format("%s = %s", n, tostring(v)))
	end
    end
    orig_ZO_QuestJournalNavigationEntry_OnMouseUp = ZO_QuestJournalNavigationEntry_OnMouseUp
    ZO_QuestJournalNavigationEntry_OnMouseUp = journal_hook
    init_settings()
end

EVENT_MANAGER:RegisterForEvent(myname, EVENT_ADD_ON_LOADED, init)
