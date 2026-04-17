-- MythicPlusTracker/core.lua

-- ==================================
-- 1. 本地化模块 (Localization)
-- ==================================
local L = {}
local currentLocale = GetLocale()

-- 默认语言 (简体中文 zhCN)
L["INSTANCE_239"] = "执政团之座"
L["INSTANCE_556"] = "萨隆矿坑"
L["INSTANCE_161"] = "通天峰"
L["INSTANCE_402"] = "艾杰斯亚学院"
L["INSTANCE_557"] = "风行者之塔"
L["INSTANCE_558"] = "魔导师平台"
L["INSTANCE_560"] = "迈萨拉洞窟"
L["INSTANCE_559"] = "节点希纳斯"

L["NO_KEY"] = "你没有当前的大秘境钥匙！"
L["NOT_IN_GROUP"] = "你不在小队或团队中，无法发送钥匙信息。"
L["CURRENT_KEY"] = "当前钥匙"
L["UNKNOWN_INSTANCE"] = "未知副本"
L["TIME_COMPLETED"] = "限时"
L["TIME_FAILED"] = "超时"
L["DEBUG_TITLE"] = "=== MythicPlusTracker 调试报告 ==="
L["DEBUG_API"] = "API 实时读取"
L["DEBUG_DB"] = "数据库 旧值"
L["DATA_UPDATED"] = "检测到变化！数据已更新。"
L["DATA_SAME"] = "数据一致，无需更新。"
L["DEBUG_DETAIL"] = "API 详细记录"
L["NO_KEY_CURRENT"] = "当前没有钥匙"
L["UI_TITLE"] = "本周大秘境统计"
L["UI_BUTTON_VIEW"] = "查看"
L["UI_BUTTON_SEND"] = "发送钥匙"
L["UI_TOTAL_RUNS"] = "本周总低保次数"
L["BUG_REPORT"] = "若发现Bug请联系尽是风流"

-- 英语 (enUS)
if currentLocale == "enUS" or currentLocale == "enGB" then
    L["INSTANCE_239"] = "Seat of the Triumvirate"
    L["INSTANCE_556"] = "Pit of Saron"
    L["INSTANCE_161"] = "Skyreach"
    L["INSTANCE_402"] = "Algeth'ar Academy"
    L["INSTANCE_557"] = "Windrunner Spire"
    L["INSTANCE_558"] = "Magister's Terrace"
    L["INSTANCE_560"] = "Maisara Caverns"
    L["INSTANCE_559"] = "Nexus-Point Xenas"
    
    L["NO_KEY"] = "You don't have a Mythic Keystone!"
    L["NOT_IN_GROUP"] = "You are not in a group or raid."
    L["CURRENT_KEY"] = "Current Keystone"
    L["UNKNOWN_INSTANCE"] = "Unknown Dungeon"
    L["TIME_COMPLETED"] = "Completed"
    L["TIME_FAILED"] = "Failed"
    L["DEBUG_TITLE"] = "=== MythicPlusTracker Debug Report ==="
    L["DEBUG_API"] = "API Read"
    L["DEBUG_DB"] = "Database Old Value"
    L["DATA_UPDATED"] = "Change detected! Data updated."
    L["DATA_SAME"] = "Data is consistent."
    L["DEBUG_DETAIL"] = "API Details"
    L["NO_KEY_CURRENT"] = "No current key"
    L["UI_TITLE"] = "Weekly M+ Stats"
    L["UI_BUTTON_VIEW"] = "View"
    L["UI_BUTTON_SEND"] = "Send Key"
    L["UI_TOTAL_RUNS"] = "Total Weekly Runs"
    L["BUG_REPORT"] = "Bug report to Jinshifengliu"
end

-- ==================================
-- 2. 首先定义 addonName
-- ==================================
local addonName = "MythicPlusTracker"

-- ==================================
-- 3. 立即创建 addon 表，避免任何索引赋值时为 nil
-- ==================================
local addon = {
    db = nil,
    displayFrame = nil,
    L = L -- 将本地化表挂载到 addon 上，方便内部函数访问
}

-- 将 addon 表注册到全局环境
_G[addonName] = addon

