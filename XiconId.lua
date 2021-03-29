local ADDON_NAME = "XiconId"
local VERSION = "v1.0.0-Release"

local print = function(s)
    local str = s
    if s == nil then str = "nil" end
    if type(str) == "boolean" then
        if str then
            str = "true"
        else
            str = "false"
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffa0f6aa[".. ADDON_NAME .."]|r: " .. str)
end

---------------------------------------------------------------------------------------------

-- FRAME SETUP & CONSTANTS

---------------------------------------------------------------------------------------------

local idCache = {}
--local iconCache = {}
local XiconId = CreateFrame("Frame", "XiconId")
local methodList = {
    item = {
        "SetHyperlink",
        "SetBagItem",
        "SetInventoryItem",
        -- auction
        "SetAuctionItem",
        "SetAuctionSellItem",
        -- loot
        "SetLootItem",
        "SetLootRollItem",
        -- crafting
        "SetCraftSpell",
        "SetCraftItem",
        "SetTradeSkillItem",
        "SetTrainerService",
        -- mail
        "SetInboxItem",
        "SetSendMailItem",
        -- quest log
        "SetQuestItem",
        "SetQuestLogItem",
        -- trade
        "SetTradePlayerItem",
        "SetTradeTargetItem",
        -- vendor tooltip
        "SetMerchantItem",
        "SetBuybackItem",
        "SetMerchantCostItem",
        -- socketing interface
        "SetSocketGem",
        "SetExistingSocketGem",
        -- 2.1.0
        "SetHyperlinkCompareItem",
        -- 2.3.0
        "SetGuildBankItem",
    },
    buff = {
        "SetPlayerBuff",
        "SetUnitBuff",
        "SetUnitDebuff",
    },
    spell = {
        "SetSpell",
    },
    talant = {
        "SetTalent",
    },
    unit = {
        "SetUnit",
    },
    action = {
        "SetAction",
        "SetPetAction",
    },
}

---------------------------------------------------------------------------------------------

-- PARSE FUNCTIONS

---------------------------------------------------------------------------------------------

local function parseLink(tooltip, link, str, pattern)
    local ID = string.match(link, pattern)
    local _, rank = GetSpellInfo(ID)
    rank = rank and string.find(rank, "%d+") and "(R" .. string.match(rank, "%d+") .. ")" or ""
    tooltip:AddLine("  ")
    tooltip:AddLine(str .. ID .. rank)
    tooltip:Show()
end

local function parseAura(tooltip, name, rank)
    if GetSpellLink(name, rank) or GetSpellLink(name) then
        parseLink(tooltip, GetSpellLink(name, rank) or GetSpellLink(name), "SpellID: ", "spell:(%d+)")
        return
    elseif XiconIdDB.idCache[name] then
        local possibleSpellIDs = ""
        local cacheIndex = 0
        for spellID, ranks in pairs(XiconIdDB.idCache[name]) do
            local spell = ranks == "" and spellID or spellID .. "(" .. ranks .. ")"
            if cacheIndex ~= 0 and cacheIndex % 10 == 0 then
                possibleSpellIDs = possibleSpellIDs .. ",\n"
            end
            if cacheIndex == 0 then
                possibleSpellIDs = possibleSpellIDs .. spell
            else
                possibleSpellIDs = string.find(possibleSpellIDs, "\n$") and possibleSpellIDs .. "       " .. spell or possibleSpellIDs .. "," .. spell
            end
            cacheIndex = cacheIndex + 1
        end
        tooltip:AddLine("  ")
        tooltip:AddLine(cacheIndex > 1 and "SpellIDs: " .. possibleSpellIDs or "SpellID: " .. possibleSpellIDs)
        tooltip:Show()
        return
    end
end

local function parseSpellOrItem(tooltip, spellId)
    local _, link = tooltip:GetItem()
    if link then
        local _, itemLink, _, level = GetItemInfo(link)
        local str
        if level then
            str = "ItemLvl: " .. level
        end
        if itemLink then
            parseLink(tooltip, itemLink, str and str .. ", ItemID: " or "ItemID: ", "item:(%d+)")
        end
        return
    end
    local name, rank = tooltip:GetSpell()
    if rank and GetSpellLink(name, rank) then
        parseLink(tooltip, GetSpellLink(name, rank), "SpellID: ", "spell:(%d+)")
        return
    end

    ---SpellLink
    if spellId and type(spellId) == "string" and  string.match(spellId,"spell.*") then
        name, rank = GetSpellInfo(spellId)
        rank = rank and string.find(rank, "%d+") and "(R" .. string.match(rank, "%d+") .. ")" or ""
        tooltip:AddLine("  ")
        tooltip:AddLine("SpellID: " .. spellId .. rank)
        tooltip:Show()
        return
    end
end

local function parseTalent(tooltip, tab, id, inspect)
    local name, rank = tooltip:GetSpell()
    if rank and GetSpellLink(name, rank) then
        parseLink(tooltip, GetSpellLink(name, rank), "SpellID: ", "spell:(%d+)")
        return
    end
    if tab and id then
        local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, id, inspect)
        parseAura(tooltip, name, rank)
    end
end

