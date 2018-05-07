local version = '1.0'
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

local function accept(name, val)
    saved.quests[name] = val
    SelectChatterOption(1)
end

local function offered_handler()
    local name = GetUnitName("interact")
    if saved.quests[name] then
	AcceptOfferedQuest()
    end
end

local function completed_handler()
    local name = GetUnitName("interact")
    if saved.quests[name] then
	CompleteQuest()
    end
end

local function chatter_handler(step, n)
    local name = GetUnitName("interact")
    local text
    local func
    if n > 1 or name:lower():find(' writ') ~= nil  then
	return
    end
    if n == 0 then
	if not saved.quests[name] then
	    return
	end
	text = "|cff0000[Stop accepting this quest automatically]|r"
	func = function() accept(name, false) end
    elseif saved.quests[name] then
	SelectChatterOption(1)
	return
    else
	local _, otype = GetChatterOption(1)
	if otype ~= CHATTER_START_NEW_QUEST_BESTOWAL then
	    return
	end
	text = "|c00ff00[Accept this quest automatically from now on]|r"
	func = function() accept(name, true) end
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

local function init(_, name)
    if name ~= myname then
	return
    end
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide(name, 1, nil, {quests = {}})

    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_CONFIRM_INTERACT, function() d("CONFIRM_INTERACT") end)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_CHATTER_BEGIN, chatter_handler)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_CONVERSATION_UPDATED, function(x, y) d("CONVERSATION_UPDATED") end)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_QUEST_COMPLETE_DIALOG, completed_handler)
    ZO_InteractWindowPlayerAreaOptions:RegisterForEvent(EVENT_QUEST_OFFERED, offered_handler)
end

EVENT_MANAGER:RegisterForEvent(myname, EVENT_ADD_ON_LOADED, init)