-- ==================================
-- 4. 副本 ID 映射表 (现在优先读取本地化，保留硬编码作为后备)
-- ==================================
-- 保留你原来的硬编码作为默认值，但如果 L 表里有翻译，则使用 L 表的
local MAP_ID_TO_NAME = {
    [239] = L["INSTANCE_239"] or "Seat of the Triumvirate",
    [556] = L["INSTANCE_556"] or "The MOTHERLODE!!",
    [161] = L["INSTANCE_161"] or "Waycrest Manor",
    [402] = L["INSTANCE_402"] or "Atal'Dazar",
    [557] = L["INSTANCE_557"] or "The Underrot",
    [558] = L["INSTANCE_558"] or "Tol Dagor",
    [560] = L["INSTANCE_560"] or "Motherlode Mine",
    [559] = L["INSTANCE_559"] or "Kings' Rest",
}

-- ==================================
-- 5. 默认配置
-- ==================================
local defaults = {
    chars = {},
}

-- ==================================
-- 6. 初始化数据库
-- ==================================
function addon:InitializeDB()
    if not MythicPlusTrackerDB or type(MythicPlusTrackerDB) ~= "table" then
        MythicPlusTrackerDB = CopyTable(defaults)
    else
        if not MythicPlusTrackerDB.chars then
            MythicPlusTrackerDB.chars = {}
        end
    end
    self.db = MythicPlusTrackerDB
end

-- ==================================
-- 7. 获取副本名称的辅助函数
-- ==================================
local function GetMapNameByID(mapID)
    if not mapID then return L["UNKNOWN_INSTANCE"] end
    local name = MAP_ID_TO_NAME[mapID]
    if name then return name end
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.name then
        return mapInfo.name
    end
    return string.format(L["UNKNOWN_INSTANCE"] .. " (ID:%d)", mapID)
end

-- ==================================
-- 8. 核心功能：获取 API 原始数据
-- ==================================
function addon:GetWeeklyRunsFromAPI()
    local runHistory = C_MythicPlus.GetRunHistory(false, true)
    local count = 0
    local debugInfo = ""
    if not runHistory then return 0, "" end
    for i, run in ipairs(runHistory) do
        if run.thisWeek and run.level >= 10 then
            count = count + 1
            local mapName = GetMapNameByID(run.mapChallengeModeID)
            -- 使用本地化字符串
            local timeStatus = run.completed and ("|cff00ff00" .. L["TIME_COMPLETED"] .. "|r") or ("|cffff0000" .. L["TIME_FAILED"] .. "|r")
            debugInfo = debugInfo .. string.format("\n %d. +%d %s [%s]", i, run.level, mapName, timeStatus)
        end
    end
    return count, debugInfo
end

-- ==================================
-- 9. 获取当前钥匙信息
-- ==================================
function addon:GetCurrentKeystoneInfo()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if level and mapID then
        local mapName = GetMapNameByID(mapID)
        return level, mapName
    end
    return nil, nil
end

-- ==================================
-- 10. 发送钥匙信息到小队
-- ==================================
function addon:SendKeystoneInfoToParty()
    local level, mapName = self:GetCurrentKeystoneInfo()
    if not level then
        -- 使用本地化字符串
        print("|cffff0000" .. L["NO_KEY"] .. "|r")
        return
    end
    local inParty = IsInGroup(LE_PARTY_CATEGORY_HOME)
    local inRaid = IsInRaid(LE_PARTY_CATEGORY_HOME)
    if not inParty and not inRaid then
        -- 使用本地化字符串
        print("|cffff0000" .. L["NOT_IN_GROUP"] .. "|r")
        return
    end
    -- 使用本地化字符串
    local message = string.format(L["CURRENT_KEY"] .. ": +%d %s", level, mapName)
    if inRaid then
        SendChatMessage(message, "RAID")
    else
        SendChatMessage(message, "PARTY")
    end
end

-- ==================================
-- 11. 更新当前角色数据
-- ==================================
function addon:UpdateCurrentCharData(silent)
    local charName = UnitName("player")
    local realm = GetRealmName()
    local fullName = charName .. "-" .. realm
    local apiRuns, apiDebug = self:GetWeeklyRunsFromAPI()
    local _, class = UnitClass("player")
    local oldData = self.db.chars[fullName]
    local savedRuns = oldData and oldData.runs or 0
    self.db.chars[fullName] = {
        runs = apiRuns,
        lastUpdate = time(),
        class = class
    }
