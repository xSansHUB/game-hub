local Services = {}
local Modules = {}
local Remotes = {}
local State = {}
local RuntimeName = {}
local ConfigRuntime = {}
local Hub = {}
local TeamRuntime = {}
local RebirthRuntime = {}
local ZoneRuntime = {}
local SkillRuntime = {}
local IndexRuntime = {}
local RollRuntime = {}
local PotionRuntime = {}
local LootRuntime = {}
local LogRuntime = {}
local AntiAfkRuntime = {}
local SchedulerRuntime = {}
local ConnectionRuntime = {}
local UIRuntime = {}

local GLOBAL_NAME = "RollToDefendHub"
local GAME_NAME = "Roll To Defend"
local CONFIG_ROOT = "xSansHUB"
local CONFIG_FOLDER = CONFIG_ROOT .. "/RollToDefend"
local WINDUI_URL = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
local BUILD_NUMBER = 13
local LOG_LIMIT = 150
local DISPLAY_LOG_LIMIT = 40
local LOG_ROUTINE_PATTERNS = {
    "waiting",
    "cooldown",
    "no units available",
    "already equipped",
    "anti afk pulse",
    "config saved",
    "toggle enabled",
    "toggle disabled",
}

local ModuleDefinitions = {
    DataController = {"Game", "Controllers", "DataController"},
    InventoryDataUtil = {"Game", "Controllers", "InterfaceController", "SharedModules", "InventoryDataUtil"},
    InventoryGuiUtil = {"Game", "Controllers", "InterfaceController", "SharedModules", "InventoryGuiUtil"},
    InventoryItemsView = {"Game", "Controllers", "InterfaceController", "SharedModules", "InventoryItemsView"},
    Mutations = {"Game", "Tables", "Mutations"},
    RebirthData = {"Game", "Tables", "RebirthData"},
    ZoneInfo = {"Game", "Tables", "ZoneInfo"},
    ClientPolicy = {"Game", "Gamemodes", "ClientPolicy"},
    UpgradeTree = {"Game", "Tables", "UpgradeTree"},
    IndexRewards = {"Game", "Tables", "IndexRewards"},
    GameShared = {"Game", "Tables", "GameShared"},
    GameSettingsState = {"Game", "Tables", "GameSettingsState"},
    UnitTable = {"Game", "Tables", "UnitTable"},
    ItemTable = {"Game", "Tables", "ItemTable"},
    ColorData = {"Game", "Tables", "ColorData"},
    FrameController = {"Game", "Controllers", "InterfaceController", "_uipackage", "UIFeatures", "FrameController"},
    CutsceneController = {"Game", "Controllers", "InterfaceController", "RollSystem", "CutsceneController"},
    RollResultUtil = {"Game", "Controllers", "InterfaceController", "RollSystem", "RollResultUtil"},
    SpecialRollDisplay = {"Game", "Controllers", "InterfaceController", "RollSystem", "SpecialRollDisplay"},
    CoinPickupSystem = {"Game", "Controllers", "EnemyDropController", "CoinPickupSystem"},
    CoinDropState = {"Game", "Controllers", "EnemyDropController", "CoinDropState"},
}

local RemoteDefinitions = {
    EquipBest = {"InventoryRemotes", "EquipBest"},
    PurchaseUpgrade = {"UpgradeRemotes", "PurchaseUpgrade"},
    PurchaseZone = {"ZoneRemotes", "PurchaseZone"},
    ClaimIndexReward = {"ClaimIndexReward"},
    RollRequest = {"RollEvents", "RollRequest"},
    RollResult = {"RollEvents", "RollResult"},
    AutoRollState = {"RollEvents", "AutoRollState"},
    UseItem = {"ItemRemotes", "UseItem"},
    SpawnLoot = {"SpawnLoot"},
}

local BooleanSettingDefinitions = {
    {state = "autoEquipBest", control = "autoEquipBestToggle", stop = true},
    {state = "autoRebirth", control = "autoRebirthToggle", stop = true},
    {state = "autoBuyZones", control = "autoBuyZonesToggle", stop = true},
    {state = "autoUpgradeSkills", control = "autoUpgradeSkillsToggle", stop = true},
    {state = "autoClaimIndex", control = "autoClaimIndexToggle", stop = true},
    {state = "autoRoll", control = "autoRollToggle", stop = true},
    {state = "autoUsePotions", control = "autoUsePotionsToggle", stop = true},
    {state = "autoCollectLoot", control = "autoCollectLootToggle", stop = true},
    {state = "antiAfk", control = "antiAfkToggle", stop = true},
    {state = "autoSave", control = "autoSaveToggle"},
}

local ValueSettingDefinitions = {
    {state = "windowKeybind", control = "windowKeybindControl"},
    {state = "logFilter", control = "logFilterInput"},
    {state = "skillUpgradePriority", control = "skillUpgradePriorityDropdown"},
}

local MapSettingDefinitions = {
    {state = "skillUpgradeWhitelist", control = "skillUpgradeWhitelistDropdown"},
    {state = "rollLogRarityWhitelist", control = "rollLogRarityWhitelistDropdown"},
    {state = "potionWhitelist", control = "potionWhitelistDropdown"},
}

ConfigRuntime.version = BUILD_NUMBER
ConfigRuntime.saveToken = 0
ConfigRuntime.loading = false
ConfigRuntime.path = CONFIG_FOLDER .. "/" .. tostring(game.PlaceId) .. ".json"

local function formatScriptVersion(build)
    build = math.max(0, math.floor(tonumber(build) or 0))
    if build < 100 then
        return string.format("1.%d.0", build)
    end
    return string.format("1.%d.%d", math.floor(build / 100), build % 100)
end

Hub.Version = formatScriptVersion(ConfigRuntime.version)
Hub.Build = ConfigRuntime.version

local previousHub = getgenv()[GLOBAL_NAME]
if type(previousHub) == "table" and type(previousHub.Stop) == "function" then
    pcall(previousHub.Stop)
end

Services.Players = game:GetService("Players")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.HttpService = game:GetService("HttpService")
Services.RunService = game:GetService("RunService")
Services.Workspace = game:GetService("Workspace")
Services.VirtualUser = game:GetService("VirtualUser")
local virtualInputSuccess, virtualInputService = pcall(game.GetService, game, "VirtualInputManager")
Services.VirtualInputManager = virtualInputSuccess and virtualInputService or nil
Services.LocalPlayer = Services.Players.LocalPlayer

State.running = true
State.synchronizing = false
State.autoEquipBest = false
State.equipBestPollInterval = 0.75
State.equipBestCooldown = 2.1
State.equipBestNextAt = 0
State.equipBestPending = false
State.equipBestPendingSince = 0
State.equipBestPendingTimeout = 6
State.equipBestFailures = 0
State.equipBestLastStatus = "Idle"
State.equipBestLastRequestSignature = nil
State.equipBestLastConfirmedSignature = nil
State.autoRebirth = false
State.rebirthPollInterval = 0.75
State.rebirthCooldown = 1.1
State.rebirthNextAt = 0
State.rebirthPending = false
State.rebirthPendingSince = 0
State.rebirthPendingTimeout = 8
State.rebirthFailures = 0
State.rebirthLastStatus = "Idle"
State.rebirthRequestCount = nil
State.rebirthLastRequestSignature = nil
State.rebirthLastConfirmedCount = nil
State.autoBuyZones = false
State.zonePurchasePollInterval = 0.65
State.zonePurchaseCooldown = 0.8
State.zonePurchaseRetryCooldown = 2
State.zonePurchaseNextAt = 0
State.zonePurchasePending = false
State.zonePurchasePendingSince = 0
State.zonePurchasePendingTimeout = 8
State.zonePurchasePendingId = nil
State.zonePurchaseRequestToken = 0
State.zonePurchaseFailures = 0
State.zonePurchaseLastStatus = "Idle"
State.zonePurchaseLastPurchasedId = nil
State.autoUpgradeSkills = false
State.skillUpgradePriority = "Cheapest First"
State.skillUpgradeWhitelist = {}
State.skillUpgradePollInterval = 0.45
State.skillUpgradeCooldown = 0.35
State.skillUpgradeRetryCooldown = 1.5
State.skillUpgradeNextAt = 0
State.skillUpgradePending = false
State.skillUpgradePendingSince = 0
State.skillUpgradePendingTimeout = 8
State.skillUpgradePendingId = nil
State.skillUpgradeRequestLevel = nil
State.skillUpgradeRequestToken = 0
State.skillUpgradeFailures = 0
State.skillUpgradeLastStatus = "Idle"
State.skillUpgradeLastPurchasedId = nil
State.skillUpgradeSearch = ""
State.autoClaimIndex = false
State.indexClaimPollInterval = 0.5
State.indexClaimCooldown = 1.05
State.indexClaimRetryCooldown = 2
State.indexClaimNextAt = 0
State.indexClaimPending = false
State.indexClaimPendingSince = 0
State.indexClaimPendingTimeout = 8
State.indexClaimPendingCategory = nil
State.indexClaimPendingStep = nil
State.indexClaimFailures = 0
State.indexClaimLastStatus = "Idle"
State.indexClaimLastCategory = nil
State.indexClaimLastStep = nil
State.autoRoll = false
State.rollLogRarityWhitelist = {}
State.rollPollInterval = 0.1
State.rollRequestCooldown = 0.05
State.rollRetryCooldown = 1
State.rollNextAt = 0
State.rollPending = false
State.rollPendingSince = 0
State.rollPendingTimeout = 25
State.rollFailures = 0
State.rollLastStatus = "Idle"
State.rollLastResultCount = 0
State.rollTotalResults = 0
State.rollNativeAutoWasEnabled = false
State.rollRuntimeActive = false
State.rollNativeConnectionsDisabled = false
State.rollConnectionApi = nil
State.autoUsePotions = false
State.potionWhitelist = {}
State.potionPollInterval = 0.35
State.potionUseCooldown = 0.65
State.potionRetryCooldown = 2
State.potionNextAt = 0
State.potionPending = false
State.potionPendingSince = 0
State.potionPendingTimeout = 8
State.potionPendingGuid = nil
State.potionPendingId = nil
State.potionPendingCountBefore = nil
State.potionPendingRevision = 0
State.potionPendingSource = nil
State.potionFailures = 0
State.potionLastStatus = "Idle"
State.potionLastUsedId = nil
State.potionTotalUsed = 0
State.autoCollectLoot = false
State.lootCollectPollInterval = 0.1
State.lootCollectNextAt = 0
State.lootCollectCooldown = 0.08
State.lootCollectMaxCoinsPerCycle = 20
State.lootCollectMaxItemsPerCycle = 10
State.lootCollectFailures = 0
State.lootCollectLastStatus = "Idle"
State.lootCollectLastCoinCount = 0
State.lootCollectLastItemCount = 0
State.lootCollectTotalCoins = 0
State.lootCollectTotalItems = 0
State.antiAfk = false
State.antiAfkInterval = 45
State.antiAfkNextAt = 0
State.antiAfkLastStatus = "Disabled"
State.antiAfkLastErrors = {}
State.antiAfkSuccessfulMethods = {}
State.autoSave = true
State.windowKeybind = "G"
State.logFilter = ""
State.logs = {}
State.window = nil
State.logsParagraph = nil
State.autoEquipBestToggle = nil
State.autoRebirthToggle = nil
State.autoBuyZonesToggle = nil
State.autoUpgradeSkillsToggle = nil
State.skillUpgradePriorityDropdown = nil
State.skillUpgradeWhitelistDropdown = nil
State.skillUpgradeWhitelistSearchInput = nil
State.autoClaimIndexToggle = nil
State.autoRollToggle = nil
State.rollLogRarityWhitelistDropdown = nil
State.autoUsePotionsToggle = nil
State.potionWhitelistDropdown = nil
State.autoCollectLootToggle = nil
State.antiAfkToggle = nil
State.autoSaveToggle = nil
State.windowKeybindControl = nil
State.logFilterInput = nil
State.inventoryChangedConnection = nil
State.equippedChangedConnection = nil
State.upgradesChangedConnection = nil
State.rebirthCurrencyChangedConnection = nil
State.rebirthCountChangedConnection = nil
State.rebirthPolicyChangedConnection = nil
State.rebirthResultConnection = nil
State.zoneUnlockedChangedConnection = nil
State.zoneCashChangedConnection = nil
State.zoneTutorialChangedConnection = nil
State.zoneAutoRollChangedConnection = nil
State.zonePolicyChangedConnection = nil
State.skillUpgradeLevelsChangedConnection = nil
State.skillCashChangedConnection = nil
State.skillRollsChangedConnection = nil
State.skillEquippedChangedConnection = nil
State.skillTutorialChangedConnection = nil
State.skillZonesChangedConnection = nil
State.skillTempTutorialChangedConnection = nil
State.indexDataChangedConnection = nil
State.indexRewardsChangedConnection = nil
State.rollResultConnection = nil
State.itemsChangedConnection = nil
State.itemEffectsChangedConnection = nil
State.antiAfkIdledConnection = nil
State.antiAfkHeartbeatConnection = nil

ConnectionRuntime.fields = {
    "inventoryChangedConnection",
    "equippedChangedConnection",
    "upgradesChangedConnection",
    "rebirthCurrencyChangedConnection",
    "rebirthCountChangedConnection",
    "rebirthPolicyChangedConnection",
    "rebirthResultConnection",
    "zoneUnlockedChangedConnection",
    "zoneCashChangedConnection",
    "zoneTutorialChangedConnection",
    "zoneAutoRollChangedConnection",
    "zonePolicyChangedConnection",
    "skillUpgradeLevelsChangedConnection",
    "skillCashChangedConnection",
    "skillRollsChangedConnection",
    "skillEquippedChangedConnection",
    "skillTutorialChangedConnection",
    "skillZonesChangedConnection",
    "skillTempTutorialChangedConnection",
    "indexDataChangedConnection",
    "indexRewardsChangedConnection",
    "rollResultConnection",
    "itemsChangedConnection",
    "itemEffectsChangedConnection",
    "antiAfkIdledConnection",
    "antiAfkHeartbeatConnection",
}

local function resolvePath(root, path)
    local current = root
    for _, name in ipairs(path) do
        current = current:WaitForChild(name, 10)
        if not current then
            error("Missing instance path: " .. table.concat(path, "."))
        end
    end
    return current
end

local function buildModules(root, definitions)
    local result = {}
    for name, path in pairs(definitions) do
        result[name] = require(resolvePath(root, path))
    end
    return result
end

local function buildRemotes(root, definitions)
    local result = {}
    for name, path in pairs(definitions) do
        result[name] = resolvePath(root, path)
    end
    return result
end

local startupSuccess, startupError = pcall(function()
    Modules = buildModules(Services.ReplicatedStorage, ModuleDefinitions)
    if type(Modules.RebirthData.RemoteFolderName) ~= "string" or type(Modules.RebirthData.RequestRemoteName) ~= "string" then
        error("RebirthData remote names are invalid")
    end
    RemoteDefinitions.RebirthRequest = {
        Modules.RebirthData.RemoteFolderName,
        Modules.RebirthData.RequestRemoteName,
    }
    Remotes = buildRemotes(Services.ReplicatedStorage, RemoteDefinitions)
    if not Remotes.EquipBest:IsA("RemoteEvent") then
        error("InventoryRemotes.EquipBest is not a RemoteEvent")
    end
    if not Remotes.RebirthRequest:IsA("RemoteEvent") then
        error("Rebirth request remote is not a RemoteEvent")
    end
    if not Remotes.PurchaseUpgrade:IsA("RemoteFunction") then
        error("UpgradeRemotes.PurchaseUpgrade is not a RemoteFunction")
    end
    if not Remotes.PurchaseZone:IsA("RemoteFunction") then
        error("ZoneRemotes.PurchaseZone is not a RemoteFunction")
    end
    if not Remotes.ClaimIndexReward:IsA("RemoteEvent") then
        error("ClaimIndexReward is not a RemoteEvent")
    end
    if not Remotes.RollRequest:IsA("RemoteEvent") then
        error("RollEvents.RollRequest is not a RemoteEvent")
    end
    if not Remotes.RollResult:IsA("RemoteEvent") then
        error("RollEvents.RollResult is not a RemoteEvent")
    end
    if not Remotes.AutoRollState:IsA("RemoteEvent") then
        error("RollEvents.AutoRollState is not a RemoteEvent")
    end
    if not Remotes.UseItem:IsA("RemoteEvent") then
        error("ItemRemotes.UseItem is not a RemoteEvent")
    end
    if not Remotes.SpawnLoot:IsA("RemoteEvent") then
        error("SpawnLoot is not a RemoteEvent")
    end
    if type(Modules.CoinPickupSystem.Init) == "function" then
        Modules.CoinPickupSystem.Init(Remotes.SpawnLoot)
    end
end)

if not startupSuccess then
    warn("[xSansHUB] Startup failed: " .. tostring(startupError))
    return
end

function ConnectionRuntime.disconnect(field)
    local connection = State[field]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        State[field] = nil
    end
end

function ConnectionRuntime.disconnectAll()
    for _, field in ipairs(ConnectionRuntime.fields) do
        ConnectionRuntime.disconnect(field)
    end
end

