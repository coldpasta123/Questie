---@class QuestiePlayer
---@field numberOfGroupMembers number @The number of players currently in the group
---@field faction number @"Horde" or "Alliance"
local QuestiePlayer = QuestieLoader:CreateModule("QuestiePlayer");
local _QuestiePlayer = QuestiePlayer.private
-------------------------
--Import modules.
-------------------------
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

---@type table<QuestId, Quest>
QuestiePlayer.currentQuestlog = {} --Gets populated by QuestieQuest:GetAllQuestIds(), this is either an object to the quest in question, or the ID if the object doesn't exist.
_QuestiePlayer.playerLevel = -1
local playerRaceId = -1
local playerRaceFlag = 255 -- dummy default value to always return race not matching, corrected in init
local playerRaceFlagX2 = 1 -- dummy default value to always return race not matching, corrected in init
local playerClassName = ""
local playerClassFlag = 255 -- dummy default value to always return class not matching, corrected in init
local playerClassFlagX2 = 1 -- dummy default value to always return class not matching, corrected in init

-- Optimizations
local math_max = math.max;

QuestiePlayer.numberOfGroupMembers = 0

function QuestiePlayer:Initialize()
    _QuestiePlayer.playerLevel = UnitLevel("player")

    playerRaceId = select(3, UnitRace("player"))
    playerRaceFlag = 2 ^ (playerRaceId - 1)
    playerRaceFlagX2 = 2 * playerRaceFlag

    playerClassName = select(1, UnitClass("player"))
    local classId = select(3, UnitClass("player"))
    playerClassFlag = 2 ^ (classId - 1)
    playerClassFlagX2 = 2 * playerClassFlag

    QuestiePlayer.faction = UnitFactionGroup("player")
end

--Always compare to the UnitLevel parameter, returning the highest.
---@param level Level
function QuestiePlayer:SetPlayerLevel(level)
    local localLevel = UnitLevel("player");
    _QuestiePlayer.playerLevel = math_max(localLevel, level);
end

-- Gets the highest playerlevel available, most of the time playerLevel should be the most correct one
-- doing UnitLevel for completeness.
---@return Level
function QuestiePlayer.GetPlayerLevel()
    local level = UnitLevel("player");
    return math_max(_QuestiePlayer.playerLevel, level);
end

-- Find out if the player is at max level for the active expansion
---@return boolean isMaxLevel
function QuestiePlayer.IsMaxLevel()
    local level = QuestiePlayer.GetPlayerLevel()
    return (Questie.IsMoP and level == 90) or (Questie.IsCata and level == 85) or (Questie.IsWotlk and level == 80) or (Questie.IsTBC and level == 70) or (Questie.IsClassic and level == 60)
end

---@return string
function QuestiePlayer:GetLocalizedClassName()
    return playerClassName
end

function QuestiePlayer:GetGroupType()
    if(UnitInRaid("player")) then
        return "raid";
    elseif(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
        return "instance";
    elseif(UnitInParty("player")) then
        return "party";
    else
        return nil;
    end
end

---@return boolean
function QuestiePlayer.HasRequiredRace(requiredRaces)
    -- test a bit flag: (value % (2*flag) >= flag)
    return (not requiredRaces) or (requiredRaces == 0) or ((requiredRaces % playerRaceFlagX2) >= playerRaceFlag)
end

---@return boolean
function QuestiePlayer.HasRequiredClass(requiredClasses)
    -- test a bit flag: (value % (2*flag) >= flag)
    return (not requiredClasses) or (requiredClasses == 0) or ((requiredClasses % playerClassFlagX2) >= playerClassFlag)
end

function QuestiePlayer:GetCurrentZoneId()
    local uiMapId = C_Map.GetBestMapForUnit("player")
    if uiMapId then
        return ZoneDB:GetAreaIdByUiMapId(uiMapId)
    end

    return ZoneDB.instanceIdToUiMapId[select(8, GetInstanceInfo())]
end

---@return number
function QuestiePlayer:GetCurrentContinentId()
    local currentZoneId = QuestiePlayer:GetCurrentZoneId()
    if (not currentZoneId) or currentZoneId == 0 then
        return 1 -- Default to Eastern Kingdom
    end

    local currentContinentId = 1 -- Default to Eastern Kingdom
    for cId, cont in pairs(l10n.zoneLookup) do
        for id, _ in pairs(cont) do
            if id == currentZoneId then
                currentContinentId = cId
            end
        end
    end

    return currentContinentId
end

function QuestiePlayer:GetPartyMemberByName(playerName)
    if(UnitInParty("player") or UnitInRaid("player")) then
        local player = {}
        for index=1, 40 do
            local name, realmName = UnitName("party"..index);
            if realmName then
                name = name .. "-" .. realmName
            end
            local _, classFilename = UnitClass("party"..index);
            if name == playerName then
                player.name = playerName;
                player.class = classFilename;
                local rPerc, gPerc, bPerc, argbHex = GetClassColor(classFilename)
                player.r = rPerc;
                player.g = gPerc;
                player.b = bPerc;
                player.colorHex = argbHex;
                return player;
            end
            if(index > 6 and not UnitInRaid("player")) then
                break;
            end
        end
    end
    return nil;
end

return QuestiePlayer