end

-- ==================================
-- 12. 打印调试报告
-- ==================================
function addon:PrintDebugReport()
    local charName = UnitName("player")
    local realm = GetRealmName()
    local fullName = charName .. "-" .. realm
    local apiRuns, apiDebug = self:GetWeeklyRunsFromAPI()
    local oldData = self.db.chars[fullName]
    local savedRuns = oldData and oldData.runs or 0
    -- 使用本地化字符串
    print("\n|cff00ff00" .. L["DEBUG_TITLE"] .. "|r")
    print(string.format("角色: %s", fullName))
    print(string.format(L["DEBUG_API"] .. ": |cffff0000%d|r", apiRuns))
    print(string.format(L["DEBUG_DB"] .. ": |cffff0000%d|r", savedRuns))
    local level, mapName = self:GetCurrentKeystoneInfo()
    if level then
        print(string.format(L["CURRENT_KEY"] .. ": |cffffff00+%d %s|r", level, mapName))
    else
        print("|cffff0000" .. L["NO_KEY_CURRENT"] .. "|r")
    end
    if apiRuns ~= savedRuns then
        print("|cffffff00" .. L["DATA_UPDATED"] .. "|r")
    else
        print("|cff00ff00" .. L["DATA_SAME"] .. "|r")
    end
    if apiDebug ~= "" then
        print("|cffaaaaaa" .. L["DEBUG_DETAIL"] .. ":" .. apiDebug .. "|r")
    end
    print("|cff00ff00===================================|r\n")
end

-- ==================================
-- 13. 获取职业颜色代码
-- ==================================
function addon:GetClassColorCode(class)
    if not class then return "|cffffffff" end
    if not RAID_CLASS_COLORS then return "|cffffffff" end
    local classColors = RAID_CLASS_COLORS[class]
    if classColors then
        return string.format("|cff%02x%02x%02x", math.floor(classColors.r * 255), math.floor(classColors.g * 255), math.floor(classColors.b * 255))
    else
        return "|cffffffff"
    end
end

-- ==================================
-- 14. 根据完成次数获取箱子图标
-- ==================================
function addon:GetChestIconByRuns(runs)
    if runs >= 1 and runs <= 3 then
        return " |cff00ff00★|r"
    elseif runs >= 4 and runs <= 7 then
        return " |cff00ff00★★|r"
    elseif runs >= 8 then
        return " |cff00ff00★★★|r"
    else
        return ""
    end
end

-- ==================================
-- 15. 创建显示框架
-- ==================================
function addon:CreateDisplayFrame()
    if self.displayFrame then return self.displayFrame end
    local f = CreateFrame("Frame", "MythicPlusTrackerFrame", PVEFrame, "BackdropTemplate")
    f:SetSize(320, 280)
    f:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 5, -10)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:Hide()

    -- 标题
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -8)
    -- 使用本地化字符串
    f.title:SetText(L["UI_TITLE"])
    f.title:SetTextColor(1, 0.82, 0)

    -- 查看按钮
    f.printBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.printBtn:SetSize(50, 22)
    f.printBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", -80, 15)
    -- 使用本地化字符串
    f.printBtn:SetText(L["UI_BUTTON_VIEW"])
    f.printBtn:SetNormalFontObject("GameFontNormalSmall")
    f.printBtn:SetScript("OnClick", function(self)
        addon:PrintDebugReport()
    end)

    -- 发送钥匙按钮
    f.sendKeystoneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.sendKeystoneBtn:SetSize(80, 22)
    f.sendKeystoneBtn:SetPoint("BOTTOMLEFT", f, "BOTTOM", 5, 15)
    -- 使用本地化字符串
    f.sendKeystoneBtn:SetText(L["UI_BUTTON_SEND"])
    f.sendKeystoneBtn:SetNormalFontObject("GameFontNormalSmall")
    f.sendKeystoneBtn:SetScript("OnClick", function(self)
        addon:SendKeystoneInfoToParty()
    end)

    -- 关闭按钮
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButtonNoScripts")
    f.closeBtn:SetSize(24.5, 24.5)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.closeBtn:SetScript("OnClick", function(self)
        f:Hide()
    end)

    -- 文本显示区域
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", -35, -15)
    f.text:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.text:SetPoint("BOTTOM", f, "BOTTOM", 0, 40)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetWidth(300)

    self.displayFrame = f

    -- 关键：监听PVEFrame的显示/隐藏
    if PVEFrame then
        PVEFrame:HookScript("OnShow", function()
            if addon.displayFrame and addon.db then
                addon.displayFrame:Show()
                addon:UpdateDisplay()
            end
        end)
        PVEFrame:HookScript("OnHide", function()
            if addon.displayFrame then
                addon.displayFrame:Hide()
            end
        end)
    end
    return f