function LogRuntime.normalizeMessage(message)
    return tostring(message or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
end

function LogRuntime.isRoutineMessage(message)
    local lowered = string.lower(LogRuntime.normalizeMessage(message))
    for _, pattern in ipairs(LOG_ROUTINE_PATTERNS) do
        if string.find(lowered, string.lower(pattern), 1, true) then
            return true
        end
    end
    return false
end

function LogRuntime.matchesFilter(entry)
    local filter = string.lower(LogRuntime.normalizeMessage(State.logFilter))
    if filter == "" then
        return true
    end
    return string.find(string.lower(entry.text), filter, 1, true) ~= nil
end

function LogRuntime.buildDisplayText()
    local rows = {}
    for index = #State.logs, 1, -1 do
        local entry = State.logs[index]
        if LogRuntime.matchesFilter(entry) then
            table.insert(rows, string.format("[%s] %s", entry.time, entry.text))
            if #rows >= DISPLAY_LOG_LIMIT then
                break
            end
        end
    end
    if #rows == 0 then
        return "No logs to display."
    end
    return table.concat(rows, "\n")
end

function LogRuntime.refresh()
    if State.logsParagraph then
        pcall(function()
            State.logsParagraph:SetDesc(LogRuntime.buildDisplayText())
        end)
    end
end

function LogRuntime.add(message, force)
    local text = LogRuntime.normalizeMessage(message)
    if text == "" then
        return
    end
    if not force and LogRuntime.isRoutineMessage(text) then
        return
    end
    local last = State.logs[#State.logs]
    if last and last.text == text and os.clock() - last.clock < 3 then
        return
    end
    table.insert(State.logs, {
        time = os.date("%H:%M:%S"),
        clock = os.clock(),
        text = text,
    })
    while #State.logs > LOG_LIMIT do
        table.remove(State.logs, 1)
    end
    LogRuntime.refresh()
end

function LogRuntime.clear()
    table.clear(State.logs)
    LogRuntime.refresh()
end

local function normalizeKeybind(value)
    local key = string.upper(tostring(value or "G"))
    if Enum.KeyCode[key] then
        return key
    end
    return "G"
end

function ConfigRuntime.getFileFunction(name)
    local environment = getgenv()
    local value = environment and environment[name] or nil
    if type(value) == "function" then
        return value
    end
    value = rawget(_G, name)
    if type(value) == "function" then
        return value
    end
    return nil
end

function ConfigRuntime.ensureFolder()
    local makeFolder = ConfigRuntime.getFileFunction("makefolder")
    if not makeFolder then
        return false, "makefolder is unavailable"
    end
    local isFolder = ConfigRuntime.getFileFunction("isfolder")
    local function create(path)
        if isFolder then
            local success, exists = pcall(isFolder, path)
            if success and exists then
                return true
            end
        end
        local success = pcall(makeFolder, path)
        return success
    end
    if not create(CONFIG_ROOT) then
        return false, "failed to create " .. CONFIG_ROOT
    end
    if not create(CONFIG_FOLDER) then
        return false, "failed to create " .. CONFIG_FOLDER
    end
    return true
end

function ConfigRuntime.buildSnapshot()
    local snapshot = {
        version = ConfigRuntime.version,
    }
    for _, definition in ipairs(BooleanSettingDefinitions) do
        snapshot[definition.state] = State[definition.state] == true
    end
    for _, definition in ipairs(ValueSettingDefinitions) do
        snapshot[definition.state] = State[definition.state]
    end
    for _, definition in ipairs(MapSettingDefinitions) do
        local source = State[definition.state]
        local copy = {}
        if type(source) == "table" then
            for key, enabled in pairs(source) do
                if enabled == true then
                    copy[key] = true
                end
            end
        end
        snapshot[definition.state] = copy
    end
    return snapshot
end

function ConfigRuntime.syncControls()
    State.synchronizing = true
    for _, definition in ipairs(BooleanSettingDefinitions) do
        local control = State[definition.control]
        if control then
            pcall(function()
                control:Set(State[definition.state] == true, false)
            end)
        end
    end
    if State.logFilterInput then
        pcall(function()
            State.logFilterInput:Set(State.logFilter)
        end)
    end
    if State.skillUpgradePriorityDropdown then
        pcall(function()
            State.skillUpgradePriorityDropdown:Select(State.skillUpgradePriority)
        end)
    end
    if State.skillUpgradeWhitelistSearchInput then
        pcall(function()
            State.skillUpgradeWhitelistSearchInput:Set(State.skillUpgradeSearch)
        end)
    end
    SkillRuntime.refreshWhitelistControl()
    RollRuntime.refreshRarityControl()
    PotionRuntime.refreshWhitelistControl()
    if State.window then
        pcall(function()
            State.window:SetToggleKey(Enum.KeyCode[State.windowKeybind])
        end)
    end
    State.synchronizing = false
    LogRuntime.refresh()
end

function ConfigRuntime.apply(snapshot)
    if type(snapshot) ~= "table" then
        return false, "config root is not a table"
    end
    ConfigRuntime.loading = true
    for _, definition in ipairs(BooleanSettingDefinitions) do
        if type(snapshot[definition.state]) == "boolean" then
            State[definition.state] = snapshot[definition.state]
        end
    end
    if snapshot.windowKeybind ~= nil then
        State.windowKeybind = normalizeKeybind(snapshot.windowKeybind)
    end
    if snapshot.logFilter ~= nil then
        State.logFilter = tostring(snapshot.logFilter)
    end
    State.skillUpgradePriority = SkillRuntime.normalizePriority(snapshot.skillUpgradePriority)
    table.clear(State.skillUpgradeWhitelist)
    if type(snapshot.skillUpgradeWhitelist) == "table" then
        for skillId, enabled in pairs(snapshot.skillUpgradeWhitelist) do
            if enabled == true and RuntimeName.SkillDefinitions[skillId] then
                State.skillUpgradeWhitelist[skillId] = true
            end
        end
    end
    SkillRuntime.normalizeWhitelistGroups()
    if type(snapshot.rollLogRarityWhitelist) == "table" then
        table.clear(State.rollLogRarityWhitelist)
        for rarity, enabled in pairs(snapshot.rollLogRarityWhitelist) do
            if enabled == true and RuntimeName.RollRaritySet[rarity] then
                State.rollLogRarityWhitelist[rarity] = true
            end
        end
    end
    table.clear(State.potionWhitelist)
    if type(snapshot.potionWhitelist) == "table" then
        for itemId, enabled in pairs(snapshot.potionWhitelist) do
            if enabled == true and RuntimeName.PotionIdSet[itemId] then
                State.potionWhitelist[itemId] = true
            end
        end
    end
    State.rollPending = false
    State.rollPendingSince = 0
    State.rollNextAt = 0
    State.rollLastStatus = State.autoRoll and "Ready" or "Disabled"
    State.potionPending = false
    State.potionPendingSince = 0
    State.potionPendingGuid = nil
    State.potionPendingId = nil
    State.potionPendingCountBefore = nil
    State.potionPendingRevision = 0
    State.potionPendingSource = nil
    State.potionNextAt = 0
    State.potionLastStatus = State.autoUsePotions and "Ready" or "Disabled"
    State.equipBestPending = false
    State.equipBestPendingSince = 0
    State.equipBestNextAt = 0
    State.equipBestLastRequestSignature = nil
    State.equipBestLastConfirmedSignature = nil
    State.rebirthPending = false
    State.rebirthPendingSince = 0
    State.rebirthNextAt = 0
    State.rebirthRequestCount = nil
    State.rebirthLastRequestSignature = nil
    State.rebirthLastConfirmedCount = nil
    State.zonePurchasePending = false
    State.zonePurchasePendingSince = 0
    State.zonePurchasePendingId = nil
    State.zonePurchaseRequestToken = State.zonePurchaseRequestToken + 1
    State.zonePurchaseNextAt = 0
    State.skillUpgradePending = false
    State.skillUpgradePendingSince = 0
    State.skillUpgradePendingId = nil
    State.skillUpgradeRequestLevel = nil
    State.skillUpgradeRequestToken = State.skillUpgradeRequestToken + 1
    State.skillUpgradeNextAt = 0
    State.indexClaimPending = false
    State.indexClaimPendingSince = 0
    State.indexClaimPendingCategory = nil
    State.indexClaimPendingStep = nil
    State.indexClaimNextAt = 0
    State.indexClaimLastStatus = State.autoClaimIndex and "Ready" or "Disabled"
    State.lootCollectNextAt = 0
    State.lootCollectLastStatus = State.autoCollectLoot and "Ready" or "Disabled"
    ConfigRuntime.loading = false
    return true
end

function ConfigRuntime.save()
    local writeFile = ConfigRuntime.getFileFunction("writefile")
    if not writeFile then
        return false, "writefile is unavailable"
    end
    local folderSuccess, folderError = ConfigRuntime.ensureFolder()
    if not folderSuccess then
        return false, folderError
    end
    local encodeSuccess, encoded = pcall(Services.HttpService.JSONEncode, Services.HttpService, ConfigRuntime.buildSnapshot())
    if not encodeSuccess then
        return false, encoded
    end
    local writeSuccess, writeError = pcall(writeFile, ConfigRuntime.path, encoded)
    if not writeSuccess then
        return false, writeError
    end
    return true
end

function ConfigRuntime.scheduleSave(force)
    if not force and not State.autoSave then
        return
    end
    ConfigRuntime.saveToken = ConfigRuntime.saveToken + 1
    local token = ConfigRuntime.saveToken
    task.delay(0.4, function()
        if token ~= ConfigRuntime.saveToken or not State.running then
            return
        end
        local success, errorMessage = ConfigRuntime.save()
        if not success then
            LogRuntime.add("Config save failed: " .. tostring(errorMessage), true)
        end
    end)
end

function ConfigRuntime.load()
    local readFile = ConfigRuntime.getFileFunction("readfile")
    local isFile = ConfigRuntime.getFileFunction("isfile")
    if not readFile or not isFile then
        return false, "file APIs are unavailable"
    end
    local existsSuccess, exists = pcall(isFile, ConfigRuntime.path)
    if not existsSuccess or not exists then
        return false, "missing"
    end
    local readSuccess, content = pcall(readFile, ConfigRuntime.path)
    if not readSuccess then
        return false, content
    end
    local decodeSuccess, decoded = pcall(Services.HttpService.JSONDecode, Services.HttpService, content)
    if not decodeSuccess then
        return false, decoded
    end
    local applySuccess, applyError = ConfigRuntime.apply(decoded)
    if not applySuccess then
        return false, applyError
    end
    return true
end

function TeamRuntime.getData()
    local inventory = Modules.DataController:Get("Inventory")
    local equipped = Modules.DataController:Get("EquippedUnits")
    return inventory, equipped
end

function TeamRuntime.getSlotCount()
    local value = Modules.DataController:GetUpgradeValue("maxunits", 4)
    if type(value) ~= "number" or value < 1 then
        return 4
    end
    return math.floor(value)
end

function TeamRuntime.buildTarget(inventory)
    if type(inventory) ~= "table" then
        return {}
    end
    local candidates = {}
    for guid, entry in pairs(inventory) do
        if type(guid) == "string" and type(entry) == "table" and type(entry.UnitId) == "string" then
            local unitData = Modules.InventoryDataUtil.GetUnitData(entry.UnitId)
            if unitData then
                local level = type(entry.Level) == "number" and entry.Level or 1
                local amount = Modules.InventoryDataUtil.GetInventoryUnitAmount(entry)
                local dps = Modules.InventoryDataUtil.GetEntryDps(entry)
                local odds = Modules.Mutations.GetCombinedDisplayOdds(unitData, entry.MutationId)
                table.insert(candidates, {
                    guid = guid,
                    amount = type(amount) == "number" and amount or 1,
                    level = level,
                    dps = type(dps) == "number" and dps or 0,
                    sortWeight = type(odds) == "number" and odds ~= 0 and 1 / odds or math.huge,
                })
            end
        end
    end
    table.sort(candidates, function(left, right)
        if left.dps ~= right.dps then
            return left.dps > right.dps
        end
        if left.level ~= right.level then
            return left.level > right.level
        end
        if left.sortWeight ~= right.sortWeight then
            return left.sortWeight < right.sortWeight
        end
        return left.guid < right.guid
    end)
    local target = {}
    local slotCount = TeamRuntime.getSlotCount()
    for _, candidate in ipairs(candidates) do
        if #target >= slotCount then
            break
        end
        local amount = math.min(math.max(0, math.floor(candidate.amount)), slotCount - #target)
        for _ = 1, amount do
            table.insert(target, candidate.guid)
        end
    end
    return target
end

function TeamRuntime.getCompactEquipped(inventory, equipped)
    if type(inventory) ~= "table" then
        return {}
    end
    local compact = Modules.InventoryDataUtil.GetCompactEquippedUnits(inventory, equipped)
    if type(compact) ~= "table" then
        return {}
    end
    return compact
end

function TeamRuntime.makeSignature(values)
    local parts = {}
    for index, value in ipairs(values) do
        parts[index] = tostring(value)
    end
    return table.concat(parts, "|")
end

function TeamRuntime.getStateSnapshot()
    local inventory, equipped = TeamRuntime.getData()
    local target = TeamRuntime.buildTarget(inventory)
    local current = TeamRuntime.getCompactEquipped(inventory, equipped)
    local targetSignature = TeamRuntime.makeSignature(target)
    local currentSignature = TeamRuntime.makeSignature(current)
    return {
        inventory = inventory,
        equipped = equipped,
        target = target,
        current = current,
        targetSignature = targetSignature,
        currentSignature = currentSignature,
        isBest = #target > 0 and targetSignature == currentSignature,
    }
end

function TeamRuntime.clearPending(status)
    State.equipBestPending = false
    State.equipBestPendingSince = 0
    State.equipBestLastStatus = status or State.equipBestLastStatus
end

function TeamRuntime.confirmFromState()
    local success, snapshot = pcall(TeamRuntime.getStateSnapshot)
    if not success then
        TeamRuntime.clearPending("State read failed")
        State.equipBestNextAt = os.clock() + State.equipBestCooldown
        State.equipBestFailures = State.equipBestFailures + 1
        LogRuntime.add("Equip Best state confirmation failed: " .. tostring(snapshot), true)
        return false
    end
    if snapshot.isBest then
        local wasPending = State.equipBestPending
        TeamRuntime.clearPending("Best team equipped")
        State.equipBestLastConfirmedSignature = snapshot.currentSignature
        State.equipBestLastRequestSignature = nil
        State.equipBestFailures = 0
        State.equipBestNextAt = os.clock() + State.equipBestCooldown
        if wasPending then
            LogRuntime.add("Best units equipped successfully.", true)
        end
        return true
    end
    if State.equipBestPending and snapshot.currentSignature ~= State.equipBestLastRequestSignature then
        TeamRuntime.clearPending("Equipped state changed")
        State.equipBestNextAt = os.clock() + 0.75
    end
    return false
end

function TeamRuntime.process(force)
    if not State.running or not State.autoEquipBest then
        return false
    end
    local now = os.clock()
    if not force and now < State.equipBestNextAt then
        return false
    end
    if State.equipBestPending then
        return false
    end
    local success, snapshot = pcall(TeamRuntime.getStateSnapshot)
    if not success then
        State.equipBestFailures = State.equipBestFailures + 1
        State.equipBestLastStatus = "State read failed"
        State.equipBestNextAt = now + State.equipBestCooldown
        LogRuntime.add("Equip Best state read failed: " .. tostring(snapshot), true)
        return false
    end
    if #snapshot.target == 0 then
        State.equipBestLastStatus = "No units available"
        State.equipBestNextAt = now + State.equipBestCooldown
        return false
    end
    if snapshot.isBest then
        State.equipBestLastStatus = "Best team equipped"
        State.equipBestLastConfirmedSignature = snapshot.currentSignature
        State.equipBestNextAt = now + State.equipBestCooldown
        return false
    end
    local fireSuccess, fireError = pcall(function()
        Remotes.EquipBest:FireServer()
    end)
    if not fireSuccess then
        State.equipBestFailures = State.equipBestFailures + 1
        State.equipBestLastStatus = "Request failed"
        State.equipBestNextAt = now + State.equipBestCooldown
        LogRuntime.add("Equip Best request failed: " .. tostring(fireError), true)
        return false
    end
    State.equipBestPending = true
    State.equipBestPendingSince = now
    State.equipBestLastRequestSignature = snapshot.currentSignature
    State.equipBestLastStatus = "Awaiting confirmation"
    return true
end

function TeamRuntime.tick()
    if not State.autoEquipBest then
        return
    end
    local now = os.clock()
    if State.equipBestPending then
        if now - State.equipBestPendingSince >= State.equipBestPendingTimeout then
            TeamRuntime.clearPending("Confirmation timeout")
            State.equipBestFailures = State.equipBestFailures + 1
            State.equipBestNextAt = now + State.equipBestCooldown
            LogRuntime.add("Equip Best confirmation timed out; retry queued.", true)
        end
        return
    end
    TeamRuntime.process(false)
end

function TeamRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoEquipBest = enabled
    TeamRuntime.clearPending(enabled and "Ready" or "Disabled")
    State.equipBestNextAt = 0
    State.equipBestLastRequestSignature = nil
    if enabled then
        task.defer(function()
            if State.running and State.autoEquipBest then
                TeamRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function TeamRuntime.getState()
    return {
        enabled = State.autoEquipBest,
        pending = State.equipBestPending,
        pendingSince = State.equipBestPendingSince,
        failures = State.equipBestFailures,
        lastStatus = State.equipBestLastStatus,
        nextAt = State.equipBestNextAt,
    }
end

function RebirthRuntime.getSnapshot()
    local rebirths = Modules.DataController:Get(Modules.RebirthData.RebirthsPath)
    if type(rebirths) ~= "number" then
        rebirths = 0
    end
    local currency = Modules.DataController:Get(Modules.RebirthData.CostCurrencyPath)
    if type(currency) ~= "number" then
        currency = 0
    end
    local info = Modules.RebirthData.GetNextInfo(rebirths)
    if type(info) ~= "table" or type(info.cost) ~= "number" then
        error("RebirthData.GetNextInfo returned invalid data")
    end
    local policySuccess, canRebirth = pcall(Modules.ClientPolicy.CanRebirth)
    if not policySuccess then
        error("ClientPolicy.CanRebirth failed: " .. tostring(canRebirth))
    end
    rebirths = math.max(0, math.floor(rebirths))
    local cost = math.max(0, info.cost)
    return {
        rebirths = rebirths,
        currency = currency,
        cost = cost,
        info = info,
        canRebirth = canRebirth == true,
        affordable = cost <= currency,
        signature = table.concat({
            tostring(rebirths),
            tostring(cost),
            tostring(currency),
            canRebirth == true and "1" or "0",
        }, "|"),
    }
end

function RebirthRuntime.clearPending(status)
    State.rebirthPending = false
    State.rebirthPendingSince = 0
    State.rebirthRequestCount = nil
    State.rebirthLastRequestSignature = nil
    State.rebirthLastStatus = status or State.rebirthLastStatus
end

function RebirthRuntime.confirmFromState()
    if not State.rebirthPending then
        return false
    end
    local success, snapshot = pcall(RebirthRuntime.getSnapshot)
    if not success then
        RebirthRuntime.clearPending("State read failed")
        State.rebirthFailures = State.rebirthFailures + 1
        State.rebirthNextAt = os.clock() + State.rebirthCooldown
        LogRuntime.add("Rebirth state confirmation failed: " .. tostring(snapshot), true)
        return false
    end
    if type(State.rebirthRequestCount) == "number" and snapshot.rebirths > State.rebirthRequestCount then
        RebirthRuntime.clearPending("Rebirth complete")
        State.rebirthLastConfirmedCount = snapshot.rebirths
        State.rebirthFailures = 0
        State.rebirthNextAt = os.clock() + State.rebirthCooldown
        LogRuntime.add("Rebirth completed successfully. Total rebirths: " .. tostring(snapshot.rebirths) .. ".", true)
        return true
    end
    return false
end

function RebirthRuntime.handleResult(result)
    if not State.autoRebirth or not State.rebirthPending then
        return
    end
    if type(result) == "table" and result.success == true then
        if not RebirthRuntime.confirmFromState() then
            State.rebirthLastStatus = "Server accepted request"
        end
        return
    end
    local message = nil
    if type(result) == "table" then
        if type(result.message) == "string" and result.message ~= "" then
            message = result.message
        elseif type(result.info) == "table" and type(result.info.cost) == "number" then
            message = "Requires " .. tostring(math.floor(result.info.cost)) .. " Brains"
        end
    elseif result ~= nil then
        message = tostring(result)
    end
    RebirthRuntime.clearPending("Request rejected")
    State.rebirthFailures = State.rebirthFailures + 1
    State.rebirthNextAt = os.clock() + math.max(2, State.rebirthCooldown)
    LogRuntime.add("Rebirth request rejected: " .. (message or "unknown server response") .. ".", true)
end

function RebirthRuntime.process(force)
    if not State.running or not State.autoRebirth then
        return false
    end
    local now = os.clock()
    if not force and now < State.rebirthNextAt then
        return false
    end
    if State.rebirthPending then
        return false
    end
    local success, snapshot = pcall(RebirthRuntime.getSnapshot)
    if not success then
        State.rebirthFailures = State.rebirthFailures + 1
        State.rebirthLastStatus = "State read failed"
        State.rebirthNextAt = now + math.max(2, State.rebirthCooldown)
        LogRuntime.add("Rebirth state read failed: " .. tostring(snapshot), true)
        return false
    end
    if not snapshot.canRebirth then
        State.rebirthLastStatus = "Rebirth unavailable"
        State.rebirthNextAt = now + math.max(1.5, State.rebirthCooldown)
        return false
    end
    if not snapshot.affordable then
        State.rebirthLastStatus = "Waiting for Brains"
        State.rebirthNextAt = now + math.max(0.75, State.rebirthCooldown)
        return false
    end
    local fireSuccess, fireError = pcall(function()
        Remotes.RebirthRequest:FireServer()
    end)
    if not fireSuccess then
        State.rebirthFailures = State.rebirthFailures + 1
        State.rebirthLastStatus = "Request failed"
        State.rebirthNextAt = now + math.max(2, State.rebirthCooldown)
        LogRuntime.add("Rebirth request failed: " .. tostring(fireError), true)
        return false
    end
    State.rebirthPending = true
    State.rebirthPendingSince = now
    State.rebirthRequestCount = snapshot.rebirths
    State.rebirthLastRequestSignature = snapshot.signature
    State.rebirthLastStatus = "Awaiting confirmation"
    return true
end

function RebirthRuntime.tick()
    if not State.autoRebirth then
        return
    end
    local now = os.clock()
    if State.rebirthPending then
        if RebirthRuntime.confirmFromState() then
            return
        end
        if State.rebirthPending and now - State.rebirthPendingSince >= State.rebirthPendingTimeout then
            RebirthRuntime.clearPending("Confirmation timeout")
            State.rebirthFailures = State.rebirthFailures + 1
            State.rebirthNextAt = now + math.max(2, State.rebirthCooldown)
            LogRuntime.add("Rebirth confirmation timed out; retry queued.", true)
        end
        return
    end
    RebirthRuntime.process(false)
end

function RebirthRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoRebirth = enabled
    RebirthRuntime.clearPending(enabled and "Ready" or "Disabled")
    State.rebirthNextAt = 0
    if enabled then
        task.defer(function()
            if State.running and State.autoRebirth then
                RebirthRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function RebirthRuntime.getState()
    local snapshotSuccess, snapshot = pcall(RebirthRuntime.getSnapshot)
    return {
        enabled = State.autoRebirth,
        pending = State.rebirthPending,
        pendingSince = State.rebirthPendingSince,
        failures = State.rebirthFailures,
        lastStatus = State.rebirthLastStatus,
        nextAt = State.rebirthNextAt,
        rebirths = snapshotSuccess and snapshot.rebirths or nil,
        currency = snapshotSuccess and snapshot.currency or nil,
        nextCost = snapshotSuccess and snapshot.cost or nil,
        canRebirth = snapshotSuccess and snapshot.canRebirth or false,
        affordable = snapshotSuccess and snapshot.affordable or false,
    }
end



function ZoneRuntime.isUnlocked(unlockedZones, zoneId)
    if type(zoneId) ~= "string" then
        return false
    end
    if type(unlockedZones) == "table" and unlockedZones[zoneId] == true then
        return true
    end
    return zoneId == Modules.ZoneInfo.DefaultZone
end

function ZoneRuntime.canUseZones()
    if type(Modules.ClientPolicy.CanUseZones) ~= "function" then
        return true
    end
    local success, allowed = pcall(Modules.ClientPolicy.CanUseZones)
    return success and allowed == true
end

function ZoneRuntime.isTutorialPurchaseAllowed(unlockedZones, zoneId, cash)
    if Modules.DataController:Get("Tutorial.Completed") == true then
        return true
    end
    if ZoneRuntime.isUnlocked(unlockedZones, "Zone2") or Modules.ZoneInfo.DefaultZone == "Zone2" then
        return true
    end
    if zoneId ~= "Zone2" then
        return false
    end
    local autoRoll = Modules.DataController:Get("UpgradeLevels.AutoRoll") or 0
    if type(autoRoll) ~= "number" or autoRoll <= 0 then
        return false
    end
    local price = Modules.ZoneInfo.GetPurchasePrice(zoneId)
    return type(price) == "number" and type(cash) == "number" and price <= cash
end

function ZoneRuntime.getNextZone()
    local orderedZones = Modules.ZoneInfo.GetOrderedZones()
    if type(orderedZones) ~= "table" then
        return nil, "Zone data unavailable"
    end
    local unlockedZones = Modules.DataController:Get("UnlockedZones")
    local cash = Modules.DataController:Get("Cash")
    if type(cash) ~= "number" then
        cash = 0
    end
    for index, zoneId in ipairs(orderedZones) do
        if type(zoneId) == "string" and not ZoneRuntime.isUnlocked(unlockedZones, zoneId) then
            local previousZone = orderedZones[index - 1] or zoneId
            if not ZoneRuntime.isUnlocked(unlockedZones, previousZone) then
                return nil, "Previous zone is locked"
            end
            local price = Modules.ZoneInfo.GetPurchasePrice(zoneId)
            if type(price) ~= "number" then
                return nil, "Zone price unavailable"
            end
            return {
                id = zoneId,
                price = price,
                cash = cash,
                affordable = price <= cash,
                tutorialAllowed = ZoneRuntime.isTutorialPurchaseAllowed(unlockedZones, zoneId, cash),
                policyAllowed = ZoneRuntime.canUseZones(),
            }
        end
    end
    return nil, "All zones unlocked"
end

function ZoneRuntime.clearPending(status, invalidate)
    if invalidate then
        State.zonePurchaseRequestToken = State.zonePurchaseRequestToken + 1
    end
    State.zonePurchasePending = false
    State.zonePurchasePendingSince = 0
    State.zonePurchasePendingId = nil
    State.zonePurchaseLastStatus = status or State.zonePurchaseLastStatus
end

function ZoneRuntime.confirmFromState(unlockedZones)
    if not State.zonePurchasePending or type(State.zonePurchasePendingId) ~= "string" then
        return false
    end
    unlockedZones = type(unlockedZones) == "table" and unlockedZones or Modules.DataController:Get("UnlockedZones")
    if not ZoneRuntime.isUnlocked(unlockedZones, State.zonePurchasePendingId) then
        return false
    end
    local zoneId = State.zonePurchasePendingId
    ZoneRuntime.clearPending("Zone purchased", false)
    State.zonePurchaseFailures = 0
    State.zonePurchaseLastPurchasedId = zoneId
    State.zonePurchaseNextAt = os.clock() + State.zonePurchaseCooldown
    local displayName = type(Modules.ZoneInfo.GetDisplayName) == "function" and Modules.ZoneInfo.GetDisplayName(zoneId) or zoneId
    LogRuntime.add("Zone purchased successfully: " .. tostring(displayName) .. ".", true)
    return true
end

function ZoneRuntime.handleResponse(token, zoneId, invokeSuccess, result)
    if token ~= State.zonePurchaseRequestToken or not State.running or not State.zonePurchasePending or State.zonePurchasePendingId ~= zoneId then
        return
    end
    if not invokeSuccess then
        ZoneRuntime.clearPending("Request failed", false)
        State.zonePurchaseFailures = State.zonePurchaseFailures + 1
        State.zonePurchaseNextAt = os.clock() + State.zonePurchaseRetryCooldown
        LogRuntime.add("Zone purchase request failed for " .. tostring(zoneId) .. ": " .. tostring(result), true)
        return
    end
    if type(result) == "table" and result.success == false then
        local waitingForCash = result.currency == "Cash"
        ZoneRuntime.clearPending(waitingForCash and "Waiting for cash" or "Request rejected", false)
        State.zonePurchaseNextAt = os.clock() + (waitingForCash and State.zonePurchaseCooldown or State.zonePurchaseRetryCooldown)
        if not waitingForCash then
            State.zonePurchaseFailures = State.zonePurchaseFailures + 1
            LogRuntime.add("Zone purchase rejected for " .. tostring(zoneId) .. ": " .. tostring(result.message or "unknown server response"), true)
        end
        return
    end
    if not ZoneRuntime.confirmFromState() then
        State.zonePurchaseLastStatus = "Awaiting zone confirmation"
    end
end

function ZoneRuntime.process(force)
    if not State.running or not State.autoBuyZones then
        return false
    end
    local now = os.clock()
    if not force and now < State.zonePurchaseNextAt then
        return false
    end
    if State.zonePurchasePending then
        return false
    end
    local success, candidate, reason = pcall(ZoneRuntime.getNextZone)
    if not success then
        State.zonePurchaseFailures = State.zonePurchaseFailures + 1
        State.zonePurchaseLastStatus = "Zone scan failed"
        State.zonePurchaseNextAt = now + State.zonePurchaseRetryCooldown
        LogRuntime.add("Zone scan failed: " .. tostring(candidate), true)
        return false
    end
    if not candidate then
        State.zonePurchaseLastStatus = reason or "No zone available"
        State.zonePurchaseNextAt = now + 1
        return false
    end
    if not candidate.policyAllowed then
        State.zonePurchaseLastStatus = "Zones are unavailable"
        State.zonePurchaseNextAt = now + 1
        return false
    end
    if not candidate.tutorialAllowed then
        State.zonePurchaseLastStatus = "Waiting for tutorial requirement"
        State.zonePurchaseNextAt = now + 1
        return false
    end
    if not candidate.affordable then
        State.zonePurchaseLastStatus = "Waiting for cash"
        State.zonePurchaseNextAt = now + 0.75
        return false
    end
    State.zonePurchaseRequestToken = State.zonePurchaseRequestToken + 1
    local token = State.zonePurchaseRequestToken
    State.zonePurchasePending = true
    State.zonePurchasePendingSince = now
    State.zonePurchasePendingId = candidate.id
    State.zonePurchaseLastStatus = "Awaiting confirmation"
    task.spawn(function()
        local invokeSuccess, result = pcall(function()
            return Remotes.PurchaseZone:InvokeServer(candidate.id)
        end)
        ZoneRuntime.handleResponse(token, candidate.id, invokeSuccess, result)
    end)
    return true
end

function ZoneRuntime.tick()
    if not State.autoBuyZones then
        return
    end
    local now = os.clock()
    if State.zonePurchasePending then
        if ZoneRuntime.confirmFromState() then
            return
        end
        if State.zonePurchasePending and now - State.zonePurchasePendingSince >= State.zonePurchasePendingTimeout then
            local zoneId = State.zonePurchasePendingId
            ZoneRuntime.clearPending("Confirmation timeout", true)
            State.zonePurchaseFailures = State.zonePurchaseFailures + 1
            State.zonePurchaseNextAt = now + State.zonePurchaseRetryCooldown
            LogRuntime.add("Zone purchase confirmation timed out for " .. tostring(zoneId) .. "; retry queued.", true)
        end
        return
    end
    ZoneRuntime.process(false)
end

function ZoneRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoBuyZones = enabled
    ZoneRuntime.clearPending(enabled and "Ready" or "Disabled", true)
    State.zonePurchaseNextAt = 0
    if enabled then
        task.defer(function()
            if State.running and State.autoBuyZones then
                ZoneRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function ZoneRuntime.getState()
    local candidateSuccess, candidate, reason = pcall(ZoneRuntime.getNextZone)
    return {
        enabled = State.autoBuyZones,
        pending = State.zonePurchasePending,
        pendingSince = State.zonePurchasePendingSince,
        pendingZoneId = State.zonePurchasePendingId,
        failures = State.zonePurchaseFailures,
        lastStatus = State.zonePurchaseLastStatus,
        lastPurchasedId = State.zonePurchaseLastPurchasedId,
        nextAt = State.zonePurchaseNextAt,
        nextZoneId = candidateSuccess and candidate and candidate.id or nil,
        nextPrice = candidateSuccess and candidate and candidate.price or nil,
        cash = candidateSuccess and candidate and candidate.cash or nil,
        reason = candidateSuccess and not candidate and reason or nil,
    }
end

function ZoneRuntime.connectDataListeners()
    State.zoneUnlockedChangedConnection = Modules.DataController:OnChanged("UnlockedZones", function(unlockedZones)
        if State.autoBuyZones then
            ZoneRuntime.confirmFromState(unlockedZones)
            State.zonePurchaseNextAt = math.min(State.zonePurchaseNextAt, os.clock() + State.zonePurchaseCooldown)
        end
    end)
    local function wake()
        if State.autoBuyZones then
            State.zonePurchaseNextAt = 0
        end
    end
    State.zoneCashChangedConnection = Modules.DataController:OnChanged("Cash", wake)
    State.zoneTutorialChangedConnection = Modules.DataController:OnChanged("Tutorial.Completed", wake)
    State.zoneAutoRollChangedConnection = Modules.DataController:OnChanged("UpgradeLevels.AutoRoll", wake)
    if type(Modules.ClientPolicy.OnChanged) == "function" then
        State.zonePolicyChangedConnection = Modules.ClientPolicy.OnChanged(wake)
    end
end


function SkillRuntime.normalizePriority(value)
    if value == "Most Expensive First" then
        return value
    end
    return "Cheapest First"
end

function SkillRuntime.looksLikeSkill(data)
    if type(data) ~= "table" then
        return false
    end
    return data.price ~= nil
        or data.Price ~= nil
        or data.name ~= nil
        or data.description ~= nil
        or data.requires ~= nil
        or data.opensTree ~= nil
        or data.startUnlocked ~= nil
end

function SkillRuntime.getGroupBase(skillId, data)
    local source = tostring(type(data) == "table" and data.name or skillId)
    local base = source:gsub("^%s+", ""):gsub("%s+$", "")
    base = base:gsub("%s*[%-%_:]?%s*[Ll]evel%s*[%(%[]?%d+[%]%)]?%s*$", "")
    base = base:gsub("%s*[%-%_:]?%s*[Tt]ier%s*[%(%[]?%d+[%]%)]?%s*$", "")
    base = base:gsub("%s*[%-%_:]?%s*[%(%[]?%d+[%]%)]?%s*$", "")
    local romanBase, romanTier = base:match("^(.-)%s+([IVXLCDM]+)$")
    if romanBase and romanTier and romanTier ~= "" then
        base = romanBase
    end
    base = base:gsub("^%s+", ""):gsub("%s+$", "")
    if base == "" then
        return source
    end
    return base
end

function SkillRuntime.buildRegistry()
    RuntimeName.SkillDefinitions = {}
    RuntimeName.SkillIds = {}
    RuntimeName.SkillDisplayToId = {}
    RuntimeName.SkillIdToDisplay = {}
    RuntimeName.SkillGroups = {}
    RuntimeName.SkillGroupKeys = {}
    RuntimeName.SkillGroupLabelToKey = {}
    RuntimeName.SkillIdToGroup = {}
    RuntimeName.SkillVisibleGroupKeys = {}
    local function addSkill(skillId, data, treeName)
        if type(skillId) ~= "string" or not SkillRuntime.looksLikeSkill(data) then
            return
        end
        if data.opensTree or data.startUnlocked == true or RuntimeName.SkillDefinitions[skillId] then
            return
        end
        RuntimeName.SkillDefinitions[skillId] = {
            id = skillId,
            data = data,
            tree = treeName,
        }
        table.insert(RuntimeName.SkillIds, skillId)
    end
    local skillTrees = Modules.UpgradeTree.SkillTrees
    if type(skillTrees) == "table" then
        for treeName, treeData in pairs(skillTrees) do
            if type(treeData) == "table" then
                local upgrades = treeData.upgrades or treeData.Upgrades
                if type(upgrades) == "table" then
                    for skillId, data in pairs(upgrades) do
                        addSkill(skillId, data, treeName)
                    end
                end
            end
        end
    end
    local upgrades = Modules.UpgradeTree.Upgrades
    if type(upgrades) == "table" then
        for skillId, data in pairs(upgrades) do
            addSkill(skillId, data, Modules.UpgradeTree.DefaultTree or "Main")
        end
    elseif type(skillTrees) ~= "table" then
        for skillId, data in pairs(Modules.UpgradeTree) do
            addSkill(skillId, data, Modules.UpgradeTree.DefaultTree or "Main")
        end
    end
    table.sort(RuntimeName.SkillIds, function(left, right)
        local leftData = RuntimeName.SkillDefinitions[left].data
        local rightData = RuntimeName.SkillDefinitions[right].data
        local leftName = tostring(leftData.name or left)
        local rightName = tostring(rightData.name or right)
        if leftName ~= rightName then
            return leftName < rightName
        end
        return left < right
    end)
    local baseBuckets = {}
    for _, skillId in ipairs(RuntimeName.SkillIds) do
        local definition = RuntimeName.SkillDefinitions[skillId]
        local name = tostring(definition.data.name or skillId)
        local display = name == skillId and skillId or string.format("%s [%s]", name, skillId)
        RuntimeName.SkillDisplayToId[display] = skillId
        RuntimeName.SkillIdToDisplay[skillId] = display
        local base = SkillRuntime.getGroupBase(skillId, definition.data)
        baseBuckets[base] = baseBuckets[base] or {}
        table.insert(baseBuckets[base], skillId)
    end
    for base, skillIds in pairs(baseBuckets) do
        local grouped = #skillIds > 1
        for _, skillId in ipairs(skillIds) do
            local definition = RuntimeName.SkillDefinitions[skillId]
            local name = tostring(definition.data.name or skillId)
            local label = grouped and base or RuntimeName.SkillIdToDisplay[skillId]
            local key = grouped and ("group:" .. base) or ("skill:" .. skillId)
            local group = RuntimeName.SkillGroups[key]
            if not group then
                group = {
                    key = key,
                    label = label,
                    skillIds = {},
                    searchParts = {label},
                }
                RuntimeName.SkillGroups[key] = group
                RuntimeName.SkillGroupLabelToKey[label] = key
                table.insert(RuntimeName.SkillGroupKeys, key)
            end
            table.insert(group.skillIds, skillId)
            table.insert(group.searchParts, skillId)
            table.insert(group.searchParts, name)
            table.insert(group.searchParts, tostring(definition.tree or ""))
            RuntimeName.SkillIdToGroup[skillId] = key
        end
    end
    table.sort(RuntimeName.SkillGroupKeys, function(left, right)
        local leftLabel = RuntimeName.SkillGroups[left].label
        local rightLabel = RuntimeName.SkillGroups[right].label
        if leftLabel ~= rightLabel then
            return leftLabel < rightLabel
        end
        return left < right
    end)
    RuntimeName.SkillVisibleGroupKeys = table.clone(RuntimeName.SkillGroupKeys)
end

function SkillRuntime.getLevels()
    local levels = Modules.DataController:Get("UpgradeLevels")
    if type(levels) == "table" then
        return levels
    end
    return {}
end

function SkillRuntime.getLevel(skillId, levels)
    local value = levels and levels[skillId] or 0
    if type(value) ~= "number" then
        value = tonumber(value) or 0
    end
    return math.max(0, math.floor(value))
end

function SkillRuntime.isUnlocked(skillId, levels)
    local definition = RuntimeName.SkillDefinitions[skillId]
    if definition and definition.data.startUnlocked == true then
        return true
    end
    return SkillRuntime.getLevel(skillId, levels) > 0
end

function SkillRuntime.areRequirementsUnlocked(requirements, levels)
    if requirements == nil then
        return true
    end
    if type(requirements) == "string" then
        return SkillRuntime.isUnlocked(requirements, levels)
    end
    if type(requirements) ~= "table" then
        return false
    end
    for key, value in pairs(requirements) do
        local requiredId = nil
        if type(value) == "string" then
            requiredId = value
        elseif value == true and type(key) == "string" then
            requiredId = key
        end
        if not requiredId or not SkillRuntime.isUnlocked(requiredId, levels) then
            return false
        end
    end
    return true
end

function SkillRuntime.hasTutorialBackpackComplete(levels)
    local tempSuccess, tempValue = pcall(Modules.DataController.GetTemp, Modules.DataController, "Tutorial.BackpackComplete")
    if tempSuccess and tempValue == true then
        return true
    end
    if not SkillRuntime.isUnlocked("Inventory", levels) then
        return false
    end
    local rolls = Modules.DataController:Get("Stats.Rolls") or 0
    local equipped = Modules.DataController:Get("EquippedUnits")
    return type(rolls) == "number" and rolls >= 3 and type(equipped) == "table" and #equipped >= 3
end

function SkillRuntime.isTutorialPurchaseAllowed(skillId, levels)
    if Modules.DataController:Get("Tutorial.Completed") == true or Modules.DataController:Get("UnlockedZones.Zone2") == true then
        return true
    end
    if skillId == "Inventory" then
        local rolls = Modules.DataController:Get("Stats.Rolls") or 0
        return type(rolls) == "number" and rolls >= 3
    end
    if skillId == "AutoRoll" then
        return SkillRuntime.isUnlocked("Inventory", levels) and SkillRuntime.hasTutorialBackpackComplete(levels)
    end
    return false
end

function SkillRuntime.getPrice(data)
    if Modules.GameShared.NoCurrencyPrice == true then
        return "Cash", 0
    end
    local price = data.price
    if price == nil then
        price = data.Price
    end
    if typeof(price) == "number" then
        return "Cash", math.max(0, price)
    end
    if type(price) == "table" then
        local currency = type(price.currency) == "string" and price.currency or "Cash"
        local amount = type(price.amount) == "number" and price.amount or 0
        return currency, math.max(0, amount)
    end
    return "Cash", 0
end

function SkillRuntime.getCurrencyPath(currency)
    if currency == "Cash" then
        return "Cash"
    end
    if currency == "Rolls" then
        return "Stats.Rolls"
    end
    return currency
end

function SkillRuntime.getCurrency(currency)
    local value = Modules.DataController:Get(SkillRuntime.getCurrencyPath(currency))
    if type(value) ~= "number" then
        return 0
    end
    return value
end

function SkillRuntime.canPurchase(skillId, definition, levels)
    local data = definition.data
    if type(data) ~= "table" or data.opensTree then
        return false
    end
    if SkillRuntime.isUnlocked(skillId, levels) then
        return false
    end
    if not SkillRuntime.areRequirementsUnlocked(data.requires, levels) then
        return false
    end
    if not SkillRuntime.isTutorialPurchaseAllowed(skillId, levels) then
        return false
    end
    local currency, price = SkillRuntime.getPrice(data)
    return price <= SkillRuntime.getCurrency(currency), currency, price
end

function SkillRuntime.getCandidates()
    local levels = SkillRuntime.getLevels()
    local candidates = {}
    for _, skillId in ipairs(RuntimeName.SkillIds) do
        if State.skillUpgradeWhitelist[skillId] == true then
            local definition = RuntimeName.SkillDefinitions[skillId]
            local affordable, currency, price = SkillRuntime.canPurchase(skillId, definition, levels)
            if affordable then
                table.insert(candidates, {
                    id = skillId,
                    definition = definition,
                    currency = currency,
                    price = price,
                    level = SkillRuntime.getLevel(skillId, levels),
                })
            end
        end
    end
    local expensiveFirst = State.skillUpgradePriority == "Most Expensive First"
    table.sort(candidates, function(left, right)
        if left.price ~= right.price then
            return expensiveFirst and left.price > right.price or left.price < right.price
        end
        if left.currency ~= right.currency then
            return left.currency < right.currency
        end
        return left.id < right.id
    end)
    return candidates
end

function SkillRuntime.isGroupSelected(groupKey)
    local group = RuntimeName.SkillGroups[groupKey]
    if not group then
        return false
    end
    for _, skillId in ipairs(group.skillIds) do
        if State.skillUpgradeWhitelist[skillId] ~= true then
            return false
        end
    end
    return #group.skillIds > 0
end

function SkillRuntime.normalizeWhitelistGroups()
    local selectedGroups = {}
    for skillId, enabled in pairs(State.skillUpgradeWhitelist) do
        if enabled == true then
            local groupKey = RuntimeName.SkillIdToGroup[skillId]
            if groupKey then
                selectedGroups[groupKey] = true
            end
        end
    end
    table.clear(State.skillUpgradeWhitelist)
    for groupKey in pairs(selectedGroups) do
        local group = RuntimeName.SkillGroups[groupKey]
        if group then
            for _, skillId in ipairs(group.skillIds) do
                State.skillUpgradeWhitelist[skillId] = true
            end
        end
    end
end

function SkillRuntime.getFilteredGroups(query)
    local normalized = string.lower(tostring(query or "")):gsub("^%s+", ""):gsub("%s+$", "")
    local labels = {}
    local keys = {}
    for _, groupKey in ipairs(RuntimeName.SkillGroupKeys or {}) do
        local group = RuntimeName.SkillGroups[groupKey]
        local searchable = string.lower(table.concat(group.searchParts, " "))
        if normalized == "" or string.find(searchable, normalized, 1, true) then
            table.insert(labels, group.label)
            table.insert(keys, groupKey)
        end
    end
    return labels, keys
end

function SkillRuntime.getWhitelistSelections(groupKeys)
    local selections = {}
    for _, groupKey in ipairs(groupKeys or RuntimeName.SkillGroupKeys or {}) do
        local group = RuntimeName.SkillGroups[groupKey]
        if group and SkillRuntime.isGroupSelected(groupKey) then
            table.insert(selections, group.label)
        end
    end
    return selections
end

function SkillRuntime.resolveGroupKey(candidate)
    if type(candidate) ~= "string" then
        return nil
    end
    if RuntimeName.SkillGroups[candidate] then
        return candidate
    end
    local groupKey = RuntimeName.SkillGroupLabelToKey[candidate]
    if groupKey then
        return groupKey
    end
    local skillId = RuntimeName.SkillDisplayToId[candidate] or RuntimeName.SkillDefinitions[candidate] and candidate or nil
    return skillId and RuntimeName.SkillIdToGroup[skillId] or nil
end

function SkillRuntime.applyGroupSelection(groupKeys, selected)
    for _, groupKey in ipairs(groupKeys or {}) do
        local group = RuntimeName.SkillGroups[groupKey]
        if group then
            for _, skillId in ipairs(group.skillIds) do
                State.skillUpgradeWhitelist[skillId] = selected == true or nil
            end
        end
    end
    State.skillUpgradeNextAt = 0
end

function SkillRuntime.setWhitelist(values, visibleOnly)
    local selectedGroups = {}
    if type(values) == "table" then
        for key, value in pairs(values) do
            local candidate = type(value) == "string" and value or value == true and type(key) == "string" and key or nil
            local groupKey = SkillRuntime.resolveGroupKey(candidate)
            if groupKey then
                selectedGroups[groupKey] = true
            end
        end
    end
    local scope = visibleOnly == true and RuntimeName.SkillVisibleGroupKeys or RuntimeName.SkillGroupKeys
    SkillRuntime.applyGroupSelection(scope, false)
    for groupKey in pairs(selectedGroups) do
        SkillRuntime.applyGroupSelection({groupKey}, true)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function SkillRuntime.selectAll(selected)
    SkillRuntime.applyGroupSelection(RuntimeName.SkillGroupKeys, selected == true)
    SkillRuntime.refreshWhitelistControl()
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function SkillRuntime.selectVisible(selected)
    SkillRuntime.selectAll(selected)
end

function SkillRuntime.refreshWhitelistControl()
    local labels, keys = SkillRuntime.getFilteredGroups("")
    RuntimeName.SkillVisibleGroupKeys = keys
    local control = State.skillUpgradeWhitelistDropdown
    if not control then
        return
    end
    local wasSynchronizing = State.synchronizing
    State.synchronizing = true
    pcall(function()
        control:Refresh(labels)
        control:Select(SkillRuntime.getWhitelistSelections(keys))
    end)
    State.synchronizing = wasSynchronizing
end


function SkillRuntime.setPriority(value)
    State.skillUpgradePriority = SkillRuntime.normalizePriority(value)
    State.skillUpgradeNextAt = 0
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function SkillRuntime.clearPending(status, invalidate)
    if invalidate then
        State.skillUpgradeRequestToken = State.skillUpgradeRequestToken + 1
    end
    State.skillUpgradePending = false
    State.skillUpgradePendingSince = 0
    State.skillUpgradePendingId = nil
    State.skillUpgradeRequestLevel = nil
    State.skillUpgradeLastStatus = status or State.skillUpgradeLastStatus
end

function SkillRuntime.confirmFromState(levels)
    if not State.skillUpgradePending or type(State.skillUpgradePendingId) ~= "string" then
        return false
    end
    levels = type(levels) == "table" and levels or SkillRuntime.getLevels()
    local currentLevel = SkillRuntime.getLevel(State.skillUpgradePendingId, levels)
    local requestLevel = type(State.skillUpgradeRequestLevel) == "number" and State.skillUpgradeRequestLevel or 0
    if currentLevel <= requestLevel then
        return false
    end
    local skillId = State.skillUpgradePendingId
    SkillRuntime.clearPending("Upgrade complete", false)
    State.skillUpgradeFailures = 0
    State.skillUpgradeLastPurchasedId = skillId
    State.skillUpgradeNextAt = os.clock() + State.skillUpgradeCooldown
    LogRuntime.add(string.format("Skill upgraded successfully: %s (Level %d).", RuntimeName.SkillIdToDisplay[skillId] or skillId, currentLevel), true)
    return true
end

function SkillRuntime.handleResponse(token, skillId, previousLevel, invokeSuccess, result)
    if token ~= State.skillUpgradeRequestToken or not State.running or not State.skillUpgradePending or State.skillUpgradePendingId ~= skillId then
        return
    end
    if not invokeSuccess then
        SkillRuntime.clearPending("Request failed", false)
        State.skillUpgradeFailures = State.skillUpgradeFailures + 1
        State.skillUpgradeNextAt = os.clock() + State.skillUpgradeRetryCooldown
        LogRuntime.add("Skill upgrade request failed for " .. tostring(skillId) .. ": " .. tostring(result), true)
        return
    end
    if type(result) == "table" and result.success == true then
        local responseLevel = type(result.level) == "number" and math.floor(result.level) or previousLevel + 1
        SkillRuntime.clearPending("Upgrade complete", false)
        State.skillUpgradeFailures = 0
        State.skillUpgradeLastPurchasedId = type(result.skillId) == "string" and result.skillId or skillId
        State.skillUpgradeNextAt = os.clock() + State.skillUpgradeCooldown
        LogRuntime.add(string.format("Skill upgraded successfully: %s (Level %d).", RuntimeName.SkillIdToDisplay[skillId] or skillId, responseLevel), true)
        return
    end
    local message = type(result) == "table" and result.message or nil
    local notEnough = message == "Not enough currency."
    SkillRuntime.clearPending(notEnough and "Waiting for currency" or "Request rejected", false)
    State.skillUpgradeNextAt = os.clock() + (notEnough and State.skillUpgradeCooldown or State.skillUpgradeRetryCooldown)
    if not notEnough then
        State.skillUpgradeFailures = State.skillUpgradeFailures + 1
        LogRuntime.add("Skill upgrade rejected for " .. tostring(skillId) .. ": " .. tostring(message or "unknown server response"), true)
    end
end

function SkillRuntime.process(force)
    if not State.running or not State.autoUpgradeSkills then
        return false
    end
    local now = os.clock()
    if not force and now < State.skillUpgradeNextAt then
        return false
    end
    if State.skillUpgradePending then
        return false
    end
    if next(State.skillUpgradeWhitelist) == nil then
        State.skillUpgradeLastStatus = "No skills selected"
        State.skillUpgradeNextAt = now + 1
        return false
    end
    local success, candidates = pcall(SkillRuntime.getCandidates)
    if not success then
        State.skillUpgradeFailures = State.skillUpgradeFailures + 1
        State.skillUpgradeLastStatus = "Candidate scan failed"
        State.skillUpgradeNextAt = now + State.skillUpgradeRetryCooldown
        LogRuntime.add("Skill upgrade candidate scan failed: " .. tostring(candidates), true)
        return false
    end
    local candidate = candidates[1]
    if not candidate then
        State.skillUpgradeLastStatus = "No affordable eligible skills"
        State.skillUpgradeNextAt = now + 0.75
        return false
    end
    State.skillUpgradeRequestToken = State.skillUpgradeRequestToken + 1
    local token = State.skillUpgradeRequestToken
    State.skillUpgradePending = true
    State.skillUpgradePendingSince = now
    State.skillUpgradePendingId = candidate.id
    State.skillUpgradeRequestLevel = candidate.level
    State.skillUpgradeLastStatus = "Awaiting confirmation"
    task.spawn(function()
        local invokeSuccess, result = pcall(function()
            return Remotes.PurchaseUpgrade:InvokeServer(candidate.id)
        end)
        SkillRuntime.handleResponse(token, candidate.id, candidate.level, invokeSuccess, result)
    end)
    return true
end

function SkillRuntime.tick()
    if not State.autoUpgradeSkills then
        return
    end
    local now = os.clock()
    if State.skillUpgradePending then
        if SkillRuntime.confirmFromState() then
            return
        end
        if State.skillUpgradePending and now - State.skillUpgradePendingSince >= State.skillUpgradePendingTimeout then
            local skillId = State.skillUpgradePendingId
            SkillRuntime.clearPending("Confirmation timeout", true)
            State.skillUpgradeFailures = State.skillUpgradeFailures + 1
            State.skillUpgradeNextAt = now + State.skillUpgradeRetryCooldown
            LogRuntime.add("Skill upgrade confirmation timed out for " .. tostring(skillId) .. "; retry queued.", true)
        end
        return
    end
    SkillRuntime.process(false)
end

function SkillRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoUpgradeSkills = enabled
    SkillRuntime.clearPending(enabled and "Ready" or "Disabled", true)
    State.skillUpgradeNextAt = 0
    if enabled then
        task.defer(function()
            if State.running and State.autoUpgradeSkills then
                SkillRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function SkillRuntime.getState()
    local candidatesSuccess, candidates = pcall(SkillRuntime.getCandidates)
    local selectedCount = 0
    for _, enabled in pairs(State.skillUpgradeWhitelist) do
        if enabled == true then
            selectedCount = selectedCount + 1
        end
    end
    return {
        enabled = State.autoUpgradeSkills,
        priority = State.skillUpgradePriority,
        selectedCount = selectedCount,
        pending = State.skillUpgradePending,
        pendingSince = State.skillUpgradePendingSince,
        pendingSkillId = State.skillUpgradePendingId,
        failures = State.skillUpgradeFailures,
        lastStatus = State.skillUpgradeLastStatus,
        lastPurchasedId = State.skillUpgradeLastPurchasedId,
        nextAt = State.skillUpgradeNextAt,
        eligibleCount = candidatesSuccess and #candidates or nil,
        nextCandidate = candidatesSuccess and candidates[1] and candidates[1].id or nil,
    }
end

function SkillRuntime.connectDataListeners()
    State.skillUpgradeLevelsChangedConnection = Modules.DataController:OnChanged("UpgradeLevels", function(levels)
        if State.autoUpgradeSkills then
            SkillRuntime.confirmFromState(levels)
            State.skillUpgradeNextAt = math.min(State.skillUpgradeNextAt, os.clock() + State.skillUpgradeCooldown)
        end
    end)
    local function wake()
        if State.autoUpgradeSkills then
            State.skillUpgradeNextAt = 0
        end
    end
    State.skillCashChangedConnection = Modules.DataController:OnChanged("Cash", wake)
    State.skillRollsChangedConnection = Modules.DataController:OnChanged("Stats.Rolls", wake)
    State.skillEquippedChangedConnection = Modules.DataController:OnChanged("EquippedUnits", wake)
    State.skillTutorialChangedConnection = Modules.DataController:OnChanged("Tutorial.Completed", wake)
    State.skillZonesChangedConnection = Modules.DataController:OnChanged("UnlockedZones", wake)
    if type(Modules.DataController.OnTempChanged) == "function" then
        State.skillTempTutorialChangedConnection = Modules.DataController:OnTempChanged("Tutorial.BackpackComplete", wake)
    end
end


function IndexRuntime.isStepClaimed(claimedSteps, step)
    if type(claimedSteps) ~= "table" then
        return false
    end
    return claimedSteps[step] == true or claimedSteps[tostring(step)] == true
end

function IndexRuntime.getCategories()
    local categories = {}
    for category, rewards in pairs(Modules.IndexRewards) do
        if type(category) == "string" and type(rewards) == "table" then
            table.insert(categories, category)
        end
    end
    table.sort(categories)
    return categories
end

function IndexRuntime.getUnlockedEntryCount(indexData, category)
    local success, entries = pcall(Modules.Mutations.GetUnitsForMutation, category)
    if not success or type(entries) ~= "table" then
        return 0
    end
    local count = 0
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and type(entry.unitId) == "string" then
            local unitEntry = type(indexData) == "table" and indexData[entry.unitId] or nil
            local unlockedEntry = unitEntry
            if type(entry.mutationId) == "string" then
                unlockedEntry = type(unitEntry) == "table" and type(unitEntry.Mutations) == "table" and unitEntry.Mutations[entry.mutationId] or nil
            end
            if unlockedEntry == true or type(unlockedEntry) == "table" and unlockedEntry.Unlocked == true then
                count = count + 1
            end
        end
    end
    return count
end

function IndexRuntime.getNextReward(indexData, category)
    local rewards = Modules.IndexRewards[category]
    if type(rewards) ~= "table" then
        return nil
    end
    local claimedSteps = Modules.DataController:Get("IndexRewards." .. category)
    local unlockedCount = IndexRuntime.getUnlockedEntryCount(indexData, category)
    for step, reward in ipairs(rewards) do
        if not IndexRuntime.isStepClaimed(claimedSteps, step) then
            local requirement = type(reward) == "table" and tonumber(reward.req) or nil
            return {
                category = category,
                step = step,
                requirement = requirement,
                unlockedCount = unlockedCount,
                claimable = type(requirement) == "number" and requirement <= unlockedCount,
            }
        end
    end
    return nil
end

function IndexRuntime.getCandidates()
    local indexData = Modules.DataController:Get("Index")
    local candidates = {}
    for _, category in ipairs(IndexRuntime.getCategories()) do
        local candidate = IndexRuntime.getNextReward(indexData, category)
        if candidate and candidate.claimable then
            table.insert(candidates, candidate)
        end
    end
    table.sort(candidates, function(left, right)
        if left.requirement ~= right.requirement then
            return left.requirement < right.requirement
        end
        return left.category < right.category
    end)
    return candidates
end

function IndexRuntime.clearPending(status)
    State.indexClaimPending = false
    State.indexClaimPendingSince = 0
    State.indexClaimPendingCategory = nil
    State.indexClaimPendingStep = nil
    if status then
        State.indexClaimLastStatus = status
    end
end

function IndexRuntime.confirmFromState()
    if not State.indexClaimPending or type(State.indexClaimPendingCategory) ~= "string" or type(State.indexClaimPendingStep) ~= "number" then
        return false
    end
    local category = State.indexClaimPendingCategory
    local step = State.indexClaimPendingStep
    local claimedSteps = Modules.DataController:Get("IndexRewards." .. category)
    if not IndexRuntime.isStepClaimed(claimedSteps, step) then
        return false
    end
    IndexRuntime.clearPending("Reward claimed")
    State.indexClaimLastCategory = category
    State.indexClaimLastStep = step
    State.indexClaimNextAt = os.clock() + State.indexClaimCooldown
    LogRuntime.add(("Claimed Index reward: %s step %d"):format(category, step), true)
    return true
end

function IndexRuntime.process(force)
    if not State.autoClaimIndex and not force then
        return false, "Disabled"
    end
    if State.indexClaimPending then
        return false, "Pending confirmation"
    end
    local now = os.clock()
    if not force and now < State.indexClaimNextAt then
        return false, "Cooldown"
    end
    local success, candidates = pcall(IndexRuntime.getCandidates)
    if not success then
        State.indexClaimFailures = State.indexClaimFailures + 1
        State.indexClaimLastStatus = "State read failed"
        State.indexClaimNextAt = now + State.indexClaimRetryCooldown
        LogRuntime.add("Index reward state read failed: " .. tostring(candidates), true)
        return false, candidates
    end
    local candidate = candidates[1]
    if not candidate then
        State.indexClaimLastStatus = "No claimable rewards"
        State.indexClaimNextAt = now + State.indexClaimPollInterval
        return false, "No claimable rewards"
    end
    State.indexClaimPending = true
    State.indexClaimPendingSince = now
    State.indexClaimPendingCategory = candidate.category
    State.indexClaimPendingStep = candidate.step
    State.indexClaimLastStatus = "Claiming " .. candidate.category
    local requestSuccess, requestError = pcall(function()
        Remotes.ClaimIndexReward:FireServer(candidate.category)
    end)
    if not requestSuccess then
        IndexRuntime.clearPending("Request failed")
        State.indexClaimFailures = State.indexClaimFailures + 1
        State.indexClaimNextAt = now + State.indexClaimRetryCooldown
        LogRuntime.add("Index reward request failed for " .. candidate.category .. ": " .. tostring(requestError), true)
        return false, requestError
    end
    State.indexClaimNextAt = now + State.indexClaimCooldown
    return true, candidate
end

function IndexRuntime.tick()
    if not State.autoClaimIndex then
        return
    end
    local now = os.clock()
    if State.indexClaimPending then
        if IndexRuntime.confirmFromState() then
            return
        end
        if now - State.indexClaimPendingSince >= State.indexClaimPendingTimeout then
            local category = State.indexClaimPendingCategory
            local step = State.indexClaimPendingStep
            IndexRuntime.clearPending("Confirmation timeout")
            State.indexClaimFailures = State.indexClaimFailures + 1
            State.indexClaimNextAt = now + State.indexClaimRetryCooldown
            LogRuntime.add(("Index reward confirmation timed out for %s step %s; retry queued."):format(tostring(category), tostring(step)), true)
        end
        return
    end
    IndexRuntime.process(false)
end

function IndexRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoClaimIndex = enabled
    IndexRuntime.clearPending(enabled and "Ready" or "Disabled")
    State.indexClaimNextAt = 0
    if enabled then
        task.defer(function()
            if State.running and State.autoClaimIndex then
                IndexRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function IndexRuntime.getState()
    local candidatesSuccess, candidates = pcall(IndexRuntime.getCandidates)
    local nextCandidate = candidatesSuccess and candidates[1] or nil
    return {
        enabled = State.autoClaimIndex,
        pending = State.indexClaimPending,
        pendingSince = State.indexClaimPendingSince,
        pendingCategory = State.indexClaimPendingCategory,
        pendingStep = State.indexClaimPendingStep,
        failures = State.indexClaimFailures,
        lastStatus = State.indexClaimLastStatus,
        lastCategory = State.indexClaimLastCategory,
        lastStep = State.indexClaimLastStep,
        nextAt = State.indexClaimNextAt,
        claimableCount = candidatesSuccess and #candidates or nil,
        nextCategory = nextCandidate and nextCandidate.category or nil,
        nextStep = nextCandidate and nextCandidate.step or nil,
    }
end

function IndexRuntime.connectDataListeners()
    State.indexDataChangedConnection = Modules.DataController:OnChanged("Index", function()
        if State.autoClaimIndex then
            State.indexClaimNextAt = 0
        end
    end)
    State.indexRewardsChangedConnection = Modules.DataController:OnChanged("IndexRewards", function()
        if State.autoClaimIndex and not IndexRuntime.confirmFromState() then
            State.indexClaimNextAt = 0
        end
    end)
end

function RollRuntime.registerRarity(label, selected)
    label = tostring(label or "")
    if label == "" then
        return nil
    end
    RuntimeName.RollRarityNames = RuntimeName.RollRarityNames or {}
    RuntimeName.RollRaritySet = RuntimeName.RollRaritySet or {}
    if not RuntimeName.RollRaritySet[label] then
        RuntimeName.RollRaritySet[label] = true
        table.insert(RuntimeName.RollRarityNames, label)
    end
    if selected == true then
        State.rollLogRarityWhitelist[label] = true
    end
    return label
end

function RollRuntime.buildRarityRegistry()
    RuntimeName.RollRarityNames = {}
    RuntimeName.RollRaritySet = {}
    local success, units = pcall(Modules.UnitTable.GetSortedUnits)
    if success and type(units) == "table" then
        for _, unit in ipairs(units) do
            if type(unit) == "table" then
                local infoSuccess, info = pcall(Modules.ColorData.GetRarityInfo, unit)
                local rarity = infoSuccess and type(info) == "table" and info.Rarity or unit.Rarity or unit.rarity
                if type(rarity) == "string" and rarity ~= "" then
                    RollRuntime.registerRarity(rarity, false)
                end
            end
        end
    end
    RollRuntime.registerRarity("Mutation", false)
    RollRuntime.registerRarity("Luck", false)
    RollRuntime.registerRarity("Wheel Spin", false)
    RollRuntime.registerRarity("Unknown", false)
    if next(State.rollLogRarityWhitelist) == nil then
        for _, rarity in ipairs(RuntimeName.RollRarityNames) do
            State.rollLogRarityWhitelist[rarity] = true
        end
    end
end

function RollRuntime.getSelectedRarities()
    local values = {}
    for _, rarity in ipairs(RuntimeName.RollRarityNames or {}) do
        if State.rollLogRarityWhitelist[rarity] == true then
            table.insert(values, rarity)
        end
    end
    return values
end

function RollRuntime.setRarityWhitelist(values)
    local selected = {}
    if type(values) == "string" then
        selected[values] = true
    elseif type(values) == "table" then
        for key, value in pairs(values) do
            if type(key) == "number" then
                selected[tostring(value)] = true
            elseif value == true then
                selected[tostring(key)] = true
            end
        end
    end
    table.clear(State.rollLogRarityWhitelist)
    for rarity in pairs(selected) do
        if RuntimeName.RollRaritySet[rarity] then
            State.rollLogRarityWhitelist[rarity] = true
        end
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function RollRuntime.setAllRarities(selected)
    table.clear(State.rollLogRarityWhitelist)
    if selected == true then
        for _, rarity in ipairs(RuntimeName.RollRarityNames or {}) do
            State.rollLogRarityWhitelist[rarity] = true
        end
    end
    RollRuntime.refreshRarityControl()
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function RollRuntime.refreshRarityControl(refreshValues)
    local control = State.rollLogRarityWhitelistDropdown
    if not control then
        return
    end
    local wasSynchronizing = State.synchronizing
    State.synchronizing = true
    pcall(function()
        if refreshValues == true then
            control:Refresh(RuntimeName.RollRarityNames)
        end
        control:Select(RollRuntime.getSelectedRarities())
    end)
    State.synchronizing = wasSynchronizing
end

function RollRuntime.getConnectionGetter()
    local environment = getgenv()
    for _, name in ipairs({"getconnections", "get_signal_cons", "getsignalconnections"}) do
        local getter = environment and environment[name] or rawget(_G, name)
        if type(getter) == "function" then
            return getter, name
        end
    end
    return nil, nil
end

function RollRuntime.setConnectionEnabled(connection, enabled)
    local methods = enabled and {"Enable", "enable"} or {"Disable", "disable"}
    for _, methodName in ipairs(methods) do
        local readSuccess, method = pcall(function()
            return connection[methodName]
        end)
        if readSuccess and type(method) == "function" then
            local callSuccess = pcall(method, connection)
            if callSuccess then
                return true
            end
        end
    end
    return pcall(function()
        connection.Enabled = enabled
    end)
end

function RollRuntime.captureNativeConnections()
    if RuntimeName.RollNativeConnectionsCaptured then
        return #(RuntimeName.RollNativeConnections or {})
    end
    RuntimeName.RollNativeConnectionsCaptured = true
    RuntimeName.RollNativeConnections = {}
    local getter, getterName = RollRuntime.getConnectionGetter()
    State.rollConnectionApi = getterName
    if not getter then
        return 0
    end
    local success, connections = pcall(getter, Remotes.RollResult.OnClientEvent)
    if not success or type(connections) ~= "table" then
        return 0
    end
    for _, connection in ipairs(connections) do
        table.insert(RuntimeName.RollNativeConnections, connection)
    end
    return #RuntimeName.RollNativeConnections
end

function RollRuntime.setNativeVisualConnectionsEnabled(enabled)
    local changed = 0
    for _, connection in ipairs(RuntimeName.RollNativeConnections or {}) do
        if RollRuntime.setConnectionEnabled(connection, enabled) then
            changed = changed + 1
        end
    end
    State.rollNativeConnectionsDisabled = not enabled and changed > 0
    return changed
end

function RollRuntime.setCutsceneSuppressed(suppressed)
    if not RuntimeName.RollOriginalCutscenePlay then
        RuntimeName.RollOriginalCutscenePlay = Modules.CutsceneController.Play
    end
    if suppressed then
        Modules.CutsceneController.Play = function(info)
            local skip = Modules.CutsceneController.Skip
            if type(skip) == "function" then
                pcall(skip, info)
            end
            return true
        end
        return
    end
    if RuntimeName.RollOriginalCutscenePlay then
        Modules.CutsceneController.Play = RuntimeName.RollOriginalCutscenePlay
    end
end

function RollRuntime.findNativeGuiRoots()
    local roots = {}
    local playerGui = Services.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local main = playerGui and playerGui:FindFirstChild("Main") or nil
    if not main then
        return roots
    end
    for _, instance in ipairs(main:GetDescendants()) do
        if instance:IsA("GuiObject") and instance:FindFirstChild("Maximsed") and instance:FindFirstChild("Minimised") then
            table.insert(roots, instance)
            break
        end
    end
    local bottom = main:FindFirstChild("Bottom")
    local rarityRoll = bottom and bottom:FindFirstChild("RarityRoll") or nil
    if rarityRoll and rarityRoll:IsA("GuiObject") then
        table.insert(roots, rarityRoll)
    end
    return roots
end

function RollRuntime.setNativeGuiHidden(hidden)
    RuntimeName.RollHiddenGuiStates = RuntimeName.RollHiddenGuiStates or setmetatable({}, {__mode = "k"})
    if hidden then
        for _, root in ipairs(RollRuntime.findNativeGuiRoots()) do
            if RuntimeName.RollHiddenGuiStates[root] == nil then
                RuntimeName.RollHiddenGuiStates[root] = root.Visible
            end
            root.Visible = false
        end
        return
    end
    for root, visible in pairs(RuntimeName.RollHiddenGuiStates) do
        if root.Parent then
            pcall(function()
                root.Visible = visible
            end)
        end
    end
    RuntimeName.RollHiddenGuiStates = setmetatable({}, {__mode = "k"})
end

function RollRuntime.canRequestTutorialRoll()
    if Modules.DataController:Get("Tutorial.Completed") == true
        or Modules.DataController:Get("UnlockedZones.Zone2") == true
        or Modules.DataController:GetTemp("Tutorial.BackpackComplete") == true
    then
        return true
    end
    local equipped = Modules.DataController:Get("EquippedUnits")
    local rolls = tonumber(Modules.DataController:Get("Stats.Rolls")) or 0
    if rolls < 3 then
        return rolls <= 0 or (tonumber(Modules.DataController:Get("Stats.EnemiesKilled")) or 0) > 0
    end
    local inventoryLevel = tonumber(Modules.DataController:Get("UpgradeLevels.Inventory")) or 0
    if inventoryLevel <= 0 or type(equipped) ~= "table" then
        return rolls <= 0 or (rolls < 3 and (tonumber(Modules.DataController:Get("Stats.EnemiesKilled")) or 0) > 0)
    end
    return #equipped >= 3
end

function RollRuntime.getLuckSetting()
    local success, setting = pcall(Modules.GameSettingsState.GetLuckSetting)
    if success and type(setting) == "table" then
        return setting.Enabled == true, tonumber(setting.Value) or 1
    end
    return false, 1
end

function RollRuntime.getNativeRollButton()
    local success, button = pcall(Modules.FrameController.GetButton, "RollSystem")
    if success and typeof(button) == "Instance" then
        return button
    end
    return nil
end

function RollRuntime.getPausedSpecialRollUpgrades()
    local button = RollRuntime.getNativeRollButton()
    if not button then
        return {}
    end
    local success, paused = pcall(Modules.SpecialRollDisplay.GetPausedSpecialRollUpgrades, button)
    if success and type(paused) == "table" then
        return paused
    end
    return {}
end

function RollRuntime.clearSpecialRollDisplay()
    local button = RollRuntime.getNativeRollButton()
    if not button then
        return
    end
    pcall(Modules.SpecialRollDisplay.ClearRollButtonBoostIcon, button)
    pcall(Modules.SpecialRollDisplay.SetSpecialRollBorder, button, nil, false)
end

function RollRuntime.getResultSources(payload)
    local sources = {}
    if type(payload) == "table" and type(payload.results) == "table" then
        for _, result in ipairs(payload.results) do
            table.insert(sources, result)
        end
    else
        table.insert(sources, payload)
    end
    return sources
end

function RollRuntime.getWinnerRarity(winner)
    if type(winner) ~= "table" then
        return "Unknown"
    end
    local kind = winner.kind or winner._rollItemType
    if kind == "Luck" then
        return "Luck"
    end
    if kind == "Mutation" then
        return "Mutation"
    end
    if kind == "WheelSpin" or winner.id == "WheelSpin" then
        return "Wheel Spin"
    end
    local success, info = pcall(Modules.ColorData.GetRarityInfo, winner)
    local rarity = success and type(info) == "table" and info.Rarity or winner.Rarity or winner.rarity
    if type(rarity) ~= "string" or rarity == "" then
        rarity = "Unknown"
    end
    if not RuntimeName.RollRaritySet[rarity] then
        RollRuntime.registerRarity(rarity, false)
        RollRuntime.refreshRarityControl(true)
    end
    return rarity
end

function RollRuntime.getWinnerName(winner)
    if type(winner) ~= "table" then
        return tostring(winner or "Unknown")
    end
    local kind = winner.kind or winner._rollItemType
    if kind == "Luck" then
        return "x" .. tostring(tonumber(winner.multiplier) or 2) .. " Luck"
    end
    return tostring(winner.name or winner.Name or winner.unitName or winner.unitId or winner.id or kind or "Unknown")
end

function RollRuntime.getWinnerOdds(winner)
    if type(winner) ~= "table" then
        return nil
    end
    local odds = winner.displayOdds or winner.odds
    if type(odds) ~= "number" and type(winner.chance) == "number" and winner.chance > 0 then
        odds = 1 / winner.chance
    end
    local rareInfo = winner.rareRollInfo
    if type(odds) ~= "number" and type(rareInfo) == "table" then
        odds = rareInfo.displayRarity or rareInfo.effectiveRarity
    end
    if type(odds) == "number" and odds > 0 then
        return odds
    end
    return nil
end

function RollRuntime.formatNumber(value)
    value = tonumber(value)
    if not value then
        return "?"
    end
    local absolute = math.abs(value)
    local suffixes = {
        {1e15, "Q"},
        {1e12, "T"},
        {1e9, "B"},
        {1e6, "M"},
        {1e3, "K"},
    }
    for _, entry in ipairs(suffixes) do
        if absolute >= entry[1] then
            local text = string.format("%.2f", value / entry[1]):gsub("0+$", ""):gsub("%.$", "")
            return text .. entry[2]
        end
    end
    return tostring(math.floor(value + 0.5))
end

function RollRuntime.acknowledgeRareCutscenes(payload)
    local rollEvents = Services.ReplicatedStorage:FindFirstChild("RollEvents")
    local remote = rollEvents and rollEvents:FindFirstChild("RareRollCutsceneFinished") or nil
    if not remote or not remote:IsA("RemoteEvent") then
        return
    end
    local visited = {}
    local announcements = {}
    local function visit(value)
        if type(value) ~= "table" or visited[value] then
            return
        end
        visited[value] = true
        if type(value.announcementId) == "string" then
            announcements[value.announcementId] = true
        end
        for _, child in pairs(value) do
            if type(child) == "table" then
                visit(child)
            end
        end
    end
    visit(payload)
    for announcementId in pairs(announcements) do
        pcall(remote.FireServer, remote, announcementId)
    end
end

function RollRuntime.logResults(payload)
    local resultCount = 0
    for _, source in ipairs(RollRuntime.getResultSources(payload)) do
        local success, stages = pcall(Modules.RollResultUtil.NormalizeRollStages, source)
        if success and type(stages) == "table" then
            for _, stage in ipairs(stages) do
                local winner = type(stage) == "table" and stage.winner or nil
                if winner ~= nil then
                    resultCount = resultCount + 1
                    State.rollTotalResults = State.rollTotalResults + 1
                    local rarity = RollRuntime.getWinnerRarity(winner)
                    if State.rollLogRarityWhitelist[rarity] == true then
                        local name = RollRuntime.getWinnerName(winner)
                        local odds = RollRuntime.getWinnerOdds(winner)
                        local detail = odds and (" | 1 in " .. RollRuntime.formatNumber(odds)) or ""
                        LogRuntime.add(string.format("Roll #%d: %s | %s%s", State.rollTotalResults, name, rarity, detail), true)
                    end
                end
            end
        end
    end
    State.rollLastResultCount = resultCount
    return resultCount
end

function RollRuntime.clearPending(status)
    State.rollPending = false
    State.rollPendingSince = 0
    if status then
        State.rollLastStatus = status
    end
end

function RollRuntime.handleResult(payload)
    local ownedRequest = State.rollPending or State.autoRoll
    RollRuntime.setNativeGuiHidden(State.autoRoll)
    if type(payload) == "table" and payload.status == "Cooldown" then
        if ownedRequest then
            RollRuntime.clearPending("Server cooldown")
            State.rollNextAt = os.clock() + math.max(0.05, tonumber(payload.retryAfter) or State.rollRetryCooldown) + 0.05
        end
        return
    end
    if type(payload) == "table" and payload.status == "TutorialLocked" then
        if ownedRequest then
            RollRuntime.clearPending("Tutorial locked")
            State.rollFailures = State.rollFailures + 1
            RollRuntime.setAuto(false)
            if State.autoRollToggle then
                pcall(function()
                    State.autoRollToggle:Set(false, false)
                end)
            end
            LogRuntime.add("Auto Roll stopped: complete the tutorial requirements first.", true)
        end
        return
    end
    if payload == nil or payload == false or type(payload) == "table" and payload.success == false then
        if ownedRequest then
            RollRuntime.clearPending("Roll failed")
            State.rollFailures = State.rollFailures + 1
            State.rollNextAt = os.clock() + State.rollRetryCooldown
        end
        return
    end
    local resultCount = RollRuntime.logResults(payload)
    if State.rollNativeConnectionsDisabled then
        RollRuntime.acknowledgeRareCutscenes(payload)
    end
    RollRuntime.clearSpecialRollDisplay()
    if ownedRequest then
        RollRuntime.clearPending(resultCount > 0 and ("Received " .. tostring(resultCount) .. " result stages") or "Result received")
        State.rollNextAt = os.clock() + State.rollRequestCooldown
    end
end

function RollRuntime.process(force)
    if not force and not State.autoRoll then
        return false
    end
    local now = os.clock()
    if State.rollPending then
        if now - State.rollPendingSince < State.rollPendingTimeout then
            return false
        end
        State.rollFailures = State.rollFailures + 1
        RollRuntime.clearPending("Result timeout")
        State.rollNextAt = now + State.rollRetryCooldown
    end
    if not force and now < State.rollNextAt then
        return false
    end
    if not RollRuntime.canRequestTutorialRoll() then
        State.rollLastStatus = "Waiting for tutorial requirements"
        State.rollNextAt = now + State.rollRetryCooldown
        return false
    end
    RollRuntime.setNativeGuiHidden(true)
    local luckEnabled, luckValue = RollRuntime.getLuckSetting()
    local pausedUpgrades = RollRuntime.getPausedSpecialRollUpgrades()
    State.rollPending = true
    State.rollPendingSince = now
    State.rollLastStatus = "Requesting roll"
    local success, errorMessage = pcall(Remotes.RollRequest.FireServer, Remotes.RollRequest, false, pausedUpgrades, luckEnabled, luckValue)
    RollRuntime.clearSpecialRollDisplay()
    if not success then
        State.rollFailures = State.rollFailures + 1
        RollRuntime.clearPending("Request failed")
        State.rollNextAt = now + State.rollRetryCooldown
        LogRuntime.add("Auto Roll request failed: " .. tostring(errorMessage), true)
        return false
    end
    return true
end

function RollRuntime.tick()
    if State.autoRoll then
        RollRuntime.setNativeGuiHidden(true)
        RollRuntime.process(false)
    end
end

function RollRuntime.setAuto(enabled)
    enabled = enabled == true
    if State.autoRoll == enabled and State.rollRuntimeActive == enabled then
        return
    end
    State.autoRoll = enabled
    State.rollRuntimeActive = enabled
    RollRuntime.clearPending(enabled and "Ready" or "Disabled")
    State.rollNextAt = 0
    if enabled then
        State.rollNativeAutoWasEnabled = Modules.DataController:Get("AutoRoll") == true
        if State.rollNativeAutoWasEnabled then
            pcall(Remotes.AutoRollState.FireServer, Remotes.AutoRollState, false)
        end
        local disabledCount = RollRuntime.setNativeVisualConnectionsEnabled(false)
        RollRuntime.setCutsceneSuppressed(true)
        RollRuntime.setNativeGuiHidden(true)
        if disabledCount <= 0 then
            State.rollLastStatus = "Ready with UI hiding fallback"
        end
        task.defer(function()
            if State.running and State.autoRoll then
                RollRuntime.process(true)
            end
        end)
    else
        RollRuntime.setNativeVisualConnectionsEnabled(true)
        RollRuntime.setCutsceneSuppressed(false)
        RollRuntime.setNativeGuiHidden(false)
        RollRuntime.clearSpecialRollDisplay()
        if State.rollNativeAutoWasEnabled then
            pcall(Remotes.AutoRollState.FireServer, Remotes.AutoRollState, true)
        end
        State.rollNativeAutoWasEnabled = false
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function RollRuntime.getState()
    return {
        enabled = State.autoRoll,
        pending = State.rollPending,
        pendingSince = State.rollPendingSince,
        failures = State.rollFailures,
        lastStatus = State.rollLastStatus,
        lastResultCount = State.rollLastResultCount,
        totalResults = State.rollTotalResults,
        nextAt = State.rollNextAt,
        nativeConnectionsCaptured = #(RuntimeName.RollNativeConnections or {}),
        nativeConnectionsDisabled = State.rollNativeConnectionsDisabled,
        connectionApi = State.rollConnectionApi,
        selectedRarities = RollRuntime.getSelectedRarities(),
    }
end

function RollRuntime.connectResultListener()
    RollRuntime.captureNativeConnections()
    State.rollResultConnection = Remotes.RollResult.OnClientEvent:Connect(RollRuntime.handleResult)
end


function PotionRuntime.normalizeToken(value)
    if type(value) ~= "string" then
        return ""
    end
    return string.lower(value):gsub("[^%w]", "")
end

function PotionRuntime.resolveItemId(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if RuntimeName.PotionIdSet[value] then
        return value
    end
    local byLabel = RuntimeName.PotionIdByLabel[value]
    if byLabel then
        return byLabel
    end
    local normalized = PotionRuntime.normalizeToken(value)
    local exact = RuntimeName.PotionIdByNormalized[normalized]
    if exact then
        return exact
    end
    local bestId = nil
    local bestLength = 0
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        local definition = RuntimeName.PotionDefinitions[itemId]
        if definition then
            for alias in pairs(definition.aliasSet or {}) do
                if #alias >= 6 and string.find(normalized, alias, 1, true) and #alias > bestLength then
                    bestId = itemId
                    bestLength = #alias
                end
            end
        end
    end
    return bestId
end

function PotionRuntime.extractDuration(info, depth)
    if type(info) ~= "table" or (depth or 0) > 4 then
        return nil
    end
    local fields = {
        "Duration",
        "duration",
        "EffectDuration",
        "effectDuration",
        "BoostDuration",
        "boostDuration",
        "Time",
        "time",
        "Seconds",
        "seconds",
        "Lifetime",
        "lifetime",
    }
    for _, field in ipairs(fields) do
        local value = tonumber(info[field])
        if value and value > 0 and value <= 86400 then
            return value
        end
    end
    for key, value in pairs(info) do
        if type(value) == "table" then
            local normalized = PotionRuntime.normalizeToken(tostring(key))
            if string.find(normalized, "effect", 1, true) or string.find(normalized, "boost", 1, true) or string.find(normalized, "use", 1, true) or string.find(normalized, "potion", 1, true) then
                local duration = PotionRuntime.extractDuration(value, (depth or 0) + 1)
                if duration then
                    return duration
                end
            end
        end
    end
    return nil
end

function PotionRuntime.registerDefinition(itemId, aliases, fallbackName, order)
    local infoSuccess, info = pcall(Modules.ItemTable.GetItem, itemId)
    local name = fallbackName or itemId
    if infoSuccess and type(info) == "table" then
        local configuredName = info.name or info.Name or info.displayName or info.DisplayName
        if type(configuredName) == "string" and configuredName ~= "" then
            name = configuredName
        end
    end
    local label = name
    if RuntimeName.PotionIdByLabel[label] then
        label = string.format("%s [%s]", name, itemId)
    end
    local aliasSet = {}
    local aliasList = {}
    local function addAlias(value)
        if type(value) ~= "string" or value == "" then
            return
        end
        local normalized = PotionRuntime.normalizeToken(value)
        if normalized == "" or aliasSet[normalized] then
            return
        end
        aliasSet[normalized] = true
        table.insert(aliasList, value)
    end
    addAlias(itemId)
    addAlias(name)
    addAlias(fallbackName)
    if type(aliases) == "table" then
        for _, alias in ipairs(aliases) do
            addAlias(alias)
        end
    end
    if infoSuccess and type(info) == "table" then
        for _, field in ipairs({
            "effect",
            "Effect",
            "effectKey",
            "EffectKey",
            "boost",
            "Boost",
            "boostKey",
            "BoostKey",
            "effectName",
            "EffectName",
            "itemEffect",
            "ItemEffect",
        }) do
            addAlias(info[field])
        end
    end
    local definition = {
        id = itemId,
        name = name,
        label = label,
        order = order,
        aliases = aliasList,
        aliasSet = aliasSet,
        duration = PotionRuntime.extractDuration(infoSuccess and info or nil, 0) or 300,
        info = infoSuccess and type(info) == "table" and info or nil,
    }
    RuntimeName.PotionDefinitions[itemId] = definition
    RuntimeName.PotionIdSet[itemId] = true
    RuntimeName.PotionIdByLabel[label] = itemId
    RuntimeName.PotionLabelById[itemId] = label
    RuntimeName.PotionIdByNormalized[PotionRuntime.normalizeToken(itemId)] = itemId
    RuntimeName.PotionIdByNormalized[PotionRuntime.normalizeToken(name)] = itemId
    RuntimeName.PotionIdByNormalized[PotionRuntime.normalizeToken(label)] = itemId
    for normalized in pairs(aliasSet) do
        RuntimeName.PotionDefinitionByAlias[normalized] = itemId
    end
    table.insert(RuntimeName.PotionIds, itemId)
    table.insert(RuntimeName.PotionLabels, label)
end

function PotionRuntime.buildRegistry()
    RuntimeName.PotionDefinitions = {}
    RuntimeName.PotionIdSet = {}
    RuntimeName.PotionIdByLabel = {}
    RuntimeName.PotionLabelById = {}
    RuntimeName.PotionIdByNormalized = {}
    RuntimeName.PotionDefinitionByAlias = {}
    RuntimeName.PotionIds = {}
    RuntimeName.PotionLabels = {}
    RuntimeName.PotionLocalActiveUntil = {}
    RuntimeName.PotionActiveSources = {}
    RuntimeName.PotionInventoryKeys = {}
    RuntimeName.PotionNativeCounts = {}
    RuntimeName.PotionNativeTokens = {}
    RuntimeName.PotionEntryCache = nil
    RuntimeName.PotionEntryCacheAt = 0
    RuntimeName.PotionItemsRevision = 0
    RuntimeName.PotionLastUiScanAt = 0
    RuntimeName.PotionUiScanStatus = "Idle"
    RuntimeName.PotionDiscoverySources = {}
    local definitions = {
        {"LuckBoostPotion", {"LuckPotionBoost", "LuckBoost", "LuckPotion", "Luck Boost Potion"}, "Luck Boost Potion"},
        {"LuckBoostPotionUltra", {"UltraLuckPotion", "UltraLuck", "Ultra Luck Potion", "Ultra Luck Boost"}, "Ultra Luck Boost Potion"},
        {"RollSpeedBoost", {"RollSpeedPotion", "RollSpeed", "Roll Speed Potion", "Roll Speed Boost"}, "Roll Speed Boost"},
        {"CurrencyBoost", {"CoinPotionBoost", "CoinBoost", "CurrencyPotion", "Currency Boost Potion"}, "Currency Boost"},
    }
    for order, definition in ipairs(definitions) do
        PotionRuntime.registerDefinition(definition[1], definition[2], definition[3], order)
    end
end

function PotionRuntime.getSelectedLabels()
    local labels = {}
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        if State.potionWhitelist[itemId] == true then
            table.insert(labels, RuntimeName.PotionLabelById[itemId])
        end
    end
    return labels
end

function PotionRuntime.normalizeSelection(values)
    local selected = {}
    if type(values) == "string" then
        selected[values] = true
    elseif type(values) == "table" then
        for key, value in pairs(values) do
            if type(key) == "number" then
                selected[tostring(value)] = true
            elseif value == true then
                selected[tostring(key)] = true
            end
        end
    end
    return selected
end

function PotionRuntime.setWhitelist(values)
    local selected = PotionRuntime.normalizeSelection(values)
    table.clear(State.potionWhitelist)
    for value in pairs(selected) do
        local itemId = PotionRuntime.resolveItemId(value)
        if itemId then
            State.potionWhitelist[itemId] = true
        end
    end
    State.potionNextAt = 0
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function PotionRuntime.setAll(selected)
    table.clear(State.potionWhitelist)
    if selected == true then
        for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
            State.potionWhitelist[itemId] = true
        end
    end
    State.potionNextAt = 0
    PotionRuntime.refreshWhitelistControl()
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function PotionRuntime.refreshWhitelistControl()
    local control = State.potionWhitelistDropdown
    if not control then
        return
    end
    local wasSynchronizing = State.synchronizing
    State.synchronizing = true
    pcall(function()
        control:Select(PotionRuntime.getSelectedLabels())
    end)
    State.synchronizing = wasSynchronizing
end

function PotionRuntime.getExplicitRequestToken(value)
    if type(value) ~= "table" then
        return nil
    end
    for _, field in ipairs({
        "GUID",
        "Guid",
        "guid",
        "UID",
        "Uid",
        "uid",
        "UUID",
        "Uuid",
        "uuid",
        "ItemGUID",
        "ItemGuid",
        "itemGuid",
        "ItemUID",
        "ItemUid",
        "itemUid",
        "RequestToken",
        "requestToken",
        "RequestKey",
        "requestKey",
        "Token",
        "token",
    }) do
        local token = value[field]
        if type(token) == "string" and token ~= "" then
            return token
        end
    end
    return nil
end

function PotionRuntime.getDirectItemId(value)
    if type(value) ~= "table" then
        return nil
    end
    for _, field in ipairs({
        "ItemID",
        "ItemId",
        "itemId",
        "itemID",
        "ItemType",
        "itemType",
        "ItemName",
        "itemName",
        "Type",
        "type",
        "Name",
        "name",
        "ID",
        "Id",
        "id",
        "EntryKey",
        "entryKey",
        "Key",
        "key",
        "Item",
        "item",
    }) do
        local itemId = PotionRuntime.resolveItemId(value[field])
        if itemId then
            return itemId
        end
    end
    return nil
end

function PotionRuntime.resolveItemIdDeep(value, depth, visited)
    depth = depth or 0
    if depth > 4 then
        return nil
    end
    if type(value) == "string" then
        return PotionRuntime.resolveItemId(value)
    end
    if type(value) ~= "table" then
        return nil
    end
    visited = visited or {}
    if visited[value] then
        return nil
    end
    visited[value] = true
    local direct = PotionRuntime.getDirectItemId(value)
    if direct then
        return direct
    end
    for key, child in pairs(value) do
        local fromKey = PotionRuntime.resolveItemId(type(key) == "string" and key or nil)
        if fromKey then
            return fromKey
        end
        if type(child) == "string" then
            local fromValue = PotionRuntime.resolveItemId(child)
            if fromValue then
                return fromValue
            end
        elseif type(child) == "table" then
            local nested = PotionRuntime.resolveItemIdDeep(child, depth + 1, visited)
            if nested then
                return nested
            end
        end
    end
    return nil
end

function PotionRuntime.looksLikeRequestToken(value, authoritative)
    if type(value) ~= "string" or value == "" then
        return false
    end
    if authoritative == true then
        return true
    end
    if PotionRuntime.resolveItemId(value) then
        return false
    end
    local normalized = PotionRuntime.normalizeToken(value)
    if normalized == "" then
        return false
    end
    local blocked = {
        id = true,
        item = true,
        itemid = true,
        itemtype = true,
        itemname = true,
        type = true,
        name = true,
        key = true,
        guid = true,
        uid = true,
        uuid = true,
        guids = true,
        uids = true,
        amount = true,
        count = true,
        quantity = true,
        icon = true,
        data = true,
        info = true,
        items = true,
        entries = true,
        duration = true,
        active = true,
        enabled = true,
    }
    if blocked[normalized] then
        return false
    end
    if #value >= 10 then
        return true
    end
    return #value >= 4 and (string.find(value, "-", 1, true) or string.find(value, "_", 1, true) or string.find(value, "%d")) ~= nil
end

function PotionRuntime.getUpvalueValues(callback)
    if type(callback) ~= "function" then
        return {}
    end
    local environment = getgenv()
    local candidates = {
        environment and environment.getupvalues,
        rawget(_G, "getupvalues"),
        type(debug) == "table" and debug.getupvalues or nil,
    }
    for _, getter in ipairs(candidates) do
        if type(getter) == "function" then
            local success, result = pcall(getter, callback)
            if success and type(result) == "table" then
                return result
            end
        end
    end
    local values = {}
    local getter = type(debug) == "table" and debug.getupvalue or nil
    if type(getter) == "function" then
        for index = 1, 80 do
            local success, name, value = pcall(getter, callback, index)
            if not success or name == nil then
                break
            end
            values[name] = value
        end
    end
    return values
end

function PotionRuntime.getNativeInventoryInfo(items)
    local rawKeys = {}
    local counts = {}
    local tokens = {}
    local success, result = pcall(Modules.InventoryDataUtil.GetItemEntryKeys, items)
    if not success or type(result) ~= "table" then
        RuntimeName.PotionInventoryKeys = rawKeys
        RuntimeName.PotionNativeCounts = counts
        RuntimeName.PotionNativeTokens = tokens
        return rawKeys, counts, tokens
    end
    for key, value in pairs(result) do
        local keyString = tostring(key)
        rawKeys[keyString] = value
        local itemId = PotionRuntime.resolveItemId(keyString)
        if not itemId and type(value) == "table" then
            itemId = PotionRuntime.resolveItemIdDeep(value)
        end
        if itemId then
            local amount = tonumber(value)
            if not amount and type(value) == "table" then
                amount = tonumber(value.amount or value.Amount or value.count or value.Count or value.quantity or value.Quantity)
            end
            if not amount then
                amount = 1
            end
            counts[itemId] = (counts[itemId] or 0) + math.max(0, amount)
            tokens[itemId] = tokens[itemId] or {}
            table.insert(tokens[itemId], keyString)
        end
    end
    RuntimeName.PotionInventoryKeys = rawKeys
    RuntimeName.PotionNativeCounts = counts
    RuntimeName.PotionNativeTokens = tokens
    return rawKeys, counts, tokens
end

function PotionRuntime.getSelectedEntryInfo()
    local view = Modules.InventoryItemsView
    if type(view) ~= "table" or type(view.GetSelectedEntryInfo) ~= "function" then
        return nil
    end
    local success, result = pcall(view.GetSelectedEntryInfo)
    if success and type(result) == "table" then
        return result
    end
    return nil
end

function PotionRuntime.findItemsPage()
    local player = Services.Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui") or nil
    if not playerGui or type(Modules.InventoryGuiUtil.GetItemsPage) ~= "function" then
        return nil
    end
    local candidates = {}
    local seen = {}
    local function addCandidate(instance)
        if instance and not seen[instance] then
            seen[instance] = true
            table.insert(candidates, instance)
        end
    end
    addCandidate(playerGui:FindFirstChild("Main"))
    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if descendant.Name == "Inventory" or descendant.Name == "Backpack" or descendant.Name == "InventoryFrame" then
            addCandidate(descendant)
        elseif descendant:FindFirstChild("ButtonsLeft") and descendant:FindFirstChild("Main") then
            addCandidate(descendant)
        end
        if #candidates >= 80 then
            break
        end
    end
    for _, candidate in ipairs(candidates) do
        local success, result = pcall(Modules.InventoryGuiUtil.GetItemsPage, candidate)
        if success and typeof(result) == "Instance" then
            return result
        end
    end
    return nil
end

function PotionRuntime.resolveItemIdFromInstance(instance, stopAt)
    local current = instance
    local depth = 0
    while current and depth < 6 do
        local fromName = PotionRuntime.resolveItemId(current.Name)
        if fromName then
            return fromName
        end
        local attributesSuccess, attributes = pcall(current.GetAttributes, current)
        if attributesSuccess and type(attributes) == "table" then
            for _, value in pairs(attributes) do
                local fromAttribute = PotionRuntime.resolveItemId(value)
                if fromAttribute then
                    return fromAttribute
                end
            end
        end
        if current == stopAt then
            break
        end
        current = current.Parent
        depth = depth + 1
    end
    local scanned = 0
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local fromText = PotionRuntime.resolveItemId(descendant.Text)
            if fromText then
                return fromText
            end
        end
        scanned = scanned + 1
        if scanned >= 50 then
            break
        end
    end
    return nil
end

function PotionRuntime.invokeSignal(signal, ...)
    if signal == nil then
        return false
    end
    local environment = getgenv()
    local fireSignal = environment and environment.firesignal or rawget(_G, "firesignal")
    if type(fireSignal) == "function" then
        local success = pcall(fireSignal, signal, ...)
        if success then
            return true
        end
    end
    local getter = RollRuntime.getConnectionGetter()
    if not getter then
        return false
    end
    local success, connections = pcall(getter, signal)
    if not success or type(connections) ~= "table" then
        return false
    end
    local fired = false
    for _, connection in ipairs(connections) do
        local callback = nil
        pcall(function()
            callback = connection.Function or connection.Callback
        end)
        if type(callback) == "function" and pcall(callback, ...) then
            fired = true
        end
    end
    return fired
end

function PotionRuntime.activateInventoryButton(button)
    local activated = false
    local success, signal = pcall(function()
        return button.Activated
    end)
    if success then
        activated = PotionRuntime.invokeSignal(signal) or activated
    end
    success, signal = pcall(function()
        return button.MouseButton1Click
    end)
    if success then
        activated = PotionRuntime.invokeSignal(signal) or activated
    end
    success, signal = pcall(function()
        return button.InputBegan
    end)
    if success then
        local fakeInput = {UserInputType = Enum.UserInputType.MouseButton1}
        activated = PotionRuntime.invokeSignal(signal, fakeInput) or activated
    end
    return activated
end

function PotionRuntime.getInventoryEntries(forceRefresh)
    local now = os.clock()
    if forceRefresh ~= true and type(RuntimeName.PotionEntryCache) == "table" and now - (RuntimeName.PotionEntryCacheAt or 0) < 0.5 then
        return RuntimeName.PotionEntryCache
    end
    local items = Modules.DataController:Get("Items")
    local entries = {}
    local seenEntries = {}
    local discoverySources = {}
    local _, nativeCounts, nativeTokens = PotionRuntime.getNativeInventoryInfo(items)
    local function add(token, itemId, source, authoritative, priority)
        itemId = PotionRuntime.resolveItemId(itemId)
        if not itemId or not PotionRuntime.looksLikeRequestToken(token, authoritative) then
            return
        end
        token = tostring(token)
        local signature = itemId .. "\0" .. token
        local existing = seenEntries[signature]
        if existing then
            if (priority or 50) < existing.priority then
                existing.priority = priority or 50
                existing.source = source
            end
            return
        end
        local entry = {
            token = token,
            guid = token,
            itemId = itemId,
            definition = RuntimeName.PotionDefinitions[itemId],
            source = source,
            priority = priority or 50,
        }
        seenEntries[signature] = entry
        discoverySources[source] = true
        table.insert(entries, entry)
    end
    local visited = {}
    local scannedNodes = 0
    local tokenFields = {
        guid = true,
        uid = true,
        uuid = true,
        itemguid = true,
        itemuid = true,
        requesttoken = true,
        requestkey = true,
        token = true,
        guids = true,
        uids = true,
        uuids = true,
    }
    local function scan(key, value, inheritedId, source, authoritative, depth, priority)
        if depth > 7 or scannedNodes > 1800 then
            return
        end
        scannedNodes = scannedNodes + 1
        local keyItemId = PotionRuntime.resolveItemId(type(key) == "string" and key or nil)
        if type(value) == "string" then
            local valueItemId = PotionRuntime.resolveItemId(value)
            if valueItemId and type(key) == "string" then
                add(key, valueItemId, source, false, priority)
            elseif inheritedId and (authoritative or type(key) == "number") then
                add(value, inheritedId, source, authoritative or type(key) == "number", priority)
            end
            return
        end
        if type(value) ~= "table" then
            if inheritedId and type(key) == "string" and PotionRuntime.looksLikeRequestToken(key, authoritative) then
                add(key, inheritedId, source, authoritative, priority)
            end
            return
        end
        if visited[value] then
            return
        end
        visited[value] = true
        local directItemId = PotionRuntime.getDirectItemId(value)
        local itemId = directItemId or keyItemId or inheritedId or PotionRuntime.resolveItemIdDeep(value, 0, {})
        local explicitToken = PotionRuntime.getExplicitRequestToken(value)
        if itemId and explicitToken then
            add(explicitToken, itemId, source, true, priority)
        elseif directItemId and type(key) == "string" and PotionRuntime.looksLikeRequestToken(key, false) then
            add(key, directItemId, source, false, priority)
        end
        for field, container in pairs(value) do
            local normalizedField = PotionRuntime.normalizeToken(tostring(field))
            if tokenFields[normalizedField] then
                if type(container) == "string" and itemId then
                    add(container, itemId, source .. "." .. tostring(field), true, priority)
                elseif type(container) == "table" then
                    local containerItemId = itemId or PotionRuntime.resolveItemIdDeep(container, 0, {})
                    for tokenKey, tokenValue in pairs(container) do
                        if type(tokenValue) == "string" and containerItemId then
                            add(tokenValue, containerItemId, source .. "." .. tostring(field), true, priority)
                        elseif type(tokenKey) == "string" and containerItemId and type(tokenValue) ~= "table" then
                            add(tokenKey, containerItemId, source .. "." .. tostring(field), true, priority)
                        elseif type(tokenValue) == "table" then
                            scan(tokenKey, tokenValue, containerItemId, source .. "." .. tostring(field), true, depth + 1, priority)
                        end
                    end
                end
            end
        end
        for childKey, childValue in pairs(value) do
            local normalizedKey = PotionRuntime.normalizeToken(tostring(childKey))
            if not tokenFields[normalizedKey] then
                local childAuthoritative = authoritative or (type(childKey) == "number" and itemId ~= nil)
                scan(childKey, childValue, itemId, source .. "." .. tostring(childKey), childAuthoritative, depth + 1, priority)
            end
        end
    end
    if type(items) == "table" then
        for key, value in pairs(items) do
            scan(key, value, nil, "Items." .. tostring(key), false, 0, 30)
        end
    end
    local selectedInfo = PotionRuntime.getSelectedEntryInfo()
    if selectedInfo then
        scan("Selected", selectedInfo, PotionRuntime.resolveItemIdDeep(selectedInfo, 0, {}), "InventoryItemsView.GetSelectedEntryInfo", true, 0, 5)
    end
    local view = Modules.InventoryItemsView
    if type(view) == "table" then
        local inspectedFunctions = 0
        for name, callback in pairs(view) do
            local lowered = string.lower(tostring(name))
            if type(callback) == "function" and (string.find(lowered, "selected", 1, true) or string.find(lowered, "entry", 1, true) or string.find(lowered, "item", 1, true) or lowered == "render") then
                if string.sub(lowered, 1, 3) == "get" and name ~= "GetSelectedEntryInfo" then
                    local success, result = pcall(callback)
                    if success and type(result) == "table" then
                        scan(name, result, PotionRuntime.resolveItemIdDeep(result, 0, {}), "InventoryItemsView." .. tostring(name), true, 0, 8)
                    end
                end
                for upvalueName, upvalue in pairs(PotionRuntime.getUpvalueValues(callback)) do
                    if type(upvalue) == "table" then
                        scan(upvalueName, upvalue, nil, "InventoryItemsView.Upvalue." .. tostring(name) .. "." .. tostring(upvalueName), false, 0, 12)
                    end
                end
                inspectedFunctions = inspectedFunctions + 1
                if inspectedFunctions >= 12 then
                    break
                end
            end
        end
    end
    local hasSelectedAvailable = false
    for _, entry in ipairs(entries) do
        if State.potionWhitelist[entry.itemId] == true then
            hasSelectedAvailable = true
            break
        end
    end
    if not hasSelectedAvailable and now - (RuntimeName.PotionLastUiScanAt or 0) >= 2 then
        RuntimeName.PotionLastUiScanAt = now
        local itemsPage = PotionRuntime.findItemsPage()
        if itemsPage then
            local scannedButtons = 0
            for _, descendant in ipairs(itemsPage:GetDescendants()) do
                if descendant:IsA("GuiButton") then
                    local insideDetail = descendant:FindFirstAncestor("DetailPage") ~= nil
                    local itemId = not insideDetail and PotionRuntime.resolveItemIdFromInstance(descendant, itemsPage) or nil
                    if itemId and State.potionWhitelist[itemId] == true then
                        PotionRuntime.activateInventoryButton(descendant)
                        local info = PotionRuntime.getSelectedEntryInfo()
                        if info then
                            scan(descendant.Name, info, itemId, "InventoryItemsView.UI." .. descendant:GetFullName(), true, 0, 1)
                        end
                        scannedButtons = scannedButtons + 1
                        if scannedButtons >= 24 then
                            break
                        end
                    end
                end
            end
            RuntimeName.PotionUiScanStatus = scannedButtons > 0 and ("Scanned " .. tostring(scannedButtons) .. " potion entries") or "No potion entry buttons found"
        else
            RuntimeName.PotionUiScanStatus = "Items page not found"
        end
    end
    for itemId, tokenList in pairs(nativeTokens or {}) do
        if (nativeCounts[itemId] or 0) > 0 then
            for _, token in ipairs(tokenList) do
                add(token, itemId, "InventoryDataUtil.GetItemEntryKeys", true, 90)
            end
        end
    end
    table.sort(entries, function(left, right)
        local leftDefinition = left.definition
        local rightDefinition = right.definition
        local leftOrder = leftDefinition and leftDefinition.order or math.huge
        local rightOrder = rightDefinition and rightDefinition.order or math.huge
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        return left.token < right.token
    end)
    RuntimeName.PotionDiscoverySources = discoverySources
    RuntimeName.PotionEntryCache = entries
    RuntimeName.PotionEntryCacheAt = now
    State.potionDetectedEntries = #entries
    return entries
end

function PotionRuntime.isEffectActiveValue(value)
    local valueType = type(value)
    if valueType == "boolean" then
        return value
    end
    if valueType == "number" then
        if value <= 0 then
            return false
        end
        if value > 100000000000 then
            return value / 1000 > os.time()
        end
        if value > 1000000000 then
            return value > os.time()
        end
        return true
    end
    if valueType == "string" then
        local numberValue = tonumber(value)
        if numberValue then
            return PotionRuntime.isEffectActiveValue(numberValue)
        end
        local lowered = string.lower(value)
        return lowered == "true" or lowered == "active" or lowered == "enabled"
    end
    if valueType ~= "table" then
        return false
    end
    local nowUnix = os.time()
    for _, field in ipairs({"ExpiresAt", "expiresAt", "EndTime", "endTime", "EndsAt", "endsAt", "Expiration", "expiration"}) do
        local expiresAt = tonumber(value[field])
        if expiresAt then
            if expiresAt > 100000000000 then
                return expiresAt / 1000 > nowUnix
            end
            if expiresAt > 1000000000 then
                return expiresAt > nowUnix
            end
        end
    end
    for _, field in ipairs({"Active", "active", "Enabled", "enabled", "IsActive", "isActive", "Remaining", "remaining", "TimeLeft", "timeLeft"}) do
        if value[field] ~= nil and PotionRuntime.isEffectActiveValue(value[field]) then
            return true
        end
    end
    return false
end

function PotionRuntime.findActiveAlias(value, definition, depth, path)
    if type(value) ~= "table" or depth > 5 then
        return false, nil
    end
    for key, child in pairs(value) do
        local normalizedKey = PotionRuntime.normalizeToken(tostring(key))
        if definition.aliasSet[normalizedKey] and PotionRuntime.isEffectActiveValue(child) then
            return true, path .. "." .. tostring(key)
        end
        if type(child) == "table" then
            local active, source = PotionRuntime.findActiveAlias(child, definition, depth + 1, path .. "." .. tostring(key))
            if active then
                return true, source
            end
        end
    end
    return false, nil
end

function PotionRuntime.getEffectRoots()
    local roots = {}
    for _, path in ipairs({"ItemEffects", "ActiveItemEffects", "PotionEffects", "Boosts", "Effects"}) do
        local success, value = pcall(Modules.DataController.Get, Modules.DataController, path)
        if success and value ~= nil then
            table.insert(roots, {path = path, value = value})
        end
    end
    return roots
end

function PotionRuntime.isActive(itemId)
    local localUntil = RuntimeName.PotionLocalActiveUntil and RuntimeName.PotionLocalActiveUntil[itemId] or nil
    if type(localUntil) == "number" then
        if os.clock() < localUntil then
            RuntimeName.PotionActiveSources[itemId] = "local timer"
            return true
        end
        RuntimeName.PotionLocalActiveUntil[itemId] = nil
    end
    local definition = RuntimeName.PotionDefinitions[itemId]
    if not definition then
        return false
    end
    for _, root in ipairs(PotionRuntime.getEffectRoots()) do
        local active, source = PotionRuntime.findActiveAlias(root.value, definition, 0, root.path)
        if active then
            RuntimeName.PotionActiveSources[itemId] = source
            return true
        end
    end
    RuntimeName.PotionActiveSources[itemId] = nil
    return false
end

function PotionRuntime.getAvailableCount(itemId, entries)
    local nativeCount = RuntimeName.PotionNativeCounts and RuntimeName.PotionNativeCounts[itemId] or nil
    if type(nativeCount) == "number" then
        return nativeCount
    end
    local count = 0
    for _, entry in ipairs(entries or PotionRuntime.getInventoryEntries()) do
        if entry.itemId == itemId then
            count = count + 1
        end
    end
    return count
end

function PotionRuntime.hasRequestToken(token, entries)
    if type(token) ~= "string" then
        return false
    end
    for _, entry in ipairs(entries or PotionRuntime.getInventoryEntries()) do
        if entry.token == token or entry.guid == token then
            return true
        end
    end
    return false
end

function PotionRuntime.clearPending(status)
    State.potionPending = false
    State.potionPendingSince = 0
    State.potionPendingGuid = nil
    State.potionPendingId = nil
    State.potionPendingCountBefore = nil
    State.potionPendingRevision = 0
    State.potionPendingSource = nil
    if status then
        State.potionLastStatus = status
    end
end

function PotionRuntime.confirmFromState()
    if not State.potionPending then
        return false
    end
    local itemId = State.potionPendingId
    local token = State.potionPendingGuid
    RuntimeName.PotionEntryCache = nil
    local entries = PotionRuntime.getInventoryEntries(true)
    local active = itemId and PotionRuntime.isActive(itemId) or false
    local currentCount = itemId and PotionRuntime.getAvailableCount(itemId, entries) or nil
    local countDecreased = type(State.potionPendingCountBefore) == "number" and type(currentCount) == "number" and currentCount < State.potionPendingCountBefore
    local revisionAdvanced = (RuntimeName.PotionItemsRevision or 0) > (State.potionPendingRevision or 0)
    local tokenMissing = token and not PotionRuntime.hasRequestToken(token, entries) or false
    if not active and not countDecreased and not (revisionAdvanced and tokenMissing) then
        return false
    end
    local definition = itemId and RuntimeName.PotionDefinitions[itemId] or nil
    local label = definition and definition.label or tostring(itemId or "Potion")
    if itemId and RuntimeName.PotionLocalActiveUntil then
        local duration = definition and definition.duration or 300
        RuntimeName.PotionLocalActiveUntil[itemId] = math.max(RuntimeName.PotionLocalActiveUntil[itemId] or 0, os.clock() + duration)
    end
    PotionRuntime.clearPending("Used " .. label)
    State.potionLastUsedId = itemId
    State.potionTotalUsed = State.potionTotalUsed + 1
    State.potionFailures = 0
    State.potionNextAt = os.clock() + State.potionUseCooldown
    LogRuntime.add("Potion used: " .. label, true)
    return true
end

function PotionRuntime.getCandidate()
    local selectedCount = 0
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        if State.potionWhitelist[itemId] == true then
            selectedCount = selectedCount + 1
        end
    end
    if selectedCount == 0 then
        return nil, "Potion whitelist is empty"
    end
    local entries = PotionRuntime.getInventoryEntries(true)
    local ownedSelectedCount = 0
    local activeSelectedCount = 0
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        if State.potionWhitelist[itemId] == true then
            local count = PotionRuntime.getAvailableCount(itemId, entries)
            local candidate = nil
            for _, entry in ipairs(entries) do
                if entry.itemId == itemId then
                    candidate = entry
                    break
                end
            end
            if count > 0 or candidate then
                ownedSelectedCount = ownedSelectedCount + 1
                if PotionRuntime.isActive(itemId) then
                    activeSelectedCount = activeSelectedCount + 1
                elseif candidate then
                    candidate.countBefore = count
                    return candidate, nil
                end
            end
        end
    end
    if ownedSelectedCount == 0 then
        return nil, "No whitelisted potions available"
    end
    if activeSelectedCount == ownedSelectedCount then
        return nil, "Whitelisted potion effects are active"
    end
    return nil, "Potion request token was not found"
end

function PotionRuntime.process(force)
    if not force and not State.autoUsePotions then
        return false
    end
    local now = os.clock()
    if State.potionPending then
        if PotionRuntime.confirmFromState() then
            return true
        end
        if now - State.potionPendingSince < State.potionPendingTimeout then
            return false
        end
        State.potionFailures = State.potionFailures + 1
        PotionRuntime.clearPending("Use confirmation timeout")
        State.potionNextAt = now + State.potionRetryCooldown
        return false
    end
    if not force and now < State.potionNextAt then
        return false
    end
    local candidate, reason = PotionRuntime.getCandidate()
    if not candidate then
        State.potionLastStatus = reason or "No potion available"
        State.potionNextAt = now + State.potionRetryCooldown
        return false
    end
    State.potionPending = true
    State.potionPendingSince = now
    State.potionPendingGuid = candidate.token
    State.potionPendingId = candidate.itemId
    State.potionPendingCountBefore = candidate.countBefore
    State.potionPendingRevision = RuntimeName.PotionItemsRevision or 0
    State.potionPendingSource = candidate.source
    State.potionLastStatus = "Using " .. candidate.definition.label .. " via " .. tostring(candidate.source)
    local success, errorMessage = pcall(Remotes.UseItem.FireServer, Remotes.UseItem, candidate.token)
    if not success then
        State.potionFailures = State.potionFailures + 1
        PotionRuntime.clearPending("Use request failed")
        State.potionNextAt = now + State.potionRetryCooldown
        LogRuntime.add("Potion use request failed: " .. tostring(errorMessage), true)
        return false
    end
    State.potionNextAt = now + State.potionUseCooldown
    return true
end

function PotionRuntime.tick()
    if State.autoUsePotions then
        PotionRuntime.process(false)
    end
end

function PotionRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoUsePotions = enabled
    PotionRuntime.clearPending(enabled and "Ready" or "Disabled")
    State.potionNextAt = 0
    RuntimeName.PotionEntryCache = nil
    if enabled then
        task.defer(function()
            if State.running and State.autoUsePotions then
                PotionRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function PotionRuntime.getPotions()
    local values = {}
    local entries = PotionRuntime.getInventoryEntries(true)
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        local definition = RuntimeName.PotionDefinitions[itemId]
        table.insert(values, {
            id = itemId,
            name = definition.name,
            label = definition.label,
            aliases = definition.aliases,
            duration = definition.duration,
            selected = State.potionWhitelist[itemId] == true,
            active = PotionRuntime.isActive(itemId),
            activeSource = RuntimeName.PotionActiveSources[itemId],
            available = PotionRuntime.getAvailableCount(itemId, entries),
        })
    end
    return values
end

function PotionRuntime.getState()
    local entries = PotionRuntime.getInventoryEntries(true)
    local available = {}
    local sources = {}
    local tokens = {}
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        available[itemId] = PotionRuntime.getAvailableCount(itemId, entries)
        tokens[itemId] = {}
    end
    for _, entry in ipairs(entries) do
        sources[entry.itemId] = sources[entry.itemId] or entry.source
        table.insert(tokens[entry.itemId], entry.token)
    end
    local activeSources = {}
    for _, itemId in ipairs(RuntimeName.PotionIds or {}) do
        PotionRuntime.isActive(itemId)
        activeSources[itemId] = RuntimeName.PotionActiveSources[itemId]
    end
    local discoverySources = {}
    for source in pairs(RuntimeName.PotionDiscoverySources or {}) do
        table.insert(discoverySources, source)
    end
    table.sort(discoverySources)
    return {
        enabled = State.autoUsePotions,
        pending = State.potionPending,
        pendingSince = State.potionPendingSince,
        pendingGuid = State.potionPendingGuid,
        pendingId = State.potionPendingId,
        pendingSource = State.potionPendingSource,
        pendingCountBefore = State.potionPendingCountBefore,
        failures = State.potionFailures,
        lastStatus = State.potionLastStatus,
        lastUsedId = State.potionLastUsedId,
        totalUsed = State.potionTotalUsed,
        nextAt = State.potionNextAt,
        detectedEntries = #entries,
        selected = PotionRuntime.getSelectedLabels(),
        available = available,
        entrySources = sources,
        requestTokens = tokens,
        inventoryKeys = RuntimeName.PotionInventoryKeys,
        nativeCounts = RuntimeName.PotionNativeCounts,
        nativeTokens = RuntimeName.PotionNativeTokens,
        activeSources = activeSources,
        discoverySources = discoverySources,
        uiScanStatus = RuntimeName.PotionUiScanStatus,
        itemsRevision = RuntimeName.PotionItemsRevision,
    }
end

function PotionRuntime.connectDataListeners()
    State.itemsChangedConnection = Modules.DataController:OnChanged("Items", function()
        RuntimeName.PotionItemsRevision = (RuntimeName.PotionItemsRevision or 0) + 1
        RuntimeName.PotionEntryCache = nil
        RuntimeName.PotionEntryCacheAt = 0
        if State.potionPending and PotionRuntime.confirmFromState() then
            return
        end
        if State.autoUsePotions then
            State.potionNextAt = 0
        end
    end)
    State.itemEffectsChangedConnection = Modules.DataController:OnChanged("ItemEffects", function()
        if State.potionPending and PotionRuntime.confirmFromState() then
            return
        end
        if State.autoUsePotions then
            State.potionNextAt = 0
        end
    end)
end

function AntiAfkRuntime.tryMouseMoveRelative()
    local mover = getgenv().mousemoverel or rawget(_G, "mousemoverel")
    if type(mover) ~= "function" then
        return false, "unavailable"
    end
    local success, errorMessage = pcall(function()
        mover(1, 0)
        mover(-1, 0)
    end)
    return success, success and nil or errorMessage
end

function AntiAfkRuntime.tryVirtualInputMouse()
    local service = Services.VirtualInputManager
    if not service then
        return false, "unavailable"
    end
    local success, errorMessage = pcall(function()
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
        local x = math.floor(viewport.X / 2)
        local y = math.floor(viewport.Y / 2)
        service:SendMouseMoveEvent(x + 1, y, game)
        service:SendMouseMoveEvent(x, y, game)
    end)
    return success, success and nil or errorMessage
end

function AntiAfkRuntime.tryVirtualUser()
    local service = Services.VirtualUser
    if not service then
        return false, "unavailable"
    end
    local success, errorMessage = pcall(function()
        if type(service.ClickButton2) == "function" then
            service:ClickButton2(Vector2.new(0, 0))
        else
            service:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
            task.wait()
            service:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
        end
    end)
    return success, success and nil or errorMessage
end

function AntiAfkRuntime.tryVirtualInputKey()
    local service = Services.VirtualInputManager
    if not service then
        return false, "unavailable"
    end
    local success, errorMessage = pcall(function()
        service:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
        service:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
    end)
    return success, success and nil or errorMessage
end

function AntiAfkRuntime.pulse()
    if not State.antiAfk then
        return
    end
    local methods = {
        {"MouseRel", AntiAfkRuntime.tryMouseMoveRelative},
        {"VIM Mouse", AntiAfkRuntime.tryVirtualInputMouse},
        {"VirtualUser", AntiAfkRuntime.tryVirtualUser},
        {"VIM Key", AntiAfkRuntime.tryVirtualInputKey},
    }
    local successfulMethods = {}
    local errors = {}
    for _, method in ipairs(methods) do
        local name = method[1]
        local success, errorMessage = method[2]()
        if success then
            table.insert(successfulMethods, name)
        elseif errorMessage then
            table.insert(errors, name .. ": " .. tostring(errorMessage))
        end
    end
    State.antiAfkSuccessfulMethods = successfulMethods
    State.antiAfkLastErrors = errors
    State.antiAfkLastStatus = #successfulMethods > 0 and table.concat(successfulMethods, " + ") or "No method succeeded"
    State.antiAfkNextAt = os.clock() + State.antiAfkInterval
end

function AntiAfkRuntime.disconnect()
    ConnectionRuntime.disconnect("antiAfkIdledConnection")
    ConnectionRuntime.disconnect("antiAfkHeartbeatConnection")
end

function AntiAfkRuntime.setEnabled(enabled)
    enabled = enabled == true
    State.antiAfk = enabled
    AntiAfkRuntime.disconnect()
    if enabled and State.running then
        State.antiAfkNextAt = 0
        State.antiAfkIdledConnection = Services.LocalPlayer.Idled:Connect(function()
            AntiAfkRuntime.pulse()
        end)
        State.antiAfkHeartbeatConnection = Services.RunService.Heartbeat:Connect(function()
            if State.antiAfk and os.clock() >= State.antiAfkNextAt then
                AntiAfkRuntime.pulse()
            end
        end)
        task.defer(AntiAfkRuntime.pulse)
    else
        State.antiAfkLastStatus = "Disabled"
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function LootRuntime.getHumanoidRootPart()
    local character = Services.LocalPlayer.Character
    if not character then
        return nil
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart:IsA("BasePart") then
        return rootPart
    end
    return nil
end

function LootRuntime.scheduleCoins(limit)
    local coinFolder = Modules.CoinDropState.CoinFolder
    if not coinFolder or not coinFolder.Parent then
        return 0
    end
    local scheduledCoins = Modules.CoinDropState.PickupScheduledCoins
    local pickingUpCoins = Modules.CoinDropState.PickingUpCoins
    local pendingPickups = Modules.CoinDropState.PendingPickups
    local scheduled = 0
    for _, coin in ipairs(coinFolder:GetChildren()) do
        if scheduled >= limit then
            break
        end
        local alreadyHandled = type(scheduledCoins) == "table" and scheduledCoins[coin]
            or type(pickingUpCoins) == "table" and pickingUpCoins[coin]
            or type(pendingPickups) == "table" and pendingPickups[coin]
        if coin:IsA("BasePart") and coin.Parent and not alreadyHandled then
            local success = pcall(Modules.CoinPickupSystem.Schedule, coin, 0)
            if success then
                scheduled = scheduled + 1
            else
                State.lootCollectFailures = State.lootCollectFailures + 1
            end
        end
    end
    return scheduled
end

function LootRuntime.collectItems(rootPart, limit)
    local collected = 0
    local now = os.clock()
    RuntimeName.LootItemAttempts = RuntimeName.LootItemAttempts or setmetatable({}, {__mode = "k"})
    for _, item in ipairs(Services.Workspace:GetChildren()) do
        if collected >= limit then
            break
        end
        if item:IsA("BasePart") and item.Name == "Item" and type(item:GetAttribute("GUID")) == "string" and type(item:GetAttribute("ItemID")) == "string" then
            local lastAttempt = RuntimeName.LootItemAttempts[item] or 0
            if now - lastAttempt >= 3 then
                RuntimeName.LootItemAttempts[item] = now
                local success = pcall(function()
                    item.Position = rootPart.Position + Vector3.new(0, 1.5, 0)
                end)
                if success then
                    collected = collected + 1
                else
                    State.lootCollectFailures = State.lootCollectFailures + 1
                end
            end
        end
    end
    return collected
end

function LootRuntime.process(force)
    if not force and not State.autoCollectLoot then
        return false
    end
    local now = os.clock()
    if not force and now < State.lootCollectNextAt then
        return false
    end
    State.lootCollectNextAt = now + State.lootCollectCooldown
    local rootPart = LootRuntime.getHumanoidRootPart()
    if not rootPart then
        State.lootCollectLastStatus = "Character unavailable"
        return false
    end
    local coinCount = LootRuntime.scheduleCoins(State.lootCollectMaxCoinsPerCycle)
    local itemCount = LootRuntime.collectItems(rootPart, State.lootCollectMaxItemsPerCycle)
    State.lootCollectLastCoinCount = coinCount
    State.lootCollectLastItemCount = itemCount
    State.lootCollectTotalCoins = State.lootCollectTotalCoins + coinCount
    State.lootCollectTotalItems = State.lootCollectTotalItems + itemCount
    if coinCount > 0 or itemCount > 0 then
        State.lootCollectLastStatus = string.format("Queued %d coins and %d items", coinCount, itemCount)
        return true
    end
    State.lootCollectLastStatus = "No drops available"
    return false
end

function LootRuntime.tick()
    if State.autoCollectLoot then
        LootRuntime.process(false)
    end
end

function LootRuntime.setAuto(enabled)
    enabled = enabled == true
    State.autoCollectLoot = enabled
    State.lootCollectNextAt = 0
    State.lootCollectLastStatus = enabled and "Ready" or "Disabled"
    if not enabled then
        RuntimeName.LootItemAttempts = setmetatable({}, {__mode = "k"})
    else
        task.defer(function()
            if State.running and State.autoCollectLoot then
                LootRuntime.process(true)
            end
        end)
    end
    if not State.synchronizing and not ConfigRuntime.loading then
        ConfigRuntime.scheduleSave(false)
    end
end

function LootRuntime.getState()
    return {
        enabled = State.autoCollectLoot,
        lastStatus = State.lootCollectLastStatus,
        lastCoins = State.lootCollectLastCoinCount,
        lastItems = State.lootCollectLastItemCount,
        totalCoinsQueued = State.lootCollectTotalCoins,
        totalItemsMoved = State.lootCollectTotalItems,
        failures = State.lootCollectFailures,
        nextAt = State.lootCollectNextAt,
    }
end

function AntiAfkRuntime.getState()
    return {
        enabled = State.antiAfk,
        lastStatus = State.antiAfkLastStatus,
        successfulMethods = table.clone(State.antiAfkSuccessfulMethods),
        errors = table.clone(State.antiAfkLastErrors),
        heartbeatConnected = State.antiAfkHeartbeatConnection ~= nil,
        idledConnected = State.antiAfkIdledConnection ~= nil,
        virtualUserAvailable = Services.VirtualUser ~= nil,
        virtualInputManagerAvailable = Services.VirtualInputManager ~= nil,
    }
end

function SchedulerRuntime.spawn(interval, callback)
    task.spawn(function()
        while State.running do
            local success, errorMessage = pcall(callback)
            if not success then
                LogRuntime.add("Scheduler failure: " .. tostring(errorMessage), true)
            end
            local delayValue = type(interval) == "function" and interval() or interval
            task.wait(math.max(0.05, tonumber(delayValue) or 1))
        end
    end)
end

function SchedulerRuntime.start(definitions)
    for _, definition in ipairs(definitions) do
        SchedulerRuntime.spawn(definition.interval, definition.callback)
    end
end

function UIRuntime.createTab(window, title, icon)
    return window:Tab({
        Title = title,
        Icon = icon,
        Locked = false,
    })
end

function UIRuntime.createSection(parent, title, opened)
    return parent:Section({
        Title = title,
        TextSize = 14,
        Opened = opened == true,
    })
end

function UIRuntime.createToggle(parent, field, options)
    options.TextSize = 13
    options.DescTextSize = 11
    local originalCallback = options.Callback
    options.Callback = function(value)
        if State.synchronizing then
            State[field] = value == true
            return
        end
        if originalCallback then
            originalCallback(value == true)
        else
            State[field] = value == true
            ConfigRuntime.scheduleSave(false)
        end
    end
    State[field] = State[field] == true
    return parent:Toggle(options)
end

function UIRuntime.createDropdown(parent, field, options)
    options.TextSize = 13
    options.DescTextSize = 11
    local originalCallback = options.Callback
    options.Callback = function(value)
        if State.synchronizing then
            return
        end
        if originalCallback then
            originalCallback(value)
        else
            State[field] = value
            ConfigRuntime.scheduleSave(false)
        end
    end
    return parent:Dropdown(options)
end

function UIRuntime.createInput(parent, field, options)
    options.TextSize = 13
    options.DescTextSize = 11
    local originalCallback = options.Callback
    options.Callback = function(value)
        if State.synchronizing then
            State[field] = tostring(value or "")
            return
        end
        if originalCallback then
            originalCallback(value)
        else
            State[field] = tostring(value or "")
            ConfigRuntime.scheduleSave(false)
        end
    end
    return parent:Input(options)
end

function UIRuntime.createButton(parent, options)
    options.TextSize = 13
    options.DescTextSize = 11
    return parent:Button(options)
end

function UIRuntime.build(WindUI)
    local window = WindUI:CreateWindow({
        Title = GAME_NAME,
        Icon = "shield",
        Author = "xSansHUB",
        Folder = "xSansHUB_RollToDefend",
        Size = UDim2.fromOffset(520, 400),
        MinSize = Vector2.new(480, 340),
        ToggleKey = Enum.KeyCode[State.windowKeybind],
        Transparent = true,
        Theme = "Indigo",
        Resizable = true,
        SideBarWidth = 160,
        HideSearchBar = true,
        ScrollBarEnabled = false,
    })
    State.window = window
    window:Tag({
        Title = "v" .. Hub.Version,
        Icon = "badge-info",
        Border = true,
    })
    local automationTab = UIRuntime.createTab(window, "Automation", "bot")
    local rollTab = UIRuntime.createTab(window, "Roll", "dices")
    local logsTab = UIRuntime.createTab(window, "Logs", "scroll-text")
    local settingsTab = UIRuntime.createTab(window, "Settings", "settings")
    local teamSection = UIRuntime.createSection(automationTab, "Progression & Team", true)
    State.autoEquipBestToggle = UIRuntime.createToggle(teamSection, "autoEquipBest", {
        Title = "Auto Equip Best",
        Desc = "Equips the strongest available units whenever the team is no longer optimal.",
        Type = "Checkbox",
        Value = State.autoEquipBest,
        Callback = TeamRuntime.setAuto,
    })
    State.autoRebirthToggle = UIRuntime.createToggle(teamSection, "autoRebirth", {
        Title = "Auto Rebirth",
        Desc = "Rebirths automatically when the official requirements and policy allow it.",
        Type = "Checkbox",
        Value = State.autoRebirth,
        Callback = RebirthRuntime.setAuto,
    })
    State.autoBuyZonesToggle = UIRuntime.createToggle(teamSection, "autoBuyZones", {
        Title = "Auto Buy Zones",
        Desc = "Purchases the next sequential zone when cash, tutorial, and zone policy requirements are met.",
        Type = "Checkbox",
        Value = State.autoBuyZones,
        Callback = ZoneRuntime.setAuto,
    })
    local rewardsSection = UIRuntime.createSection(automationTab, "Daily & Rewards", false)
    State.autoClaimIndexToggle = UIRuntime.createToggle(rewardsSection, "autoClaimIndex", {
        Title = "Auto Claim Index",
        Desc = "Claims every currently available Index reward, one confirmed reward at a time.",
        Type = "Checkbox",
        Value = State.autoClaimIndex,
        Callback = IndexRuntime.setAuto,
    })
    local lootSection = UIRuntime.createSection(automationTab, "Loot", false)
    State.autoCollectLootToggle = UIRuntime.createToggle(lootSection, "autoCollectLoot", {
        Title = "Auto Collect Drop Loot",
        Desc = "Uses native coin scheduling and moves unlocked item drops into the game pickup radius.",
        Type = "Checkbox",
        Value = State.autoCollectLoot,
        Callback = LootRuntime.setAuto,
    })
    local consumablesSection = UIRuntime.createSection(automationTab, "Consumables", false)
    State.autoUsePotionsToggle = UIRuntime.createToggle(consumablesSection, "autoUsePotions", {
        Title = "Auto Use Potions",
        Desc = "Uses one available whitelisted potion whenever its matching effect is inactive.",
        Type = "Checkbox",
        Value = State.autoUsePotions,
        Callback = PotionRuntime.setAuto,
    })
    State.potionWhitelistDropdown = UIRuntime.createDropdown(consumablesSection, "potionWhitelist", {
        Title = "Potion Whitelist",
        Desc = "Only selected potion types may be used automatically.",
        Values = RuntimeName.PotionLabels,
        Value = PotionRuntime.getSelectedLabels(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 320,
        Callback = PotionRuntime.setWhitelist,
    })
    UIRuntime.createButton(consumablesSection, {
        Title = "Select All Potions",
        Desc = "Select every supported potion type.",
        Icon = "list-checks",
        Callback = function()
            PotionRuntime.setAll(true)
        end,
    })
    UIRuntime.createButton(consumablesSection, {
        Title = "Unselect All Potions",
        Desc = "Clear every selected potion type.",
        Icon = "list-x",
        Callback = function()
            PotionRuntime.setAll(false)
        end,
    })
    local skillSection = UIRuntime.createSection(automationTab, "Skill Upgrades", false)
    State.autoUpgradeSkillsToggle = UIRuntime.createToggle(skillSection, "autoUpgradeSkills", {
        Title = "Auto Upgrade Skills",
        Desc = "Purchases one eligible whitelisted skill at a time using the official upgrade remote.",
        Type = "Checkbox",
        Value = State.autoUpgradeSkills,
        Callback = SkillRuntime.setAuto,
    })
    State.skillUpgradePriorityDropdown = UIRuntime.createDropdown(skillSection, "skillUpgradePriority", {
        Title = "Upgrade Priority",
        Desc = "Chooses the cheapest or most expensive currently affordable skill first.",
        Values = {"Cheapest First", "Most Expensive First"},
        Value = State.skillUpgradePriority,
        Multi = false,
        AllowNone = false,
        Callback = SkillRuntime.setPriority,
    })
    local initialGroupLabels, initialGroupKeys = SkillRuntime.getFilteredGroups("")
    RuntimeName.SkillVisibleGroupKeys = initialGroupKeys
    State.skillUpgradeWhitelistDropdown = UIRuntime.createDropdown(skillSection, "skillUpgradeWhitelist", {
        Title = "Skill Group Whitelist",
        Desc = "Selecting one group enables every tier in that group.",
        Values = initialGroupLabels,
        Value = SkillRuntime.getWhitelistSelections(initialGroupKeys),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 320,
        Callback = function(values)
            SkillRuntime.setWhitelist(values, false)
        end,
    })
    UIRuntime.createButton(skillSection, {
        Title = "Select All",
        Desc = "Select every skill group.",
        Icon = "list-checks",
        Callback = function()
            SkillRuntime.selectAll(true)
        end,
    })
    UIRuntime.createButton(skillSection, {
        Title = "Unselect All",
        Desc = "Clear every selected skill group.",
        Icon = "list-x",
        Callback = function()
            SkillRuntime.selectAll(false)
        end,
    })
    local rollAutomationSection = UIRuntime.createSection(rollTab, "Roll Automation", true)
    State.autoRollToggle = UIRuntime.createToggle(rollAutomationSection, "autoRoll", {
        Title = "Auto Roll",
        Desc = "Rolls in the background while native roll UI animations and rare cutscenes are suppressed.",
        Type = "Checkbox",
        Value = State.autoRoll,
        Callback = RollRuntime.setAuto,
    })
    local rollLogsSection = UIRuntime.createSection(rollTab, "Result Logs", true)
    State.rollLogRarityWhitelistDropdown = UIRuntime.createDropdown(rollLogsSection, "rollLogRarityWhitelist", {
        Title = "Rarity Log Whitelist",
        Desc = "Only selected result rarities are added to Logs.",
        Values = RuntimeName.RollRarityNames,
        Value = RollRuntime.getSelectedRarities(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = RollRuntime.setRarityWhitelist,
    })
    UIRuntime.createButton(rollLogsSection, {
        Title = "Select All Rarities",
        Desc = "Log every available roll result rarity.",
        Icon = "list-checks",
        Callback = function()
            RollRuntime.setAllRarities(true)
        end,
    })
    UIRuntime.createButton(rollLogsSection, {
        Title = "Unselect All Rarities",
        Desc = "Disable roll result logging for every rarity.",
        Icon = "list-x",
        Callback = function()
            RollRuntime.setAllRarities(false)
        end,
    })
    local logsSection = UIRuntime.createSection(logsTab, "Session", true)
    State.logsParagraph = logsSection:Paragraph({
        Title = "Activity",
        Desc = LogRuntime.buildDisplayText(),
    })
    State.logFilterInput = UIRuntime.createInput(logsSection, "logFilter", {
        Title = "Log Filter",
        Desc = "Case-insensitive text filter.",
        Value = State.logFilter,
        Placeholder = "Filter logs...",
        Callback = function(value)
            State.logFilter = tostring(value or "")
            LogRuntime.refresh()
            ConfigRuntime.scheduleSave(false)
        end,
    })
    UIRuntime.createButton(logsSection, {
        Title = "Clear Logs",
        Desc = "Clears the current session log list.",
        Icon = "trash-2",
        Callback = LogRuntime.clear,
    })
    local interfaceSection = UIRuntime.createSection(settingsTab, "Interface", true)
    State.windowKeybindControl = interfaceSection:Keybind({
        Title = "Window Keybind",
        Desc = "Opens or closes the hub window.",
        Value = State.windowKeybind,
        Callback = function(value)
            local key = normalizeKeybind(value)
            State.windowKeybind = key
            pcall(function()
                window:SetToggleKey(Enum.KeyCode[key])
            end)
            ConfigRuntime.scheduleSave(false)
        end,
    })
    local utilitiesSection = UIRuntime.createSection(settingsTab, "Utilities", false)
    State.antiAfkToggle = UIRuntime.createToggle(utilitiesSection, "antiAfk", {
        Title = "Anti AFK",
        Desc = "Runs all supported idle-prevention input methods every 45 seconds.",
        Type = "Checkbox",
        Value = State.antiAfk,
        Callback = AntiAfkRuntime.setEnabled,
    })
    local configurationSection = UIRuntime.createSection(settingsTab, "Configuration", false)
    State.autoSaveToggle = UIRuntime.createToggle(configurationSection, "autoSave", {
        Title = "Auto Save",
        Desc = "Saves persistent settings after changes.",
        Type = "Checkbox",
        Value = State.autoSave,
        Callback = function(enabled)
            State.autoSave = enabled
            ConfigRuntime.scheduleSave(true)
        end,
    })
    UIRuntime.createButton(configurationSection, {
        Title = "Close Hub",
        Desc = "Stops automation, disconnects listeners, and closes the window.",
        Icon = "x",
        Callback = function()
            Hub.Stop()
        end,
    })
    window:SelectTab(1)
    ConfigRuntime.syncControls()
end

function TeamRuntime.connectDataListeners()
    State.inventoryChangedConnection = Modules.DataController:OnChanged("Inventory", function()
        if State.autoEquipBest then
            State.equipBestNextAt = 0
            TeamRuntime.confirmFromState()
        end
    end)
    State.equippedChangedConnection = Modules.DataController:OnChanged("EquippedUnits", function()
        if State.autoEquipBest then
            TeamRuntime.confirmFromState()
        end
    end)
    State.upgradesChangedConnection = Modules.DataController:OnChanged("UpgradeLevels", function()
        if State.autoEquipBest then
            State.equipBestNextAt = 0
            TeamRuntime.confirmFromState()
        end
    end)
end

function RebirthRuntime.connectDataListeners()
    State.rebirthCurrencyChangedConnection = Modules.DataController:OnChanged(Modules.RebirthData.CostCurrencyPath, function()
        if State.autoRebirth then
            State.rebirthNextAt = 0
        end
    end)
    State.rebirthCountChangedConnection = Modules.DataController:OnChanged(Modules.RebirthData.RebirthsPath, function()
        if State.autoRebirth then
            RebirthRuntime.confirmFromState()
            State.rebirthNextAt = math.min(State.rebirthNextAt, os.clock() + State.rebirthCooldown)
        end
    end)
    if type(Modules.ClientPolicy.OnChanged) == "function" then
        State.rebirthPolicyChangedConnection = Modules.ClientPolicy.OnChanged(function()
            if State.autoRebirth then
                State.rebirthNextAt = 0
            end
        end)
    end
    State.rebirthResultConnection = Remotes.RebirthRequest.OnClientEvent:Connect(RebirthRuntime.handleResult)
end

Hub.Team = {
    SetAuto = TeamRuntime.setAuto,
    ToggleAuto = function()
        TeamRuntime.setAuto(not State.autoEquipBest)
        if State.autoEquipBestToggle then
            pcall(function()
                State.autoEquipBestToggle:Set(State.autoEquipBest, false)
            end)
        end
        return State.autoEquipBest
    end,
    Process = TeamRuntime.process,
    GetState = TeamRuntime.getState,
}

Hub.Rebirth = {
    SetAuto = RebirthRuntime.setAuto,
    ToggleAuto = function()
        RebirthRuntime.setAuto(not State.autoRebirth)
        if State.autoRebirthToggle then
            pcall(function()
                State.autoRebirthToggle:Set(State.autoRebirth, false)
            end)
        end
        return State.autoRebirth
    end,
    Process = RebirthRuntime.process,
    GetState = RebirthRuntime.getState,
}


Hub.Zones = {
    SetAuto = ZoneRuntime.setAuto,
    ToggleAuto = function()
        ZoneRuntime.setAuto(not State.autoBuyZones)
        if State.autoBuyZonesToggle then
            pcall(function()
                State.autoBuyZonesToggle:Set(State.autoBuyZones, false)
            end)
        end
        return State.autoBuyZones
    end,
    Process = ZoneRuntime.process,
    GetState = ZoneRuntime.getState,
}

Hub.Skills = {
    SetAuto = SkillRuntime.setAuto,
    ToggleAuto = function()
        SkillRuntime.setAuto(not State.autoUpgradeSkills)
        if State.autoUpgradeSkillsToggle then
            pcall(function()
                State.autoUpgradeSkillsToggle:Set(State.autoUpgradeSkills, false)
            end)
        end
        return State.autoUpgradeSkills
    end,
    Process = SkillRuntime.process,
    SetPriority = SkillRuntime.setPriority,
    SetWhitelist = SkillRuntime.setWhitelist,
    SelectAll = function()
        SkillRuntime.selectAll(true)
    end,
    UnselectAll = function()
        SkillRuntime.selectAll(false)
    end,
    SelectAllVisible = function()
        SkillRuntime.selectAll(true)
    end,
    UnselectAllVisible = function()
        SkillRuntime.selectAll(false)
    end,
    GetGroups = function()
        local groups = {}
        for _, groupKey in ipairs(RuntimeName.SkillGroupKeys) do
            local group = RuntimeName.SkillGroups[groupKey]
            table.insert(groups, {
                key = groupKey,
                name = group.label,
                skillIds = table.clone(group.skillIds),
                selected = SkillRuntime.isGroupSelected(groupKey),
            })
        end
        return groups
    end,
    GetSkills = function()
        local skills = {}
        for _, skillId in ipairs(RuntimeName.SkillIds) do
            local definition = RuntimeName.SkillDefinitions[skillId]
            local currency, price = SkillRuntime.getPrice(definition.data)
            table.insert(skills, {
                id = skillId,
                name = definition.data.name or skillId,
                display = RuntimeName.SkillIdToDisplay[skillId],
                tree = definition.tree,
                group = RuntimeName.SkillGroups[RuntimeName.SkillIdToGroup[skillId]].label,
                currency = currency,
                price = price,
            })
        end
        return skills
    end,
    GetState = SkillRuntime.getState,
}


Hub.Index = {
    SetAuto = IndexRuntime.setAuto,
    ToggleAuto = function()
        IndexRuntime.setAuto(not State.autoClaimIndex)
        if State.autoClaimIndexToggle then
            pcall(function()
                State.autoClaimIndexToggle:Set(State.autoClaimIndex, false)
            end)
        end
        return State.autoClaimIndex
    end,
    Process = IndexRuntime.process,
    GetState = IndexRuntime.getState,
}

Hub.Roll = {
    SetAuto = RollRuntime.setAuto,
    ToggleAuto = function()
        RollRuntime.setAuto(not State.autoRoll)
        if State.autoRollToggle then
            pcall(function()
                State.autoRollToggle:Set(State.autoRoll, false)
            end)
        end
        return State.autoRoll
    end,
    Process = RollRuntime.process,
    SetRarityWhitelist = RollRuntime.setRarityWhitelist,
    SelectAllRarities = function()
        RollRuntime.setAllRarities(true)
    end,
    UnselectAllRarities = function()
        RollRuntime.setAllRarities(false)
    end,
    GetRarities = function()
        return table.clone(RuntimeName.RollRarityNames or {})
    end,
    GetState = RollRuntime.getState,
}

Hub.Potions = {
    SetAuto = PotionRuntime.setAuto,
    ToggleAuto = function()
        PotionRuntime.setAuto(not State.autoUsePotions)
        if State.autoUsePotionsToggle then
            pcall(function()
                State.autoUsePotionsToggle:Set(State.autoUsePotions, false)
            end)
        end
        return State.autoUsePotions
    end,
    Process = PotionRuntime.process,
    SetWhitelist = PotionRuntime.setWhitelist,
    SelectAll = function()
        PotionRuntime.setAll(true)
    end,
    UnselectAll = function()
        PotionRuntime.setAll(false)
    end,
    GetPotions = PotionRuntime.getPotions,
    GetState = PotionRuntime.getState,
}

Hub.Loot = {
    SetAuto = LootRuntime.setAuto,
    ToggleAuto = function()
        LootRuntime.setAuto(not State.autoCollectLoot)
        if State.autoCollectLootToggle then
            pcall(function()
                State.autoCollectLootToggle:Set(State.autoCollectLoot, false)
            end)
        end
        return State.autoCollectLoot
    end,
    Process = LootRuntime.process,
    GetState = LootRuntime.getState,
}

Hub.Logs = {
    Add = LogRuntime.add,
    Clear = LogRuntime.clear,
    Get = function()
        return table.clone(State.logs)
    end,
}

Hub.Config = {
    Save = ConfigRuntime.save,
    Load = function()
        local success, errorMessage = ConfigRuntime.load()
        if success then
            ConfigRuntime.syncControls()
            TeamRuntime.setAuto(State.autoEquipBest)
            RebirthRuntime.setAuto(State.autoRebirth)
            ZoneRuntime.setAuto(State.autoBuyZones)
            SkillRuntime.setAuto(State.autoUpgradeSkills)
            IndexRuntime.setAuto(State.autoClaimIndex)
            RollRuntime.setAuto(State.autoRoll)
            PotionRuntime.setAuto(State.autoUsePotions)
            LootRuntime.setAuto(State.autoCollectLoot)
            AntiAfkRuntime.setEnabled(State.antiAfk)
        end
        return success, errorMessage
    end,
    GetPath = function()
        return ConfigRuntime.path
    end,
}

Hub.AntiAfk = {
    SetEnabled = AntiAfkRuntime.setEnabled,
    Toggle = function()
        AntiAfkRuntime.setEnabled(not State.antiAfk)
        if State.antiAfkToggle then
            pcall(function()
                State.antiAfkToggle:Set(State.antiAfk, false)
            end)
        end
        return State.antiAfk
    end,
    Pulse = AntiAfkRuntime.pulse,
    GetState = AntiAfkRuntime.getState,
}

function Hub.GetState()
    return {
        running = State.running,
        game = GAME_NAME,
        placeId = game.PlaceId,
        version = Hub.Version,
        build = Hub.Build,
        team = TeamRuntime.getState(),
        rebirth = RebirthRuntime.getState(),
        zones = ZoneRuntime.getState(),
        skills = SkillRuntime.getState(),
        index = IndexRuntime.getState(),
        roll = RollRuntime.getState(),
        potions = PotionRuntime.getState(),
        loot = LootRuntime.getState(),
        antiAfk = AntiAfkRuntime.getState(),
        configPath = ConfigRuntime.path,
    }
end

function Hub.Stop()
    if not State.running then
        return
    end
    if State.autoSave then
        pcall(ConfigRuntime.save)
    end
    State.running = false
    State.autoEquipBest = false
    State.autoRebirth = false
    State.autoBuyZones = false
    State.autoUpgradeSkills = false
    State.autoClaimIndex = false
    State.autoRoll = false
    State.rollRuntimeActive = false
    State.autoUsePotions = false
    State.autoCollectLoot = false
    State.antiAfk = false
    TeamRuntime.clearPending("Stopped")
    RebirthRuntime.clearPending("Stopped")
    ZoneRuntime.clearPending("Stopped", true)
    SkillRuntime.clearPending("Stopped", true)
    IndexRuntime.clearPending("Stopped")
    RollRuntime.clearPending("Stopped")
    PotionRuntime.clearPending("Stopped")
    RollRuntime.setNativeVisualConnectionsEnabled(true)
    RollRuntime.setCutsceneSuppressed(false)
    RollRuntime.setNativeGuiHidden(false)
    RollRuntime.clearSpecialRollDisplay()
    if State.rollNativeAutoWasEnabled then
        pcall(Remotes.AutoRollState.FireServer, Remotes.AutoRollState, true)
    end
    State.rollNativeAutoWasEnabled = false
    RuntimeName.LootItemAttempts = setmetatable({}, {__mode = "k"})
    State.lootCollectLastStatus = "Stopped"
    ConnectionRuntime.disconnectAll()
    ConfigRuntime.saveToken = ConfigRuntime.saveToken + 1
    if State.window then
        pcall(function()
            State.window:Destroy()
        end)
        State.window = nil
    end
    if getgenv()[GLOBAL_NAME] == Hub then
        getgenv()[GLOBAL_NAME] = nil
    end
end

getgenv()[GLOBAL_NAME] = Hub

local rollRegistrySuccess, rollRegistryError = pcall(RollRuntime.buildRarityRegistry)
if not rollRegistrySuccess or #RuntimeName.RollRarityNames == 0 then
    warn("[xSansHUB] Roll rarity registry startup failed: " .. tostring(rollRegistryError or "no rarity definitions"))
    Hub.Stop()
    return
end

local potionRegistrySuccess, potionRegistryError = pcall(PotionRuntime.buildRegistry)
if not potionRegistrySuccess or #RuntimeName.PotionIds == 0 then
    warn("[xSansHUB] Potion registry startup failed: " .. tostring(potionRegistryError or "no potion definitions"))
    Hub.Stop()
    return
end

local skillRegistrySuccess, skillRegistryError = pcall(SkillRuntime.buildRegistry)
if not skillRegistrySuccess or #RuntimeName.SkillIds == 0 then
    warn("[xSansHUB] Skill registry startup failed: " .. tostring(skillRegistryError or "no purchasable skill definitions"))
    Hub.Stop()
    return
end

local configLoaded, configLoadError = ConfigRuntime.load()
if not configLoaded and configLoadError ~= "missing" and configLoadError ~= "file APIs are unavailable" then
    LogRuntime.add("Config load failed: " .. tostring(configLoadError), true)
end

local windSuccess, WindUI = pcall(function()
    local separator = string.find(WINDUI_URL, "?", 1, true) and "&" or "?"
    local source = game:HttpGet(WINDUI_URL .. separator .. "cache=" .. tostring(os.time()), false)
    return loadstring(source)()
end)

if not windSuccess then
    warn("[xSansHUB] WindUI load failed: " .. tostring(WindUI))
    Hub.Stop()
    return
end

local uiSuccess, uiError = pcall(UIRuntime.build, WindUI)
if not uiSuccess then
    warn("[xSansHUB] UI startup failed: " .. tostring(uiError))
    Hub.Stop()
    return
end

local listenersSuccess, listenersError = pcall(TeamRuntime.connectDataListeners)
if not listenersSuccess then
    LogRuntime.add("Team listener startup failed: " .. tostring(listenersError), true)
end

local rebirthListenersSuccess, rebirthListenersError = pcall(RebirthRuntime.connectDataListeners)
if not rebirthListenersSuccess then
    LogRuntime.add("Rebirth listener startup failed: " .. tostring(rebirthListenersError), true)
end

local zoneListenersSuccess, zoneListenersError = pcall(ZoneRuntime.connectDataListeners)
if not zoneListenersSuccess then
    LogRuntime.add("Zone listener startup failed: " .. tostring(zoneListenersError), true)
end

local skillListenersSuccess, skillListenersError = pcall(SkillRuntime.connectDataListeners)
if not skillListenersSuccess then
    LogRuntime.add("Skill listener startup failed: " .. tostring(skillListenersError), true)
end

local indexListenersSuccess, indexListenersError = pcall(IndexRuntime.connectDataListeners)
if not indexListenersSuccess then
    LogRuntime.add("Index listener startup failed: " .. tostring(indexListenersError), true)
end

local rollListenerSuccess, rollListenerError = pcall(RollRuntime.connectResultListener)
if not rollListenerSuccess then
    LogRuntime.add("Roll listener startup failed: " .. tostring(rollListenerError), true)
end

local potionListenersSuccess, potionListenersError = pcall(PotionRuntime.connectDataListeners)
if not potionListenersSuccess then
    LogRuntime.add("Potion listener startup failed: " .. tostring(potionListenersError), true)
end

if State.antiAfk then
    AntiAfkRuntime.setEnabled(true)
end

if State.autoEquipBest then
    TeamRuntime.setAuto(true)
end

if State.autoRebirth then
    RebirthRuntime.setAuto(true)
end

if State.autoBuyZones then
    ZoneRuntime.setAuto(true)
end

if State.autoUpgradeSkills then
    SkillRuntime.setAuto(true)
end

if State.autoClaimIndex then
    IndexRuntime.setAuto(true)
end

if State.autoRoll then
    RollRuntime.setAuto(true)
end

if State.autoUsePotions then
    PotionRuntime.setAuto(true)
end

if State.autoCollectLoot then
    LootRuntime.setAuto(true)
end

if not configLoaded and State.autoSave then
    ConfigRuntime.scheduleSave(true)
end

SchedulerRuntime.start({
    {
        interval = function()
            return State.equipBestPollInterval
        end,
        callback = TeamRuntime.tick,
    },
    {
        interval = function()
            return State.rebirthPollInterval
        end,
        callback = RebirthRuntime.tick,
    },
    {
        interval = function()
            return State.zonePurchasePollInterval
        end,
        callback = ZoneRuntime.tick,
    },
    {
        interval = function()
            return State.skillUpgradePollInterval
        end,
        callback = SkillRuntime.tick,
    },
    {
        interval = function()
            return State.indexClaimPollInterval
        end,
        callback = IndexRuntime.tick,
    },
    {
        interval = function()
            return State.rollPollInterval
        end,
        callback = RollRuntime.tick,
    },
    {
        interval = function()
            return State.potionPollInterval
        end,
        callback = PotionRuntime.tick,
    },
    {
        interval = function()
            return State.lootCollectPollInterval
        end,
        callback = LootRuntime.tick,
    },
})