local function parsePlayerBuff(tooltip, index)
    if index and type(index) == 'number' and index > 0 then
        for i=1, BUFF_MAX_DISPLAY do
            local name, rank, icon, count, duration, timeLeft, isMine,isStealable, shouldConsolidate, spellId = UnitBuff("player", i)
            if not name then break end
            if (GetPlayerBuffTexture(index, "HELPFUL") == icon) then
                parseAura(tooltip, name, rank)
            end
        end
        for i=1, DEBUFF_MAX_DISPLAY do
            local name, rank, icon, count, debuffType, duration, timeLeft, isMine = UnitDebuff("player", i)
            if not name then break end
            if (GetPlayerBuffTexture(index, "HARMFUL") == icon) then
                parseAura(tooltip, name, rank)
            end
        end
    end
end

local function parseUnitDebuff(tooltip, unit, index)
    local name, rank = UnitDebuff(unit, index)
    if not name then return end
    parseAura(tooltip, name, rank)
end

local function parseUnitBuff(tooltip, unit, index)
    local name, rank = UnitBuff(unit, index)
    if not name then return end
    parseAura(tooltip, name, rank)
end



---------------------------------------------------------------------------------------------

-- EVENT HANDLERS

---------------------------------------------------------------------------------------------

function XiconId:ADDON_LOADED(...)
    if select(1, ...) == ADDON_NAME then
        if not XiconIdDB then
            XiconIdDB = { idCache = {}}
        end
        if not XiconIdDB.idCache then XiconIdDB.idCache = {} end
        ---spellID
        hooksecurefunc(GameTooltip, "SetSpell", parseSpellOrItem)

        ---itemID
        for _,v in ipairs(methodList["item"]) do
            hooksecurefunc(GameTooltip, v, parseSpellOrItem)
        end

        ---spellID and itemID
        hooksecurefunc(GameTooltip, "SetAction", parseSpellOrItem)
        hooksecurefunc(GameTooltip, "SetPetAction", parseSpellOrItem)
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", parseSpellOrItem)

        ---talent
        hooksecurefunc(GameTooltip, "SetTalent", parseTalent)

        --- player buffs
        hooksecurefunc(GameTooltip, "SetPlayerBuff", parsePlayerBuff)

        --- unit debuff
        hooksecurefunc(GameTooltip, "SetUnitDebuff", parseUnitDebuff)

        --- unit buff
        hooksecurefunc(GameTooltip, "SetUnitBuff", parseUnitBuff)

        --- icon and id cache
        local num = 0;
        for _,_ in pairs(XiconIdDB.idCache) do
            num = num + 1;
        end
        if (num < 15466) then
            XiconId.CreateIconCache()
            --XiconIdDB.iconCache = iconCache
            XiconIdDB.idCache = idCache
        end
    end
end

---------------------------------------------------------------------------------------------

-- REGISTER EVENTS

---------------------------------------------------------------------------------------------

XiconId:SetScript("OnEvent", function(self, event, ...)
    XiconId[event](self, ...); -- call one of the functions above
end);
for k, _ in pairs(XiconId) do
    XiconId:RegisterEvent(k); -- Register all events for which handlers have been defined
end

---------------------------------------------------------------------------------------------

-- SPELLID CACHE

---------------------------------------------------------------------------------------------

-- Handle coroutines
local dynFrame = {};
do
    -- Internal data
    dynFrame.frame = CreateFrame("frame");
    dynFrame.update = {};
    dynFrame.size = 0;

    -- Add an action to be resumed via OnUpdate
    function dynFrame.AddAction(self, name, func)
        if not name then
            name = string.format("NIL", dynFrame.size+1);
        end

        if not dynFrame.update[name] then
            dynFrame.update[name] = func;
            dynFrame.size = dynFrame.size + 1

            dynFrame.frame:Show();
        end
    end

    -- Remove an action from OnUpdate
    function dynFrame.RemoveAction(self, name)
        if dynFrame.update[name] then
            dynFrame.update[name] = nil
            dynFrame.size = dynFrame.size - 1

            if dynFrame.size == 0 then
                dynFrame.frame:Hide()
            end
        end
    end

    -- Setup frame
    dynFrame.frame:Hide()
    dynFrame.frame:SetScript("OnUpdate", function(self, elapsed)
        -- Start timing
        local start = debugprofilestop()
        local hasData = true

        -- Resume as often as possible (Limit to 16ms per frame -> 60 FPS)
        while (debugprofilestop() - start < 16 and hasData) do
            -- Stop loop without data
            hasData = false

            -- Resume all coroutines
            for name, func in pairs(dynFrame.update) do
                -- Loop has data
                hasData = true

                -- Resume or remove
                if coroutine.status(func) ~= "dead" then
                    local err,ret1,ret2 = assert(coroutine.resume(func))
                else
                    dynFrame:RemoveAction(name)
                end
            end
        end
    end);
end

function XiconId.CreateIconCache(callback)
    local func = function()
        local id = 0
        local misses = 0

        while (misses < 200) do
            id = id + 1
            local name, rank, icon = GetSpellInfo(id);
            if(name) then
                --[[if not(iconCache[name]) then
                    iconCache[name] = icon
                end--]]
                if not(idCache[name]) then
                    idCache[name] = {}
                end
                idCache[name][id] = type(rank) == "string" and string.match(rank, "%d+") and "R" .. string.match(rank, "%d+") or rank
                misses = 0;
            else
                misses = misses + 1
            end
            coroutine.yield()
        end

        if(callback) then
            callback()
        end
    end

    local co = coroutine.create(func)
    dynFrame:AddAction(callback, co)
end