end

-- ==================================
-- 16. 更新显示
-- ==================================
function addon:UpdateDisplay()
    if not self.displayFrame then
        self:CreateDisplayFrame()
    end
    if not self.db then return end
    local f = self.displayFrame
    local textLines = {}
    local totalActualRuns = 0
    if not self.db.chars then
        self.db.chars = {}
    end
    local sortedChars = {}
    for charName in pairs(self.db.chars) do
        table.insert(sortedChars, charName)
    end
    table.sort(sortedChars)

    for i, charName in ipairs(sortedChars) do
        local data = self.db.chars[charName]
        if data then
            local runs = data.runs or 0
            local color = "|cff00ff00"
            if runs == 0 then
                color = "|cffff0000"
            elseif runs < 8 then
                color = "|cffffff00"
            end
            local classColor = addon:GetClassColorCode(data.class)
            local chestIcon = addon:GetChestIconByRuns(runs)
            table.insert(textLines, string.format("%s%s|r: %s%d/8|r%s", classColor, charName, color, runs, chestIcon))
            totalActualRuns = totalActualRuns + runs
        end
    end

    if #textLines == 0 then
        table.insert(textLines, "|cffaaaaaa" .. L["DATA_SAME"] .. "|r")
    end

    local finalText = table.concat(textLines, "\n")
    -- 使用本地化字符串
    local footerText = string.format("\n|cffaaaaaa----------------|r\n|cffffff00" .. L["UI_TOTAL_RUNS"] .. ": %d|r\n\n\n\n\n|cff888888" .. L["BUG_REPORT"], totalActualRuns)
    f.text:SetText(finalText .. footerText)
end

-- ==================================
-- 17. 显示窗口
-- ==================================
function addon:ShowDisplayFrame()
    if not self.displayFrame then
        self:CreateDisplayFrame()
    end
    if self.displayFrame then
        self.displayFrame:Show()
        self:UpdateDisplay()
    end
end

-- ==================================
-- 18. 事件处理
-- ==================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
local mapInfoRequested = false

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon:InitializeDB()
        addon:CreateDisplayFrame()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not mapInfoRequested then
            C_MythicPlus.RequestMapInfo()
            mapInfoRequested = true
        end
        C_Timer.After(1, function()
            addon:UpdateCurrentCharData(true)
        end)
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        addon:UpdateCurrentCharData(true)
        if addon.displayFrame and addon.displayFrame:IsShown() then
            addon:UpdateDisplay()
        end
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        C_Timer.After(5, function()
            addon:UpdateCurrentCharData(true)
            if addon.displayFrame and addon.displayFrame:IsShown() then
                addon:UpdateDisplay()
            end
        end)
    end
end)

-- ==================================
-- 19. 命令
-- ==================================
SLASH_MYTHICPLUSTRACKER1 = "/mptr"
SlashCmdList["MYTHICPLUSTRACKER"] = function(msg)
    if not addon.db then
        print("|cffff0000MythicPlusTracker: " .. L["DATA_SAME"] .. "，" .. L["BUG_REPORT"] .. "|r")
        return
    end
    if msg == "reset" then
        addon.db.chars = {}
        addon:UpdateDisplay()
        print("数据已重置")
    elseif msg == "key" or msg == "keystone" then
        addon:SendKeystoneInfoToParty()
    elseif msg == "show" then
        addon:ShowDisplayFrame()
    else
        addon:UpdateCurrentCharData(true)
        addon:PrintDebugReport()
        addon:ShowDisplayFrame()
    end
end
