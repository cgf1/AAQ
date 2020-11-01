local version = '1.19'
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
local ZO_Dialogs_ShowDialog = ZO_Dialogs_ShowDialog

local seen

local giver
local curgiver
local curqname

local title = "Automatically Accept Quests (v" .. version .. ")"

local function quest_added(_, n, qname)
    local repeatable =	GetJournalQuestRepeatType(n) ~= QUEST_REPEAT_NOT_REPEATABLE
    if giver and not giver:lower():find(' writ') and not saved.quests[giver] and not saved.quests['-' .. giver] and (repeatable or saved.nonrepeatable) then
	curgiver = giver
	curqname = qname
	ZO_Dialogs_ShowDialog("AAQ", {}, {titleParams = {title}, mainTextParams = {giver}})
    else
	if saved.quests[giver] ~= nil then
	    saved.quests[giver] = qname
	end
	giver = nil
    end
end

local function quest_shared()
    giver = nil
end

local function affirmative()
    saved.quests[curgiver] = curqname
    giver = nil
    curgiver = nil
    curqname = nil
end

local function nochoice()
    giver = nil
    curgiver = nil
    curqname = nil
end

local function negatory()
    saved.quests['-' .. curgiver] = curqname
    curgiver = nil
    giver = nil
    curqname = nil
end

local function quest_offered()
    local issuer = GetUnitName("interact")
    if saved.quests[issuer] then
	giver = issuer
	AcceptOfferedQuest()
    end
end

local function completed()
    local issuer = GetUnitName("interact")
    if saved.quests[issuer] then
	df("automatically completing %s", saved.quests[issuer])
	CompleteQuest()
    end
end

local function chatbeg(_, n)
    local pgiver = GetUnitName("interact")
    if not saved.quests[pgiver] then
	giver = pgiver
    else
	SelectChatterOption(1)
	giver = nil
    end
end

local function chatend()
    giver = nil
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
	local issuer = tracked(GetJournalQuestName(ix))
	if issuer then
	    AddCustomMenuItem("Reset automatic quest acceptance", function()
		saved.quests[issuer] = nil
		saved.quests['-' .. issuer] = nil
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
    local name, title, author
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
    saved = ZO_SavedVars:NewAccountWide(name, 1, nil, {nonrepeatable = false, quests = {}, repeatable = {}})
    seen = saved.repeatable
    for n, v in pairs(saved.quests) do
	if n:lower():find(' writ') then
	    saved.quests[n] = nil
	end
    end
    saved.rgivers = {}

    local confirm = {
	title = { text = "Automatically Accept Quests"},
	mainText = {text = "Automatically accept/complete quests from <<1>> from now on?", align = TEXT_ALIGN_CENTER},
	warning = {text = "Hitting ESC/ALT will ask about this quest provider next time", align = TEXT_ALIGN_CENTER},
	noChoiceCallback = nochoice,
	buttons = {
	    {text = SI_YES, callback = affirmative},
	    {text = SI_NO, callback = negatory},
	},
    }
    ZO_Dialogs_RegisterCustomDialog("AAQ", confirm)

    EVENT_MANAGER:RegisterForEvent(name, EVENT_CONFIRM_INTERACT, function() --[[ d("CONFIRM_INTERACT") --]] end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CHATTER_BEGIN, chatbeg)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CHATTER_END, chatend)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CONVERSATION_UPDATED, function(x, y) --[[ d("CONVERSATION_UPDATED") --]] end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_COMPLETE_DIALOG, completed)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_OFFERED, quest_offered)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_ADDED, quest_added)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_SHARED, quest_shared)
    SLASH_COMMANDS["/aaqdel"] = function (s)
	saved.quests[s] = nil
    end
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
