local Services = {}
local Modules = {}
local Remotes = {}
local State = {}
local RuntimeName = {}
local ConfigRuntime = {}
local Hub = {}
local ModuleDefinitions = {}
local RemoteDefinitions = {}
local BooleanSettingDefinitions = {}
local ValueSettingDefinitions = {}
local MapSettingDefinitions = {}
local SchedulerRuntime = {}
local ConnectionRuntime = {}
local LogRuntime = {}
local RebirthRuntime = {}
local TrainingRuntime = {}
local WeightTrainingRuntime = {}
local WeightRuntime = {}
local PlaytimeRuntime = {}
local SpinRuntime = {}
local KickRuntime = {}
local KickRewardRuntime = {}
local PlotRuntime = {}
local CollectRuntime = {}
local CardUpgradeRuntime = {}
local CardPlacementRuntime = {}
local CardPickupRuntime = {}
local SpeedUpgradeRuntime = {}
local AntiAfkRuntime = {}
local VisualRuntime = {}
local InterfaceRuntime = {}

Services.Players = game:GetService("Players")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.HttpService = game:GetService("HttpService")
Services.RunService = game:GetService("RunService")
Services.Workspace = game:GetService("Workspace")
Services.UserInputService = game:GetService("UserInputService")
Services.VirtualInputManager = game:GetService("VirtualInputManager")
Services.VirtualUser = game:GetService("VirtualUser")

RuntimeName.game = "Kick A Lucky Block For Soccer Cards"
RuntimeName.global = "xSansKickALuckyBlockForSoccerCardsHub"
RuntimeName.configFolder = "Kick A Lucky Block For Soccer Cards"
RuntimeName.loader = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"

ConfigRuntime.version = 30

local function formatScriptVersion(build)
    build = math.max(0, math.floor(tonumber(build) or 0))
    if build < 100 then
        return string.format("1.%d.0", build)
    end
    return string.format("1.%d.%d", math.floor(build / 100), build % 100)
end

Hub.Build = ConfigRuntime.version
Hub.Version = formatScriptVersion(Hub.Build)
Hub.SecretLandingRisk = "DUAL MODE"

State.running = true
State.autoRebirth = false
State.rebirthPollInterval = 0.35
State.rebirthCooldown = 0.75
State.rebirthNextAt = 0
State.rebirthPending = false
State.rebirthPendingSince = 0
State.rebirthPendingTimeout = 8
State.rebirthBeforeCount = 0
State.rebirthBeforePower = 0
State.rebirthFailures = 0
State.rebirthLastStatus = "Idle"
State.rebirthLastSignature = nil
State.autoTrainingWeight = false
State.hideTrainingBonusVisuals = true
State.trainingTapDelay = 0.05
State.trainingPollInterval = 0.1
State.trainingCooldown = 0.35
State.trainingNextAt = 0
State.trainingToken = nil
State.trainingDuration = 0
State.trainingExpiresAt = 0
State.trainingReward = 0
State.trainingQueuedAt = 0
State.trainingPending = false
State.trainingPendingSince = 0
State.trainingPendingTimeout = 2.5
State.trainingBeforePower = 0
State.trainingAttempts = 0
State.trainingFailures = 0
State.trainingLastStatus = "Idle"
State.trainingNativeConnections = {}
State.trainingNativeSuppressed = false
State.autoWeightTraining = false
State.freeMovementWhileTraining = false
State.weightTrainingPollInterval = 0.1
State.weightTrainingActivateInterval = 0.25
State.weightTrainingNextAt = 0
State.weightTrainingLastActivateAt = 0
State.weightTrainingLastPower = 0
State.weightTrainingLastPowerAt = 0
State.weightTrainingActivationCount = 0
State.weightTrainingFailures = 0
State.weightTrainingTool = nil
State.weightTrainingToolName = nil
State.weightTrainingManagedEquip = false
State.weightTrainingLastStatus = "Idle"
State.weightTrainingHumanoid = nil
State.weightTrainingRoot = nil
State.weightTrainingBaseWalkSpeed = 16
State.weightTrainingBaseJumpPower = 50
State.weightTrainingBaseJumpHeight = 7.2
State.weightTrainingBaseAutoRotate = true
State.weightTrainingControls = nil
State.weightTrainingControlsResolved = false
State.autoBuyWeights = false
State.autoBuyBestAffordableWeight = false
State.weightBuyWhitelist = {}
State.weightCurrencyNames = {"Cash", "Money", "Coins", "Currency"}
State.weightCurrencyName = nil
State.weightCurrencySource = nil
State.weightCurrencyValue = 0
State.weightBestAffordableTarget = nil
State.weightBestOwnedName = nil
State.weightBestOwnedPower = 0
State.weightBestOwnedPrice = 0
State.weightNames = {}
State.weightNameSet = {}
State.weightData = {}
State.weightUnlocked = {}
State.weightEquipped = nil
State.weightCursor = 0
State.weightPollInterval = 0.35
State.weightCooldown = 0.75
State.weightRetryCooldown = 4
State.weightNextAt = 0
State.weightPending = false
State.weightPendingSince = 0
State.weightPendingTimeout = 5
State.weightPendingName = nil
State.weightPendingAction = nil
State.weightFailures = 0
State.weightLastStatus = "Idle"
State.weightLastRefreshAt = 0
State.autoClaimPlaytimeRewards = false
State.playtimePollInterval = 1
State.playtimeCooldown = 0.75
State.playtimeRetryCooldown = 3
State.playtimeNextAt = 0
State.playtimePending = false
State.playtimePendingId = nil
State.playtimeFailures = 0
State.playtimeLastStatus = "Idle"
State.playtimeState = nil
State.playtimeLastRefreshAt = 0
State.playtimeRefreshInterval = 15
State.autoSpin = false
State.spinPollInterval = 0.35
State.spinCooldown = 7
State.spinRetryCooldown = 7
State.spinNextAt = 0
State.spinPending = false
State.spinFailures = 0
State.spinDeniedCount = 0
State.spinLastStatus = "Idle"
State.spinLastIndex = nil
State.spinLastResult = nil
State.spinLastResponseMessage = nil
State.spinAwaitingState = false
State.spinAwaitingSince = 0
State.spinAwaitingTimeout = 8
State.spinBeforeSignature = nil
State.spinLocalDailyUsedAt = 0
State.autoLandSecretChance = false
State.autoLandSecretChanceLowRisk = false
State.autoLandSecretChanceRisk = false
State.kickSecretPollInterval = 0.12
State.kickSecretCooldown = 2.5
State.kickSecretRetryCooldown = 5
State.kickSecretNextAt = 0
State.kickSecretPhase = "Idle"
State.kickSecretPhaseSince = 0
State.kickSecretWalkTimeout = 15
State.kickSecretSelectTimeout = 6
State.kickSecretLaunchTimeout = 12
State.kickSecretLaunchRecoveryTimeout = 75
State.kickSecretFlightTimeout = 35
State.kickSecretActivitySeen = false
State.kickSecretActivitySeenAt = 0
State.kickSecretRecoveredLaunches = 0
State.kickSecretTargetPower = 0.99
State.kickSecretInstantPowerSpeed = 120
State.kickSecretOriginalPowerBarSpeed = nil
State.kickSecretInstantPowerArmed = false
State.kickSecretPowerSubmitPending = false
State.kickSecretPerfectThreshold = 0.9
State.kickSecretAssistStartRatio = 0.55
State.kickSecretHardCorrectRatio = 0.78
State.kickSecretTargetZone = nil
State.kickSecretTargetPart = nil
State.kickSecretBlock = nil
State.kickSecretAssistApplied = false
State.kickSecretTargetReached = false
State.kickSecretLandingCount = 0
State.kickSecretFailures = 0
State.kickSecretLastStatus = "Idle"
State.kickSecretLastProgress = 0
State.kickSecretLastDistance = 0
State.kickSecretLastError = nil
State.kickSecretFireSignalCallback = nil
State.kickSecretFireSignalResolved = false
State.kickSecretRequiredPower = 0
State.kickSecretCurrentPower = 0
State.kickSecretRequirementMet = false
State.kickSecretRequirementAvailable = false
State.kickSecretTargetBlockName = nil
State.kickSecretRunActive = false
State.kickSecretRunDistance = 500
State.kickSecretRunSpeedMultiplier = 2
State.kickSecretRunBaseWalkSpeed = nil
State.kickSecretRunHumanoid = nil
State.kickSecretRunAppliedWalkSpeed = nil
State.kickSecretReturnTimeout = 20
State.kickSecretHardCorrectionEnabled = false
State.kickSecretRiskLevel = "OFF"
State.kickSecretRunMode = "Idle"
State.kickSecretRunDirection = Vector3.zero
State.kickSecretRunDestination = nil
State.kickSecretAutoRunConnection = nil
State.kickRewardAwaitingCard = false
State.kickRewardActivityCount = 0
State.kickRewardLoggedCount = 0
State.kickRewardWindowUntil = 0
State.kickRewardLastStatus = "Idle"
State.kickRewardLastCard = nil
State.kickRewardLastRarity = nil
State.kickRewardLastMutation = nil
State.kickRewardLastLevel = 0
State.kickRewardLastIncome = 0
State.kickRewardLastZone = nil
State.kickRewardPendingTools = setmetatable({}, {__mode = "k"})
State.kickRewardSeenTools = setmetatable({}, {__mode = "k"})
State.kickRewardFilterThresholdNames = {"None", "AND", "OR"}
State.kickRewardFilterThresholdSet = {None = true, AND = true, OR = true}
State.kickRewardFilterThreshold = "None"
State.kickRewardCardNameNames = {"None"}
State.kickRewardCardNameSet = {None = true}
State.kickRewardRarityNames = {"None"}
State.kickRewardRaritySet = {None = true}
State.kickRewardMutationNames = {"None"}
State.kickRewardMutationSet = {None = true}
State.kickRewardCardNameWhitelist = {None = true}
State.kickRewardRarityWhitelist = {None = true}
State.kickRewardMutationWhitelist = {None = true}
State.kickRewardFilterDecision = nil
State.kickRewardFilterDecisionReason = "Not Evaluated"
State.kickRewardFilterDecisionLogged = false
State.kickRewardFilterWaitSince = 0
State.kickRewardFilterWaitTimeout = 1.5
State.kickRewardCurrentPreview = nil
State.kickRewardAcceptedCount = 0
State.kickRewardRejectedCount = 0
State.kickRewardRejecting = false
State.kickRewardLastDecision = nil
State.kickRewardLastDecisionReason = nil
State.autoCollectMoney = false
State.collectPollInterval = 0.08
State.collectCycleDelay = 0.1
State.collectNextAt = 0
State.collectCursor = 0
State.collectPending = false
State.collectPendingSince = 0
State.collectPendingTimeout = 0.5
State.collectPendingKey = nil
State.collectPendingSlot = nil
State.collectBeforeSignature = nil
State.collectFailures = 0
State.collectLastStatus = "Idle"
State.collectUnavailableLogged = false
State.autoUpgradePlacedCards = false
State.cardUpgradeRarityNames = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythical",
    "Divine",
    "Celestial",
    "Cosmic",
    "Eternal",
    "Hacked",
    "Secret",
    "Exclusive",
}
State.cardUpgradeRaritySet = {}
for _, rarity in ipairs(State.cardUpgradeRarityNames) do
    State.cardUpgradeRaritySet[rarity] = true
end
State.cardUpgradeRarityWhitelist = {}
State.cardUpgradeTargetLevel = 50
State.cardUpgradePollInterval = 0.08
State.cardUpgradeCooldown = 0
State.cardUpgradeRetryCooldown = 15
State.cardUpgradeNextAt = 0
State.cardUpgradeCursor = 0
State.cardUpgradePending = false
State.cardUpgradePendingSince = 0
State.cardUpgradePendingTimeout = 2
State.cardUpgradePendingKey = nil
State.cardUpgradePendingSlot = nil
State.cardUpgradePendingVisual = nil
State.cardUpgradeBeforeLevel = 0
State.cardUpgradeBeforeEarnings = ""
State.cardUpgradeSkipUntil = {}
State.cardUpgradeFailures = 0
State.cardUpgradeLastStatus = "Idle"
State.autoFillEmptySlots = false
State.cardPlacementPriorityNames = {
    "Best Rarity",
    "Best Mutation",
    "Best Income (Mutation)",
}
State.cardPlacementPrioritySet = {}
for _, priority in ipairs(State.cardPlacementPriorityNames) do
    State.cardPlacementPrioritySet[priority] = true
end
State.cardPlacementPriorities = {
    ["Best Income (Mutation)"] = true,
}
State.cardPlacementRarityNames = table.clone(State.cardUpgradeRarityNames)
State.cardPlacementRarityRank = {}
for index, rarity in ipairs(State.cardPlacementRarityNames) do
    State.cardPlacementRarityRank[rarity] = index
end
State.cardPlacementMutationNames = {
    "Normal",
    "Gold",
    "Diamond",
    "Rainbow",
    "Galaxy",
    "Meteor",
}
State.cardPlacementMutationRank = {}
for index, mutation in ipairs(State.cardPlacementMutationNames) do
    State.cardPlacementMutationRank[mutation] = index
end
State.cardPlacementMutationIncomeMultipliers = {
    Normal = 1,
    Gold = 1.25,
    Diamond = 1.5,
    Rainbow = 2,
    Meteor = 2.5,
}
State.cardPlacementPriorityInitialized = false
State.cardPlacementPriorityPhase = "Mutation Adjusted Income"
State.cardPlacementPriorityRarity = nil
State.cardPlacementPriorityRarityRank = 0
State.cardPlacementPriorityMutation = nil
State.cardPlacementPriorityMutationRank = 0
State.cardPlacementTeleportOffset = 3
State.cardPlacementMoveDelay = 0.18
State.cardPlacementPollInterval = 0.45
State.cardPlacementCooldown = 0.55
State.cardPlacementRetryCooldown = 8
State.cardPlacementNextAt = 0
State.cardPlacementCursor = 0
State.cardPlacementPending = false
State.cardPlacementPendingSince = 0
State.cardPlacementPendingTimeout = 5
State.cardPlacementPendingKey = nil
State.cardPlacementPendingSlot = nil
State.cardPlacementPendingTool = nil
State.cardPlacementPendingName = nil
State.cardPlacementPendingIncome = 0
State.cardPlacementSkipUntil = {}
State.cardPlacementFailures = 0
State.cardPlacementPendingTriggerMode = nil
State.cardPlacementFallbackAttempted = false
State.cardPlacementFallbackDelay = 1
State.cardPlacementLastTriggerMode = "None"
State.cardPlacementLastPromptError = nil
State.cardPlacementLastStatus = "Idle"
State.autoPickupPlacedCards = false
State.cardPickupPollInterval = 0.45
State.cardPickupCooldown = 0.65
State.cardPickupRetryCooldown = 8
State.cardPickupNextAt = 0
State.cardPickupPending = false
State.cardPickupPendingSince = 0
State.cardPickupPendingTimeout = 5
State.cardPickupPendingKey = nil
State.cardPickupPendingSlot = nil
State.cardPickupPendingVisual = nil
State.cardPickupPendingName = nil
State.cardPickupPendingTriggerMode = nil
State.cardPickupFallbackAttempted = false
State.cardPickupFallbackDelay = 1
State.cardPickupSkipUntil = {}
State.cardPickupFailures = 0
State.cardPickupLastStatus = "Idle"
State.autoUpgradeSpeed = false
State.speedUpgradeTargetLevel = 50
State.speedUpgradePollInterval = 0.08
State.speedUpgradeCooldown = 0
State.speedUpgradeRetryCooldown = 10
State.speedUpgradeNextAt = 0
State.speedUpgradePending = false
State.speedUpgradePendingSince = 0
State.speedUpgradePendingTimeout = 2
State.speedUpgradeBeforeLevel = 0
State.speedUpgradeCurrent = nil
State.speedUpgradeCost = nil
State.speedUpgradeFailures = 0
State.speedUpgradeLastStatus = "Idle"
State.speedUpgradeLastRefreshAt = 0
State.autoSave = true
State.windowKeybind = "G"
State.antiAfk = true
State.antiAfkInterval = 45
State.antiAfkNextAt = 0
State.antiAfkLastMethods = {}
State.antiAfkLastErrors = {}
State.antiAfkLastStatus = "Idle"
State.hideUpgradeVisuals = true
State.hideCollectVisuals = true
State.visualOriginalProperties = setmetatable({}, {__mode = "k"})
State.visualHiddenCount = 0
State.visualLastStatus = "Ready"
State.logFilter = ""
State.logs = {}
State.logLastMessage = nil
State.logLastAt = 0
State.controls = {}
State.syncingControls = false
State.controlCallbacksReady = false
State.window = nil
State.logParagraph = nil
State.leaderstats = nil
State.powerValue = nil
State.rebirthsValue = nil
State.requestRebirth = nil
State.showTrainingPowerBonus = nil
State.claimTrainingPowerBonus = nil
State.requestWeightPurchase = nil
State.getUnlockedWeights = nil
State.updateWeightsUI = nil
State.resetWeightsUI = nil
State.getPlaytimeRewardState = nil
State.claimPlaytimeReward = nil
State.requestSpin = nil
State.requestSlotUpgrade = nil
State.purchaseUpgrade = nil
State.updateUpgradesUI = nil
State.plotCache = {}
State.plotCacheByKey = {}
State.plotCachePlot = nil
State.plotCacheDirty = true
State.plotCacheNextAt = 0
State.plotCacheRefreshInterval = 3
State.plotSchedulerInterval = 0.08
State.plotStartupGraceUntil = os.clock() + 5
State.plotFeatureCursor = 0
State.plotNextActionAt = 0
State.plotActionGap = 0.02
State.plotCacheGeneration = 0
State.plotCacheLastStatus = "Idle"
State.collectTouchCallback = nil
State.collectTouchCallbackResolved = false
State.cardPlacementPromptCallback = nil
State.cardPlacementPromptCallbackResolved = false
State.cardPlacementUnavailableLogged = false
State.configMigratedFrom = nil

local function resolvePath(root, path, timeout)
    local current = root
    for _, name in ipairs(path) do
        if not current then
            return nil
        end
        current = current:WaitForChild(name, timeout or 10)
    end
    return current
end

local function buildModules(root, definitions)
    local result = {}
    for name, path in pairs(definitions) do
        local moduleScript = resolvePath(root, path, 10)
        if moduleScript then
            local success, value = pcall(require, moduleScript)
            if success then
                result[name] = value
            end
        end
    end
    return result
end

local function buildRemotes(root, definitions)
    local result = {}
    for name, definition in pairs(definitions) do
        result[name] = resolvePath(root, definition.path or definition, definition.timeout or 10)
    end
    return result
end

ModuleDefinitions.WeightConfigurations = {
    "Modules",
    "WeightConfigurations",
}

ModuleDefinitions.PlaytimeRewardConfiguration = {
    "Modules",
    "PlaytimeRewardConfiguration",
}

ModuleDefinitions.DailySpinConfiguration = {
    "Modules",
    "DailySpinConfiguration",
}

ModuleDefinitions.ItemConfigurations = {
    "Modules",
    "ItemConfigurations",
}

ModuleDefinitions.NumberFormatter = {
    "Modules",
    "NumberFormatter",
}

ModuleDefinitions.LuckyBlockConfigurations = {
    "Modules",
    "LuckyBlockConfigurations",
}

ModuleDefinitions.RarityConfigurations = {
    "Modules",
    "RarityConfigurations",
}

ModuleDefinitions.MutationConfigurations = {
    "Modules",
    "MutationConfigurations",
}

ModuleDefinitions.KickConfigurations = {
    "Modules",
    "KickConfigurations",
}

RemoteDefinitions.RequestRebirth = {
    path = {"Events", "RequestRebirth"},
    timeout = 10,
}

RemoteDefinitions.ShowTrainingPowerBonus = {
    path = {"Events", "ShowTrainingPowerBonus"},
    timeout = 10,
}

RemoteDefinitions.ClaimTrainingPowerBonus = {
    path = {"Events", "ClaimTrainingPowerBonus"},
    timeout = 10,
}

RemoteDefinitions.RequestWeightPurchase = {
    path = {"Events", "RequestWeightPurchase"},
    timeout = 10,
}

RemoteDefinitions.GetUnlockedWeights = {
    path = {"Events", "GetUnlockedWeights"},
    timeout = 10,
}

RemoteDefinitions.UpdateWeightsUI = {
    path = {"Events", "UpdateWeightsUI"},
    timeout = 10,
}

RemoteDefinitions.ResetWeightsUI = {
    path = {"Events", "ResetWeightsUI"},
    timeout = 10,
}

RemoteDefinitions.GetPlaytimeRewardState = {
    path = {"Events", "GetPlaytimeRewardState"},
    timeout = 10,
}

RemoteDefinitions.ClaimPlaytimeReward = {
    path = {"Events", "ClaimPlaytimeReward"},
    timeout = 10,
}

RemoteDefinitions.RequestSpin = {
    path = {"Events", "RequestSpin"},
    timeout = 10,
}

RemoteDefinitions.RequestSlotUpgrade = {
    path = {"Events", "RequestSlotUpgrade"},
    timeout = 10,
}

RemoteDefinitions.PurchaseUpgrade = {
    path = {"Events", "PurchaseUpgrade"},
    timeout = 10,
}

RemoteDefinitions.UpdateUpgradesUI = {
    path = {"Events", "UpdateUpgradesUI"},
    timeout = 10,
}

Modules = buildModules(Services.ReplicatedStorage, ModuleDefinitions)
Remotes = buildRemotes(Services.ReplicatedStorage, RemoteDefinitions)
State.requestRebirth = Remotes.RequestRebirth
State.showTrainingPowerBonus = Remotes.ShowTrainingPowerBonus
State.claimTrainingPowerBonus = Remotes.ClaimTrainingPowerBonus
State.requestWeightPurchase = Remotes.RequestWeightPurchase
State.getUnlockedWeights = Remotes.GetUnlockedWeights
State.updateWeightsUI = Remotes.UpdateWeightsUI
State.resetWeightsUI = Remotes.ResetWeightsUI
State.getPlaytimeRewardState = Remotes.GetPlaytimeRewardState
State.claimPlaytimeReward = Remotes.ClaimPlaytimeReward
State.requestSpin = Remotes.RequestSpin
State.requestSlotUpgrade = Remotes.RequestSlotUpgrade
State.purchaseUpgrade = Remotes.PurchaseUpgrade
State.updateUpgradesUI = Remotes.UpdateUpgradesUI

local function formatCompactNumber(value)
    local number = tonumber(value) or 0
    local formatter = Modules.NumberFormatter
    if formatter and type(formatter.Format) == "function" then
        local success, formatted = pcall(formatter.Format, number)
        if success and formatted ~= nil and tostring(formatted) ~= "" then
            return tostring(formatted)
        end
    end
    local negative = number < 0
    local absolute = math.abs(number)
    if absolute < 1000 then
        local rounded = math.floor(absolute + 0.5)
        return (negative and "-" or "") .. tostring(rounded)
    end
    local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
    local index = math.min(#suffixes, math.floor(math.log(absolute) / math.log(1000)) + 1)
    local scaled = absolute / (1000 ^ (index - 1))
    local pattern
    if scaled >= 100 then
        pattern = "%.0f"
    elseif scaled >= 10 then
        pattern = "%.1f"
    else
        pattern = "%.2f"
    end
    local formatted = string.format(pattern, scaled):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    return (negative and "-" or "") .. formatted .. suffixes[index]
end

local LOG_ROUTINE_PATTERNS = {
    "waiting",
    "cooldown",
    "no rebirth available",
    "no training bonus available",
    "no selected weights",
    "all selected weights unlocked",
    "no playtime reward available",
    "playtime state refreshed",
    "no spin available",
    "spin state waiting",
    "collect processed without confirmation",
    "no empty slot available",
    "no eligible card upgrade",
    "speed target reached",
    "anti afk pulse",
    "config saved",
    "toggle enabled",
    "toggle disabled",
}

function LogRuntime.normalizeMessage(message)
    return tostring(message or ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
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

function LogRuntime.render()
    local paragraph = State.logParagraph
    if not paragraph then
        return
    end
    local filter = string.lower(LogRuntime.normalizeMessage(State.logFilter))
    local lines = {}
    for index = #State.logs, 1, -1 do
        local entry = State.logs[index]
        local searchable = string.lower(entry.level .. " " .. entry.message)
        if filter == "" or string.find(searchable, filter, 1, true) then
            table.insert(lines, 1, string.format("[%s] [%s] %s", entry.time, entry.level, entry.message))
            if #lines >= 40 then
                break
            end
        end
    end
    local text = #lines > 0 and table.concat(lines, "\n") or "No important events yet."
    pcall(function()
        paragraph:SetDesc(text)
    end)
end

function LogRuntime.add(level, message)
    message = LogRuntime.normalizeMessage(message)
    if message == "" or LogRuntime.isRoutineMessage(message) then
        return
    end
    local now = os.clock()
    if State.logLastMessage == message and now - State.logLastAt < 2 then
        return
    end
    State.logLastMessage = message
    State.logLastAt = now
    table.insert(State.logs, {
        time = os.date("%H:%M:%S"),
        level = tostring(level or "INFO"),
        message = message,
    })
    while #State.logs > 150 do
        table.remove(State.logs, 1)
    end
    LogRuntime.render()
end

function LogRuntime.clear()
    table.clear(State.logs)
    State.logLastMessage = nil
    State.logLastAt = 0
    LogRuntime.render()
end

local function normalizePollInterval(value)
    value = tonumber(value)
    if not value then
        return 0.35
    end
    return math.clamp(value, 0.1, 5)
end

local function normalizeTrainingTapDelay(value)
    if tostring(value) == "Instant" then
        return 0
    end
    local number = tonumber(tostring(value):match("[%d%.]+"))
    if not number then
        return 0.05
    end
    return math.clamp(number, 0, 1)
end

local function normalizeCollectCycleDelay(value)
    local number = tonumber(tostring(value):match("[%d%.]+"))
    if not number then
        return 0.1
    end
    return math.clamp(number, 0, 60)
end

local function normalizeRunSpeedMultiplier(value)
    local number = tonumber(tostring(value):match("[%d%.]+"))
    if not number then
        return 2
    end
    return math.clamp(number, 1, 10)
end

local function normalizeKickRewardThreshold(value)
    value = string.upper(tostring(value or "None"))
    if value == "AND" or value == "OR" then
        return value
    end
    return "None"
end

local function normalizeWindowKeybind(value)
    local allowed = {
        G = true,
        RightShift = true,
        LeftAlt = true,
        RightControl = true,
    }
    value = tostring(value or "G")
    return allowed[value] and value or "G"
end

local function normalizeLogFilter(value)
    return tostring(value or "")
end

local function normalizeTargetLevel(value)
    value = tonumber(value) or 0
    return math.max(0, math.floor(value))
end

BooleanSettingDefinitions = {
    {
        state = "autoRebirth",
        control = "autoRebirthToggle",
        stop = true,
    },
    {
        state = "autoWeightTraining",
        control = "autoWeightTrainingToggle",
        stop = true,
    },
    {
        state = "freeMovementWhileTraining",
        control = "freeMovementWhileTrainingToggle",
        stop = true,
    },
    {
        state = "autoTrainingWeight",
        control = "autoTrainingWeightToggle",
        stop = true,
    },
    {
        state = "hideTrainingBonusVisuals",
        control = "hideTrainingBonusVisualsToggle",
    },
    {
        state = "autoBuyWeights",
        control = "autoBuyWeightsToggle",
        stop = true,
    },
    {
        state = "autoBuyBestAffordableWeight",
        control = "autoBuyBestAffordableWeightToggle",
        stop = true,
    },
    {
        state = "autoClaimPlaytimeRewards",
        control = "autoClaimPlaytimeRewardsToggle",
        stop = true,
    },
    {
        state = "autoSpin",
        control = "autoSpinToggle",
        stop = true,
    },
    {
        state = "autoLandSecretChanceLowRisk",
        control = "autoLandSecretChanceLowRiskToggle",
        stop = true,
    },
    {
        state = "autoLandSecretChanceRisk",
        control = "autoLandSecretChanceRiskToggle",
        stop = true,
    },
    {
        state = "autoCollectMoney",
        control = "autoCollectMoneyToggle",
        stop = true,
    },
    {
        state = "autoUpgradePlacedCards",
        control = "autoUpgradePlacedCardsToggle",
        stop = true,
    },
    {
        state = "autoFillEmptySlots",
        control = "autoFillEmptySlotsToggle",
        stop = true,
    },
    {
        state = "autoPickupPlacedCards",
        control = "autoPickupPlacedCardsToggle",
        stop = true,
    },
    {
        state = "autoUpgradeSpeed",
        control = "autoUpgradeSpeedToggle",
        stop = true,
    },
    {
        state = "antiAfk",
        control = "antiAfkToggle",
        stop = true,
    },
    {
        state = "hideUpgradeVisuals",
        control = "hideUpgradeVisualsToggle",
    },
    {
        state = "hideCollectVisuals",
        control = "hideCollectVisualsToggle",
    },
    {
        state = "autoSave",
        control = "autoSaveToggle",
    },
}

ValueSettingDefinitions = {
    {
        state = "rebirthPollInterval",
        control = "rebirthPollIntervalDropdown",
        normalize = normalizePollInterval,
    },
    {
        state = "trainingTapDelay",
        control = "trainingTapDelayDropdown",
        normalize = normalizeTrainingTapDelay,
    },
    {
        state = "collectCycleDelay",
        control = "collectCycleDelayInput",
        normalize = normalizeCollectCycleDelay,
    },
    {
        state = "kickSecretRunSpeedMultiplier",
        control = "kickSecretRunSpeedMultiplierInput",
        normalize = normalizeRunSpeedMultiplier,
    },
    {
        state = "kickRewardFilterThreshold",
        control = "kickRewardFilterThresholdDropdown",
        normalize = normalizeKickRewardThreshold,
    },
    {
        state = "windowKeybind",
        control = "windowKeybindDropdown",
        normalize = normalizeWindowKeybind,
    },
    {
        state = "logFilter",
        control = "logFilterInput",
        normalize = normalizeLogFilter,
    },
    {
        state = "cardUpgradeTargetLevel",
        control = "cardUpgradeTargetLevelInput",
        normalize = normalizeTargetLevel,
    },
    {
        state = "speedUpgradeTargetLevel",
        control = "speedUpgradeTargetLevelInput",
        normalize = normalizeTargetLevel,
    },
}

MapSettingDefinitions = {
    {
        key = "kickRewardCardNameWhitelist",
        state = "kickRewardCardNameWhitelist",
        control = "kickRewardCardNameWhitelistDropdown",
        apply = function(source, target)
            KickRewardRuntime.applyWhitelist(source, target, State.kickRewardCardNameSet)
        end,
        toControl = function()
            return KickRewardRuntime.getCardNameWhitelist()
        end,
    },
    {
        key = "kickRewardRarityWhitelist",
        state = "kickRewardRarityWhitelist",
        control = "kickRewardRarityWhitelistDropdown",
        apply = function(source, target)
            KickRewardRuntime.applyWhitelist(source, target, State.kickRewardRaritySet)
        end,
        toControl = function()
            return KickRewardRuntime.getRarityWhitelist()
        end,
    },
    {
        key = "kickRewardMutationWhitelist",
        state = "kickRewardMutationWhitelist",
        control = "kickRewardMutationWhitelistDropdown",
        apply = function(source, target)
            KickRewardRuntime.applyWhitelist(source, target, State.kickRewardMutationSet)
        end,
        toControl = function()
            return KickRewardRuntime.getMutationWhitelist()
        end,
    },
    {
        key = "cardPlacementPriorities",
        state = "cardPlacementPriorities",
        control = "cardPlacementPriorityDropdown",
        apply = function(source, target)
            table.clear(target)
            if type(source) ~= "table" then
                target["Best Income (Mutation)"] = true
                return
            end
            for key, value in pairs(source) do
                local priority
                if type(key) == "number" and type(value) == "string" then
                    priority = value
                elseif type(key) == "string" and value == true then
                    priority = key
                end
                if priority == "Best Income (Base)" then
                    priority = "Best Income (Mutation)"
                end
                if priority and State.cardPlacementPrioritySet[priority] then
                    target[priority] = true
                end
            end
            if next(target) == nil then
                target["Best Income (Mutation)"] = true
            end
        end,
        toControl = function()
            return CardPlacementRuntime.getPriorities()
        end,
    },
    {
        key = "cardUpgradeRarityWhitelist",
        state = "cardUpgradeRarityWhitelist",
        control = "cardUpgradeRarityWhitelistDropdown",
        apply = function(source, target)
            table.clear(target)
            if type(source) ~= "table" then
                return
            end
            for key, value in pairs(source) do
                local rarity
                if type(key) == "number" and type(value) == "string" then
                    rarity = value
                elseif type(key) == "string" and value == true then
                    rarity = key
                end
                if rarity and State.cardUpgradeRaritySet[rarity] then
                    target[rarity] = true
                end
            end
        end,
        toControl = function()
            return CardUpgradeRuntime.getWhitelist()
        end,
    },
    {
        key = "weightBuyWhitelist",
        state = "weightBuyWhitelist",
        control = "weightBuyWhitelistDropdown",
        apply = function(source, target)
            table.clear(target)
            if type(source) ~= "table" then
                return
            end
            for key, value in pairs(source) do
                local name
                if type(key) == "number" and type(value) == "string" then
                    name = value
                elseif type(key) == "string" and value == true then
                    name = key
                end
                if name and State.weightNameSet[name] then
                    target[name] = true
                end
            end
        end,
        toControl = function()
            return WeightRuntime.getWhitelist()
        end,
    },
}

ConfigRuntime.rootFolder = "xSansHUB"
ConfigRuntime.gameFolder = ConfigRuntime.rootFolder .. "/" .. RuntimeName.configFolder
ConfigRuntime.path = ConfigRuntime.gameFolder .. "/" .. tostring(game.PlaceId) .. ".json"
ConfigRuntime.saveToken = 0

function ConfigRuntime.ensureFolders()
    if type(makefolder) ~= "function" then
        return false
    end
    pcall(makefolder, ConfigRuntime.rootFolder)
    pcall(makefolder, ConfigRuntime.gameFolder)
    return true
end

function ConfigRuntime.buildSnapshot()
    local snapshot = {
        version = ConfigRuntime.version,
        game = RuntimeName.game,
        placeId = game.PlaceId,
    }
    for _, definition in ipairs(BooleanSettingDefinitions) do
        snapshot[definition.key or definition.state] = State[definition.state] == true
    end
    for _, definition in ipairs(ValueSettingDefinitions) do
        snapshot[definition.key or definition.state] = State[definition.state]
    end
    for _, definition in ipairs(MapSettingDefinitions) do
        local source = State[definition.state]
        snapshot[definition.key or definition.state] = type(source) == "table" and table.clone(source) or {}
    end
    return snapshot
end

function ConfigRuntime.save(force)
    if not force and not State.autoSave then
        return false
    end
    if type(writefile) ~= "function" then
        LogRuntime.add("ERROR", "Config write is unavailable in this executor")
        return false
    end
    ConfigRuntime.ensureFolders()
    local encodedSuccess, encoded = pcall(Services.HttpService.JSONEncode, Services.HttpService, ConfigRuntime.buildSnapshot())
    if not encodedSuccess then
        LogRuntime.add("ERROR", "Config encoding failed: " .. tostring(encoded))
        return false
    end
    local writeSuccess, writeError = pcall(writefile, ConfigRuntime.path, encoded)
    if not writeSuccess then
        LogRuntime.add("ERROR", "Config save failed: " .. tostring(writeError))
        return false
    end
    return true
end

function ConfigRuntime.queueSave()
    if not State.autoSave then
        return
    end
    ConfigRuntime.saveToken = ConfigRuntime.saveToken + 1
    local token = ConfigRuntime.saveToken
    task.delay(0.4, function()
        if State.running and token == ConfigRuntime.saveToken then
            ConfigRuntime.save(false)
        end
    end)
end

function ConfigRuntime.apply(data)
    if type(data) ~= "table" then
        return false
    end
    local sourceVersion = math.max(0, math.floor(tonumber(data.version) or 0))
    State.configMigratedFrom = nil
    for _, definition in ipairs(BooleanSettingDefinitions) do
        local value = data[definition.key or definition.state]
        if type(value) == "boolean" then
            State[definition.state] = value
        end
    end
    for _, definition in ipairs(ValueSettingDefinitions) do
        local value = data[definition.key or definition.state]
        if value ~= nil then
            State[definition.state] = definition.normalize and definition.normalize(value) or value
        end
    end
    for _, definition in ipairs(MapSettingDefinitions) do
        local source = data[definition.key or definition.state]
        if type(source) == "table" then
            if definition.apply then
                definition.apply(source, State[definition.state])
            else
                State[definition.state] = table.clone(source)
            end
        end
    end
    State.rebirthPending = false
    State.rebirthPendingSince = 0
    State.rebirthNextAt = 0
    State.rebirthLastSignature = nil
    State.trainingPending = false
    State.trainingPendingSince = 0
    State.trainingNextAt = 0
    State.trainingToken = nil
    State.trainingExpiresAt = 0
    State.trainingAttempts = 0
    State.weightTrainingNextAt = 0
    State.weightTrainingLastActivateAt = 0
    State.weightTrainingLastPower = State.powerValue and tonumber(State.powerValue.Value) or 0
    State.weightTrainingLastPowerAt = 0
    State.weightTrainingActivationCount = 0
    State.weightTrainingFailures = 0
    State.weightTrainingTool = nil
    State.weightTrainingToolName = nil
    State.weightTrainingManagedEquip = false
    State.weightTrainingLastStatus = State.autoWeightTraining and "Ready" or "Disabled"
    State.weightPending = false
    State.weightPendingSince = 0
    State.weightPendingName = nil
    State.weightPendingAction = nil
    State.weightNextAt = 0
    State.weightFailures = 0
    State.weightCursor = 0
    State.weightCurrencyName = nil
    State.weightCurrencySource = nil
    State.weightCurrencyValue = 0
    State.weightBestAffordableTarget = nil
    State.weightBestOwnedName = nil
    State.weightBestOwnedPower = 0
    State.weightBestOwnedPrice = 0
    State.playtimePending = false
    State.playtimePendingId = nil
    State.playtimeNextAt = 0
    State.playtimeFailures = 0
    State.playtimeState = nil
    State.playtimeLastRefreshAt = 0
    State.spinPending = false
    State.spinNextAt = 0
    State.spinFailures = 0
    State.spinAwaitingState = false
    State.spinAwaitingSince = 0
    State.spinBeforeSignature = nil
    if sourceVersion < ConfigRuntime.version then
        State.configMigratedFrom = sourceVersion
    end
    if sourceVersion < 8 then
        State.autoCollectMoney = false
        State.autoUpgradePlacedCards = false
        State.autoFillEmptySlots = false
        State.autoUpgradeSpeed = false
    end
    if sourceVersion < 18 then
        State.autoWeightTraining = false
        State.freeMovementWhileTraining = false
    end
    if sourceVersion < 25 then
        State.autoBuyBestAffordableWeight = false
    end
    if sourceVersion < 28 then
        State.kickRewardFilterThreshold = "None"
        table.clear(State.kickRewardCardNameWhitelist)
        State.kickRewardCardNameWhitelist.None = true
        table.clear(State.kickRewardRarityWhitelist)
        State.kickRewardRarityWhitelist.None = true
        table.clear(State.kickRewardMutationWhitelist)
        State.kickRewardMutationWhitelist.None = true
    end
    if sourceVersion < 29 then
        if State.cardPlacementPriorities["Best Income (Base)"] == true then
            State.cardPlacementPriorities["Best Income (Base)"] = nil
            State.cardPlacementPriorities["Best Income (Mutation)"] = true
        end
        if next(State.cardPlacementPriorities) == nil then
            State.cardPlacementPriorities["Best Income (Mutation)"] = true
        end
    end
    if sourceVersion < 24 then
        local legacyVisualSetting = data.hideUpgradeCollectVisuals
        if type(data.hideUpgradeVisuals) ~= "boolean" then
            State.hideUpgradeVisuals = type(legacyVisualSetting) == "boolean" and legacyVisualSetting or true
        end
        if type(data.hideCollectVisuals) ~= "boolean" then
            State.hideCollectVisuals = type(legacyVisualSetting) == "boolean" and legacyVisualSetting or true
        end
        State.kickSecretRunSpeedMultiplier = normalizeRunSpeedMultiplier(data.kickSecretRunSpeedMultiplier)
    end
    if sourceVersion < 16 then
        State.autoLandSecretChance = false
        State.autoLandSecretChanceLowRisk = false
        State.autoLandSecretChanceRisk = false
        State.autoPickupPlacedCards = false
    end
    if State.autoLandSecretChanceRisk then
        State.autoLandSecretChanceLowRisk = false
        State.autoLandSecretChance = true
        State.kickSecretHardCorrectionEnabled = true
        State.kickSecretRiskLevel = "RISK"
    elseif State.autoLandSecretChanceLowRisk then
        State.autoLandSecretChance = true
        State.kickSecretHardCorrectionEnabled = false
        State.kickSecretRiskLevel = "LOW RISK"
    else
        State.autoLandSecretChance = false
        State.kickSecretHardCorrectionEnabled = false
        State.kickSecretRiskLevel = "OFF"
    end
    if sourceVersion < 13 then
        table.clear(State.cardPlacementPriorities)
        local oldMode = tostring(data.cardPlacementFilterMode or "")
        if oldMode == "Rarity" then
            State.cardPlacementPriorities["Best Rarity"] = true
        elseif oldMode == "Mutation" then
            State.cardPlacementPriorities["Best Mutation"] = true
        elseif oldMode == "Base Income + Mutation" then
            State.cardPlacementPriorities["Best Mutation"] = true
            State.cardPlacementPriorities["Best Income (Mutation)"] = true
        else
            State.cardPlacementPriorities["Best Income (Mutation)"] = true
        end
    end
    CollectRuntime.resetLifecycle(State.autoCollectMoney and "Ready" or "Disabled")
    CardUpgradeRuntime.resetLifecycle(State.autoUpgradePlacedCards and "Ready" or "Disabled")
    CardPlacementRuntime.resetLifecycle(State.autoFillEmptySlots and "Ready" or "Disabled")
    CardPickupRuntime.resetLifecycle(State.autoPickupPlacedCards and "Ready" or "Disabled")
    SpeedUpgradeRuntime.resetLifecycle(State.autoUpgradeSpeed and "Ready" or "Disabled")
    State.plotStartupGraceUntil = os.clock() + 3
    State.plotNextActionAt = 0
    PlotRuntime.invalidate("Config Applied")
    return true
end

function ConfigRuntime.load()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return false
    end
    local existsSuccess, exists = pcall(isfile, ConfigRuntime.path)
    if not existsSuccess or not exists then
        return false
    end
    local readSuccess, content = pcall(readfile, ConfigRuntime.path)
    if not readSuccess then
        LogRuntime.add("ERROR", "Config read failed: " .. tostring(content))
        return false
    end
    local decodeSuccess, data = pcall(Services.HttpService.JSONDecode, Services.HttpService, content)
    if not decodeSuccess then
        LogRuntime.add("ERROR", "Config decode failed: " .. tostring(data))
        return false
    end
    return ConfigRuntime.apply(data)
end

local function getControlValue(definition)
    local value = State[definition.state]
    if definition.state == "rebirthPollInterval" then
        return string.format("%.2f seconds", value)
    end
    if definition.state == "trainingTapDelay" then
        return value <= 0 and "Instant" or string.format("%.2f seconds", value)
    end
    if definition.state == "cardUpgradeTargetLevel" or definition.state == "speedUpgradeTargetLevel" then
        return tostring(normalizeTargetLevel(value))
    end
    if definition.state == "collectCycleDelay" then
        return tostring(normalizeCollectCycleDelay(value))
    end
    if definition.state == "kickSecretRunSpeedMultiplier" then
        return tostring(normalizeRunSpeedMultiplier(value))
    end
    if definition.state == "kickRewardFilterThreshold" then
        return normalizeKickRewardThreshold(value)
    end
    return value
end

function ConfigRuntime.syncControls()
    if State.syncingControls or not State.controlCallbacksReady then
        return false
    end
    State.syncingControls = true
    local success, errorMessage = pcall(function()
        for _, definition in ipairs(BooleanSettingDefinitions) do
            local control = State.controls[definition.control]
            if control then
                pcall(function()
                    control:Set(State[definition.state] == true, false)
                end)
            end
        end
        for _, definition in ipairs(ValueSettingDefinitions) do
            local control = State.controls[definition.control]
            if control then
                pcall(function()
                    control:Set(getControlValue(definition), false)
                end)
            end
        end
        for _, definition in ipairs(MapSettingDefinitions) do
            local control = State.controls[definition.control]
            if control then
                local value = definition.toControl and definition.toControl(State[definition.state]) or State[definition.state]
                pcall(function()
                    control:Set(value, false)
                end)
            end
        end
    end)
    State.syncingControls = false
    if not success then
        LogRuntime.add("ERROR", "Control synchronization failed: " .. tostring(errorMessage))
    end
    return success
end

ConnectionRuntime.fields = {
    "rebirthChangedConnection",
    "powerChangedConnection",
    "trainingBonusConnection",
    "weightUpdateConnection",
    "weightResetConnection",
    "spinNumberConnection",
    "spinLastDailyConnection",
    "speedUpgradeUpdateConnection",
    "kickSecretPowerBarSizeConnection",
    "kickSecretAutoRunConnection",
    "antiAfkIdledConnection",
    "antiAfkHeartbeatConnection",
    "visualPlayerGuiAddedConnection",
    "visualWorkspaceAddedConnection",
    "kickRewardActivityConnection",
    "kickRewardBackpackConnection",
    "kickRewardCharacterAddedConnection",
    "kickRewardCharacterToolConnection",
}

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

function SchedulerRuntime.spawn(interval, callback)
    task.spawn(function()
        while State.running do
            local success, errorMessage = pcall(callback)
            if not success then
                LogRuntime.add("ERROR", "Scheduler failure: " .. tostring(errorMessage))
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

function RebirthRuntime.getCost()
    local rebirths = State.rebirthsValue
    local count = rebirths and tonumber(rebirths.Value) or 0
    return 1000 * 2 ^ math.max(0, count)
end

function RebirthRuntime.getPower()
    return State.powerValue and tonumber(State.powerValue.Value) or 0
end

function RebirthRuntime.resetLifecycle(status)
    State.rebirthPending = false
    State.rebirthPendingSince = 0
    State.rebirthBeforeCount = 0
    State.rebirthBeforePower = 0
    State.rebirthNextAt = 0
    State.rebirthLastSignature = nil
    State.rebirthLastStatus = status or "Idle"
end

function RebirthRuntime.setAuto(enabled, save)
    State.autoRebirth = enabled == true
    RebirthRuntime.resetLifecycle(State.autoRebirth and "Ready" or "Disabled")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function RebirthRuntime.confirm(currentCount)
    if not State.rebirthPending then
        return
    end
    if currentCount <= State.rebirthBeforeCount then
        return
    end
    local previous = State.rebirthBeforeCount
    State.rebirthPending = false
    State.rebirthPendingSince = 0
    State.rebirthFailures = 0
    State.rebirthNextAt = os.clock() + State.rebirthCooldown
    State.rebirthLastSignature = nil
    State.rebirthLastStatus = "Confirmed"
    LogRuntime.add("SUCCESS", string.format("Rebirth confirmed: %d -> %d", previous, currentCount))
end

function RebirthRuntime.process()
    if not State.autoRebirth or State.rebirthPending then
        return false
    end
    local remote = State.requestRebirth
    local rebirths = State.rebirthsValue
    if not remote or not rebirths or not State.powerValue then
        return false
    end
    local now = os.clock()
    if now < State.rebirthNextAt then
        return false
    end
    local count = tonumber(rebirths.Value) or 0
    local power = RebirthRuntime.getPower()
    local cost = RebirthRuntime.getCost()
    if power < cost then
        State.rebirthLastStatus = "Insufficient Power"
        return false
    end
    local signature = tostring(count) .. ":" .. tostring(power)
    if State.rebirthLastSignature == signature then
        return false
    end
    State.rebirthBeforeCount = count
    State.rebirthBeforePower = power
    State.rebirthPending = true
    State.rebirthPendingSince = now
    State.rebirthLastSignature = signature
    State.rebirthLastStatus = "Request Pending"
    local success, errorMessage = pcall(function()
        remote:FireServer()
    end)
    if not success then
        State.rebirthPending = false
        State.rebirthPendingSince = 0
        State.rebirthFailures = State.rebirthFailures + 1
        State.rebirthNextAt = now + math.min(5, 1 + State.rebirthFailures)
        State.rebirthLastSignature = nil
        State.rebirthLastStatus = "Request Failed"
        LogRuntime.add("ERROR", "Rebirth request failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function RebirthRuntime.tick()
    if not State.autoRebirth then
        return
    end
    local now = os.clock()
    if State.rebirthPending then
        if now - State.rebirthPendingSince >= State.rebirthPendingTimeout then
            State.rebirthPending = false
            State.rebirthPendingSince = 0
            State.rebirthFailures = State.rebirthFailures + 1
            State.rebirthNextAt = now + math.min(6, 1.5 + State.rebirthFailures)
            State.rebirthLastSignature = nil
            State.rebirthLastStatus = "Confirmation Timeout"
            LogRuntime.add("ERROR", "Rebirth confirmation timed out")
        end
        return
    end
    RebirthRuntime.process()
end

function RebirthRuntime.bind()
    local player = Services.Players.LocalPlayer
    local leaderstats = player:WaitForChild("leaderstats", 10)
    if not leaderstats then
        LogRuntime.add("ERROR", "leaderstats was not found")
        return false
    end
    local power = leaderstats:WaitForChild("Power", 10)
    local rebirths = leaderstats:WaitForChild("Rebirths", 10)
    if not power or not rebirths then
        LogRuntime.add("ERROR", "Power or Rebirths leaderstat was not found")
        return false
    end
    State.leaderstats = leaderstats
    State.powerValue = power
    State.rebirthsValue = rebirths
    ConnectionRuntime.disconnect("rebirthChangedConnection")
    ConnectionRuntime.disconnect("powerChangedConnection")
    State.rebirthChangedConnection = rebirths.Changed:Connect(function(value)
        RebirthRuntime.confirm(tonumber(value) or tonumber(rebirths.Value) or 0)
    end)
    State.powerChangedConnection = power.Changed:Connect(function(value)
        if State.autoRebirth and not State.rebirthPending then
            State.rebirthLastSignature = nil
        end
        local currentPower = tonumber(value) or tonumber(power.Value) or 0
        TrainingRuntime.confirm(currentPower)
        WeightTrainingRuntime.onPowerChanged(currentPower)
    end)
    return true
end

function RebirthRuntime.getState()
    return {
        enabled = State.autoRebirth,
        cost = RebirthRuntime.getCost(),
        power = RebirthRuntime.getPower(),
        rebirths = State.rebirthsValue and State.rebirthsValue.Value or 0,
        pending = State.rebirthPending,
        pendingSince = State.rebirthPendingSince,
        failures = State.rebirthFailures,
        lastStatus = State.rebirthLastStatus,
        pollInterval = State.rebirthPollInterval,
    }
end

function TrainingRuntime.getConnectionGetter()
    local environment = type(getgenv) == "function" and getgenv() or _G
    local names = {
        "getconnections",
        "get_signal_cons",
        "getsignalconnections",
    }
    for _, name in ipairs(names) do
        local callback = environment and rawget(environment, name) or nil
        if type(callback) == "function" then
            return callback
        end
    end
    return nil
end

function TrainingRuntime.captureNativeConnections()
    table.clear(State.trainingNativeConnections)
    local remote = State.showTrainingPowerBonus
    local getter = TrainingRuntime.getConnectionGetter()
    if not remote or not getter then
        return false
    end
    local success, connections = pcall(getter, remote.OnClientEvent)
    if not success or type(connections) ~= "table" then
        return false
    end
    for _, connection in ipairs(connections) do
        local disableMethod
        local enableMethod
        local readable = pcall(function()
            disableMethod = connection and connection.Disable or nil
            enableMethod = connection and connection.Enable or nil
        end)
        if readable and type(disableMethod) == "function" and type(enableMethod) == "function" then
            State.trainingNativeConnections[#State.trainingNativeConnections + 1] = connection
        end
    end
    return #State.trainingNativeConnections > 0
end

function TrainingRuntime.setNativeSuppressed(suppressed)
    suppressed = suppressed == true and State.autoTrainingWeight and State.hideTrainingBonusVisuals
    if State.trainingNativeSuppressed == suppressed then
        return
    end
    local applied = 0
    for _, connection in ipairs(State.trainingNativeConnections) do
        local success = pcall(function()
            if suppressed then
                connection:Disable()
            else
                connection:Enable()
            end
        end)
        if success then
            applied = applied + 1
        end
    end
    State.trainingNativeSuppressed = suppressed and applied > 0
end

function TrainingRuntime.clearToken(status)
    State.trainingToken = nil
    State.trainingDuration = 0
    State.trainingExpiresAt = 0
    State.trainingReward = 0
    State.trainingQueuedAt = 0
    State.trainingPending = false
    State.trainingPendingSince = 0
    State.trainingBeforePower = 0
    State.trainingAttempts = 0
    State.trainingNextAt = 0
    State.trainingLastStatus = status or "Idle"
end

function TrainingRuntime.setAuto(enabled, save)
    State.autoTrainingWeight = enabled == true
    State.trainingFailures = 0
    TrainingRuntime.clearToken(State.autoTrainingWeight and "Ready" or "Disabled")
    TrainingRuntime.setNativeSuppressed(State.autoTrainingWeight)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function TrainingRuntime.setHideVisuals(enabled, save)
    State.hideTrainingBonusVisuals = enabled == true
    TrainingRuntime.setNativeSuppressed(State.autoTrainingWeight)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function TrainingRuntime.onBonus(token, duration, reward)
    if typeof(token) ~= "string" or not State.autoTrainingWeight then
        return
    end
    local now = os.clock()
    duration = math.max(0.4, tonumber(duration) or 3)
    State.trainingToken = token
    State.trainingDuration = duration
    State.trainingExpiresAt = now + duration
    State.trainingReward = math.max(0, tonumber(reward) or 0)
    State.trainingQueuedAt = now + State.trainingTapDelay
    State.trainingPending = false
    State.trainingPendingSince = 0
    State.trainingBeforePower = 0
    State.trainingAttempts = 0
    State.trainingNextAt = 0
    State.trainingLastStatus = "Bonus Available"
    TrainingRuntime.setNativeSuppressed(true)
    task.defer(TrainingRuntime.process)
end

function TrainingRuntime.confirm(currentPower)
    if not State.trainingPending then
        return
    end
    currentPower = tonumber(currentPower) or 0
    local delta = currentPower - State.trainingBeforePower
    local requiredDelta = State.trainingReward > 0 and State.trainingReward or 1
    if delta < requiredDelta then
        return
    end
    local reward = State.trainingReward
    State.trainingFailures = 0
    TrainingRuntime.clearToken("Confirmed")
    LogRuntime.add("SUCCESS", "Training weight bonus claimed: +" .. string.format("%g", reward))
end

function TrainingRuntime.process()
    if not State.autoTrainingWeight or State.trainingPending then
        return false
    end
    local token = State.trainingToken
    local remote = State.claimTrainingPowerBonus
    if not token or not remote then
        return false
    end
    local now = os.clock()
    if now >= State.trainingExpiresAt then
        TrainingRuntime.clearToken("Expired")
        return false
    end
    if now < State.trainingQueuedAt or now < State.trainingNextAt then
        return false
    end
    State.trainingPending = true
    State.trainingPendingSince = now
    State.trainingBeforePower = State.powerValue and tonumber(State.powerValue.Value) or 0
    State.trainingAttempts = State.trainingAttempts + 1
    State.trainingLastStatus = "Claim Pending"
    local success, errorMessage = pcall(function()
        remote:FireServer(token)
    end)
    if not success then
        State.trainingPending = false
        State.trainingPendingSince = 0
        State.trainingFailures = State.trainingFailures + 1
        State.trainingNextAt = now + math.min(2, 0.25 + State.trainingFailures * 0.25)
        State.trainingLastStatus = "Claim Failed"
        LogRuntime.add("ERROR", "Training bonus claim failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function TrainingRuntime.tick()
    if not State.autoTrainingWeight then
        return
    end
    local token = State.trainingToken
    if not token then
        return
    end
    local now = os.clock()
    if now >= State.trainingExpiresAt then
        local wasPending = State.trainingPending
        TrainingRuntime.clearToken(wasPending and "Confirmation Timeout" or "Expired")
        if wasPending then
            State.trainingFailures = State.trainingFailures + 1
            LogRuntime.add("ERROR", "Training bonus expired before confirmation")
        end
        return
    end
    if State.trainingPending then
        if now - State.trainingPendingSince >= State.trainingPendingTimeout then
            State.trainingPending = false
            State.trainingPendingSince = 0
            State.trainingFailures = State.trainingFailures + 1
            if State.trainingAttempts < 2 and now + State.trainingCooldown < State.trainingExpiresAt then
                State.trainingNextAt = now + State.trainingCooldown
                State.trainingLastStatus = "Retry Scheduled"
            else
                TrainingRuntime.clearToken("Confirmation Timeout")
                LogRuntime.add("ERROR", "Training bonus confirmation timed out")
            end
        end
        return
    end
    TrainingRuntime.process()
end

function TrainingRuntime.bind()
    local remote = State.showTrainingPowerBonus
    if not remote then
        return false
    end
    TrainingRuntime.captureNativeConnections()
    ConnectionRuntime.disconnect("trainingBonusConnection")
    State.trainingBonusConnection = remote.OnClientEvent:Connect(function(token, duration, reward)
        TrainingRuntime.onBonus(token, duration, reward)
    end)
    return true
end

function TrainingRuntime.getState()
    return {
        enabled = State.autoTrainingWeight,
        hideNativeVisuals = State.hideTrainingBonusVisuals,
        tokenAvailable = State.trainingToken ~= nil,
        pending = State.trainingPending,
        pendingSince = State.trainingPendingSince,
        expiresAt = State.trainingExpiresAt,
        reward = State.trainingReward,
        attempts = State.trainingAttempts,
        failures = State.trainingFailures,
        lastStatus = State.trainingLastStatus,
        tapDelay = State.trainingTapDelay,
        eventConnected = State.trainingBonusConnection ~= nil,
        nativeConnectionsCaptured = #State.trainingNativeConnections,
        nativeVisualsSuppressed = State.trainingNativeSuppressed,
    }
end


function WeightTrainingRuntime.getCharacterState()
    local player = Services.Players.LocalPlayer
    local character = player.Character
    if not character then
        return nil, nil, nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or not root:IsA("BasePart") then
        return character, humanoid, nil
    end
    return character, humanoid, root
end

function WeightTrainingRuntime.isWeightTool(tool)
    return tool and tool:IsA("Tool") and tool:GetAttribute("IsWeight") == true
end

function WeightTrainingRuntime.getToolPower(tool)
    if not WeightTrainingRuntime.isWeightTool(tool) then
        return -1
    end
    local data = State.weightData[tool.Name]
    if type(data) == "table" then
        local configured = tonumber(data.Power)
        if configured then
            return configured
        end
    end
    local attributes = {
        "Power",
        "PowerPerSecond",
        "TrainingPower",
    }
    for _, attribute in ipairs(attributes) do
        local value = tonumber(tool:GetAttribute(attribute))
        if value then
            return value
        end
    end
    return 0
end

function WeightTrainingRuntime.getEquippedWeight(character)
    if not character then
        return nil
    end
    for _, child in ipairs(character:GetChildren()) do
        if WeightTrainingRuntime.isWeightTool(child) then
            return child
        end
    end
    return nil
end

function WeightTrainingRuntime.findBestWeight(character)
    local player = Services.Players.LocalPlayer
    local backpack = player:FindFirstChildOfClass("Backpack")
    local equipped = WeightTrainingRuntime.getEquippedWeight(character)
    local best = nil
    local bestPower = -1
    local function consider(tool)
        if not WeightTrainingRuntime.isWeightTool(tool) then
            return
        end
        local power = WeightTrainingRuntime.getToolPower(tool)
        if not best or power > bestPower or power == bestPower and tool == equipped then
            best = tool
            bestPower = power
        end
    end
    if character then
        for _, child in ipairs(character:GetChildren()) do
            consider(child)
        end
    end
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            consider(child)
        end
    end
    return best, bestPower
end

function WeightTrainingRuntime.findWeightToolByName(name)
    if type(name) ~= "string" then
        return nil
    end
    local player = Services.Players.LocalPlayer
    local character = player.Character
    if character then
        local tool = character:FindFirstChild(name)
        if WeightTrainingRuntime.isWeightTool(tool) then
            return tool
        end
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(name)
        if WeightTrainingRuntime.isWeightTool(tool) then
            return tool
        end
    end
    return nil
end

function WeightTrainingRuntime.equipWeightTool(name)
    local player = Services.Players.LocalPlayer
    if player:GetAttribute("LuckyBlockActivityActive") == true or State.cardPlacementPending or State.cardPickupPending then
        return false, "Busy"
    end
    local character, humanoid, root = WeightTrainingRuntime.getCharacterState()
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return false, "Character Unavailable"
    end
    local tool = name and WeightTrainingRuntime.findWeightToolByName(name) or nil
    if not tool then
        tool = WeightTrainingRuntime.findBestWeight(character)
    end
    if not tool then
        return false, "Weight Tool Unavailable"
    end
    local equipped = WeightTrainingRuntime.getEquippedWeight(character)
    if equipped == tool and tool.Parent == character then
        State.weightTrainingTool = tool
        State.weightTrainingToolName = tool.Name
        return true, tool.Name
    end
    WeightTrainingRuntime.captureMovement(humanoid, root)
    local success, errorMessage = pcall(function()
        humanoid:EquipTool(tool)
    end)
    if not success then
        return false, tostring(errorMessage)
    end
    State.weightTrainingManagedEquip = true
    State.weightTrainingTool = tool
    State.weightTrainingToolName = tool.Name
    State.weightTrainingLastActivateAt = 0
    State.weightTrainingNextAt = os.clock() + 0.1
    State.weightTrainingLastStatus = "Equipping " .. tool.Name
    return true, tool.Name
end

function WeightTrainingRuntime.captureMovement(humanoid, root)
    if not humanoid or not root then
        return
    end
    if State.weightTrainingHumanoid ~= humanoid or State.weightTrainingRoot ~= root then
        State.weightTrainingHumanoid = humanoid
        State.weightTrainingRoot = root
        State.weightTrainingControls = nil
        State.weightTrainingControlsResolved = false
    end
    local walkSpeed = tonumber(humanoid.WalkSpeed) or 0
    if walkSpeed > 0.1 then
        State.weightTrainingBaseWalkSpeed = walkSpeed
    elseif not State.weightTrainingBaseWalkSpeed or State.weightTrainingBaseWalkSpeed <= 0.1 then
        State.weightTrainingBaseWalkSpeed = 16
    end
    if humanoid.UseJumpPower then
        local jumpPower = tonumber(humanoid.JumpPower) or 0
        if jumpPower > 0.1 then
            State.weightTrainingBaseJumpPower = jumpPower
        elseif not State.weightTrainingBaseJumpPower or State.weightTrainingBaseJumpPower <= 0.1 then
            State.weightTrainingBaseJumpPower = 50
        end
    else
        local jumpHeight = tonumber(humanoid.JumpHeight) or 0
        if jumpHeight > 0.1 then
            State.weightTrainingBaseJumpHeight = jumpHeight
        elseif not State.weightTrainingBaseJumpHeight or State.weightTrainingBaseJumpHeight <= 0.1 then
            State.weightTrainingBaseJumpHeight = 7.2
        end
    end
    if humanoid.AutoRotate then
        State.weightTrainingBaseAutoRotate = true
    end
end

function WeightTrainingRuntime.resolveControls()
    if State.weightTrainingControlsResolved then
        return State.weightTrainingControls
    end
    State.weightTrainingControlsResolved = true
    local player = Services.Players.LocalPlayer
    local playerScripts = player:FindFirstChild("PlayerScripts")
    local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule") or nil
    if not playerModule then
        return nil
    end
    local success, controls = pcall(function()
        local module = require(playerModule)
        if type(module) ~= "table" or type(module.GetControls) ~= "function" then
            return nil
        end
        return module:GetControls()
    end)
    if success then
        State.weightTrainingControls = controls
    end
    return State.weightTrainingControls
end

function WeightTrainingRuntime.enforceFreeMovement(character, humanoid, root)
    if not State.freeMovementWhileTraining then
        return false
    end
    if Services.Players.LocalPlayer:GetAttribute("LuckyBlockActivityActive") == true then
        State.weightTrainingLastStatus = "Movement Paused During Kick Activity"
        return false
    end
    local equipped = WeightTrainingRuntime.getEquippedWeight(character)
    if not equipped then
        WeightTrainingRuntime.captureMovement(humanoid, root)
        return false
    end
    if humanoid.Health <= 0 then
        return false
    end
    if root.Anchored then
        pcall(function()
            root.Anchored = false
        end)
    end
    if humanoid.PlatformStand then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    if not humanoid.AutoRotate then
        pcall(function()
            humanoid.AutoRotate = State.weightTrainingBaseAutoRotate ~= false
        end)
    end
    if tonumber(humanoid.WalkSpeed) and humanoid.WalkSpeed <= 0.1 then
        pcall(function()
            humanoid.WalkSpeed = math.max(1, tonumber(State.weightTrainingBaseWalkSpeed) or 16)
        end)
    end
    if humanoid.UseJumpPower then
        if tonumber(humanoid.JumpPower) and humanoid.JumpPower <= 0.1 then
            pcall(function()
                humanoid.JumpPower = math.max(1, tonumber(State.weightTrainingBaseJumpPower) or 50)
            end)
        end
    elseif tonumber(humanoid.JumpHeight) and humanoid.JumpHeight <= 0.1 then
        pcall(function()
            humanoid.JumpHeight = math.max(1, tonumber(State.weightTrainingBaseJumpHeight) or 7.2)
        end)
    end
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end)
    local controls = WeightTrainingRuntime.resolveControls()
    if controls then
        pcall(function()
            controls:Enable()
        end)
    end
    State.weightTrainingLastStatus = State.autoWeightTraining and "Training with Free Movement" or "Free Movement Active"
    return true
end

function WeightTrainingRuntime.stopManagedTool()
    local tool = State.weightTrainingTool
    if tool and tool.Parent then
        pcall(function()
            tool:Deactivate()
        end)
    end
    local character, humanoid = WeightTrainingRuntime.getCharacterState()
    if State.weightTrainingManagedEquip and humanoid and tool and tool.Parent == character then
        pcall(function()
            humanoid:UnequipTools()
        end)
    end
    State.weightTrainingTool = nil
    State.weightTrainingToolName = nil
    State.weightTrainingManagedEquip = false
end

function WeightTrainingRuntime.resetLifecycle(status, stopTool)
    if stopTool then
        WeightTrainingRuntime.stopManagedTool()
    end
    State.weightTrainingNextAt = 0
    State.weightTrainingLastActivateAt = 0
    State.weightTrainingActivationCount = 0
    State.weightTrainingFailures = 0
    State.weightTrainingLastPower = State.powerValue and tonumber(State.powerValue.Value) or 0
    State.weightTrainingLastPowerAt = 0
    State.weightTrainingLastStatus = status or "Idle"
end

function WeightTrainingRuntime.setAuto(enabled, save)
    State.autoWeightTraining = enabled == true
    WeightTrainingRuntime.resetLifecycle(State.autoWeightTraining and "Ready" or "Disabled", not State.autoWeightTraining)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function WeightTrainingRuntime.setFreeMovement(enabled, save)
    State.freeMovementWhileTraining = enabled == true
    State.weightTrainingControls = nil
    State.weightTrainingControlsResolved = false
    if State.freeMovementWhileTraining then
        local _, humanoid, root = WeightTrainingRuntime.getCharacterState()
        WeightTrainingRuntime.captureMovement(humanoid, root)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function WeightTrainingRuntime.onPowerChanged(currentPower)
    if not State.autoWeightTraining then
        return
    end
    local character = Services.Players.LocalPlayer.Character
    if not WeightTrainingRuntime.getEquippedWeight(character) then
        return
    end
    currentPower = tonumber(currentPower) or 0
    if currentPower > State.weightTrainingLastPower then
        State.weightTrainingLastPowerAt = os.clock()
        State.weightTrainingLastStatus = State.freeMovementWhileTraining and "Training with Free Movement" or "Training Active"
    end
    State.weightTrainingLastPower = currentPower
end

function WeightTrainingRuntime.process()
    if not State.autoWeightTraining then
        return false
    end
    local player = Services.Players.LocalPlayer
    if player:GetAttribute("LuckyBlockActivityActive") == true then
        State.weightTrainingLastStatus = "Paused During Kick Activity"
        return false
    end
    if State.cardPlacementPending or State.cardPickupPending then
        State.weightTrainingLastStatus = "Paused During Card Tool Action"
        return false
    end
    local character, humanoid, root = WeightTrainingRuntime.getCharacterState()
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        State.weightTrainingLastStatus = "Waiting for Character"
        return false
    end
    local equipped = WeightTrainingRuntime.getEquippedWeight(character)
    if not equipped then
        WeightTrainingRuntime.captureMovement(humanoid, root)
    end
    local best = WeightTrainingRuntime.findBestWeight(character)
    if not best then
        State.weightTrainingTool = nil
        State.weightTrainingToolName = nil
        State.weightTrainingLastStatus = "No Weight Tool Available"
        return false
    end
    if best.Parent ~= character then
        WeightTrainingRuntime.captureMovement(humanoid, root)
        local success, errorMessage = pcall(function()
            humanoid:EquipTool(best)
        end)
        if not success then
            State.weightTrainingFailures = State.weightTrainingFailures + 1
            State.weightTrainingNextAt = os.clock() + math.min(5, 0.5 + State.weightTrainingFailures)
            State.weightTrainingLastStatus = "Weight Equip Failed"
            if State.weightTrainingFailures == 1 or State.weightTrainingFailures % 5 == 0 then
                LogRuntime.add("ERROR", "Weight equip failed: " .. tostring(errorMessage))
            end
            return false
        end
        State.weightTrainingManagedEquip = true
        State.weightTrainingTool = best
        State.weightTrainingToolName = best.Name
        State.weightTrainingLastStatus = "Equipping " .. best.Name
        State.weightTrainingNextAt = os.clock() + 0.1
        return true
    end
    if State.weightTrainingTool ~= best then
        State.weightTrainingTool = best
        State.weightTrainingToolName = best.Name
        State.weightTrainingLastActivateAt = 0
        State.weightTrainingManagedEquip = State.weightTrainingManagedEquip or equipped ~= best
    end
    local now = os.clock()
    if now < State.weightTrainingNextAt or now - State.weightTrainingLastActivateAt < State.weightTrainingActivateInterval then
        return false
    end
    if best.Enabled == false then
        State.weightTrainingLastStatus = "Weight Tool Cooldown"
        State.weightTrainingNextAt = now + State.weightTrainingActivateInterval
        return false
    end
    local success, errorMessage = pcall(function()
        best:Activate()
    end)
    State.weightTrainingLastActivateAt = now
    State.weightTrainingNextAt = now + State.weightTrainingActivateInterval
    if not success then
        State.weightTrainingFailures = State.weightTrainingFailures + 1
        State.weightTrainingLastStatus = "Weight Activation Failed"
        if State.weightTrainingFailures == 1 or State.weightTrainingFailures % 10 == 0 then
            LogRuntime.add("ERROR", "Weight activation failed: " .. tostring(errorMessage))
        end
        return false
    end
    State.weightTrainingActivationCount = State.weightTrainingActivationCount + 1
    State.weightTrainingFailures = 0
    State.weightTrainingLastStatus = State.freeMovementWhileTraining and "Training with Free Movement" or "Training Active"
    return true
end

function WeightTrainingRuntime.tick()
    if not State.autoWeightTraining and not State.freeMovementWhileTraining then
        return
    end
    local character, humanoid, root = WeightTrainingRuntime.getCharacterState()
    if humanoid and root then
        local equipped = WeightTrainingRuntime.getEquippedWeight(character)
        if not equipped then
            WeightTrainingRuntime.captureMovement(humanoid, root)
        end
        WeightTrainingRuntime.enforceFreeMovement(character, humanoid, root)
    end
    if State.autoWeightTraining then
        WeightTrainingRuntime.process()
    end
end

function WeightTrainingRuntime.getState()
    local character = Services.Players.LocalPlayer.Character
    local equipped = WeightTrainingRuntime.getEquippedWeight(character)
    return {
        enabled = State.autoWeightTraining,
        freeMovement = State.freeMovementWhileTraining,
        equippedWeight = equipped and equipped.Name or nil,
        managedWeight = State.weightTrainingToolName,
        activationCount = State.weightTrainingActivationCount,
        lastActivateAt = State.weightTrainingLastActivateAt,
        lastPowerAt = State.weightTrainingLastPowerAt,
        lastPower = State.weightTrainingLastPower,
        failures = State.weightTrainingFailures,
        lastStatus = State.weightTrainingLastStatus,
        controlsResolved = State.weightTrainingControlsResolved,
        controlsAvailable = State.weightTrainingControls ~= nil,
    }
end

function WeightRuntime.buildCatalog()
    table.clear(State.weightNames)
    table.clear(State.weightNameSet)
    table.clear(State.weightData)
    local configuration = Modules.WeightConfigurations
    local weights = type(configuration) == "table" and rawget(configuration, "Weights") or nil
    if type(weights) ~= "table" then
        return false
    end
    local entries = {}
    for name, data in pairs(weights) do
        if type(name) == "string" and type(data) == "table" then
            entries[#entries + 1] = {
                name = name,
                price = math.max(0, tonumber(rawget(data, "Price")) or 0),
                power = math.max(0, tonumber(rawget(data, "Power")) or 0),
            }
        end
    end
    table.sort(entries, function(left, right)
        if left.price == right.price then
            return left.name < right.name
        end
        return left.price < right.price
    end)
    for _, entry in ipairs(entries) do
        State.weightNames[#State.weightNames + 1] = entry.name
        State.weightNameSet[entry.name] = true
        State.weightData[entry.name] = {
            Price = entry.price,
            Power = entry.power,
        }
    end
    return #State.weightNames > 0
end


function WeightRuntime.getCurrency()
    local player = Services.Players.LocalPlayer
    local leaderstats = player and player:FindFirstChild("leaderstats")
    for _, name in ipairs(State.weightCurrencyNames) do
        local valueObject = leaderstats and leaderstats:FindFirstChild(name)
        if valueObject then
            local success, value = pcall(function()
                return tonumber(valueObject.Value)
            end)
            if success and value then
                State.weightCurrencyName = name
                State.weightCurrencySource = "leaderstats"
                State.weightCurrencyValue = math.max(0, value)
                return State.weightCurrencyValue, name, "leaderstats"
            end
        end
    end
    for _, name in ipairs(State.weightCurrencyNames) do
        local value = player and tonumber(player:GetAttribute(name)) or nil
        if value then
            State.weightCurrencyName = name
            State.weightCurrencySource = "attribute"
            State.weightCurrencyValue = math.max(0, value)
            return State.weightCurrencyValue, name, "attribute"
        end
    end
    State.weightCurrencyName = nil
    State.weightCurrencySource = nil
    State.weightCurrencyValue = 0
    return nil, nil, nil
end

function WeightRuntime.getBestOwnedTarget()
    local bestName = nil
    local bestPower = -1
    local bestPrice = -1
    local function consider(name)
        if type(name) ~= "string" or not State.weightNameSet[name] then
            return
        end
        local data = State.weightData[name]
        local power = data and tonumber(data.Power) or 0
        local price = data and tonumber(data.Price) or 0
        if not bestName
            or power > bestPower
            or power == bestPower and price > bestPrice
            or power == bestPower and price == bestPrice and name < bestName
        then
            bestName = name
            bestPower = power
            bestPrice = price
        end
    end
    for _, name in ipairs(State.weightNames) do
        if State.weightUnlocked[name] == true then
            consider(name)
        end
    end
    consider(State.weightEquipped)
    local player = Services.Players.LocalPlayer
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    if character then
        for _, child in ipairs(character:GetChildren()) do
            if WeightTrainingRuntime.isWeightTool(child) then
                State.weightUnlocked[child.Name] = true
                consider(child.Name)
            end
        end
    end
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if WeightTrainingRuntime.isWeightTool(child) then
                State.weightUnlocked[child.Name] = true
                consider(child.Name)
            end
        end
    end
    State.weightBestOwnedName = bestName
    State.weightBestOwnedPower = math.max(0, bestPower)
    State.weightBestOwnedPrice = math.max(0, bestPrice)
    return bestName, State.weightBestOwnedPower, State.weightBestOwnedPrice
end

function WeightRuntime.getBestAffordableTarget()
    local currency = WeightRuntime.getCurrency()
    if currency == nil then
        State.weightBestAffordableTarget = nil
        return nil, "Currency Unavailable"
    end
    local _, ownedPower = WeightRuntime.getBestOwnedTarget()
    local bestName = nil
    local bestData = nil
    local strongerLockedExists = false
    for _, name in ipairs(State.weightNames) do
        if State.weightUnlocked[name] ~= true then
            local data = State.weightData[name]
            local price = data and tonumber(data.Price) or nil
            local power = data and tonumber(data.Power) or nil
            if price and power and power > ownedPower then
                strongerLockedExists = true
                if price <= currency then
                    if not bestData
                        or power > bestData.Power
                        or power == bestData.Power and price > bestData.Price
                        or power == bestData.Power and price == bestData.Price and name < bestName
                    then
                        bestName = name
                        bestData = {
                            Price = price,
                            Power = power,
                        }
                    end
                end
            end
        end
    end
    State.weightBestAffordableTarget = bestName
    if bestName then
        return bestName, nil
    end
    if strongerLockedExists then
        return nil, "Waiting for Stronger Affordable Weight"
    end
    return nil, "Best Weight Already Owned"
end

function WeightRuntime.ensureBestOwnedEquipped()
    if not State.autoBuyBestAffordableWeight or State.weightPending then
        return false
    end
    local bestName = WeightRuntime.getBestOwnedTarget()
    if not bestName then
        State.weightLastStatus = "No Owned Weight"
        return false
    end
    local equippedTool = WeightTrainingRuntime.getEquippedWeight(Services.Players.LocalPlayer.Character)
    if equippedTool and equippedTool.Name == bestName then
        State.weightEquipped = bestName
        State.weightLastStatus = "Best Weight Equipped: " .. bestName
        return true
    end
    local localTool = WeightTrainingRuntime.findWeightToolByName(bestName)
    if localTool then
        local success = WeightTrainingRuntime.equipWeightTool(bestName)
        if success then
            State.weightEquipped = bestName
            State.weightLastStatus = "Best Weight Equipped: " .. bestName
            return true
        end
    end
    if State.weightEquipped == bestName then
        State.weightLastStatus = "Waiting for Best Weight Tool: " .. bestName
        return false
    end
    local remote = State.requestWeightPurchase
    if not remote or not remote:IsA("RemoteEvent") then
        State.weightLastStatus = "Equip Remote Unavailable"
        return false
    end
    local now = os.clock()
    if now < State.weightNextAt then
        return false
    end
    State.weightPending = true
    State.weightPendingSince = now
    State.weightPendingName = bestName
    State.weightPendingAction = "Equip"
    State.weightLastStatus = "Equip Pending: " .. bestName
    local success, errorMessage = pcall(function()
        remote:FireServer(bestName)
    end)
    if not success then
        State.weightPending = false
        State.weightPendingSince = 0
        State.weightPendingName = nil
        State.weightPendingAction = nil
        State.weightFailures = State.weightFailures + 1
        State.weightNextAt = now + math.min(15, State.weightRetryCooldown + State.weightFailures)
        State.weightLastStatus = "Equip Request Failed"
        LogRuntime.add("ERROR", "Best weight equip request failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function WeightRuntime.getWhitelist()
    local selected = {}
    for _, name in ipairs(State.weightNames) do
        if State.weightBuyWhitelist[name] == true then
            selected[#selected + 1] = name
        end
    end
    return selected
end

function WeightRuntime.setWhitelist(source, save)
    local normalized = {}
    if type(source) == "string" then
        if State.weightNameSet[source] then
            normalized[source] = true
        end
    elseif type(source) == "table" then
        for key, value in pairs(source) do
            local name
            if type(key) == "number" and type(value) == "string" then
                name = value
            elseif type(key) == "string" and value == true then
                name = key
            end
            if name and State.weightNameSet[name] then
                normalized[name] = true
            end
        end
    end
    table.clear(State.weightBuyWhitelist)
    for name in pairs(normalized) do
        State.weightBuyWhitelist[name] = true
    end
    State.weightCursor = 0
    State.weightPending = false
    State.weightPendingSince = 0
    State.weightPendingName = nil
    State.weightNextAt = 0
    State.weightFailures = 0
    State.weightLastStatus = "Whitelist Updated"
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function WeightRuntime.applyUnlockedSnapshot(source)
    if type(source) ~= "table" then
        return false
    end
    table.clear(State.weightUnlocked)
    for key, value in pairs(source) do
        local name
        if type(key) == "number" and type(value) == "string" then
            name = value
        elseif type(key) == "string" and value == true then
            name = key
        end
        if name and State.weightNameSet[name] then
            State.weightUnlocked[name] = true
        end
    end
    State.weightLastRefreshAt = os.clock()
    return true
end

function WeightRuntime.confirm(name)
    if type(name) ~= "string" or not State.weightNameSet[name] then
        return false
    end
    State.weightUnlocked[name] = true
    State.weightEquipped = name
    if not State.weightPending or State.weightPendingName ~= name then
        return false
    end
    local data = State.weightData[name] or {}
    State.weightPending = false
    State.weightPendingSince = 0
    local action = State.weightPendingAction or "Purchase"
    State.weightPendingName = nil
    State.weightPendingAction = nil
    State.weightFailures = 0
    State.weightNextAt = os.clock() + State.weightCooldown
    if action == "Equip" then
        State.weightLastStatus = "Best Weight Equipped: " .. name
        LogRuntime.add("SUCCESS", "Best weight equipped: " .. name)
    else
        State.weightLastStatus = "Purchased and Equipped: " .. name
        LogRuntime.add(
            "SUCCESS",
            string.format(
                "Weight purchased and equipped: %s ($%s, +%s Power/s)",
                name,
                string.format("%g", tonumber(data.Price) or 0),
                string.format("%g", tonumber(data.Power) or 0)
            )
        )
    end
    task.defer(function()
        WeightTrainingRuntime.equipWeightTool(name)
    end)
    return true
end

function WeightRuntime.refreshUnlocked(silent)
    local remote = State.getUnlockedWeights
    if not remote or not remote:IsA("RemoteFunction") then
        if not silent then
            LogRuntime.add("ERROR", "GetUnlockedWeights RemoteFunction is unavailable")
        end
        return false
    end
    local success, result = pcall(function()
        return remote:InvokeServer()
    end)
    if not success or type(result) ~= "table" then
        if not silent then
            LogRuntime.add("ERROR", "Unlocked weights refresh failed: " .. tostring(result))
        end
        return false
    end
    WeightRuntime.applyUnlockedSnapshot(result)
    local pendingName = State.weightPendingName
    if pendingName and State.weightPendingAction ~= "Equip" and State.weightUnlocked[pendingName] then
        WeightRuntime.confirm(pendingName)
    end
    return true
end

function WeightRuntime.getNextTarget()
    local total = #State.weightNames
    if total <= 0 then
        return nil
    end
    for offset = 1, total do
        local index = ((State.weightCursor + offset - 1) % total) + 1
        local name = State.weightNames[index]
        if State.weightBuyWhitelist[name] == true and State.weightUnlocked[name] ~= true then
            State.weightCursor = index
            return name
        end
    end
    return nil
end

function WeightRuntime.resetLifecycle(status)
    State.weightPending = false
    State.weightPendingSince = 0
    State.weightPendingName = nil
    State.weightPendingAction = nil
    State.weightNextAt = 0
    State.weightFailures = 0
    State.weightCursor = 0
    State.weightLastStatus = status or "Idle"
end

function WeightRuntime.setAuto(enabled, save)
    State.autoBuyWeights = enabled == true
    local active = State.autoBuyWeights or State.autoBuyBestAffordableWeight
    local status = State.autoBuyBestAffordableWeight and "Best Affordable Ready" or (active and "Ready" or "Disabled")
    WeightRuntime.resetLifecycle(status)
    if active then
        task.defer(function()
            WeightRuntime.refreshUnlocked(true)
            WeightRuntime.process()
        end)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function WeightRuntime.setAutoBestAffordable(enabled, save)
    State.autoBuyBestAffordableWeight = enabled == true
    local active = State.autoBuyWeights or State.autoBuyBestAffordableWeight
    local status = State.autoBuyBestAffordableWeight and "Best Affordable Ready" or (active and "Ready" or "Disabled")
    WeightRuntime.resetLifecycle(status)
    if active then
        task.defer(function()
            WeightRuntime.refreshUnlocked(true)
            WeightRuntime.process()
        end)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function WeightRuntime.process()
    if (not State.autoBuyWeights and not State.autoBuyBestAffordableWeight) or State.weightPending then
        return false
    end
    local remote = State.requestWeightPurchase
    if not remote or not remote:IsA("RemoteEvent") then
        State.weightLastStatus = "Remote Unavailable"
        return false
    end
    local now = os.clock()
    if now < State.weightNextAt then
        return false
    end
    local name
    if State.autoBuyBestAffordableWeight then
        local reason
        name, reason = WeightRuntime.getBestAffordableTarget()
        if not name then
            State.weightLastStatus = reason or "Waiting for Affordable Weight"
            return false
        end
    else
        if next(State.weightBuyWhitelist) == nil then
            State.weightLastStatus = "No Selected Weights"
            return false
        end
        name = WeightRuntime.getNextTarget()
        if not name then
            State.weightLastStatus = "All Selected Weights Unlocked"
            return false
        end
        State.weightBestAffordableTarget = nil
    end
    State.weightPending = true
    State.weightPendingSince = now
    State.weightPendingName = name
    State.weightPendingAction = "Purchase"
    State.weightLastStatus = "Purchase Pending: " .. name
    local success, errorMessage = pcall(function()
        remote:FireServer(name)
    end)
    if not success then
        State.weightPending = false
        State.weightPendingSince = 0
        State.weightPendingName = nil
        State.weightPendingAction = nil
        State.weightFailures = State.weightFailures + 1
        State.weightNextAt = now + math.min(15, State.weightRetryCooldown + State.weightFailures)
        State.weightLastStatus = "Request Failed"
        LogRuntime.add("ERROR", "Weight purchase request failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function WeightRuntime.tick()
    if not State.autoBuyWeights and not State.autoBuyBestAffordableWeight then
        return
    end
    local now = os.clock()
    if State.weightPending then
        if now - State.weightPendingSince < State.weightPendingTimeout then
            return
        end
        local pendingAction = State.weightPendingAction or "Purchase"
        if pendingAction ~= "Equip" then
            WeightRuntime.refreshUnlocked(true)
            if not State.weightPending then
                return
            end
        end
        local failedName = State.weightPendingName
        State.weightPending = false
        State.weightPendingSince = 0
        State.weightPendingName = nil
        State.weightPendingAction = nil
        State.weightFailures = State.weightFailures + 1
        State.weightNextAt = now + math.min(20, State.weightRetryCooldown + State.weightFailures * 2)
        State.weightLastStatus = pendingAction == "Equip" and "Equip Confirmation Timeout" or "Purchase Confirmation Timeout"
        if State.weightFailures == 1 or State.weightFailures % 5 == 0 then
            if pendingAction == "Equip" then
                LogRuntime.add("ERROR", "Best weight equip was not confirmed for " .. tostring(failedName))
            else
                LogRuntime.add(
                    "ERROR",
                    "Weight purchase was not confirmed for " .. tostring(failedName) .. "; the server may require more currency or progression"
                )
            end
        end
        return
    end
    if State.autoBuyBestAffordableWeight then
        local requested = WeightRuntime.process()
        if not requested and not State.weightPending then
            WeightRuntime.ensureBestOwnedEquipped()
        end
        return
    end
    WeightRuntime.process()
end

function WeightRuntime.bind()
    local updateRemote = State.updateWeightsUI
    local resetRemote = State.resetWeightsUI
    if not updateRemote or not resetRemote then
        return false
    end
    ConnectionRuntime.disconnect("weightUpdateConnection")
    ConnectionRuntime.disconnect("weightResetConnection")
    State.weightUpdateConnection = updateRemote.OnClientEvent:Connect(function(name)
        if type(name) == "string" then
            WeightRuntime.confirm(name)
        end
    end)
    State.weightResetConnection = resetRemote.OnClientEvent:Connect(function(unlocked, equipped)
        if type(unlocked) == "table" then
            WeightRuntime.applyUnlockedSnapshot(unlocked)
        end
        if type(equipped) == "string" then
            State.weightEquipped = equipped
        end
        local pendingName = State.weightPendingName
        if pendingName then
            if State.weightPendingAction == "Equip" and equipped == pendingName then
                WeightRuntime.confirm(pendingName)
            elseif State.weightPendingAction ~= "Equip" and State.weightUnlocked[pendingName] then
                WeightRuntime.confirm(pendingName)
            end
        end
    end)
    return true
end

function WeightRuntime.getState()
    local unlocked = {}
    for _, name in ipairs(State.weightNames) do
        if State.weightUnlocked[name] then
            unlocked[#unlocked + 1] = name
        end
    end
    return {
        enabled = State.autoBuyWeights,
        bestAffordableEnabled = State.autoBuyBestAffordableWeight,
        whitelistIgnored = State.autoBuyBestAffordableWeight,
        whitelist = WeightRuntime.getWhitelist(),
        currencyName = State.weightCurrencyName,
        currencySource = State.weightCurrencySource,
        currencyValue = State.weightCurrencyValue,
        bestAffordableTarget = State.weightBestAffordableTarget,
        bestOwnedName = State.weightBestOwnedName,
        bestOwnedPower = State.weightBestOwnedPower,
        bestOwnedPrice = State.weightBestOwnedPrice,
        unlocked = unlocked,
        equipped = State.weightEquipped,
        pending = State.weightPending,
        pendingSince = State.weightPendingSince,
        pendingName = State.weightPendingName,
        pendingAction = State.weightPendingAction,
        failures = State.weightFailures,
        lastStatus = State.weightLastStatus,
        lastRefreshAt = State.weightLastRefreshAt,
        catalogSize = #State.weightNames,
    }
end


function PlaytimeRuntime.getSessionSeconds()
    local sessionStart = tonumber(Services.Players.LocalPlayer:GetAttribute("PlaytimeSessionStart"))
    if sessionStart and sessionStart > 0 then
        return math.max(0, os.time() - sessionStart)
    end
    local state = State.playtimeState
    if type(state) ~= "table" then
        return 0
    end
    local stateStart = tonumber(rawget(state, "SessionStart"))
    if stateStart and stateStart > 0 then
        return math.max(0, os.time() - stateStart)
    end
    return math.max(0, tonumber(rawget(state, "SessionSeconds")) or 0)
end

function PlaytimeRuntime.isClaimed(id)
    local state = State.playtimeState
    local claimed = type(state) == "table" and rawget(state, "Claimed") or nil
    if type(claimed) ~= "table" then
        return false
    end
    return claimed[id] == true or claimed[tostring(id)] == true
end

function PlaytimeRuntime.getMilestones()
    local configuration = Modules.PlaytimeRewardConfiguration
    local milestones = type(configuration) == "table" and rawget(configuration, "Milestones") or nil
    return type(milestones) == "table" and milestones or {}
end

function PlaytimeRuntime.findReadyMilestone()
    local sessionSeconds = PlaytimeRuntime.getSessionSeconds()
    for _, milestone in ipairs(PlaytimeRuntime.getMilestones()) do
        if type(milestone) == "table" then
            local id = tonumber(rawget(milestone, "Id"))
            local minutes = math.max(0, tonumber(rawget(milestone, "Minutes")) or 0)
            if id and not PlaytimeRuntime.isClaimed(id) and sessionSeconds >= minutes * 60 then
                return milestone
            end
        end
    end
    return nil
end

function PlaytimeRuntime.refreshState(silent)
    local remote = State.getPlaytimeRewardState
    if not remote or not remote:IsA("RemoteFunction") then
        if not silent then
            LogRuntime.add("ERROR", "GetPlaytimeRewardState RemoteFunction is unavailable")
        end
        return false
    end
    local success, result = pcall(function()
        return remote:InvokeServer()
    end)
    if not success or type(result) ~= "table" then
        State.playtimeFailures = State.playtimeFailures + 1
        State.playtimeLastStatus = "State Refresh Failed"
        if not silent then
            LogRuntime.add("ERROR", "Playtime reward state refresh failed: " .. tostring(result))
        end
        return false
    end
    State.playtimeState = result
    State.playtimeLastRefreshAt = os.clock()
    State.playtimeLastStatus = "State Refreshed"
    return true
end

function PlaytimeRuntime.resetLifecycle(status)
    State.playtimePending = false
    State.playtimePendingId = nil
    State.playtimeNextAt = 0
    State.playtimeFailures = 0
    State.playtimeLastStatus = status or "Idle"
end

function PlaytimeRuntime.setAuto(enabled, save)
    State.autoClaimPlaytimeRewards = enabled == true
    PlaytimeRuntime.resetLifecycle(State.autoClaimPlaytimeRewards and "Ready" or "Disabled")
    if State.autoClaimPlaytimeRewards then
        task.defer(function()
            if not State.playtimeState then
                PlaytimeRuntime.refreshState(true)
            end
            PlaytimeRuntime.process()
        end)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function PlaytimeRuntime.process()
    if not State.autoClaimPlaytimeRewards or State.playtimePending then
        return false
    end
    local now = os.clock()
    if now < State.playtimeNextAt then
        return false
    end
    if not State.playtimeState then
        if not PlaytimeRuntime.refreshState(true) then
            State.playtimeNextAt = now + State.playtimeRetryCooldown
            return false
        end
    end
    local milestone = PlaytimeRuntime.findReadyMilestone()
    if not milestone then
        if now - State.playtimeLastRefreshAt >= State.playtimeRefreshInterval then
            PlaytimeRuntime.refreshState(true)
            milestone = PlaytimeRuntime.findReadyMilestone()
        end
        if not milestone then
            State.playtimeLastStatus = "No Playtime Reward Available"
            return false
        end
    end
    local id = tonumber(rawget(milestone, "Id"))
    local title = tostring(rawget(milestone, "Title") or ("Reward #" .. tostring(id)))
    local remote = State.claimPlaytimeReward
    if not remote or not remote:IsA("RemoteFunction") then
        State.playtimeLastStatus = "Remote Unavailable"
        return false
    end
    State.playtimePending = true
    State.playtimePendingId = id
    State.playtimeLastStatus = "Claim Pending: " .. title
    local success, result = pcall(function()
        return remote:InvokeServer(id)
    end)
    State.playtimePending = false
    State.playtimePendingId = nil
    if success and type(result) == "table" and rawget(result, "Success") == true then
        local newState = rawget(result, "State")
        if type(newState) == "table" then
            State.playtimeState = newState
            State.playtimeLastRefreshAt = os.clock()
        else
            PlaytimeRuntime.refreshState(true)
        end
        State.playtimeFailures = 0
        State.playtimeNextAt = os.clock() + State.playtimeCooldown
        State.playtimeLastStatus = "Claimed: " .. title
        LogRuntime.add("SUCCESS", "Playtime reward claimed: " .. title)
        return true
    end
    PlaytimeRuntime.refreshState(true)
    if PlaytimeRuntime.isClaimed(id) then
        State.playtimeFailures = 0
        State.playtimeNextAt = os.clock() + State.playtimeCooldown
        State.playtimeLastStatus = "Claim Confirmed: " .. title
        LogRuntime.add("SUCCESS", "Playtime reward claimed: " .. title)
        return true
    end
    State.playtimeFailures = State.playtimeFailures + 1
    State.playtimeNextAt = os.clock() + math.min(15, State.playtimeRetryCooldown + State.playtimeFailures)
    State.playtimeLastStatus = "Claim Failed"
    local message = type(result) == "table" and rawget(result, "Message") or result
    if not success or State.playtimeFailures == 1 or State.playtimeFailures % 5 == 0 then
        LogRuntime.add("ERROR", "Playtime reward claim failed for " .. title .. ": " .. tostring(message))
    end
    return false
end

function PlaytimeRuntime.tick()
    if State.autoClaimPlaytimeRewards then
        PlaytimeRuntime.process()
    end
end

function PlaytimeRuntime.getState()
    local claimed = {}
    for _, milestone in ipairs(PlaytimeRuntime.getMilestones()) do
        local id = type(milestone) == "table" and tonumber(rawget(milestone, "Id")) or nil
        if id and PlaytimeRuntime.isClaimed(id) then
            claimed[#claimed + 1] = id
        end
    end
    return {
        enabled = State.autoClaimPlaytimeRewards,
        pending = State.playtimePending,
        pendingId = State.playtimePendingId,
        sessionSeconds = PlaytimeRuntime.getSessionSeconds(),
        claimed = claimed,
        failures = State.playtimeFailures,
        lastStatus = State.playtimeLastStatus,
        lastRefreshAt = State.playtimeLastRefreshAt,
    }
end

function SpinRuntime.getSignature()
    local player = Services.Players.LocalPlayer
    return tostring(player:GetAttribute("SpinNumber")) .. ":" .. tostring(player:GetAttribute("LastDailySpin"))
end

function SpinRuntime.getAvailability()
    local player = Services.Players.LocalPlayer
    local spinAttribute = player:GetAttribute("SpinNumber")
    if spinAttribute == nil then
        return false, 0, 0
    end
    local spins = math.max(0, tonumber(spinAttribute) or 0)
    local serverLastDailySpin = tonumber(player:GetAttribute("LastDailySpin")) or 0
    local effectiveLastDailySpin = math.max(serverLastDailySpin, tonumber(State.spinLocalDailyUsedAt) or 0)
    local remaining = math.max(0, 86400 - (os.time() - effectiveLastDailySpin))
    return spins > 0 or remaining <= 0, spins, remaining
end

function SpinRuntime.describeReward(index)
    local configuration = Modules.DailySpinConfiguration
    local rewards = type(configuration) == "table" and rawget(configuration, "Rewards") or nil
    local reward = type(rewards) == "table" and rewards[index] or nil
    if type(reward) ~= "table" then
        return "Reward #" .. tostring(index)
    end
    local rewardType = tostring(rawget(reward, "Type") or "Reward")
    local name = rawget(reward, "Name")
    local amount = tonumber(rawget(reward, "Amount"))
    if rewardType == "Cash" and amount then
        return "$" .. string.format("%g", amount)
    end
    if rewardType == "Spins" and amount then
        return "+" .. string.format("%g", amount) .. " Spins"
    end
    if name ~= nil and tostring(name) ~= "" then
        return tostring(name)
    end
    if amount then
        return string.format("%g %s", amount, rewardType)
    end
    return rewardType .. " #" .. tostring(index)
end

function SpinRuntime.getResponseMessage(result)
    if type(result) ~= "table" then
        if result == nil or result == false then
            return "No spins available"
        end
        return tostring(result)
    end
    local keys = {
        "Message",
        "message",
        "Error",
        "error",
        "Reason",
        "reason",
        "Status",
        "status",
    }
    for _, key in ipairs(keys) do
        local value = rawget(result, key)
        if value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    return "Server denied the spin request"
end

function SpinRuntime.resetLifecycle(status)
    State.spinPending = false
    State.spinNextAt = 0
    State.spinFailures = 0
    State.spinDeniedCount = 0
    State.spinAwaitingState = false
    State.spinAwaitingSince = 0
    State.spinBeforeSignature = nil
    State.spinLastResponseMessage = nil
    State.spinLastStatus = status or "Idle"
end

function SpinRuntime.setAuto(enabled, save)
    State.autoSpin = enabled == true
    SpinRuntime.resetLifecycle(State.autoSpin and "Ready" or "Disabled")
    if State.autoSpin then
        task.defer(SpinRuntime.process)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function SpinRuntime.onStateChanged()
    local player = Services.Players.LocalPlayer
    local serverLastDailySpin = tonumber(player:GetAttribute("LastDailySpin")) or 0
    if serverLastDailySpin >= State.spinLocalDailyUsedAt then
        State.spinLocalDailyUsedAt = 0
    end
    if State.spinAwaitingState and SpinRuntime.getSignature() ~= State.spinBeforeSignature then
        State.spinAwaitingState = false
        State.spinAwaitingSince = 0
        State.spinBeforeSignature = nil
        State.spinLastStatus = "State Confirmed"
    end
end

function SpinRuntime.process()
    if not State.autoSpin or State.spinPending or State.spinAwaitingState then
        return false
    end
    local now = os.clock()
    if now < State.spinNextAt then
        return false
    end
    local available, spins = SpinRuntime.getAvailability()
    if not available then
        State.spinLastStatus = "No Spin Available"
        return false
    end
    local remote = State.requestSpin
    if not remote or not remote:IsA("RemoteFunction") then
        State.spinLastStatus = "Remote Unavailable"
        return false
    end
    local beforeSignature = SpinRuntime.getSignature()
    local usedDailySpin = spins <= 0
    State.spinPending = true
    State.spinLastStatus = usedDailySpin and "Using Daily Spin" or "Using Stored Spin"
    local success, result = pcall(function()
        return remote:InvokeServer()
    end)
    State.spinPending = false
    if not success then
        State.spinFailures = State.spinFailures + 1
        State.spinNextAt = os.clock() + math.min(30, State.spinRetryCooldown + State.spinFailures * 2)
        State.spinLastResponseMessage = tostring(result)
        State.spinLastStatus = "Invocation Failed"
        LogRuntime.add("ERROR", "Daily spin invocation failed: " .. tostring(result))
        return false
    end
    local confirmed = type(result) == "table" and (rawget(result, "success") == true or rawget(result, "Success") == true)
    if not confirmed then
        State.spinFailures = State.spinFailures + 1
        State.spinDeniedCount = State.spinDeniedCount + 1
        State.spinLastResponseMessage = SpinRuntime.getResponseMessage(result)
        State.spinLastStatus = "Server Denied: " .. State.spinLastResponseMessage
        State.spinNextAt = os.clock() + math.min(30, State.spinRetryCooldown + State.spinFailures * 2)
        return false
    end
    local index = tonumber(rawget(result, "Index"))
    State.spinLastIndex = index
    State.spinLastResult = result
    State.spinLastResponseMessage = nil
    State.spinFailures = 0
    State.spinDeniedCount = 0
    State.spinNextAt = os.clock() + State.spinCooldown
    State.spinLastStatus = "Spin Confirmed"
    if usedDailySpin then
        State.spinLocalDailyUsedAt = os.time()
    end
    if SpinRuntime.getSignature() == beforeSignature then
        State.spinAwaitingState = true
        State.spinAwaitingSince = os.clock()
        State.spinBeforeSignature = beforeSignature
    end
    LogRuntime.add("SUCCESS", "Daily spin reward: " .. SpinRuntime.describeReward(index or 0))
    return true
end

function SpinRuntime.tick()
    if not State.autoSpin then
        return
    end
    if State.spinAwaitingState then
        if SpinRuntime.getSignature() ~= State.spinBeforeSignature then
            SpinRuntime.onStateChanged()
        elseif os.clock() - State.spinAwaitingSince >= State.spinAwaitingTimeout then
            State.spinAwaitingState = false
            State.spinAwaitingSince = 0
            State.spinBeforeSignature = nil
            State.spinLastStatus = "Response Confirmed"
        end
        return
    end
    SpinRuntime.process()
end

function SpinRuntime.bind()
    local player = Services.Players.LocalPlayer
    ConnectionRuntime.disconnect("spinNumberConnection")
    ConnectionRuntime.disconnect("spinLastDailyConnection")
    State.spinNumberConnection = player:GetAttributeChangedSignal("SpinNumber"):Connect(SpinRuntime.onStateChanged)
    State.spinLastDailyConnection = player:GetAttributeChangedSignal("LastDailySpin"):Connect(SpinRuntime.onStateChanged)
    return true
end

function SpinRuntime.getState()
    local available, spins, remaining = SpinRuntime.getAvailability()
    return {
        enabled = State.autoSpin,
        available = available,
        storedSpins = spins,
        dailyRemaining = remaining,
        pending = State.spinPending,
        awaitingState = State.spinAwaitingState,
        cooldownRemaining = math.max(0, State.spinNextAt - os.clock()),
        failures = State.spinFailures,
        deniedCount = State.spinDeniedCount,
        lastIndex = State.spinLastIndex,
        lastReward = State.spinLastIndex and SpinRuntime.describeReward(State.spinLastIndex) or nil,
        lastResponseMessage = State.spinLastResponseMessage,
        lastStatus = State.spinLastStatus,
        spinNumberConnected = State.spinNumberConnection ~= nil,
        lastDailySpinConnected = State.spinLastDailyConnection ~= nil,
    }
end


function PlotRuntime.getPlot()
    local player = Services.Players.LocalPlayer
    return Services.Workspace:FindFirstChild("Plot_" .. player.Name)
end

function PlotRuntime.getIndex(name, prefix)
    return tonumber(tostring(name):match("^" .. prefix .. "(%d+)$")) or math.huge
end

function PlotRuntime.clearCache(status)
    table.clear(State.plotCache)
    table.clear(State.plotCacheByKey)
    State.plotCachePlot = nil
    State.plotCacheDirty = true
    State.plotCacheNextAt = 0
    State.plotCacheLastStatus = status or "Cache Cleared"
end

function PlotRuntime.invalidate(status)
    State.plotCacheDirty = true
    State.plotCacheNextAt = 0
    if status then
        State.plotCacheLastStatus = status
    end
end

function PlotRuntime.isEntryAlive(entry)
    return entry
        and entry.floor
        and entry.floor.Parent
        and entry.slot
        and entry.slot.Parent
end

function PlotRuntime.buildEntry(floor, slot)
    local spawn = slot:FindFirstChild("Spawn")
    local prompt = spawn and spawn:FindFirstChildWhichIsA("ProximityPrompt") or nil
    if not prompt and spawn then
        local namedPrompt = spawn:FindFirstChild("ProximityPrompt")
        if namedPrompt and namedPrompt:IsA("ProximityPrompt") then
            prompt = namedPrompt
        end
    end
    local collectPart = slot:FindFirstChild("CollectTouch")
    if collectPart and not collectPart:IsA("BasePart") then
        collectPart = nil
    end
    local upgradePart = slot:FindFirstChild("UpgradePart")
    local upgradeGui = upgradePart and upgradePart:FindFirstChild("UpgradeGUI") or nil
    local key = floor.Name .. "/" .. slot.Name
    return {
        floor = floor,
        slot = slot,
        key = key,
        floorIndex = PlotRuntime.getIndex(floor.Name, "Floor"),
        slotIndex = PlotRuntime.getIndex(slot.Name, "Slot"),
        spawn = spawn,
        prompt = prompt,
        collectPart = collectPart,
        upgradeGui = upgradeGui,
    }
end

function PlotRuntime.refreshCache(force)
    local now = os.clock()
    local plot = PlotRuntime.getPlot()
    if not force
        and not State.plotCacheDirty
        and State.plotCachePlot == plot
        and now < State.plotCacheNextAt
    then
        return State.plotCache
    end
    table.clear(State.plotCache)
    table.clear(State.plotCacheByKey)
    State.plotCachePlot = plot
    State.plotCacheDirty = false
    State.plotCacheNextAt = now + State.plotCacheRefreshInterval
    if not plot then
        State.plotCacheLastStatus = "Plot Unavailable"
        return State.plotCache
    end
    local result = State.plotCache
    for _, floor in ipairs(plot:GetChildren()) do
        if floor:IsA("Model") or floor:IsA("Folder") then
            local slots = floor:FindFirstChild("Slots")
            if slots then
                for _, slot in ipairs(slots:GetChildren()) do
                    if slot:IsA("Model") or slot:IsA("Folder") then
                        result[#result + 1] = PlotRuntime.buildEntry(floor, slot)
                    end
                end
            end
        end
    end
    table.sort(result, function(left, right)
        if left.floorIndex == right.floorIndex then
            if left.slotIndex == right.slotIndex then
                return left.key < right.key
            end
            return left.slotIndex < right.slotIndex
        end
        return left.floorIndex < right.floorIndex
    end)
    for _, entry in ipairs(result) do
        State.plotCacheByKey[entry.key] = entry
    end
    State.plotCacheGeneration = State.plotCacheGeneration + 1
    State.plotCacheLastStatus = "Cached " .. tostring(#result) .. " Slots"
    return result
end

function PlotRuntime.getSlots()
    return PlotRuntime.refreshCache(false)
end

function PlotRuntime.isUnlocked(entry)
    return PlotRuntime.isEntryAlive(entry) and entry.slot:GetAttribute("IsUnlocked") == true
end

function PlotRuntime.getSpawn(entry)
    if not PlotRuntime.isEntryAlive(entry) then
        PlotRuntime.invalidate("Stale Slot Entry")
        return nil
    end
    local spawn = entry.spawn
    if spawn and spawn.Parent == entry.slot then
        return spawn
    end
    spawn = entry.slot:FindFirstChild("Spawn")
    entry.spawn = spawn
    return spawn
end

function PlotRuntime.getVisualItem(entry)
    local spawn = PlotRuntime.getSpawn(entry)
    return spawn and spawn:FindFirstChild("VisualItem") or nil
end

function PlotRuntime.getPlacedCardVisual(entry)
    local visual = PlotRuntime.getVisualItem(entry)
    if not visual then
        return nil
    end
    local originalName = visual:GetAttribute("OriginalName")
    if type(originalName) == "string" and originalName ~= "" then
        return visual
    end
    if visual:FindFirstChild("Card") then
        return visual
    end
    return nil
end

function PlotRuntime.getPrompt(entry)
    local spawn = PlotRuntime.getSpawn(entry)
    if not spawn then
        return nil
    end
    local prompt = entry.prompt
    if prompt and prompt.Parent == spawn and prompt:IsA("ProximityPrompt") then
        return prompt
    end
    prompt = spawn:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then
        local namedPrompt = spawn:FindFirstChild("ProximityPrompt")
        if namedPrompt and namedPrompt:IsA("ProximityPrompt") then
            prompt = namedPrompt
        end
    end
    entry.prompt = prompt
    return prompt
end

function PlotRuntime.getCollectPart(entry)
    if not PlotRuntime.isEntryAlive(entry) then
        PlotRuntime.invalidate("Stale Collect Entry")
        return nil
    end
    local part = entry.collectPart
    if part and part.Parent and part:IsA("BasePart") then
        return part
    end
    part = entry.slot:FindFirstChild("CollectTouch")
    if part and not part:IsA("BasePart") then
        part = nil
    end
    entry.collectPart = part
    return part
end

function PlotRuntime.getUpgradeAddress(entry)
    if not PlotRuntime.isEntryAlive(entry) then
        PlotRuntime.invalidate("Stale Upgrade Entry")
        return nil, nil
    end
    local gui = entry.upgradeGui
    if not gui or not gui.Parent then
        local upgradePart = entry.slot:FindFirstChild("UpgradePart")
        gui = upgradePart and upgradePart:FindFirstChild("UpgradeGUI") or nil
        entry.upgradeGui = gui
    end
    local floorName = gui and gui:GetAttribute("FloorName") or nil
    local slotName = gui and gui:GetAttribute("SlotName") or nil
    if type(floorName) ~= "string" or floorName == "" then
        floorName = entry.floor.Name
    end
    if type(slotName) ~= "string" or slotName == "" then
        slotName = entry.slot.Name
    end
    return floorName, slotName
end

function PlotRuntime.getEarningsText(visual)
    if not visual then
        return ""
    end
    local infoGui = visual:FindFirstChild("InfoGUI")
    local labels = infoGui and infoGui:FindFirstChild("TextLabels") or nil
    local label = labels and labels:FindFirstChild("Earnings") or nil
    if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
        return tostring(label.Text)
    end
    return ""
end

function PlotRuntime.getCollectSignature(entry)
    local part = PlotRuntime.getCollectPart(entry)
    if not part then
        return ""
    end
    local gui = part:FindFirstChild("CollectGUI")
    return gui and tostring(gui.Enabled) or ""
end

function CollectRuntime.getTouchCallback(force)
    if State.collectTouchCallbackResolved and not force then
        return State.collectTouchCallback
    end
    local environment = type(getgenv) == "function" and getgenv() or _G
    local callback = environment and rawget(environment, "firetouchinterest") or nil
    if type(callback) ~= "function" and type(getfenv) == "function" then
        local success, currentEnvironment = pcall(getfenv)
        if success and type(currentEnvironment) == "table" then
            callback = rawget(currentEnvironment, "firetouchinterest")
        end
    end
    State.collectTouchCallback = type(callback) == "function" and callback or nil
    State.collectTouchCallbackResolved = true
    return State.collectTouchCallback
end

function CollectRuntime.getTargets()
    local slots = PlotRuntime.getSlots()
    local targets = {}
    for _, entry in ipairs(slots) do
        if PlotRuntime.isUnlocked(entry)
            and PlotRuntime.getVisualItem(entry)
            and PlotRuntime.getCollectPart(entry)
        then
            targets[#targets + 1] = entry
        end
    end
    return targets
end

function CollectRuntime.addTouchSource(result, seen, part)
    if not part or not part:IsA("BasePart") or not part.Parent or seen[part] then
        return
    end
    seen[part] = true
    result[#result + 1] = part
end

function CollectRuntime.addToolParts(result, seen, tool)
    if not tool then
        return
    end
    local stack = {tool}
    while #stack > 0 and #result < 4 do
        local current = table.remove(stack)
        for _, child in ipairs(current:GetChildren()) do
            if child:IsA("BasePart") then
                CollectRuntime.addTouchSource(result, seen, child)
            else
                stack[#stack + 1] = child
            end
        end
    end
end

function CollectRuntime.getTouchSources(character)
    local result = {}
    local seen = {}
    if not character then
        return result
    end
    local equippedWeight = WeightTrainingRuntime.getEquippedWeight(character)
    if equippedWeight then
        CollectRuntime.addToolParts(result, seen, equippedWeight)
    end
    local preferred = {
        "HumanoidRootPart",
        "LowerTorso",
        "Torso",
        "LeftFoot",
        "RightFoot",
        "Head",
    }
    for _, name in ipairs(preferred) do
        if #result >= 4 then
            break
        end
        CollectRuntime.addTouchSource(result, seen, character:FindFirstChild(name))
    end
    if #result < 2 then
        for _, child in ipairs(character:GetChildren()) do
            if #result >= 4 then
                break
            end
            CollectRuntime.addTouchSource(result, seen, child)
        end
    end
    return result
end

function CollectRuntime.fireTouch(callback, source, target)
    local sourceCanTouch = source.CanTouch
    local targetCanTouch = target.CanTouch
    local success, errorMessage = pcall(function()
        source.CanTouch = true
        target.CanTouch = true
        callback(source, target, 0)
        callback(source, target, 1)
    end)
    pcall(function()
        source.CanTouch = sourceCanTouch
        target.CanTouch = targetCanTouch
    end)
    return success, errorMessage
end

function CollectRuntime.resetLifecycle(status)
    State.collectNextAt = 0
    State.collectCursor = 0
    State.collectPending = false
    State.collectPendingSince = 0
    State.collectPendingKey = nil
    State.collectPendingSlot = nil
    State.collectBeforeSignature = nil
    State.collectFailures = 0
    State.collectUnavailableLogged = false
    State.collectLastStatus = status or "Idle"
end

function CollectRuntime.setAuto(enabled, save)
    State.autoCollectMoney = enabled == true
    CollectRuntime.resetLifecycle(State.autoCollectMoney and "Ready" or "Disabled")
    State.plotStartupGraceUntil = math.max(State.plotStartupGraceUntil, os.clock() + 0.75)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function CollectRuntime.setCycleDelay(value, save)
    State.collectCycleDelay = normalizeCollectCycleDelay(value)
    State.collectNextAt = 0
    State.collectLastStatus = "Cycle Delay Updated"
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    return State.collectCycleDelay
end

function CollectRuntime.finish(status, confirmed)
    State.collectPending = false
    State.collectPendingSince = 0
    State.collectPendingKey = nil
    State.collectPendingSlot = nil
    State.collectBeforeSignature = nil
    State.collectNextAt = os.clock() + State.collectCycleDelay
    State.collectLastStatus = status
    if confirmed then
        State.collectFailures = 0
    end
end

function CollectRuntime.process()
    local now = os.clock()
    if not State.autoCollectMoney or now < State.collectNextAt then
        return false
    end
    local callback = CollectRuntime.getTouchCallback(false)
    if not callback then
        State.collectLastStatus = "firetouchinterest Unavailable"
        if not State.collectUnavailableLogged then
            State.collectUnavailableLogged = true
            LogRuntime.add("ERROR", "Auto Collect requires firetouchinterest support")
        end
        State.collectNextAt = now + 15
        return false
    end
    local character = Services.Players.LocalPlayer.Character
    local touchSources = CollectRuntime.getTouchSources(character)
    if #touchSources == 0 then
        State.collectLastStatus = "Touch Source Unavailable"
        State.collectNextAt = now + 1
        return false
    end
    local targets = CollectRuntime.getTargets()
    if #targets == 0 then
        State.collectLastStatus = "No Collectable Slot"
        State.collectNextAt = now + 0.5
        return false
    end
    local triggered = 0
    local firstError
    for _, entry in ipairs(targets) do
        local part = PlotRuntime.getCollectPart(entry)
        if part then
            local targetTriggered = false
            for _, source in ipairs(touchSources) do
                local success, errorMessage = CollectRuntime.fireTouch(callback, source, part)
                if success then
                    targetTriggered = true
                elseif not firstError then
                    firstError = errorMessage
                end
            end
            if targetTriggered then
                triggered = triggered + 1
                State.collectPendingKey = entry.key
            end
        end
    end
    State.collectNextAt = os.clock() + State.collectCycleDelay
    if triggered > 0 then
        State.collectFailures = 0
        State.collectLastStatus = string.format("Rapid Collect Triggered: %d Slots", triggered)
        return true
    end
    State.collectFailures = State.collectFailures + 1
    State.collectLastStatus = "Collect Failed"
    State.collectNextAt = now + math.min(10, 1 + State.collectFailures)
    if firstError then
        LogRuntime.add("ERROR", "Auto Collect touch failed: " .. tostring(firstError))
    end
    return false
end

function CollectRuntime.tick(allowProcess)
    if not State.autoCollectMoney then
        return false
    end
    if allowProcess == false or os.clock() < State.plotStartupGraceUntil then
        return false
    end
    PlotRuntime.refreshCache(false)
    return CollectRuntime.process()
end

function CollectRuntime.getState()
    return {
        enabled = State.autoCollectMoney,
        pending = false,
        pendingKey = State.collectPendingKey,
        failures = State.collectFailures,
        lastStatus = State.collectLastStatus,
        firetouchinterestAvailable = CollectRuntime.getTouchCallback(false) ~= nil,
        touchSources = #CollectRuntime.getTouchSources(Services.Players.LocalPlayer.Character),
        dedicatedScheduler = true,
        cycleDelay = State.collectCycleDelay,
        cachedSlots = #State.plotCache,
    }
end

function CardUpgradeRuntime.getWhitelist()
    local selected = {}
    for _, rarity in ipairs(State.cardUpgradeRarityNames) do
        if State.cardUpgradeRarityWhitelist[rarity] == true then
            selected[#selected + 1] = rarity
        end
    end
    return selected
end

function CardUpgradeRuntime.setWhitelist(source, save)
    local normalized = {}
    if type(source) == "string" then
        if State.cardUpgradeRaritySet[source] then
            normalized[source] = true
        end
    elseif type(source) == "table" then
        for key, value in pairs(source) do
            local rarity
            if type(key) == "number" and type(value) == "string" then
                rarity = value
            elseif type(key) == "string" and value == true then
                rarity = key
            end
            if rarity and State.cardUpgradeRaritySet[rarity] then
                normalized[rarity] = true
            end
        end
    end
    table.clear(State.cardUpgradeRarityWhitelist)
    for rarity in pairs(normalized) do
        State.cardUpgradeRarityWhitelist[rarity] = true
    end
    CardUpgradeRuntime.resetLifecycle(State.autoUpgradePlacedCards and "Ready" or "Disabled")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function CardUpgradeRuntime.setTargetLevel(value, save)
    State.cardUpgradeTargetLevel = normalizeTargetLevel(value)
    CardUpgradeRuntime.resetLifecycle(State.autoUpgradePlacedCards and "Ready" or "Disabled")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function CardUpgradeRuntime.isEligible(entry, now)
    if not PlotRuntime.isUnlocked(entry) then
        return false
    end
    local visual = PlotRuntime.getVisualItem(entry)
    if not visual then
        return false
    end
    local rarity = visual:GetAttribute("Rarity")
    local level = tonumber(visual:GetAttribute("Level"))
    if type(rarity) ~= "string" or State.cardUpgradeRarityWhitelist[rarity] ~= true or not level then
        return false
    end
    if State.cardUpgradeTargetLevel > 0 and level >= State.cardUpgradeTargetLevel then
        return false
    end
    if (State.cardUpgradeSkipUntil[entry.key] or 0) > now then
        return false
    end
    return true, visual, rarity, level
end

function CardUpgradeRuntime.getNextTarget()
    local slots = PlotRuntime.getSlots()
    local total = #slots
    local now = os.clock()
    if total == 0 then
        return nil
    end
    for offset = 1, total do
        local index = ((State.cardUpgradeCursor + offset - 1) % total) + 1
        local entry = slots[index]
        local eligible, visual, rarity, level = CardUpgradeRuntime.isEligible(entry, now)
        if eligible then
            State.cardUpgradeCursor = index
            return entry, visual, rarity, level
        end
    end
    return nil
end

function CardUpgradeRuntime.resetLifecycle(status)
    State.cardUpgradeNextAt = 0
    State.cardUpgradeCursor = 0
    State.cardUpgradePending = false
    State.cardUpgradePendingSince = 0
    State.cardUpgradePendingKey = nil
    State.cardUpgradePendingSlot = nil
    State.cardUpgradePendingVisual = nil
    State.cardUpgradeBeforeLevel = 0
    State.cardUpgradeBeforeEarnings = ""
    State.cardUpgradeFailures = 0
    table.clear(State.cardUpgradeSkipUntil)
    State.cardUpgradeLastStatus = status or "Idle"
end

function CardUpgradeRuntime.setAuto(enabled, save)
    State.autoUpgradePlacedCards = enabled == true
    CardUpgradeRuntime.resetLifecycle(State.autoUpgradePlacedCards and "Ready" or "Disabled")
    State.plotStartupGraceUntil = math.max(State.plotStartupGraceUntil, os.clock() + 0.75)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function CardUpgradeRuntime.clearPending(status)
    State.cardUpgradePending = false
    State.cardUpgradePendingSince = 0
    State.cardUpgradePendingKey = nil
    State.cardUpgradePendingSlot = nil
    State.cardUpgradePendingVisual = nil
    State.cardUpgradeBeforeLevel = 0
    State.cardUpgradeBeforeEarnings = ""
    State.cardUpgradeLastStatus = status
end

function CardUpgradeRuntime.process()
    local now = os.clock()
    if not State.autoUpgradePlacedCards or State.cardUpgradePending or now < State.cardUpgradeNextAt then
        return false
    end
    if next(State.cardUpgradeRarityWhitelist) == nil then
        State.cardUpgradeLastStatus = "No Selected Rarities"
        State.cardUpgradeNextAt = now + 2
        return false
    end
    local remote = State.requestSlotUpgrade
    if not remote or not remote:IsA("RemoteEvent") then
        State.cardUpgradeLastStatus = "Remote Unavailable"
        State.cardUpgradeNextAt = now + 5
        return false
    end
    local entry, visual, rarity, level = CardUpgradeRuntime.getNextTarget()
    if not entry then
        State.cardUpgradeLastStatus = "No Eligible Card Upgrade"
        State.cardUpgradeNextAt = now + 1.5
        return false
    end
    local floorName, slotName = PlotRuntime.getUpgradeAddress(entry)
    if not floorName or not slotName then
        State.cardUpgradeSkipUntil[entry.key] = now + State.cardUpgradeRetryCooldown
        State.cardUpgradeLastStatus = "Upgrade Address Missing"
        State.cardUpgradeNextAt = now + 2
        return false
    end
    State.cardUpgradePending = true
    State.cardUpgradePendingSince = now
    State.cardUpgradePendingKey = entry.key
    State.cardUpgradePendingSlot = entry.slot
    State.cardUpgradePendingVisual = visual
    State.cardUpgradeBeforeLevel = level
    State.cardUpgradeBeforeEarnings = ""
    State.cardUpgradeLastStatus = string.format("Upgrade Pending: %s %s L%d", rarity, entry.key, level)
    local success, errorMessage = pcall(function()
        remote:FireServer(floorName, slotName)
    end)
    if not success then
        State.cardUpgradeFailures = State.cardUpgradeFailures + 1
        State.cardUpgradeSkipUntil[entry.key] = now + State.cardUpgradeRetryCooldown
        CardUpgradeRuntime.clearPending("Request Failed")
        State.cardUpgradeNextAt = now + math.min(12, 2 + State.cardUpgradeFailures * 2)
        LogRuntime.add("ERROR", "Card upgrade request failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function CardUpgradeRuntime.tick(allowProcess)
    if not State.autoUpgradePlacedCards then
        return false
    end
    if State.cardUpgradePending then
        local visual = State.cardUpgradePendingVisual
        if not visual or not visual.Parent then
            local key = State.cardUpgradePendingKey
            if key then
                State.cardUpgradeSkipUntil[key] = os.clock() + State.cardUpgradeRetryCooldown
            end
            CardUpgradeRuntime.clearPending("Card Changed During Upgrade")
            PlotRuntime.invalidate("Placed Card Changed")
            return false
        end
        local newLevel = tonumber(visual:GetAttribute("Level")) or State.cardUpgradeBeforeLevel
        if newLevel > State.cardUpgradeBeforeLevel then
            local oldLevel = State.cardUpgradeBeforeLevel
            local key = State.cardUpgradePendingKey
            local name = tostring(visual:GetAttribute("OriginalName") or "Card")
            State.cardUpgradeFailures = 0
            CardUpgradeRuntime.clearPending("Upgrade Confirmed")
            State.cardUpgradeNextAt = os.clock() + State.cardUpgradeCooldown
            State.plotNextActionAt = 0
            if State.cardUpgradeTargetLevel > 0 and newLevel >= State.cardUpgradeTargetLevel then
                LogRuntime.add("SUCCESS", string.format("Card target reached: %s L%d at %s", name, newLevel, tostring(key)))
            elseif newLevel % 10 == 0 or newLevel - oldLevel > 1 then
                LogRuntime.add("SUCCESS", string.format("Card upgraded: %s L%d at %s", name, newLevel, tostring(key)))
            end
            return true
        end
        if os.clock() - State.cardUpgradePendingSince >= State.cardUpgradePendingTimeout then
            local key = State.cardUpgradePendingKey
            State.cardUpgradeFailures = State.cardUpgradeFailures + 1
            if key then
                State.cardUpgradeSkipUntil[key] = os.clock() + State.cardUpgradeRetryCooldown
            end
            CardUpgradeRuntime.clearPending("Upgrade Unconfirmed")
            State.cardUpgradeNextAt = os.clock() + State.cardUpgradeRetryCooldown
        end
        return false
    end
    if allowProcess == false then
        return false
    end
    return CardUpgradeRuntime.process()
end

function CardUpgradeRuntime.getState()
    return {
        enabled = State.autoUpgradePlacedCards,
        targetLevel = State.cardUpgradeTargetLevel,
        rarityWhitelist = CardUpgradeRuntime.getWhitelist(),
        pending = State.cardUpgradePending,
        pendingKey = State.cardUpgradePendingKey,
        beforeLevel = State.cardUpgradeBeforeLevel,
        failures = State.cardUpgradeFailures,
        lastStatus = State.cardUpgradeLastStatus,
        cachedSlots = #State.plotCache,
    }
end

function CardPlacementRuntime.getPromptCallback(force)
    if State.cardPlacementPromptCallbackResolved and not force then
        return State.cardPlacementPromptCallback
    end
    local callback = nil
    local direct = fireproximityprompt
    if type(direct) == "function" then
        callback = direct
    end
    if type(callback) ~= "function" then
        local environment = type(getgenv) == "function" and getgenv() or _G
        callback = environment and rawget(environment, "fireproximityprompt") or nil
    end
    if type(callback) ~= "function" and type(getrenv) == "function" then
        local success, runtimeEnvironment = pcall(getrenv)
        if success and type(runtimeEnvironment) == "table" then
            callback = rawget(runtimeEnvironment, "fireproximityprompt")
        end
    end
    if type(callback) ~= "function" and type(getfenv) == "function" then
        local success, currentEnvironment = pcall(getfenv, 0)
        if success and type(currentEnvironment) == "table" then
            callback = rawget(currentEnvironment, "fireproximityprompt")
        end
    end
    State.cardPlacementPromptCallback = type(callback) == "function" and callback or nil
    State.cardPlacementPromptCallbackResolved = true
    return State.cardPlacementPromptCallback
end

function CardPlacementRuntime.triggerNativePrompt(prompt)
    if not prompt or not prompt.Parent then
        return false, "Prompt unavailable"
    end
    local success, errorMessage = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(0.05, tonumber(prompt.HoldDuration) or 0))
        prompt:InputHoldEnd()
    end)
    if success then
        State.cardPlacementLastTriggerMode = "Native Input"
        State.cardPlacementLastPromptError = nil
        return true, "Native Input"
    end
    State.cardPlacementLastPromptError = tostring(errorMessage)
    return false, tostring(errorMessage)
end

function CardPlacementRuntime.moveToPrompt(prompt)
    local character = Services.Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local target = prompt and prompt.Parent
    if not root or not root:IsA("BasePart") or not target or not target:IsA("BasePart") then
        return false, "Prompt target unavailable"
    end
    local success, errorMessage = pcall(function()
        root.CFrame = target.CFrame * CFrame.new(0, State.cardPlacementTeleportOffset, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        task.wait(State.cardPlacementMoveDelay)
    end)
    if success then
        State.cardPlacementLastPromptError = nil
        return true, "Teleported"
    end
    State.cardPlacementLastPromptError = tostring(errorMessage)
    return false, tostring(errorMessage)
end

function CardPlacementRuntime.triggerExecutorPrompt(prompt)
    local callback = CardPlacementRuntime.getPromptCallback(false)
    if not callback then
        return false, "fireproximityprompt unavailable"
    end
    local success, errorMessage = pcall(callback, prompt)
    if success then
        State.cardPlacementLastTriggerMode = "Executor"
        State.cardPlacementLastPromptError = nil
        return true, "Executor"
    end
    State.cardPlacementLastPromptError = tostring(errorMessage)
    return false, tostring(errorMessage)
end

function CardPlacementRuntime.triggerPrompt(prompt, preferNative)
    if preferNative then
        local nativeSuccess, nativeResult = CardPlacementRuntime.triggerNativePrompt(prompt)
        if nativeSuccess then
            return true, nativeResult
        end
        local executorSuccess, executorResult = CardPlacementRuntime.triggerExecutorPrompt(prompt)
        if executorSuccess then
            return true, executorResult
        end
        return false, tostring(nativeResult) .. " | " .. tostring(executorResult)
    end
    local executorSuccess, executorResult = CardPlacementRuntime.triggerExecutorPrompt(prompt)
    if executorSuccess then
        return true, executorResult
    end
    local nativeSuccess, nativeResult = CardPlacementRuntime.triggerNativePrompt(prompt)
    if nativeSuccess then
        return true, nativeResult
    end
    return false, tostring(executorResult) .. " | " .. tostring(nativeResult)
end

function CardPlacementRuntime.buildCatalog()
    local configuration = Modules.ItemConfigurations
    local items = type(configuration) == "table" and rawget(configuration, "Items") or nil
    if type(items) ~= "table" then
        return false
    end
    for name, data in pairs(items) do
        local income = type(data) == "table" and tonumber(rawget(data, "Income")) or nil
        if type(name) == "string" and income and income > 0 then
            return true
        end
    end
    return false
end

function CardPlacementRuntime.normalizePriorities(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local selected
            if type(key) == "number" and type(value) == "string" then
                selected = value
            elseif type(key) == "string" and value == true then
                selected = key
            end
            if selected == "Best Income (Base)" then
                selected = "Best Income (Mutation)"
            end
            if selected and State.cardPlacementPrioritySet[selected] then
                result[selected] = true
            end
        end
    end
    if next(result) == nil then
        result["Best Income (Mutation)"] = true
    end
    return result
end

function CardPlacementRuntime.getPriorities()
    local result = {}
    for _, priority in ipairs(State.cardPlacementPriorityNames) do
        if State.cardPlacementPriorities[priority] == true then
            result[#result + 1] = priority
        end
    end
    return result
end

function CardPlacementRuntime.resetPriorityPlan()
    State.cardPlacementPriorityInitialized = false
    State.cardPlacementPriorityPhase = "Dynamic Ranking"
    State.cardPlacementPriorityRarity = nil
    State.cardPlacementPriorityRarityRank = 0
    State.cardPlacementPriorityMutation = nil
    State.cardPlacementPriorityMutationRank = 0
end

function CardPlacementRuntime.setPriorities(source, save)
    local normalized = CardPlacementRuntime.normalizePriorities(source)
    table.clear(State.cardPlacementPriorities)
    for priority in pairs(normalized) do
        State.cardPlacementPriorities[priority] = true
    end
    CardPlacementRuntime.resetPriorityPlan()
    CardPlacementRuntime.resetLifecycle(State.autoFillEmptySlots and "Ready" or "Disabled")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function CardPlacementRuntime.getRarityRank(value)
    local name = tostring(value or "")
    local direct = State.cardPlacementRarityRank[name]
    if direct then
        return direct
    end
    local lowered = string.lower(name)
    for rarity, rank in pairs(State.cardPlacementRarityRank) do
        if string.lower(rarity) == lowered then
            return rank
        end
    end
    return 0
end

function CardPlacementRuntime.getMutationRank(value)
    local name = tostring(value or "Normal")
    local direct = State.cardPlacementMutationRank[name]
    if direct then
        return direct
    end
    local lowered = string.lower(name)
    for mutation, rank in pairs(State.cardPlacementMutationRank) do
        if string.lower(mutation) == lowered then
            return rank
        end
    end
    return 0
end

function CardPlacementRuntime.getMutationIncomeMultiplier(value)
    local name = tostring(value or "Normal")
    local configuration = Modules.MutationConfigurations
    local entry = type(configuration) == "table" and rawget(configuration, name) or nil
    if type(entry) ~= "table" and type(configuration) == "table" then
        local lowered = string.lower(name)
        for mutationName, mutationData in pairs(configuration) do
            if type(mutationName) == "string" and string.lower(mutationName) == lowered then
                entry = mutationData
                break
            end
        end
    end
    if type(entry) == "table" then
        local fields = {
            "IncomeMultiplier",
            "EarningsMultiplier",
            "CashMultiplier",
            "Multiplier",
        }
        for _, field in ipairs(fields) do
            local multiplier = tonumber(rawget(entry, field))
            if multiplier and multiplier > 0 then
                return multiplier
            end
        end
    end
    local direct = State.cardPlacementMutationIncomeMultipliers[name]
    if direct then
        return direct
    end
    local lowered = string.lower(name)
    for mutation, multiplier in pairs(State.cardPlacementMutationIncomeMultipliers) do
        if string.lower(mutation) == lowered then
            return multiplier
        end
    end
    return 1
end

function CardPlacementRuntime.isCandidateBetter(candidate, best)
    if not best then
        return true
    end
    local useIncome = State.cardPlacementPriorities["Best Income (Mutation)"] == true
    local useRarity = State.cardPlacementPriorities["Best Rarity"] == true
    local useMutation = State.cardPlacementPriorities["Best Mutation"] == true
    if useIncome and candidate.income ~= best.income then
        return candidate.income > best.income
    end
    if useRarity then
        local candidateRank = CardPlacementRuntime.getRarityRank(candidate.rarity)
        local bestRank = CardPlacementRuntime.getRarityRank(best.rarity)
        if candidateRank ~= bestRank then
            return candidateRank > bestRank
        end
    end
    if useMutation then
        local candidateRank = CardPlacementRuntime.getMutationRank(candidate.mutation)
        local bestRank = CardPlacementRuntime.getMutationRank(best.mutation)
        if candidateRank ~= bestRank then
            return candidateRank > bestRank
        end
    end
    if not useIncome and candidate.income ~= best.income then
        return candidate.income > best.income
    end
    if candidate.level ~= best.level then
        return candidate.level > best.level
    end
    if candidate.name ~= best.name then
        return candidate.name < best.name
    end
    return tostring(candidate.tool.Name) < tostring(best.tool.Name)
end

function CardPlacementRuntime.initializePriorityPlan(candidates)
    CardPlacementRuntime.resetPriorityPlan()
    local best
    for _, candidate in ipairs(candidates) do
        if CardPlacementRuntime.isCandidateBetter(candidate, best) then
            best = candidate
        end
    end
    State.cardPlacementPriorityInitialized = true
    State.cardPlacementPriorityPhase = "Dynamic Ranking"
    if best then
        State.cardPlacementPriorityRarity = best.rarity
        State.cardPlacementPriorityRarityRank = CardPlacementRuntime.getRarityRank(best.rarity)
        State.cardPlacementPriorityMutation = best.mutation
        State.cardPlacementPriorityMutationRank = CardPlacementRuntime.getMutationRank(best.mutation)
    end
end

function CardPlacementRuntime.matchesPriorityPlan(candidate)
    return candidate ~= nil
end

function CardPlacementRuntime.getToolData(tool)
    if not tool or not tool:IsA("Tool") then
        return nil
    end
    if tool:GetAttribute("IsTemporary") == true or tool:GetAttribute("IsSpawnedItem") == true then
        return nil
    end
    local originalName = tool:GetAttribute("OriginalName")
    if type(originalName) ~= "string" or originalName == "" then
        originalName = tool.Name
    end
    local configuration = Modules.ItemConfigurations
    local data
    if type(configuration) == "table" and type(rawget(configuration, "GetItemData")) == "function" then
        local success, value = pcall(configuration.GetItemData, originalName)
        if success then
            data = value
        end
    end
    if type(data) ~= "table" then
        local items = type(configuration) == "table" and rawget(configuration, "Items") or nil
        data = type(items) == "table" and rawget(items, originalName) or nil
    end
    local baseIncome = type(data) == "table" and tonumber(rawget(data, "Income")) or nil
    if not baseIncome or baseIncome <= 0 then
        return nil
    end
    local mutation = tostring(tool:GetAttribute("Mutation") or "Normal")
    local mutationMultiplier = CardPlacementRuntime.getMutationIncomeMultiplier(mutation)
    local adjustedIncome = baseIncome * mutationMultiplier
    return {
        tool = tool,
        name = originalName,
        income = adjustedIncome,
        baseIncome = baseIncome,
        mutationMultiplier = mutationMultiplier,
        level = math.max(0, tonumber(tool:GetAttribute("Level")) or 0),
        rarity = tostring(tool:GetAttribute("Rarity") or rawget(data, "Rarity") or "Unknown"),
        mutation = mutation,
    }
end

function CardPlacementRuntime.getBestTool()
    local player = Services.Players.LocalPlayer
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        return nil
    end
    local candidates = {}
    for _, tool in ipairs(backpack:GetChildren()) do
        local candidate = CardPlacementRuntime.getToolData(tool)
        if candidate then
            candidates[#candidates + 1] = candidate
        end
    end
    if #candidates == 0 then
        CardPlacementRuntime.resetPriorityPlan()
        return nil
    end
    CardPlacementRuntime.initializePriorityPlan(candidates)
    local best
    for _, candidate in ipairs(candidates) do
        if CardPlacementRuntime.isCandidateBetter(candidate, best) then
            best = candidate
        end
    end
    return best
end

function CardPlacementRuntime.getNextEmptySlot()
    local slots = PlotRuntime.getSlots()
    local now = os.clock()
    for index, entry in ipairs(slots) do
        local prompt = PlotRuntime.getPrompt(entry)
        if PlotRuntime.isUnlocked(entry)
            and not PlotRuntime.getPlacedCardVisual(entry)
            and prompt
            and prompt.Enabled
            and (State.cardPlacementSkipUntil[entry.key] or 0) <= now
        then
            State.cardPlacementCursor = index
            return entry
        end
    end
    State.cardPlacementCursor = 0
    return nil
end

function CardPlacementRuntime.resetLifecycle(status)
    State.cardPlacementNextAt = 0
    State.cardPlacementCursor = 0
    CardPlacementRuntime.resetPriorityPlan()
    State.cardPlacementPending = false
    State.cardPlacementPendingSince = 0
    State.cardPlacementPendingKey = nil
    State.cardPlacementPendingSlot = nil
    State.cardPlacementPendingTool = nil
    State.cardPlacementPendingName = nil
    State.cardPlacementPendingIncome = 0
    State.cardPlacementFailures = 0
    State.cardPlacementPendingTriggerMode = nil
    State.cardPlacementFallbackAttempted = false
    State.cardPlacementLastTriggerMode = "None"
    State.cardPlacementLastPromptError = nil
    State.cardPlacementUnavailableLogged = false
    table.clear(State.cardPlacementSkipUntil)
    State.cardPlacementLastStatus = status or "Idle"
end

function CardPlacementRuntime.setAuto(enabled, save)
    State.autoFillEmptySlots = enabled == true
    if State.autoFillEmptySlots and State.autoPickupPlacedCards then
        State.autoPickupPlacedCards = false
        CardPickupRuntime.resetLifecycle("Disabled by Auto Fill")
    end
    CardPlacementRuntime.resetLifecycle(State.autoFillEmptySlots and "Ready" or "Disabled")
    State.plotStartupGraceUntil = math.max(State.plotStartupGraceUntil, os.clock() + 0.75)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    ConfigRuntime.syncControls()
end

function CardPlacementRuntime.unequip()
    local character = Services.Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid:UnequipTools()
        end)
    end
end

function CardPlacementRuntime.clearPending(status)
    State.cardPlacementPending = false
    State.cardPlacementPendingSince = 0
    State.cardPlacementPendingKey = nil
    State.cardPlacementPendingSlot = nil
    State.cardPlacementPendingTool = nil
    State.cardPlacementPendingName = nil
    State.cardPlacementPendingIncome = 0
    State.cardPlacementPendingTriggerMode = nil
    State.cardPlacementFallbackAttempted = false
    State.cardPlacementLastStatus = status
end

function CardPlacementRuntime.process()
    local now = os.clock()
    if not State.autoFillEmptySlots or State.cardPlacementPending or now < State.cardPlacementNextAt then
        return false
    end
    local entry = CardPlacementRuntime.getNextEmptySlot()
    if not entry then
        CardPlacementRuntime.resetPriorityPlan()
        State.cardPlacementLastStatus = "No Empty Slot Available"
        State.cardPlacementNextAt = now + 2
        return false
    end
    local card = CardPlacementRuntime.getBestTool()
    if not card then
        State.cardPlacementLastStatus = "No Card in Backpack"
        State.cardPlacementNextAt = now + 3
        return false
    end
    local character = Services.Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local prompt = PlotRuntime.getPrompt(entry)
    if not humanoid or not prompt or not prompt.Enabled then
        State.cardPlacementLastStatus = "Character or Prompt Unavailable"
        State.cardPlacementNextAt = now + 2
        PlotRuntime.invalidate("Prompt Changed")
        return false
    end
    local equipSuccess, equipError = pcall(function()
        humanoid:EquipTool(card.tool)
    end)
    if not equipSuccess then
        State.cardPlacementFailures = State.cardPlacementFailures + 1
        State.cardPlacementNextAt = now + State.cardPlacementRetryCooldown
        State.cardPlacementLastStatus = "Equip Failed"
        LogRuntime.add("ERROR", "Card equip failed: " .. tostring(equipError))
        return false
    end
    task.wait(0.12)
    if not card.tool.Parent or card.tool.Parent ~= character then
        State.cardPlacementFailures = State.cardPlacementFailures + 1
        CardPlacementRuntime.unequip()
        State.cardPlacementNextAt = os.clock() + State.cardPlacementRetryCooldown
        State.cardPlacementLastStatus = "Equip Unconfirmed"
        return false
    end
    State.cardPlacementPending = true
    State.cardPlacementPendingSince = os.clock()
    State.cardPlacementPendingKey = entry.key
    State.cardPlacementPendingSlot = entry.slot
    State.cardPlacementPendingTool = card.tool
    State.cardPlacementPendingName = card.name
    State.cardPlacementPendingIncome = card.income
    State.cardPlacementFallbackAttempted = false
    local moveSuccess, moveMode = CardPlacementRuntime.moveToPrompt(prompt)
    if not moveSuccess then
        State.cardPlacementFailures = State.cardPlacementFailures + 1
        State.cardPlacementSkipUntil[entry.key] = os.clock() + State.cardPlacementRetryCooldown
        CardPlacementRuntime.unequip()
        CardPlacementRuntime.clearPending("Teleport Failed")
        State.cardPlacementNextAt = os.clock() + State.cardPlacementRetryCooldown
        LogRuntime.add("ERROR", "Card placement teleport failed: " .. tostring(moveMode))
        return false
    end
    State.cardPlacementLastStatus = "Placement Pending: " .. card.name .. " -> " .. entry.key
    local success, triggerMode = CardPlacementRuntime.triggerPrompt(prompt, true)
    State.cardPlacementPendingTriggerMode = tostring(moveMode) .. " -> " .. tostring(triggerMode)
    local errorMessage = State.cardPlacementLastPromptError or triggerMode
    if not success then
        State.cardPlacementFailures = State.cardPlacementFailures + 1
        State.cardPlacementSkipUntil[entry.key] = os.clock() + State.cardPlacementRetryCooldown
        CardPlacementRuntime.unequip()
        CardPlacementRuntime.clearPending("Prompt Failed")
        State.cardPlacementNextAt = os.clock() + State.cardPlacementRetryCooldown
        LogRuntime.add("ERROR", "Card placement prompt failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function CardPlacementRuntime.tick(allowProcess)
    if not State.autoFillEmptySlots then
        return false
    end
    if State.cardPlacementPending then
        local slot = State.cardPlacementPendingSlot
        local entry = {slot = slot, floor = slot and slot.Parent and slot.Parent.Parent}
        local visual = PlotRuntime.getPlacedCardVisual(entry)
        if visual then
            local name = State.cardPlacementPendingName or tostring(visual:GetAttribute("OriginalName") or "Card")
            local key = State.cardPlacementPendingKey
            local income = State.cardPlacementPendingIncome
            State.cardPlacementFailures = 0
            CardPlacementRuntime.clearPending("Placement Confirmed")
            CardPlacementRuntime.unequip()
            State.cardPlacementNextAt = os.clock() + State.cardPlacementCooldown
            PlotRuntime.invalidate("Slot Filled")
            LogRuntime.add("SUCCESS", string.format("Card placed: %s (mutation-adjusted %s/s) at %s", name, string.format("%g", income), tostring(key)))
            return true
        end
        local elapsed = os.clock() - State.cardPlacementPendingSince
        local tool = State.cardPlacementPendingTool
        local character = Services.Players.LocalPlayer.Character
        if not State.cardPlacementFallbackAttempted
            and elapsed >= State.cardPlacementFallbackDelay
            and tool
            and tool.Parent == character
        then
            local prompt = slot and PlotRuntime.getPrompt({slot = slot, floor = slot.Parent and slot.Parent.Parent}) or nil
            if prompt and prompt.Enabled then
                State.cardPlacementFallbackAttempted = true
                local primaryMode = State.cardPlacementPendingTriggerMode
                local moveSuccess, moveMode = CardPlacementRuntime.moveToPrompt(prompt)
                local retrySuccess, retryMode = false, moveMode
                if moveSuccess then
                    retrySuccess, retryMode = CardPlacementRuntime.triggerPrompt(prompt, true)
                end
                if retrySuccess then
                    State.cardPlacementPendingTriggerMode = tostring(primaryMode) .. " -> " .. tostring(moveMode) .. " -> " .. tostring(retryMode)
                    State.cardPlacementLastStatus = "Placement Retry: " .. tostring(retryMode)
                else
                    State.cardPlacementLastStatus = "Placement Trigger Failed"
                end
            end
        end
        if elapsed >= State.cardPlacementPendingTimeout then
            local key = State.cardPlacementPendingKey
            State.cardPlacementFailures = State.cardPlacementFailures + 1
            if key then
                State.cardPlacementSkipUntil[key] = os.clock() + State.cardPlacementRetryCooldown
            end
            CardPlacementRuntime.unequip()
            CardPlacementRuntime.clearPending("Placement Unconfirmed")
            State.cardPlacementNextAt = os.clock() + State.cardPlacementRetryCooldown
        end
        return false
    end
    if allowProcess == false then
        return false
    end
    return CardPlacementRuntime.process()
end

function CardPlacementRuntime.getState()
    local best = CardPlacementRuntime.getBestTool()
    return {
        enabled = State.autoFillEmptySlots,
        pending = State.cardPlacementPending,
        pendingKey = State.cardPlacementPendingKey,
        pendingCard = State.cardPlacementPendingName,
        bestBackpackCard = best and best.name or nil,
        bestBackpackBaseIncome = best and best.baseIncome or nil,
        bestBackpackMutationMultiplier = best and best.mutationMultiplier or nil,
        bestBackpackAdjustedIncome = best and best.income or nil,
        priorities = CardPlacementRuntime.getPriorities(),
        priorityPhase = State.cardPlacementPriorityPhase,
        priorityRarity = State.cardPlacementPriorityRarity,
        priorityMutation = State.cardPlacementPriorityMutation,
        failures = State.cardPlacementFailures,
        lastStatus = State.cardPlacementLastStatus,
        fireproximitypromptAvailable = CardPlacementRuntime.getPromptCallback(false) ~= nil,
        nativePromptFallbackAvailable = true,
        pendingTriggerMode = State.cardPlacementPendingTriggerMode,
        lastTriggerMode = State.cardPlacementLastTriggerMode,
        lastPromptError = State.cardPlacementLastPromptError,
        cachedSlots = #State.plotCache,
    }
end


function CardPickupRuntime.getNextOccupiedSlot()
    local now = os.clock()
    for _, entry in ipairs(PlotRuntime.getSlots()) do
        local skipUntil = State.cardPickupSkipUntil[entry.key] or 0
        local visual = PlotRuntime.getPlacedCardVisual(entry)
        local prompt = visual and PlotRuntime.getPrompt(entry) or nil
        if PlotRuntime.isUnlocked(entry)
            and now >= skipUntil
            and visual
            and prompt
            and prompt.Enabled
        then
            return entry, visual, prompt
        end
    end
    return nil, nil, nil
end

function CardPickupRuntime.resetLifecycle(status)
    State.cardPickupNextAt = 0
    State.cardPickupPending = false
    State.cardPickupPendingSince = 0
    State.cardPickupPendingKey = nil
    State.cardPickupPendingSlot = nil
    State.cardPickupPendingVisual = nil
    State.cardPickupPendingName = nil
    State.cardPickupPendingTriggerMode = nil
    State.cardPickupFallbackAttempted = false
    State.cardPickupFailures = 0
    State.cardPickupLastStatus = status or "Idle"
end

function CardPickupRuntime.setAuto(enabled, save)
    State.autoPickupPlacedCards = enabled == true
    if State.autoPickupPlacedCards and State.autoFillEmptySlots then
        State.autoFillEmptySlots = false
        CardPlacementRuntime.resetLifecycle("Disabled by Auto Pickup")
        CardPlacementRuntime.unequip()
    end
    CardPickupRuntime.resetLifecycle(State.autoPickupPlacedCards and "Ready" or "Disabled")
    State.plotStartupGraceUntil = math.max(State.plotStartupGraceUntil, os.clock() + 0.75)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    ConfigRuntime.syncControls()
end

function CardPickupRuntime.clearPending(status)
    State.cardPickupPending = false
    State.cardPickupPendingSince = 0
    State.cardPickupPendingKey = nil
    State.cardPickupPendingSlot = nil
    State.cardPickupPendingVisual = nil
    State.cardPickupPendingName = nil
    State.cardPickupPendingTriggerMode = nil
    State.cardPickupFallbackAttempted = false
    State.cardPickupLastStatus = status
end

function CardPickupRuntime.process()
    local now = os.clock()
    if not State.autoPickupPlacedCards or State.cardPickupPending or now < State.cardPickupNextAt then
        return false
    end
    local player = Services.Players.LocalPlayer
    if player:GetAttribute("LuckyBlockActivityActive") == true then
        State.cardPickupLastStatus = "Waiting for Kick Activity"
        State.cardPickupNextAt = now + 1
        return false
    end
    local entry, visual, prompt = CardPickupRuntime.getNextOccupiedSlot()
    if not entry then
        State.cardPickupLastStatus = "No Placed Card Available"
        State.cardPickupNextAt = now + 2
        return false
    end
    CardPlacementRuntime.unequip()
    task.wait(0.12)
    local name = tostring(visual:GetAttribute("OriginalName") or visual.Name or "Card")
    State.cardPickupPending = true
    State.cardPickupPendingSince = os.clock()
    State.cardPickupPendingKey = entry.key
    State.cardPickupPendingSlot = entry.slot
    State.cardPickupPendingVisual = visual
    State.cardPickupPendingName = name
    State.cardPickupFallbackAttempted = false
    local moveSuccess, moveMode = CardPlacementRuntime.moveToPrompt(prompt)
    if not moveSuccess then
        State.cardPickupFailures = State.cardPickupFailures + 1
        State.cardPickupSkipUntil[entry.key] = os.clock() + State.cardPickupRetryCooldown
        CardPickupRuntime.clearPending("Teleport Failed")
        State.cardPickupNextAt = os.clock() + State.cardPickupRetryCooldown
        LogRuntime.add("ERROR", "Card pickup teleport failed: " .. tostring(moveMode))
        return false
    end
    local success, triggerMode = CardPlacementRuntime.triggerPrompt(prompt, true)
    State.cardPickupPendingTriggerMode = tostring(moveMode) .. " -> " .. tostring(triggerMode)
    if not success then
        State.cardPickupFailures = State.cardPickupFailures + 1
        State.cardPickupSkipUntil[entry.key] = os.clock() + State.cardPickupRetryCooldown
        CardPickupRuntime.clearPending("Prompt Failed")
        State.cardPickupNextAt = os.clock() + State.cardPickupRetryCooldown
        LogRuntime.add("ERROR", "Card pickup prompt failed: " .. tostring(triggerMode))
        return false
    end
    State.cardPickupLastStatus = "Pickup Pending: " .. name .. " <- " .. entry.key
    return true
end

function CardPickupRuntime.tick(allowProcess)
    if not State.autoPickupPlacedCards then
        return false
    end
    if State.cardPickupPending then
        local slot = State.cardPickupPendingSlot
        local entry = {slot = slot, floor = slot and slot.Parent and slot.Parent.Parent}
        local visual = PlotRuntime.getPlacedCardVisual(entry)
        if not visual or visual ~= State.cardPickupPendingVisual then
            local name = State.cardPickupPendingName or "Card"
            local key = State.cardPickupPendingKey
            State.cardPickupFailures = 0
            CardPickupRuntime.clearPending("Pickup Confirmed")
            State.cardPickupNextAt = os.clock() + State.cardPickupCooldown
            PlotRuntime.invalidate("Slot Card Picked Up")
            LogRuntime.add("SUCCESS", "Card picked up: " .. tostring(name) .. " from " .. tostring(key))
            return true
        end
        local elapsed = os.clock() - State.cardPickupPendingSince
        if not State.cardPickupFallbackAttempted and elapsed >= State.cardPickupFallbackDelay then
            local prompt = slot and PlotRuntime.getPrompt(entry) or nil
            if prompt and prompt.Enabled then
                State.cardPickupFallbackAttempted = true
                CardPlacementRuntime.unequip()
                local moveSuccess, moveMode = CardPlacementRuntime.moveToPrompt(prompt)
                local retrySuccess, retryMode = false, moveMode
                if moveSuccess then
                    retrySuccess, retryMode = CardPlacementRuntime.triggerPrompt(prompt, true)
                end
                if retrySuccess then
                    State.cardPickupPendingTriggerMode = tostring(State.cardPickupPendingTriggerMode) .. " -> " .. tostring(moveMode) .. " -> " .. tostring(retryMode)
                    State.cardPickupLastStatus = "Pickup Retry: " .. tostring(retryMode)
                else
                    State.cardPickupLastStatus = "Pickup Trigger Failed"
                end
            end
        end
        if elapsed >= State.cardPickupPendingTimeout then
            local key = State.cardPickupPendingKey
            State.cardPickupFailures = State.cardPickupFailures + 1
            if key then
                State.cardPickupSkipUntil[key] = os.clock() + State.cardPickupRetryCooldown
            end
            CardPickupRuntime.clearPending("Pickup Unconfirmed")
            State.cardPickupNextAt = os.clock() + State.cardPickupRetryCooldown
        end
        return false
    end
    if allowProcess == false then
        return false
    end
    return CardPickupRuntime.process()
end

function CardPickupRuntime.getState()
    return {
        enabled = State.autoPickupPlacedCards,
        pending = State.cardPickupPending,
        pendingKey = State.cardPickupPendingKey,
        pendingCard = State.cardPickupPendingName,
        failures = State.cardPickupFailures,
        lastStatus = State.cardPickupLastStatus,
        pendingTriggerMode = State.cardPickupPendingTriggerMode,
        cachedSlots = #State.plotCache,
    }
end

function PlotRuntime.tick()
    if not State.autoUpgradePlacedCards
        and not State.autoFillEmptySlots
        and not State.autoPickupPlacedCards
    then
        return
    end
    local now = os.clock()
    if now < State.plotStartupGraceUntil then
        return
    end
    PlotRuntime.refreshCache(false)
    if State.cardUpgradePending then
        CardUpgradeRuntime.tick(false)
    end
    if State.cardPlacementPending then
        CardPlacementRuntime.tick(false)
    end
    if State.cardPickupPending then
        CardPickupRuntime.tick(false)
    end
    if State.cardUpgradePending or State.cardPlacementPending or State.cardPickupPending then
        return
    end
    if now < State.plotNextActionAt then
        return
    end
    for _ = 1, 3 do
        State.plotFeatureCursor = State.plotFeatureCursor % 3 + 1
        local acted = false
        if State.plotFeatureCursor == 1 and State.autoUpgradePlacedCards then
            acted = CardUpgradeRuntime.tick(true)
        elseif State.plotFeatureCursor == 2 and State.autoFillEmptySlots then
            acted = CardPlacementRuntime.tick(true)
        elseif State.plotFeatureCursor == 3 and State.autoPickupPlacedCards then
            acted = CardPickupRuntime.tick(true)
        end
        if acted then
            State.plotNextActionAt = os.clock() + State.plotActionGap
            return
        end
    end
    State.plotNextActionAt = now + 0.05
end

function PlotRuntime.getState()
    return {
        cachedSlots = #State.plotCache,
        cacheGeneration = State.plotCacheGeneration,
        cacheStatus = State.plotCacheLastStatus,
        cacheRefreshRemaining = math.max(0, State.plotCacheNextAt - os.clock()),
        startupGraceRemaining = math.max(0, State.plotStartupGraceUntil - os.clock()),
    }
end

function SpeedUpgradeRuntime.onUpdate(payload)
    if type(payload) ~= "table" then
        return
    end
    local speed = rawget(payload, "Speed")
    if type(speed) ~= "table" then
        return
    end
    local current = tonumber(rawget(speed, "Current"))
    local cost = tonumber(rawget(speed, "Cost"))
    if current then
        State.speedUpgradeCurrent = current
    end
    if cost then
        State.speedUpgradeCost = cost
    end
    State.speedUpgradeLastRefreshAt = os.clock()
    if State.speedUpgradePending and current and current > State.speedUpgradeBeforeLevel then
        local oldLevel = State.speedUpgradeBeforeLevel
        State.speedUpgradePending = false
        State.speedUpgradePendingSince = 0
        State.speedUpgradeBeforeLevel = 0
        State.speedUpgradeFailures = 0
        State.speedUpgradeNextAt = os.clock() + State.speedUpgradeCooldown
        State.speedUpgradeLastStatus = "Upgrade Confirmed"
        task.defer(SpeedUpgradeRuntime.process)
        if State.speedUpgradeTargetLevel > 0 and current >= State.speedUpgradeTargetLevel then
            LogRuntime.add("SUCCESS", string.format("Speed target reached: %d", current))
        elseif current % 10 == 0 or current - oldLevel > 1 then
            LogRuntime.add("SUCCESS", string.format("Speed upgraded to %d", current))
        end
    end
end

function SpeedUpgradeRuntime.refresh()
    local remote = State.updateUpgradesUI
    if not remote or not remote:IsA("RemoteEvent") then
        return false
    end
    local success, errorMessage = pcall(function()
        remote:FireServer()
    end)
    if not success then
        LogRuntime.add("ERROR", "Speed upgrade state request failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function SpeedUpgradeRuntime.resetLifecycle(status)
    State.speedUpgradeNextAt = 0
    State.speedUpgradePending = false
    State.speedUpgradePendingSince = 0
    State.speedUpgradeBeforeLevel = 0
    State.speedUpgradeFailures = 0
    State.speedUpgradeLastStatus = status or "Idle"
end

function SpeedUpgradeRuntime.setTargetLevel(value, save)
    State.speedUpgradeTargetLevel = normalizeTargetLevel(value)
    SpeedUpgradeRuntime.resetLifecycle(State.autoUpgradeSpeed and "Ready" or "Disabled")
    SpeedUpgradeRuntime.refresh()
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function SpeedUpgradeRuntime.setAuto(enabled, save)
    State.autoUpgradeSpeed = enabled == true
    SpeedUpgradeRuntime.resetLifecycle(State.autoUpgradeSpeed and "Ready" or "Disabled")
    if State.autoUpgradeSpeed then
        SpeedUpgradeRuntime.refresh()
        task.defer(SpeedUpgradeRuntime.process)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function SpeedUpgradeRuntime.process()
    if not State.autoUpgradeSpeed or State.speedUpgradePending or os.clock() < State.speedUpgradeNextAt then
        return false
    end
    local current = State.speedUpgradeCurrent
    if current == nil then
        SpeedUpgradeRuntime.refresh()
        State.speedUpgradeLastStatus = "Waiting for State"
        State.speedUpgradeNextAt = os.clock() + 1
        return false
    end
    if State.speedUpgradeTargetLevel > 0 and current >= State.speedUpgradeTargetLevel then
        State.speedUpgradeLastStatus = "Speed Target Reached"
        return false
    end
    local remote = State.purchaseUpgrade
    if not remote or not remote:IsA("RemoteEvent") then
        State.speedUpgradeLastStatus = "Remote Unavailable"
        return false
    end
    State.speedUpgradePending = true
    State.speedUpgradePendingSince = os.clock()
    State.speedUpgradeBeforeLevel = current
    State.speedUpgradeLastStatus = "Upgrade Pending"
    local success, errorMessage = pcall(function()
        remote:FireServer("Speed", 1)
    end)
    if not success then
        State.speedUpgradePending = false
        State.speedUpgradePendingSince = 0
        State.speedUpgradeFailures = State.speedUpgradeFailures + 1
        State.speedUpgradeNextAt = os.clock() + math.min(20, State.speedUpgradeRetryCooldown + State.speedUpgradeFailures)
        State.speedUpgradeLastStatus = "Request Failed"
        LogRuntime.add("ERROR", "Speed upgrade request failed: " .. tostring(errorMessage))
        return false
    end
    return true
end

function SpeedUpgradeRuntime.tick()
    if not State.autoUpgradeSpeed then
        return
    end
    if State.speedUpgradePending then
        if os.clock() - State.speedUpgradePendingSince >= State.speedUpgradePendingTimeout then
            State.speedUpgradePending = false
            State.speedUpgradePendingSince = 0
            State.speedUpgradeBeforeLevel = 0
            State.speedUpgradeFailures = State.speedUpgradeFailures + 1
            State.speedUpgradeNextAt = os.clock() + math.min(30, State.speedUpgradeRetryCooldown + State.speedUpgradeFailures * 2)
            State.speedUpgradeLastStatus = "Upgrade Unconfirmed"
            SpeedUpgradeRuntime.refresh()
        end
        return
    end
    SpeedUpgradeRuntime.process()
end

function SpeedUpgradeRuntime.bind()
    local remote = State.updateUpgradesUI
    if not remote or not remote:IsA("RemoteEvent") then
        return false
    end
    ConnectionRuntime.disconnect("speedUpgradeUpdateConnection")
    State.speedUpgradeUpdateConnection = remote.OnClientEvent:Connect(SpeedUpgradeRuntime.onUpdate)
    SpeedUpgradeRuntime.refresh()
    return true
end

function SpeedUpgradeRuntime.getState()
    return {
        enabled = State.autoUpgradeSpeed,
        targetLevel = State.speedUpgradeTargetLevel,
        current = State.speedUpgradeCurrent,
        cost = State.speedUpgradeCost,
        pending = State.speedUpgradePending,
        failures = State.speedUpgradeFailures,
        lastStatus = State.speedUpgradeLastStatus,
        updateConnected = State.speedUpgradeUpdateConnection ~= nil,
    }
end


function KickRewardRuntime.buildFilterCatalog()
    table.clear(State.kickRewardCardNameNames)
    table.clear(State.kickRewardCardNameSet)
    State.kickRewardCardNameNames[1] = "None"
    State.kickRewardCardNameSet.None = true
    local configuration = Modules.ItemConfigurations
    local items = type(configuration) == "table" and rawget(configuration, "Items") or nil
    if type(items) == "table" then
        local names = {}
        for name, data in pairs(items) do
            if type(name) == "string" and type(data) == "table" and tonumber(rawget(data, "Income")) then
                names[#names + 1] = name
            end
        end
        table.sort(names, function(a, b)
            return string.lower(a) < string.lower(b)
        end)
        for _, name in ipairs(names) do
            State.kickRewardCardNameNames[#State.kickRewardCardNameNames + 1] = name
            State.kickRewardCardNameSet[name] = true
        end
    end
    table.clear(State.kickRewardRarityNames)
    table.clear(State.kickRewardRaritySet)
    State.kickRewardRarityNames[1] = "None"
    State.kickRewardRaritySet.None = true
    for _, rarity in ipairs(State.cardUpgradeRarityNames) do
        State.kickRewardRarityNames[#State.kickRewardRarityNames + 1] = rarity
        State.kickRewardRaritySet[rarity] = true
    end
    table.clear(State.kickRewardMutationNames)
    table.clear(State.kickRewardMutationSet)
    State.kickRewardMutationNames[1] = "None"
    State.kickRewardMutationSet.None = true
    for _, mutation in ipairs(State.cardPlacementMutationNames) do
        State.kickRewardMutationNames[#State.kickRewardMutationNames + 1] = mutation
        State.kickRewardMutationSet[mutation] = true
    end
    return #State.kickRewardCardNameNames > 1
end

function KickRewardRuntime.normalizeWhitelist(source, allowed)
    local selected = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local name
            if type(key) == "number" and type(value) == "string" then
                name = value
            elseif type(key) == "string" and value == true then
                name = key
            end
            if name and allowed[name] then
                selected[name] = true
            end
        end
    elseif type(source) == "string" and allowed[source] then
        selected[source] = true
    end
    if selected.None == true or next(selected) == nil then
        return {None = true}
    end
    return selected
end

function KickRewardRuntime.applyWhitelist(source, target, allowed)
    local normalized = KickRewardRuntime.normalizeWhitelist(source, allowed)
    table.clear(target)
    for name in pairs(normalized) do
        target[name] = true
    end
end

function KickRewardRuntime.getWhitelist(source, order)
    if source.None == true then
        return {"None"}
    end
    local result = {}
    for _, name in ipairs(order) do
        if name ~= "None" and source[name] == true then
            result[#result + 1] = name
        end
    end
    if #result == 0 then
        return {"None"}
    end
    return result
end

function KickRewardRuntime.getCardNameWhitelist()
    return KickRewardRuntime.getWhitelist(State.kickRewardCardNameWhitelist, State.kickRewardCardNameNames)
end

function KickRewardRuntime.getRarityWhitelist()
    return KickRewardRuntime.getWhitelist(State.kickRewardRarityWhitelist, State.kickRewardRarityNames)
end

function KickRewardRuntime.getMutationWhitelist()
    return KickRewardRuntime.getWhitelist(State.kickRewardMutationWhitelist, State.kickRewardMutationNames)
end

function KickRewardRuntime.resetDecision(status)
    State.kickRewardFilterDecision = nil
    State.kickRewardFilterDecisionReason = status or "Not Evaluated"
    State.kickRewardFilterDecisionLogged = false
    State.kickRewardFilterWaitSince = 0
    State.kickRewardCurrentPreview = nil
    State.kickRewardRejecting = false
end

function KickRewardRuntime.setThreshold(value, save)
    State.kickRewardFilterThreshold = normalizeKickRewardThreshold(value)
    KickRewardRuntime.resetDecision("Filter Updated")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    return State.kickRewardFilterThreshold
end

function KickRewardRuntime.setCardNameWhitelist(value, save)
    KickRewardRuntime.applyWhitelist(value, State.kickRewardCardNameWhitelist, State.kickRewardCardNameSet)
    KickRewardRuntime.resetDecision("Filter Updated")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    return KickRewardRuntime.getCardNameWhitelist()
end

function KickRewardRuntime.setRarityWhitelist(value, save)
    KickRewardRuntime.applyWhitelist(value, State.kickRewardRarityWhitelist, State.kickRewardRaritySet)
    KickRewardRuntime.resetDecision("Filter Updated")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    return KickRewardRuntime.getRarityWhitelist()
end

function KickRewardRuntime.setMutationWhitelist(value, save)
    KickRewardRuntime.applyWhitelist(value, State.kickRewardMutationWhitelist, State.kickRewardMutationSet)
    KickRewardRuntime.resetDecision("Filter Updated")
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    return KickRewardRuntime.getMutationWhitelist()
end

function KickRewardRuntime.isCriterionActive(whitelist)
    if type(whitelist) ~= "table" or whitelist.None == true then
        return false
    end
    return next(whitelist) ~= nil
end

function KickRewardRuntime.isFilterActive()
    if State.kickRewardFilterThreshold == "None" then
        return false
    end
    return KickRewardRuntime.isCriterionActive(State.kickRewardCardNameWhitelist)
        or KickRewardRuntime.isCriterionActive(State.kickRewardRarityWhitelist)
        or KickRewardRuntime.isCriterionActive(State.kickRewardMutationWhitelist)
end

function KickRewardRuntime.containsInsensitive(whitelist, value)
    if type(whitelist) ~= "table" then
        return false
    end
    value = string.lower(tostring(value or ""))
    for name, selected in pairs(whitelist) do
        if selected == true and name ~= "None" and string.lower(tostring(name)) == value then
            return true
        end
    end
    return false
end

function KickRewardRuntime.resolveDisplayValue(configurations, value)
    local text = tostring(value or "")
    if type(configurations) ~= "table" then
        return text
    end
    for name, data in pairs(configurations) do
        if type(name) == "string" and type(data) == "table" then
            local displayName = tostring(rawget(data, "DisplayName") or name)
            if string.lower(displayName) == string.lower(text) then
                return name
            end
        end
    end
    return text
end

function KickRewardRuntime.readTextLabel(labels, name)
    local label = labels and labels:FindFirstChild(name) or nil
    if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
        local text = tostring(label.Text or "")
        if text ~= "" then
            return text
        end
    end
    return nil
end

function KickRewardRuntime.getPreviewModel()
    local player = Services.Players.LocalPlayer
    local character = player and player.Character
    local active = character and character:FindFirstChild("ActiveMorph") or nil
    if active and active:IsA("Model") then
        return active
    end
    local workspacePreview = Services.Workspace:FindFirstChild("HatchedItem")
    if workspacePreview and workspacePreview:IsA("Model") then
        return workspacePreview
    end
    return nil
end

function KickRewardRuntime.readPreview()
    local model = KickRewardRuntime.getPreviewModel()
    if not model then
        return nil
    end
    local infoGui = model:FindFirstChild("InfoGUI")
    local labels = infoGui and infoGui:FindFirstChild("TextLabels") or nil
    if not labels then
        return nil
    end
    local name = KickRewardRuntime.readTextLabel(labels, "Name")
    local rarity = KickRewardRuntime.readTextLabel(labels, "Rarity")
    local mutation = KickRewardRuntime.readTextLabel(labels, "Mutation")
    if not name or not rarity or not mutation then
        return nil
    end
    rarity = KickRewardRuntime.resolveDisplayValue(Modules.RarityConfigurations, rarity)
    mutation = KickRewardRuntime.resolveDisplayValue(Modules.MutationConfigurations, mutation)
    return {
        model = model,
        name = name,
        rarity = rarity,
        mutation = mutation,
    }
end

function KickRewardRuntime.evaluate(preview)
    if not KickRewardRuntime.isFilterActive() then
        return true, "Whitelist Disabled"
    end
    if not preview then
        return nil, "Waiting for Card Preview"
    end
    local tests = {}
    if KickRewardRuntime.isCriterionActive(State.kickRewardCardNameWhitelist) then
        tests[#tests + 1] = KickRewardRuntime.containsInsensitive(State.kickRewardCardNameWhitelist, preview.name)
    end
    if KickRewardRuntime.isCriterionActive(State.kickRewardRarityWhitelist) then
        tests[#tests + 1] = KickRewardRuntime.containsInsensitive(State.kickRewardRarityWhitelist, preview.rarity)
    end
    if KickRewardRuntime.isCriterionActive(State.kickRewardMutationWhitelist) then
        tests[#tests + 1] = KickRewardRuntime.containsInsensitive(State.kickRewardMutationWhitelist, preview.mutation)
    end
    if #tests == 0 then
        return true, "No Active Whitelist"
    end
    if State.kickRewardFilterThreshold == "AND" then
        for _, matched in ipairs(tests) do
            if not matched then
                return false, "AND Threshold Not Matched"
            end
        end
        return true, "AND Threshold Matched"
    end
    for _, matched in ipairs(tests) do
        if matched then
            return true, "OR Threshold Matched"
        end
    end
    return false, "OR Threshold Not Matched"
end

function KickRewardRuntime.updateDecision()
    if State.kickRewardFilterDecision ~= nil then
        return State.kickRewardFilterDecision, State.kickRewardCurrentPreview
    end
    local preview = KickRewardRuntime.readPreview()
    State.kickRewardCurrentPreview = preview
    local decision, reason = KickRewardRuntime.evaluate(preview)
    State.kickRewardFilterDecision = decision
    State.kickRewardFilterDecisionReason = reason
    if decision ~= nil and not State.kickRewardFilterDecisionLogged then
        State.kickRewardFilterDecisionLogged = true
        State.kickRewardLastDecision = decision
        State.kickRewardLastDecisionReason = reason
        if KickRewardRuntime.isFilterActive() then
            local details = preview and string.format(
                "%s | Rarity: %s | Mutation: %s | Threshold: %s",
                tostring(preview.name),
                tostring(preview.rarity),
                tostring(preview.mutation),
                tostring(State.kickRewardFilterThreshold)
            ) or "Unknown card"
            if decision then
                State.kickRewardAcceptedCount = State.kickRewardAcceptedCount + 1
                LogRuntime.add("FILTER", "Kick card accepted: " .. details)
            else
                State.kickRewardRejectedCount = State.kickRewardRejectedCount + 1
                LogRuntime.add("FILTER", "Kick card rejected: " .. details .. " | Running toward tsunami")
            end
        end
    end
    return decision, preview
end

function KickRewardRuntime.isKickWindowActive()
    local player = Services.Players.LocalPlayer
    return State.kickRewardAwaitingCard
        or (player and player:GetAttribute("LuckyBlockActivityActive") == true)
        or os.clock() <= State.kickRewardWindowUntil
end

function KickRewardRuntime.getZone(tool)
    local attributes = {"Zone", "ZoneId", "SourceZone", "RewardZone"}
    for _, name in ipairs(attributes) do
        local value = tool:GetAttribute(name)
        if value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    if State.kickSecretTargetReached and State.kickSecretTargetZone then
        return tostring(State.kickSecretTargetZone.Name)
    end
    return nil
end

function KickRewardRuntime.inspectTool(tool)
    if not tool or not tool.Parent or not tool:IsA("Tool") then
        return false
    end
    if State.kickRewardSeenTools[tool] then
        return false
    end
    local card = CardPlacementRuntime.getToolData(tool)
    if not card or not KickRewardRuntime.isKickWindowActive() then
        return false
    end
    State.kickRewardSeenTools[tool] = true
    State.kickRewardAwaitingCard = false
    State.kickRewardLoggedCount = State.kickRewardLoggedCount + 1
    State.kickRewardLastCard = card.name
    State.kickRewardLastRarity = card.rarity
    State.kickRewardLastMutation = card.mutation
    State.kickRewardLastLevel = card.level
    State.kickRewardLastIncome = card.income
    State.kickRewardLastZone = KickRewardRuntime.getZone(tool)
    State.kickRewardLastStatus = "Kick Card Logged"
    local details = string.format(
        "Kick card obtained: %s | Rarity: %s | Mutation: %s | Level: %d | Base Income: %s/s",
        tostring(card.name),
        tostring(card.rarity),
        tostring(card.mutation),
        math.floor(tonumber(card.level) or 0),
        formatCompactNumber(card.income)
    )
    if State.kickRewardLastZone then
        details = details .. " | Zone: " .. tostring(State.kickRewardLastZone)
    end
    LogRuntime.add("REWARD", details)
    return true
end

function KickRewardRuntime.queueTool(tool)
    if not tool or not tool:IsA("Tool") or State.kickRewardPendingTools[tool] or State.kickRewardSeenTools[tool] then
        return
    end
    State.kickRewardPendingTools[tool] = true
    task.delay(0.12, function()
        State.kickRewardPendingTools[tool] = nil
        KickRewardRuntime.inspectTool(tool)
    end)
end

function KickRewardRuntime.bindCharacter(character)
    ConnectionRuntime.disconnect("kickRewardCharacterToolConnection")
    if character then
        State.kickRewardCharacterToolConnection = character.ChildAdded:Connect(KickRewardRuntime.queueTool)
    end
end

function KickRewardRuntime.bind()
    local player = Services.Players.LocalPlayer
    if not player then
        return false
    end
    ConnectionRuntime.disconnect("kickRewardActivityConnection")
    ConnectionRuntime.disconnect("kickRewardBackpackConnection")
    ConnectionRuntime.disconnect("kickRewardCharacterAddedConnection")
    ConnectionRuntime.disconnect("kickRewardCharacterToolConnection")
    State.kickRewardActivityConnection = player:GetAttributeChangedSignal("LuckyBlockActivityActive"):Connect(function()
        if player:GetAttribute("LuckyBlockActivityActive") == true then
            KickRewardRuntime.resetDecision("Waiting for Card Preview")
            State.kickRewardActivityCount = State.kickRewardActivityCount + 1
            State.kickRewardAwaitingCard = true
            State.kickRewardWindowUntil = os.clock() + 120
            State.kickRewardLastStatus = "Waiting for Kick Card"
        else
            if State.kickRewardFilterDecision == false or State.kickRewardRejecting then
                State.kickRewardAwaitingCard = false
                State.kickRewardWindowUntil = 0
                State.kickRewardLastStatus = "Kick Card Rejected"
            else
                State.kickRewardWindowUntil = math.max(State.kickRewardWindowUntil, os.clock() + 20)
            end
        end
    end)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
    if backpack then
        State.kickRewardBackpackConnection = backpack.ChildAdded:Connect(KickRewardRuntime.queueTool)
    end
    State.kickRewardCharacterAddedConnection = player.CharacterAdded:Connect(KickRewardRuntime.bindCharacter)
    KickRewardRuntime.bindCharacter(player.Character)
    if player:GetAttribute("LuckyBlockActivityActive") == true then
        KickRewardRuntime.resetDecision("Waiting for Card Preview")
        State.kickRewardActivityCount = State.kickRewardActivityCount + 1
        State.kickRewardAwaitingCard = true
        State.kickRewardWindowUntil = os.clock() + 120
    end
    return true
end

function KickRewardRuntime.getState()
    return {
        awaitingCard = State.kickRewardAwaitingCard,
        activityCount = State.kickRewardActivityCount,
        loggedCount = State.kickRewardLoggedCount,
        lastStatus = State.kickRewardLastStatus,
        lastCard = State.kickRewardLastCard,
        lastRarity = State.kickRewardLastRarity,
        lastMutation = State.kickRewardLastMutation,
        lastLevel = State.kickRewardLastLevel,
        lastBaseIncome = State.kickRewardLastIncome,
        lastZone = State.kickRewardLastZone,
        filterThreshold = State.kickRewardFilterThreshold,
        cardNameWhitelist = KickRewardRuntime.getCardNameWhitelist(),
        rarityWhitelist = KickRewardRuntime.getRarityWhitelist(),
        mutationWhitelist = KickRewardRuntime.getMutationWhitelist(),
        filterActive = KickRewardRuntime.isFilterActive(),
        currentPreview = State.kickRewardCurrentPreview,
        currentDecision = State.kickRewardFilterDecision,
        currentDecisionReason = State.kickRewardFilterDecisionReason,
        accepting = State.kickRewardFilterDecision == true,
        rejecting = State.kickRewardRejecting,
        acceptedCount = State.kickRewardAcceptedCount,
        rejectedCount = State.kickRewardRejectedCount,
        lastDecision = State.kickRewardLastDecision,
        lastDecisionReason = State.kickRewardLastDecisionReason,
        activityConnected = State.kickRewardActivityConnection ~= nil,
        backpackConnected = State.kickRewardBackpackConnection ~= nil,
    }
end

function KickRuntime.getCharacterParts()
    local player = Services.Players.LocalPlayer
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not root or not root:IsA("BasePart") then
        return nil, nil, nil
    end
    return character, humanoid, root
end

function KickRuntime.isInsidePart(root, part)
    if not root or not part or not part:IsA("BasePart") then
        return false
    end
    local localPosition = part.CFrame:PointToObjectSpace(root.Position)
    local size = part.Size
    return math.abs(localPosition.X) <= size.X / 2
        and math.abs(localPosition.Y) <= size.Y / 2 + 15
        and math.abs(localPosition.Z) <= size.Z / 2
end

function KickRuntime.getGui()
    local player = Services.Players.LocalPlayer
    local playerGui = player and player:FindFirstChild("PlayerGui")
    local gui = playerGui and playerGui:FindFirstChild("GUI")
    local hud = gui and gui:FindFirstChild("HUD")
    local kick = hud and hud:FindFirstChild("Kick")
    local powerBar = hud and hud:FindFirstChild("PowerBar")
    local bar = powerBar and powerBar:FindFirstChild("Bar")
    return kick, powerBar, bar
end

function KickRuntime.resolveFireSignal()
    if State.kickSecretFireSignalResolved then
        return State.kickSecretFireSignalCallback
    end
    State.kickSecretFireSignalResolved = true
    local environments = {_G}
    if type(getgenv) == "function" then
        local success, environment = pcall(getgenv)
        if success and type(environment) == "table" then
            environments[#environments + 1] = environment
        end
    end
    if type(getrenv) == "function" then
        local success, environment = pcall(getrenv)
        if success and type(environment) == "table" then
            environments[#environments + 1] = environment
        end
    end
    if type(getfenv) == "function" then
        local success, environment = pcall(getfenv)
        if success and type(environment) == "table" then
            environments[#environments + 1] = environment
        end
    end
    for _, environment in ipairs(environments) do
        local callback = rawget(environment, "firesignal")
        if type(callback) == "function" then
            State.kickSecretFireSignalCallback = callback
            return callback
        end
    end
    return nil
end

function KickRuntime.sendMouseClick(x, y)
    local input = Services.VirtualInputManager
    if not input then
        return false, "VirtualInputManager unavailable"
    end
    local viewport = Services.Workspace.CurrentCamera and Services.Workspace.CurrentCamera.ViewportSize
    x = tonumber(x) or (viewport and viewport.X / 2) or 400
    y = tonumber(y) or (viewport and viewport.Y / 2) or 300
    local success, errorMessage = pcall(function()
        input:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.025)
        input:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    return success, errorMessage
end

function KickRuntime.activateKickButton(button)
    if not button or not button:IsA("GuiButton") or not button.Visible then
        return false, "Kick button unavailable"
    end
    local fireSignal = KickRuntime.resolveFireSignal()
    if fireSignal then
        local success, errorMessage = pcall(function()
            fireSignal(button.MouseButton1Click)
        end)
        if success then
            return true, "Signal"
        end
        State.kickSecretLastError = tostring(errorMessage)
    end
    local position = button.AbsolutePosition
    local size = button.AbsoluteSize
    return KickRuntime.sendMouseClick(position.X + size.X / 2, position.Y + size.Y / 2)
end

function KickRuntime.getTargetZone()
    local zones = Services.Workspace:FindFirstChild("Zones")
    local kickPart = Services.Workspace:FindFirstChild("KickPart")
    if not zones or not kickPart or not kickPart:IsA("BasePart") then
        return nil, nil, nil
    end
    local selectedZone = nil
    local selectedPart = nil
    local selectedScore = -math.huge
    for _, zone in ipairs(zones:GetChildren()) do
        local detection = zone:FindFirstChild("Detection")
        if detection and detection:IsA("BasePart") then
            local numericName = tonumber(zone.Name)
            local score
            if numericName then
                score = 1000000000 + numericName
            else
                local delta = Vector3.new(
                    detection.Position.X - kickPart.Position.X,
                    0,
                    detection.Position.Z - kickPart.Position.Z
                )
                score = delta.Magnitude
            end
            if score > selectedScore then
                selectedScore = score
                selectedZone = zone
                selectedPart = detection
            end
        end
    end
    return selectedZone, selectedPart, kickPart
end

function KickRuntime.getPowerRequirement(zone)
    local configuration = Modules.LuckyBlockConfigurations
    local player = Services.Players.LocalPlayer
    local leaderstats = player and player:FindFirstChild("leaderstats")
    local powerValue = leaderstats and leaderstats:FindFirstChild("Power")
    local currentPower = powerValue and tonumber(powerValue.Value) or 0
    local requiredPower = 0
    local blockName = nil
    local available = false
    if configuration and zone then
        local zoneModels = configuration.ZoneModels
        if type(zoneModels) == "table" then
            blockName = zoneModels[tostring(zone.Name)]
        end
        local blocks = configuration.Blocks
        local blockData = type(blocks) == "table" and blockName and blocks[blockName] or nil
        local requirement = blockData and tonumber(blockData.PowerRequirement) or nil
        if requirement ~= nil then
            requiredPower = requirement
            available = true
        end
    end
    State.kickSecretCurrentPower = currentPower
    State.kickSecretRequiredPower = requiredPower
    State.kickSecretRequirementAvailable = available
    State.kickSecretRequirementMet = available and currentPower >= requiredPower
    State.kickSecretTargetBlockName = blockName
    return currentPower, requiredPower, blockName, available
end

function KickRuntime.getTrackDirection(target, kickPart)
    if not target or not kickPart then
        return nil
    end
    local delta = Vector3.new(
        target.Position.X - kickPart.Position.X,
        0,
        target.Position.Z - kickPart.Position.Z
    )
    if delta.Magnitude <= 1 then
        return nil
    end
    return delta.Unit
end

function KickRuntime.getTsunamiEnd()
    local tsunami = Services.Workspace:FindFirstChild("Tsunami")
    if not tsunami then
        return nil
    end
    if tsunami:IsA("BasePart") then
        return tsunami
    end
    local ending = tsunami:FindFirstChild("End")
    if ending and ending:IsA("BasePart") then
        return ending
    end
    return tsunami:FindFirstChildWhichIsA("BasePart")
end

function KickRuntime.getEscapeDirection(zone)
    local ending = KickRuntime.getTsunamiEnd()
    local origin = zone and zone:FindFirstChild("Spawn") or nil
    if not origin or not origin:IsA("BasePart") then
        origin = State.kickSecretTargetPart
    end
    if not origin or not origin:IsA("BasePart") or not ending then
        return nil
    end
    local delta = Vector3.new(
        ending.Position.X - origin.Position.X,
        0,
        ending.Position.Z - origin.Position.Z
    )
    if delta.Magnitude <= 1 then
        return nil
    end
    return delta.Unit
end

function KickRuntime.restoreRunSpeed()
    local humanoid = State.kickSecretRunHumanoid
    local baseSpeed = tonumber(State.kickSecretRunBaseWalkSpeed)
    local appliedSpeed = tonumber(State.kickSecretRunAppliedWalkSpeed)
    if humanoid and humanoid.Parent and baseSpeed and baseSpeed > 0 then
        pcall(function()
            local current = tonumber(humanoid.WalkSpeed) or 0
            if not appliedSpeed or math.abs(current - appliedSpeed) <= 0.5 then
                humanoid.WalkSpeed = baseSpeed
            end
        end)
    end
    State.kickSecretRunBaseWalkSpeed = nil
    State.kickSecretRunHumanoid = nil
    State.kickSecretRunAppliedWalkSpeed = nil
end

function KickRuntime.applyRunMovement(direction, mode)
    local _, humanoid, root = KickRuntime.getCharacterParts()
    if not humanoid or not root or not direction or root.Anchored or humanoid.Health <= 0 then
        State.kickSecretRunActive = false
        State.kickSecretRunMode = root and root.Anchored and "Waiting for Native Unlock" or "Unavailable"
        return false
    end
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude <= 0.01 then
        State.kickSecretRunActive = false
        State.kickSecretRunMode = "Invalid Direction"
        return false
    end
    flat = flat.Unit
    local destination = root.Position + flat * State.kickSecretRunDistance
    local success = pcall(function()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        if State.kickSecretRunHumanoid ~= humanoid or not State.kickSecretRunBaseWalkSpeed then
            KickRuntime.restoreRunSpeed()
            local currentSpeed = tonumber(humanoid.WalkSpeed) or 0
            local fallbackSpeed = math.max(16, tonumber(State.weightTrainingBaseWalkSpeed) or 16)
            State.kickSecretRunBaseWalkSpeed = currentSpeed > 0.1 and currentSpeed or fallbackSpeed
            State.kickSecretRunHumanoid = humanoid
        end
        local multiplier = normalizeRunSpeedMultiplier(State.kickSecretRunSpeedMultiplier)
        local desiredSpeed = math.max(1, (tonumber(State.kickSecretRunBaseWalkSpeed) or 16) * multiplier)
        humanoid.WalkSpeed = desiredSpeed
        State.kickSecretRunAppliedWalkSpeed = desiredSpeed
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        local controls = WeightTrainingRuntime.resolveControls()
        if controls then
            controls:Enable()
        end
        humanoid:Move(flat, false)
        humanoid:MoveTo(destination)
    end)
    State.kickSecretRunActive = success
    State.kickSecretRunMode = success and tostring(mode or "Running") or "Move Failed"
    State.kickSecretRunDirection = flat
    State.kickSecretRunDestination = destination
    return success
end

function KickRuntime.runInDirection(direction, mode)
    local flat = direction and Vector3.new(direction.X, 0, direction.Z) or Vector3.zero
    if flat.Magnitude <= 0.01 then
        State.kickSecretRunActive = false
        State.kickSecretRunMode = "Invalid Direction"
        return false
    end
    State.kickSecretRunDirection = flat.Unit
    if not State.kickSecretAutoRunConnection then
        State.kickSecretAutoRunConnection = Services.RunService.Heartbeat:Connect(function()
            if not State.running or not State.autoLandSecretChance or State.kickSecretPhase ~= "Waiting Completion" then
                ConnectionRuntime.disconnect("kickSecretAutoRunConnection")
                return
            end
            KickRuntime.applyRunMovement(
                State.kickSecretRunDirection,
                State.kickRewardRejecting and "Running Toward Tsunami" or "Escaping Tsunami"
            )
        end)
    end
    return KickRuntime.applyRunMovement(State.kickSecretRunDirection, mode)
end

function KickRuntime.runEscape(zone)
    local direction = KickRuntime.getEscapeDirection(zone)
    if not direction then
        State.kickSecretRunActive = false
        State.kickSecretRunMode = "Escape Direction Unavailable"
        return false
    end
    return KickRuntime.runInDirection(direction, "Escaping Tsunami")
end

function KickRuntime.getActiveTsunamiPart()
    local _, _, root = KickRuntime.getCharacterParts()
    local bestPart
    local bestDistance = math.huge
    local staticTsunami = Services.Workspace:FindFirstChild("Tsunami")
    local templates = Services.ReplicatedStorage:FindFirstChild("Tsunamis")
    for _, instance in ipairs(Services.Workspace:GetChildren()) do
        if instance ~= staticTsunami then
            local hitbox
            local templateMatch = templates and templates:FindFirstChild(instance.Name) ~= nil
            if instance:IsA("Model") and (templateMatch or not templates) then
                local candidate = instance:FindFirstChild("Hitbox")
                if candidate and candidate:IsA("BasePart") then
                    hitbox = candidate
                end
            elseif instance:IsA("BasePart") and string.find(string.lower(instance.Name), "tsunami", 1, true) then
                hitbox = instance
            end
            if hitbox then
                local distance = root and (hitbox.Position - root.Position).Magnitude or 0
                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = hitbox
                end
            end
        end
    end
    return bestPart
end

function KickRuntime.runTowardTsunami(zone)
    local _, _, root = KickRuntime.getCharacterParts()
    local activePart = KickRuntime.getActiveTsunamiPart()
    local direction
    if root and activePart then
        local delta = Vector3.new(
            activePart.Position.X - root.Position.X,
            0,
            activePart.Position.Z - root.Position.Z
        )
        if delta.Magnitude > 1 then
            direction = delta.Unit
        end
    end
    if not direction then
        local escapeDirection = KickRuntime.getEscapeDirection(zone)
        if escapeDirection then
            direction = -escapeDirection
        end
    end
    if not direction then
        State.kickSecretRunActive = false
        State.kickSecretRunMode = "Tsunami Direction Unavailable"
        return false
    end
    State.kickRewardRejecting = true
    return KickRuntime.runInDirection(direction, "Running Toward Tsunami")
end

function KickRuntime.getBlockPart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        local primary = instance.PrimaryPart
        if primary and primary:IsA("BasePart") then
            return primary
        end
        return instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function KickRuntime.isKnownBlockName(name)
    name = tostring(name or "")
    local configuration = Modules.LuckyBlockConfigurations
    if not configuration then
        return false
    end
    if type(configuration.Blocks) == "table" and configuration.Blocks[name] then
        return true
    end
    if type(configuration.ZoneModels) == "table" then
        for _, blockName in pairs(configuration.ZoneModels) do
            if tostring(blockName) == name then
                return true
            end
        end
    end
    return false
end

function KickRuntime.getActiveBlock()
    local player = Services.Players.LocalPlayer
    local character = player and player.Character
    local camera = Services.Workspace.CurrentCamera
    local subject = camera and camera.CameraSubject
    local subjectPart = KickRuntime.getBlockPart(subject)
    if subjectPart and subjectPart.Parent and subjectPart.Position.Y > -3000 then
        if not character or not subjectPart:IsDescendantOf(character) then
            return subjectPart
        end
    end
    local previous = State.kickSecretBlock
    if previous and previous.Parent and previous:IsA("BasePart") and previous.Position.Y > -3000 then
        return previous
    end
    local kickPart = Services.Workspace:FindFirstChild("KickPart")
    local bestPart
    local bestScore = -math.huge
    for _, child in ipairs(Services.Workspace:GetChildren()) do
        if child ~= character and KickRuntime.isKnownBlockName(child.Name) then
            local part = KickRuntime.getBlockPart(child)
            if part and part.Parent and part.Position.Y > -3000 then
                local score = 0
                if not part.Anchored then
                    score = score + 1000
                end
                local speed = part.AssemblyLinearVelocity.Magnitude
                if speed > 1 then
                    score = score + 2000 + math.min(speed, 1000)
                end
                if part.CollisionGroup == "LuckyBlocks" then
                    score = score + 500
                end
                if kickPart and kickPart:IsA("BasePart") then
                    local distance = (part.Position - kickPart.Position).Magnitude
                    score = score + math.max(0, 1000 - math.min(distance, 1000))
                end
                if score > bestScore then
                    bestScore = score
                    bestPart = part
                end
            end
        end
    end
    return bestPart
end

function KickRuntime.isBlockInsideTarget(block, target)
    if not block or not target or not block:IsA("BasePart") or not target:IsA("BasePart") then
        return false
    end
    local localPosition = target.CFrame:PointToObjectSpace(block.Position)
    local size = target.Size
    local paddingX = block.Size.X / 2 + 1.5
    local paddingY = block.Size.Y / 2 + 4
    local paddingZ = block.Size.Z / 2 + 1.5
    return math.abs(localPosition.X) <= size.X / 2 + paddingX
        and math.abs(localPosition.Y) <= size.Y / 2 + paddingY
        and math.abs(localPosition.Z) <= size.Z / 2 + paddingZ
end

function KickRuntime.restoreInstantPower()
    ConnectionRuntime.disconnect("kickSecretPowerBarSizeConnection")
    local configuration = Modules.KickConfigurations
    if configuration and State.kickSecretOriginalPowerBarSpeed ~= nil then
        configuration.PowerBarSpeed = State.kickSecretOriginalPowerBarSpeed
    end
    State.kickSecretOriginalPowerBarSpeed = nil
    State.kickSecretInstantPowerArmed = false
end

function KickRuntime.submitPerfectPower()
    if State.kickSecretPowerSubmitPending or State.kickSecretPhase ~= "Selecting Power" then
        return false
    end
    State.kickSecretPowerSubmitPending = true
    KickRuntime.restoreInstantPower()
    task.defer(function()
        if not State.running or State.kickSecretPhase ~= "Selecting Power" then
            State.kickSecretPowerSubmitPending = false
            return
        end
        local success, errorMessage = KickRuntime.sendMouseClick()
        if not success then
            State.kickSecretPowerSubmitPending = false
            KickRuntime.fail(errorMessage)
            return
        end
        State.kickSecretPhase = "Launching"
        State.kickSecretPhaseSince = os.clock()
        State.kickSecretLastStatus = "Instant Perfect Kick Submitted"
    end)
    return true
end

function KickRuntime.armInstantPower(powerBar, bar)
    if State.kickSecretInstantPowerArmed then
        return true
    end
    local configuration = Modules.KickConfigurations
    if not configuration or not powerBar or not bar then
        return false
    end
    local thresholds = configuration.EffectThresholds
    local perfect = type(thresholds) == "table" and tonumber(thresholds.Perfect) or 90
    State.kickSecretPerfectThreshold = math.clamp((perfect or 90) / 100, 0, 1)
    State.kickSecretOriginalPowerBarSpeed = tonumber(configuration.PowerBarSpeed) or 1.5
    configuration.PowerBarSpeed = State.kickSecretInstantPowerSpeed
    State.kickSecretInstantPowerArmed = true
    ConnectionRuntime.disconnect("kickSecretPowerBarSizeConnection")
    State.kickSecretPowerBarSizeConnection = bar:GetPropertyChangedSignal("Size"):Connect(function()
        if not State.running or State.kickSecretPhase ~= "Selecting Power" or State.kickSecretPowerSubmitPending then
            return
        end
        local value = tonumber(bar.Size.Y.Scale) or 0
        if value >= State.kickSecretTargetPower then
            KickRuntime.submitPerfectPower()
        end
    end)
    local value = tonumber(bar.Size.Y.Scale) or 0
    if powerBar.Visible and value >= State.kickSecretTargetPower then
        KickRuntime.submitPerfectPower()
    end
    return true
end

function KickRuntime.stopMovement()
    ConnectionRuntime.disconnect("kickSecretAutoRunConnection")
    KickRuntime.restoreRunSpeed()
    local _, humanoid, root = KickRuntime.getCharacterParts()
    if humanoid and root then
        pcall(function()
            humanoid:Move(Vector3.zero, false)
            humanoid:MoveTo(root.Position)
        end)
    end
    State.kickSecretRunActive = false
    State.kickSecretRunMode = "Stopped"
    State.kickSecretRunDirection = Vector3.zero
    State.kickSecretRunDestination = nil
end

function KickRuntime.resetLifecycle(status)
    KickRuntime.restoreInstantPower()
    ConnectionRuntime.disconnect("kickSecretAutoRunConnection")
    KickRuntime.restoreRunSpeed()
    State.kickSecretPowerSubmitPending = false
    State.kickSecretPhase = "Idle"
    State.kickSecretPhaseSince = os.clock()
    State.kickSecretTargetZone = nil
    State.kickSecretTargetPart = nil
    State.kickSecretBlock = nil
    State.kickSecretAssistApplied = false
    State.kickSecretTargetReached = false
    State.kickSecretLastProgress = 0
    State.kickSecretLastDistance = 0
    State.kickSecretRequiredPower = 0
    State.kickSecretCurrentPower = 0
    State.kickSecretRequirementMet = false
    State.kickSecretRequirementAvailable = false
    State.kickSecretTargetBlockName = nil
    State.kickSecretRunActive = false
    State.kickSecretRunMode = "Idle"
    State.kickSecretRunDirection = Vector3.zero
    State.kickSecretRunDestination = nil
    State.kickSecretActivitySeen = false
    State.kickSecretActivitySeenAt = 0
    KickRewardRuntime.resetDecision("Not Evaluated")
    State.kickSecretLastStatus = status or "Idle"
end

function KickRuntime.applyModeState()
    if State.autoLandSecretChanceRisk then
        State.autoLandSecretChanceLowRisk = false
        State.autoLandSecretChance = true
        State.kickSecretHardCorrectionEnabled = true
        State.kickSecretRiskLevel = "RISK"
    elseif State.autoLandSecretChanceLowRisk then
        State.autoLandSecretChance = true
        State.kickSecretHardCorrectionEnabled = false
        State.kickSecretRiskLevel = "LOW RISK"
    else
        State.autoLandSecretChance = false
        State.kickSecretHardCorrectionEnabled = false
        State.kickSecretRiskLevel = "OFF"
    end
end

function KickRuntime.setMode(mode, enabled, save)
    mode = tostring(mode or "LOW RISK")
    enabled = enabled == true
    if mode == "RISK" then
        State.autoLandSecretChanceRisk = enabled
        if enabled then
            State.autoLandSecretChanceLowRisk = false
        end
    else
        State.autoLandSecretChanceLowRisk = enabled
        if enabled then
            State.autoLandSecretChanceRisk = false
        end
    end
    KickRuntime.applyModeState()
    KickRuntime.stopMovement()
    KickRuntime.resetLifecycle(State.autoLandSecretChance and "Ready" or "Disabled")
    State.kickSecretNextAt = 0
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    ConfigRuntime.syncControls()
end

function KickRuntime.setAuto(enabled, save)
    KickRuntime.setMode("LOW RISK", enabled, save)
end

function KickRuntime.setRunSpeedMultiplier(value, save)
    State.kickSecretRunSpeedMultiplier = normalizeRunSpeedMultiplier(value)
    if save ~= false then
        ConfigRuntime.queueSave()
    end
    return State.kickSecretRunSpeedMultiplier
end

function KickRuntime.fail(message)
    State.kickSecretFailures = State.kickSecretFailures + 1
    State.kickSecretLastError = tostring(message or "Unknown failure")
    State.kickSecretNextAt = os.clock() + State.kickSecretRetryCooldown
    KickRuntime.stopMovement()
    KickRuntime.resetLifecycle("Retry Cooldown")
    LogRuntime.add("ERROR", "Secret landing failed: " .. State.kickSecretLastError)
end

function KickRuntime.beginCompletionRecovery(status)
    KickRuntime.restoreInstantPower()
    State.kickSecretPowerSubmitPending = false
    State.kickSecretPhase = "Waiting Completion"
    State.kickSecretPhaseSince = os.clock()
    State.kickSecretRecoveredLaunches = State.kickSecretRecoveredLaunches + 1
    State.kickSecretLastStatus = status or "Recovering Native Activity"
end

function KickRuntime.markTargetReached(block, zone)
    if State.kickSecretTargetReached then
        return
    end
    State.kickSecretTargetReached = true
    State.kickSecretLandingCount = State.kickSecretLandingCount + 1
    State.kickSecretLastStatus = "Secret Chance Zone Reached"
    State.kickSecretPhase = "Waiting Completion"
    State.kickSecretPhaseSince = os.clock()
    LogRuntime.add(
        "SUCCESS",
        "Lucky block reached Secret Chance Zone " .. tostring(zone and zone.Name or "")
    )
end

function KickRuntime.assistFlight(block, target, kickPart)
    if not block or not target or not kickPart then
        return false
    end
    if KickRuntime.isBlockInsideTarget(block, target) then
        KickRuntime.markTargetReached(block, State.kickSecretTargetZone)
        return true
    end
    local start2 = Vector2.new(kickPart.Position.X, kickPart.Position.Z)
    local target2 = Vector2.new(target.Position.X, target.Position.Z)
    local block2 = Vector2.new(block.Position.X, block.Position.Z)
    local track = target2 - start2
    local trackLength = track.Magnitude
    if trackLength <= 1 then
        return false
    end
    local direction2 = track.Unit
    local projection = (block2 - start2):Dot(direction2)
    local progress = projection / trackLength
    local horizontalDelta = Vector3.new(
        target.Position.X - block.Position.X,
        0,
        target.Position.Z - block.Position.Z
    )
    State.kickSecretLastProgress = progress
    State.kickSecretLastDistance = horizontalDelta.Magnitude
    if progress >= State.kickSecretAssistStartRatio and horizontalDelta.Magnitude > 1 then
        local velocity = block.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        horizontalSpeed = math.clamp(horizontalSpeed, 90, 360)
        local guided = horizontalDelta.Unit * horizontalSpeed
        block.AssemblyLinearVelocity = Vector3.new(guided.X, velocity.Y, guided.Z)
        State.kickSecretAssistApplied = true
        State.kickSecretLastStatus = "Guiding Flight"
    end
    local hardCorrect = progress >= State.kickSecretHardCorrectRatio
        or projection > trackLength
        or horizontalDelta.Magnitude <= 260
        or os.clock() - State.kickSecretPhaseSince >= State.kickSecretFlightTimeout - 3
    if hardCorrect then
        if State.kickSecretHardCorrectionEnabled then
            local rotation = block.CFrame - block.Position
            local targetPosition = target.Position
            block.CFrame = CFrame.new(targetPosition) * rotation
            block.AssemblyLinearVelocity = Vector3.new(0, -6, 0)
            block.AssemblyAngularVelocity = Vector3.zero
            State.kickSecretAssistApplied = true
            State.kickSecretLastStatus = "RISK Hard Landing Correction"
        elseif horizontalDelta.Magnitude > 1 then
            local velocity = block.AssemblyLinearVelocity
            local finalSpeed = math.clamp(horizontalDelta.Magnitude * 1.25, 45, 180)
            local guided = horizontalDelta.Unit * finalSpeed
            block.AssemblyLinearVelocity = Vector3.new(guided.X, math.min(velocity.Y, -8), guided.Z)
            State.kickSecretAssistApplied = true
            State.kickSecretLastStatus = "Low Risk Final Velocity Guidance"
        end
    end
    return false
end

function KickRuntime.tick()
    if not State.autoLandSecretChance or not State.running then
        return
    end
    local now = os.clock()
    local player = Services.Players.LocalPlayer
    local activity = player:GetAttribute("LuckyBlockActivityActive") == true
    if activity and not State.kickSecretActivitySeen then
        State.kickSecretActivitySeen = true
        State.kickSecretActivitySeenAt = now
    end
    if State.kickSecretPhase == "Waiting Completion" then
        local zone = State.kickSecretTargetZone
        local target = State.kickSecretTargetPart
        local kickPart = Services.Workspace:FindFirstChild("KickPart")
        if activity then
            local _, _, root = KickRuntime.getCharacterParts()
            local decision = KickRewardRuntime.updateDecision()
            if root and not root.Anchored then
                if decision == nil and KickRewardRuntime.isFilterActive() then
                    if State.kickRewardFilterWaitSince <= 0 then
                        State.kickRewardFilterWaitSince = now
                    end
                    if now - State.kickRewardFilterWaitSince >= State.kickRewardFilterWaitTimeout then
                        State.kickRewardFilterDecision = false
                        State.kickRewardFilterDecisionReason = "Card Preview Unavailable"
                        State.kickRewardLastDecision = false
                        State.kickRewardLastDecisionReason = State.kickRewardFilterDecisionReason
                        State.kickRewardRejectedCount = State.kickRewardRejectedCount + 1
                        if not State.kickRewardFilterDecisionLogged then
                            State.kickRewardFilterDecisionLogged = true
                            LogRuntime.add("FILTER", "Kick card rejected: preview unavailable | Running toward tsunami")
                        end
                        decision = false
                    else
                        KickRuntime.stopMovement()
                        State.kickSecretRunMode = "Waiting for Card Filter Data"
                        State.kickSecretLastStatus = "Waiting for Kick Card Whitelist Decision"
                    end
                end
                if decision == false then
                    if KickRuntime.runTowardTsunami(zone) then
                        State.kickSecretLastStatus = "Rejecting Card; Running Toward Tsunami"
                    else
                        State.kickSecretLastStatus = "Waiting for Tsunami Direction"
                    end
                elseif decision == true then
                    State.kickRewardRejecting = false
                    if KickRuntime.runEscape(zone) then
                        State.kickSecretLastStatus = "Accepted Card; Auto Running from Tsunami"
                    else
                        State.kickSecretLastStatus = "Waiting for Escape Direction"
                    end
                end
            else
                State.kickSecretRunActive = false
                State.kickSecretRunMode = "Waiting for Native Unlock"
                State.kickSecretLastStatus = decision == nil and KickRewardRuntime.isFilterActive()
                    and "Reading Kick Card for Whitelist"
                    or "Waiting for Card Reveal to Finish"
            end
            if now - State.kickSecretPhaseSince > 90 then
                KickRuntime.fail("Activity did not complete")
            end
        else
            KickRuntime.stopMovement()
            State.kickSecretPhase = "Returning"
            State.kickSecretPhaseSince = now
            State.kickSecretLastStatus = "Returning to Kick Part"
        end
        return
    end
    if State.kickSecretPhase == "Returning" then
        local kickPart = Services.Workspace:FindFirstChild("KickPart")
        local character, humanoid, root = KickRuntime.getCharacterParts()
        if not kickPart or not kickPart:IsA("BasePart") then
            KickRuntime.fail("Kick Part unavailable while returning")
            return
        end
        if not character then
            State.kickSecretLastStatus = "Waiting for Character to Return"
            return
        end
        if KickRuntime.isInsidePart(root, kickPart) then
            KickRuntime.stopMovement()
            State.kickSecretNextAt = now + State.kickSecretCooldown
            KickRuntime.resetLifecycle("Cooldown")
        elseif root.Anchored then
            State.kickSecretRunActive = false
            State.kickSecretLastStatus = "Waiting to Run Back"
        else
            humanoid:MoveTo(kickPart.Position)
            State.kickSecretRunActive = true
            State.kickSecretLastStatus = "Running Back to Kick Part"
            if now - State.kickSecretPhaseSince > State.kickSecretReturnTimeout then
                KickRuntime.fail("Could not return to Kick Part")
            end
        end
        return
    end
    if State.kickSecretPhase == "Flight" or State.kickSecretPhase == "Launching" then
        local zone, target, kickPart = KickRuntime.getTargetZone()
        if zone and target and kickPart then
            State.kickSecretTargetZone = zone
            State.kickSecretTargetPart = target
        end
        local _, _, root = KickRuntime.getCharacterParts()
        if activity and root and not root.Anchored and State.kickSecretActivitySeenAt > 0 and now - State.kickSecretActivitySeenAt > 3 then
            KickRuntime.beginCompletionRecovery("Native Landing Completed; Starting Auto Run")
            return
        end
        local block = KickRuntime.getActiveBlock()
        if block then
            State.kickSecretBlock = block
            if State.kickSecretPhase ~= "Flight" then
                State.kickSecretPhase = "Flight"
                State.kickSecretPhaseSince = now
                State.kickSecretLastStatus = "Flight Detected"
            end
            if zone and target and kickPart then
                KickRuntime.assistFlight(block, target, kickPart)
            end
            if State.kickSecretPhase == "Flight" and now - State.kickSecretPhaseSince > State.kickSecretFlightTimeout then
                if activity then
                    KickRuntime.beginCompletionRecovery("Flight Tracking Ended; Waiting for Native Unlock")
                else
                    KickRuntime.fail("Flight target timeout")
                end
            end
            return
        end
        local phaseElapsed = now - State.kickSecretPhaseSince
        if activity then
            if phaseElapsed > State.kickSecretLaunchTimeout then
                State.kickSecretLastStatus = "Recovering Active Native Launch"
            end
            if phaseElapsed > State.kickSecretLaunchRecoveryTimeout then
                KickRuntime.beginCompletionRecovery("Launch Tracking Timeout; Waiting for Native Completion")
            end
        elseif State.kickSecretActivitySeen then
            State.kickSecretPhase = "Returning"
            State.kickSecretPhaseSince = now
            State.kickSecretLastStatus = "Native Activity Completed"
        elseif phaseElapsed > 4 then
            KickRuntime.fail("Lucky block activity did not start")
        end
        return
    end
    if now < State.kickSecretNextAt then
        return
    end
    if activity then
        State.kickSecretLastStatus = "Waiting for Current Activity"
        return
    end
    if State.cardPlacementPending then
        State.kickSecretLastStatus = "Waiting for Card Placement"
        return
    end
    local zone, target, kickPart = KickRuntime.getTargetZone()
    if not zone or not target or not kickPart then
        KickRuntime.fail("Secret Chance Zone target unavailable")
        return
    end
    State.kickSecretTargetZone = zone
    State.kickSecretTargetPart = target
    local currentPower, requiredPower, blockName, requirementAvailable = KickRuntime.getPowerRequirement(zone)
    if not requirementAvailable then
        State.kickSecretLastStatus = "Waiting for Power Requirement Data"
        State.kickSecretNextAt = now + 1
        return
    end
    if currentPower < requiredPower then
        State.kickSecretLastStatus = "Need " .. tostring(requiredPower) .. " Power for " .. tostring(blockName or zone.Name)
        State.kickSecretNextAt = now + 1
        return
    end
    local character, humanoid, root = KickRuntime.getCharacterParts()
    if not character then
        State.kickSecretLastStatus = "Waiting for Character"
        return
    end
    if State.kickSecretPhase == "Idle" then
        State.kickSecretPhase = "Walking"
        State.kickSecretPhaseSince = now
        State.kickSecretLastStatus = "Walking to Kick Part"
    end
    if State.kickSecretPhase == "Walking" then
        if not KickRuntime.isInsidePart(root, kickPart) then
            humanoid:MoveTo(kickPart.Position)
            State.kickSecretRunActive = true
            if now - State.kickSecretPhaseSince > State.kickSecretWalkTimeout then
                KickRuntime.fail("Could not reach Kick Part")
            end
            return
        end
        State.kickSecretRunActive = false
        KickRuntime.stopMovement()
        local kickButton = KickRuntime.getGui()
        local success, method = KickRuntime.activateKickButton(kickButton)
        if not success then
            KickRuntime.fail(method)
            return
        end
        State.kickSecretPhase = "Selecting Power"
        State.kickSecretPhaseSince = now
        State.kickSecretLastStatus = "Preparing Instant Perfect Kick"
        local _, powerBar, bar = KickRuntime.getGui()
        KickRuntime.armInstantPower(powerBar, bar)
        return
    end
    if State.kickSecretPhase == "Selecting Power" then
        local _, powerBar, bar = KickRuntime.getGui()
        if powerBar and bar then
            if not State.kickSecretInstantPowerArmed then
                KickRuntime.armInstantPower(powerBar, bar)
            end
            local value = tonumber(bar.Size.Y.Scale) or 0
            if powerBar.Visible and value >= State.kickSecretTargetPower then
                KickRuntime.submitPerfectPower()
            elseif powerBar.Visible then
                State.kickSecretLastStatus = "Charging Instant Perfect"
            end
        end
        if activity then
            KickRuntime.restoreInstantPower()
            State.kickSecretPowerSubmitPending = false
            State.kickSecretPhase = "Launching"
            State.kickSecretPhaseSince = now
        elseif now - State.kickSecretPhaseSince > State.kickSecretSelectTimeout then
            KickRuntime.fail("Power selection timeout")
        end
    end
end

function KickRuntime.getState()
    return {
        enabled = State.autoLandSecretChance,
        phase = State.kickSecretPhase,
        targetZone = State.kickSecretTargetZone and State.kickSecretTargetZone.Name or nil,
        targetPart = State.kickSecretTargetPart and State.kickSecretTargetPart:GetFullName() or nil,
        blockDetected = State.kickSecretBlock ~= nil and State.kickSecretBlock.Parent ~= nil,
        assistApplied = State.kickSecretAssistApplied,
        targetReached = State.kickSecretTargetReached,
        landingCount = State.kickSecretLandingCount,
        failures = State.kickSecretFailures,
        progress = State.kickSecretLastProgress,
        distance = State.kickSecretLastDistance,
        lastStatus = State.kickSecretLastStatus,
        lastError = State.kickSecretLastError,
        riskLevel = State.kickSecretRiskLevel,
        hardCorrection = State.kickSecretHardCorrectionEnabled,
        currentPower = State.kickSecretCurrentPower,
        requiredPower = State.kickSecretRequiredPower,
        requirementMet = State.kickSecretRequirementMet,
        requirementAvailable = State.kickSecretRequirementAvailable,
        targetBlockName = State.kickSecretTargetBlockName,
        autoRunActive = State.kickSecretRunActive,
        autoRunMode = State.kickSecretRunMode,
        autoRunDirection = State.kickSecretRunDirection,
        autoRunDestination = State.kickSecretRunDestination,
        lowRiskEnabled = State.autoLandSecretChanceLowRisk,
        riskEnabled = State.autoLandSecretChanceRisk,
        fireSignalAvailable = KickRuntime.resolveFireSignal() ~= nil,
        virtualInputAvailable = Services.VirtualInputManager ~= nil,
        instantPerfectEnabled = true,
        instantPowerArmed = State.kickSecretInstantPowerArmed,
        powerSubmitPending = State.kickSecretPowerSubmitPending,
        targetPower = State.kickSecretTargetPower,
        perfectThreshold = State.kickSecretPerfectThreshold,
        instantPowerSpeed = State.kickSecretInstantPowerSpeed,
        currentPowerBarSpeed = Modules.KickConfigurations and Modules.KickConfigurations.PowerBarSpeed or nil,
        activitySeen = State.kickSecretActivitySeen,
        recoveredLaunches = State.kickSecretRecoveredLaunches,
        autoRunSpeedMultiplier = State.kickSecretRunSpeedMultiplier,
        autoRunBaseWalkSpeed = State.kickSecretRunBaseWalkSpeed,
        autoRunAppliedWalkSpeed = State.kickSecretRunAppliedWalkSpeed,
        rewardFilterThreshold = State.kickRewardFilterThreshold,
        rewardFilterActive = KickRewardRuntime.isFilterActive(),
        rewardDecision = State.kickRewardFilterDecision,
        rewardDecisionReason = State.kickRewardFilterDecisionReason,
        rejectingCard = State.kickRewardRejecting,
        rewardPreview = State.kickRewardCurrentPreview,
    }
end

function AntiAfkRuntime.tryMouseMoveRelative()
    local environment = type(getgenv) == "function" and getgenv() or _G
    local callback = environment and rawget(environment, "mousemoverel") or nil
    if type(callback) ~= "function" then
        return false, "mousemoverel unavailable"
    end
    local success, errorMessage = pcall(callback, 1, 0)
    return success, success and nil or errorMessage
end

function AntiAfkRuntime.tryVirtualInputMouse()
    if not Services.VirtualInputManager then
        return false, "VirtualInputManager unavailable"
    end
    local position = Services.UserInputService:GetMouseLocation()
    local success, errorMessage = pcall(function()
        Services.VirtualInputManager:SendMouseMoveEvent(position.X + 1, position.Y, game)
    end)
    return success, success and nil or errorMessage
end

function AntiAfkRuntime.tryVirtualUser()
    if not Services.VirtualUser then
        return false, "VirtualUser unavailable"
    end
    local success, errorMessage = pcall(function()
        Services.VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
    if success then
        return true
    end
    local fallbackSuccess, fallbackError = pcall(function()
        Services.VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
        task.wait()
        Services.VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
    end)
    return fallbackSuccess, fallbackSuccess and nil or fallbackError or errorMessage
end

function AntiAfkRuntime.tryVirtualInputKey()
    if not Services.VirtualInputManager then
        return false, "VirtualInputManager unavailable"
    end
    local success, errorMessage = pcall(function()
        Services.VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
        task.wait()
        Services.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
    end)
    return success, success and nil or errorMessage
end


function VisualRuntime.isTextObject(instance)
    return instance
        and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox"))
end

function VisualRuntime.classify(instance)
    if not VisualRuntime.isTextObject(instance) then
        return nil
    end
    local text = tostring(instance.Text or "")
    local lowered = string.lower(text)
    if string.find(lowered, "slot upgraded", 1, true) then
        return "Slot Upgrade"
    end
    local compact = string.gsub(text, "%s+", "")
    if string.match(compact, "^%+%$[%d%.,]+[%a]*") then
        return "Collect Money"
    end
    return nil
end

function VisualRuntime.isKindEnabled(kind)
    if kind == "Slot Upgrade" then
        return State.hideUpgradeVisuals
    end
    if kind == "Collect Money" then
        return State.hideCollectVisuals
    end
    return false
end

function VisualRuntime.getTarget(instance, kind)
    if kind == "Collect Money" then
        local current = instance
        while current and current ~= Services.Workspace do
            if current:IsA("BillboardGui") or current:IsA("SurfaceGui") then
                return current, "Enabled"
            end
            current = current.Parent
        end
    end
    return instance, "Visible"
end

function VisualRuntime.hideTarget(instance, property, hiddenValue, kind)
    if not instance or not instance.Parent then
        return false
    end
    if hiddenValue == nil then
        hiddenValue = false
    end
    if State.visualOriginalProperties[instance] == nil then
        local success, value = pcall(function()
            return instance[property]
        end)
        if not success then
            return false
        end
        State.visualOriginalProperties[instance] = {
            property = property,
            value = value,
            kind = kind,
        }
    end
    local success = pcall(function()
        instance[property] = hiddenValue
    end)
    if success then
        State.visualHiddenCount = State.visualHiddenCount + 1
    end
    return success
end

function VisualRuntime.getCollectEffectRoot(instance)
    local plot = PlotRuntime.getPlot()
    local character = Services.Players.LocalPlayer.Character
    local current = instance and instance.Parent or nil
    while current and current ~= Services.Workspace and current ~= Services.Workspace.CurrentCamera do
        if current:IsA("Model") then
            if plot and current:IsDescendantOf(plot) then
                return nil
            end
            if character and current:IsDescendantOf(character) then
                return nil
            end
            if current:FindFirstChildOfClass("Humanoid") then
                return nil
            end
            return current
        end
        current = current.Parent
    end
    return nil
end

function VisualRuntime.hideCollectEffect(instance)
    local root = VisualRuntime.getCollectEffectRoot(instance)
    if not root then
        return 0
    end
    local stack = {root}
    local hidden = 0
    while #stack > 0 do
        local current = table.remove(stack)
        if current:IsA("BasePart") then
            if VisualRuntime.hideTarget(current, "LocalTransparencyModifier", 1, "Collect Money") then
                hidden = hidden + 1
            end
        elseif current:IsA("Decal") or current:IsA("Texture") then
            if VisualRuntime.hideTarget(current, "Transparency", 1, "Collect Money") then
                hidden = hidden + 1
            end
        elseif current:IsA("ParticleEmitter") or current:IsA("Beam") or current:IsA("Trail") then
            if VisualRuntime.hideTarget(current, "Enabled", false, "Collect Money") then
                hidden = hidden + 1
            end
        elseif current:IsA("PointLight") or current:IsA("SpotLight") or current:IsA("SurfaceLight") then
            if VisualRuntime.hideTarget(current, "Enabled", false, "Collect Money") then
                hidden = hidden + 1
            end
        elseif current:IsA("BillboardGui") or current:IsA("SurfaceGui") then
            if VisualRuntime.hideTarget(current, "Enabled", false, "Collect Money") then
                hidden = hidden + 1
            end
        end
        for _, child in ipairs(current:GetChildren()) do
            stack[#stack + 1] = child
        end
    end
    return hidden
end

function VisualRuntime.process(instance)
    local kind = VisualRuntime.classify(instance)
    if not kind or not VisualRuntime.isKindEnabled(kind) then
        return false
    end
    local target, property = VisualRuntime.getTarget(instance, kind)
    local hidden = VisualRuntime.hideTarget(target, property, false, kind)
    if kind == "Collect Money" then
        VisualRuntime.hideCollectEffect(instance)
    end
    if hidden then
        State.visualLastStatus = "Hidden " .. kind
    end
    return hidden
end

function VisualRuntime.walk(root)
    if not root then
        return 0
    end
    local stack = {root}
    local hidden = 0
    while #stack > 0 do
        local current = table.remove(stack)
        if VisualRuntime.process(current) then
            hidden = hidden + 1
        end
        for _, child in ipairs(current:GetChildren()) do
            stack[#stack + 1] = child
        end
    end
    return hidden
end

function VisualRuntime.applyExisting()
    if not State.hideUpgradeVisuals and not State.hideCollectVisuals then
        State.visualLastStatus = "Visual Hiding Disabled"
        return 0
    end
    local player = Services.Players.LocalPlayer
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local total = VisualRuntime.walk(playerGui)
    local plot = PlotRuntime.getPlot()
    if plot then
        total = total + VisualRuntime.walk(plot)
    end
    local camera = Services.Workspace.CurrentCamera
    if camera then
        total = total + VisualRuntime.walk(camera)
    end
    State.visualLastStatus = total > 0 and ("Hidden " .. tostring(total) .. " Existing Visuals") or "Watching Visuals"
    return total
end

function VisualRuntime.restoreKind(kind)
    local restored = 0
    for instance, data in pairs(State.visualOriginalProperties) do
        if type(data) == "table" and data.kind == kind then
            if instance and instance.Parent then
                local success = pcall(function()
                    instance[data.property] = data.value
                end)
                if success then
                    restored = restored + 1
                end
            end
            State.visualOriginalProperties[instance] = nil
        end
    end
    State.visualLastStatus = "Restored " .. tostring(restored) .. " " .. tostring(kind) .. " Visuals"
    return restored
end

function VisualRuntime.restoreAll()
    local restored = 0
    for instance, data in pairs(State.visualOriginalProperties) do
        if instance and instance.Parent and type(data) == "table" then
            local success = pcall(function()
                instance[data.property] = data.value
            end)
            if success then
                restored = restored + 1
            end
        end
    end
    State.visualOriginalProperties = setmetatable({}, {__mode = "k"})
    State.visualLastStatus = "Restored " .. tostring(restored) .. " Visuals"
    return restored
end

function VisualRuntime.onDescendantAdded(instance)
    if not State.hideUpgradeVisuals and not State.hideCollectVisuals then
        return
    end
    VisualRuntime.process(instance)
    if VisualRuntime.isTextObject(instance) then
        task.defer(function()
            if State.running and instance.Parent and (State.hideUpgradeVisuals or State.hideCollectVisuals) then
                VisualRuntime.process(instance)
            end
        end)
    end
end

function VisualRuntime.bind()
    local playerGui = Services.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    ConnectionRuntime.disconnect("visualPlayerGuiAddedConnection")
    ConnectionRuntime.disconnect("visualWorkspaceAddedConnection")
    if playerGui then
        State.visualPlayerGuiAddedConnection = playerGui.DescendantAdded:Connect(VisualRuntime.onDescendantAdded)
    end
    State.visualWorkspaceAddedConnection = Services.Workspace.DescendantAdded:Connect(VisualRuntime.onDescendantAdded)
    VisualRuntime.applyExisting()
    return true
end

function VisualRuntime.setUpgradeEnabled(enabled, save)
    State.hideUpgradeVisuals = enabled == true
    if State.hideUpgradeVisuals then
        VisualRuntime.applyExisting()
    else
        VisualRuntime.restoreKind("Slot Upgrade")
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function VisualRuntime.setCollectEnabled(enabled, save)
    State.hideCollectVisuals = enabled == true
    if State.hideCollectVisuals then
        VisualRuntime.applyExisting()
    else
        VisualRuntime.restoreKind("Collect Money")
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function VisualRuntime.setEnabled(enabled, save)
    State.hideUpgradeVisuals = enabled == true
    State.hideCollectVisuals = enabled == true
    if State.hideUpgradeVisuals or State.hideCollectVisuals then
        VisualRuntime.applyExisting()
    else
        VisualRuntime.restoreAll()
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function VisualRuntime.getState()
    return {
        hideUpgradeVisuals = State.hideUpgradeVisuals,
        hideCollectVisuals = State.hideCollectVisuals,
        hiddenCount = State.visualHiddenCount,
        trackedCount = (function()
            local count = 0
            for _ in pairs(State.visualOriginalProperties) do
                count = count + 1
            end
            return count
        end)(),
        lastStatus = State.visualLastStatus,
        playerGuiConnected = State.visualPlayerGuiAddedConnection ~= nil,
        workspaceConnected = State.visualWorkspaceAddedConnection ~= nil,
    }
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
        local success, errorMessage = method[2]()
        if success then
            successfulMethods[#successfulMethods + 1] = method[1]
        elseif errorMessage then
            errors[#errors + 1] = method[1] .. ": " .. tostring(errorMessage)
        end
    end
    State.antiAfkLastMethods = successfulMethods
    State.antiAfkLastErrors = errors
    State.antiAfkLastStatus = #successfulMethods > 0 and table.concat(successfulMethods, " + ") or "Unavailable"
    State.antiAfkNextAt = os.clock() + State.antiAfkInterval
    if #successfulMethods == 0 then
        LogRuntime.add("ERROR", "All Anti AFK input methods are unavailable")
    end
end

function AntiAfkRuntime.bind()
    ConnectionRuntime.disconnect("antiAfkIdledConnection")
    ConnectionRuntime.disconnect("antiAfkHeartbeatConnection")
    State.antiAfkIdledConnection = Services.Players.LocalPlayer.Idled:Connect(function()
        if State.antiAfk then
            AntiAfkRuntime.pulse()
        end
    end)
    State.antiAfkHeartbeatConnection = Services.RunService.Heartbeat:Connect(function()
        if State.antiAfk and os.clock() >= State.antiAfkNextAt then
            AntiAfkRuntime.pulse()
        end
    end)
end

function AntiAfkRuntime.setEnabled(enabled, save)
    State.antiAfk = enabled == true
    State.antiAfkNextAt = 0
    if State.antiAfk then
        task.defer(AntiAfkRuntime.pulse)
    end
    if save ~= false then
        ConfigRuntime.queueSave()
    end
end

function AntiAfkRuntime.getState()
    return {
        enabled = State.antiAfk,
        interval = State.antiAfkInterval,
        lastStatus = State.antiAfkLastStatus,
        successfulMethods = table.clone(State.antiAfkLastMethods),
        errors = table.clone(State.antiAfkLastErrors),
        heartbeatConnected = State.antiAfkHeartbeatConnection ~= nil,
        idledConnected = State.antiAfkIdledConnection ~= nil,
        virtualUserAvailable = Services.VirtualUser ~= nil,
        virtualInputManagerAvailable = Services.VirtualInputManager ~= nil,
    }
end

local weightCatalogReady = WeightRuntime.buildCatalog()
local cardPlacementCatalogReady = CardPlacementRuntime.buildCatalog()
local kickRewardFilterCatalogReady = KickRewardRuntime.buildFilterCatalog()
local loadedConfig = ConfigRuntime.load()

local existingHub = type(getgenv) == "function" and getgenv()[RuntimeName.global] or nil
if type(existingHub) == "table" and type(existingHub.Stop) == "function" then
    pcall(existingHub.Stop)
end

if
    not State.requestRebirth
    or not State.showTrainingPowerBonus
    or not State.claimTrainingPowerBonus
    or not State.requestWeightPurchase
    or not State.getUnlockedWeights
    or not State.updateWeightsUI
    or not State.resetWeightsUI
    or not State.getPlaytimeRewardState
    or not State.claimPlaytimeReward
    or not State.requestSpin
    or not State.requestSlotUpgrade
    or not State.purchaseUpgrade
    or not State.updateUpgradesUI
    or not Modules.WeightConfigurations
    or not Modules.PlaytimeRewardConfiguration
    or not Modules.DailySpinConfiguration
    or not Modules.ItemConfigurations
    or not Modules.RarityConfigurations
    or not Modules.MutationConfigurations
    or not weightCatalogReady
    or not cardPlacementCatalogReady
    or not kickRewardFilterCatalogReady
then
    warn("[xSansHUB] Required automation references were not found")
    return
end

local windSuccess, WindUI = pcall(function()
    return loadstring(game:HttpGet(RuntimeName.loader))()
end)

if not windSuccess or not WindUI then
    warn("[xSansHUB] WindUI failed to load: " .. tostring(WindUI))
    return
end

local Window = WindUI:CreateWindow({
    Title = "xSansHUB | Kick A Lucky Block",
    Icon = "repeat-2",
    Author = "xSansHUB",
    Folder = "xSansHUB",
    Size = UDim2.fromOffset(520, 420),
    Transparent = true,
    Theme = "Indigo",
    Resizable = true,
    SideBarWidth = 155,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

State.window = Window

Window:Tag({
    Title = "v" .. Hub.Version,
    Icon = "badge-info",
    Border = true,
})

local function createTab(title, icon)
    return Window:Tab({
        Title = title,
        Icon = icon,
    })
end

local function createSection(parent, title, opened)
    return parent:Section({
        Title = title,
        TextSize = 14,
        Opened = opened == true,
    })
end

local function wrapControlCallback(callback)
    return function(value)
        if not State.controlCallbacksReady or State.syncingControls then
            return
        end
        if callback then
            local success, errorMessage = pcall(callback, value)
            if not success then
                LogRuntime.add("ERROR", "Control callback failed: " .. tostring(errorMessage))
            end
        end
    end
end

local function createToggle(parent, controlField, options)
    options.TextSize = 13
    options.DescTextSize = 11
    options.Callback = wrapControlCallback(options.Callback)
    local control = parent:Toggle(options)
    State.controls[controlField] = control
    return control
end

local function createDropdown(parent, controlField, options)
    options.TextSize = 13
    options.DescTextSize = 11
    options.Callback = wrapControlCallback(options.Callback)
    local control = parent:Dropdown(options)
    State.controls[controlField] = control
    return control
end

local function createInput(parent, controlField, options)
    options.TextSize = 13
    options.DescTextSize = 11
    options.Callback = wrapControlCallback(options.Callback)
    local control = parent:Input(options)
    State.controls[controlField] = control
    return control
end

local function createButton(parent, options)
    options.TextSize = 13
    options.DescTextSize = 11
    return parent:Button(options)
end

local function addToggles(parent, specs)
    local controls = {}
    for _, spec in ipairs(specs) do
        controls[#controls + 1] = createToggle(parent, spec.control, spec.options)
    end
    return controls
end

local Tabs = {
    Automation = createTab("Automation", "repeat-2"),
    Logs = createTab("Logs", "scroll-text"),
    Settings = createTab("Settings", "settings"),
}

local KickSection = createSection(Tabs.Automation, "Kick & Landing", true)
local PlotSection = createSection(Tabs.Automation, "Plot & Cards", false)
local PlayerUpgradesSection = createSection(Tabs.Automation, "Player Upgrades", false)
local WeightsSection = createSection(Tabs.Automation, "Weights", false)
local RewardsSection = createSection(Tabs.Automation, "Daily & Rewards", false)
local TrainingSection = createSection(Tabs.Automation, "Training", false)
local RebirthSection = createSection(Tabs.Automation, "Rebirth", false)
local UtilitySection = createSection(Tabs.Settings, "Utilities", true)
local InterfaceSection = createSection(Tabs.Settings, "Interface", false)
local ConfigurationSection = createSection(Tabs.Settings, "Configuration", false)
local SessionSection = createSection(Tabs.Settings, "Session", false)


addToggles(KickSection, {
    {
        control = "autoLandSecretChanceLowRiskToggle",
        options = {
            Title = "Auto Land Secret Chance [LOW RISK]",
            Desc = "Checks Power, guides velocity without teleporting the block, then auto-runs during the tsunami escape. Enabling this disables RISK mode.",
            Value = State.autoLandSecretChanceLowRisk,
            Callback = function(value)
                KickRuntime.setMode("LOW RISK", value, true)
            end,
        },
    },
    {
        control = "autoLandSecretChanceRiskToggle",
        options = {
            Title = "Auto Land Secret Chance [RISK]",
            Desc = "Checks Power, allows hard block position correction, then auto-runs during the tsunami escape. Enabling this disables LOW RISK mode.",
            Value = State.autoLandSecretChanceRisk,
            Callback = function(value)
                KickRuntime.setMode("RISK", value, true)
            end,
        },
    },
})

createInput(KickSection, "kickSecretRunSpeedMultiplierInput", {
    Title = "Auto Run Speed Multiplier",
    Desc = "Multiplies the native movement speed only during the tsunami escape. 2 means twice the detected speed.",
    Value = tostring(State.kickSecretRunSpeedMultiplier),
    Placeholder = "2",
    Callback = function(value)
        KickRuntime.setRunSpeedMultiplier(value, true)
    end,
})

createDropdown(KickSection, "kickRewardFilterThresholdDropdown", {
    Title = "Kick Reward Whitelist Threshold",
    Desc = "None accepts every card. AND requires every active whitelist to match. OR accepts when any active whitelist matches.",
    Values = State.kickRewardFilterThresholdNames,
    Value = State.kickRewardFilterThreshold,
    Multi = false,
    Callback = function(value)
        KickRewardRuntime.setThreshold(value, true)
        ConfigRuntime.syncControls()
    end,
})

createDropdown(KickSection, "kickRewardCardNameWhitelistDropdown", {
    Title = "Kick Card Name Whitelist",
    Desc = "Select allowed card names. None overrides every other selected value and disables this criterion.",
    Values = State.kickRewardCardNameNames,
    Value = KickRewardRuntime.getCardNameWhitelist(),
    Multi = true,
    Callback = function(value)
        KickRewardRuntime.setCardNameWhitelist(value, true)
        ConfigRuntime.syncControls()
    end,
})

createDropdown(KickSection, "kickRewardRarityWhitelistDropdown", {
    Title = "Kick Rarity Whitelist",
    Desc = "Select allowed rarities. None overrides every other selected value and disables this criterion.",
    Values = State.kickRewardRarityNames,
    Value = KickRewardRuntime.getRarityWhitelist(),
    Multi = true,
    Callback = function(value)
        KickRewardRuntime.setRarityWhitelist(value, true)
        ConfigRuntime.syncControls()
    end,
})

createDropdown(KickSection, "kickRewardMutationWhitelistDropdown", {
    Title = "Kick Mutation Whitelist",
    Desc = "Select allowed mutations. None overrides every other selected value and disables this criterion.",
    Values = State.kickRewardMutationNames,
    Value = KickRewardRuntime.getMutationWhitelist(),
    Multi = true,
    Callback = function(value)
        KickRewardRuntime.setMutationWhitelist(value, true)
        ConfigRuntime.syncControls()
    end,
})

addToggles(PlotSection, {
    {
        control = "autoCollectMoneyToggle",
        options = {
            Title = "Auto Collect Money",
            Desc = "Triggers every occupied unlocked slot collector in one batch, then waits for the configured cycle delay.",
            Value = State.autoCollectMoney,
            Callback = function(value)
                CollectRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "autoUpgradePlacedCardsToggle",
        options = {
            Title = "Auto Upgrade Placed Cards",
            Desc = "Upgrades matching placed cards and sends the next request immediately after server confirmation.",
            Value = State.autoUpgradePlacedCards,
            Callback = function(value)
                CardUpgradeRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "autoFillEmptySlotsToggle",
        options = {
            Title = "Auto Fill Empty Slots",
            Desc = "Fills unlocked empty slots using the selected card priorities, then falls back to highest base income.",
            Value = State.autoFillEmptySlots,
            Callback = function(value)
                CardPlacementRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "autoPickupPlacedCardsToggle",
        options = {
            Title = "Auto Pickup Placed Cards",
            Desc = "Unequips held tools, teleports through occupied slots in Floor and Slot order, and triggers each native pickup prompt. Enabling this disables Auto Fill.",
            Value = State.autoPickupPlacedCards,
            Callback = function(value)
                CardPickupRuntime.setAuto(value, true)
            end,
        },
    },
})

createInput(PlotSection, "collectCycleDelayInput", {
    Title = "Collect Delay Per Cycle",
    Desc = "Seconds between full collect batches. 0 runs once per scheduler tick.",
    Value = tostring(State.collectCycleDelay),
    Placeholder = "0.1",
    Callback = function(value)
        CollectRuntime.setCycleDelay(value, true)
    end,
})

createDropdown(PlotSection, "cardUpgradeRarityWhitelistDropdown", {
    Title = "Upgrade Rarity Whitelist",
    Desc = "Only placed cards with selected rarities will be upgraded.",
    Values = State.cardUpgradeRarityNames,
    Value = CardUpgradeRuntime.getWhitelist(),
    Multi = true,
    Callback = function(value)
        CardUpgradeRuntime.setWhitelist(value, true)
    end,
})

createInput(PlotSection, "cardUpgradeTargetLevelInput", {
    Title = "Target Card Level",
    Desc = "Enter a whole number. 0 means unlimited.",
    Value = tostring(State.cardUpgradeTargetLevel),
    Placeholder = "50",
    Callback = function(value)
        CardUpgradeRuntime.setTargetLevel(value, true)
    end,
})

createDropdown(PlotSection, "cardPlacementPriorityDropdown", {
    Title = "Fill Card Priority",
    Desc = "Ranks every Backpack card again for each slot. Income uses base income multiplied by the card mutation. Priority order is Best Rarity, then Best Mutation, then mutation-adjusted income.",
    Values = State.cardPlacementPriorityNames,
    Value = CardPlacementRuntime.getPriorities(),
    Multi = true,
    Callback = function(value)
        CardPlacementRuntime.setPriorities(value, true)
    end,
})

addToggles(PlayerUpgradesSection, {
    {
        control = "autoUpgradeSpeedToggle",
        options = {
            Title = "Auto Upgrade Speed",
            Desc = "Purchases one Speed level at a time and immediately continues after server confirmation.",
            Value = State.autoUpgradeSpeed,
            Callback = function(value)
                SpeedUpgradeRuntime.setAuto(value, true)
            end,
        },
    },
})

createInput(PlayerUpgradesSection, "speedUpgradeTargetLevelInput", {
    Title = "Target Speed Level",
    Desc = "Enter a whole number. 0 means unlimited.",
    Value = tostring(State.speedUpgradeTargetLevel),
    Placeholder = "50",
    Callback = function(value)
        SpeedUpgradeRuntime.setTargetLevel(value, true)
    end,
})

addToggles(WeightsSection, {
    {
        control = "autoBuyWeightsToggle",
        options = {
            Title = "Auto Buy Weights",
            Desc = "Purchases selected locked weights one request at a time. The whitelist is ignored while Best Affordable mode is enabled.",
            Value = State.autoBuyWeights,
            Callback = function(value)
                WeightRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "autoBuyBestAffordableWeightToggle",
        options = {
            Title = "Auto Buy Best Affordable Weight",
            Desc = "Buys only the strongest affordable upgrade above your current best weight, then equips it automatically. Lower or weaker weights are skipped. This takes priority over the whitelist mode.",
            Value = State.autoBuyBestAffordableWeight,
            Callback = function(value)
                WeightRuntime.setAutoBestAffordable(value, true)
            end,
        },
    },
})

createDropdown(WeightsSection, "weightBuyWhitelistDropdown", {
    Title = "Weight Whitelist",
    Desc = "Only selected locked weights will be purchased.",
    Values = State.weightNames,
    Value = WeightRuntime.getWhitelist(),
    Multi = true,
    Callback = function(value)
        WeightRuntime.setWhitelist(value, true)
    end,
})


addToggles(RewardsSection, {
    {
        control = "autoClaimPlaytimeRewardsToggle",
        options = {
            Title = "Auto Claim Playtime Rewards",
            Desc = "Claims each unlocked playtime milestone directly through the server function.",
            Value = State.autoClaimPlaytimeRewards,
            Callback = function(value)
                PlaytimeRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "autoSpinToggle",
        options = {
            Title = "Auto Spin",
            Desc = "Uses stored spins and the available daily spin without opening the wheel.",
            Value = State.autoSpin,
            Callback = function(value)
                SpinRuntime.setAuto(value, true)
            end,
        },
    },
})

addToggles(TrainingSection, {
    {
        control = "autoWeightTrainingToggle",
        options = {
            Title = "Auto Training",
            Desc = "Equips the highest-power available IsWeight Tool and activates it automatically. Pauses during kick activity and card tool actions.",
            Value = State.autoWeightTraining,
            Callback = function(value)
                WeightTrainingRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "freeMovementWhileTrainingToggle",
        options = {
            Title = "Free Movement While Training",
            Desc = "Keeps movement controls, WalkSpeed, jumping, AutoRotate, and the root part available while an IsWeight Tool is equipped. Pauses during kick activity.",
            Value = State.freeMovementWhileTraining,
            Callback = function(value)
                WeightTrainingRuntime.setFreeMovement(value, true)
            end,
        },
    },
    {
        control = "autoTrainingWeightToggle",
        options = {
            Title = "Auto Claim Training Bonus",
            Desc = "Automatically claims each server-issued x2 training bonus.",
            Value = State.autoTrainingWeight,
            Callback = function(value)
                TrainingRuntime.setAuto(value, true)
            end,
        },
    },
    {
        control = "hideTrainingBonusVisualsToggle",
        options = {
            Title = "Hide Native Bonus Button",
            Desc = "Keeps bonus claims in the background when signal controls are supported.",
            Value = State.hideTrainingBonusVisuals,
            Callback = function(value)
                TrainingRuntime.setHideVisuals(value, true)
            end,
        },
    },
})

createDropdown(TrainingSection, "trainingTapDelayDropdown", {
    Title = "Tap Delay",
    Desc = "Delay before claiming a newly received training bonus.",
    Values = {
        "Instant",
        "0.05 seconds",
        "0.10 seconds",
        "0.20 seconds",
        "0.35 seconds",
    },
    Value = State.trainingTapDelay <= 0 and "Instant" or string.format("%.2f seconds", State.trainingTapDelay),
    Multi = false,
    Callback = function(value)
        State.trainingTapDelay = normalizeTrainingTapDelay(value)
        ConfigRuntime.queueSave()
    end,
})

addToggles(RebirthSection, {
    {
        control = "autoRebirthToggle",
        options = {
            Title = "Auto Rebirth",
            Desc = "Rebirths when Power reaches the exact server requirement.",
            Value = State.autoRebirth,
            Callback = function(value)
                RebirthRuntime.setAuto(value, true)
            end,
        },
    },
})

createDropdown(RebirthSection, "rebirthPollIntervalDropdown", {
    Title = "Poll Interval",
    Desc = "How often eligibility is checked.",
    Values = {
        "0.10 seconds",
        "0.20 seconds",
        "0.35 seconds",
        "0.50 seconds",
        "1.00 seconds",
    },
    Value = string.format("%.2f seconds", State.rebirthPollInterval),
    Multi = false,
    Callback = function(value)
        local number = tonumber(tostring(value):match("[%d%.]+"))
        State.rebirthPollInterval = normalizePollInterval(number)
        ConfigRuntime.queueSave()
    end,
})

State.logParagraph = Tabs.Logs:Paragraph({
    Title = "Session Logs",
    Desc = "No important events yet.",
    Image = "scroll-text",
})

local logFilterControl = Tabs.Logs:Input({
    Title = "Filter",
    Desc = "Case-insensitive log filter.",
    Value = State.logFilter,
    Placeholder = "reward, spin, weight, training, rebirth, error",
    Callback = wrapControlCallback(function(value)
        State.logFilter = normalizeLogFilter(value)
        LogRuntime.render()
        ConfigRuntime.queueSave()
    end),
})
State.controls.logFilterInput = logFilterControl

createButton(Tabs.Logs, {
    Title = "Clear Logs",
    Desc = "Clears stored session logs.",
    Callback = LogRuntime.clear,
})

addToggles(UtilitySection, {
    {
        control = "antiAfkToggle",
        options = {
            Title = "Anti AFK",
            Desc = "Runs all supported input methods every 45 seconds.",
            Value = State.antiAfk,
            Callback = function(value)
                AntiAfkRuntime.setEnabled(value, true)
            end,
        },
    },
})

createDropdown(InterfaceSection, "windowKeybindDropdown", {
    Title = "Window Keybind",
    Desc = "Key used to show or hide the hub.",
    Values = {
        "G",
        "RightShift",
        "LeftAlt",
        "RightControl",
    },
    Value = State.windowKeybind,
    Multi = false,
    Callback = function(value)
        State.windowKeybind = normalizeWindowKeybind(value)
        InterfaceRuntime.applyWindowKeybind()
        ConfigRuntime.queueSave()
    end,
})



addToggles(InterfaceSection, {
    {
        control = "hideUpgradeVisualsToggle",
        options = {
            Title = "Hide Upgrade Visuals",
            Desc = "Hides local Slot Upgraded notifications. Enabled by default and uses event detection without periodic scanning.",
            Value = State.hideUpgradeVisuals,
            Callback = function(value)
                VisualRuntime.setUpgradeEnabled(value, true)
            end,
        },
    },
    {
        control = "hideCollectVisualsToggle",
        options = {
            Title = "Hide Collect Visuals",
            Desc = "Hides local +$ collect popups and their linked money effects. Enabled by default and uses event detection without periodic scanning.",
            Value = State.hideCollectVisuals,
            Callback = function(value)
                VisualRuntime.setCollectEnabled(value, true)
            end,
        },
    },
})

addToggles(ConfigurationSection, {
    {
        control = "autoSaveToggle",
        options = {
            Title = "Auto Save",
            Desc = "Saves settings with a short debounce.",
            Value = State.autoSave,
            Callback = function(value)
                State.autoSave = value == true
                if State.autoSave then
                    ConfigRuntime.queueSave()
                else
                    ConfigRuntime.save(true)
                end
            end,
        },
    },
})

createButton(SessionSection, {
    Title = "Close Hub",
    Desc = "Stops automation and destroys the interface.",
    Callback = function()
        Hub.Stop()
    end,
})

State.controlCallbacksReady = true

function InterfaceRuntime.applyWindowKeybind()
    local keyCode = Enum.KeyCode[normalizeWindowKeybind(State.windowKeybind)]
    local success, errorMessage = pcall(function()
        Window:SetToggleKey(keyCode)
    end)
    if not success then
        LogRuntime.add("ERROR", "Window keybind could not be applied: " .. tostring(errorMessage))
    end
    return success
end

function Hub.GetState()
    return {
        running = State.running,
        game = RuntimeName.game,
        placeId = game.PlaceId,
        version = Hub.Version,
        build = Hub.Build,
        rebirth = RebirthRuntime.getState(),
        training = TrainingRuntime.getState(),
        weightTraining = WeightTrainingRuntime.getState(),
        weights = WeightRuntime.getState(),
        playtime = PlaytimeRuntime.getState(),
        spin = SpinRuntime.getState(),
        kick = KickRuntime.getState(),
        kickRewards = KickRewardRuntime.getState(),
        plot = PlotRuntime.getState(),
        collect = CollectRuntime.getState(),
        cardUpgrade = CardUpgradeRuntime.getState(),
        cardPlacement = CardPlacementRuntime.getState(),
        cardPickup = CardPickupRuntime.getState(),
        speedUpgrade = SpeedUpgradeRuntime.getState(),
        antiAfk = AntiAfkRuntime.getState(),
        interfaceVisuals = VisualRuntime.getState(),
        configPath = ConfigRuntime.path,
    }
end

Hub.Rebirth = {
    SetAuto = function(enabled)
        RebirthRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAuto = function()
        RebirthRuntime.setAuto(not State.autoRebirth, true)
        ConfigRuntime.syncControls()
        return State.autoRebirth
    end,
    Process = RebirthRuntime.process,
    GetState = RebirthRuntime.getState,
}

Hub.Training = {
    SetAuto = function(enabled)
        TrainingRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAuto = function()
        TrainingRuntime.setAuto(not State.autoTrainingWeight, true)
        ConfigRuntime.syncControls()
        return State.autoTrainingWeight
    end,
    SetHideNativeVisuals = function(enabled)
        TrainingRuntime.setHideVisuals(enabled, true)
        ConfigRuntime.syncControls()
    end,
    SetAutoTraining = function(enabled)
        WeightTrainingRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAutoTraining = function()
        WeightTrainingRuntime.setAuto(not State.autoWeightTraining, true)
        ConfigRuntime.syncControls()
        return State.autoWeightTraining
    end,
    SetFreeMovement = function(enabled)
        WeightTrainingRuntime.setFreeMovement(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleFreeMovement = function()
        WeightTrainingRuntime.setFreeMovement(not State.freeMovementWhileTraining, true)
        ConfigRuntime.syncControls()
        return State.freeMovementWhileTraining
    end,
    Process = TrainingRuntime.process,
    ProcessWeight = WeightTrainingRuntime.process,
    GetState = TrainingRuntime.getState,
    GetWeightState = WeightTrainingRuntime.getState,
}


Hub.WeightTraining = {
    SetAuto = function(enabled)
        WeightTrainingRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAuto = function()
        WeightTrainingRuntime.setAuto(not State.autoWeightTraining, true)
        ConfigRuntime.syncControls()
        return State.autoWeightTraining
    end,
    SetFreeMovement = function(enabled)
        WeightTrainingRuntime.setFreeMovement(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleFreeMovement = function()
        WeightTrainingRuntime.setFreeMovement(not State.freeMovementWhileTraining, true)
        ConfigRuntime.syncControls()
        return State.freeMovementWhileTraining
    end,
    Process = WeightTrainingRuntime.process,
    GetState = WeightTrainingRuntime.getState,
}
Hub.Weights = {
    SetAuto = function(enabled)
        WeightRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAuto = function()
        WeightRuntime.setAuto(not State.autoBuyWeights, true)
        ConfigRuntime.syncControls()
        return State.autoBuyWeights
    end,
    SetBestAffordable = function(enabled)
        WeightRuntime.setAutoBestAffordable(enabled, true)
        ConfigRuntime.syncControls()
        return State.autoBuyBestAffordableWeight
    end,
    ToggleBestAffordable = function()
        WeightRuntime.setAutoBestAffordable(not State.autoBuyBestAffordableWeight, true)
        ConfigRuntime.syncControls()
        return State.autoBuyBestAffordableWeight
    end,
    SetWhitelist = function(value)
        WeightRuntime.setWhitelist(value, true)
        ConfigRuntime.syncControls()
    end,
    GetWhitelist = WeightRuntime.getWhitelist,
    Refresh = function()
        return WeightRuntime.refreshUnlocked(false)
    end,
    EquipBest = function()
        return WeightRuntime.ensureBestOwnedEquipped()
    end,
    Process = WeightRuntime.process,
    GetState = WeightRuntime.getState,
}


Hub.KickRewards = {
    SetThreshold = function(value)
        local threshold = KickRewardRuntime.setThreshold(value, true)
        ConfigRuntime.syncControls()
        return threshold
    end,
    SetCardNames = function(value)
        local result = KickRewardRuntime.setCardNameWhitelist(value, true)
        ConfigRuntime.syncControls()
        return result
    end,
    SetRarities = function(value)
        local result = KickRewardRuntime.setRarityWhitelist(value, true)
        ConfigRuntime.syncControls()
        return result
    end,
    SetMutations = function(value)
        local result = KickRewardRuntime.setMutationWhitelist(value, true)
        ConfigRuntime.syncControls()
        return result
    end,
    GetCardNames = KickRewardRuntime.getCardNameWhitelist,
    GetRarities = KickRewardRuntime.getRarityWhitelist,
    GetMutations = KickRewardRuntime.getMutationWhitelist,
    GetState = KickRewardRuntime.getState,
}

Hub.Playtime = {
    SetAuto = function(enabled)
        PlaytimeRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAuto = function()
        PlaytimeRuntime.setAuto(not State.autoClaimPlaytimeRewards, true)
        ConfigRuntime.syncControls()
        return State.autoClaimPlaytimeRewards
    end,
    Refresh = function()
        return PlaytimeRuntime.refreshState(false)
    end,
    Process = PlaytimeRuntime.process,
    GetState = PlaytimeRuntime.getState,
}

Hub.Spin = {
    SetAuto = function(enabled)
        SpinRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAuto = function()
        SpinRuntime.setAuto(not State.autoSpin, true)
        ConfigRuntime.syncControls()
        return State.autoSpin
    end,
    Process = SpinRuntime.process,
    GetState = SpinRuntime.getState,
}

Hub.Kick = {
    SetAutoSecretLanding = function(enabled)
        KickRuntime.setMode("LOW RISK", enabled, true)
        return State.autoLandSecretChance
    end,
    ToggleAutoSecretLanding = function()
        KickRuntime.setMode("LOW RISK", not State.autoLandSecretChanceLowRisk, true)
        return State.autoLandSecretChanceLowRisk
    end,
    SetLowRisk = function(enabled)
        KickRuntime.setMode("LOW RISK", enabled, true)
        return State.autoLandSecretChanceLowRisk
    end,
    ToggleLowRisk = function()
        KickRuntime.setMode("LOW RISK", not State.autoLandSecretChanceLowRisk, true)
        return State.autoLandSecretChanceLowRisk
    end,
    SetRisk = function(enabled)
        KickRuntime.setMode("RISK", enabled, true)
        return State.autoLandSecretChanceRisk
    end,
    ToggleRisk = function()
        KickRuntime.setMode("RISK", not State.autoLandSecretChanceRisk, true)
        return State.autoLandSecretChanceRisk
    end,
    SetRunSpeedMultiplier = function(value)
        local multiplier = KickRuntime.setRunSpeedMultiplier(value, true)
        ConfigRuntime.syncControls()
        return multiplier
    end,
    GetState = KickRuntime.getState,
}


Hub.Plot = {
    SetAutoCollect = function(enabled)
        CollectRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAutoCollect = function()
        CollectRuntime.setAuto(not State.autoCollectMoney, true)
        ConfigRuntime.syncControls()
        return State.autoCollectMoney
    end,
    SetCollectCycleDelay = function(value)
        local delay = CollectRuntime.setCycleDelay(value, true)
        ConfigRuntime.syncControls()
        return delay
    end,
    ProcessCollect = CollectRuntime.process,
    GetCollectState = CollectRuntime.getState,
}

Hub.Cards = {
    SetCollectCycleDelay = function(value)
        local delay = CollectRuntime.setCycleDelay(value, true)
        ConfigRuntime.syncControls()
        return delay
    end,
    SetAutoUpgrade = function(enabled)
        CardUpgradeRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAutoUpgrade = function()
        CardUpgradeRuntime.setAuto(not State.autoUpgradePlacedCards, true)
        ConfigRuntime.syncControls()
        return State.autoUpgradePlacedCards
    end,
    SetUpgradeRarities = function(value)
        CardUpgradeRuntime.setWhitelist(value, true)
        ConfigRuntime.syncControls()
    end,
    GetUpgradeRarities = CardUpgradeRuntime.getWhitelist,
    SetTargetLevel = function(value)
        CardUpgradeRuntime.setTargetLevel(value, true)
        ConfigRuntime.syncControls()
        return State.cardUpgradeTargetLevel
    end,
    ProcessUpgrade = CardUpgradeRuntime.process,
    GetUpgradeState = CardUpgradeRuntime.getState,
    SetAutoFillEmpty = function(enabled)
        CardPlacementRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAutoFillEmpty = function()
        CardPlacementRuntime.setAuto(not State.autoFillEmptySlots, true)
        ConfigRuntime.syncControls()
        return State.autoFillEmptySlots
    end,
    SetFillPriorities = function(value)
        CardPlacementRuntime.setPriorities(value, true)
        ConfigRuntime.syncControls()
        return CardPlacementRuntime.getPriorities()
    end,
    GetFillPriorities = CardPlacementRuntime.getPriorities,
    ResetFillPriorityPlan = function()
        CardPlacementRuntime.resetPriorityPlan()
        return CardPlacementRuntime.getState()
    end,
    ProcessFillEmpty = CardPlacementRuntime.process,
    GetPlacementState = CardPlacementRuntime.getState,
    SetAutoPickupPlaced = function(enabled)
        CardPickupRuntime.setAuto(enabled, true)
        return State.autoPickupPlacedCards
    end,
    ToggleAutoPickupPlaced = function()
        CardPickupRuntime.setAuto(not State.autoPickupPlacedCards, true)
        return State.autoPickupPlacedCards
    end,
    ProcessPickupPlaced = CardPickupRuntime.process,
    GetPickupState = CardPickupRuntime.getState,
}

Hub.Upgrades = {
    SetAutoSpeed = function(enabled)
        SpeedUpgradeRuntime.setAuto(enabled, true)
        ConfigRuntime.syncControls()
    end,
    ToggleAutoSpeed = function()
        SpeedUpgradeRuntime.setAuto(not State.autoUpgradeSpeed, true)
        ConfigRuntime.syncControls()
        return State.autoUpgradeSpeed
    end,
    SetSpeedTarget = function(value)
        SpeedUpgradeRuntime.setTargetLevel(value, true)
        ConfigRuntime.syncControls()
        return State.speedUpgradeTargetLevel
    end,
    Refresh = SpeedUpgradeRuntime.refresh,
    ProcessSpeed = SpeedUpgradeRuntime.process,
    GetState = SpeedUpgradeRuntime.getState,
}

Hub.AntiAfk = {
    SetEnabled = function(enabled)
        AntiAfkRuntime.setEnabled(enabled, true)
        ConfigRuntime.syncControls()
    end,
    Pulse = AntiAfkRuntime.pulse,
    GetState = AntiAfkRuntime.getState,
}



Hub.Interface = {
    SetHideUpgradeVisuals = function(enabled)
        VisualRuntime.setUpgradeEnabled(enabled, true)
        ConfigRuntime.syncControls()
        return State.hideUpgradeVisuals
    end,
    ToggleHideUpgradeVisuals = function()
        VisualRuntime.setUpgradeEnabled(not State.hideUpgradeVisuals, true)
        ConfigRuntime.syncControls()
        return State.hideUpgradeVisuals
    end,
    SetHideCollectVisuals = function(enabled)
        VisualRuntime.setCollectEnabled(enabled, true)
        ConfigRuntime.syncControls()
        return State.hideCollectVisuals
    end,
    ToggleHideCollectVisuals = function()
        VisualRuntime.setCollectEnabled(not State.hideCollectVisuals, true)
        ConfigRuntime.syncControls()
        return State.hideCollectVisuals
    end,
    SetHideUpgradeCollectVisuals = function(enabled)
        VisualRuntime.setEnabled(enabled, true)
        ConfigRuntime.syncControls()
        return State.hideUpgradeVisuals and State.hideCollectVisuals
    end,
    RefreshVisuals = VisualRuntime.applyExisting,
    GetState = VisualRuntime.getState,
}

Hub.Logs = {
    Clear = LogRuntime.clear,
    Add = LogRuntime.add,
    GetEntries = function()
        return table.clone(State.logs)
    end,
    SetFilter = function(value)
        State.logFilter = normalizeLogFilter(value)
        LogRuntime.render()
        ConfigRuntime.syncControls()
        ConfigRuntime.queueSave()
    end,
}

Hub.Config = {
    Path = ConfigRuntime.path,
    Save = function()
        return ConfigRuntime.save(true)
    end,
    Load = function()
        local success = ConfigRuntime.load()
        ConfigRuntime.syncControls()
        RebirthRuntime.setAuto(State.autoRebirth, false)
        TrainingRuntime.setAuto(State.autoTrainingWeight, false)
        WeightTrainingRuntime.setAuto(State.autoWeightTraining, false)
        WeightTrainingRuntime.setFreeMovement(State.freeMovementWhileTraining, false)
        WeightRuntime.setAuto(State.autoBuyWeights, false)
        WeightRuntime.setAutoBestAffordable(State.autoBuyBestAffordableWeight, false)
        PlaytimeRuntime.setAuto(State.autoClaimPlaytimeRewards, false)
        SpinRuntime.setAuto(State.autoSpin, false)
        KickRuntime.applyModeState()
        KickRuntime.resetLifecycle(State.autoLandSecretChance and "Ready" or "Disabled")
        CollectRuntime.setAuto(State.autoCollectMoney, false)
        CardUpgradeRuntime.setAuto(State.autoUpgradePlacedCards, false)
        CardPlacementRuntime.setAuto(State.autoFillEmptySlots, false)
        CardPickupRuntime.setAuto(State.autoPickupPlacedCards, false)
        SpeedUpgradeRuntime.setAuto(State.autoUpgradeSpeed, false)
        AntiAfkRuntime.setEnabled(State.antiAfk, false)
        VisualRuntime.setUpgradeEnabled(State.hideUpgradeVisuals, false)
        VisualRuntime.setCollectEnabled(State.hideCollectVisuals, false)
        InterfaceRuntime.applyWindowKeybind()
        return success
    end,
}

function Hub.Stop()
    if not State.running then
        return
    end
    State.running = false
    RebirthRuntime.setAuto(false, false)
    TrainingRuntime.setAuto(false, false)
    WeightTrainingRuntime.setAuto(false, false)
    WeightTrainingRuntime.setFreeMovement(false, false)
    WeightRuntime.setAuto(false, false)
    WeightRuntime.setAutoBestAffordable(false, false)
    PlaytimeRuntime.setAuto(false, false)
    SpinRuntime.setAuto(false, false)
    KickRuntime.setMode("LOW RISK", false, false)
    KickRuntime.setMode("RISK", false, false)
    CollectRuntime.setAuto(false, false)
    CardUpgradeRuntime.setAuto(false, false)
    CardPlacementRuntime.setAuto(false, false)
    CardPickupRuntime.setAuto(false, false)
    SpeedUpgradeRuntime.setAuto(false, false)
    CardPlacementRuntime.unequip()
    PlotRuntime.clearCache("Stopped")
    TrainingRuntime.setNativeSuppressed(false)
    table.clear(State.trainingNativeConnections)
    VisualRuntime.restoreAll()
    AntiAfkRuntime.setEnabled(false, false)
    for _, definition in ipairs(BooleanSettingDefinitions) do
        if definition.stop then
            State[definition.state] = false
        end
    end
    ConfigRuntime.syncControls()
    ConnectionRuntime.disconnectAll()
    local window = State.window
    State.window = nil
    if window then
        pcall(function()
            window:Destroy()
        end)
    end
    if type(getgenv) == "function" and getgenv()[RuntimeName.global] == Hub then
        getgenv()[RuntimeName.global] = nil
    end
end

if type(getgenv) == "function" then
    getgenv()[RuntimeName.global] = Hub
end

RebirthRuntime.bind()
TrainingRuntime.bind()
WeightRuntime.bind()
WeightRuntime.refreshUnlocked(true)
KickRewardRuntime.bind()
PlaytimeRuntime.refreshState(true)
SpinRuntime.bind()
SpeedUpgradeRuntime.bind()
AntiAfkRuntime.bind()
VisualRuntime.bind()
InterfaceRuntime.applyWindowKeybind()
ConfigRuntime.syncControls()

if State.autoSave and (not loadedConfig or State.configMigratedFrom ~= nil) then
    ConfigRuntime.save(true)
end

RebirthRuntime.setAuto(State.autoRebirth, false)
TrainingRuntime.setAuto(State.autoTrainingWeight, false)
WeightTrainingRuntime.setAuto(State.autoWeightTraining, false)
WeightTrainingRuntime.setFreeMovement(State.freeMovementWhileTraining, false)
WeightRuntime.setAuto(State.autoBuyWeights, false)
WeightRuntime.setAutoBestAffordable(State.autoBuyBestAffordableWeight, false)
PlaytimeRuntime.setAuto(State.autoClaimPlaytimeRewards, false)
SpinRuntime.setAuto(State.autoSpin, false)
KickRuntime.applyModeState()
KickRuntime.resetLifecycle(State.autoLandSecretChance and "Ready" or "Disabled")
CollectRuntime.setAuto(State.autoCollectMoney, false)
CardUpgradeRuntime.setAuto(State.autoUpgradePlacedCards, false)
CardPlacementRuntime.setAuto(State.autoFillEmptySlots, false)
CardPickupRuntime.setAuto(State.autoPickupPlacedCards, false)
SpeedUpgradeRuntime.setAuto(State.autoUpgradeSpeed, false)
AntiAfkRuntime.setEnabled(State.antiAfk, false)

SchedulerRuntime.start({
    {
        interval = function()
            return State.rebirthPollInterval
        end,
        callback = RebirthRuntime.tick,
    },
    {
        interval = function()
            return State.trainingPollInterval
        end,
        callback = TrainingRuntime.tick,
    },
    {
        interval = function()
            return State.weightTrainingPollInterval
        end,
        callback = WeightTrainingRuntime.tick,
    },
    {
        interval = function()
            return State.collectPollInterval
        end,
        callback = CollectRuntime.tick,
    },
    {
        interval = function()
            return State.weightPollInterval
        end,
        callback = WeightRuntime.tick,
    },
    {
        interval = function()
            return State.playtimePollInterval
        end,
        callback = PlaytimeRuntime.tick,
    },
    {
        interval = function()
            return State.spinPollInterval
        end,
        callback = SpinRuntime.tick,
    },
    {
        interval = function()
            return State.kickSecretPollInterval
        end,
        callback = KickRuntime.tick,
    },
    {
        interval = function()
            return State.plotSchedulerInterval
        end,
        callback = PlotRuntime.tick,
    },
    {
        interval = function()
            return State.speedUpgradePollInterval
        end,
        callback = SpeedUpgradeRuntime.tick,
    },
})

pcall(function()
    Window:SelectTab(1)
end)

LogRuntime.add("INFO", "Hub loaded for " .. RuntimeName.game)
