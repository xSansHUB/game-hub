--[[
    Standalone Loan Out Manager - WindUI

    Fitur:
      - Menggunakan WindUI dengan keybind G dan floating OpenButton.
      - Semua action button memakai layout vertikal full-width agar tidak overlap atau terpotong.
      - Title menggunakan nama game dan author xSansHUB.
      - Menampilkan seluruh pemain yang sedang loan out.
      - Collect All untuk seluruh loan yang sudah selesai.
      - Loan Top berdasarkan whitelist rarity dan durasi yang dipilih.
      - Toggle Auto Loan, Auto Collect, Auto Play, Auto Open Packs, Auto Claim Playtime Rewards, Auto Claim Daily Reward, Auto Equip Best stabil (pause Auto Play sampai lineup tidak berubah), Auto Join International Cup, Auto Collect Cup Rewards, Auto Collect PackDrop, Auto Conveyor, Anti AFK, Lock Position, dan Auto Prestige.
      - Pack session log, rarity filter log, Pick Pack selection, Skip Pack Animation, Instant Packs, dan Auto Buy Pack Shop dengan Prestige Priority.
      - Visual Fill International Cup: membuka menu Cup dan mengisi slot React melalui simulasi tombol UI.
      - Movement: anti tabrak sesama player tanpa anchor, Back to Base melalui Workspace.World.Plots, dan recovery Auto Conveyor pada part Animed Convoyor.
      - Loan Duration dan Rarity Whitelist berada tepat di atas toggle Auto Loan.
      - Pilihan durasi diambil dari LoanConfig.Durations.
      - Dashboard sesi Auto Loan: terkirim, masih berputar, selesai, dan income.
      - Config file: Save, Load, Auto Save, dan Auto Load per PlaceId.
      - Polling-only UI refresh; tidak memakai callback DataChanged game.
      - Tidak mengubah atau membutuhkan ClubManager.

    API manual:
      LoanOutGUI.Toggle()
      LoanOutGUI.Show()
      LoanOutGUI.Hide()
      LoanOutGUI.Refresh()
      LoanOutGUI.CollectAll()
      LoanOutGUI.LoanTop()
      LoanOutGUI.SetDuration(minutes)
      LoanOutGUI.SetRarityEnabled(rarity, true/false)
      LoanOutGUI.SetWhitelist({Legendary = true, Epic = false})
      LoanOutGUI.ResetDashboard()
      LoanOutGUI.ToggleAutoLoan()
      LoanOutGUI.ToggleAutoCollect()
      LoanOutGUI.ToggleAutoPrestige()
      LoanOutGUI.ToggleAutoMatch()
      LoanOutGUI.ToggleAutoOpenPacks()
      LoanOutGUI.SetPackPickMode("best_rarity" / "best_ovr" / "best_rarity_ovr")
      LoanOutGUI.SetSkipPackAnimation(true/false)
      LoanOutGUI.SetInstantPacks(true/false)
      LoanOutGUI.SetAutoBuyPacks(true/false)
      LoanOutGUI.SetPackBuyWhitelist({Basic = true, Premium = false})
      LoanOutGUI.SetPackBuyPrestigePriority(true/false)
      LoanOutGUI.BuyPacksNow() -- membeli tepat 1 pack dari tier terpilih
      LoanOutGUI.GetUICapabilityState()
      LoanOutGUI.GetPackSessionLog()
      LoanOutGUI.ClearPackSessionLog()
      LoanOutGUI.ToggleAutoClaimPlayTimeRewards()
      LoanOutGUI.ClaimPlayTimeRewardsNow()
      LoanOutGUI.ToggleAutoClaimDailyReward()
      LoanOutGUI.ClaimDailyRewardNow()
      LoanOutGUI.ToggleAutoEquipBest()
      LoanOutGUI.ToggleAutoJoinWorldCup()
      LoanOutGUI.ToggleAutoCollectWorldCupRewards()
      LoanOutGUI.ToggleAutoPickupSpawnedPacks()
      LoanOutGUI.FillWorldCupVisualSquad()
      LoanOutGUI.CollectWorldCupRewardNow()
      LoanOutGUI.PickupSpawnedPacksNow()
      LoanOutGUI.SetWorldCupSquadMode("last_team" / "best_rarity_ovr")
      LoanOutGUI.ToggleLockPosition()
      LoanOutGUI.SetLockPosition(true/false)
      LoanOutGUI.BackToBase()
      LoanOutGUI.ToggleAutoConveyor()
      LoanOutGUI.SetAutoConveyor(true/false)
      LoanOutGUI.TeleportToConveyor()
      LoanOutGUI.ToggleAntiAfk()
      LoanOutGUI.SetAntiAfk(true/false)
      LoanOutGUI.PulseAntiAfk()
      LoanOutGUI.Rejoin()
      LoanOutGUI.PrestigeNow()
      LoanOutGUI.SaveConfig()
      LoanOutGUI.LoadConfig()
      LoanOutGUI.SetAutoSave(true/false)
      LoanOutGUI.SetAutoLoad(true/false)
      LoanOutGUI.Stop()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Environment = if type(getgenv) == "function" then getgenv() else _G

-- Hentikan build sebelumnya seawal mungkin. Build lama memasang callback
-- DataChanged pada free-thread Signal game, sehingga callback tersebut dapat
-- terus memanggil WindUI walau build baru sedang dibuat.
do
    local previous = Environment.LoanOutGUI
    if type(previous) == "table" and type(previous.Stop) == "function" then
        pcall(function()
            previous.Stop()
        end)
    end
end

local function getCurrentGameName()
    local fallbackName = tostring(game.Name or "Unknown Game")

    local success, productInfo = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)

    if success
        and type(productInfo) == "table"
        and type(productInfo.Name) == "string"
        and productInfo.Name ~= ""
    then
        return productInfo.Name
    end

    if fallbackName == "" then
        return "Unknown Game"
    end

    return fallbackName
end

local GAME_NAME = getCurrentGameName()
local HUB_TITLE = GAME_NAME

local CONFIG_VERSION = 23
local CONFIG_ROOT = "xSansHUB"
local CONFIG_FOLDER = CONFIG_ROOT .. "/LoanOutManager"
local CONFIG_FILE = CONFIG_FOLDER .. "/" .. tostring(game.PlaceId) .. ".json"
local CONFIG_FILE_SUPPORTED = type(readfile) == "function" and type(writefile) == "function"

local function normalizeKeybindName(value)
    local keyName = tostring(value or "G")
    if Enum.KeyCode[keyName] then
        return keyName
    end
    return "G"
end

local WORLD_CUP_SQUAD_MODE_LAST = "last_team"
local WORLD_CUP_SQUAD_MODE_BEST = "best_rarity_ovr"

local function normalizeWorldCupSquadMode(value)
    value = tostring(value or WORLD_CUP_SQUAD_MODE_BEST)

    if value == WORLD_CUP_SQUAD_MODE_LAST
        or value == "Last Team"
        or value == "last"
    then
        return WORLD_CUP_SQUAD_MODE_LAST
    end

    return WORLD_CUP_SQUAD_MODE_BEST
end

local function worldCupSquadModeLabel(value)
    if normalizeWorldCupSquadMode(value) == WORLD_CUP_SQUAD_MODE_LAST then
        return "Last Team"
    end
    return "Best Rarity / OVR"
end

local PACK_PICK_MODE_RARITY = "best_rarity"
local PACK_PICK_MODE_OVR = "best_ovr"
local PACK_PICK_MODE_RARITY_OVR = "best_rarity_ovr"

local function normalizePackPickMode(value)
    value = tostring(value or PACK_PICK_MODE_RARITY_OVR)

    if value == PACK_PICK_MODE_RARITY
        or value == "Best Rarity"
        or value == "rarity"
    then
        return PACK_PICK_MODE_RARITY
    end

    if value == PACK_PICK_MODE_OVR
        or value == "Best OVR"
        or value == "ovr"
        or value == "rating"
    then
        return PACK_PICK_MODE_OVR
    end

    return PACK_PICK_MODE_RARITY_OVR
end

local function packPickModeLabel(value)
    value = normalizePackPickMode(value)

    if value == PACK_PICK_MODE_RARITY then
        return "Best Rarity"
    end

    if value == PACK_PICK_MODE_OVR then
        return "Best OVR"
    end

    return "Best Rarity + OVR"
end

local function configFileExists()
    if not CONFIG_FILE_SUPPORTED then
        return false
    end

    if type(isfile) == "function" then
        local success, exists = pcall(isfile, CONFIG_FILE)
        return success and exists == true
    end

    return pcall(readfile, CONFIG_FILE)
end

local function readRawConfigFile()
    if not CONFIG_FILE_SUPPORTED then
        return nil, "Executor tidak mendukung readfile/writefile"
    end

    if not configFileExists() then
        return nil, "Config belum tersimpan"
    end

    local readSuccess, content = pcall(readfile, CONFIG_FILE)
    if not readSuccess then
        return nil, tostring(content)
    end

    local decodeSuccess, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not decodeSuccess or type(decoded) ~= "table" then
        return nil, decodeSuccess and "Format config tidak valid" or tostring(decoded)
    end

    return decoded
end

local function mergeRawConfig(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    if source.autoLoan ~= nil then
        target.autoLoan = source.autoLoan == true
    end
    if source.autoCollect ~= nil then
        target.autoCollect = source.autoCollect == true
    end
    if source.autoPrestige ~= nil then
        target.autoPrestige = source.autoPrestige == true
    end
    -- autoPlay adalah nama config baru. autoMatch tetap dibaca untuk migrasi
    -- dari config versi lama.
    if source.autoPlay ~= nil then
        target.autoPlay = source.autoPlay == true
        target.autoMatch = source.autoPlay == true
    elseif source.autoMatch ~= nil then
        target.autoPlay = source.autoMatch == true
        target.autoMatch = source.autoMatch == true
    end
    if source.autoOpenPacks ~= nil then
        target.autoOpenPacks = source.autoOpenPacks == true
    end
    if source.packPickMode ~= nil then
        target.packPickMode = normalizePackPickMode(source.packPickMode)
    end
    if source.skipPackAnimation ~= nil then
        target.skipPackAnimation = source.skipPackAnimation == true
    end
    if source.instantPacks ~= nil then
        target.instantPacks = source.instantPacks == true
    end
    if source.autoBuyPacks ~= nil then
        target.autoBuyPacks = source.autoBuyPacks == true
    end
    if source.packBuyPrestigePriority ~= nil then
        target.packBuyPrestigePriority = source.packBuyPrestigePriority == true
    end
    if type(source.packBuyWhitelist) == "table" then
        target.packBuyWhitelist = {}
        for tier, enabled in pairs(source.packBuyWhitelist) do
            target.packBuyWhitelist[tostring(tier)] = enabled == true
        end
    end
    if type(source.packLogRarityWhitelist) == "table" then
        target.packLogRarityWhitelist = {}
        for rarity, enabled in pairs(source.packLogRarityWhitelist) do
            target.packLogRarityWhitelist[tostring(rarity)] = enabled == true
        end
    end
    if source.autoClaimPlayTimeRewards ~= nil then
        target.autoClaimPlayTimeRewards = source.autoClaimPlayTimeRewards == true
    end
    if source.autoClaimDailyReward ~= nil then
        target.autoClaimDailyReward = source.autoClaimDailyReward == true
    end
    if source.autoEquipBest ~= nil then
        target.autoEquipBest = source.autoEquipBest == true
    end
    if source.autoJoinWorldCup ~= nil then
        target.autoJoinWorldCup = source.autoJoinWorldCup == true
    end
    if source.autoCollectWorldCupRewards ~= nil then
        target.autoCollectWorldCupRewards = source.autoCollectWorldCupRewards == true
    end
    if source.fillWorldCupVisualBeforeJoin ~= nil then
        target.fillWorldCupVisualBeforeJoin = source.fillWorldCupVisualBeforeJoin == true
    end
    if source.autoPickupSpawnedPacks ~= nil then
        target.autoPickupSpawnedPacks = source.autoPickupSpawnedPacks == true
    end
    if source.lockPosition ~= nil then
        target.lockPosition = source.lockPosition == true
    end
    if source.autoConveyor ~= nil then
        target.autoConveyor = source.autoConveyor == true
    end
    if source.worldCupSquadMode ~= nil then
        target.worldCupSquadMode = normalizeWorldCupSquadMode(source.worldCupSquadMode)
    end
    if tonumber(source.duration) then
        target.duration = tonumber(source.duration)
    end
    if type(source.rarityWhitelist) == "table" then
        target.rarityWhitelist = {}
        for rarity, enabled in pairs(source.rarityWhitelist) do
            target.rarityWhitelist[tostring(rarity)] = enabled == true
        end
    end
    if source.autoSave ~= nil then
        target.autoSave = source.autoSave == true
    end
    if source.autoLoad ~= nil then
        target.autoLoad = source.autoLoad == true
    end
    if source.windowKeybind ~= nil then
        target.windowKeybind = normalizeKeybindName(source.windowKeybind)
    end
end

local GUI_NAME = "StandaloneLoanOutGUI"
local POLL_INTERVAL = 1
local DISCOVERY_ATTEMPTS = 80
local DISCOVERY_DELAY = 0.25
local TOP_CARD_SCAN_INTERVAL = 2
local AUTO_ACTION_INTERVAL = 0.75
local AUTO_RETRY_DELAY = 2
local PRESTIGE_CHECK_INTERVAL = 2
local PRESTIGE_RETRY_DELAY = 8
local PRESTIGE_SUCCESS_DELAY = 3
local AUTO_MATCH_RETRY_DELAY = 5
local AUTO_PLAY_ENSURE_DELAY = 8
local AUTO_PACK_RETRY_DELAY = 8
local AUTO_BUY_PACK_INTERVAL = 1.5
local AUTO_BUY_PACK_RETRY_DELAY = 5
local AUTO_BUY_PACK_MAX_BATCH = 25
local PACK_BUY_PRESTIGE_REFRESH_INTERVAL = 4
local AUTO_EQUIP_BEST_RETRY_DELAY = 8
local AUTO_EQUIP_BEST_SETTLE_TIMEOUT = 2
local AUTO_EQUIP_BEST_MAX_PASSES = 4
local AUTO_MATCH_PAUSE_TIMEOUT = 3
local WORLD_CUP_CHECK_INTERVAL = 6
local WORLD_CUP_RETRY_DELAY = 12
local WORLD_CUP_SUCCESS_DELAY = 15
local WORLD_CUP_VISUAL_TIMEOUT = 7
local WORLD_CUP_VISUAL_STEP_DELAY = 0.18
local WORLD_CUP_REWARD_CHECK_INTERVAL = 5
local SPAWNED_PACK_SCAN_INTERVAL = 2
local SPAWNED_PACK_INTERACT_COOLDOWN = 3
local SPAWNED_PACK_RADIUS = 90
local BASE_TELEPORT_HEIGHT = 4
local CONVEYOR_TELEPORT_HEIGHT = 4
local MOVEMENT_OVERRIDE_DURATION = 0.75
local BASE_PICKUP_SETTLE_DELAY = 0.35
local TRACKED_LOAN_GRACE = 5

local FALLBACK_DURATIONS = {5, 15, 30, 60}

local WORLD_CUP_FORMATIONS = {
    "4-4-2",
    "4-3-3",
    "5-3-2",
    "4-2-3-1",
}

local RARITY_PRIORITY = {
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    WorldClass = 5,
    Secret = 6,
    Rainbow = 7,
    Flaming = 8,
    Godly = 9,
    Forbidden = 10,
    Sacred = 11,
}

local RARITY_DISPLAY_ORDER = {
    "Sacred",
    "Forbidden",
    "Godly",
    "Flaming",
    "Rainbow",
    "Secret",
    "WorldClass",
    "Legendary",
    "Epic",
    "Rare",
    "Common",
}

local COLORS = {
    background = Color3.fromRGB(17, 19, 26),
    panel = Color3.fromRGB(24, 27, 36),
    panelAlt = Color3.fromRGB(30, 34, 45),
    border = Color3.fromRGB(67, 73, 94),
    primary = Color3.fromRGB(112, 92, 255),
    primaryHover = Color3.fromRGB(130, 112, 255),
    text = Color3.fromRGB(242, 244, 255),
    muted = Color3.fromRGB(158, 164, 187),
    success = Color3.fromRGB(80, 220, 135),
    warning = Color3.fromRGB(255, 196, 77),
    danger = Color3.fromRGB(245, 91, 105),
}

local PersistentConfig = Environment.LoanOutGUIConfig
if type(PersistentConfig) ~= "table" then
    PersistentConfig = {}
    Environment.LoanOutGUIConfig = PersistentConfig
end

local StartupConfigLoaded = false
local StartupConfigError = nil
local StartupDiskConfig = nil

if CONFIG_FILE_SUPPORTED then
    local loadedConfig, loadError = readRawConfigFile()
    if loadedConfig then
        StartupDiskConfig = loadedConfig

        -- Auto Save/Auto Load selalu dibaca sebagai metadata. Isi konfigurasi lain
        -- hanya diterapkan otomatis ketika Auto Load aktif.
        if loadedConfig.autoSave ~= nil then
            PersistentConfig.autoSave = loadedConfig.autoSave == true
        end
        if loadedConfig.autoLoad ~= nil then
            PersistentConfig.autoLoad = loadedConfig.autoLoad == true
        end

        if loadedConfig.autoLoad ~= false then
            mergeRawConfig(PersistentConfig, loadedConfig)
            StartupConfigLoaded = true
        end
    elseif loadError ~= "Config belum tersimpan" then
        StartupConfigError = loadError
    end
end

if type(PersistentConfig.rarityWhitelist) ~= "table" then
    PersistentConfig.rarityWhitelist = {}
end
if PersistentConfig.autoSave == nil then
    PersistentConfig.autoSave = true
end
if PersistentConfig.autoLoad == nil then
    PersistentConfig.autoLoad = true
end
PersistentConfig.windowKeybind = normalizeKeybindName(PersistentConfig.windowKeybind)
PersistentConfig.worldCupSquadMode = normalizeWorldCupSquadMode(PersistentConfig.worldCupSquadMode)
PersistentConfig.packPickMode = normalizePackPickMode(PersistentConfig.packPickMode)
if PersistentConfig.skipPackAnimation == nil then
    PersistentConfig.skipPackAnimation = true
end
if PersistentConfig.instantPacks == nil then
    PersistentConfig.instantPacks = false
end
if PersistentConfig.autoBuyPacks == nil then
    PersistentConfig.autoBuyPacks = false
end
if PersistentConfig.packBuyPrestigePriority == nil then
    PersistentConfig.packBuyPrestigePriority = true
end
if type(PersistentConfig.packBuyWhitelist) ~= "table" then
    PersistentConfig.packBuyWhitelist = {}
end
if type(PersistentConfig.packLogRarityWhitelist) ~= "table" then
    PersistentConfig.packLogRarityWhitelist = {}
end
for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
    if PersistentConfig.packLogRarityWhitelist[rarity] == nil then
        PersistentConfig.packLogRarityWhitelist[rarity] = true
    end
end
if PersistentConfig.autoCollectWorldCupRewards == nil then
    PersistentConfig.autoCollectWorldCupRewards = true
end
if PersistentConfig.fillWorldCupVisualBeforeJoin == nil then
    PersistentConfig.fillWorldCupVisualBeforeJoin = true
end
if PersistentConfig.autoPickupSpawnedPacks == nil then
    PersistentConfig.autoPickupSpawnedPacks = true
end
if PersistentConfig.lockPosition == nil then
    PersistentConfig.lockPosition = false
end
if PersistentConfig.autoConveyor == nil then
    PersistentConfig.autoConveyor = false
end
if PersistentConfig.antiAfk == nil then
    PersistentConfig.antiAfk = true
end

if PersistentConfig.autoClaimPlayTimeRewards == nil then
    PersistentConfig.autoClaimPlayTimeRewards = false
end
if PersistentConfig.autoClaimDailyReward == nil then
    PersistentConfig.autoClaimDailyReward = false
end

-- Migrasi config lama: field autoMatch sebelumnya hanya mengatur tombol STOP.
-- Field baru autoPlay menjalankan AttemptSendOut + SetAutoMatch + playback background.
if PersistentConfig.autoPlay == nil and PersistentConfig.autoMatch ~= nil then
    PersistentConfig.autoPlay = PersistentConfig.autoMatch == true
end

local Dashboard = Environment.LoanOutGUIDashboard
if type(Dashboard) ~= "table" then
    Dashboard = {
        autoSent = 0,
        autoCollected = 0,
        autoIncome = 0,
        failures = 0,
        lastAction = "No automation activity yet",
        lastIncome = 0,
        startedAt = os.time(),
        activeLoans = {},
    }
    Environment.LoanOutGUIDashboard = Dashboard
end

Dashboard.autoSent = tonumber(Dashboard.autoSent) or 0
Dashboard.autoCollected = tonumber(Dashboard.autoCollected) or 0
Dashboard.autoIncome = tonumber(Dashboard.autoIncome) or 0
Dashboard.failures = tonumber(Dashboard.failures) or 0
Dashboard.lastAction = tostring(Dashboard.lastAction or "No automation activity yet")
Dashboard.lastIncome = tonumber(Dashboard.lastIncome) or 0
Dashboard.startedAt = tonumber(Dashboard.startedAt) or os.time()
Dashboard.activeLoans = type(Dashboard.activeLoans) == "table" and Dashboard.activeLoans or {}

local PackSession = Environment.xSansHUBPackSession
if type(PackSession) ~= "table" then
    PackSession = {
        startedAt = os.time(),
        entries = {},
        totalOpened = 0,
        totalPickPacks = 0,
    }
    Environment.xSansHUBPackSession = PackSession
end
PackSession.startedAt = tonumber(PackSession.startedAt) or os.time()
PackSession.entries = type(PackSession.entries) == "table" and PackSession.entries or {}
PackSession.totalOpened = tonumber(PackSession.totalOpened) or 0
PackSession.totalPickPacks = tonumber(PackSession.totalPickPacks) or 0

local State = {
    running = true,
    visible = true,
    collecting = false,
    loaning = false,
    prestiging = false,
    autoLoan = PersistentConfig.autoLoan == true,
    autoCollect = PersistentConfig.autoCollect == true,
    autoPrestige = PersistentConfig.autoPrestige == true,
    autoMatch = (PersistentConfig.autoPlay ~= nil and PersistentConfig.autoPlay or PersistentConfig.autoMatch) == true,
    autoOpenPacks = PersistentConfig.autoOpenPacks == true,
    packPickMode = normalizePackPickMode(PersistentConfig.packPickMode),
    skipPackAnimation = PersistentConfig.skipPackAnimation ~= false,
    instantPacks = PersistentConfig.instantPacks == true,
    autoBuyPacks = PersistentConfig.autoBuyPacks == true,
    packBuyPrestigePriority = PersistentConfig.packBuyPrestigePriority ~= false,
    packBuyWhitelist = PersistentConfig.packBuyWhitelist,
    packShopTiers = {},
    packShopLabelToTier = {},
    packShopTierToLabel = {},
    packShopDiscoverySources = {},
    packShopDiscoveryScannedTables = 0,
    packLogRarityWhitelist = PersistentConfig.packLogRarityWhitelist,
    packSession = PackSession,
    autoClaimPlayTimeRewards = PersistentConfig.autoClaimPlayTimeRewards == true,
    autoClaimDailyReward = PersistentConfig.autoClaimDailyReward == true,
    autoEquipBest = PersistentConfig.autoEquipBest == true,
    autoJoinWorldCup = PersistentConfig.autoJoinWorldCup == true,
    autoCollectWorldCupRewards = PersistentConfig.autoCollectWorldCupRewards ~= false,
    fillWorldCupVisualBeforeJoin = PersistentConfig.fillWorldCupVisualBeforeJoin ~= false,
    autoPickupSpawnedPacks = PersistentConfig.autoPickupSpawnedPacks ~= false,
    lockPosition = PersistentConfig.lockPosition == true,
    autoConveyor = PersistentConfig.autoConveyor == true,
    antiAfk = PersistentConfig.antiAfk ~= false,
    antiAfkCount = 0,
    lastAntiAfkAt = 0,
    nextAntiAfkPulseAt = 0,
    antiAfkInterval = 45,
    antiAfkMethod = "waiting",
    lastAntiAfkError = nil,
    antiAfkBusy = false,
    worldCupSquadMode = normalizeWorldCupSquadMode(PersistentConfig.worldCupSquadMode),
    settingAutoMatch = false,
    openingPacks = false,
    buyingPacks = false,
    claimingPlayTimeRewards = false,
    claimingDailyReward = false,
    equippingBest = false,
    joiningWorldCup = false,
    collectingWorldCupReward = false,
    fillingWorldCupVisual = false,
    pickingSpawnedPacks = false,
    worldCupAutoPlayPaused = false,
    rejoining = false,
    autoMatchTransaction = false,
    matchPlaybackActive = false,
    matchEventListenersConnected = false,
    autoMatchPendingSync = (PersistentConfig.autoPlay ~= nil or PersistentConfig.autoMatch ~= nil) and StartupConfigLoaded,
    autoMatchSyncIgnoreUntil = 0,
    nextAutoMatchSyncAt = 0,
    nextAutoPlayEnsureAt = 0,
    nextAutoOpenPackAt = 0,
    nextAutoBuyPackAt = 0,
    nextPackBuyPrestigeRefreshAt = 0,
    nextPlayTimeClaimAt = 0,
    lastPlayTimeClaimAt = 0,
    lastPlayTimeClaimCount = 0,
    nextDailyRewardClaimAt = 0,
    lastDailyRewardClaimAt = 0,
    lastDailyRewardClaimDay = nil,
    lastDailyRewardClaimResponse = nil,
    lastDailyRewardClaimError = nil,
    lastObservedPackCount = 0,
    lastPackOpenAt = 0,
    lastPackPickAt = 0,
    lastPackPickTier = nil,
    lastPackPickIndex = nil,
    lastPackPickCard = nil,
    lastPackOpenCount = 0,
    lastPackPickCount = 0,
    lastPackOpenError = nil,
    lastInstantPackFallback = nil,
    lastPackBuyAt = 0,
    lastPackBuyTier = nil,
    lastPackBuyCount = 0,
    lastPackBuySpent = 0,
    lastPackBuyError = nil,
    lastPackBuyStatus = "idle",
    lastPackLogUpdateAt = 0,
    lastEquipBestSignature = nil,
    lastEquipBestAt = 0,
    lastEquipBestResult = "idle",
    autoEquipBestPasses = 0,
    autoEquipBestChanged = false,
    worldCupStatus = nil,
    worldCupStatusUpdatedAt = 0,
    lastWorldCupJoinAt = 0,
    lastWorldCupCollectAt = 0,
    lastWorldCupVisualFillAt = 0,
    lastWorldCupVisualFillCount = 0,
    lastWorldCupVisualFillError = nil,
    lastSpawnedPackPickupAt = 0,
    lastSpawnedPackPickupCount = 0,
    spawnedPackCandidates = {},
    lastSpawnedPackScanAt = 0,
    packInteractionTimestamps = setmetatable({}, {__mode = "k"}),
    packInteractionAttempts = setmetatable({}, {__mode = "k"}),
    cachedPlayerBase = nil,
    lastPlayerBaseScanAt = 0,
    cachedOwnedPlot = nil,
    cachedOwnedPlotSpawn = nil,
    lastOwnedPlotScanAt = 0,
    movementRoot = nil,
    movementRootWasAnchored = nil,
    lockedCFrame = nil,
    movementOverrideCFrame = nil,
    movementOverrideUntil = 0,
    playerCollisionStates = setmetatable({}, {__mode = "k"}),
    lastAntiCollisionSweepAt = 0,
    nextConveyorCheckAt = 0,
    lastConveyorRecoveryAt = 0,
    conveyorOutsideSince = nil,
    packPickupStartedAt = 0,
    lastBaseTeleportAt = 0,
    lastConveyorTeleportAt = 0,
    autoSave = PersistentConfig.autoSave ~= false,
    autoLoad = PersistentConfig.autoLoad ~= false,
    windowKeybind = normalizeKeybindName(PersistentConfig.windowKeybind),
    selectedDuration = tonumber(PersistentConfig.duration) or 5,
    rarityWhitelist = PersistentConfig.rarityWhitelist,
    durationOptions = {},
    rarityOptions = {},
    stats = Dashboard,
    autoLoanedIds = Dashboard.activeLoans,

    dataService = nil,
    networker = nil,
    eventBus = nil,
    prestigeInfo = nil,

    playerCardDatabase = nil,
    variantConfig = nil,
    loanConfig = nil,
    skillsConfig = nil,
    worldCupConfig = nil,
    playTimeConfig = nil,
    packConfig = nil,
    formationLayout = nil,
    cardResolve = nil,

    windUI = nil,
    window = nil,
    dashboardTab = nil,
    automationTab = nil,
    packsTab = nil,
    configurationTab = nil,
    settingsTab = nil,
    worldCupTab = nil,
    movementTab = nil,

    summaryParagraph = nil,
    dashboardParagraph = nil,
    statusParagraph = nil,
    loanListParagraph = nil,
    prestigeParagraph = nil,
    prestigeGateParagraphs = {},
    prestigeInfoUpdatedAt = 0,
    configurationParagraph = nil,
    packSummaryParagraph = nil,
    packShopParagraph = nil,
    packLogParagraph = nil,
    worldCupParagraph = nil,
    worldCupPreviewParagraph = nil,
    spawnedPackParagraph = nil,
    movementParagraph = nil,

    collectButton = nil,
    loanButton = nil,
    prestigeButton = nil,
    autoLoanToggle = nil,
    autoCollectToggle = nil,
    autoMatchToggle = nil,
    autoOpenPacksToggle = nil,
    packPickModeDropdown = nil,
    skipPackAnimationToggle = nil,
    instantPacksToggle = nil,
    autoBuyPacksToggle = nil,
    packBuyPrestigePriorityToggle = nil,
    packBuyWhitelistDropdown = nil,
    packBuyButton = nil,
    packLogRarityDropdown = nil,
    autoClaimPlayTimeRewardsToggle = nil,
    autoClaimDailyRewardToggle = nil,
    autoEquipBestToggle = nil,
    autoJoinWorldCupToggle = nil,
    autoCollectWorldCupRewardsToggle = nil,
    fillWorldCupVisualToggle = nil,
    autoPickupSpawnedPacksToggle = nil,
    lockPositionToggle = nil,
    autoConveyorToggle = nil,
    antiAfkToggle = nil,
    autoPrestigeToggle = nil,
    durationDropdown = nil,
    worldCupSquadDropdown = nil,
    rarityDropdown = nil,
    configParagraph = nil,
    autoSaveToggle = nil,
    autoLoadToggle = nil,
    windowKeybindControl = nil,
    saveConfigButton = nil,
    loadConfigButton = nil,
    worldCupJoinButton = nil,
    worldCupCheckButton = nil,
    worldCupVisualFillButton = nil,
    worldCupCollectButton = nil,
    spawnedPackPickupButton = nil,
    backToBaseButton = nil,
    teleportConveyorButton = nil,
    rejoinButton = nil,

    configSupported = CONFIG_FILE_SUPPORTED,
    configLoading = false,
    configDirty = false,
    configSaveToken = 0,
    configLastSavedAt = nil,
    startupConfigLoaded = StartupConfigLoaded,
    startupConfigError = StartupConfigError,

    collectButtonEnabled = false,
    loanButtonEnabled = false,
    syncingConfiguration = false,
    configurationFromUI = false,
    lastStatusText = "Connecting...",
    lastStatusKind = "WARNING",

    connections = {},
    lastStructureSignature = nil,
    cachedTopCard = nil,
    lastTopCardScan = 0,
    nextAutoLoanAt = 0,
    nextAutoCollectAt = 0,
    nextPrestigeCheckAt = 0,
    nextAutoEquipBestAt = 0,
    nextWorldCupCheckAt = 0,
    nextWorldCupRewardCheckAt = 0,
    nextSpawnedPackScanAt = 0,

    -- DataChanged milik game dijalankan melalui free-thread Signal.
    -- Callback tersebut tidak boleh menyentuh Instance/WindUI secara langsung.
    uiRefreshRequested = false,
    uiCapabilityFailures = 0,
    lastUiCapabilityError = nil,
    lastUiCapabilityMethod = nil,
    packUiDirty = true,
    pendingStatus = nil,
    forceUIRefreshRequested = false,
}

local updateConfigManagerUI

local function copyWhitelistForConfig()
    local result = {}

    if #State.rarityOptions > 0 then
        for _, rarity in ipairs(State.rarityOptions) do
            result[tostring(rarity)] = State.rarityWhitelist[rarity] ~= false
        end
    else
        for rarity, enabled in pairs(State.rarityWhitelist) do
            result[tostring(rarity)] = enabled == true
        end
    end

    return result
end

local function copyPackLogWhitelistForConfig()
    local result = {}
    for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
        result[rarity] = State.packLogRarityWhitelist[rarity] ~= false
    end
    return result
end

local function copyPackBuyWhitelistForConfig()
    local result = {}
    for tier, enabled in pairs(State.packBuyWhitelist or {}) do
        result[tostring(tier)] = enabled == true
    end
    return result
end

local function syncPersistentConfig()
    PersistentConfig.autoLoan = State.autoLoan == true
    PersistentConfig.autoCollect = State.autoCollect == true
    PersistentConfig.autoPrestige = State.autoPrestige == true
    PersistentConfig.autoPlay = State.autoMatch == true
    PersistentConfig.autoMatch = State.autoMatch == true -- compatibility untuk config lama
    PersistentConfig.autoOpenPacks = State.autoOpenPacks == true
    PersistentConfig.packPickMode = normalizePackPickMode(State.packPickMode)
    PersistentConfig.skipPackAnimation = State.skipPackAnimation == true
    PersistentConfig.instantPacks = State.instantPacks == true
    PersistentConfig.autoBuyPacks = State.autoBuyPacks == true
    PersistentConfig.packBuyPrestigePriority = State.packBuyPrestigePriority == true
    PersistentConfig.packBuyWhitelist = copyPackBuyWhitelistForConfig()
    PersistentConfig.packLogRarityWhitelist = copyPackLogWhitelistForConfig()
    PersistentConfig.autoClaimPlayTimeRewards = State.autoClaimPlayTimeRewards == true
    PersistentConfig.autoClaimDailyReward = State.autoClaimDailyReward == true
    PersistentConfig.autoEquipBest = State.autoEquipBest == true
    PersistentConfig.autoJoinWorldCup = State.autoJoinWorldCup == true
    PersistentConfig.autoCollectWorldCupRewards = State.autoCollectWorldCupRewards == true
    PersistentConfig.fillWorldCupVisualBeforeJoin = State.fillWorldCupVisualBeforeJoin == true
    PersistentConfig.autoPickupSpawnedPacks = State.autoPickupSpawnedPacks == true
    PersistentConfig.lockPosition = State.lockPosition == true
    PersistentConfig.autoConveyor = State.autoConveyor == true
    PersistentConfig.antiAfk = State.antiAfk == true
    PersistentConfig.worldCupSquadMode = normalizeWorldCupSquadMode(State.worldCupSquadMode)
    PersistentConfig.autoSave = State.autoSave == true
    PersistentConfig.autoLoad = State.autoLoad == true
    PersistentConfig.windowKeybind = normalizeKeybindName(State.windowKeybind)
    PersistentConfig.duration = tonumber(State.selectedDuration) or 5
    PersistentConfig.rarityWhitelist = copyWhitelistForConfig()
end

local function buildConfigSnapshot()
    syncPersistentConfig()

    return {
        version = CONFIG_VERSION,
        placeId = game.PlaceId,
        gameName = GAME_NAME,
        savedAt = os.time(),
        autoSave = State.autoSave == true,
        autoLoad = State.autoLoad == true,
        windowKeybind = normalizeKeybindName(State.windowKeybind),
        autoLoan = State.autoLoan == true,
        autoCollect = State.autoCollect == true,
        autoPrestige = State.autoPrestige == true,
        autoPlay = State.autoMatch == true,
        autoMatch = State.autoMatch == true, -- compatibility untuk versi lama
        autoOpenPacks = State.autoOpenPacks == true,
        packPickMode = normalizePackPickMode(State.packPickMode),
        skipPackAnimation = State.skipPackAnimation == true,
        instantPacks = State.instantPacks == true,
        autoBuyPacks = State.autoBuyPacks == true,
        packBuyPrestigePriority = State.packBuyPrestigePriority == true,
        packBuyWhitelist = copyPackBuyWhitelistForConfig(),
        packLogRarityWhitelist = copyPackLogWhitelistForConfig(),
        autoClaimPlayTimeRewards = State.autoClaimPlayTimeRewards == true,
        autoClaimDailyReward = State.autoClaimDailyReward == true,
        autoEquipBest = State.autoEquipBest == true,
        autoJoinWorldCup = State.autoJoinWorldCup == true,
        autoCollectWorldCupRewards = State.autoCollectWorldCupRewards == true,
        fillWorldCupVisualBeforeJoin = State.fillWorldCupVisualBeforeJoin == true,
        autoPickupSpawnedPacks = State.autoPickupSpawnedPacks == true,
        lockPosition = State.lockPosition == true,
        autoConveyor = State.autoConveyor == true,
        antiAfk = State.antiAfk == true,
        worldCupSquadMode = normalizeWorldCupSquadMode(State.worldCupSquadMode),
        duration = tonumber(State.selectedDuration) or 5,
        rarityWhitelist = copyWhitelistForConfig(),
    }
end

local function ensureConfigFolders()
    if not State.configSupported then
        return false, "Executor tidak mendukung file config"
    end

    if type(makefolder) ~= "function" then
        return true
    end

    local folders = {CONFIG_ROOT, CONFIG_FOLDER}
    for _, folder in ipairs(folders) do
        local exists = false
        if type(isfolder) == "function" then
            local success, result = pcall(isfolder, folder)
            exists = success and result == true
        end

        if not exists then
            local success, errorMessage = pcall(makefolder, folder)
            if not success then
                -- Sebagian executor melempar error bila folder sudah ada.
                if type(isfolder) == "function" then
                    local checkSuccess, result = pcall(isfolder, folder)
                    if not (checkSuccess and result == true) then
                        return false, tostring(errorMessage)
                    end
                end
            end
        end
    end

    return true
end

local function saveConfigToDisk()
    syncPersistentConfig()

    if not State.configSupported then
        return false, "Executor tidak mendukung readfile/writefile"
    end

    local folderSuccess, folderError = ensureConfigFolders()
    if not folderSuccess then
        return false, folderError
    end

    local encodeSuccess, encoded = pcall(function()
        return HttpService:JSONEncode(buildConfigSnapshot())
    end)
    if not encodeSuccess then
        return false, tostring(encoded)
    end

    local writeSuccess, writeError = pcall(writefile, CONFIG_FILE, encoded)
    if not writeSuccess then
        return false, tostring(writeError)
    end

    State.configDirty = false
    State.configLastSavedAt = os.time()
    if updateConfigManagerUI then
        updateConfigManagerUI()
    end
    return true
end

local function requestConfigSave()
    syncPersistentConfig()
    State.configDirty = true

    if updateConfigManagerUI then
        updateConfigManagerUI()
    end

    if State.configLoading or not State.autoSave or not State.configSupported then
        return
    end

    State.configSaveToken += 1
    local token = State.configSaveToken

    task.delay(0.4, function()
        if not State.running
            or State.configLoading
            or not State.autoSave
            or token ~= State.configSaveToken
        then
            return
        end

        saveConfigToDisk()
    end)
end

local function setAutoSaveEnabled(enabled)
    State.autoSave = enabled == true
    PersistentConfig.autoSave = State.autoSave

    -- Simpan sekali saat toggle berubah agar pilihan Auto Save sendiri tetap persisten,
    -- termasuk saat pengguna baru saja mematikannya.
    if State.configSupported then
        saveConfigToDisk()
    else
        syncPersistentConfig()
    end

    if updateConfigManagerUI then
        updateConfigManagerUI()
    end
end

local function setAutoLoadEnabled(enabled)
    State.autoLoad = enabled == true
    PersistentConfig.autoLoad = State.autoLoad

    -- Metadata Auto Load harus disimpan langsung; jika tidak, startup berikutnya
    -- tidak dapat mengetahui bahwa Auto Load telah dinonaktifkan.
    if State.configSupported then
        saveConfigToDisk()
    else
        syncPersistentConfig()
    end

    if updateConfigManagerUI then
        updateConfigManagerUI()
    end
end

local function disconnectAll()
    for _, connection in ipairs(State.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(State.connections)
end

local function stopPreviousInstances()
    local oldGui = Environment.LoanOutGUI
    if type(oldGui) == "table" and type(oldGui.Stop) == "function" then
        pcall(oldGui.Stop)
    end

    local oldWindow = Environment.LoanOutGUIWindWindow
    if oldWindow and type(oldWindow.Destroy) == "function" then
        pcall(function()
            oldWindow:Destroy()
        end)
    end
    Environment.LoanOutGUIWindWindow = nil

    -- Hentikan logger versi lama agar tidak kembali mencetak daftar ke Output.
    local oldLogger = Environment.LoanOutLogger
    if type(oldLogger) == "table" and type(oldLogger.Stop) == "function" then
        pcall(oldLogger.Stop)
    end
end

stopPreviousInstances()

local function addConnection(connection)
    if connection then
        State.connections[#State.connections + 1] = connection
    end
    return connection
end

-- Register fix: helper functions are namespaced under Runtime to stay below Luau's 200-local limit.
local Runtime = {}

Runtime.virtualUser = nil
pcall(function()
    Runtime.virtualUser = game:GetService("VirtualUser")
end)

Runtime.virtualInputManager = nil
pcall(function()
    Runtime.virtualInputManager = game:GetService("VirtualInputManager")
end)

local function statusKindFromColor(color)
    if color == COLORS.success then
        return "SUCCESS"
    elseif color == COLORS.danger then
        return "ERROR"
    elseif color == COLORS.warning then
        return "WARNING"
    end
    return "INFO"
end

local function setStatus(text, color)
    State.lastStatusText = tostring(text or "")
    State.lastStatusKind = statusKindFromColor(color)

    if State.statusParagraph and type(State.statusParagraph.SetDesc) == "function" then
        State.statusParagraph:SetDesc(string.format("[%s] %s", State.lastStatusKind, State.lastStatusText))
    end
end

local function setElementLocked(element, locked)
    if not element then
        return
    end

    if element.__friendlyAction then
        element.FriendlyLocked = locked == true
        return
    end

    if locked and element.Locked ~= true and type(element.Lock) == "function" then
        element:Lock()
    elseif not locked and element.Locked == true and type(element.Unlock) == "function" then
        element:Unlock()
    end
end

local function setCollectButton(text, enabled)
    State.collectButtonEnabled = enabled == true

    local button = State.collectButton
    if not button then
        return
    end

    if type(button.SetTitle) == "function" then
        button:SetTitle(tostring(text or "Collect All"))
    end
    if type(button.SetDesc) == "function" then
        button:SetDesc(nil)
    end
    setElementLocked(button, not enabled)
end

local function setLoanButton(text, enabled)
    State.loanButtonEnabled = enabled == true

    local button = State.loanButton
    if not button then
        return
    end

    if type(button.SetTitle) == "function" then
        button:SetTitle(tostring(text or "Loan Top"))
    end
    if type(button.SetDesc) == "function" then
        button:SetDesc(nil)
    end
    setElementLocked(button, not enabled)
end

local formatCompactNumber

local function updateAutomationButtons(allowInstanceAccess)
    if allowInstanceAccess ~= true then
        State.uiRefreshRequested = true
        return
    end
    if State.autoLoanToggle and type(State.autoLoanToggle.Set) == "function" then
        if State.autoLoanToggle.Value ~= State.autoLoan then
            State.autoLoanToggle:Set(State.autoLoan, false)
        end
        State.autoLoanToggle:SetDesc(string.format(
            "Isi slot kosong otomatis • %s • %d/%d rarity aktif",
            Runtime.getDurationLabel and Runtime.getDurationLabel(State.selectedDuration) or tostring(State.selectedDuration),
            Runtime.getEnabledRarityCount and Runtime.getEnabledRarityCount() or 0,
            #State.rarityOptions
        ))
    end

    if State.autoCollectToggle and type(State.autoCollectToggle.Set) == "function" then
        if State.autoCollectToggle.Value ~= State.autoCollect then
            State.autoCollectToggle:Set(State.autoCollect, false)
        end
        State.autoCollectToggle:SetDesc("Collect seluruh loan yang selesai sebelum Auto Loan mengisi slot kembali.")
    end

    if State.autoMatchToggle and type(State.autoMatchToggle.Set) == "function" then
        if State.autoMatchToggle.Value ~= State.autoMatch then
            State.autoMatchToggle:Set(State.autoMatch, false)
        end

        local autoMatchDesc
        if State.worldCupAutoPlayPaused then
            autoMatchDesc = "PAUSED FOR CUP • menunggu squad International Cup disiapkan atau didaftarkan."
        elseif State.autoMatchTransaction then
            autoMatchDesc = "PAUSED TEMPORARILY • menjalankan squad automation lalu Auto Play dimulai kembali."
        elseif State.settingAutoMatch then
            autoMatchDesc = "STARTING • menjalankan AttemptSendOut dan mengaktifkan match berantai."
        elseif State.autoMatchPendingSync then
            autoMatchDesc = "PENDING • menunggu Networker/EventBus untuk memulai Auto Play."
        elseif State.autoMatch then
            autoMatchDesc = "ACTIVE • Auto Play berjalan di background dan lanjut ke match berikutnya."
        else
            autoMatchDesc = "Tekan toggle untuk memulai match pertama dan melanjutkan match berikutnya otomatis."
        end
        State.autoMatchToggle:SetDesc(autoMatchDesc)
    end

    if State.autoOpenPacksToggle and type(State.autoOpenPacksToggle.Set) == "function" then
        if State.autoOpenPacksToggle.Value ~= State.autoOpenPacks then
            State.autoOpenPacksToggle:Set(State.autoOpenPacks, false)
        end

        local packCount = Runtime.getOwnedPackCount and Runtime.getOwnedPackCount() or 0
        local pickMode = packPickModeLabel(State.packPickMode)
        local packsDesc
        if State.openingPacks then
            packsDesc = string.format(
                "OPENING • %d pack • Pick Pack: %s.",
                packCount,
                pickMode
            )
        elseif State.autoOpenPacks and packCount > 0 then
            packsDesc = string.format(
                "ACTIVE • %d pack tersedia • Pick Pack: %s.",
                packCount,
                pickMode
            )
        elseif State.autoOpenPacks then
            packsDesc = string.format("ACTIVE • menunggu pack • Pick Pack: %s.", pickMode)
        else
            packsDesc = string.format(
                "%d pack tersedia • Pick Pack: %s.",
                packCount,
                pickMode
            )
        end
        State.autoOpenPacksToggle:SetDesc(packsDesc)
    end


    if State.skipPackAnimationToggle and type(State.skipPackAnimationToggle.Set) == "function" then
        if State.skipPackAnimationToggle.Value ~= State.skipPackAnimation then
            State.skipPackAnimationToggle:Set(State.skipPackAnimation, false)
        end
        State.skipPackAnimationToggle:SetDesc(
            State.skipPackAnimation
                and "Direct open • animasi pack dilewati dan hasil masuk session log."
                or "Overlay game dipakai • Pick Pack dan log otomatis terbatas."
        )
    end

    if State.instantPacksToggle and type(State.instantPacksToggle.Set) == "function" then
        if State.instantPacksToggle.Value ~= State.instantPacks then
            State.instantPacksToggle:Set(State.instantPacks, false)
        end

        local hasPass = Runtime.getData and Runtime.getData("Passes.InstantOpen") == true
        local desc
        if State.instantPacks and hasPass then
            desc = "ACTIVE • pack biasa dibuka dengan batch; Pick Pack tetap dipilih satu per satu."
        elseif State.instantPacks then
            desc = "FALLBACK • Instant Open pass tidak terdeteksi; memakai direct open biasa."
        else
            desc = "Batch open pack biasa saat Instant Open pass tersedia."
        end
        State.instantPacksToggle:SetDesc(desc)
    end

    if State.autoBuyPacksToggle and type(State.autoBuyPacksToggle.Set) == "function" then
        if State.autoBuyPacksToggle.Value ~= State.autoBuyPacks then
            State.autoBuyPacksToggle:Set(State.autoBuyPacks, false)
        end

        local buyState = Runtime.getPackBuyState and Runtime.getPackBuyState() or nil
        local desc
        if State.buyingPacks then
            desc = "BUYING • pembelian pack sedang diproses."
        elseif not State.autoBuyPacks then
            desc = "Beli pack terpilih otomatis memakai coins yang dapat dibelanjakan."
        elseif buyState and buyState.blockedByPrestige then
            desc = "SAVING • coins disimpan untuk requirement Prestige."
        elseif buyState and buyState.nextTier then
            desc = string.format(
                "READY • %s • cost %s • budget %s.",
                tostring(buyState.nextLabel or buyState.nextTier),
                formatCompactNumber(buyState.nextCost or 0),
                formatCompactNumber(buyState.spendable or 0)
            )
        else
            desc = "ACTIVE • menunggu coins atau pack whitelist yang dapat dibeli."
        end
        State.autoBuyPacksToggle:SetDesc(desc)
    end

    if State.packBuyPrestigePriorityToggle
        and type(State.packBuyPrestigePriorityToggle.Set) == "function"
    then
        if State.packBuyPrestigePriorityToggle.Value ~= State.packBuyPrestigePriority then
            State.packBuyPrestigePriorityToggle:Set(State.packBuyPrestigePriority, false)
        end

        State.packBuyPrestigePriorityToggle:SetDesc(
            State.packBuyPrestigePriority
                and "Reserve requirement Coins Prestige; hanya surplus yang dipakai membeli pack."
                or "Auto Buy dapat memakai seluruh coins yang tersedia."
        )
    end

    if Runtime.updatePackShopUI then
        Runtime.updatePackShopUI(true)
    end

    if Runtime.updatePackUI then
        Runtime.updatePackUI(true)
    end

    if State.autoClaimPlayTimeRewardsToggle
        and type(State.autoClaimPlayTimeRewardsToggle.Set) == "function"
    then
        if State.autoClaimPlayTimeRewardsToggle.Value ~= State.autoClaimPlayTimeRewards then
            State.autoClaimPlayTimeRewardsToggle:Set(State.autoClaimPlayTimeRewards, false)
        end

        local playTimeState = Runtime.getPlayTimeRewardState
            and Runtime.getPlayTimeRewardState()
            or {readyCount = 0}
        local playTimeDesc

        if State.claimingPlayTimeRewards then
            playTimeDesc = string.format(
                "CLAIMING • %d reward siap.",
                tonumber(playTimeState.readyCount) or 0
            )
        elseif State.autoClaimPlayTimeRewards and (tonumber(playTimeState.readyCount) or 0) > 0 then
            playTimeDesc = string.format(
                "ACTIVE • %d reward siap diklaim.",
                tonumber(playTimeState.readyCount) or 0
            )
        elseif State.autoClaimPlayTimeRewards and playTimeState.nextIn ~= nil then
            playTimeDesc = string.format(
                "ACTIVE • reward berikutnya sekitar %d menit.",
                math.max(1, math.ceil((tonumber(playTimeState.nextIn) or 0) / 60))
            )
        elseif State.autoClaimPlayTimeRewards then
            playTimeDesc = "ACTIVE • semua reward tersedia sudah diklaim."
        else
            playTimeDesc = "Claim reward playtime yang sudah siap."
        end

        State.autoClaimPlayTimeRewardsToggle:SetDesc(playTimeDesc)
    end

    if State.autoClaimDailyRewardToggle
        and type(State.autoClaimDailyRewardToggle.Set) == "function"
    then
        if State.autoClaimDailyRewardToggle.Value ~= State.autoClaimDailyReward then
            State.autoClaimDailyRewardToggle:Set(State.autoClaimDailyReward, false)
        end

        local dailyState = Runtime.getDailyRewardState
            and Runtime.getDailyRewardState()
            or {available = false, claimDay = 1}
        local dailyDesc

        if State.claimingDailyReward then
            dailyDesc = string.format(
                "CLAIMING • Day %d.",
                tonumber(dailyState.claimDay) or 1
            )
        elseif State.autoClaimDailyReward and dailyState.ready then
            dailyDesc = string.format(
                "READY • Day %d akan diklaim otomatis.",
                tonumber(dailyState.claimDay) or 1
            )
        elseif State.autoClaimDailyReward and dailyState.available then
            dailyDesc = "WAITING • reward tersedia, menunggu onboarding selesai."
        elseif State.autoClaimDailyReward then
            dailyDesc = string.format(
                "ACTIVE • menunggu Daily Reward berikutnya • Day %d.",
                tonumber(dailyState.claimDay) or 1
            )
        else
            dailyDesc = string.format(
                "Claim Daily Reward otomatis saat tersedia • Day %d.",
                tonumber(dailyState.claimDay) or 1
            )
        end

        State.autoClaimDailyRewardToggle:SetDesc(dailyDesc)
    end

    if State.autoEquipBestToggle and type(State.autoEquipBestToggle.Set) == "function" then
        if State.autoEquipBestToggle.Value ~= State.autoEquipBest then
            State.autoEquipBestToggle:Set(State.autoEquipBest, false)
        end

        local equipDesc
        if State.equippingBest then
            equipDesc = string.format(
                "EQUIPPING • Auto Play dipause • pass %d/%d sampai lineup tidak berubah lagi.",
                math.max(State.autoEquipBestPasses, 1),
                AUTO_EQUIP_BEST_MAX_PASSES
            )
        elseif State.matchPlaybackActive then
            equipDesc = "WAITING • match sedang berlangsung; Equip Best diproses sebelum Auto Play berikutnya."
        elseif State.autoEquipBest and State.lastEquipBestResult == "already_best" then
            equipDesc = "ACTIVE • lineup sudah terbaik • tetap memantau kartu baru tanpa mematikan toggle."
        elseif State.autoEquipBest and State.autoMatch then
            equipDesc = "ACTIVE • kartu berubah → Auto Play dipause → Equip Best sampai stabil → Auto Play dilanjutkan."
        elseif State.autoEquipBest then
            equipDesc = "ACTIVE • Starting Eleven diperbarui sampai stabil saat koleksi kartu berubah."
        else
            equipDesc = "Susun Starting Eleven terbaik otomatis saat koleksi berubah."
        end
        State.autoEquipBestToggle:SetDesc(equipDesc)
    end

    if State.fillWorldCupVisualToggle and type(State.fillWorldCupVisualToggle.Set) == "function" then
        if State.fillWorldCupVisualToggle.Value ~= State.fillWorldCupVisualBeforeJoin then
            State.fillWorldCupVisualToggle:Set(State.fillWorldCupVisualBeforeJoin, false)
        end

        local visualDesc
        if State.fillingWorldCupVisual then
            visualDesc = "FILLING • membuka menu Cup dan memilih pemain satu per satu."
        elseif State.fillWorldCupVisualBeforeJoin then
            visualDesc = "ACTIVE • mencoba mengisi slot visual sebelum EnterWorldCup; fallback direct join bila UI berubah."
        else
            visualDesc = "Join tetap dikirim langsung ke server tanpa mengisi slot visual menu bawaan."
        end
        State.fillWorldCupVisualToggle:SetDesc(visualDesc)
    end

    if State.autoCollectWorldCupRewardsToggle and type(State.autoCollectWorldCupRewardsToggle.Set) == "function" then
        if State.autoCollectWorldCupRewardsToggle.Value ~= State.autoCollectWorldCupRewards then
            State.autoCollectWorldCupRewardsToggle:Set(State.autoCollectWorldCupRewards, false)
        end

        local status = State.worldCupStatus
        local rewardDesc
        if State.collectingWorldCupReward then
            rewardDesc = "COLLECTING • klaim reward International Cup sedang diproses."
        elseif State.autoCollectWorldCupRewards and status and status.pendingClaim and status.canCollect == true then
            rewardDesc = "READY • reward tersedia dan akan diklaim otomatis."
        elseif State.autoCollectWorldCupRewards and status and status.pendingClaim then
            rewardDesc = "WAITING • hasil Cup belum siap diklaim."
        elseif State.autoCollectWorldCupRewards then
            rewardDesc = "ACTIVE • memantau reward International Cup secara terpisah dari Auto Join."
        else
            rewardDesc = "Reward Cup hanya diklaim melalui tombol manual."
        end
        State.autoCollectWorldCupRewardsToggle:SetDesc(rewardDesc)
    end

    if State.autoPickupSpawnedPacksToggle and type(State.autoPickupSpawnedPacksToggle.Set) == "function" then
        if State.autoPickupSpawnedPacksToggle.Value ~= State.autoPickupSpawnedPacks then
            State.autoPickupSpawnedPacksToggle:Set(State.autoPickupSpawnedPacks, false)
        end

        local candidateCount = 0
        if type(State.spawnedPackCandidates) == "table" then
            candidateCount = #State.spawnedPackCandidates
        end
        local pickupDesc
        if State.pickingSpawnedPacks then
            pickupDesc = string.format("COLLECTING • menuju %d PackDrop di depan base.", candidateCount)
        elseif State.autoPickupSpawnedPacks and candidateCount > 0 then
            pickupDesc = string.format("ACTIVE • %d PackDrop terdeteksi di Workspace dekat base.", candidateCount)
        elseif State.autoPickupSpawnedPacks then
            pickupDesc = "ACTIVE • menunggu BasePart Workspace.PackDrop muncul di dekat base."
        else
            pickupDesc = "Deteksi BasePart bernama PackDrop di Workspace, lalu teleport untuk mengambilnya."
        end
        State.autoPickupSpawnedPacksToggle:SetDesc(pickupDesc)
    end

    if State.autoJoinWorldCupToggle and type(State.autoJoinWorldCupToggle.Set) == "function" then
        if State.autoJoinWorldCupToggle.Value ~= State.autoJoinWorldCup then
            State.autoJoinWorldCupToggle:Set(State.autoJoinWorldCup, false)
        end

        local status = State.worldCupStatus
        local phaseInfo = Runtime.getWorldCupPhase and Runtime.getWorldCupPhase() or nil
        local phase = phaseInfo and phaseInfo.phase or "unknown"
        local modeLabel = worldCupSquadModeLabel(State.worldCupSquadMode)
        local cupDesc

        if State.joiningWorldCup then
            cupDesc = "RUNNING • memproses reward atau entry International Cup."
        elseif State.autoJoinWorldCup and status and status.pendingClaim and status.canCollect == true then
            cupDesc = "ACTIVE • reward sebelumnya akan di-collect agar entry berikutnya terbuka."
        elseif State.autoJoinWorldCup and status and status.pendingClaim then
            cupDesc = "WAITING • hasil turnamen belum siap untuk diklaim."
        elseif State.autoJoinWorldCup and status and status.youEntered then
            cupDesc = "ENTERED • tim sudah terdaftar pada International Cup saat ini."
        elseif State.autoJoinWorldCup and phase == "entry" then
            cupDesc = "READY • entry sedang terbuka • squad: " .. modeLabel .. "."
        elseif State.autoJoinWorldCup then
            cupDesc = "ACTIVE • menunggu entry International Cup berikutnya • squad: " .. modeLabel .. "."
        else
            cupDesc = "Join otomatis saat entry terbuka • squad: " .. modeLabel .. "."
        end

        State.autoJoinWorldCupToggle:SetDesc(cupDesc)

        if State.worldCupParagraph then
            local title = "International Cup"
            if status and status.youEntered then
                title = "International Cup • ENTERED"
            elseif status and status.pendingClaim then
                title = "International Cup • REWARD"
            elseif phase == "entry" then
                title = "International Cup • ENTRY OPEN"
            elseif phase ~= "unknown" then
                title = "International Cup • " .. string.upper(tostring(phase))
            end

            if type(State.worldCupParagraph.SetTitle) == "function" then
                State.worldCupParagraph:SetTitle(title)
            end
            if type(State.worldCupParagraph.SetDesc) == "function" then
                State.worldCupParagraph:SetDesc(cupDesc)
            end
        end

        if Runtime.updateWorldCupPreview then
            Runtime.updateWorldCupPreview()
        end

        if State.worldCupCollectButton then
            local canCollect = status and status.pendingClaim and status.canCollect == true
                and not State.collectingWorldCupReward
                and not State.joiningWorldCup
            if type(State.worldCupCollectButton.SetTitle) == "function" then
                State.worldCupCollectButton:SetTitle(State.collectingWorldCupReward and "Collecting Reward..." or "Collect Cup Reward")
            end
            if type(State.worldCupCollectButton.SetDesc) == "function" then
                State.worldCupCollectButton:SetDesc(nil)
            end
            setElementLocked(State.worldCupCollectButton, not canCollect)
        end

        if State.worldCupVisualFillButton then
            local visualEnabled = phase == "entry" and not State.fillingWorldCupVisual and not State.joiningWorldCup
            if type(State.worldCupVisualFillButton.SetTitle) == "function" then
                State.worldCupVisualFillButton:SetTitle(State.fillingWorldCupVisual and "Filling Visual Squad..." or "Fill Visual Squad")
            end
            if type(State.worldCupVisualFillButton.SetDesc) == "function" then
                State.worldCupVisualFillButton:SetDesc(nil)
            end
            setElementLocked(State.worldCupVisualFillButton, not visualEnabled)
        end

        if State.spawnedPackPickupButton then
            local pickupEnabled = not State.pickingSpawnedPacks
            if type(State.spawnedPackPickupButton.SetTitle) == "function" then
                State.spawnedPackPickupButton:SetTitle(State.pickingSpawnedPacks and "Collecting PackDrop..." or "Collect PackDrop")
            end
            if type(State.spawnedPackPickupButton.SetDesc) == "function" then
                State.spawnedPackPickupButton:SetDesc(nil)
            end
            setElementLocked(State.spawnedPackPickupButton, not pickupEnabled)
        end

        if State.worldCupJoinButton then
            local buttonTitle = "Join International Cup"
            local buttonDesc = "Entry belum terbuka."
            local buttonEnabled = false

            if State.joiningWorldCup then
                buttonTitle = "Processing Cup..."
                buttonDesc = "Request International Cup sedang berjalan."
            elseif status and status.pendingClaim and status.canCollect == true then
                buttonTitle = "Collect Cup Reward"
                buttonDesc = "Klaim reward agar dapat mengikuti Cup berikutnya."
                buttonEnabled = true
            elseif status and status.youEntered then
                buttonTitle = "Already Entered"
                buttonDesc = "Squad sudah terdaftar pada International Cup saat ini."
            elseif phase == "entry" then
                buttonTitle = "Join International Cup"
                buttonDesc = "Gunakan " .. modeLabel .. " untuk mendaftar sekarang."
                buttonEnabled = true
            else
                buttonTitle = "Entry Closed"
                buttonDesc = "Menunggu fase entry International Cup berikutnya."
            end

            if type(State.worldCupJoinButton.SetTitle) == "function" then
                State.worldCupJoinButton:SetTitle(buttonTitle)
            end
            if type(State.worldCupJoinButton.SetDesc) == "function" then
                State.worldCupJoinButton:SetDesc(nil)
            end
            setElementLocked(State.worldCupJoinButton, not buttonEnabled)
        end
    end

    if State.lockPositionToggle and type(State.lockPositionToggle.Set) == "function" then
        if State.lockPositionToggle.Value ~= State.lockPosition then
            State.lockPositionToggle:Set(State.lockPosition, false)
        end

        local lockDesc
        if State.lockPosition then
            lockDesc = "ACTIVE • collision karakter player lain dimatikan secara lokal; movement dan conveyor tetap normal."
        else
            lockDesc = "Cegah player lain menabrak atau mendorong karakter tanpa meng-anchor HumanoidRootPart."
        end
        State.lockPositionToggle:SetDesc(lockDesc)
    end

    if State.autoConveyorToggle and type(State.autoConveyorToggle.Set) == "function" then
        if State.autoConveyorToggle.Value ~= State.autoConveyor then
            State.autoConveyorToggle:Set(State.autoConveyor, false)
        end

        local conveyor = Runtime.getConveyorTarget and Runtime.getConveyorTarget() or nil
        local conveyorDesc
        if State.autoConveyor and conveyor then
            conveyorDesc = "ACTIVE • tetap berjalan normal di conveyor; teleport ulang hanya jika keluar dari salah satu Animed Convoyor."
        elseif State.autoConveyor then
            conveyorDesc = "WAITING • part Animed Convoyor belum ditemukan; akan dicoba lagi otomatis."
        else
            conveyorDesc = conveyor
                and "Teleport ke part Animed Convoyor dan kembali otomatis jika keluar."
                or 'Workspace.World.Conveyor[" Animed Convoyor"] belum ditemukan.'
        end
        State.autoConveyorToggle:SetDesc(conveyorDesc)
    end

    if State.antiAfkToggle and type(State.antiAfkToggle.Set) == "function" then
        if State.antiAfkToggle.Value ~= State.antiAfk then
            State.antiAfkToggle:Set(State.antiAfk, false)
        end

        local antiAfkDesc
        if State.antiAfk then
            antiAfkDesc = string.format(
                "ACTIVE • pulse tiap %ds • method: %s",
                tonumber(State.antiAfkInterval) or 45,
                tostring(State.antiAfkMethod or "waiting")
            )

            if State.antiAfkCount > 0 then
                antiAfkDesc = antiAfkDesc .. string.format(" • pulse %d", State.antiAfkCount)
            end

            if State.lastAntiAfkError then
                antiAfkDesc = antiAfkDesc .. " • fallback aktif"
            end
        else
            antiAfkDesc = "Anti AFK mati • idle kick Roblox tidak dicegah."
        end
        State.antiAfkToggle:SetDesc(antiAfkDesc)
    end

    if State.movementParagraph then
        local plot = Runtime.findOwnedPlot and Runtime.findOwnedPlot(false) or nil
        local spawnPart = Runtime.getOwnedPlotSpawn and Runtime.getOwnedPlotSpawn(false) or nil
        local conveyor = Runtime.getConveyorTarget and Runtime.getConveyorTarget() or nil
        local desc = string.format(
            "Plot: %s • Spawn: %s • Animed Convoyor: %s • Anti Player Collision: %s • Auto Conveyor: %s",
            plot and plot.Name or "not found",
            spawnPart and "ready" or "not found",
            conveyor and "ready" or "not found",
            State.lockPosition and "ON" or "OFF",
            State.autoConveyor and "ON" or "OFF"
        )
        if type(State.movementParagraph.SetTitle) == "function" then
            State.movementParagraph:SetTitle("Movement & Base")
        end
        if type(State.movementParagraph.SetDesc) == "function" then
            State.movementParagraph:SetDesc(desc)
        end
    end

    if State.backToBaseButton then
        local spawnPart = Runtime.getOwnedPlotSpawn and Runtime.getOwnedPlotSpawn(false) or nil
        if type(State.backToBaseButton.SetDesc) == "function" then
            State.backToBaseButton:SetDesc(nil)
        end
        setElementLocked(State.backToBaseButton, spawnPart == nil)
    end

    if State.teleportConveyorButton then
        local conveyor = Runtime.getConveyorTarget and Runtime.getConveyorTarget() or nil
        if type(State.teleportConveyorButton.SetDesc) == "function" then
            State.teleportConveyorButton:SetDesc(nil)
        end
        setElementLocked(State.teleportConveyorButton, conveyor == nil)
    end

    if State.autoPrestigeToggle and type(State.autoPrestigeToggle.Set) == "function" then
        if State.autoPrestigeToggle.Value ~= State.autoPrestige then
            State.autoPrestigeToggle:Set(State.autoPrestige, false)
        end

        local prestigeDesc = "Prestige otomatis saat semua requirement terpenuhi. Division dan Coins akan di-reset."
        if State.prestiging then
            prestigeDesc = "RUNNING • request DoPrestige sedang diproses."
        elseif State.prestigeInfo and State.prestigeInfo.eligible then
            prestigeDesc = "READY • seluruh requirement terpenuhi dan prestige siap dijalankan."
        end
        State.autoPrestigeToggle:SetDesc(prestigeDesc)
    end
end

local function setAutoLoanEnabled(enabled, announce)
    State.autoLoan = enabled == true
    PersistentConfig.autoLoan = State.autoLoan
    State.nextAutoLoanAt = 0
    State.cachedTopCard = nil
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoLoan
                and string.format(
                    "Auto Loan aktif • whitelist rarity • %d menit.",
                    State.selectedDuration
                )
                or "Auto Loan dinonaktifkan.",
            State.autoLoan and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoCollectEnabled(enabled, announce)
    State.autoCollect = enabled == true
    PersistentConfig.autoCollect = State.autoCollect
    State.nextAutoCollectAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoCollect
                and "Auto Collect aktif • loan selesai akan diambil otomatis."
                or "Auto Collect dinonaktifkan.",
            State.autoCollect and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoOpenPacksEnabled(enabled, announce)
    State.autoOpenPacks = enabled == true
    PersistentConfig.autoOpenPacks = State.autoOpenPacks
    State.nextAutoOpenPackAt = 0
    State.lastObservedPackCount = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoOpenPacks
                and ("Auto Open Packs aktif • Pick Pack: " .. packPickModeLabel(State.packPickMode) .. ".")
                or "Auto Open Packs dinonaktifkan.",
            State.autoOpenPacks and COLORS.success or COLORS.muted
        )
    end
end

local function setPackPickMode(mode, announce)
    State.packPickMode = normalizePackPickMode(mode)
    PersistentConfig.packPickMode = State.packPickMode
    State.nextAutoOpenPackAt = 0
    State.packUiDirty = true
    State.uiRefreshRequested = true
    requestConfigSave()

    if announce ~= false then
        setStatus(
            "Pick Pack selection: " .. packPickModeLabel(State.packPickMode) .. ".",
            COLORS.success
        )
    end

    return State.packPickMode
end

Runtime.setSkipPackAnimationEnabled = function(enabled, announce)
    State.skipPackAnimation = enabled == true
    PersistentConfig.skipPackAnimation = State.skipPackAnimation
    State.nextAutoOpenPackAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.skipPackAnimation
                and "Skip Pack Animation aktif."
                or "Skip Pack Animation dinonaktifkan.",
            State.skipPackAnimation and COLORS.success or COLORS.muted
        )
    end

    return State.skipPackAnimation
end

Runtime.setInstantPacksEnabled = function(enabled, announce)
    State.instantPacks = enabled == true
    PersistentConfig.instantPacks = State.instantPacks
    State.nextAutoOpenPackAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        local hasPass = Runtime.getData and Runtime.getData("Passes.InstantOpen") == true
        local message
        if State.instantPacks and hasPass then
            message = "Instant Packs aktif."
        elseif State.instantPacks then
            message = "Instant Packs aktif, tetapi pass belum terdeteksi; fallback direct open."
        else
            message = "Instant Packs dinonaktifkan."
        end
        setStatus(message, State.instantPacks and COLORS.success or COLORS.muted)
    end

    return State.instantPacks
end

Runtime.setAutoBuyPacksEnabled = function(enabled, announce)
    State.autoBuyPacks = enabled == true
    PersistentConfig.autoBuyPacks = State.autoBuyPacks
    State.nextAutoBuyPackAt = 0
    State.lastPackBuyError = nil
    State.packUiDirty = true
    State.uiRefreshRequested = true
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoBuyPacks
                and "Auto Buy Packs aktif."
                or "Auto Buy Packs dinonaktifkan.",
            State.autoBuyPacks and COLORS.success or COLORS.muted
        )
    end

    return State.autoBuyPacks
end

Runtime.setPackBuyPrestigePriorityEnabled = function(enabled, announce)
    State.packBuyPrestigePriority = enabled == true
    PersistentConfig.packBuyPrestigePriority = State.packBuyPrestigePriority
    State.nextAutoBuyPackAt = 0
    State.nextPackBuyPrestigeRefreshAt = 0
    State.packUiDirty = true
    State.uiRefreshRequested = true
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.packBuyPrestigePriority
                and "Prestige Priority aktif • requirement Coins disimpan."
                or "Prestige Priority dinonaktifkan • seluruh coins dapat digunakan.",
            State.packBuyPrestigePriority and COLORS.success or COLORS.warning
        )
    end

    return State.packBuyPrestigePriority
end

local function setAutoClaimPlayTimeRewardsEnabled(enabled, announce)
    State.autoClaimPlayTimeRewards = enabled == true
    PersistentConfig.autoClaimPlayTimeRewards = State.autoClaimPlayTimeRewards
    State.nextPlayTimeClaimAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoClaimPlayTimeRewards
                and "Auto Claim Playtime Rewards aktif."
                or "Auto Claim Playtime Rewards dinonaktifkan.",
            State.autoClaimPlayTimeRewards and COLORS.success or COLORS.muted
        )
    end
end

Runtime.setAutoClaimDailyRewardEnabled = function(enabled, announce)
    State.autoClaimDailyReward = enabled == true
    PersistentConfig.autoClaimDailyReward = State.autoClaimDailyReward
    State.nextDailyRewardClaimAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoClaimDailyReward
                and "Auto Claim Daily Reward aktif."
                or "Auto Claim Daily Reward dinonaktifkan.",
            State.autoClaimDailyReward and COLORS.success or COLORS.muted
        )
    end

    return State.autoClaimDailyReward
end

local function setAutoEquipBestEnabled(enabled, announce)
    State.autoEquipBest = enabled == true
    PersistentConfig.autoEquipBest = State.autoEquipBest
    State.nextAutoEquipBestAt = 0
    State.lastEquipBestSignature = nil
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoEquipBest
                and "Auto Equip Best aktif • Auto Play dipause sementara saat lineup perlu diperbarui."
                or "Auto Equip Best dinonaktifkan.",
            State.autoEquipBest and COLORS.success or COLORS.muted
        )
    end
end

local function setWorldCupSquadMode(value, announce)
    State.worldCupSquadMode = normalizeWorldCupSquadMode(value)
    PersistentConfig.worldCupSquadMode = State.worldCupSquadMode
    State.nextWorldCupCheckAt = 0
    State.nextWorldCupRewardCheckAt = 0
    State.nextSpawnedPackScanAt = 0
    State.cachedTopCard = nil
    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            "International Cup squad: " .. worldCupSquadModeLabel(State.worldCupSquadMode),
            COLORS.success
        )
    end

    return State.worldCupSquadMode
end

local function setAutoJoinWorldCupEnabled(enabled, announce)
    State.autoJoinWorldCup = enabled == true
    PersistentConfig.autoJoinWorldCup = State.autoJoinWorldCup
    State.nextWorldCupCheckAt = 0
    State.cachedTopCard = nil
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoJoinWorldCup
                and ("Auto Join International Cup aktif • squad: " .. worldCupSquadModeLabel(State.worldCupSquadMode) .. ".")
                or "Auto Join International Cup dinonaktifkan.",
            State.autoJoinWorldCup and COLORS.success or COLORS.muted
        )
    end
end

local function setFillWorldCupVisualEnabled(enabled, announce)
    State.fillWorldCupVisualBeforeJoin = enabled == true
    PersistentConfig.fillWorldCupVisualBeforeJoin = State.fillWorldCupVisualBeforeJoin
    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.fillWorldCupVisualBeforeJoin
                and "Visual Fill Cup aktif • slot menu bawaan akan dicoba diisi sebelum join."
                or "Visual Fill Cup dinonaktifkan • join memakai request langsung.",
            State.fillWorldCupVisualBeforeJoin and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoCollectWorldCupRewardsEnabled(enabled, announce)
    State.autoCollectWorldCupRewards = enabled == true
    PersistentConfig.autoCollectWorldCupRewards = State.autoCollectWorldCupRewards
    State.nextWorldCupRewardCheckAt = 0
    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.autoCollectWorldCupRewards
                and "Auto Collect Cup Rewards aktif."
                or "Auto Collect Cup Rewards dinonaktifkan.",
            State.autoCollectWorldCupRewards and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoPickupSpawnedPacksEnabled(enabled, announce)
    State.autoPickupSpawnedPacks = enabled == true
    PersistentConfig.autoPickupSpawnedPacks = State.autoPickupSpawnedPacks
    State.nextSpawnedPackScanAt = 0
    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.autoPickupSpawnedPacks
                and "Auto Collect PackDrop aktif • menunggu Workspace.PackDrop di dekat base."
                or "Auto Collect PackDrop dinonaktifkan.",
            State.autoPickupSpawnedPacks and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoPrestigeEnabled(enabled, announce)
    State.autoPrestige = enabled == true
    PersistentConfig.autoPrestige = State.autoPrestige
    State.nextPrestigeCheckAt = 0
    -- Pertahankan hasil Check Prestige terakhir saat toggle berubah.
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoPrestige
                and "Auto Prestige aktif • Division & Coins akan di-reset otomatis saat eligible."
                or "Auto Prestige dinonaktifkan.",
            State.autoPrestige and COLORS.success or COLORS.muted
        )
    end
end

local function formatRemaining(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60

    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
    end

    return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function formatNumber(value)
    local textValue = tostring(math.floor(tonumber(value) or 0))
    local sign, digits = textValue:match("^(%-?)(%d+)$")
    if not digits then
        return textValue
    end

    local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
    reversed = reversed:reverse():gsub("^,", "")
    return (sign or "") .. reversed
end

formatCompactNumber = function(value)
    value = tonumber(value) or 0
    local absolute = math.abs(value)

    if absolute >= 1e9 then
        return string.format("%.2fB", value / 1e9):gsub("%.?0+B$", "B")
    elseif absolute >= 1e6 then
        return string.format("%.2fM", value / 1e6):gsub("%.?0+M$", "M")
    elseif absolute >= 1e3 then
        return string.format("%.2fK", value / 1e3):gsub("%.?0+K$", "K")
    end

    return formatNumber(value)
end

Runtime.getDurationLabel = function(minutes)
    minutes = tonumber(minutes) or 0

    local loanConfig = State.loanConfig
    local durations = loanConfig and loanConfig.Durations
    if type(durations) == "table" then
        for _, duration in ipairs(durations) do
            if type(duration) == "table" and tonumber(duration.mins) == minutes then
                return tostring(duration.label or (minutes .. " Min"))
            end
        end
    end

    return string.format("%d Min", minutes)
end

local function isRarityWhitelisted(rarity)
    return State.rarityWhitelist[tostring(rarity)] ~= false
end

Runtime.getEnabledRarityCount = function()
    local count = 0
    for _, rarity in ipairs(State.rarityOptions) do
        if isRarityWhitelisted(rarity) then
            count += 1
        end
    end
    return count
end

local function getTrackedAutoLoanCount()
    local count = 0
    for _ in pairs(State.autoLoanedIds) do
        count += 1
    end
    return count
end

local function initializeConfigurationOptions()
    local durationSet = {}
    local durations = {}
    local loanDurations = State.loanConfig and State.loanConfig.Durations

    if type(loanDurations) == "table" then
        for _, duration in ipairs(loanDurations) do
            local minutes = type(duration) == "table" and tonumber(duration.mins) or nil
            if minutes and minutes > 0 and not durationSet[minutes] then
                durationSet[minutes] = true
                durations[#durations + 1] = minutes
            end
        end
    end

    if #durations == 0 then
        for _, minutes in ipairs(FALLBACK_DURATIONS) do
            durationSet[minutes] = true
            durations[#durations + 1] = minutes
        end
    end

    table.sort(durations)
    State.durationOptions = durations

    if not durationSet[State.selectedDuration] then
        State.selectedDuration = durations[1] or 5
    end
    PersistentConfig.duration = State.selectedDuration

    local raritySet = {}
    local rarityOptions = {}

    for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
        if not raritySet[rarity] then
            raritySet[rarity] = true
            rarityOptions[#rarityOptions + 1] = rarity
        end
    end

    local variantRarities = State.variantConfig and State.variantConfig.Rarities
    if type(variantRarities) == "table" then
        for index = #variantRarities, 1, -1 do
            local rarityData = variantRarities[index]
            local rarity = type(rarityData) == "table" and rarityData.id or nil
            if rarity and not raritySet[rarity] then
                raritySet[rarity] = true
                table.insert(rarityOptions, 1, rarity)
            end
        end
    end

    table.sort(rarityOptions, function(a, b)
        local aRank = RARITY_PRIORITY[a] or 0
        local bRank = RARITY_PRIORITY[b] or 0
        if aRank ~= bRank then
            return aRank > bRank
        end
        return tostring(a) < tostring(b)
    end)

    State.rarityOptions = rarityOptions
end

local function safelyGetModule(core, moduleName)
    if core == nil or type(core.GetModule) ~= "function" then
        return nil
    end

    local success, result = pcall(core.GetModule, core, moduleName)
    if success then
        return result
    end

    return nil
end

local function isDataService(candidate)
    return candidate ~= nil and type(candidate.Get) == "function"
end

local function isNetworker(candidate)
    return candidate ~= nil and type(candidate.Call) == "function"
end

local function findFrameworkFromGC()
    if type(getgc) ~= "function" then
        return nil, nil, nil
    end

    local success, objects = pcall(getgc, true)
    if not success or type(objects) ~= "table" then
        return nil, nil, nil
    end

    local foundDataService = nil
    local foundNetworker = nil
    local foundEventBus = nil

    for _, object in ipairs(objects) do
        if type(object) == "table" then
            local core = rawget(object, "_core")

            if core ~= nil then
                local dataService = safelyGetModule(core, "DataService")
                local networker = rawget(core, "Networker")
                local eventBus = rawget(object, "bus")
                    or rawget(object, "_bus")
                    or rawget(core, "EventBus")
                    or safelyGetModule(core, "EventBus")

                if not foundDataService and isDataService(dataService) then
                    foundDataService = dataService
                end

                if not foundNetworker and isNetworker(networker) then
                    foundNetworker = networker
                end

                if not foundEventBus and eventBus ~= nil then
                    foundEventBus = eventBus
                end

                if foundDataService and foundNetworker and foundEventBus then
                    return foundDataService, foundNetworker, foundEventBus
                end
            end
        end
    end

    return foundDataService, foundNetworker, foundEventBus
end

local function findDataServiceFromLoadedModules()
    if type(getloadedmodules) ~= "function" then
        return nil
    end

    local success, modules = pcall(getloadedmodules)
    if not success or type(modules) ~= "table" then
        return nil
    end

    for _, moduleScript in ipairs(modules) do
        if moduleScript:IsA("ModuleScript") and moduleScript.Name == "DataService" then
            local requireSuccess, result = pcall(require, moduleScript)
            if requireSuccess and isDataService(result) then
                return result
            end
        end
    end

    return nil
end

local function discoverFramework()
    for attempt = 1, DISCOVERY_ATTEMPTS do
        if not State.running then
            return false
        end

        local dataService, networker, eventBus = findFrameworkFromGC()
        dataService = dataService or findDataServiceFromLoadedModules()

        if isDataService(dataService) then
            State.dataService = dataService
            State.networker = networker
            State.eventBus = eventBus

            if isNetworker(networker) then
                setStatus("Connected • Collect tersedia", COLORS.success)
            else
                setStatus("Data terhubung • Networker belum ditemukan", COLORS.warning)
            end

            return true
        end

        setStatus(
            string.format("Mencari data game... (%d/%d)", attempt, DISCOVERY_ATTEMPTS),
            COLORS.warning
        )
        task.wait(DISCOVERY_DELAY)
    end

    setStatus("DataService tidak ditemukan. Jalankan setelah game selesai loading.", COLORS.danger)
    return false
end

local function loadGameModules()
    local modulesFolder = ReplicatedStorage:FindFirstChild("Shared")
    modulesFolder = modulesFolder and modulesFolder:FindFirstChild("Modules")
    modulesFolder = modulesFolder and modulesFolder:FindFirstChild("Game")

    if not modulesFolder then
        return
    end

    local databaseModule = modulesFolder:FindFirstChild("PlayerCardDatabase")
    local variantModule = modulesFolder:FindFirstChild("VariantConfig")
    local loanConfigModule = modulesFolder:FindFirstChild("LoanConfig")
    local skillsConfigModule = modulesFolder:FindFirstChild("SkillsConfig")
    local worldCupConfigModule = modulesFolder:FindFirstChild("WorldCupConfig")
    local playTimeConfigModule = modulesFolder:FindFirstChild("PlayTimeConfig")
    local packConfigModule = modulesFolder:FindFirstChild("PackConfig")
    local formationLayoutModule = modulesFolder:FindFirstChild("FormationLayout")
    local cardResolveModule = modulesFolder:FindFirstChild("CardResolve")

    if databaseModule then
        local success, result = pcall(require, databaseModule)
        if success then
            State.playerCardDatabase = result
        end
    end

    if variantModule then
        local success, result = pcall(require, variantModule)
        if success then
            State.variantConfig = result
        end
    end

    if loanConfigModule then
        local success, result = pcall(require, loanConfigModule)
        if success then
            State.loanConfig = result
        end
    end

    if skillsConfigModule then
        local success, result = pcall(require, skillsConfigModule)
        if success then
            State.skillsConfig = result
        end
    end

    if worldCupConfigModule then
        local success, result = pcall(require, worldCupConfigModule)
        if success then
            State.worldCupConfig = result
        end
    end

    if playTimeConfigModule then
        local success, result = pcall(require, playTimeConfigModule)
        if success then
            State.playTimeConfig = result
        end
    end

    if packConfigModule then
        local success, result = pcall(require, packConfigModule)
        if success then
            State.packConfig = result
        end
    end

    if formationLayoutModule then
        local success, result = pcall(require, formationLayoutModule)
        if success then
            State.formationLayout = result
        end
    end

    if cardResolveModule then
        local success, result = pcall(require, cardResolveModule)
        if success then
            State.cardResolve = result
        end
    end

    if State.packConfig and Runtime.refreshPackShopTiers then
        Runtime.refreshPackShopTiers()
    end
end

Runtime.getData = function(path)
    local dataService = State.dataService
    if not isDataService(dataService) then
        return nil
    end

    local success, directValue = pcall(dataService.Get, dataService, path)
    if success and directValue ~= nil then
        return directValue
    end

    local rootName, nestedPath = string.match(path, "^([^%.]+)%.(.+)$")
    if rootName == nil then
        return nil
    end

    local rootSuccess, value = pcall(dataService.Get, dataService, rootName)
    if not rootSuccess then
        return nil
    end

    for key in string.gmatch(nestedPath, "[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[key]
    end

    return value
end


Runtime.getOwnedPackCount = function()
    local ownedPacks = Runtime.getData("Packs.Owned")
    if type(ownedPacks) ~= "table" then
        return 0
    end

    local total = 0
    for _, amount in pairs(ownedPacks) do
        total += math.max(0, tonumber(amount) or 0)
    end

    return total
end

Runtime.getPlayTimeRewardState = function()
    local playTime = Runtime.getData("PlayTime")
    local tiers = State.playTimeConfig and State.playTimeConfig.Tiers
    local seconds = type(playTime) == "table" and (tonumber(playTime.seconds) or 0) or 0
    local claimed = type(playTime) == "table" and playTime.claimed or nil

    if type(claimed) ~= "table" then
        claimed = {}
    end

    local result = {
        seconds = seconds,
        totalTiers = type(tiers) == "table" and #tiers or 0,
        claimedCount = 0,
        readyCount = 0,
        readyTiers = {},
        nextTier = nil,
        nextIn = nil,
        configAvailable = type(tiers) == "table",
    }

    if type(tiers) ~= "table" then
        return result
    end

    local nextThreshold
    for tierIndex, tier in ipairs(tiers) do
        local isClaimed = claimed[tostring(tierIndex)] == true or claimed[tierIndex] == true
        local threshold = math.max(0, tonumber(type(tier) == "table" and tier.min) or 0) * 60

        if isClaimed then
            result.claimedCount += 1
        elseif seconds >= threshold then
            result.readyCount += 1
            result.readyTiers[#result.readyTiers + 1] = tierIndex
        elseif nextThreshold == nil or threshold < nextThreshold then
            nextThreshold = threshold
            result.nextTier = tierIndex
        end
    end

    if nextThreshold ~= nil then
        result.nextIn = math.max(0, nextThreshold - seconds)
    end

    return result
end

Runtime.getDailyRewardState = function()
    local available = Runtime.getData("DailyRewards.Available") == true
    local claimDay = math.max(
        1,
        math.floor(tonumber(Runtime.getData("DailyRewards.ClaimDay")) or 1)
    )
    local onboardingComplete = Runtime.getData("Onboarding.Complete") == true
    local guideStage = Runtime.getData("Onboarding.GuideStage")
    local guideReady = guideStage == nil or guideStage == "done"

    return {
        available = available,
        ready = available and onboardingComplete and guideReady,
        claimDay = claimDay,
        onboardingComplete = onboardingComplete,
        guideStage = guideStage,
    }
end


local function getRarity(baseCard, rating)
    local variantConfig = State.variantConfig
    local database = State.playerCardDatabase

    if baseCard and variantConfig and type(variantConfig.IsVariant) == "function" then
        local success, isVariant = pcall(variantConfig.IsVariant, baseCard.rarity)
        if success and isVariant then
            return baseCard.rarity
        end
    end

    if database and type(database.GetRarityFromRating) == "function" then
        local success, rarity = pcall(database.GetRarityFromRating, rating)
        if success and rarity then
            return rarity
        end
    end

    return baseCard and baseCard.rarity or "Unknown"
end

local function resolveCard(instanceId, loanData)
    loanData = type(loanData) == "table" and loanData or {}

    local fallback = {
        instanceId = instanceId,
        baseId = loanData.baseId,
        name = loanData.name or "Unknown Player",
        rating = tonumber(loanData.rating) or 0,
        position = loanData.position or "-",
        rarity = loanData.rarity or "Unknown",
        club = loanData.club or "-",
    }

    local database = State.playerCardDatabase
    if not database or type(database.GetById) ~= "function" then
        return fallback
    end

    local ownedCards = Runtime.getData("Squad.Owned") or {}
    local ownedCard = ownedCards[instanceId]
    if type(ownedCard) ~= "table" then
        return fallback
    end

    local success, baseCard = pcall(database.GetById, ownedCard.baseId)
    if not success or not baseCard then
        return fallback
    end

    local upgrade = tonumber(ownedCard.upgrade) or 0
    local rating = (tonumber(baseCard.rating) or 0) + upgrade

    return {
        instanceId = instanceId,
        baseId = baseCard.id or ownedCard.baseId,
        name = baseCard.name or fallback.name,
        rating = rating,
        position = baseCard.position or fallback.position,
        rarity = getRarity(baseCard, rating),
        club = baseCard.club or fallback.club,
    }
end

local function rarityRank(rarity)
    local knownRank = RARITY_PRIORITY[tostring(rarity)]
    if knownRank then
        return knownRank
    end

    local variantConfig = State.variantConfig
    local rarities = variantConfig and variantConfig.Rarities
    if type(rarities) == "table" then
        for index, rarityData in ipairs(rarities) do
            if type(rarityData) == "table" and rarityData.id == rarity then
                return 100 + index
            end
        end
    end

    return 0
end

local function isBetterLoanCandidate(candidate, current)
    if current == nil then
        return true
    end

    local candidateRank = rarityRank(candidate.rarity)
    local currentRank = rarityRank(current.rarity)

    if candidateRank ~= currentRank then
        return candidateRank > currentRank
    end

    if candidate.rating ~= current.rating then
        return candidate.rating > current.rating
    end

    return tostring(candidate.name) < tostring(current.name)
end

local function getStartingElevenSet()
    local result = {}
    local startingEleven = Runtime.getData("Squad.StartingEleven")

    if type(startingEleven) == "table" then
        for _, instanceId in pairs(startingEleven) do
            if type(instanceId) == "string" then
                result[instanceId] = true
            end
        end
    end

    return result
end

local function addActiveIds(target, entries)
    if type(entries) ~= "table" then
        return
    end

    for _, entry in pairs(entries) do
        if type(entry) == "table" and entry.instanceId ~= nil then
            target[tostring(entry.instanceId)] = true
        end
    end
end

local function getUnavailableCardIds()
    local unavailable = getStartingElevenSet()

    addActiveIds(unavailable, Runtime.getData("Loans.active"))
    addActiveIds(unavailable, Runtime.getData("Training.active"))

    local promotion = Runtime.getData("Promotion")
    if type(promotion) == "table" and promotion.active then
        addActiveIds(unavailable, promotion.players)
    end

    return unavailable
end

Runtime.getSquadEquipSignature = function()
    local parts = {"formation=" .. tostring(Runtime.getData("Squad.Formation") or "")}
    local ownedCards = Runtime.getData("Squad.Owned")

    if type(ownedCards) == "table" then
        for instanceId, cardData in pairs(ownedCards) do
            if type(cardData) == "table" then
                parts[#parts + 1] = string.format(
                    "card:%s:%s:%s",
                    tostring(instanceId),
                    tostring(cardData.baseId or ""),
                    tostring(cardData.upgrade or 0)
                )
            end
        end
    end

    local function appendActive(prefix, entries)
        if type(entries) ~= "table" then
            return
        end
        for _, entry in pairs(entries) do
            if type(entry) == "table" and entry.instanceId ~= nil then
                parts[#parts + 1] = prefix .. ":" .. tostring(entry.instanceId)
            end
        end
    end

    appendActive("loan", Runtime.getData("Loans.active"))
    appendActive("training", Runtime.getData("Training.active"))

    local startingEleven = Runtime.getData("Squad.StartingEleven")
    if type(startingEleven) == "table" then
        for slot, instanceId in pairs(startingEleven) do
            if instanceId ~= nil and instanceId ~= false then
                parts[#parts + 1] = string.format(
                    "xi:%s:%s",
                    tostring(slot),
                    tostring(instanceId)
                )
            end
        end
    end

    local promotion = Runtime.getData("Promotion")
    if type(promotion) == "table" and promotion.active then
        appendActive("promotion", promotion.players)
    end

    table.sort(parts)
    return table.concat(parts, "|")
end

local function getStartingElevenSignature()
    local startingEleven = Runtime.getData("Squad.StartingEleven")
    if type(startingEleven) ~= "table" then
        return ""
    end

    local parts = {}
    for slot, instanceId in pairs(startingEleven) do
        if instanceId ~= nil and instanceId ~= false then
            parts[#parts + 1] = tostring(slot) .. ":" .. tostring(instanceId)
        end
    end

    table.sort(parts)
    return table.concat(parts, "|")
end

local function waitForStartingElevenChange(previousSignature, timeoutSeconds)
    local deadline = os.clock() + math.max(0, tonumber(timeoutSeconds) or 0)
    local currentSignature = getStartingElevenSignature()

    while State.running and os.clock() < deadline do
        currentSignature = getStartingElevenSignature()
        if currentSignature ~= previousSignature then
            return currentSignature, true
        end
        task.wait(0.1)
    end

    currentSignature = getStartingElevenSignature()
    return currentSignature, currentSignature ~= previousSignature
end

local function findTopAvailableCard()
    local ownedCards = Runtime.getData("Squad.Owned")
    if type(ownedCards) ~= "table" then
        return nil
    end

    local unavailable = getUnavailableCardIds()

    -- Saat Auto Join Cup aktif, jangan loan pemain yang sedang dicadangkan
    -- untuk Last Team atau Best Rarity/OVR sebelum entry selesai.
    if State.autoJoinWorldCup and Runtime.getWorldCupReservedIds then
        local reserved = Runtime.getWorldCupReservedIds()
        for instanceId in pairs(reserved) do
            unavailable[tostring(instanceId)] = true
        end
    end

    local bestByBaseId = {}

    for instanceId in pairs(ownedCards) do
        instanceId = tostring(instanceId)

        if not unavailable[instanceId] then
            local card = resolveCard(instanceId)
            if card and isRarityWhitelisted(card.rarity) then
                local groupKey = tostring(card.baseId or card.instanceId)
                local current = bestByBaseId[groupKey]

                if isBetterLoanCandidate(card, current) then
                    bestByBaseId[groupKey] = card
                end
            end
        end
    end

    local bestCard = nil
    for _, card in pairs(bestByBaseId) do
        if isBetterLoanCandidate(card, bestCard) then
            bestCard = card
        end
    end

    return bestCard
end

local function getTopAvailableCard(forceScan)
    local now = os.clock()
    if forceScan
        or State.cachedTopCard == nil
        or now - State.lastTopCardScan >= TOP_CARD_SCAN_INTERVAL
    then
        State.cachedTopCard = findTopAvailableCard()
        State.lastTopCardScan = now
    end

    return State.cachedTopCard
end

local function getActiveLoanCount()
    local activeLoans = Runtime.getData("Loans.active")
    if type(activeLoans) ~= "table" then
        return 0
    end

    local count = 0
    for _, loanData in pairs(activeLoans) do
        if type(loanData) == "table" then
            count += 1
        end
    end

    return count
end

local function getLoanSlotCapacity()
    local loanConfig = State.loanConfig
    if not loanConfig or type(loanConfig.UnlockedSlots) ~= "function" then
        return nil
    end

    local clubLevel = tonumber(Runtime.getData("Club.Level")) or 1
    local prestigeCount = tonumber(Runtime.getData("Prestige.Count")) or 0
    local success, baseSlots = pcall(loanConfig.UnlockedSlots, clubLevel, prestigeCount)

    if not success or type(baseSlots) ~= "number" then
        return nil
    end

    local bonusSlots = 0
    local skillsConfig = State.skillsConfig
    if skillsConfig and type(skillsConfig.BonusLoanSlots) == "function" then
        local ownedSkills = Runtime.getData("Skills.owned") or {}
        local bonusSuccess, result = pcall(skillsConfig.BonusLoanSlots, ownedSkills)
        if bonusSuccess then
            bonusSlots = tonumber(result) or 0
        end
    end

    return math.max(0, math.floor(baseSlots + bonusSlots))
end

local function getLoanSlotState()
    local activeCount = getActiveLoanCount()
    local capacity = getLoanSlotCapacity()

    if capacity == nil then
        return true, activeCount, nil
    end

    return activeCount < capacity, activeCount, capacity
end

local function buildRows()
    local activeLoans = Runtime.getData("Loans.active")
    if type(activeLoans) ~= "table" then
        activeLoans = {}
    end

    local now = os.time()
    local rows = {}

    for slot, loanData in pairs(activeLoans) do
        if type(slot) == "number" and type(loanData) == "table" then
            local instanceId = tostring(loanData.instanceId or "unknown")
            local card = resolveCard(instanceId, loanData)
            local endsAt = tonumber(loanData.endsAt) or 0
            local remaining = math.max(0, endsAt - now)

            rows[#rows + 1] = {
                slot = slot,
                key = tostring(slot) .. ":" .. instanceId,
                instanceId = instanceId,
                name = tostring(card.name),
                rating = tonumber(card.rating) or 0,
                position = tostring(card.position),
                rarity = tostring(card.rarity),
                club = tostring(card.club),
                endsAt = endsAt,
                remaining = remaining,
                ready = remaining <= 0,
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.ready ~= b.ready then
            return a.ready
        end
        return a.slot < b.slot
    end)

    return rows
end

local function buildStructureSignature(rows)
    local parts = {}

    for _, row in ipairs(rows) do
        parts[#parts + 1] = table.concat({
            row.key,
            row.name,
            tostring(row.rating),
            row.position,
            row.rarity,
            row.club,
            tostring(row.endsAt),
            tostring(row.ready),
        }, "|")
    end

    return table.concat(parts, ";")
end

local function clearRows()
    State.lastStructureSignature = nil
end

local function formatLoanRows(rows)
    if #rows == 0 then
        return "Tidak ada pemain yang sedang loan out."
    end

    local lines = {}
    for _, row in ipairs(rows) do
        local status = row.ready and "READY" or "ON LOAN"
        local remaining = row.ready and "Collect now" or formatRemaining(row.remaining)
        lines[#lines + 1] = string.format(
            "[%s] Slot %d • %s • %d OVR • %s • %s • %s",
            status,
            row.slot,
            row.name,
            row.rating,
            row.position,
            tostring(row.rarity):gsub("WorldClass", "World Class"),
            remaining
        )
    end

    return table.concat(lines, "\n")
end

local function reconcileTrackedAutoLoans(rows)
    local activeIds = {}
    for _, row in ipairs(rows) do
        activeIds[row.instanceId] = true
    end

    local now = os.time()
    for instanceId, tracked in pairs(State.autoLoanedIds) do
        local sentAt = type(tracked) == "table" and tonumber(tracked.sentAt) or 0
        if not activeIds[instanceId] and now - sentAt > TRACKED_LOAN_GRACE then
            State.autoLoanedIds[instanceId] = nil
        end
    end
end

local function getSelectedRarityLabels()
    local values = {}
    for _, rarity in ipairs(State.rarityOptions) do
        if isRarityWhitelisted(rarity) then
            values[#values + 1] = tostring(rarity):gsub("WorldClass", "World Class")
        end
    end
    return values
end

local function rarityFromDisplayLabel(label)
    label = tostring(label)
    if label == "World Class" then
        return "WorldClass"
    end
    return label
end

local function syncConfigurationControls()
    if State.syncingConfiguration then
        return
    end

    State.syncingConfiguration = true

    if State.durationDropdown and type(State.durationDropdown.Select) == "function" then
        State.durationDropdown:Select(Runtime.getDurationLabel(State.selectedDuration))
    end

    if State.rarityDropdown and type(State.rarityDropdown.Select) == "function" then
        State.rarityDropdown:Select(getSelectedRarityLabels())
    end

    if State.worldCupSquadDropdown then
        local label = worldCupSquadModeLabel(State.worldCupSquadMode)
        pcall(function()
            if type(State.worldCupSquadDropdown.Select) == "function" then
                State.worldCupSquadDropdown:Select(label)
            elseif type(State.worldCupSquadDropdown.SetValue) == "function" then
                State.worldCupSquadDropdown:SetValue(label)
            end
        end)
    end

    if State.packPickModeDropdown then
        local label = packPickModeLabel(State.packPickMode)
        pcall(function()
            if type(State.packPickModeDropdown.Select) == "function" then
                State.packPickModeDropdown:Select(label)
            elseif type(State.packPickModeDropdown.SetValue) == "function" then
                State.packPickModeDropdown:SetValue(label)
            end
        end)
    end

    if State.packBuyWhitelistDropdown and type(State.packBuyWhitelistDropdown.Select) == "function" then
        local selected = {}
        for _, tier in ipairs(State.packShopTiers or {}) do
            if State.packBuyWhitelist[tier] == true then
                selected[#selected + 1] = State.packShopTierToLabel[tier] or tier
            end
        end
        pcall(function()
            State.packBuyWhitelistDropdown:Select(selected)
        end)
    end

    if State.packLogRarityDropdown and type(State.packLogRarityDropdown.Select) == "function" then
        local selected = {}
        for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
            if State.packLogRarityWhitelist[rarity] ~= false then
                selected[#selected + 1] = rarity == "WorldClass" and "World Class" or rarity
            end
        end
        pcall(function()
            State.packLogRarityDropdown:Select(selected)
        end)
    end

    State.syncingConfiguration = false
end

local function updateDashboardUI()
    if State.dashboardParagraph and type(State.dashboardParagraph.SetDesc) == "function" then
        State.dashboardParagraph:SetDesc(string.format(
            "Auto Sent: %s  •  In Rotation: %s  •  Auto Collected: %s  •  Auto Income: £%s\n%s  •  Failed: %d  •  Last income: £%s",
            formatNumber(State.stats.autoSent),
            formatNumber(getTrackedAutoLoanCount()),
            formatNumber(State.stats.autoCollected),
            formatCompactNumber(State.stats.autoIncome),
            tostring(State.stats.lastAction),
            tonumber(State.stats.failures) or 0,
            formatCompactNumber(State.stats.lastIncome)
        ))
    end
end

local function updateConfigurationVisuals()
    if State.configurationParagraph and type(State.configurationParagraph.SetDesc) == "function" then
        State.configurationParagraph:SetDesc(string.format(
            "Duration: %s  •  Whitelist: %d/%d rarity aktif",
            Runtime.getDurationLabel(State.selectedDuration),
            Runtime.getEnabledRarityCount(),
            #State.rarityOptions
        ))
    end

    if not State.configurationFromUI then
        syncConfigurationControls()
    end
    State.configurationFromUI = false
end

local refreshUI

local function isValidDuration(minutes)
    minutes = tonumber(minutes)
    if not minutes then
        return false
    end

    for _, option in ipairs(State.durationOptions) do
        if option == minutes then
            return true
        end
    end

    return false
end

local function applyLoadedConfig(config)
    if type(config) ~= "table" then
        return false, "Format config tidak valid"
    end

    State.configLoading = true
    State.syncingConfiguration = true

    if config.autoSave ~= nil then
        State.autoSave = config.autoSave == true
    end
    if config.autoLoad ~= nil then
        State.autoLoad = config.autoLoad == true
    end

    local keyName = normalizeKeybindName(config.windowKeybind or State.windowKeybind)
    State.windowKeybind = keyName
    if State.window and type(State.window.SetToggleKey) == "function" then
        State.window:SetToggleKey(Enum.KeyCode[keyName])
    end
    if State.windowKeybindControl then
        pcall(function()
            if type(State.windowKeybindControl.Set) == "function" then
                State.windowKeybindControl:Set(keyName, false)
            elseif type(State.windowKeybindControl.SetValue) == "function" then
                State.windowKeybindControl:SetValue(keyName)
            end
        end)
    end

    local loadedDuration = tonumber(config.duration)
    if isValidDuration(loadedDuration) then
        State.selectedDuration = loadedDuration
    end

    if type(config.rarityWhitelist) == "table" then
        for _, rarity in ipairs(State.rarityOptions) do
            local configured = config.rarityWhitelist[rarity]
            if configured ~= nil then
                State.rarityWhitelist[rarity] = configured == true
            end
        end
    end

    if config.autoLoan ~= nil then
        State.autoLoan = config.autoLoan == true
    end
    if config.autoCollect ~= nil then
        State.autoCollect = config.autoCollect == true
    end
    if config.autoPrestige ~= nil then
        State.autoPrestige = config.autoPrestige == true
    end
    if config.autoPlay ~= nil then
        State.autoMatch = config.autoPlay == true
        State.autoMatchPendingSync = true
    elseif config.autoMatch ~= nil then
        State.autoMatch = config.autoMatch == true
        State.autoMatchPendingSync = true
    end
    if config.autoOpenPacks ~= nil then
        State.autoOpenPacks = config.autoOpenPacks == true
    end
    if config.packPickMode ~= nil then
        State.packPickMode = normalizePackPickMode(config.packPickMode)
    end
    if config.skipPackAnimation ~= nil then
        State.skipPackAnimation = config.skipPackAnimation == true
    end
    if config.instantPacks ~= nil then
        State.instantPacks = config.instantPacks == true
    end
    if config.autoBuyPacks ~= nil then
        State.autoBuyPacks = config.autoBuyPacks == true
    end
    if config.packBuyPrestigePriority ~= nil then
        State.packBuyPrestigePriority = config.packBuyPrestigePriority == true
    end
    if type(config.packBuyWhitelist) == "table" then
        State.packBuyWhitelist = {}
        for tier, enabled in pairs(config.packBuyWhitelist) do
            State.packBuyWhitelist[tostring(tier)] = enabled == true
        end
    end
    if type(config.packLogRarityWhitelist) == "table" then
        for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
            local configured = config.packLogRarityWhitelist[rarity]
            if configured ~= nil then
                State.packLogRarityWhitelist[rarity] = configured == true
            end
        end
    end
    if config.autoClaimPlayTimeRewards ~= nil then
        State.autoClaimPlayTimeRewards = config.autoClaimPlayTimeRewards == true
    end
    if config.autoClaimDailyReward ~= nil then
        State.autoClaimDailyReward = config.autoClaimDailyReward == true
    end
    if config.autoEquipBest ~= nil then
        State.autoEquipBest = config.autoEquipBest == true
    end
    if config.autoJoinWorldCup ~= nil then
        State.autoJoinWorldCup = config.autoJoinWorldCup == true
    end
    if config.autoCollectWorldCupRewards ~= nil then
        State.autoCollectWorldCupRewards = config.autoCollectWorldCupRewards == true
    end
    if config.fillWorldCupVisualBeforeJoin ~= nil then
        State.fillWorldCupVisualBeforeJoin = config.fillWorldCupVisualBeforeJoin == true
    end
    if config.autoPickupSpawnedPacks ~= nil then
        State.autoPickupSpawnedPacks = config.autoPickupSpawnedPacks == true
    end
    if config.lockPosition ~= nil then
        State.lockPosition = config.lockPosition == true
        State.lockedCFrame = nil
    end
    if config.autoConveyor ~= nil then
        State.autoConveyor = config.autoConveyor == true
    end
    if config.antiAfk ~= nil then
        State.antiAfk = config.antiAfk == true
    end
    if config.worldCupSquadMode ~= nil then
        State.worldCupSquadMode = normalizeWorldCupSquadMode(config.worldCupSquadMode)
    end

    State.nextAutoLoanAt = 0
    State.nextAutoCollectAt = 0
    State.nextPrestigeCheckAt = 0
    State.nextAutoOpenPackAt = 0
    State.nextAutoBuyPackAt = 0
    State.nextPackBuyPrestigeRefreshAt = 0
    State.nextPlayTimeClaimAt = 0
    State.nextDailyRewardClaimAt = 0
    State.nextAutoEquipBestAt = 0
    State.nextWorldCupCheckAt = 0
    State.nextWorldCupRewardCheckAt = 0
    State.nextSpawnedPackScanAt = 0
    State.lastObservedPackCount = 0
    State.lastEquipBestSignature = nil
    State.cachedTopCard = nil
    State.configDirty = false

    syncPersistentConfig()

    State.syncingConfiguration = false
    State.configLoading = false

    syncConfigurationControls()
    updateAutomationButtons()
    if Runtime.updateWorldCupPreview then
        Runtime.updateWorldCupPreview()
    end
    updateConfigurationVisuals()
    if updateConfigManagerUI then
        updateConfigManagerUI()
    end
    refreshUI(true)

    return true
end

local function loadConfigFromDisk()
    local config, loadError = readRawConfigFile()
    if not config then
        return false, loadError
    end

    local success, applyError = applyLoadedConfig(config)
    if not success then
        return false, applyError
    end

    return true
end

local function updatePrestigeParagraph()
    local paragraph = State.prestigeParagraph
    if not paragraph or type(paragraph.SetDesc) ~= "function" then
        return
    end

    local gateParagraphs = State.prestigeGateParagraphs or {}
    local info = State.prestigeInfo

    if not info then
        if type(paragraph.SetTitle) == "function" then
            paragraph:SetTitle("Prestige Status")
        end
        paragraph:SetDesc("Belum ada data. Tekan Check Prestige untuk memuat status terbaru.")

        for _, gateParagraph in ipairs(gateParagraphs) do
            if gateParagraph.ElementFrame then
                gateParagraph.ElementFrame.Visible = false
            end
        end
        return
    end

    local count = tonumber(info.count) or 0
    local nextNumber = tonumber(info.nextNumber) or (count + 1)

    if type(paragraph.SetTitle) == "function" then
        paragraph:SetTitle(string.format("Prestige %d  →  Prestige %d", count, nextNumber))
    end

    if info.eligible then
        paragraph:SetDesc("READY TO PRESTIGE • Semua requirement sudah terpenuhi.")
    else
        paragraph:SetDesc("NOT ELIGIBLE • Selesaikan requirement yang belum terpenuhi.")
    end

    local gates = type(info.gates) == "table" and info.gates or {}

    for index, gateParagraph in ipairs(gateParagraphs) do
        local gate = gates[index]

        if gate and type(gate) == "table" then
            if gateParagraph.ElementFrame then
                gateParagraph.ElementFrame.Visible = true
            end

            if type(gateParagraph.SetTitle) == "function" then
                gateParagraph:SetTitle(tostring(gate.label or gate.kind or ("Requirement " .. index)))
            end

            local description
            if gate.met then
                description = "DONE"
            elseif gate.kind == "text" then
                local current = gate.cur
                if current == nil or tostring(current) == "" then
                    current = "Pending"
                end
                description = "Current: " .. tostring(current)
            else
                local current = tonumber(gate.cur) or 0
                local needed = math.max(tonumber(gate.need) or 0, 0)
                local percent = needed > 0 and math.clamp(current / needed, 0, 1) * 100 or 0

                description = string.format(
                    "%s / %s  •  %.1f%%",
                    formatNumber(current),
                    formatNumber(needed),
                    percent
                )
            end

            if type(gateParagraph.SetDesc) == "function" then
                gateParagraph:SetDesc(description)
            end
        elseif gateParagraph.ElementFrame then
            gateParagraph.ElementFrame.Visible = false
        end
    end
end

refreshUI = function(forceRebuild, allowInstanceAccess)
    if allowInstanceAccess ~= true then
        State.uiRefreshRequested = true
        return
    end
    if not State.running or not State.window then
        return
    end

    State.uiRefreshRequested = false

    if State.pendingStatus then
        local pending = State.pendingStatus
        State.pendingStatus = nil
        setStatus(pending.text, pending.color)
    end

    -- Settings.AutoMatch tetap menjadi status backend Auto Play dari game. Saat config belum
    -- menunggu sinkronisasi dan request tidak sedang berjalan, ikuti perubahan
    -- dari menu/indicator bawaan game (misalnya tombol STOP).
    if not State.settingAutoMatch
        and not State.autoMatchTransaction
        and not State.autoMatchPendingSync
        and os.clock() >= State.autoMatchSyncIgnoreUntil
    then
        local serverAutoMatch = Runtime.getData("Settings.AutoMatch")
        if type(serverAutoMatch) == "boolean" and serverAutoMatch ~= State.autoMatch then
            State.autoMatch = serverAutoMatch
            PersistentConfig.autoMatch = serverAutoMatch
            requestConfigSave()
        end
    end

    local rows = buildRows()
    reconcileTrackedAutoLoans(rows)
    local topCard = getTopAvailableCard(forceRebuild)
    local hasFreeSlot, activeCount, slotCapacity = getLoanSlotState()
    local readyCount = 0

    for _, row in ipairs(rows) do
        if row.ready then
            readyCount += 1
        end
    end

    if State.summaryParagraph and type(State.summaryParagraph.SetDesc) == "function" then
        local activeText
        if slotCapacity ~= nil then
            activeText = string.format("%d/%d Active", activeCount, slotCapacity)
        else
            activeText = string.format("%d Active Loan%s", #rows, #rows == 1 and "" or "s")
        end

        State.summaryParagraph:SetDesc(string.format(
            "%s  •  %d Ready  •  Duration %s  •  Whitelist %d/%d",
            activeText,
            readyCount,
            Runtime.getDurationLabel(State.selectedDuration),
            Runtime.getEnabledRarityCount(),
            #State.rarityOptions
        ))
    end

    if State.loanListParagraph and type(State.loanListParagraph.SetDesc) == "function" then
        State.loanListParagraph:SetDesc(formatLoanRows(rows))
    end

    updateAutomationButtons(true)
    updateDashboardUI()
    updatePrestigeParagraph()

    local networkReady = isNetworker(State.networker)
    local actionBusy = State.collecting
        or State.loaning
        or State.prestiging
        or State.equippingBest
        or State.autoMatchTransaction
        or State.joiningWorldCup
        or State.collectingWorldCupReward
        or State.fillingWorldCupVisual
        or State.pickingSpawnedPacks
        or State.claimingPlayTimeRewards

    if not State.collecting then
        if readyCount > 0 and networkReady and not actionBusy then
            setCollectButton(string.format("Collect All (%d)", readyCount), true)
        elseif readyCount > 0 then
            setCollectButton(string.format("Collect All (%d)", readyCount), false)
        else
            setCollectButton("Collect All", false)
        end
    end

    if not State.loaning then
        if not hasFreeSlot and slotCapacity ~= nil then
            setLoanButton("Loan Slots Full", false)
        elseif topCard and networkReady and not actionBusy then
            setLoanButton(string.format("Loan Top (%s)", Runtime.getDurationLabel(State.selectedDuration)), true)
        else
            setLoanButton(string.format("Loan Top (%s)", Runtime.getDurationLabel(State.selectedDuration)), false)
        end
    end
end

local tryRediscoverNetworker

local function callNetwork(action, payload)
    local networker = State.networker
    if not isNetworker(networker) then
        return nil, "Networker belum ditemukan"
    end

    local success, response
    if payload == nil then
        success, response = pcall(networker.Call, networker, action)
    else
        success, response = pcall(networker.Call, networker, action, payload)
    end
    if not success then
        return nil, tostring(response)
    end

    if not response then
        return nil, "Server tidak memberikan respons"
    end

    if type(response) == "table" and response.success == false then
        return response, tostring(response.reason or "Request gagal")
    end

    return response, nil
end

local function callNetworkLoose(action, payload)
    local networker = State.networker
    if not isNetworker(networker) then
        return nil, "Networker belum ditemukan"
    end

    local success, response
    if payload == nil then
        success, response = pcall(networker.Call, networker, action)
    else
        success, response = pcall(networker.Call, networker, action, payload)
    end

    if not success then
        return nil, tostring(response)
    end
    if type(response) == "table" and response.success == false then
        return nil, tostring(response.reason or "Request gagal")
    end

    -- Sebagian action UI seperti AutoFillBestEleven bersifat
    -- fire-and-forget dan dapat mengembalikan nil meskipun request diterima.
    return response ~= nil and response or true, nil
end

function Runtime.claimReadyPlayTimeRewards(isAutomatic)
    if State.claimingPlayTimeRewards then
        return false, "Claim playtime sedang diproses"
    end

    if not tryRediscoverNetworker() then
        return false, "Networker belum ditemukan"
    end

    local rewardState = Runtime.getPlayTimeRewardState()
    if not rewardState.configAvailable then
        return false, "PlayTimeConfig tidak ditemukan"
    end
    if rewardState.readyCount <= 0 then
        return false, "Belum ada reward playtime yang siap"
    end

    State.claimingPlayTimeRewards = true
    updateAutomationButtons()

    task.spawn(function()
        local claimedCount = 0
        local lastError

        for _, tierIndex in ipairs(rewardState.readyTiers) do
            if not State.running
                or (isAutomatic and not State.autoClaimPlayTimeRewards)
            then
                break
            end

            local response, errorMessage = callNetworkLoose("ClaimPlayTime", {
                tier = tierIndex,
            })

            if response then
                claimedCount += 1
            else
                lastError = errorMessage
            end

            task.wait(0.25)
        end

        State.claimingPlayTimeRewards = false
        State.lastPlayTimeClaimAt = os.time()
        State.lastPlayTimeClaimCount = claimedCount
        State.nextPlayTimeClaimAt = os.clock() + 5
        State.nextAutoOpenPackAt = 0
        updateAutomationButtons()
        refreshUI(true)

        if claimedCount > 0 then
            setStatus(
                string.format("Playtime reward diklaim: %d tier.", claimedCount),
                COLORS.success
            )
        elseif not isAutomatic then
            setStatus(
                "Claim Playtime gagal: " .. tostring(lastError or "request ditolak"),
                COLORS.danger
            )
        end
    end)

    return true
end

function Runtime.claimDailyReward(isAutomatic)
    if State.claimingDailyReward then
        return false, "Claim Daily Reward sedang diproses"
    end

    if not tryRediscoverNetworker() then
        return false, "Networker belum ditemukan"
    end

    local dailyState = Runtime.getDailyRewardState()
    if not dailyState.available then
        return false, "Daily Reward belum tersedia"
    end
    if not dailyState.ready then
        return false, "Onboarding belum selesai"
    end

    State.claimingDailyReward = true
    State.lastDailyRewardClaimError = nil
    updateAutomationButtons()

    task.spawn(function()
        local response, errorMessage = callNetwork("ClaimDailyReward")
        local claimed = response == true
            or (
                type(response) == "table"
                and response.success == true
            )

        State.claimingDailyReward = false
        State.nextDailyRewardClaimAt = os.clock() + 5

        if claimed then
            State.lastDailyRewardClaimAt = os.time()
            State.lastDailyRewardClaimDay = dailyState.claimDay
            State.lastDailyRewardClaimResponse = response
            State.lastDailyRewardClaimError = nil
            State.nextAutoOpenPackAt = 0

            setStatus(
                string.format(
                    "Daily Reward Day %d berhasil diklaim.",
                    dailyState.claimDay
                ),
                COLORS.success
            )
        else
            State.lastDailyRewardClaimResponse = response
            State.lastDailyRewardClaimError = tostring(
                errorMessage or "Server tidak mengonfirmasi claim"
            )

            if not isAutomatic then
                setStatus(
                    "Claim Daily Reward gagal: "
                        .. State.lastDailyRewardClaimError,
                    COLORS.danger
                )
            end
        end

        updateAutomationButtons()
        refreshUI(true)
    end)

    return true
end


local function getPlaybackEventBus()
    local eventBus = State.eventBus
    if eventBus ~= nil and type(eventBus.Fire) == "function" then
        return eventBus
    end

    local dataService, networker, discoveredEventBus = findFrameworkFromGC()
    if isDataService(dataService) then
        State.dataService = dataService
    end
    if isNetworker(networker) then
        State.networker = networker
    end
    if discoveredEventBus ~= nil and type(discoveredEventBus.Fire) == "function" then
        State.eventBus = discoveredEventBus
        return discoveredEventBus
    end

    return nil
end

local function fireMatchPlaybackRequested(matchResponse)
    local eventBus = getPlaybackEventBus()
    if not eventBus then
        return false, "EventBus belum ditemukan"
    end

    local payload = matchResponse
    if type(matchResponse) == "table" then
        payload = table.clone(matchResponse)
        payload.view = "background"
    end

    local success, result = pcall(
        eventBus.Fire,
        eventBus,
        "MatchPlaybackRequested",
        payload
    )
    if not success then
        return false, tostring(result)
    end

    -- Listener Signal akan menyinkronkan nilai ini juga. Set langsung agar
    -- automation lain tidak sempat mengirim request squad saat playback dimulai.
    State.matchPlaybackActive = true
    State.uiRefreshRequested = true

    return true, result
end

local function requestAutoPlayStart()
    if not isNetworker(State.networker) then
        if type(tryRediscoverNetworker) == "function" then
            tryRediscoverNetworker()
        end
    end
    if not isNetworker(State.networker) then
        return false, "Networker belum ditemukan"
    end

    local serverAutoMatch = Runtime.getData("Settings.AutoMatch") == true

    -- Jika match sedang berjalan, jangan AttemptSendOut lagi. Cukup aktifkan
    -- SetAutoMatch agar match berikutnya dilanjutkan secara otomatis.
    if State.matchPlaybackActive then
        if not serverAutoMatch then
            local enabledResponse, enabledError = callNetworkLoose(
                "SetAutoMatch",
                {enabled = true}
            )
            if not enabledResponse then
                return false, enabledError
            end
        end
        return true
    end

    -- Selalu coba AttemptSendOut bila tidak ada playback yang terdeteksi.
    -- Ini juga memperbaiki state lama ketika SetAutoMatch sudah true tetapi
    -- match pertama belum pernah dikirim.
    local matchResponse, matchError = callNetwork("AttemptSendOut")
    if not matchResponse then
        return false, matchError or "AttemptSendOut gagal"
    end
    if type(matchResponse) == "table" and matchResponse.success ~= true then
        local reason = tostring(matchResponse.reason or matchError or "AttemptSendOut ditolak")
        local normalizedReason = string.lower(reason)
        local likelyAlreadyRunning = serverAutoMatch
            and (
                string.find(normalizedReason, "progress", 1, true)
                or string.find(normalizedReason, "already", 1, true)
                or string.find(normalizedReason, "active", 1, true)
                or string.find(normalizedReason, "running", 1, true)
            )

        if likelyAlreadyRunning then
            return true, reason
        end

        return false, reason
    end

    local enabledResponse, enabledError = callNetworkLoose(
        "SetAutoMatch",
        {enabled = true}
    )
    if not enabledResponse then
        return false, "Match terkirim, tetapi SetAutoMatch gagal: "
            .. tostring(enabledError)
    end

    local playbackStarted, playbackError = fireMatchPlaybackRequested(matchResponse)
    if not playbackStarted then
        -- Match dan setting AutoMatch sudah diterima server. Pertahankan status ON,
        -- tetapi laporkan bahwa tampilan background tidak berhasil dibuka.
        return true, "Match dimulai, tetapi playback background gagal: "
            .. tostring(playbackError)
    end

    return true
end

local function setAutoPlayEnabled(enabled, announce, forceRequest)
    enabled = enabled == true

    if State.settingAutoMatch or State.autoMatchTransaction then
        return false, "Pengaturan Auto Play sedang diproses"
    end

    local previousValue = State.autoMatch
    State.autoMatch = enabled
    PersistentConfig.autoPlay = enabled
    PersistentConfig.autoMatch = enabled -- compatibility untuk config lama
    State.autoMatchPendingSync = true
    State.nextAutoMatchSyncAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if type(tryRediscoverNetworker) ~= "function" then
        return false, "Networker discovery belum siap"
    end

    if not isNetworker(State.networker) then
        tryRediscoverNetworker()
    end

    if not isNetworker(State.networker) then
        if announce ~= false then
            setStatus("Auto Play menunggu Networker ditemukan.", COLORS.warning)
        end
        return false, "Networker belum ditemukan"
    end

    State.settingAutoMatch = true
    State.autoMatchPendingSync = false
    updateAutomationButtons()

    task.spawn(function()
        local accepted = false
        local warningMessage = nil
        local errorMessage = nil

        if enabled then
            accepted, warningMessage = requestAutoPlayStart()
            if not accepted then
                errorMessage = warningMessage
                warningMessage = nil
            end
        else
            local response, requestError = callNetworkLoose(
                "SetAutoMatch",
                {enabled = false}
            )
            accepted = response ~= nil
            errorMessage = requestError
        end

        State.settingAutoMatch = false

        if accepted then
            State.autoMatch = enabled
            PersistentConfig.autoPlay = enabled
            PersistentConfig.autoMatch = enabled
            State.autoMatchSyncIgnoreUntil = os.clock() + 5
            State.nextAutoMatchSyncAt = 0
            State.nextAutoPlayEnsureAt = os.clock() + AUTO_PLAY_ENSURE_DELAY
            State.autoMatchPendingSync = false
            requestConfigSave()

            if announce ~= false then
                if warningMessage then
                    setStatus(warningMessage, COLORS.warning)
                else
                    setStatus(
                        enabled
                            and "Auto Play dimulai di background."
                            or "Auto Play dihentikan; match yang sedang berjalan tidak dipaksa berhenti.",
                        enabled and COLORS.success or COLORS.muted
                    )
                end
            end
        else
            local serverValue = Runtime.getData("Settings.AutoMatch")
            if type(serverValue) == "boolean" then
                State.autoMatch = serverValue
            else
                State.autoMatch = previousValue
            end
            PersistentConfig.autoPlay = State.autoMatch
            PersistentConfig.autoMatch = State.autoMatch
            State.autoMatchPendingSync = forceRequest == true
            State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY

            if announce ~= false then
                setStatus("Auto Play gagal: " .. tostring(errorMessage), COLORS.danger)
            end
        end

        updateAutomationButtons()
        refreshUI(false)
    end)

    return true
end

tryRediscoverNetworker = function()
    if isNetworker(State.networker) then
        return true
    end

    local dataService, networker, eventBus = findFrameworkFromGC()

    if isDataService(dataService) then
        State.dataService = dataService
    end

    if isNetworker(networker) then
        State.networker = networker
    end

    if eventBus then
        State.eventBus = eventBus
    end

    return isNetworker(State.networker)
end

local function tryRediscoverEventBus()
    local eventBus = State.eventBus
    if eventBus ~= nil and type(eventBus.Fire) == "function" then
        return true
    end

    local dataService, networker, discoveredEventBus = findFrameworkFromGC()
    if isDataService(dataService) then
        State.dataService = dataService
    end
    if isNetworker(networker) then
        State.networker = networker
    end
    if discoveredEventBus ~= nil and type(discoveredEventBus.Fire) == "function" then
        State.eventBus = discoveredEventBus
    end

    return State.eventBus ~= nil and type(State.eventBus.Fire) == "function"
end

local function fireBusEvent(eventName, payload)
    if not tryRediscoverEventBus() then
        return false, "EventBus belum ditemukan"
    end

    local eventBus = State.eventBus
    local success, result = pcall(eventBus.Fire, eventBus, eventName, payload)
    if not success then
        return false, tostring(result)
    end

    return true, result
end

Runtime.isPackLogRarityEnabled = function(rarity)
    return State.packLogRarityWhitelist[tostring(rarity or "Unknown")] ~= false
end

Runtime.resolvePackLogCard = function(card)
    if type(card) ~= "table" then
        return nil
    end

    local resolved = Runtime.resolvePackChoiceCard and Runtime.resolvePackChoiceCard(card, 1) or nil
    if resolved then
        return {
            instanceId = card.instanceId,
            baseId = card.baseId,
            name = resolved.name,
            rating = resolved.rating,
            rarity = resolved.rarity,
            position = tostring(card.position or ""),
        }
    end

    return {
        instanceId = card.instanceId,
        baseId = card.baseId,
        name = tostring(card.name or "Unknown Card"),
        rating = tonumber(card.rating) or 0,
        rarity = tostring(card.rarity or "Unknown"),
        position = tostring(card.position or ""),
    }
end

Runtime.appendPackSessionLog = function(card, tier, kind, selectedIndex)
    local resolved = Runtime.resolvePackLogCard(card)
    if not resolved then
        return nil
    end

    local entry = {
        time = os.time(),
        tier = tostring(tier or "Pack"),
        kind = tostring(kind or "normal"),
        selectedIndex = tonumber(selectedIndex),
        instanceId = resolved.instanceId,
        baseId = resolved.baseId,
        name = resolved.name,
        rating = resolved.rating,
        rarity = resolved.rarity,
        position = resolved.position,
    }

    local entries = State.packSession.entries
    entries[#entries + 1] = entry
    State.packSession.totalOpened = (tonumber(State.packSession.totalOpened) or 0) + 1
    if entry.kind == "pick" then
        State.packSession.totalPickPacks = (tonumber(State.packSession.totalPickPacks) or 0) + 1
    end

    while #entries > 250 do
        table.remove(entries, 1)
    end

    State.lastPackLogUpdateAt = os.clock()
    State.packUiDirty = true
    State.uiRefreshRequested = true

    return entry
end

Runtime.getFilteredPackSessionEntries = function()
    local result = {}
    for _, entry in ipairs(State.packSession.entries) do
        if Runtime.isPackLogRarityEnabled(entry.rarity) then
            result[#result + 1] = entry
        end
    end
    return result
end

Runtime.formatPackSessionLog = function()
    local entries = Runtime.getFilteredPackSessionEntries()
    if #entries == 0 then
        return "Belum ada card yang sesuai filter."
    end

    local lines = {}
    local firstIndex = math.max(1, #entries - 39)
    for index = firstIndex, #entries do
        local entry = entries[index]
        local clockText = os.date("%H:%M:%S", tonumber(entry.time) or os.time())
        local pickText = entry.kind == "pick"
            and string.format(" • PICK #%d", tonumber(entry.selectedIndex) or 0)
            or ""
        lines[#lines + 1] = string.format(
            "[%s] %s • %s OVR • %s%s • %s",
            clockText,
            tostring(entry.name),
            tostring(entry.rating),
            tostring(entry.rarity),
            pickText,
            tostring(entry.tier)
        )
    end

    return table.concat(lines, "\n")
end

Runtime.updatePackUI = function(allowInstanceAccess)
    if allowInstanceAccess ~= true then
        State.packUiDirty = true
        State.uiRefreshRequested = true
        return
    end
    if Runtime.updatePackShopUI then
        Runtime.updatePackShopUI()
    end

    if not State.packUiDirty
        and State.lastPackUiRenderAt
        and os.clock() - State.lastPackUiRenderAt < 1
    then
        return
    end

    local visibleCount = #Runtime.getFilteredPackSessionEntries()
    local hasPass = Runtime.getData and Runtime.getData("Passes.InstantOpen") == true
    local pickReady = State.packConfig ~= nil

    if State.packSummaryParagraph and type(State.packSummaryParagraph.SetDesc) == "function" then
        pcall(function()
            State.packSummaryParagraph:SetDesc(string.format(
                "Owned: %d • Session: %d • Visible: %d • Pick: %d\nMode: %s • PackConfig: %s • Skip: %s • Instant: %s%s",
                Runtime.getOwnedPackCount and Runtime.getOwnedPackCount() or 0,
                tonumber(State.packSession.totalOpened) or 0,
                visibleCount,
                tonumber(State.packSession.totalPickPacks) or 0,
                packPickModeLabel(State.packPickMode),
                pickReady and "READY" or "MISSING",
                State.skipPackAnimation and "ON" or "OFF",
                State.instantPacks and "ON" or "OFF",
                State.instantPacks and not hasPass and " (fallback)" or ""
            ))
        end)
    end

    if State.packLogParagraph and type(State.packLogParagraph.SetDesc) == "function" then
        pcall(function()
            State.packLogParagraph:SetDesc(Runtime.formatPackSessionLog())
        end)
    end

    State.packUiDirty = false
    State.lastPackUiRenderAt = os.clock()
end

Runtime.clearPackSessionLog = function(announce)
    table.clear(State.packSession.entries)
    State.packSession.totalOpened = 0
    State.packSession.totalPickPacks = 0
    State.packSession.startedAt = os.time()
    State.packUiDirty = true
    State.uiRefreshRequested = true

    if announce ~= false then
        setStatus("Pack session log dibersihkan.", COLORS.success)
    end

    return true
end

Runtime.refreshPackShopTiers = function()
    local packConfig = State.packConfig
    local tiers = {}
    local seen = {}
    local discoverySources = {}
    local visitedTables = {}
    local scannedTableCount = 0

    local function addTier(value, source)
        if value == nil then
            return false
        end

        local tier = tostring(value)
        if tier == "" or seen[tier] then
            return false
        end

        local config = Runtime.getPackTierConfig and Runtime.getPackTierConfig(tier) or nil
        if type(config) ~= "table" or (tonumber(config.cost) or 0) <= 0 then
            return false
        end

        seen[tier] = true
        tiers[#tiers + 1] = tier
        discoverySources[tier] = tostring(source or "unknown")
        return true
    end

    local function looksLikePackConfig(value)
        return type(value) == "table"
            and (
                value.cost ~= nil
                or value.drops ~= nil
                or value.pick ~= nil
                or value.displayName ~= nil
                or value.packTier ~= nil
            )
    end

    local function scanTable(source, sourceName, depth)
        if type(source) ~= "table"
            or visitedTables[source]
            or depth > 7
            or scannedTableCount >= 6000
        then
            return
        end

        visitedTables[source] = true
        scannedTableCount += 1

        for key, value in pairs(source) do
            if type(key) == "string" then
                addTier(key, sourceName .. ".key")
            end

            if type(value) == "string" then
                addTier(value, sourceName .. ".value")
            elseif type(value) == "table" then
                if looksLikePackConfig(value) then
                    addTier(
                        value.packTier
                            or value.tier
                            or value.id
                            or value.key
                            or (type(key) == "string" and key or nil),
                        sourceName .. ".config"
                    )
                end

                scanTable(value, sourceName .. "." .. tostring(key), depth + 1)
            end
        end
    end

    local function scanFunctionConstants(callback, sourceName)
        if type(callback) ~= "function" then
            return
        end

        local reader = nil
        if type(getconstants) == "function" then
            reader = getconstants
        elseif type(debug) == "table" and type(debug.getconstants) == "function" then
            reader = debug.getconstants
        end

        if type(reader) ~= "function" then
            return
        end

        local success, constants = pcall(reader, callback)
        if success and type(constants) == "table" then
            for index, value in pairs(constants) do
                if type(value) == "string" then
                    addTier(value, sourceName .. ".constant." .. tostring(index))
                end
            end
        end
    end

    local function scanFunctionUpvalues(callback, sourceName)
        if type(callback) ~= "function" then
            return
        end

        local readAll = nil
        if type(getupvalues) == "function" then
            readAll = getupvalues
        elseif type(debug) == "table" and type(debug.getupvalues) == "function" then
            readAll = debug.getupvalues
        end

        if readAll then
            local success, upvalues = pcall(readAll, callback)
            if success and type(upvalues) == "table" then
                for key, value in pairs(upvalues) do
                    if type(value) == "table" then
                        scanTable(value, sourceName .. ".upvalue." .. tostring(key), 0)
                    end
                end
            end
            return
        end

        local getOne = type(debug) == "table" and debug.getupvalue or nil
        if type(getOne) ~= "function" then
            return
        end

        for index = 1, 120 do
            local success, name, value = pcall(getOne, callback, index)
            if not success or name == nil then
                break
            end
            if type(value) == "table" then
                scanTable(value, sourceName .. ".upvalue." .. tostring(name), 0)
            end
        end
    end

    if packConfig then
        scanTable(packConfig, "PackConfig", 0)

        -- Prestige/limited packs sering berada di local table yang ditangkap
        -- oleh PackConfig.Get(), bukan di Order atau PositionalOrder.
        for functionName, callback in pairs(packConfig) do
            if type(callback) == "function" then
                local sourceName = "PackConfig." .. tostring(functionName)
                scanFunctionUpvalues(callback, sourceName)
                scanFunctionConstants(callback, sourceName)

                local lowered = string.lower(tostring(functionName))
                if lowered == "getall"
                    or lowered == "list"
                    or lowered == "all"
                    or string.find(lowered, "prestigepack", 1, true)
                    or string.find(lowered, "shoppack", 1, true)
                then
                    local success, result = pcall(callback)
                    if success and type(result) == "table" then
                        scanTable(result, sourceName .. ".result", 0)
                    end
                end
            end
        end
    end

    -- Beberapa build mengirim daftar pack prestige melalui player data.
    for _, dataPath in ipairs({
        "Packs.PrestigePacks",
        "Packs.Prestige",
        "Packs.Shop",
        "Packs.Available",
        "Packs.Offers",
        "Packs.LimitedPacks",
        "Packs.Owned",
    }) do
        local dataTable = Runtime.getData and Runtime.getData(dataPath) or nil
        if type(dataTable) == "table" then
            scanTable(dataTable, "Data." .. dataPath, 0)
        end
    end

    for _, tier in ipairs({
        "Basic",
        "Premium",
        "Elite",
        "Prestige",
        "PrestigePack",
        "Prestige1",
        "Prestige2",
        "Prestige3",
        "Prestige4",
        "Prestige5",
    }) do
        addTier(tier, "fallback")
    end

    table.sort(tiers, function(a, b)
        local configA = Runtime.getPackTierConfig(a) or {}
        local configB = Runtime.getPackTierConfig(b) or {}

        local prestigeA = tonumber(
            configA.prestige
                or configA.prestigeRequired
                or configA.requiredPrestige
                or configA.minPrestige
                or configA.prestigeLevel
        ) or 0
        local prestigeB = tonumber(
            configB.prestige
                or configB.prestigeRequired
                or configB.requiredPrestige
                or configB.minPrestige
                or configB.prestigeLevel
        ) or 0

        if prestigeA ~= prestigeB then
            return prestigeA > prestigeB
        end

        local costA = tonumber(configA.cost) or 0
        local costB = tonumber(configB.cost) or 0
        if costA ~= costB then
            return costA > costB
        end

        return a < b
    end)

    State.packShopTiers = tiers
    State.packShopLabelToTier = {}
    State.packShopTierToLabel = {}
    State.packShopDiscoverySources = discoverySources
    State.packShopDiscoveryScannedTables = scannedTableCount

    for _, tier in ipairs(tiers) do
        local config = Runtime.getPackTierConfig(tier) or {}
        local baseLabel = tostring(config.displayName or config.name or tier)
        if not string.find(string.lower(baseLabel), "pack", 1, true) then
            baseLabel = baseLabel .. " Pack"
        end

        local prestigeRequirement = tonumber(
            config.prestige
                or config.prestigeRequired
                or config.requiredPrestige
                or config.minPrestige
                or config.prestigeLevel
        )

        local prestigeText = ""
        if prestigeRequirement and prestigeRequirement > 0 then
            prestigeText = string.format(" • P%d", prestigeRequirement)
        elseif string.find(string.lower(tier), "prestige", 1, true) then
            prestigeText = " • PRESTIGE"
        end

        local label = string.format(
            "%s%s • %s",
            baseLabel,
            prestigeText,
            formatCompactNumber(tonumber(config.cost) or 0)
        )

        if State.packShopLabelToTier[label] then
            label = label .. " • " .. tier
        end

        State.packShopLabelToTier[label] = tier
        State.packShopTierToLabel[tier] = label

        if State.packBuyWhitelist[tier] == nil then
            State.packBuyWhitelist[tier] = false
        end
    end

    return tiers
end

Runtime.getPackBuyWhitelistCount = function()
    local enabled = 0
    for _, tier in ipairs(State.packShopTiers or {}) do
        if State.packBuyWhitelist[tier] == true then
            enabled += 1
        end
    end
    return enabled
end

Runtime.getPrestigeCoinGate = function(info)
    if type(info) ~= "table" or type(info.gates) ~= "table" then
        return nil
    end

    for _, gate in ipairs(info.gates) do
        if type(gate) == "table" then
            local identity = string.lower(table.concat({
                tostring(gate.kind or ""),
                tostring(gate.label or ""),
                tostring(gate.id or ""),
                tostring(gate.stat or ""),
                tostring(gate.path or ""),
            }, " "))
            if string.find(identity, "coin", 1, true)
                or string.find(identity, "currency", 1, true)
                or string.find(identity, "cash", 1, true)
            then
                return gate
            end
        end
    end

    return nil
end

Runtime.getPrestigeCoinBudget = function()
    local coins = math.max(0, tonumber(Runtime.getData("Coins")) or 0)

    if not State.packBuyPrestigePriority then
        return {
            coins = coins,
            reserve = 0,
            spendable = coins,
            coinRequirement = nil,
            coinRequirementMet = true,
            infoAvailable = true,
            blocked = false,
            reason = "Priority OFF",
        }
    end

    local info = State.prestigeInfo
    if type(info) ~= "table" then
        return {
            coins = coins,
            reserve = 0,
            spendable = 0,
            coinRequirement = nil,
            coinRequirementMet = false,
            infoAvailable = false,
            blocked = true,
            reason = "Waiting Prestige info",
        }
    end

    if info.eligible == true and State.autoPrestige then
        return {
            coins = coins,
            reserve = coins,
            spendable = 0,
            coinRequirement = coins,
            coinRequirementMet = true,
            infoAvailable = true,
            blocked = true,
            eligible = true,
            reason = "Prestige ready",
        }
    end

    local gate = Runtime.getPrestigeCoinGate(info)
    if not gate then
        return {
            coins = coins,
            reserve = 0,
            spendable = coins,
            coinRequirement = nil,
            coinRequirementMet = true,
            infoAvailable = true,
            blocked = false,
            reason = "No coin gate",
        }
    end

    local required = math.max(0, tonumber(gate.need) or 0)
    local spendable = math.max(0, coins - required)

    return {
        coins = coins,
        reserve = required,
        spendable = spendable,
        coinRequirement = required,
        coinRequirementMet = coins >= required,
        infoAvailable = true,
        blocked = spendable <= 0,
        gate = gate,
        reason = coins < required and "Saving for Prestige" or "Prestige reserve secured",
    }
end

Runtime.getPickPackPurchaseRemaining = function(tier)
    if not Runtime.isPickPackTier(tier) then
        return math.huge
    end

    local packConfig = State.packConfig
    local rotation = packConfig
        and type(packConfig.LimitedRotation) == "table"
        and packConfig.LimitedRotation[tier]
        or nil

    local perWindow = math.max(1, tonumber(rotation and rotation.perWindow) or 1)
    local windowId = nil

    if packConfig and type(packConfig.WindowState) == "function" then
        local success, windowState = pcall(packConfig.WindowState, tier)
        if success and type(windowState) == "table" then
            windowId = windowState.windowId
        end
    end

    local limitedPacks = Runtime.getData("Packs.LimitedPacks")
    local record = type(limitedPacks) == "table" and limitedPacks[tier] or nil
    local bought = 0

    if type(record) == "table"
        and (windowId == nil or record.window == windowId)
    then
        bought = math.max(0, tonumber(record.count) or 0)
    end

    return math.max(0, perWindow - bought)
end

Runtime.getPackBuyCandidates = function(spendable)
    spendable = math.max(0, tonumber(spendable) or 0)
    local candidates = {}

    for _, tier in ipairs(State.packShopTiers or {}) do
        if State.packBuyWhitelist[tier] == true then
            local config = Runtime.getPackTierConfig(tier)
            local cost = type(config) == "table" and math.max(0, tonumber(config.cost) or 0) or 0
            local remaining = Runtime.getPickPackPurchaseRemaining(tier)

            if cost > 0 and cost <= spendable and remaining > 0 then
                candidates[#candidates + 1] = {
                    tier = tier,
                    label = State.packShopTierToLabel[tier] or tier,
                    config = config,
                    cost = cost,
                    pick = Runtime.isPickPackTier(tier),
                    remaining = remaining,
                }
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.cost ~= b.cost then
            return a.cost > b.cost
        end
        return a.tier < b.tier
    end)

    return candidates
end

Runtime.getPackBuyState = function()
    if #State.packShopTiers == 0 and State.packConfig then
        Runtime.refreshPackShopTiers()
    end

    local budget = Runtime.getPrestigeCoinBudget()
    local candidates = Runtime.getPackBuyCandidates(budget.spendable)
    local nextPack = candidates[1]

    local nextCount = 0
    if nextPack and (tonumber(nextPack.cost) or 0) > 0 then
        nextCount = math.max(
            0,
            math.min(
                math.floor((tonumber(budget.spendable) or 0) / nextPack.cost),
                AUTO_BUY_PACK_MAX_BATCH
            )
        )

        if nextPack.pick then
            nextCount = math.min(nextCount, math.max(0, tonumber(nextPack.remaining) or 0))
        end
    end

    return {
        enabled = State.autoBuyPacks,
        running = State.buyingPacks,
        prestigePriority = State.packBuyPrestigePriority,
        coins = budget.coins,
        reserve = budget.reserve,
        spendable = budget.spendable,
        coinRequirement = budget.coinRequirement,
        coinRequirementMet = budget.coinRequirementMet,
        prestigeInfoAvailable = budget.infoAvailable,
        blockedByPrestige = budget.blocked,
        budgetReason = budget.reason,
        whitelistCount = Runtime.getPackBuyWhitelistCount(),
        totalPackCount = #State.packShopTiers,
        discoveryScannedTables = State.packShopDiscoveryScannedTables,
        discoverySources = State.packShopDiscoverySources,
        nextTier = nextPack and nextPack.tier or nil,
        nextLabel = nextPack and nextPack.label or nil,
        nextCost = nextPack and nextPack.cost or nil,
        nextIsPick = nextPack and nextPack.pick or false,
        nextRemaining = nextPack and nextPack.remaining or nil,
        nextCount = nextCount,
        manualBuyCount = 1,
        maxBatch = AUTO_BUY_PACK_MAX_BATCH,
        lastBuyAt = State.lastPackBuyAt,
        lastTier = State.lastPackBuyTier,
        lastCount = State.lastPackBuyCount,
        lastSpent = State.lastPackBuySpent,
        lastError = State.lastPackBuyError,
        status = State.lastPackBuyStatus,
    }
end

Runtime.updatePackShopUI = function(allowInstanceAccess)
    if allowInstanceAccess ~= true then
        State.packUiDirty = true
        State.uiRefreshRequested = true
        return
    end
    local buyState = Runtime.getPackBuyState()

    if State.packShopParagraph and type(State.packShopParagraph.SetDesc) == "function" then
        local nextText = buyState.nextLabel or "None"

        local priorityText
        if not buyState.prestigePriority then
            priorityText = "OFF"
        elseif not buyState.prestigeInfoAvailable then
            priorityText = "WAITING"
        elseif buyState.blockedByPrestige then
            priorityText = "SAVING"
        else
            priorityText = "RESERVED"
        end

        pcall(function()
            State.packShopParagraph:SetDesc(string.format(
                "Coins: %s • Reserve: %s • Spendable: %s\nWhitelist: %d/%d • Next: %s ×%d • Prestige: %s • Scan: %d",
                formatCompactNumber(buyState.coins or 0),
                formatCompactNumber(buyState.reserve or 0),
                formatCompactNumber(buyState.spendable or 0),
                buyState.whitelistCount or 0,
                buyState.totalPackCount or 0,
                nextText,
                tonumber(buyState.nextCount) or 0,
                priorityText,
                tonumber(State.packShopDiscoveryScannedTables) or 0
            ))
        end)
    end

    if State.packBuyButton then
        local canBuy = not State.buyingPacks
            and (buyState.whitelistCount or 0) > 0
            and (buyState.totalPackCount or 0) > 0

        -- Hindari SetTitle dari callback WindUI: pada sebagian executor callback
        -- berjalan tanpa capability Instance/Plugin.
        setElementLocked(State.packBuyButton, not canBuy)
    end
end

Runtime.buySelectedPacks = function(isAutomatic, requestedCount)
    if State.buyingPacks then
        return false, "Pembelian pack sedang berjalan"
    end

    if State.openingPacks then
        return false, "Auto Open Packs sedang berjalan"
    end

    if #State.packShopTiers == 0 then
        Runtime.refreshPackShopTiers()
    end

    if Runtime.getPackBuyWhitelistCount() <= 0 then
        if not isAutomatic then
            setStatus("Pilih minimal satu pack pada whitelist.", COLORS.warning)
        end
        State.lastPackBuyStatus = "no_whitelist"
        return false, "Pack whitelist kosong"
    end

    if State.packBuyPrestigePriority then
        local infoAge = os.clock() - (tonumber(State.prestigeInfoUpdatedAt) or 0)
        if not State.prestigeInfo or infoAge >= PACK_BUY_PRESTIGE_REFRESH_INTERVAL then
            local info, infoError = Runtime.fetchPrestigeInfo()
            if not info then
                State.lastPackBuyStatus = "waiting_prestige"
                State.lastPackBuyError = tostring(infoError or "Prestige info unavailable")
                State.nextAutoBuyPackAt = os.clock() + AUTO_BUY_PACK_RETRY_DELAY
                updateAutomationButtons()
                return false, State.lastPackBuyError
            end
        end
    end

    local buyState = Runtime.getPackBuyState()
    if buyState.blockedByPrestige then
        State.lastPackBuyStatus = buyState.prestigeInfoAvailable and "saving_prestige" or "waiting_prestige"
        State.lastPackBuyError = nil
        State.nextAutoBuyPackAt = os.clock() + AUTO_BUY_PACK_RETRY_DELAY
        updateAutomationButtons()

        if not isAutomatic then
            setStatus(
                buyState.prestigeInfoAvailable
                    and string.format(
                        "Auto Buy dijeda • simpan %s Coins untuk Prestige.",
                        formatCompactNumber(buyState.reserve or 0)
                    )
                    or "Auto Buy dijeda • menunggu Prestige info.",
                COLORS.warning
            )
        end

        return false, State.lastPackBuyStatus
    end

    local candidates = Runtime.getPackBuyCandidates(buyState.spendable)
    local selected = candidates[1]
    if not selected then
        State.lastPackBuyStatus = "waiting_budget"
        State.lastPackBuyError = nil
        State.nextAutoBuyPackAt = os.clock() + AUTO_BUY_PACK_RETRY_DELAY
        updateAutomationButtons()

        if not isAutomatic then
            setStatus("Belum ada pack whitelist yang dapat dibeli dari budget saat ini.", COLORS.warning)
        end

        return false, "Tidak ada pack yang affordable"
    end

    local affordableCount = math.floor((buyState.spendable or 0) / selected.cost)

    local count
    if requestedCount ~= nil then
        count = math.max(
            1,
            math.min(
                affordableCount,
                math.floor(tonumber(requestedCount) or 1)
            )
        )
    else
        count = math.max(
            1,
            math.min(affordableCount, AUTO_BUY_PACK_MAX_BATCH)
        )
    end

    if selected.pick then
        count = math.min(count, math.max(0, tonumber(selected.remaining) or 0))
    end

    if count <= 0 then
        State.lastPackBuyStatus = "limited"
        State.nextAutoBuyPackAt = os.clock() + AUTO_BUY_PACK_RETRY_DELAY
        return false, "Limit Pick Pack habis"
    end

    if not tryRediscoverNetworker() then
        return false, "Networker belum ditemukan"
    end

    State.buyingPacks = true
    State.lastPackBuyStatus = "buying"
    State.lastPackBuyError = nil
    State.nextAutoBuyPackAt = math.huge
    updateAutomationButtons()

    task.spawn(function()
        local purchased = 0
        local lastError = nil

        if selected.pick then
            for _ = 1, count do
                if not State.running or (isAutomatic and not State.autoBuyPacks) then
                    break
                end

                local response, errorMessage = callNetworkLoose("BuyPickPack", {
                    packTier = selected.tier,
                })

                if not response or errorMessage then
                    lastError = tostring(errorMessage or "BuyPickPack gagal")
                    break
                end

                purchased += 1
                task.wait(0.15)
            end
        else
            local response, errorMessage = callNetworkLoose("BuyPack", {
                packTier = selected.tier,
                count = count,
            })

            if response and not errorMessage then
                purchased = count
            else
                lastError = tostring(errorMessage or "BuyPack gagal")
            end
        end

        State.buyingPacks = false
        State.lastPackBuyAt = os.time()
        State.lastPackBuyTier = selected.tier
        State.lastPackBuyCount = purchased
        State.lastPackBuySpent = purchased * selected.cost
        State.lastPackBuyError = lastError
        State.lastPackBuyStatus = lastError and "error" or (purchased > 0 and "success" or "stopped")
        State.nextAutoBuyPackAt = os.clock()
            + (lastError and AUTO_BUY_PACK_RETRY_DELAY or AUTO_BUY_PACK_INTERVAL)
        State.packUiDirty = true
        State.uiRefreshRequested = true

        if purchased > 0 and State.autoOpenPacks then
            State.nextAutoOpenPackAt = 0
        end

        State.pendingStatus = {
            text = lastError
                and ("Buy Pack gagal: " .. lastError)
                or string.format(
                    "Bought %d× %s • spent %s Coins.",
                    purchased,
                    tostring(selected.label),
                    formatCompactNumber(purchased * selected.cost)
                ),
            color = lastError and COLORS.danger or COLORS.success,
        }
    end)

    return true
end

Runtime.getOwnedPacksSnapshot = function()
    local owned = Runtime.getData("Packs.Owned")
    local snapshot = {}

    if type(owned) ~= "table" then
        return snapshot
    end

    for tier, amount in pairs(owned) do
        local count = math.max(0, math.floor(tonumber(amount) or 0))
        if count > 0 then
            snapshot[tostring(tier)] = count
        end
    end

    return snapshot
end

Runtime.getNextOwnedPackTier = function(owned)
    if type(owned) ~= "table" then
        return nil
    end

    local packConfig = State.packConfig
    local order = packConfig and packConfig.Order
    if type(order) == "table" then
        for index = #order, 1, -1 do
            local tier = tostring(order[index])
            if (tonumber(owned[tier]) or 0) > 0 then
                return tier
            end
        end
    end

    local positionalOrder = packConfig and packConfig.PositionalOrder
    if type(positionalOrder) == "table" then
        for _, tierValue in pairs(positionalOrder) do
            local tier = tostring(tierValue)
            if (tonumber(owned[tier]) or 0) > 0 then
                return tier
            end
        end
    end

    for tier, amount in pairs(owned) do
        if (tonumber(amount) or 0) > 0 then
            return tostring(tier)
        end
    end

    return nil
end

Runtime.getPackTierConfig = function(tier)
    local packConfig = State.packConfig
    if not packConfig or type(packConfig.Get) ~= "function" then
        return nil
    end

    local success, result = pcall(packConfig.Get, tier)
    if success and type(result) == "table" then
        return result
    end

    return nil
end

Runtime.isPickPackTier = function(tier)
    local config = Runtime.getPackTierConfig(tier)
    if type(config) ~= "table" then
        return false
    end

    -- Referensi game hanya mengecek truthy/falsy, bukan harus boolean true.
    if config.pick ~= nil and config.pick ~= false then
        return true
    end

    local choiceCount = tonumber(config.pickCount or config.choices or config.choose)
    return choiceCount ~= nil and choiceCount > 1
end

Runtime.extractPickCards = function(response)
    if type(response) ~= "table" then
        return nil
    end

    local candidates = response.cards
        or response.choices
        or response.options
        or response.results

    if type(candidates) == "table" and next(candidates) ~= nil then
        return candidates
    end

    if #response > 0 then
        return response
    end

    return nil
end

Runtime.resolvePackChoiceCard = function(card, index)
    card = type(card) == "table" and card or {}

    local resolved = nil
    local cardResolve = State.cardResolve
    if cardResolve and type(cardResolve.Resolve) == "function" then
        local success, result = pcall(cardResolve.Resolve, card)
        if success and type(result) == "table" then
            resolved = result
        end
    end

    local baseCard = nil
    local database = State.playerCardDatabase
    if card.baseId ~= nil and database and type(database.GetById) == "function" then
        local success, result = pcall(database.GetById, card.baseId)
        if success and type(result) == "table" then
            baseCard = result
        end
    end

    local upgrade = tonumber(card.upgrade) or 0
    local rating = tonumber(resolved and resolved.rating)
        or tonumber(card.rating)
        or ((tonumber(baseCard and baseCard.rating) or 0) + upgrade)

    local rarity = resolved and resolved.rarity
        or card.rarity
        or (baseCard and getRarity(baseCard, rating))
        or "Unknown"

    return {
        index = index,
        card = card,
        name = tostring(
            (resolved and resolved.name)
                or card.name
                or (baseCard and baseCard.name)
                or ("Choice " .. tostring(index))
        ),
        rating = tonumber(rating) or 0,
        rarity = tostring(rarity),
        rank = rarityRank(rarity),
    }
end

Runtime.selectPackChoiceIndex = function(cards)
    if type(cards) ~= "table" or next(cards) == nil then
        return nil, nil
    end

    local mode = normalizePackPickMode(State.packPickMode)
    local best = nil

    for rawIndex, card in pairs(cards) do
        local index = tonumber(rawIndex)
        if index and type(card) == "table" then
            local candidate = Runtime.resolvePackChoiceCard(card, index)
            local better = best == nil

            if best ~= nil and mode == PACK_PICK_MODE_RARITY then
                better = candidate.rank > best.rank
                    or (candidate.rank == best.rank and candidate.rating > best.rating)
            elseif best ~= nil and mode == PACK_PICK_MODE_OVR then
                better = candidate.rating > best.rating
                    or (candidate.rating == best.rating and candidate.rank > best.rank)
            elseif best ~= nil then
                better = candidate.rank > best.rank
                    or (candidate.rank == best.rank and candidate.rating > best.rating)
            end

            if better then
                best = candidate
            end
        end
    end

    return best and best.index or nil, best
end

Runtime.getNextPickPackTier = function(owned)
    if type(owned) ~= "table" then
        return nil
    end

    for tier, amount in pairs(owned) do
        if (tonumber(amount) or 0) > 0 then
            local config = Runtime.getPackTierConfig(tier)
            if Runtime.isPickPackTier(tier) then
                return tostring(tier)
            end
        end
    end

    return nil
end

Runtime.openInstantPackBatch = function(count)
    count = math.clamp(math.floor(tonumber(count) or 0), 1, 100)
    local response, errorMessage = callNetwork("OpenOwnedPackBatch", {
        count = count,
    })

    if not response or errorMessage or type(response.results) ~= "table" then
        return false, errorMessage or "Instant batch gagal"
    end

    local logged = 0
    for _, card in ipairs(response.results) do
        if Runtime.appendPackSessionLog(card, "Instant Batch", "instant") then
            logged += 1
        end
    end

    return true, {
        count = #response.results,
        logged = logged,
        remaining = tonumber(response.remaining) or 0,
    }
end

Runtime.openOwnedPackTier = function(tier)
    local isPickPack = Runtime.isPickPackTier(tier)

    if not isPickPack then
        local response, errorMessage = callNetwork("AttemptOpenOwnedPack", {
            packTier = tier,
        })

        if not response or errorMessage then
            return false, errorMessage or "Pack gagal dibuka"
        end

        local resultCard = response.card
            or response.result
            or response.reward
            or response.playerCard

        if type(resultCard) ~= "table" then
            return false, "Server membuka pack tetapi card result tidak ditemukan"
        end

        return true, {
            kind = "normal",
            tier = tier,
            card = resultCard,
        }
    end

    local pickResponse, pickError = callNetwork("OpenPickPack", {
        packTier = tier,
    })

    local cards = Runtime.extractPickCards(pickResponse)
    if not pickResponse or pickError or type(cards) ~= "table" then
        return false, pickError or "Pilihan kartu tidak tersedia"
    end

    local selectedIndex, selectedCard = Runtime.selectPackChoiceIndex(cards)
    if not selectedIndex or not selectedCard then
        return false, "Tidak ada kartu yang dapat dipilih"
    end

    local resolvedResponse, resolveError = callNetwork("ResolvePick", {
        index = selectedIndex,
    })

    if not resolvedResponse or resolveError then
        return false, resolveError or "Pilihan kartu gagal dikonfirmasi"
    end

    local resultCard = resolvedResponse.card
        or resolvedResponse.result
        or resolvedResponse.reward
        or selectedCard.card

    State.lastPackPickAt = os.time()
    State.lastPackPickTier = tier
    State.lastPackPickIndex = selectedIndex
    State.lastPackPickCard = selectedCard
    State.packUiDirty = true

    return true, {
        kind = "pick",
        tier = tier,
        index = selectedIndex,
        selected = selectedCard,
        card = resultCard,
    }
end

Runtime.openOwnedPacksAutomatically = function(isAutomatic)
    if State.openingPacks then
        return false, "Auto Open Packs sedang diproses"
    end

    local packCount = Runtime.getOwnedPackCount()
    if packCount <= 0 then
        return false, "Tidak ada pack untuk dibuka"
    end

    if not tryRediscoverNetworker() then
        return false, "Networker belum ditemukan"
    end

    State.openingPacks = true
    State.lastPackOpenError = nil
    State.lastInstantPackFallback = nil
    State.lastPackOpenCount = 0
    State.lastPackPickCount = 0
    State.lastObservedPackCount = packCount
    updateAutomationButtons()

    task.spawn(function()
        local owned = Runtime.getOwnedPacksSnapshot()
        local openedCount = 0
        local pickCount = 0
        local lastError = nil
        local operationLimit = math.min(100, packCount)

        -- Pick Pack selalu diproses satu per satu agar pilihan 3 kartu tetap
        -- mengikuti mode Best Rarity / Best OVR.
        while openedCount < operationLimit do
            local pickTier = Runtime.getNextPickPackTier(owned)
            if not pickTier then
                break
            end

            local success, resultOrError = Runtime.openOwnedPackTier(pickTier)
            if not success then
                lastError = tostring(resultOrError or "Pick Pack gagal dibuka")
                break
            end

            openedCount += 1
            pickCount += 1
            local resultCard = resultOrError.card
                or (resultOrError.selected and resultOrError.selected.card)
            Runtime.appendPackSessionLog(
                resultCard,
                pickTier,
                "pick",
                resultOrError.index
            )
            owned[pickTier] = math.max(0, (tonumber(owned[pickTier]) or 1) - 1)
            task.wait(0.15)
        end

        -- Saat animasi native dipakai, Pick Pack sudah diselesaikan langsung agar
        -- mode pemilihan tetap bekerja. Pack biasa diteruskan ke overlay game.
        if not lastError and not State.skipPackAnimation and openedCount < operationLimit then
            local success, errorMessage = fireBusEvent("PacksInventoryOpen", {
                auto = true,
            })

            if not success then
                lastError = tostring(errorMessage or "Pack overlay gagal dibuka")
            else
                State.pendingStatus = {
                    text = string.format(
                        "%d Pick Pack dipilih otomatis. Pack biasa dilanjutkan lewat animasi game; log pack biasa memerlukan Skip Pack Animation.",
                        pickCount
                    ),
                    color = COLORS.warning,
                }
            end

            State.openingPacks = false
            State.lastPackOpenAt = os.clock()
            State.lastPackOpenCount = openedCount
            State.lastPackPickCount = pickCount
            State.lastPackOpenError = lastError
            State.nextAutoOpenPackAt = os.clock() + AUTO_PACK_RETRY_DELAY
            State.packUiDirty = true
            State.uiRefreshRequested = true
            return
        end

        local hasInstantPass = Runtime.getData("Passes.InstantOpen") == true
        if not lastError
            and State.instantPacks
            and openedCount < operationLimit
            and hasInstantPass
        then
            local requested = operationLimit - openedCount
            local success, batchResult = Runtime.openInstantPackBatch(requested)
            if success then
                openedCount += tonumber(batchResult.count) or 0
                if (tonumber(batchResult.remaining) or 0) <= 0 then
                    owned = {}
                else
                    task.wait(0.2)
                    owned = Runtime.getOwnedPacksSnapshot()
                end
            else
                lastError = tostring(batchResult or "Instant batch gagal")
            end
        elseif State.instantPacks and not hasInstantPass then
            State.lastInstantPackFallback = "Passes.InstantOpen tidak aktif"
        end

        -- Fallback normal/direct untuk semua pack yang belum dibuka.
        if not lastError and openedCount < operationLimit then
            for _ = openedCount + 1, operationLimit do
                if not State.running then
                    break
                end

                local tier = Runtime.getNextOwnedPackTier(owned)
                if not tier then
                    break
                end

                local success, resultOrError = Runtime.openOwnedPackTier(tier)
                if not success then
                    lastError = tostring(resultOrError or "Pack gagal dibuka")
                    break
                end

                openedCount += 1
                if type(resultOrError) == "table" and resultOrError.kind == "pick" then
                    pickCount += 1
                end

                local resultCard = type(resultOrError) == "table"
                    and (resultOrError.card
                        or (resultOrError.selected and resultOrError.selected.card))
                    or nil
                Runtime.appendPackSessionLog(
                    resultCard,
                    tier,
                    type(resultOrError) == "table" and resultOrError.kind or "normal",
                    type(resultOrError) == "table" and resultOrError.index or nil
                )

                owned[tier] = math.max(0, (tonumber(owned[tier]) or 1) - 1)
                task.wait(0.15)
            end
        end

        State.openingPacks = false
        State.lastPackOpenAt = os.clock()
        State.lastPackOpenCount = openedCount
        State.lastPackPickCount = pickCount
        State.lastPackOpenError = lastError
        State.nextAutoOpenPackAt = os.clock() + AUTO_PACK_RETRY_DELAY
        State.packUiDirty = true
        State.uiRefreshRequested = true

        if lastError then
            State.pendingStatus = {
                text = string.format(
                    "Auto Open berhenti setelah %d pack: %s",
                    openedCount,
                    lastError
                ),
                color = COLORS.warning,
            }
        elseif not isAutomatic then
            State.pendingStatus = {
                text = string.format(
                    "%d pack dibuka • %d Pick Pack • %s.",
                    openedCount,
                    pickCount,
                    State.instantPacks and hasInstantPass and "Instant" or "Direct"
                ),
                color = COLORS.success,
            }
        end
    end)

    return true
end

local function ensureMatchPlaybackListeners()
    if State.matchEventListenersConnected then
        return true
    end

    if not tryRediscoverEventBus() then
        return false
    end

    local eventBus = State.eventBus
    if type(eventBus.Connect) ~= "function" then
        return false
    end

    local connectedAny = false

    local successRequested, requestedConnection = pcall(eventBus.Connect, eventBus, "MatchPlaybackRequested", function()
        -- Callback Signal game dapat berjalan pada free thread. Hanya ubah state Lua;
        -- jangan memanggil WindUI/Instance dari callback ini.
        State.matchPlaybackActive = true
        State.nextAutoPlayEnsureAt = os.clock() + AUTO_PLAY_ENSURE_DELAY
        State.uiRefreshRequested = true
    end)
    if successRequested and requestedConnection then
        addConnection(requestedConnection)
        connectedAny = true
    end

    local successEnded, endedConnection = pcall(eventBus.Connect, eventBus, "MatchPlaybackEnded", function()
        State.matchPlaybackActive = false
        State.nextWorldCupCheckAt = 0
        State.nextAutoPlayEnsureAt = os.clock() + 1
        State.nextAutoEquipBestAt = 0
        State.uiRefreshRequested = true
    end)
    if successEnded and endedConnection then
        addConnection(endedConnection)
        connectedAny = true
    end

    State.matchEventListenersConnected = connectedAny
    return connectedAny
end

local function waitForAutoMatchValue(expectedValue, timeoutSeconds)
    local deadline = os.clock() + math.max(0, tonumber(timeoutSeconds) or 0)
    repeat
        local current = Runtime.getData("Settings.AutoMatch")
        if current == expectedValue then
            return true
        end
        task.wait(0.1)
    until os.clock() >= deadline or not State.running

    return Runtime.getData("Settings.AutoMatch") == expectedValue
end

local function runWithAutoMatchPaused(actionCallback)
    if State.autoMatchTransaction or State.settingAutoMatch then
        return nil, "Auto Play sedang diproses"
    end
    if State.matchPlaybackActive then
        return nil, "Match sedang berlangsung"
    end

    local desiredAutoMatch = State.autoMatch == true
        or Runtime.getData("Settings.AutoMatch") == true
    local paused = false
    State.autoMatchTransaction = true
    State.autoMatchSyncIgnoreUntil = os.clock() + 12
    updateAutomationButtons()

    if desiredAutoMatch then
        local pauseResponse, pauseError = callNetworkLoose("SetAutoMatch", {enabled = false})
        if not pauseResponse then
            State.autoMatchTransaction = false
            updateAutomationButtons()
            return nil, "Gagal pause Auto Play: " .. tostring(pauseError)
        end
        paused = true
        waitForAutoMatchValue(false, AUTO_MATCH_PAUSE_TIMEOUT)
    end

    local actionResponse, actionError = actionCallback()

    local restoreError = nil
    if paused then
        local restored, restoreWarning = requestAutoPlayStart()
        if restored then
            State.autoMatch = true
            PersistentConfig.autoPlay = true
            PersistentConfig.autoMatch = true
            State.autoMatchPendingSync = false
            State.autoMatchSyncIgnoreUntil = os.clock() + 5
            restoreError = restoreWarning
        else
            restoreError = restoreWarning
        end
    end

    State.autoMatchTransaction = false
    updateAutomationButtons()

    if restoreError then
        -- Playback warning tidak membatalkan action, tetapi tampilkan agar mudah
        -- didiagnosis. Retry hanya diperlukan bila setting server belum aktif.
        local serverEnabled = Runtime.getData("Settings.AutoMatch") == true
        if not serverEnabled then
            State.autoMatchPendingSync = true
            State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY
            return actionResponse, actionError
                or ("Action selesai, tetapi gagal memulai kembali Auto Play: "
                    .. tostring(restoreError))
        end
    end

    return actionResponse, actionError
end

local function equipBestEleven(isAutomatic)
    if State.equippingBest or State.collecting or State.loaning or State.prestiging or State.joiningWorldCup then
        return false, "Automation lain sedang berjalan"
    end
    if State.matchPlaybackActive then
        State.nextAutoEquipBestAt = os.clock() + AUTO_EQUIP_BEST_RETRY_DELAY
        return false, "Match sedang berlangsung"
    end
    if State.autoMatchTransaction or State.settingAutoMatch then
        State.nextAutoEquipBestAt = os.clock() + AUTO_EQUIP_BEST_RETRY_DELAY
        return false, "Auto Play sedang diproses"
    end

    State.equippingBest = true
    State.autoEquipBestPasses = 0
    State.autoEquipBestChanged = false
    State.lastEquipBestResult = "running"
    State.autoMatchTransaction = true
    State.autoMatchSyncIgnoreUntil = os.clock() + 30
    updateAutomationButtons()

    task.spawn(function()
        local shouldResumeAutoPlay = State.autoMatch == true
            or Runtime.getData("Settings.AutoMatch") == true
        local pausedAutoPlay = false
        local response = true
        local errorMessage = nil
        local stable = false
        local changedAny = false
        local passes = 0

        if shouldResumeAutoPlay then
            local pauseResponse, pauseError = callNetworkLoose(
                "SetAutoMatch",
                {enabled = false}
            )
            if not pauseResponse then
                response = nil
                errorMessage = "Gagal pause Auto Play: " .. tostring(pauseError)
            else
                pausedAutoPlay = true
                waitForAutoMatchValue(false, AUTO_MATCH_PAUSE_TIMEOUT)
            end
        end

        if response then
            local previousLineupSignature = getStartingElevenSignature()
            local seenSignatures = {[previousLineupSignature] = true}

            for pass = 1, AUTO_EQUIP_BEST_MAX_PASSES do
                if not State.running or not State.autoEquipBest then
                    break
                end

                passes = pass
                State.autoEquipBestPasses = pass
                updateAutomationButtons()

                local passResponse, passError = callNetworkLoose("AutoFillBestEleven")
                if not passResponse then
                    response = nil
                    errorMessage = passError or "AutoFillBestEleven gagal"
                    break
                end

                local currentLineupSignature, changed = waitForStartingElevenChange(
                    previousLineupSignature,
                    AUTO_EQUIP_BEST_SETTLE_TIMEOUT
                )

                if not changed then
                    stable = true
                    break
                end

                changedAny = true
                State.autoEquipBestChanged = true

                -- Jika signature kembali berulang, lineup sudah berhenti bergerak.
                if seenSignatures[currentLineupSignature] then
                    stable = true
                    break
                end

                seenSignatures[currentLineupSignature] = true
                previousLineupSignature = currentLineupSignature
                task.wait(0.15)
            end

            if response and not stable and passes >= AUTO_EQUIP_BEST_MAX_PASSES then
                -- Batas pengaman. Pass berikutnya akan dicoba hanya bila signature
                -- koleksi/lineup berubah lagi, sehingga tidak membuat loop tanpa akhir.
                stable = true
            end
        end

        -- Toggle Auto Equip Best tetap ON. Auto Play hanya dilanjutkan bila toggle
        -- Auto Play masih ON; bila pengguna mematikannya selama proses, jangan restart.
        local restoreWarning = nil
        if pausedAutoPlay and State.autoMatch then
            local restored, warning = requestAutoPlayStart()
            if restored then
                PersistentConfig.autoPlay = true
                PersistentConfig.autoMatch = true
                State.autoMatchPendingSync = false
                State.autoMatchSyncIgnoreUntil = os.clock() + 5
                restoreWarning = warning
            else
                restoreWarning = warning or "Gagal memulai kembali Auto Play"
                State.autoMatchPendingSync = true
                State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY
            end
        end

        State.equippingBest = false
        State.autoMatchTransaction = false
        State.autoEquipBestPasses = passes
        State.autoEquipBestChanged = changedAny
        State.nextAutoEquipBestAt = os.clock() + AUTO_EQUIP_BEST_RETRY_DELAY

        if response then
            State.lastEquipBestSignature = Runtime.getSquadEquipSignature()
            State.lastEquipBestAt = os.time()
            State.lastEquipBestResult = changedAny and "updated" or "already_best"

            local resumeText = shouldResumeAutoPlay
                and " • Auto Play dilanjutkan."
                or "."

            if changedAny then
                setStatus(
                    string.format(
                        "Equip Best selesai • lineup diperbarui dan stabil setelah %d siklus%s",
                        math.max(passes, 1),
                        resumeText
                    ),
                    COLORS.success
                )
            else
                setStatus(
                    "Equip Best selesai • tidak ada kartu OVR/rarity lebih tinggi yang dapat mengganti lineup"
                        .. resumeText,
                    COLORS.success
                )
            end

            if restoreWarning then
                setStatus(
                    "Equip Best selesai, tetapi pemulihan Auto Play memberi peringatan: "
                        .. tostring(restoreWarning),
                    COLORS.warning
                )
            end

            task.wait(0.35)
            refreshUI(true)
        else
            State.lastEquipBestResult = "error"
            if not isAutomatic then
                setStatus("Equip Best gagal: " .. tostring(errorMessage), COLORS.danger)
            end
        end

        updateAutomationButtons()
    end)

    return true
end

local PACK_NAME_TOKENS = {
    "pack",
    "reward",
    "gift",
    "crate",
    "claim",
    "pickup",
    "drop",
    "card",
    "playercard",
    "collectible",
}

local function lowerText(value)
    return string.lower(tostring(value or ""))
end

local function textHasAnyToken(value, tokens)
    local textValue = lowerText(value)
    for _, token in ipairs(tokens) do
        if string.find(textValue, token, 1, true) then
            return true
        end
    end
    return false
end

local function getWorldPosition(instance)
    if typeof(instance) ~= "Instance" then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        local success, pivot = pcall(instance.GetPivot, instance)
        if success then
            return pivot.Position
        end
    end

    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function ownerMatchesLocalPlayer(instance)
    if typeof(instance) ~= "Instance" then
        return nil
    end

    local numericAttributes = {"OwnerUserId", "UserId", "OwnerId", "PlayerUserId"}
    for _, attributeName in ipairs(numericAttributes) do
        local value = instance:GetAttribute(attributeName)
        if value ~= nil then
            return tonumber(value) == LocalPlayer.UserId
        end
    end

    local textAttributes = {"Owner", "Player", "Username", "PlayerName"}
    for _, attributeName in ipairs(textAttributes) do
        local value = instance:GetAttribute(attributeName)
        if value ~= nil then
            local normalized = lowerText(value)
            return normalized == lowerText(LocalPlayer.Name)
                or normalized == lowerText(LocalPlayer.DisplayName)
        end
    end

    for _, childName in ipairs({"Owner", "Player", "OwnerPlayer"}) do
        local child = instance:FindFirstChild(childName)
        if child then
            if child:IsA("ObjectValue") and child.Value ~= nil then
                return child.Value == LocalPlayer
            elseif child:IsA("StringValue") then
                return lowerText(child.Value) == lowerText(LocalPlayer.Name)
            elseif child:IsA("IntValue") or child:IsA("NumberValue") then
                return tonumber(child.Value) == LocalPlayer.UserId
            end
        end
    end

    return nil
end

local function getWorldFolder()
    return Workspace:FindFirstChild("World")
end

Runtime.findOwnedPlot = function(forceScan)
    if not forceScan
        and State.cachedOwnedPlot
        and State.cachedOwnedPlot.Parent
        and os.clock() - State.lastOwnedPlotScanAt < 8
    then
        return State.cachedOwnedPlot
    end

    State.lastOwnedPlotScanAt = os.clock()
    State.cachedOwnedPlot = nil
    State.cachedOwnedPlotSpawn = nil

    local world = getWorldFolder()
    local plots = world and world:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    local username = lowerText(LocalPlayer.Name)
    for index = 1, 10 do
        local plot = plots:FindFirstChild("Plot" .. index)
        if plot and (plot:IsA("Model") or plot:IsA("Folder")) then
            local ownerName = plot:GetAttribute("OwnerName")
            if ownerName ~= nil and lowerText(ownerName) == username then
                State.cachedOwnedPlot = plot
                State.cachedPlayerBase = plot
                State.lastPlayerBaseScanAt = os.clock()
                return plot
            end
        end
    end

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") or plot:IsA("Folder") then
            local ownerName = plot:GetAttribute("OwnerName")
            if ownerName ~= nil and lowerText(ownerName) == username then
                State.cachedOwnedPlot = plot
                State.cachedPlayerBase = plot
                State.lastPlayerBaseScanAt = os.clock()
                return plot
            end
        end
    end

    return nil
end

Runtime.getOwnedPlotSpawn = function(forceScan)
    if not forceScan
        and State.cachedOwnedPlotSpawn
        and State.cachedOwnedPlotSpawn.Parent
    then
        return State.cachedOwnedPlotSpawn
    end

    local plot = Runtime.findOwnedPlot(forceScan)
    if not plot then
        return nil
    end

    local spawnPart = plot:FindFirstChild("Spawn", true)
    if spawnPart and spawnPart:IsA("BasePart") then
        State.cachedOwnedPlotSpawn = spawnPart
        return spawnPart
    end

    return nil
end

Runtime.getConveyorParts = function()
    local world = getWorldFolder()
    local conveyorModel = world and world:FindFirstChild("Conveyor")
    local parts = {}
    local conveyorPartName = " Animed Convoyor" -- Ada satu spasi di awal nama.

    if not conveyorModel then
        return parts
    end

    for _, descendant in ipairs(conveyorModel:GetDescendants()) do
        if descendant:IsA("BasePart")
            and descendant.Name == conveyorPartName
        then
            parts[#parts + 1] = descendant
        end
    end

    table.sort(parts, function(a, b)
        return a:GetFullName() < b:GetFullName()
    end)

    return parts
end

Runtime.getConveyorTarget = function()
    local parts = Runtime.getConveyorParts()
    if #parts == 0 then
        return nil
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return parts[1]
    end

    local nearest = parts[1]
    local nearestDistance = (nearest.Position - root.Position).Magnitude

    for index = 2, #parts do
        local part = parts[index]
        local distance = (part.Position - root.Position).Magnitude
        if distance < nearestDistance then
            nearest = part
            nearestDistance = distance
        end
    end

    return nearest
end

Runtime.isCharacterOnConveyor = function(rootOrPosition)
    local root = nil
    local position = nil

    if typeof(rootOrPosition) == "Instance" and rootOrPosition:IsA("BasePart") then
        root = rootOrPosition
        position = rootOrPosition.Position
    elseif typeof(rootOrPosition) == "Vector3" then
        position = rootOrPosition
        local character = LocalPlayer.Character
        root = character and character:FindFirstChild("HumanoidRootPart") or nil
    else
        return false, nil
    end

    local character = root and root.Parent or LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootHalfHeight = root and root.Size.Y * 0.5 or 1
    local hipHeight = humanoid and humanoid.HipHeight or 2

    -- Periksa posisi kaki, bukan pusat HumanoidRootPart. Versi sebelumnya
    -- menambahkan toleransi X/Z sebesar 4 stud sehingga player yang sudah
    -- berada di samping conveyor masih dianggap berada di atas conveyor.
    local feetPosition = position - Vector3.new(0, hipHeight + rootHalfHeight - 0.25, 0)

    for _, part in ipairs(Runtime.getConveyorParts()) do
        local localFeet = part.CFrame:PointToObjectSpace(feetPosition)
        local halfSize = part.Size * 0.5
        local xInset = math.min(0.75, halfSize.X * 0.15)
        local zInset = math.min(0.75, halfSize.Z * 0.15)
        local xLimit = math.max(0.05, halfSize.X - xInset)
        local zLimit = math.max(0.05, halfSize.Z - zInset)
        local topSurface = halfSize.Y

        if math.abs(localFeet.X) <= xLimit
            and math.abs(localFeet.Z) <= zLimit
            and localFeet.Y >= topSurface - 2
            and localFeet.Y <= topSurface + 2.5
        then
            return true, part
        end
    end

    return false, nil
end

local function getInstanceCFrame(instance)
    if typeof(instance) ~= "Instance" then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.CFrame
    end

    if instance:IsA("Model") then
        local success, pivot = pcall(instance.GetPivot, instance)
        if success then
            return pivot
        end
    end

    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

local function getCharacterRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil
    end

    return character:FindFirstChild("HumanoidRootPart"), character
end

Runtime.releaseMovementRoot = function()
    local root = State.movementRoot
    if root and root.Parent then
        pcall(function()
            root.Anchored = State.movementRootWasAnchored == true
        end)
    end

    State.movementRoot = nil
    State.movementRootWasAnchored = nil
end

local function adoptMovementRoot(root)
    if State.movementRoot == root then
        return
    end

    Runtime.releaseMovementRoot()
    State.movementRoot = root
    State.movementRootWasAnchored = root.Anchored == true
end

local function holdCharacterAt(targetCFrame)
    if typeof(targetCFrame) ~= "CFrame" then
        return false
    end

    local root = getCharacterRoot()
    if not root then
        return false
    end

    adoptMovementRoot(root)

    local success = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Anchored = true
        root.CFrame = targetCFrame
    end)

    return success
end

local function teleportCharacter(targetCFrame, holdDuration, updateLockPosition, shouldHold)
    if typeof(targetCFrame) ~= "CFrame" then
        return false, "Target teleport tidak valid"
    end

    local root, character = getCharacterRoot()
    if not root or not character then
        return false, "Character atau HumanoidRootPart belum tersedia"
    end

    Runtime.releaseMovementRoot()

    if shouldHold == true then
        State.movementOverrideCFrame = targetCFrame
        State.movementOverrideUntil = os.clock()
            + math.max(tonumber(holdDuration) or MOVEMENT_OVERRIDE_DURATION, 0)
    else
        State.movementOverrideCFrame = nil
        State.movementOverrideUntil = 0
    end

    local success, errorMessage = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(targetCFrame)
        root.Anchored = false
    end)

    if not success then
        return false, tostring(errorMessage)
    end

    if updateLockPosition and State.lockPosition then
        State.lockedCFrame = targetCFrame
    end

    if shouldHold == true then
        holdCharacterAt(targetCFrame)
    end

    return true
end

Runtime.teleportBackToBase = function(isAutomatic)
    local spawnPart = Runtime.getOwnedPlotSpawn(true)
    if not spawnPart then
        return false, "Plot dengan OwnerName " .. tostring(LocalPlayer.Name) .. " atau part Spawn tidak ditemukan"
    end

    if not isAutomatic and State.autoConveyor and Runtime.setAutoConveyorEnabled then
        Runtime.setAutoConveyorEnabled(false, false)
    end

    local targetCFrame = spawnPart.CFrame * CFrame.new(0, BASE_TELEPORT_HEIGHT, 0)
    local success, errorMessage = teleportCharacter(
        targetCFrame,
        0,
        false,
        false
    )

    if success then
        State.lastBaseTeleportAt = os.time()
        if not isAutomatic then
            setStatus("Berhasil teleport ke base sendiri: " .. tostring(spawnPart.Parent.Name) .. ".Spawn", COLORS.success)
        end
        updateAutomationButtons()
    elseif not isAutomatic then
        setStatus("Back to Base gagal: " .. tostring(errorMessage), COLORS.danger)
    end

    return success, errorMessage
end

Runtime.teleportToConveyor = function(isAutomatic)
    local conveyorPart = Runtime.getConveyorTarget()
    if not conveyorPart then
        local errorMessage = 'Part " Animed Convoyor" di Workspace.World.Conveyor tidak ditemukan'
        if not isAutomatic then
            setStatus(errorMessage, COLORS.warning)
        end
        return false, errorMessage
    end

    local targetCFrame = conveyorPart.CFrame
        * CFrame.new(0, conveyorPart.Size.Y * 0.5 + CONVEYOR_TELEPORT_HEIGHT, 0)

    local success, errorMessage = teleportCharacter(targetCFrame, 0, false, false)
    if success then
        State.lastConveyorTeleportAt = os.time()
        State.lastConveyorRecoveryAt = os.clock()
        State.nextConveyorCheckAt = os.clock() + 0.4

        if not isAutomatic then
            setStatus(
                "Berhasil teleport ke " .. conveyorPart:GetFullName() .. ".",
                COLORS.success
            )
        end
    elseif not isAutomatic then
        setStatus("Teleport Conveyor gagal: " .. tostring(errorMessage), COLORS.danger)
    end

    updateAutomationButtons()
    return success, errorMessage
end

Runtime.restorePlayerCollisions = function()
    for part, originalCanCollide in pairs(State.playerCollisionStates) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = originalCanCollide == true
            end)
        end
    end

    table.clear(State.playerCollisionStates)
end

Runtime.applyAntiPlayerCollision = function()
    if not State.lockPosition then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character then
                for _, descendant in ipairs(character:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        if State.playerCollisionStates[descendant] == nil then
                            State.playerCollisionStates[descendant] = descendant.CanCollide == true
                        end

                        if descendant.CanCollide then
                            pcall(function()
                                descendant.CanCollide = false
                            end)
                        end
                    end
                end
            end
        end
    end
end

Runtime.setLockPositionEnabled = function(enabled, announce)
    State.lockPosition = enabled == true
    PersistentConfig.lockPosition = State.lockPosition
    State.lockedCFrame = nil
    State.movementOverrideCFrame = nil
    State.movementOverrideUntil = 0
    Runtime.releaseMovementRoot()

    if State.lockPosition then
        Runtime.applyAntiPlayerCollision()
    else
        Runtime.restorePlayerCollisions()
    end

    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.lockPosition
                and "Anti Player Collision aktif. Player lain tidak dapat mendorongmu; movement dan conveyor tetap normal."
                or "Anti Player Collision dimatikan. Collision player lain dipulihkan.",
            State.lockPosition and COLORS.success or COLORS.muted
        )
    end

    return State.lockPosition
end

Runtime.setAutoConveyorEnabled = function(enabled, announce)
    State.autoConveyor = enabled == true
    PersistentConfig.autoConveyor = State.autoConveyor
    State.movementOverrideUntil = 0
    State.movementOverrideCFrame = nil
    State.nextConveyorCheckAt = 0
    State.conveyorOutsideSince = nil
    Runtime.releaseMovementRoot()

    if State.autoConveyor then
        Runtime.teleportToConveyor(true)
    end

    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.autoConveyor
                and "Auto Conveyor aktif. Movement tetap normal; jika keluar dari Animed Convoyor, player diteleport kembali."
                or "Auto Conveyor dimatikan.",
            State.autoConveyor and COLORS.success or COLORS.muted
        )
    end

    return State.autoConveyor
end

Runtime.tryMouseMoveRelative = function()
    local mover = nil

    if type(Environment) == "table" then
        mover = Environment.mousemoverel
            or Environment.mouse_move_relative
            or Environment.mouserel
    end

    if type(mover) ~= "function" and type(mousemoverel) == "function" then
        mover = mousemoverel
    end

    if type(mover) ~= "function" then
        return false, "mousemoverel unavailable"
    end

    local success, errorMessage = pcall(function()
        mover(1, 0)
        task.wait(0.03)
        mover(-1, 0)
    end)

    return success, success and nil or tostring(errorMessage)
end

Runtime.tryVirtualInputMouse = function()
    local manager = Runtime.virtualInputManager
    if not manager then
        return false, "VirtualInputManager unavailable"
    end

    local success, errorMessage = pcall(function()
        local position = UserInputService:GetMouseLocation()
        manager:SendMouseMoveEvent(position.X + 1, position.Y, game)
        task.wait(0.03)
        manager:SendMouseMoveEvent(position.X, position.Y, game)
    end)

    return success, success and nil or tostring(errorMessage)
end

Runtime.tryVirtualInputKey = function()
    local manager = Runtime.virtualInputManager
    if not manager then
        return false, "VirtualInputManager unavailable"
    end

    local success, errorMessage = pcall(function()
        manager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
        task.wait(0.04)
        manager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
    end)

    return success, success and nil or tostring(errorMessage)
end

Runtime.tryVirtualUser = function()
    local virtualUser = Runtime.virtualUser
    if not virtualUser then
        return false, "VirtualUser unavailable"
    end

    local camera = Workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or CFrame.new()
    local point = Vector2.new(0, 0)

    local success, errorMessage = pcall(function()
        virtualUser:CaptureController()

        local clicked = pcall(function()
            virtualUser:ClickButton2(point)
        end)

        if not clicked then
            virtualUser:Button2Down(point, cameraCFrame)
            task.wait(0.06)
            virtualUser:Button2Up(point, cameraCFrame)
        end
    end)

    return success, success and nil or tostring(errorMessage)
end

Runtime.preventIdleKick = function(source)
    if not State.running or not State.antiAfk then
        return false, "Anti AFK disabled"
    end

    if State.antiAfkBusy then
        return false, "Anti AFK pulse already running"
    end

    State.antiAfkBusy = true

    local successfulMethods = {}
    local errors = {}

    local methods = {
        {"MouseRel", Runtime.tryMouseMoveRelative},
        {"VIM Mouse", Runtime.tryVirtualInputMouse},
        {"VirtualUser", Runtime.tryVirtualUser},
        {"VIM Key", Runtime.tryVirtualInputKey},
    }

    for _, method in ipairs(methods) do
        local name = method[1]
        local callback = method[2]
        local success, errorMessage = callback()

        if success then
            successfulMethods[#successfulMethods + 1] = name
        elseif errorMessage then
            errors[#errors + 1] = name .. ": " .. tostring(errorMessage)
        end
    end

    State.antiAfkBusy = false
    State.nextAntiAfkPulseAt = os.clock() + (tonumber(State.antiAfkInterval) or 45)

    if #successfulMethods > 0 then
        State.antiAfkCount += 1
        State.lastAntiAfkAt = os.time()
        State.antiAfkMethod = table.concat(successfulMethods, " + ")
        State.lastAntiAfkError = #errors > 0 and table.concat(errors, " | ") or nil
        State.uiRefreshRequested = true
        return true
    end

    State.antiAfkMethod = "FAILED"
    State.lastAntiAfkError = #errors > 0 and table.concat(errors, " | ")
        or "No supported virtual input method"
    State.uiRefreshRequested = true

    return false, State.lastAntiAfkError
end

Runtime.setAntiAfkEnabled = function(enabled, announce)
    State.antiAfk = enabled == true
    PersistentConfig.antiAfk = State.antiAfk
    State.nextAntiAfkPulseAt = 0

    if not State.antiAfk then
        State.antiAfkMethod = "disabled"
        State.lastAntiAfkError = nil
    else
        task.defer(function()
            if State.running and State.antiAfk then
                Runtime.preventIdleKick("toggle")
            end
        end)
    end

    requestConfigSave()
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.antiAfk
                and "Anti AFK aktif. Input keep-alive langsung dites dan dikirim berkala."
                or "Anti AFK dinonaktifkan.",
            State.antiAfk and COLORS.success or COLORS.muted
        )
    end

    return State.antiAfk
end

addConnection(LocalPlayer.Idled:Connect(function()
    State.nextAntiAfkPulseAt = 0

    task.spawn(function()
        Runtime.preventIdleKick("Idled")
    end)
end))

addConnection(RunService.Heartbeat:Connect(function()
    if not State.running then
        return
    end

    local now = os.clock()

    -- Proaktif: tidak menunggu LocalPlayer.Idled karena event tersebut tidak
    -- selalu diteruskan oleh semua executor.
    if State.antiAfk
        and not State.antiAfkBusy
        and now >= State.nextAntiAfkPulseAt
    then
        State.nextAntiAfkPulseAt = now + (tonumber(State.antiAfkInterval) or 45)

        task.spawn(function()
            Runtime.preventIdleKick("periodic")
        end)
    end

    if State.lockPosition and now - State.lastAntiCollisionSweepAt >= 0.25 then
        State.lastAntiCollisionSweepAt = now
        Runtime.applyAntiPlayerCollision()
    elseif not State.lockPosition and next(State.playerCollisionStates) ~= nil then
        Runtime.restorePlayerCollisions()
    end

    -- Jangan biarkan kegagalan collector menahan recovery conveyor selamanya.
    if State.pickingSpawnedPacks
        and State.packPickupStartedAt > 0
        and now - State.packPickupStartedAt > 10
    then
        State.pickingSpawnedPacks = false
        State.packPickupStartedAt = 0
        State.nextConveyorCheckAt = 0
    end

    if State.autoConveyor
        and not State.pickingSpawnedPacks
        and now >= State.nextConveyorCheckAt
    then
        State.nextConveyorCheckAt = now + 0.15

        local root = getCharacterRoot()
        if root then
            local onConveyor = Runtime.isCharacterOnConveyor(root)

            if onConveyor then
                State.conveyorOutsideSince = nil
            else
                State.conveyorOutsideSince = State.conveyorOutsideSince or now

                -- Grace singkat mencegah teleport palsu ketika melewati sambungan
                -- empat part conveyor yang sedang bergerak.
                if now - State.conveyorOutsideSince >= 0.45
                    and now - State.lastConveyorRecoveryAt >= 0.9
                then
                    State.lastConveyorRecoveryAt = now
                    State.conveyorOutsideSince = nil
                    Runtime.teleportToConveyor(true)
                end
            end
        else
            State.conveyorOutsideSince = nil
        end
    end

    -- Fitur movement baru tidak meng-anchor karakter. Lepaskan sisa anchor dari
    -- build lama atau teleport sementara.
    if State.movementRoot then
        Runtime.releaseMovementRoot()
    end
end))

addConnection(LocalPlayer.CharacterAdded:Connect(function()
    Runtime.releaseMovementRoot()
    State.lockedCFrame = nil
    State.nextConveyorCheckAt = 0
    State.conveyorOutsideSince = nil

    task.delay(0.75, function()
        if not State.running then
            return
        end

        if State.lockPosition then
            Runtime.applyAntiPlayerCollision()
        end

        if State.autoConveyor then
            Runtime.teleportToConveyor(true)
        end
    end)
end))

local function findLocalPlayerBase(forceScan)
    local exactPlot = Runtime.findOwnedPlot(forceScan)
    if exactPlot then
        return exactPlot
    end

    if not forceScan
        and State.cachedPlayerBase
        and State.cachedPlayerBase.Parent
        and os.clock() - State.lastPlayerBaseScanAt < 12
    then
        return State.cachedPlayerBase
    end

    State.lastPlayerBaseScanAt = os.clock()
    State.cachedPlayerBase = nil

    local bestCandidate = nil
    local bestScore = -math.huge
    local playerName = lowerText(LocalPlayer.Name)
    local userIdText = tostring(LocalPlayer.UserId)

    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("Model") or instance:IsA("Folder") then
            local name = lowerText(instance.Name)
            local ownerMatch = ownerMatchesLocalPlayer(instance)
            if ownerMatch ~= false then
                local score = 0
                if ownerMatch == true then
                    score += 100
                end
                if string.find(name, playerName, 1, true) then
                    score += 40
                end
                if string.find(name, userIdText, 1, true) then
                    score += 35
                end
                if string.find(name, "base", 1, true)
                    or string.find(name, "plot", 1, true)
                    or string.find(name, "club", 1, true)
                    or string.find(name, "house", 1, true)
                then
                    score += 25
                end

                if score > bestScore and getWorldPosition(instance) then
                    bestScore = score
                    bestCandidate = instance
                end
            end
        end
    end

    if bestScore >= 25 then
        State.cachedPlayerBase = bestCandidate
    end

    return State.cachedPlayerBase
end

local function isLikelyPackRoot(instance)
    return typeof(instance) == "Instance"
        and instance:IsA("BasePart")
        and instance.Name == "PackDrop"
        and instance.Parent == Workspace
end

local function findPackRoot(instance)
    if isLikelyPackRoot(instance) then
        return instance
    end

    return nil
end

Runtime.scanSpawnedPackCandidates = function(forceScan)
    local now = os.clock()
    if not forceScan and now - State.lastSpawnedPackScanAt < SPAWNED_PACK_SCAN_INTERVAL then
        return State.spawnedPackCandidates
    end

    State.lastSpawnedPackScanAt = now

    local character = LocalPlayer.Character
    local playerBase = findLocalPlayerBase(false)
    local baseSpawn = Runtime.getOwnedPlotSpawn(false)
    local basePosition = baseSpawn and baseSpawn.Position or (playerBase and getWorldPosition(playerBase) or nil)
    local candidates = {}
    local seen = {}

    local function consider(instance)
        if not isLikelyPackRoot(instance) then
            return
        end

        local packRoot = findPackRoot(instance)
        if not packRoot or seen[packRoot] then
            return
        end

        -- Object yang tetap ada setelah beberapa sentuhan biasanya dekorasi
        -- atau bukan collectible. Abaikan agar tidak menyebabkan teleport loop.
        if (State.packInteractionAttempts[packRoot] or 0) >= 3 then
            return
        end

        local ownerMatch = ownerMatchesLocalPlayer(packRoot)
        if ownerMatch == false then
            return
        end

        local position = getWorldPosition(packRoot) or getWorldPosition(instance)
        if not position then
            return
        end

        if character and packRoot:IsDescendantOf(character) then
            return
        end

        local insideBase = playerBase and packRoot:IsDescendantOf(playerBase)
        local nearBase = basePosition and (position - basePosition).Magnitude <= SPAWNED_PACK_RADIUS

        -- Hanya object di sekitar plot sendiri yang dihitung. Menghapus fallback
        -- nearCharacter mencegah object bernama card/pack di tempat lain memicu
        -- teleport ke base terus-menerus.
        if not insideBase and not nearBase then
            return
        end

        seen[packRoot] = true
        candidates[#candidates + 1] = {
            root = packRoot,
            source = instance,
            position = position,
        }
    end

    -- Reward tournament/event dibuat sebagai BasePart bernama PackDrop
    -- yang menjadi child langsung Workspace. Jangan scan nama generik agar
    -- dekorasi card/pack lain tidak menyebabkan teleport palsu.
    for _, instance in ipairs(Workspace:GetChildren()) do
        if instance:IsA("BasePart") and instance.Name == "PackDrop" then
            consider(instance)
        end
    end

    table.sort(candidates, function(a, b)
        local reference = basePosition
        if not reference then
            return tostring(a.root:GetFullName()) < tostring(b.root:GetFullName())
        end
        return (a.position - reference).Magnitude < (b.position - reference).Magnitude
    end)

    State.spawnedPackCandidates = candidates
    return candidates
end

Runtime.getCollectibleTouchPart = function(root)
    if isLikelyPackRoot(root) then
        return root
    end

    return nil
end

function Runtime.triggerPackInteraction(candidate)
    local root = candidate and candidate.root
    if typeof(root) ~= "Instance" or not root.Parent then
        return false, "PackDrop sudah hilang"
    end

    local now = os.clock()
    local previousAt = State.packInteractionTimestamps[root]
    if previousAt and now - previousAt < math.max(SPAWNED_PACK_INTERACT_COOLDOWN, 8) then
        return false, "Cooldown"
    end
    State.packInteractionTimestamps[root] = now
    State.packInteractionAttempts[root] = (State.packInteractionAttempts[root] or 0) + 1

    local touchPart = Runtime.getCollectibleTouchPart(root)
    if not touchPart then
        return false, "PackDrop tidak valid atau sudah hilang"
    end

    local targetCFrame = touchPart.CFrame
        * CFrame.new(0, touchPart.Size.Y * 0.5 + 2.6, 0)

    local teleported, teleportError = teleportCharacter(
        targetCFrame,
        0,
        false,
        false
    )

    if not teleported then
        return false, teleportError
    end

    -- Tidak memakai ProximityPrompt, ClickDetector, firetouchinterest, atau
    -- remote tebakan. Character diposisikan di atas object agar sentuhan
    -- normal game yang mengambil collectible.
    task.wait(0.35)
    return true
end

Runtime.pickupSpawnedPacks = function(isAutomatic)
    if State.pickingSpawnedPacks then
        return false, "Pickup PackDrop sedang berjalan"
    end

    -- Scan dilakukan sebelum teleport. Ini mencegah player selalu dipindahkan
    -- ke base ketika tidak ada collectible.
    State.lastSpawnedPackScanAt = 0
    State.spawnedPackCandidates = {}
    local candidates = Runtime.scanSpawnedPackCandidates(true)

    if #candidates <= 0 then
        State.nextSpawnedPackScanAt = os.clock() + SPAWNED_PACK_SCAN_INTERVAL
        if not isAutomatic then
            setStatus("Tidak ada Workspace.PackDrop di dekat base.", COLORS.muted)
        end
        return false, "Tidak ada PackDrop"
    end

    State.pickingSpawnedPacks = true
    State.packPickupStartedAt = os.clock()
    updateAutomationButtons()

    task.spawn(function()
        local successCount = 0

        for _, candidate in ipairs(candidates) do
            if not State.running then
                break
            end

            local interacted = Runtime.triggerPackInteraction(candidate)
            if interacted then
                successCount += 1
            end

            task.wait(0.12)
        end

        State.pickingSpawnedPacks = false
        State.packPickupStartedAt = 0
        State.lastSpawnedPackPickupAt = os.time()
        State.lastSpawnedPackPickupCount = successCount
        State.nextSpawnedPackScanAt = os.clock() + SPAWNED_PACK_SCAN_INTERVAL
        State.spawnedPackCandidates = {}
        State.lastSpawnedPackScanAt = 0

        if State.autoConveyor then
            -- Heartbeat akan mendeteksi bahwa player tidak lagi berada di
            -- conveyor dan mengembalikannya setelah proses collect selesai.
            State.nextConveyorCheckAt = 0
        end

        updateAutomationButtons()

        if successCount > 0 then
            setStatus(
                string.format(
                    "Auto collect teleport ke %d PackDrop di dekat base.",
                    successCount
                ),
                COLORS.success
            )
            State.nextAutoOpenPackAt = 0
        elseif not isAutomatic then
            setStatus(
                "PackDrop ditemukan, tetapi part sudah hilang atau tidak valid.",
                COLORS.warning
            )
        end
    end)

    return true
end

function Runtime.activateGuiButton(button)
    if typeof(button) ~= "Instance" or not button:IsA("GuiButton") then
        return false
    end

    if type(firesignal) == "function" then
        local success = pcall(function()
            firesignal(button.Activated)
        end)
        if success then
            return true
        end

        success = pcall(function()
            firesignal(button.MouseButton1Click)
        end)
        if success then
            return true
        end
    end

    if type(getconnections) == "function" then
        local success, connections = pcall(getconnections, button.Activated)
        if success and type(connections) == "table" then
            for _, connection in ipairs(connections) do
                local fired = false
                if type(connection.Fire) == "function" then
                    fired = pcall(connection.Fire, connection)
                elseif type(connection.Function) == "function" then
                    fired = pcall(connection.Function)
                end
                if fired then
                    return true
                end
            end
        end
    end

    local success = pcall(function()
        button:Activate()
    end)
    return success
end

function Runtime.findAncestorGuiButton(instance, stopAt)
    local current = instance
    while current and current ~= stopAt do
        if current:IsA("GuiButton") then
            return current
        end
        current = current.Parent
    end
    return nil
end

function Runtime.findTextLabel(root, predicate)
    if typeof(root) ~= "Instance" then
        return nil
    end
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local textValue = tostring(descendant.Text or "")
            if predicate(textValue, descendant) then
                return descendant
            end
        end
    end
    return nil
end

function Runtime.findWorldCupVisualRoot()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local containers = {playerGui, CoreGui}

    for _, container in ipairs(containers) do
        if container then
            local title = Runtime.findTextLabel(container, function(textValue)
                return string.find(string.upper(textValue), "INTERNATIONAL CUP", 1, true) ~= nil
            end)
            if title then
                local current = title
                local best = nil
                for _ = 1, 10 do
                    if not current or current == container then
                        break
                    end
                    if current:IsA("GuiObject")
                        and current.AbsoluteSize.X >= 500
                        and current.AbsoluteSize.Y >= 400
                    then
                        best = current
                    end
                    current = current.Parent
                end
                return best or title.Parent
            end
        end
    end

    return nil
end

function Runtime.waitForWorldCupRoot(timeout)
    local deadline = os.clock() + (timeout or WORLD_CUP_VISUAL_TIMEOUT)
    repeat
        local root = Runtime.findWorldCupVisualRoot()
        if root and root.Parent then
            return root
        end
        task.wait(0.1)
    until os.clock() >= deadline
    return nil
end

function Runtime.findButtonByText(root, expectedText)
    local normalizedExpected = string.upper(tostring(expectedText or ""))
    local label = Runtime.findTextLabel(root, function(textValue)
        return string.upper(string.gsub(textValue, "%s+", " ")) == normalizedExpected
    end)
    return label and Runtime.findAncestorGuiButton(label, root.Parent) or nil
end

function Runtime.setVisualWorldCupFormation(root, desiredFormation)
    for _ = 1, #WORLD_CUP_FORMATIONS + 1 do
        local formationLabel = Runtime.findTextLabel(root, function(textValue)
            local upper = string.upper(textValue)
            return string.find(upper, "FORMATION", 1, true) ~= nil
        end)
        if formationLabel and string.find(tostring(formationLabel.Text), desiredFormation, 1, true) then
            return true
        end

        local nextButton = Runtime.findButtonByText(root, ">")
        if not nextButton or not Runtime.activateGuiButton(nextButton) then
            return false, "Tombol formation berikutnya tidak ditemukan"
        end
        task.wait(WORLD_CUP_VISUAL_STEP_DELAY)
    end

    return false, "Formation visual tidak dapat disamakan"
end

function Runtime.collectVisualSlotButtons(root)
    local roleNames = {GK = true, DEF = true, MID = true, FWD = true}
    local slots = {}
    local seen = {}

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel") and roleNames[tostring(descendant.Text)] then
            local role = tostring(descendant.Text)
            local current = descendant.Parent
            local button = nil
            for _ = 1, 5 do
                if not current or current == root then
                    break
                end
                button = current:FindFirstChildWhichIsA("GuiButton", true)
                if button then
                    break
                end
                current = current.Parent
            end

            if button and not seen[button] then
                seen[button] = true
                slots[#slots + 1] = {
                    role = role,
                    button = button,
                    x = button.AbsolutePosition.X,
                    y = button.AbsolutePosition.Y,
                }
            end
        end
    end

    table.sort(slots, function(a, b)
        if math.abs(a.y - b.y) > 3 then
            return a.y < b.y
        end
        return a.x < b.x
    end)

    return slots
end

function Runtime.waitForPicker(role, timeout)
    local deadline = os.clock() + (timeout or WORLD_CUP_VISUAL_TIMEOUT)
    local expected = "SELECT A " .. string.upper(tostring(role))
    repeat
        local root = Runtime.findWorldCupVisualRoot()
        if root then
            local title = Runtime.findTextLabel(root, function(textValue)
                return string.find(string.upper(textValue), expected, 1, true) ~= nil
            end)
            if title then
                local current = title
                local pickerRoot = nil
                for _ = 1, 7 do
                    if not current or current == root then
                        break
                    end
                    if current:IsA("GuiObject") and current.AbsoluteSize.X >= 400 then
                        pickerRoot = current
                    end
                    current = current.Parent
                end
                return pickerRoot or title.Parent
            end
        end
        task.wait(0.08)
    until os.clock() >= deadline
    return nil
end

function Runtime.findPlayerButtonInPicker(pickerRoot, card)
    local exactName = tostring(card.name or "")
    local targetRating = tostring(math.floor(tonumber(card.rating) or 0))
    local fallback = nil

    for _, descendant in ipairs(pickerRoot:GetDescendants()) do
        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
            and tostring(descendant.Text or "") == exactName
        then
            local button = Runtime.findAncestorGuiButton(descendant, pickerRoot.Parent)
            if button then
                fallback = fallback or button
                local ratingFound = false
                for _, buttonDescendant in ipairs(button:GetDescendants()) do
                    if (buttonDescendant:IsA("TextLabel") or buttonDescendant:IsA("TextButton"))
                        and tostring(buttonDescendant.Text or "") == targetRating
                    then
                        ratingFound = true
                        break
                    end
                end
                if ratingFound then
                    return button
                end
            end
        end
    end

    return fallback
end

Runtime.updateWorldCupPreview = function()
    if not State.worldCupPreviewParagraph or type(State.worldCupPreviewParagraph.SetDesc) ~= "function" then
        return
    end

    local status = State.worldCupStatus
    local team = nil
    local teamError = nil
    if Runtime.selectWorldCupTeam then
        team, teamError = Runtime.selectWorldCupTeam(status)
    end

    if not team then
        State.worldCupPreviewParagraph:SetDesc("Squad preview belum tersedia • " .. tostring(teamError or "data pemain belum siap"))
        return
    end

    local lines = {string.format("Formation %s • %d pemain", tostring(team.formation), #team.cards)}
    for index, card in ipairs(team.cards) do
        lines[#lines + 1] = string.format(
            "%02d. %s • %s • %s OVR • %s",
            index,
            tostring(card.position),
            tostring(card.name),
            tostring(card.rating),
            tostring(card.rarity)
        )
    end
    State.worldCupPreviewParagraph:SetDesc(table.concat(lines, "\n"))
end

Runtime.fillWorldCupVisualSquad = function(team, isAutomatic)
    if State.fillingWorldCupVisual then
        return false, "Visual Fill sedang berjalan"
    end

    if not team then
        local status = State.worldCupStatus or Runtime.fetchWorldCupStatus()
        local selectedTeam, teamError = Runtime.selectWorldCupTeam(status)
        if not selectedTeam then
            return false, teamError
        end
        team = selectedTeam
    end

    State.fillingWorldCupVisual = true
    State.lastWorldCupVisualFillError = nil
    State.lastWorldCupVisualFillCount = 0
    updateAutomationButtons()

    local function finish(success, errorMessage, filledCount)
        State.fillingWorldCupVisual = false
        State.lastWorldCupVisualFillAt = os.time()
        State.lastWorldCupVisualFillCount = filledCount or 0
        State.lastWorldCupVisualFillError = errorMessage
        updateAutomationButtons()
        if success then
            setStatus(
                string.format("Visual squad Cup terisi %d/11 • %s.", filledCount or 0, tostring(team.formation)),
                COLORS.success
            )
        elseif not isAutomatic then
            setStatus("Visual Fill Cup gagal: " .. tostring(errorMessage), COLORS.warning)
        end
        return success, errorMessage
    end

    local root = Runtime.findWorldCupVisualRoot()
    if not root then
        local opened, openError = fireBusEvent("WorldCupToggle")
        if not opened then
            return finish(false, "Gagal membuka menu Cup: " .. tostring(openError), 0)
        end
        root = Runtime.waitForWorldCupRoot(WORLD_CUP_VISUAL_TIMEOUT)
    end

    if not root then
        return finish(false, "Menu International Cup tidak ditemukan", 0)
    end

    local formationSuccess, formationError = Runtime.setVisualWorldCupFormation(root, team.formation)
    if not formationSuccess then
        return finish(false, formationError, 0)
    end

    task.wait(WORLD_CUP_VISUAL_STEP_DELAY)
    local slots = Runtime.collectVisualSlotButtons(root)
    if #slots < 11 then
        return finish(false, string.format("Hanya menemukan %d slot visual", #slots), 0)
    end

    local slotsByRole = {GK = {}, DEF = {}, MID = {}, FWD = {}}
    for _, slot in ipairs(slots) do
        if slotsByRole[slot.role] then
            slotsByRole[slot.role][#slotsByRole[slot.role] + 1] = slot
        end
    end

    local roleIndexes = {GK = 1, DEF = 1, MID = 1, FWD = 1}
    local filledCount = 0

    for _, card in ipairs(team.cards) do
        local role = tostring(card.position)
        local slot = slotsByRole[role] and slotsByRole[role][roleIndexes[role]] or nil
        roleIndexes[role] = (roleIndexes[role] or 1) + 1

        if not slot or not Runtime.activateGuiButton(slot.button) then
            return finish(false, "Gagal membuka slot " .. role, filledCount)
        end

        local picker = Runtime.waitForPicker(role, WORLD_CUP_VISUAL_TIMEOUT)
        if not picker then
            return finish(false, "Picker " .. role .. " tidak muncul", filledCount)
        end

        local playerButton = Runtime.findPlayerButtonInPicker(picker, card)
        if not playerButton then
            return finish(false, "Kartu visual tidak ditemukan: " .. tostring(card.name), filledCount)
        end

        if not Runtime.activateGuiButton(playerButton) then
            return finish(false, "Gagal memilih " .. tostring(card.name), filledCount)
        end

        filledCount += 1
        task.wait(WORLD_CUP_VISUAL_STEP_DELAY)
    end

    return finish(filledCount == 11, filledCount == 11 and nil or "Visual squad tidak lengkap", filledCount)
end

Runtime.collectWorldCupReward = function(isAutomatic)
    if State.collectingWorldCupReward or State.joiningWorldCup then
        return false, "Reward Cup sedang diproses"
    end

    if not tryRediscoverNetworker() then
        return false, "Networker belum ditemukan"
    end

    local status = State.worldCupStatus
    if type(status) ~= "table" or os.clock() - State.worldCupStatusUpdatedAt > WORLD_CUP_REWARD_CHECK_INTERVAL then
        local fetched, fetchError = Runtime.fetchWorldCupStatus()
        if not fetched then
            return false, fetchError
        end
        status = fetched
    end

    if not status.pendingClaim or status.canCollect ~= true then
        return false, status.pendingClaim and "Reward belum siap" or "Tidak ada reward pending"
    end

    if State.matchPlaybackActive then
        return false, "Menunggu match selesai sebelum collect reward Cup"
    end

    State.collectingWorldCupReward = true
    updateAutomationButtons()

    task.spawn(function()
        local response, errorMessage = callNetwork("CollectWorldCup")
        State.collectingWorldCupReward = false
        State.nextWorldCupRewardCheckAt = os.clock()
            + (response and response.success and AUTO_ACTION_INTERVAL or WORLD_CUP_RETRY_DELAY)

        if response and response.success then
            State.lastWorldCupCollectAt = os.time()
            State.worldCupStatus = nil
            State.worldCupStatusUpdatedAt = 0
            State.cachedTopCard = nil
            State.nextSpawnedPackScanAt = 0
            State.nextAutoOpenPackAt = 0
            setStatus(
                string.format(
                    "Reward International Cup berhasil diklaim%s • menunggu Workspace.PackDrop muncul di dekat base.",
                    response.label and (" • " .. tostring(response.label)) or ""
                ),
                COLORS.success
            )
            task.delay(0.8, function()
                if State.running and State.autoPickupSpawnedPacks then
                    Runtime.pickupSpawnedPacks(true)
                end
            end)
        elseif not isAutomatic then
            setStatus("Collect reward International Cup gagal: " .. tostring(errorMessage), COLORS.danger)
        end

        updateAutomationButtons()
        refreshUI(true)
    end)

    return true
end

Runtime.getWorldCupPhase = function()
    local config = State.worldCupConfig
    if not config or type(config.Phase) ~= "function" then
        return nil
    end

    local success, result = pcall(config.Phase, os.time())
    if success and type(result) == "table" then
        return result
    end

    return nil
end

Runtime.fetchWorldCupStatus = function()
    if not tryRediscoverNetworker() then
        return nil, "Networker belum ditemukan"
    end

    local response, errorMessage = callNetwork("GetWorldCupStatus")
    if type(response) == "table" and response.success ~= false then
        State.worldCupStatus = response
        State.worldCupStatusUpdatedAt = os.clock()
        State.cachedTopCard = nil
        updateAutomationButtons()
        return response
    end

    return nil, errorMessage or "Status International Cup tidak tersedia"
end

function Runtime.getWorldCupUnavailableIds()
    local unavailable = {}
    addActiveIds(unavailable, Runtime.getData("Loans.active"))
    addActiveIds(unavailable, Runtime.getData("Training.active"))
    return unavailable
end

function Runtime.resolveWorldCupCandidate(instanceId, cardData)
    if type(cardData) ~= "table" or cardData.baseId == nil then
        return nil
    end

    local database = State.playerCardDatabase
    if not database or type(database.GetById) ~= "function" then
        return nil
    end

    local success, baseCard = pcall(database.GetById, cardData.baseId)
    if not success or not baseCard then
        return nil
    end

    local resolved = nil
    local cardResolve = State.cardResolve
    if cardResolve and type(cardResolve.Resolve) == "function" then
        local resolveSuccess, result = pcall(cardResolve.Resolve, cardData)
        if resolveSuccess and type(result) == "table" then
            resolved = result
        end
    end

    local upgrade = tonumber(cardData.upgrade) or 0
    local rating = resolved and tonumber(resolved.rating)
        or ((tonumber(baseCard.rating) or 0) + upgrade)
    local rarity = resolved and resolved.rarity or getRarity(baseCard, rating)

    return {
        instanceId = tostring(instanceId),
        baseId = tostring(cardData.baseId),
        name = tostring(baseCard.name or "Unknown Player"),
        position = tostring(baseCard.position or ""),
        nation = tostring(baseCard.nation or ""),
        rating = tonumber(rating) or 0,
        rarity = tostring(rarity or "Unknown"),
        rank = rarityRank(rarity),
    }
end

function Runtime.getFormationRoles(formation)
    local layout = State.formationLayout
    if not layout or type(layout.Get) ~= "function" then
        return nil
    end

    local success, roles = pcall(layout.Get, formation)
    if not success or type(roles) ~= "table" then
        return nil
    end

    return roles
end

function Runtime.buildWorldCupCandidatePools()
    local owned = Runtime.getData("Squad.Owned")
    if type(owned) ~= "table" then
        return nil, "Squad.Owned belum tersedia"
    end

    local unavailable = Runtime.getWorldCupUnavailableIds()
    local bestByRoleAndBase = {
        GK = {},
        DEF = {},
        MID = {},
        FWD = {},
    }

    for rawInstanceId, cardData in pairs(owned) do
        local instanceId = tostring(rawInstanceId)
        if not unavailable[instanceId] then
            local candidate = Runtime.resolveWorldCupCandidate(instanceId, cardData)
            local role = candidate and candidate.position
            if candidate and bestByRoleAndBase[role] then
                local current = bestByRoleAndBase[role][candidate.baseId]
                if not current
                    or candidate.rank > current.rank
                    or (candidate.rank == current.rank and candidate.rating > current.rating)
                then
                    bestByRoleAndBase[role][candidate.baseId] = candidate
                end
            end
        end
    end

    local pools = {
        GK = {},
        DEF = {},
        MID = {},
        FWD = {},
    }

    for role, byBase in pairs(bestByRoleAndBase) do
        for _, candidate in pairs(byBase) do
            pools[role][#pools[role] + 1] = candidate
        end

        table.sort(pools[role], function(a, b)
            if a.rank ~= b.rank then
                return a.rank > b.rank
            end
            if a.rating ~= b.rating then
                return a.rating > b.rating
            end
            return a.name < b.name
        end)
    end

    return pools
end

function Runtime.buildBestWorldCupTeamForFormation(formation, pools)
    local roles = Runtime.getFormationRoles(formation)
    if not roles then
        return nil, "FormationLayout tidak tersedia"
    end

    local required = {GK = 0, DEF = 0, MID = 0, FWD = 0}
    for _, slot in ipairs(roles) do
        local role = slot.role
        if required[role] ~= nil then
            required[role] += 1
        end
    end

    local selectedByRole = {GK = {}, DEF = {}, MID = {}, FWD = {}}
    local score = 0

    for role, amount in pairs(required) do
        local pool = pools[role] or {}
        if #pool < amount then
            return nil, string.format("Butuh %d %s, tersedia %d", amount, role, #pool)
        end

        for index = 1, amount do
            local candidate = pool[index]
            selectedByRole[role][index] = candidate
            score += candidate.rank * 100000 + candidate.rating * 100
        end
    end

    local roleIndex = {GK = 1, DEF = 1, MID = 1, FWD = 1}
    local instanceIds = {}
    local cards = {}

    for slotIndex, slot in ipairs(roles) do
        local role = slot.role
        local candidate = selectedByRole[role][roleIndex[role]]
        if not candidate then
            return nil, "Gagal mengisi slot " .. tostring(slotIndex)
        end

        roleIndex[role] += 1
        instanceIds[#instanceIds + 1] = candidate.instanceId
        cards[#cards + 1] = candidate
    end

    return {
        formation = formation,
        instanceIds = instanceIds,
        cards = cards,
        score = score,
    }
end

function Runtime.buildBestWorldCupTeam()
    local pools, poolError = Runtime.buildWorldCupCandidatePools()
    if not pools then
        return nil, poolError
    end

    local bestTeam = nil
    local reasons = {}

    for _, formation in ipairs(WORLD_CUP_FORMATIONS) do
        local team, reason = Runtime.buildBestWorldCupTeamForFormation(formation, pools)
        if team then
            if not bestTeam or team.score > bestTeam.score then
                bestTeam = team
            end
        elseif reason then
            reasons[#reasons + 1] = formation .. ": " .. reason
        end
    end

    if not bestTeam then
        return nil, reasons[1] or "Tidak cukup pemain untuk membentuk 11 pemain"
    end

    return bestTeam
end

function Runtime.buildLastWorldCupTeam(status)
    if type(status) ~= "table" then
        return nil, "Status International Cup belum tersedia"
    end

    local lastTeam = status.lastTeam
    local formation = tostring(status.lastFormation or "4-3-3")
    if type(lastTeam) ~= "table" or #lastTeam <= 0 then
        return nil, "Belum ada Last Team"
    end

    local roles = Runtime.getFormationRoles(formation)
    if not roles then
        return nil, "Formation Last Team tidak valid"
    end

    local owned = Runtime.getData("Squad.Owned")
    if type(owned) ~= "table" then
        return nil, "Squad.Owned belum tersedia"
    end

    local unavailable = Runtime.getWorldCupUnavailableIds()
    local candidatesByRole = {GK = {}, DEF = {}, MID = {}, FWD = {}}
    local usedBaseIds = {}

    for _, rawInstanceId in ipairs(lastTeam) do
        local instanceId = tostring(rawInstanceId)
        local cardData = owned[instanceId] or owned[rawInstanceId]
        if type(cardData) == "table" and not unavailable[instanceId] then
            local candidate = Runtime.resolveWorldCupCandidate(instanceId, cardData)
            if candidate
                and candidatesByRole[candidate.position]
                and not usedBaseIds[candidate.baseId]
            then
                usedBaseIds[candidate.baseId] = true
                candidatesByRole[candidate.position][#candidatesByRole[candidate.position] + 1] = candidate
            end
        end
    end

    local roleIndex = {GK = 1, DEF = 1, MID = 1, FWD = 1}
    local instanceIds = {}
    local cards = {}

    for slotIndex, slot in ipairs(roles) do
        local role = slot.role
        local candidate = candidatesByRole[role][roleIndex[role]]
        if not candidate then
            return nil, string.format("Last Team tidak lengkap untuk slot %d (%s)", slotIndex, tostring(role))
        end

        roleIndex[role] += 1
        instanceIds[#instanceIds + 1] = candidate.instanceId
        cards[#cards + 1] = candidate
    end

    if #instanceIds ~= 11 then
        return nil, "Last Team tidak berisi 11 pemain yang tersedia"
    end

    return {
        formation = formation,
        instanceIds = instanceIds,
        cards = cards,
        score = 0,
    }
end

Runtime.selectWorldCupTeam = function(status)
    if normalizeWorldCupSquadMode(State.worldCupSquadMode) == WORLD_CUP_SQUAD_MODE_LAST then
        return Runtime.buildLastWorldCupTeam(status)
    end

    return Runtime.buildBestWorldCupTeam()
end

Runtime.getWorldCupReservedIds = function()
    local reserved = {}
    if not State.autoJoinWorldCup then
        return reserved
    end

    local status = State.worldCupStatus
    if type(status) == "table" and status.youEntered then
        return reserved
    end

    local team = nil
    if normalizeWorldCupSquadMode(State.worldCupSquadMode) == WORLD_CUP_SQUAD_MODE_LAST then
        if type(status) == "table" then
            team = Runtime.buildLastWorldCupTeam(status)
        end
    else
        team = Runtime.buildBestWorldCupTeam()
    end

    if type(team) == "table" and type(team.instanceIds) == "table" then
        for _, instanceId in ipairs(team.instanceIds) do
            reserved[tostring(instanceId)] = true
        end
    end

    return reserved
end


function Runtime.pauseAutoPlayForWorldCup()
    local wantsAutoPlay = State.autoMatch == true
        or Runtime.getData("Settings.AutoMatch") == true

    if not wantsAutoPlay then
        return true
    end

    if State.worldCupAutoPlayPaused then
        return true
    end

    if State.settingAutoMatch or State.autoMatchTransaction then
        return false, "Auto Play sedang diproses"
    end

    State.autoMatchTransaction = true
    State.autoMatchSyncIgnoreUntil = os.clock() + 30
    updateAutomationButtons()

    local response, errorMessage = callNetworkLoose(
        "SetAutoMatch",
        {enabled = false}
    )

    State.autoMatchTransaction = false

    if not response then
        updateAutomationButtons()
        return false, "Gagal pause Auto Play untuk International Cup: "
            .. tostring(errorMessage)
    end

    waitForAutoMatchValue(false, AUTO_MATCH_PAUSE_TIMEOUT)

    State.worldCupAutoPlayPaused = true
    State.autoMatchPendingSync = false
    State.nextAutoPlayEnsureAt = os.clock() + 3600
    updateAutomationButtons()

    return true
end

function Runtime.restoreAutoPlayAfterWorldCup()
    if not State.worldCupAutoPlayPaused then
        return true
    end

    if not State.autoMatch then
        State.worldCupAutoPlayPaused = false
        updateAutomationButtons()
        return true
    end

    if State.matchPlaybackActive then
        return false, "Match masih berlangsung"
    end

    if State.settingAutoMatch or State.autoMatchTransaction then
        return false, "Auto Play sedang diproses"
    end

    State.autoMatchTransaction = true
    updateAutomationButtons()

    local restored, warningMessage = requestAutoPlayStart()

    State.autoMatchTransaction = false

    if restored then
        State.worldCupAutoPlayPaused = false
        State.autoMatchPendingSync = false
        State.autoMatchSyncIgnoreUntil = os.clock() + 5
        State.nextAutoPlayEnsureAt = os.clock() + AUTO_PLAY_ENSURE_DELAY
    else
        State.autoMatchPendingSync = true
        State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY
    end

    updateAutomationButtons()

    return restored, warningMessage
end

function Runtime.joinInternationalCup(isAutomatic)
    if State.joiningWorldCup
        or State.collectingWorldCupReward
        or State.fillingWorldCupVisual
        or State.collecting
        or State.loaning
        or State.prestiging
        or State.equippingBest
        or State.autoMatchTransaction
    then
        return false, "Automation lain sedang berjalan"
    end

    local status, statusError = Runtime.fetchWorldCupStatus()
    if not status then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_RETRY_DELAY
        if not isAutomatic then
            setStatus("Gagal mengecek International Cup: " .. tostring(statusError), COLORS.danger)
        end
        return false, statusError
    end

    local phaseInfo = Runtime.getWorldCupPhase()
    local phase = phaseInfo and phaseInfo.phase or nil

    -- Jika entry atau reward sedang menunggu, pause Auto Play sekarang juga.
    -- Ini penting ketika sebuah match masih berjalan: SetAutoMatch(false) akan
    -- mencegah game langsung memulai match berikutnya setelah playback selesai.
    local cupNeedsPriority = (status.pendingClaim and (not isAutomatic or State.autoCollectWorldCupRewards))
        or (phase == "entry" and not status.youEntered)

    if cupNeedsPriority then
        local paused, pauseError = Runtime.pauseAutoPlayForWorldCup()
        if not paused then
            State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_RETRY_DELAY
            if not isAutomatic then
                setStatus(tostring(pauseError), COLORS.warning)
            end
            return false, pauseError
        end
    end

    -- Reward pending mengunci entry berikutnya. Auto Collect Cup Rewards
    -- dipisahkan dari Auto Join agar keduanya dapat dikontrol sendiri.
    if status.pendingClaim then
        if status.canCollect ~= true then
            State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
            return false, "Reward belum dapat diklaim"
        end

        if not isAutomatic or State.autoCollectWorldCupRewards then
            return Runtime.collectWorldCupReward(isAutomatic)
        end

        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
        return false, "Auto Collect Cup Rewards OFF"
    end

    if status.youEntered then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
        Runtime.restoreAutoPlayAfterWorldCup()
        return false, "Sudah terdaftar"
    end

    if phase ~= "entry" then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
        Runtime.restoreAutoPlayAfterWorldCup()
        return false, "Entry belum terbuka"
    end

    if State.matchPlaybackActive then
        State.nextWorldCupCheckAt = os.clock() + 1
        if not isAutomatic then
            setStatus(
                "International Cup menunggu match selesai. Auto Play sudah dipause agar tidak memulai match berikutnya.",
                COLORS.warning
            )
        end
        return false, "Match sedang berlangsung"
    end

    local team, teamError = Runtime.selectWorldCupTeam(status)
    if not team then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_RETRY_DELAY
        if not isAutomatic then
            setStatus("Tidak dapat menyiapkan squad Cup: " .. tostring(teamError), COLORS.warning)
        end
        return false, teamError
    end

    State.joiningWorldCup = true
    updateAutomationButtons()
    setStatus(
        string.format(
            "Menyiapkan squad Cup • %s • %s • %d pemain...",
            tostring(team.formation),
            worldCupSquadModeLabel(State.worldCupSquadMode),
            #team.instanceIds
        ),
        COLORS.warning
    )

    task.spawn(function()
        if State.fillWorldCupVisualBeforeJoin then
            local visualSuccess, visualError = Runtime.fillWorldCupVisualSquad(team, true)
            if not visualSuccess then
                setStatus(
                    "Visual Fill Cup gagal, melanjutkan direct join: " .. tostring(visualError),
                    COLORS.warning
                )
            end
        end

        -- WorldCupMenu tidak memiliki remote terpisah untuk "equip".
        -- Squad dikirim langsung sebagai formation + instanceIds ke EnterWorldCup.
        local response, errorMessage = callNetworkLoose("EnterWorldCup", {
            formation = team.formation,
            instanceIds = team.instanceIds,
        })

        State.joiningWorldCup = false
    State.collectingWorldCupReward = false
    State.fillingWorldCupVisual = false
    State.pickingSpawnedPacks = false
        local joined = response ~= nil
            and (type(response) ~= "table" or response.success ~= false)
        State.nextWorldCupCheckAt = os.clock()
            + (joined and WORLD_CUP_SUCCESS_DELAY or WORLD_CUP_RETRY_DELAY)

        if joined then
            State.lastWorldCupJoinAt = os.time()
            State.worldCupStatus = nil
            State.cachedTopCard = nil
            setStatus(
                string.format(
                    "Berhasil join International Cup • %s • %d pemain • squad otomatis terkirim.",
                    tostring(team.formation),
                    #team.instanceIds
                ),
                COLORS.success
            )
            Runtime.restoreAutoPlayAfterWorldCup()
        elseif not isAutomatic then
            setStatus(
                "Join International Cup gagal: " .. tostring(errorMessage or "Unknown error"),
                COLORS.danger
            )
        end

        updateAutomationButtons()
        task.wait(0.35)
        refreshUI(true)
    end)

    return true
end

function Runtime.fetchPrestigeInfo()
    if not tryRediscoverNetworker() then
        return nil, "Networker belum ditemukan"
    end

    local response, errorMessage = callNetwork("GetPrestigeInfo")
    if response then
        State.prestigeInfo = response
        State.prestigeInfoUpdatedAt = os.clock()
        updateAutomationButtons()
        updatePrestigeParagraph()
    end

    return response, errorMessage
end

function Runtime.performPrestige(isAutomatic)
    if State.prestiging or State.collecting or State.loaning or State.joiningWorldCup then
        return false, "Automation lain sedang berjalan"
    end

    local prestigeInfo = State.prestigeInfo
    if not prestigeInfo or not prestigeInfo.eligible then
        local errorMessage
        prestigeInfo, errorMessage = Runtime.fetchPrestigeInfo()
        if not prestigeInfo then
            if not isAutomatic then
                setStatus("Gagal mengecek prestige: " .. tostring(errorMessage), COLORS.danger)
            end
            State.nextPrestigeCheckAt = os.clock() + PRESTIGE_RETRY_DELAY
            return false, errorMessage
        end
    end

    if not prestigeInfo.eligible then
        if not isAutomatic then
            setStatus("Prestige belum eligible • masih ada requirement yang belum selesai.", COLORS.warning)
        end
        State.nextPrestigeCheckAt = os.clock() + PRESTIGE_CHECK_INTERVAL
        updateAutomationButtons()
        return false, "Prestige belum eligible"
    end

    State.prestiging = true
    State.nextPrestigeCheckAt = math.huge
    updateAutomationButtons()
    setCollectButton("Collect All", false)
    setLoanButton("Loan Top", false)

    local targetNumber = tonumber(prestigeInfo.nextNumber)
        or ((tonumber(prestigeInfo.count) or 0) + 1)
    setStatus(
        string.format("Menjalankan Prestige %d...", targetNumber),
        COLORS.warning
    )

    task.spawn(function()
        local response, errorMessage = callNetwork("DoPrestige")

        State.prestiging = false
        State.prestigeInfo = nil
        State.cachedTopCard = nil
        State.nextAutoLoanAt = os.clock() + AUTO_RETRY_DELAY
        State.nextAutoCollectAt = os.clock() + AUTO_RETRY_DELAY

        if response and response.success then
            State.nextPrestigeCheckAt = os.clock() + PRESTIGE_SUCCESS_DELAY

            if response.summary then
                fireBusEvent("PrestigeComplete", response.summary)
            end

            local completedCount = tonumber(response.count) or targetNumber
            setStatus(
                string.format("PRESTIGE %d COMPLETE!", completedCount),
                COLORS.success
            )

            task.delay(1, function()
                if State.running then
                    Runtime.fetchPrestigeInfo()
                    refreshUI(true)
                end
            end)
        else
            State.nextPrestigeCheckAt = os.clock() + PRESTIGE_RETRY_DELAY
            setStatus(
                "Prestige gagal: " .. tostring(errorMessage or "Unknown error"),
                COLORS.danger
            )
        end

        updateAutomationButtons()
        task.wait(0.35)
        refreshUI(true)
    end)

    return true
end

function Runtime.collectAllReadyLoans(isAutomatic)
    if State.collecting
        or State.loaning
        or State.prestiging
        or State.equippingBest
        or State.joiningWorldCup
        or State.collectingWorldCupReward
        or State.fillingWorldCupVisual
        or State.pickingSpawnedPacks
        or State.claimingPlayTimeRewards
        or State.autoMatchTransaction
    then
        return
    end

    if not tryRediscoverNetworker() then
        setStatus("Collect gagal: Networker belum ditemukan.", COLORS.danger)
        refreshUI(false)
        return
    end

    local rows = buildRows()
    local readyRows = {}

    for _, row in ipairs(rows) do
        if row.ready then
            readyRows[#readyRows + 1] = row
        end
    end

    if #readyRows == 0 then
        if not isAutomatic then
            setStatus("Belum ada loan yang selesai.", COLORS.warning)
        end
        refreshUI(false)
        return
    end

    -- Slot terbesar diproses lebih dulu agar indeks array tidak bergeser.
    table.sort(readyRows, function(a, b)
        return a.slot > b.slot
    end)

    State.collecting = true
    setCollectButton(string.format("Collecting 0/%d", #readyRows), false)
    setStatus("Mengambil loan yang sudah selesai...", COLORS.warning)

    task.spawn(function()
        local collected = 0
        local failed = 0
        local failureReasons = {}

        for index, row in ipairs(readyRows) do
            if not State.running then
                break
            end

            setCollectButton(
                string.format("Collecting %d/%d", index, #readyRows),
                false
            )

            local response, errorMessage = callNetwork("CollectLoan", {
                slot = row.slot,
            })

            if response and response.success then
                collected += 1

                local tracked = State.autoLoanedIds[row.instanceId]
                if tracked then
                    local report = type(response.report) == "table" and response.report or {}
                    local income = tonumber(report.total) or tonumber(report.base) or 0

                    State.stats.autoCollected += 1
                    State.stats.autoIncome += income
                    State.stats.lastIncome = income
                    State.stats.lastAction = string.format("Collected %s", row.name)
                    State.autoLoanedIds[row.instanceId] = nil
                end
            else
                failed += 1
                if isAutomatic and State.autoLoanedIds[row.instanceId] then
                    State.stats.failures += 1
                    State.stats.lastAction = string.format("Collect failed: %s", row.name)
                end
                failureReasons[#failureReasons + 1] = string.format(
                    "Slot %d: %s",
                    row.slot,
                    errorMessage or "Unknown error"
                )
            end

            task.wait(0.25)
        end

        State.collecting = false
        State.nextAutoCollectAt = os.clock() + AUTO_ACTION_INTERVAL
        task.wait(0.35)
        refreshUI(true)

        if failed == 0 then
            setStatus(
                string.format("Berhasil collect %d loan.", collected),
                COLORS.success
            )
        elseif collected > 0 then
            setStatus(
                string.format("%d berhasil, %d gagal.", collected, failed),
                COLORS.warning
            )
        else
            setStatus(
                failureReasons[1] or "Semua collect gagal.",
                COLORS.danger
            )
        end
    end)
end

function Runtime.loanOutTopRarity(isAutomatic)
    if State.loaning or State.collecting or State.prestiging or State.joiningWorldCup then
        return
    end

    if Runtime.getEnabledRarityCount() == 0 then
        if not isAutomatic then
            setStatus("Aktifkan minimal satu rarity pada whitelist.", COLORS.warning)
        end
        State.nextAutoLoanAt = os.clock() + AUTO_RETRY_DELAY
        refreshUI(false)
        return
    end

    if not tryRediscoverNetworker() then
        setStatus("Loan gagal: Networker belum ditemukan.", COLORS.danger)
        State.nextAutoLoanAt = os.clock() + AUTO_RETRY_DELAY
        refreshUI(false)
        return
    end

    local hasFreeSlot = getLoanSlotState()
    if not hasFreeSlot then
        if not isAutomatic then
            setStatus("Semua loan slot sedang terisi.", COLORS.warning)
        end
        State.nextAutoLoanAt = os.clock() + AUTO_RETRY_DELAY
        refreshUI(false)
        return
    end

    local card = getTopAvailableCard(true)
    if not card then
        if not isAutomatic then
            setStatus("Tidak ada kartu yang cocok dengan whitelist rarity.", COLORS.warning)
        end
        State.nextAutoLoanAt = os.clock() + AUTO_RETRY_DELAY
        refreshUI(false)
        return
    end

    local selectedMinutes = State.selectedDuration
    local durationLabel = Runtime.getDurationLabel(selectedMinutes)

    State.loaning = true
    setLoanButton("Sending...", false)
    setCollectButton("Collect All", false)
    setStatus(
        string.format(
            "Mengirim %s • %s • %d OVR ke %s Loan...",
            tostring(card.name),
            tostring(card.rarity),
            tonumber(card.rating) or 0,
            durationLabel
        ),
        COLORS.warning
    )

    task.spawn(function()
        local response, errorMessage = callNetwork("SendLoan", {
            instanceId = card.instanceId,
            mins = selectedMinutes,
        })

        State.loaning = false
        State.cachedTopCard = nil
        State.nextAutoLoanAt = os.clock()
            + (response and response.success and AUTO_ACTION_INTERVAL or AUTO_RETRY_DELAY)

        if response and response.success then
            if isAutomatic then
                State.stats.autoSent += 1
                State.stats.lastIncome = 0
                State.stats.lastAction = string.format("Loaned %s for %s", card.name, durationLabel)
                State.autoLoanedIds[card.instanceId] = {
                    name = card.name,
                    rarity = card.rarity,
                    rating = card.rating,
                    minutes = selectedMinutes,
                    sentAt = os.time(),
                }
            end

            task.wait(0.35)
            refreshUI(true)
            setStatus(
                string.format(
                    "%s (%s, %d OVR) berhasil di-loan selama %s.",
                    tostring(card.name),
                    tostring(card.rarity),
                    tonumber(card.rating) or 0,
                    durationLabel
                ),
                COLORS.success
            )
        else
            if isAutomatic then
                State.stats.failures += 1
                State.stats.lastAction = string.format("Loan failed: %s", card.name)
            end

            task.wait(0.35)
            refreshUI(true)
            setStatus(
                string.format(
                    "Loan %s gagal: %s",
                    tostring(card.name),
                    errorMessage or "Unknown error"
                ),
                COLORS.danger
            )
        end
    end)
end

function Runtime.getReadyLoanCount()
    local readyCount = 0
    for _, row in ipairs(buildRows()) do
        if row.ready then
            readyCount += 1
        end
    end
    return readyCount
end

function Runtime.runAutomationTick()
    if not State.running then
        return
    end

    if State.autoMatchPendingSync
        and not State.worldCupAutoPlayPaused
        and not State.settingAutoMatch
        and os.clock() >= State.nextAutoMatchSyncAt
    then
        if tryRediscoverNetworker() then
            setAutoPlayEnabled(State.autoMatch, false, true)
        else
            State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY
        end
    end

    if State.collecting
        or State.loaning
        or State.prestiging
        or State.equippingBest
        or State.joiningWorldCup
        or State.collectingWorldCupReward
        or State.fillingWorldCupVisual
        or State.pickingSpawnedPacks
        or State.buyingPacks
        or State.claimingDailyReward
        or State.autoMatchTransaction
    then
        return
    end

    local now = os.clock()

    -- Auto Open Packs memakai Networker agar Pick Pack dapat dipilih otomatis.
    -- Trigger diulang dengan cooldown bila pack masih tersisa atau event sebelumnya
    -- terabaikan karena match/playback sedang berlangsung.
    if State.autoOpenPacks and now >= State.nextAutoOpenPackAt then
        local packCount = Runtime.getOwnedPackCount()
        if packCount <= 0 then
            State.lastObservedPackCount = 0
            State.nextAutoOpenPackAt = now + AUTO_PACK_RETRY_DELAY
        else
            local opened = Runtime.openOwnedPacksAutomatically(true)
            State.nextAutoOpenPackAt = now + AUTO_PACK_RETRY_DELAY
            if opened then
                return
            end
        end
    end

    if State.autoPickupSpawnedPacks and now >= State.nextSpawnedPackScanAt then
        State.nextSpawnedPackScanAt = now + SPAWNED_PACK_SCAN_INTERVAL
        local candidates = Runtime.scanSpawnedPackCandidates(true)
        if #candidates > 0 and Runtime.pickupSpawnedPacks(true) then
            return
        end
    end

    if not tryRediscoverNetworker() then
        return
    end

    ensureMatchPlaybackListeners()

    -- Auto Prestige tetap menang saat seluruh gate sudah siap. Auto Buy tidak
    -- boleh menghabiskan coins sebelum DoPrestige sempat dijalankan.
    if (State.autoPrestige or (State.autoBuyPacks and State.packBuyPrestigePriority))
        and now >= State.nextPrestigeCheckAt
    then
        State.nextPrestigeCheckAt = now + PRESTIGE_CHECK_INTERVAL

        local prestigeInfo = Runtime.fetchPrestigeInfo()
        if State.autoPrestige and prestigeInfo and prestigeInfo.eligible then
            Runtime.performPrestige(true)
            return
        end
    end

    if State.autoBuyPacks and now >= State.nextAutoBuyPackAt then
        State.nextAutoBuyPackAt = now + AUTO_BUY_PACK_RETRY_DELAY
        if Runtime.buySelectedPacks(true) then
            return
        end
    end

    if State.autoClaimDailyReward and now >= State.nextDailyRewardClaimAt then
        State.nextDailyRewardClaimAt = now + 5
        if Runtime.claimDailyReward(true) then
            return
        end
    end

    if State.autoClaimPlayTimeRewards and now >= State.nextPlayTimeClaimAt then
        State.nextPlayTimeClaimAt = now + 5
        if Runtime.claimReadyPlayTimeRewards(true) then
            return
        end
    end

    -- Reward Cup diproses terpisah agar tetap dapat diklaim walau Auto Join OFF.
    if State.autoCollectWorldCupRewards and now >= State.nextWorldCupRewardCheckAt then
        State.nextWorldCupRewardCheckAt = now + WORLD_CUP_REWARD_CHECK_INTERVAL
        if Runtime.collectWorldCupReward(true) then
            return
        end
    end

    -- International Cup mendapat prioritas sebelum Auto Play recovery.
    -- Saat entry terbuka, Auto Play dipause agar match berikutnya tidak mencuri
    -- kesempatan untuk menyusun dan mendaftarkan squad Cup.
    local blockAutoLoanForWorldCup = false
    if State.autoJoinWorldCup and now >= State.nextWorldCupCheckAt then
        State.nextWorldCupCheckAt = now + WORLD_CUP_CHECK_INTERVAL
        if Runtime.joinInternationalCup(true) then
            return
        end

        local phaseInfo = Runtime.getWorldCupPhase()
        local cupStatus = State.worldCupStatus
        blockAutoLoanForWorldCup = phaseInfo
            and phaseInfo.phase == "entry"
            and not (cupStatus and cupStatus.youEntered)
    elseif not State.autoJoinWorldCup and State.worldCupAutoPlayPaused then
        Runtime.restoreAutoPlayAfterWorldCup()
    end


    -- Equip Best mendapat prioritas sebelum Auto Play recovery. Saat ada kartu,
    -- upgrade, loan/training state, atau lineup yang berubah, Auto Play tetap ON
    -- di toggle tetapi backend dipause sampai AutoFillBestEleven tidak mengubah
    -- lineup lagi. Setelah stabil/semuanya sudah best, Auto Play baru dimulai lagi.
    if State.autoEquipBest and now >= State.nextAutoEquipBestAt then
        local currentSignature = Runtime.getSquadEquipSignature()
        if currentSignature ~= State.lastEquipBestSignature then
            State.nextAutoEquipBestAt = now + AUTO_EQUIP_BEST_RETRY_DELAY
            if equipBestEleven(true) then
                return
            end
        else
            State.nextAutoEquipBestAt = now + AUTO_EQUIP_BEST_RETRY_DELAY
        end
    end

    -- Recovery Auto Play diletakkan setelah Equip Best agar match baru tidak
    -- dimulai sebelum lineup selesai diperiksa dan sudah benar-benar stabil.
    if State.autoMatch
        and not State.worldCupAutoPlayPaused
        and not State.matchPlaybackActive
        and not State.settingAutoMatch
        and not State.autoMatchTransaction
        and not State.equippingBest
        and now >= State.nextAutoPlayEnsureAt
    then
        State.nextAutoPlayEnsureAt = now + AUTO_PLAY_ENSURE_DELAY
        local started = requestAutoPlayStart()
        if started and State.matchPlaybackActive then
            return
        end
    end

    -- Collect lebih dahulu supaya slot yang selesai segera tersedia lagi.
    if State.autoCollect and now >= State.nextAutoCollectAt then
        if Runtime.getReadyLoanCount() > 0 then
            State.nextAutoCollectAt = now + AUTO_ACTION_INTERVAL
            Runtime.collectAllReadyLoans(true)
            return
        end
    end

    if State.autoLoan and not blockAutoLoanForWorldCup and now >= State.nextAutoLoanAt then
        local hasFreeSlot = getLoanSlotState()
        if hasFreeSlot and getTopAvailableCard(false) then
            State.nextAutoLoanAt = now + AUTO_ACTION_INTERVAL
            Runtime.loanOutTopRarity(true)
        else
            State.nextAutoLoanAt = now + AUTO_RETRY_DELAY
        end
    end
end

function Runtime.setVisible(visible)
    State.visible = visible == true

    local window = State.window
    if not window then
        return
    end

    if State.visible then
        if type(window.Open) == "function" then
            window:Open()
        end
        refreshUI(false)
    elseif type(window.Close) == "function" then
        window:Close()
    end
end

function Runtime.rejoinCurrentServer()
    if State.rejoining then
        return false, "Rejoin sedang diproses"
    end

    State.rejoining = true
    setStatus("Rejoining current server...", COLORS.warning)

    task.spawn(function()
        local success, errorMessage = pcall(function()
            if tostring(game.JobId or "") ~= "" then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            else
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)

        if not success then
            State.rejoining = false
            setStatus("Rejoin gagal: " .. tostring(errorMessage), COLORS.danger)
        end
    end)

    return true
end

function Runtime.loadWindUI()
    local success, result = pcall(function()
        return loadstring(game:HttpGet(
            "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
        ))()
    end)

    if not success or type(result) ~= "table" then
        error("Gagal memuat WindUI: " .. tostring(result))
    end

    return result
end

Runtime.getThreadIdentityFunctions = function()
    local setter = nil
    local getter = nil

    if type(Environment) == "table" then
        setter = Environment.setthreadidentity
            or Environment.set_thread_identity
            or Environment.setidentity
        getter = Environment.getthreadidentity
            or Environment.get_thread_identity
            or Environment.getidentity
    end

    if type(setter) ~= "function" then
        setter = type(setthreadidentity) == "function" and setthreadidentity
            or type(setidentity) == "function" and setidentity
            or nil
    end

    if type(getter) ~= "function" then
        getter = type(getthreadidentity) == "function" and getthreadidentity
            or type(getidentity) == "function" and getidentity
            or nil
    end

    return setter, getter
end

Runtime.safeWindUICall = function(methodName, callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local args = table.pack(...)
    local success, result = pcall(callback, table.unpack(args, 1, args.n))
    if success then
        return true, result
    end

    local firstError = tostring(result)
    local lowerError = string.lower(firstError)
    local isCapabilityError = string.find(lowerError, "capability", 1, true) ~= nil
        or string.find(lowerError, "current thread cannot access", 1, true) ~= nil
        or string.find(lowerError, "lacking capability", 1, true) ~= nil

    if isCapabilityError then
        local setter, getter = Runtime.getThreadIdentityFunctions()
        if type(setter) == "function" then
            local previousIdentity = nil

            if type(getter) == "function" then
                local identitySuccess, identity = pcall(getter)
                if identitySuccess then
                    previousIdentity = identity
                end
            end

            -- Identity 8 is commonly exposed by executors as the highest
            -- available script context. Failure is caught and never reaches Output.
            pcall(setter, 8)
            success, result = pcall(callback, table.unpack(args, 1, args.n))

            if previousIdentity ~= nil then
                pcall(setter, previousIdentity)
            end

            if success then
                return true, result
            end
        end
    end

    State.uiCapabilityFailures += 1
    State.lastUiCapabilityMethod = tostring(methodName or "unknown")
    State.lastUiCapabilityError = tostring(result or firstError)

    return false, nil
end

Runtime.guardWindUIObject = function(object)
    if type(object) ~= "table" or object.__xSansCapabilityGuarded then
        return object
    end

    object.__xSansCapabilityGuarded = true

    local methods = {
        "SetDesc",
        "SetTitle",
        "Set",
        "Lock",
        "Unlock",
        "Select",
        "Refresh",
        "Open",
        "Close",
        "Toggle",
        "Destroy",
    }

    for _, methodName in ipairs(methods) do
        local original = object[methodName]
        if type(original) == "function" then
            object[methodName] = function(selfOrFirst, ...)
                local arguments

                if selfOrFirst == object then
                    arguments = table.pack(...)
                else
                    arguments = table.pack(selfOrFirst, ...)
                end

                local success, result = Runtime.safeWindUICall(
                    methodName,
                    function()
                        return original(object, table.unpack(arguments, 1, arguments.n))
                    end
                )

                if success then
                    return result
                end

                -- Keep chained WindUI calls harmless when the executor does not
                -- grant Plugin capability to the current callback thread.
                return object
            end
        end
    end

    return object
end

function Runtime.getElementBaseFrame(element)
    if type(element) ~= "table" then
        return nil
    end

    return element.ParagraphFrame
        or element.ButtonFrame
        or element.ToggleFrame
        or element.DropdownFrame
        or element.KeybindFrame
        or element.SectionFrame
end

function Runtime.compactElement(element, titleSize, descSize)
    -- Keep WindUI's native layout and padding. Only normalize typography so
    -- cards, toggles, and dropdowns stay readable without clipping.
    local frame = Runtime.getElementBaseFrame(element)
    local ui = frame and frame.UIElements

    if not ui then
        return element
    end

    if ui.Title and ui.Title:IsA("TextLabel") then
        ui.Title.TextSize = titleSize or 15
    end

    if ui.Desc and ui.Desc:IsA("TextLabel") then
        ui.Desc.TextSize = descSize or 13
    end

    return element
end

Runtime.applyDropdownTextSize = function(dropdown)
    if not dropdown then
        return
    end

    local selectedSize = tonumber(dropdown.FriendlySelectedTextSize) or 12
    local itemSize = tonumber(dropdown.FriendlyItemTextSize) or 12
    local descSize = math.max(9, itemSize - 1)

    local control = dropdown.UIElements and dropdown.UIElements.Dropdown
    if control then
        pcall(function()
            control.Size = UDim2.new(0, tonumber(dropdown.FriendlyControlWidth) or 184, 0, 36)

            local frame = control:FindFirstChild("Frame")
            local inner = frame and frame:FindFirstChild("Frame")
            local label = inner and inner:FindFirstChildWhichIsA("TextLabel")
            if label then
                label.TextSize = selectedSize
            end
        end)
    end

    for _, item in pairs(dropdown.Tabs or {}) do
        pcall(function()
            local tabItem = item.UIElements and item.UIElements.TabItem
            local outerFrame = tabItem and tabItem:FindFirstChild("Frame")
            local titleFrame = outerFrame and outerFrame:FindFirstChild("Title")

            if titleFrame then
                local titleLabel = titleFrame:FindFirstChildWhichIsA("TextLabel")
                if titleLabel then
                    titleLabel.TextSize = itemSize
                end

                local descLabel = titleFrame:FindFirstChild("Desc")
                if descLabel and descLabel:IsA("TextLabel") then
                    descLabel.TextSize = descSize
                end
            end
        end)
    end

    local menuCanvas = dropdown.UIElements and dropdown.UIElements.MenuCanvas
    if menuCanvas then
        pcall(function()
            for _, descendant in ipairs(menuCanvas:GetDescendants()) do
                if descendant:IsA("TextBox") then
                    descendant.TextSize = itemSize
                end
            end
        end)
    end
end

Runtime.setDropdownTextSize = function(dropdown, selectedSize, itemSize, controlWidth)
    if not dropdown then
        return dropdown
    end

    dropdown.FriendlySelectedTextSize = tonumber(selectedSize) or 12
    dropdown.FriendlyItemTextSize = tonumber(itemSize) or 12
    dropdown.FriendlyControlWidth = tonumber(controlWidth) or 184

    if not dropdown.__friendlyTextWrapped then
        dropdown.__friendlyTextWrapped = true

        local originalSelect = dropdown.Select
        if type(originalSelect) == "function" then
            dropdown.Select = function(selfOrItems, maybeItems)
                local items = selfOrItems == dropdown and maybeItems or selfOrItems
                local result = originalSelect(dropdown, items)
                task.defer(function()
                    Runtime.applyDropdownTextSize(dropdown)
                end)
                return result
            end
        end

        local originalRefresh = dropdown.Refresh
        if type(originalRefresh) == "function" then
            dropdown.Refresh = function(selfOrValues, maybeValues)
                local values = selfOrValues == dropdown and maybeValues or selfOrValues
                local result = originalRefresh(dropdown, values)
                task.defer(function()
                    Runtime.applyDropdownTextSize(dropdown)
                end)
                return result
            end
        end
    end

    Runtime.applyDropdownTextSize(dropdown)
    return dropdown
end

function Runtime.compactDropdown(dropdown)
    Runtime.compactElement(dropdown, 15, 13)
    return Runtime.setDropdownTextSize(dropdown, 12, 12, 184)
end

function Runtime.selectDashboardTab()
    local dashboardTab = State.dashboardTab
    if dashboardTab and type(dashboardTab.Select) == "function" then
        dashboardTab:Select()
    elseif State.window and type(State.window.SelectTab) == "function" then
        State.window:SelectTab(1)
    end
end

updateConfigManagerUI = function()
    local supportText = State.configSupported and "SUPPORTED" or "UNSUPPORTED"
    local fileState = configFileExists() and "tersimpan" or "belum ada"
    local dirtyText = State.configDirty and " • perubahan belum disimpan" or ""

    if State.configParagraph and type(State.configParagraph.SetDesc) == "function" then
        State.configParagraph:SetDesc(string.format(
            "%s • File %s • Auto Save %s • Auto Load %s%s\n%s",
            supportText,
            fileState,
            State.autoSave and "ON" or "OFF",
            State.autoLoad and "ON" or "OFF",
            dirtyText,
            CONFIG_FILE
        ))
    end

    if State.autoSaveToggle and type(State.autoSaveToggle.Set) == "function"
        and State.autoSaveToggle.Value ~= State.autoSave
    then
        State.autoSaveToggle:Set(State.autoSave, false)
    end

    if State.autoLoadToggle and type(State.autoLoadToggle.Set) == "function"
        and State.autoLoadToggle.Value ~= State.autoLoad
    then
        State.autoLoadToggle:Set(State.autoLoad, false)
    end

    setElementLocked(State.saveConfigButton, not State.configSupported)
    setElementLocked(State.loadConfigButton, not State.configSupported or not configFileExists())
    setElementLocked(State.autoSaveToggle, not State.configSupported)
    setElementLocked(State.autoLoadToggle, not State.configSupported)
end

function Runtime.uiCard(tab, options)
    options = options or {}
    options.Size = options.Size or "Small"

    local element = Runtime.compactElement(tab:Paragraph(options), 14, 12)
    return Runtime.guardWindUIObject(element)
end

function Runtime.uiButton(container, options)
    options = options or {}

    local callback = options.Callback or function() end
    local actionButton

    options.Size = options.Size or "Small"
    options.Desc = nil
    options.Color = options.Color or COLORS.primary
    options.Justify = options.Justify or "Center"
    options.IconAlign = options.IconAlign or "Left"
    options.Icon = options.Icon or "mouse-pointer-click"
    options.Callback = function()
        if actionButton and actionButton.FriendlyLocked then
            return
        end
        callback()
    end

    actionButton = container:Button(options)
    actionButton.__friendlyAction = true
    actionButton.FriendlyLocked = options.Locked == true

    return Runtime.guardWindUIObject(actionButton)
end

function Runtime.uiToggle(tab, options)
    local element = Runtime.compactElement(tab:Toggle(options), 14, 12)
    return Runtime.guardWindUIObject(element)
end

function Runtime.uiDropdown(tab, options)
    local element = Runtime.compactDropdown(tab:Dropdown(options))
    return Runtime.guardWindUIObject(element)
end

function Runtime.createHomeTab(Window)
    local tab = Window:Tab({
        Title = "Home",
        Icon = "house",
        IconSize = 16,
    })
    State.dashboardTab = tab

    State.summaryParagraph = Runtime.uiCard(tab, {
        Title = "Overview",
        Desc = "Loading...",
        Image = "layout-dashboard",
        ImageSize = 20,
    })

    tab:Space()
    State.loanButton = Runtime.uiButton(tab, {
        Title = "Loan Best",
        Icon = "send",
        Callback = function()
            if State.loanButtonEnabled then
                Runtime.loanOutTopRarity(false)
            end
        end,
    })

    State.collectButton = Runtime.uiButton(tab, {
        Title = "Collect Loans",
        Icon = "package-check",
        Callback = function()
            if State.collectButtonEnabled then
                Runtime.collectAllReadyLoans(false)
            end
        end,
    })

    State.statusParagraph = Runtime.uiCard(tab, {
        Title = "Status",
        Desc = "Connecting...",
        Image = "activity",
        ImageSize = 19,
    })

    State.dashboardParagraph = Runtime.uiCard(tab, {
        Title = "Session",
        Desc = "No activity yet",
        Image = "chart-no-axes-combined",
        ImageSize = 19,
    })

    return tab
end

function Runtime.createLoansTab(Window)
    local tab = Window:Tab({
        Title = "Loans",
        Icon = "handshake",
        IconSize = 16,
    })
    State.configurationTab = tab

    State.configurationParagraph = Runtime.uiCard(tab, {
        Title = "Loan Setup",
        Desc = "Loading...",
        Image = "sliders-horizontal",
        ImageSize = 19,
    })

    local durationValues = {}
    for _, minutes in ipairs(State.durationOptions) do
        durationValues[#durationValues + 1] = Runtime.getDurationLabel(minutes)
    end

    State.durationDropdown = Runtime.uiDropdown(tab, {
        Title = "Duration",
        Desc = "Durasi loan otomatis.",
        Values = durationValues,
        Value = Runtime.getDurationLabel(State.selectedDuration),
        SearchBarEnabled = false,
        Callback = function(selected)
            if State.syncingConfiguration then
                return
            end

            local selectedText = type(selected) == "table" and selected.Title or selected
            for _, minutes in ipairs(State.durationOptions) do
                if Runtime.getDurationLabel(minutes) == tostring(selectedText) then
                    State.selectedDuration = minutes
                    PersistentConfig.duration = minutes
                    State.nextAutoLoanAt = 0
                    State.cachedTopCard = nil
                    State.configurationFromUI = true
                    updateConfigurationVisuals()
                    refreshUI(false)
                    requestConfigSave()
                    setStatus("Durasi Auto Loan: " .. getDurationLabel(minutes), COLORS.success)
                    break
                end
            end
        end,
    })

    local rarityValues = {}
    for _, rarity in ipairs(State.rarityOptions) do
        rarityValues[#rarityValues + 1] = tostring(rarity):gsub("WorldClass", "World Class")
    end

    State.rarityDropdown = Runtime.uiDropdown(tab, {
        Title = "Rarity",
        Desc = "Kartu yang boleh dipinjamkan.",
        Values = rarityValues,
        Value = getSelectedRarityLabels(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        Callback = function(selectedValues)
            if State.syncingConfiguration then
                return
            end

            local enabled = {}
            if type(selectedValues) == "table" then
                for _, selected in ipairs(selectedValues) do
                    local selectedText = type(selected) == "table" and selected.Title or selected
                    enabled[rarityFromDisplayLabel(selectedText)] = true
                end
            elseif selectedValues ~= nil then
                enabled[rarityFromDisplayLabel(selectedValues)] = true
            end

            for _, rarity in ipairs(State.rarityOptions) do
                State.rarityWhitelist[rarity] = enabled[rarity] == true
            end

            PersistentConfig.rarityWhitelist = State.rarityWhitelist
            State.cachedTopCard = nil
            State.nextAutoLoanAt = 0
            State.configurationFromUI = true
            updateConfigurationVisuals()
            refreshUI(true)
            requestConfigSave()
        end,
    })

    tab:Space()
    Runtime.uiButton(tab, {
        Title = "Select All",
        Icon = "list-checks",
        Callback = function()
            for _, rarity in ipairs(State.rarityOptions) do
                State.rarityWhitelist[rarity] = true
            end
            PersistentConfig.rarityWhitelist = State.rarityWhitelist
            State.cachedTopCard = nil
            updateConfigurationVisuals()
            refreshUI(true)
            requestConfigSave()
        end,
    })

    Runtime.uiButton(tab, {
        Title = "Clear",
        Icon = "eraser",
        Callback = function()
            for _, rarity in ipairs(State.rarityOptions) do
                State.rarityWhitelist[rarity] = false
            end
            PersistentConfig.rarityWhitelist = State.rarityWhitelist
            State.cachedTopCard = nil
            updateConfigurationVisuals()
            refreshUI(true)
            requestConfigSave()
        end,
    })

    State.loanListParagraph = Runtime.uiCard(tab, {
        Title = "Active Loans",
        Desc = "No active loans.",
        Image = "list",
        ImageSize = 19,
    })

    return tab
end

function Runtime.createAutomationTab(Window)
    local tab = Window:Tab({
        Title = "Automation",
        Icon = "bot",
        IconSize = 16,
    })
    State.automationTab = tab

    State.autoLoanToggle = Runtime.uiToggle(tab, {
        Title = "Auto Loan",
        Desc = "Isi slot loan otomatis.",
        Icon = "send",
        IconSize = 18,
        Value = State.autoLoan,
        Callback = setAutoLoanEnabled,
    })

    State.autoCollectToggle = Runtime.uiToggle(tab, {
        Title = "Auto Collect",
        Desc = "Collect loan yang selesai.",
        Icon = "package-check",
        IconSize = 18,
        Value = State.autoCollect,
        Callback = setAutoCollectEnabled,
    })

    State.autoMatchToggle = Runtime.uiToggle(tab, {
        Title = "Auto Play",
        Desc = "Main match otomatis di background.",
        Icon = "play",
        IconSize = 18,
        Value = State.autoMatch,
        Callback = setAutoPlayEnabled,
    })


    State.autoClaimPlayTimeRewardsToggle = Runtime.uiToggle(tab, {
        Title = "Auto Claim Playtime",
        Desc = "Claim reward playtime yang sudah siap.",
        Icon = "clock",
        IconSize = 18,
        Value = State.autoClaimPlayTimeRewards,
        Callback = setAutoClaimPlayTimeRewardsEnabled,
    })

    State.autoClaimDailyRewardToggle = Runtime.uiToggle(tab, {
        Title = "Auto Claim Daily Reward",
        Desc = "Claim Daily Reward saat tersedia.",
        Icon = "gift",
        IconSize = 18,
        Value = State.autoClaimDailyReward,
        Callback = Runtime.setAutoClaimDailyRewardEnabled,
    })

    State.autoEquipBestToggle = Runtime.uiToggle(tab, {
        Title = "Auto Equip Best",
        Desc = "Update Starting Eleven saat perlu.",
        Icon = "users",
        IconSize = 18,
        Value = State.autoEquipBest,
        Callback = setAutoEquipBestEnabled,
    })

    State.autoPrestigeToggle = Runtime.uiToggle(tab, {
        Title = "Auto Prestige",
        Desc = "Prestige saat semua syarat terpenuhi.",
        Icon = "trophy",
        IconSize = 18,
        Value = State.autoPrestige,
        Callback = setAutoPrestigeEnabled,
    })

    return tab
end

function Runtime.createPacksTab(Window)
    local tab = Window:Tab({
        Title = "Packs",
        Icon = "package-open",
        IconSize = 16,
    })
    State.packsTab = tab

    if #State.packShopTiers == 0 then
        Runtime.refreshPackShopTiers()
    end

    State.packShopParagraph = Runtime.uiCard(tab, {
        Title = "Pack Shop",
        Desc = "Loading...",
        Image = "shopping-bag",
        ImageSize = 19,
    })

    local packShopValues = {}
    local selectedPackShopValues = {}
    for _, tier in ipairs(State.packShopTiers) do
        local label = State.packShopTierToLabel[tier] or tier
        packShopValues[#packShopValues + 1] = label
        if State.packBuyWhitelist[tier] == true then
            selectedPackShopValues[#selectedPackShopValues + 1] = label
        end
    end

    local packWhitelistDropdownReady = false
    State.packBuyWhitelistDropdown = Runtime.uiDropdown(tab, {
        Title = "Auto Buy Whitelist",
        Desc = "Pack yang boleh dibeli otomatis.",
        Values = packShopValues,
        Value = selectedPackShopValues,
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 280,
        Callback = function(selectedValues)
            if not packWhitelistDropdownReady or State.syncingConfiguration then
                return
            end

            local enabled = {}
            if type(selectedValues) == "table" then
                for _, selected in ipairs(selectedValues) do
                    local label = type(selected) == "table" and selected.Title or selected
                    local tier = State.packShopLabelToTier[tostring(label)]
                    if tier then
                        enabled[tier] = true
                    end
                end
            elseif selectedValues ~= nil then
                local tier = State.packShopLabelToTier[tostring(selectedValues)]
                if tier then
                    enabled[tier] = true
                end
            end

            for _, tier in ipairs(State.packShopTiers) do
                State.packBuyWhitelist[tier] = enabled[tier] == true
            end

            PersistentConfig.packBuyWhitelist = State.packBuyWhitelist
            State.nextAutoBuyPackAt = 0
            State.packUiDirty = true
            State.uiRefreshRequested = true
            requestConfigSave()
        end,
    })
    Runtime.setDropdownTextSize(State.packBuyWhitelistDropdown, 11, 11, 200)
    task.delay(0.25, function()
        packWhitelistDropdownReady = true
    end)

    State.autoBuyPacksToggle = Runtime.uiToggle(tab, {
        Title = "Auto Buy Packs",
        Desc = "Beli pack whitelist secara otomatis.",
        Icon = "shopping-cart",
        IconSize = 18,
        Value = State.autoBuyPacks,
        Callback = Runtime.setAutoBuyPacksEnabled,
    })

    State.packBuyPrestigePriorityToggle = Runtime.uiToggle(tab, {
        Title = "Prestige Priority",
        Desc = "Simpan Coins requirement Prestige.",
        Icon = "trophy",
        IconSize = 18,
        Value = State.packBuyPrestigePriority,
        Callback = Runtime.setPackBuyPrestigePriorityEnabled,
    })

    State.packBuyButton = Runtime.uiButton(tab, {
        Title = "Buy 1 Pack Now",
        Icon = "shopping-cart",
        Callback = function()
            Runtime.buySelectedPacks(false, 1)
        end,
    })

    tab:Space()

    State.packSummaryParagraph = Runtime.uiCard(tab, {
        Title = "Pack Session",
        Desc = "Loading...",
        Image = "package-search",
        ImageSize = 19,
    })

    local packPickDropdownReady = false
    State.packPickModeDropdown = Runtime.uiDropdown(tab, {
        Title = "Pick Pack Selection",
        Desc = "Pilih otomatis satu dari tiga kartu.",
        Values = {"Best Rarity", "Best OVR", "Best Rarity + OVR"},
        Value = packPickModeLabel(State.packPickMode),
        SearchBarEnabled = false,
        Callback = function(selected)
            if not packPickDropdownReady or State.syncingConfiguration then
                return
            end
            local selectedText = type(selected) == "table" and selected.Title or selected
            setPackPickMode(selectedText)
        end,
    })
    Runtime.setDropdownTextSize(State.packPickModeDropdown, 12, 11, 184)
    task.delay(0.25, function()
        packPickDropdownReady = true
    end)

    State.autoOpenPacksToggle = Runtime.uiToggle(tab, {
        Title = "Auto Open Packs",
        Desc = "Buka pack yang tersedia.",
        Icon = "package",
        IconSize = 18,
        Value = State.autoOpenPacks,
        Callback = setAutoOpenPacksEnabled,
    })

    State.skipPackAnimationToggle = Runtime.uiToggle(tab, {
        Title = "Skip Pack Animation",
        Desc = "Direct open tanpa overlay.",
        Icon = "fast-forward",
        IconSize = 18,
        Value = State.skipPackAnimation,
        Callback = Runtime.setSkipPackAnimationEnabled,
    })

    State.instantPacksToggle = Runtime.uiToggle(tab, {
        Title = "Instant Packs",
        Desc = "Batch open jika Instant Open pass aktif.",
        Icon = "zap",
        IconSize = 18,
        Value = State.instantPacks,
        Callback = Runtime.setInstantPacksEnabled,
    })

    local rarityValues = {}
    local selectedRarities = {}
    for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
        local label = rarity == "WorldClass" and "World Class" or rarity
        rarityValues[#rarityValues + 1] = label
        if State.packLogRarityWhitelist[rarity] ~= false then
            selectedRarities[#selectedRarities + 1] = label
        end
    end

    local packLogDropdownReady = false
    State.packLogRarityDropdown = Runtime.uiDropdown(tab, {
        Title = "Log Rarity",
        Desc = "Rarity yang tampil di session log.",
        Values = rarityValues,
        Value = selectedRarities,
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        Callback = function(selectedValues)
            if not packLogDropdownReady or State.syncingConfiguration then
                return
            end

            local enabled = {}
            if type(selectedValues) == "table" then
                for _, selected in ipairs(selectedValues) do
                    local label = type(selected) == "table" and selected.Title or selected
                    enabled[rarityFromDisplayLabel(label)] = true
                end
            elseif selectedValues ~= nil then
                enabled[rarityFromDisplayLabel(selectedValues)] = true
            end

            for _, rarity in ipairs(RARITY_DISPLAY_ORDER) do
                State.packLogRarityWhitelist[rarity] = enabled[rarity] == true
            end

            PersistentConfig.packLogRarityWhitelist = State.packLogRarityWhitelist
            State.packUiDirty = true
            State.uiRefreshRequested = true
            requestConfigSave()
        end,
    })
    Runtime.setDropdownTextSize(State.packLogRarityDropdown, 12, 11, 184)
    task.delay(0.25, function()
        packLogDropdownReady = true
    end)

    Runtime.uiButton(tab, {
        Title = "Open Packs Now",
        Icon = "package-open",
        Callback = function()
            Runtime.openOwnedPacksAutomatically(false)
        end,
    })

    Runtime.uiButton(tab, {
        Title = "Clear Session Log",
        Icon = "trash-2",
        Callback = function()
            Runtime.clearPackSessionLog(true)
        end,
    })

    State.packLogParagraph = Runtime.uiCard(tab, {
        Title = "Card Results",
        Desc = "Belum ada card.",
        Image = "scroll-text",
        ImageSize = 19,
    })

    State.packUiDirty = true
    State.uiRefreshRequested = true
    task.defer(function()
        if State.running then
            Runtime.updatePackUI()
        end
    end)
    return tab
end

function Runtime.createPrestigeTab(Window)
    local tab = Window:Tab({
        Title = "Prestige",
        Icon = "trophy",
        IconSize = 16,
    })
    State.prestigeTab = tab

    State.prestigeParagraph = Runtime.uiCard(tab, {
        Title = "Prestige",
        Desc = "Check status to continue.",
        Image = "trophy",
        ImageSize = 20,
    })

    State.prestigeGateParagraphs = {}
    for gateIndex = 1, 6 do
        local gateParagraph = Runtime.uiCard(tab, {
            Title = "Requirement",
            Desc = "Waiting...",
        })

        if gateParagraph.ElementFrame then
            gateParagraph.ElementFrame.Visible = false
        end

        State.prestigeGateParagraphs[#State.prestigeGateParagraphs + 1] = gateParagraph
    end

    tab:Space()
    Runtime.uiButton(tab, {
        Title = "Check",
        Icon = "refresh-cw",
        Callback = function()
            local info, errorMessage = Runtime.fetchPrestigeInfo()
            if info then
                updatePrestigeParagraph()
                setStatus("Prestige info berhasil diperbarui.", COLORS.success)
            else
                setStatus("Gagal mengecek prestige: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    })

    State.prestigeButton = Runtime.uiButton(tab, {
        Title = "Prestige Now",
        Icon = "sparkles",
        Callback = function()
            Runtime.performPrestige(false)
        end,
    })

    return tab
end

function Runtime.createWorldCupTab(Window)
    local tab = Window:Tab({
        Title = "Cup",
        Icon = "trophy",
        IconSize = 16,
    })
    State.worldCupTab = tab

    State.worldCupParagraph = Runtime.uiCard(tab, {
        Title = "International Cup",
        Desc = "Check status to continue.",
        Image = "trophy",
        ImageSize = 20,
    })

    State.worldCupPreviewParagraph = Runtime.uiCard(tab, {
        Title = "Cup Squad",
        Desc = "Squad preview unavailable.",
        Image = "users",
        ImageSize = 19,
    })

    State.worldCupSquadDropdown = Runtime.uiDropdown(tab, {
        Title = "Squad Mode",
        Desc = "Sumber squad untuk Cup.",
        Values = {"Last Team", "Best Rarity / OVR"},
        Value = worldCupSquadModeLabel(State.worldCupSquadMode),
        SearchBarEnabled = false,
        Callback = function(selected)
            if State.syncingConfiguration then
                return
            end
            local selectedText = type(selected) == "table" and selected.Title or selected
            setWorldCupSquadMode(selectedText)
        end,
    })

    State.autoJoinWorldCupToggle = Runtime.uiToggle(tab, {
        Title = "Auto Join",
        Desc = "Join saat entry terbuka.",
        Icon = "trophy",
        IconSize = 18,
        Value = State.autoJoinWorldCup,
        Callback = setAutoJoinWorldCupEnabled,
    })

    State.fillWorldCupVisualToggle = Runtime.uiToggle(tab, {
        Title = "Fill Visual Squad",
        Desc = "Tampilkan squad di menu Cup.",
        Icon = "users",
        IconSize = 18,
        Value = State.fillWorldCupVisualBeforeJoin,
        Callback = setFillWorldCupVisualEnabled,
    })

    State.autoCollectWorldCupRewardsToggle = Runtime.uiToggle(tab, {
        Title = "Auto Collect Reward",
        Desc = "Claim reward saat siap.",
        Icon = "gift",
        IconSize = 18,
        Value = State.autoCollectWorldCupRewards,
        Callback = setAutoCollectWorldCupRewardsEnabled,
    })

    State.autoPickupSpawnedPacksToggle = Runtime.uiToggle(tab, {
        Title = "Auto Collect PackDrop",
        Desc = "Ambil hadiah PackDrop.",
        Icon = "package-check",
        IconSize = 18,
        Value = State.autoPickupSpawnedPacks,
        Callback = setAutoPickupSpawnedPacksEnabled,
    })

    tab:Space()
    State.worldCupCheckButton = Runtime.uiButton(tab, {
        Title = "Check Status",
        Icon = "refresh-cw",
        Callback = function()
            local status, errorMessage = Runtime.fetchWorldCupStatus()
            if status then
                setStatus("Status International Cup berhasil diperbarui.", COLORS.success)
                refreshUI(true)
            else
                setStatus("Gagal mengecek International Cup: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    })

    State.worldCupJoinButton = Runtime.uiButton(tab, {
        Title = "Join Cup",
        Icon = "trophy",
        Callback = function()
            Runtime.joinInternationalCup(false)
        end,
    })

    State.worldCupVisualFillButton = Runtime.uiButton(tab, {
        Title = "Fill Visual Squad",
        Icon = "users",
        Callback = function()
            task.spawn(function()
                local status = State.worldCupStatus or Runtime.fetchWorldCupStatus()
                local team, teamError = Runtime.selectWorldCupTeam(status)
                if not team then
                    setStatus("Tidak dapat menyiapkan squad visual: " .. tostring(teamError), COLORS.warning)
                    return
                end
                Runtime.fillWorldCupVisualSquad(team, false)
            end)
        end,
    })

    State.worldCupCollectButton = Runtime.uiButton(tab, {
        Title = "Collect Cup Reward",
        Icon = "gift",
        Callback = function()
            Runtime.collectWorldCupReward(false)
        end,
    })

    State.spawnedPackPickupButton = Runtime.uiButton(tab, {
        Title = "Collect PackDrop",
        Icon = "package-check",
        Callback = function()
            Runtime.pickupSpawnedPacks(false)
        end,
    })

    return tab
end

function Runtime.createMovementTab(Window)
    local tab = Window:Tab({
        Title = "Movement",
        Icon = "navigation",
        IconSize = 16,
    })
    State.movementTab = tab

    State.movementParagraph = Runtime.uiCard(tab, {
        Title = "Movement",
        Desc = "Detecting base and conveyor...",
        Image = "navigation",
        ImageSize = 19,
    })

    State.lockPositionToggle = Runtime.uiToggle(tab, {
        Title = "Anti Player Collision",
        Desc = "Cegah player lain mendorong karakter.",
        Icon = "shield",
        IconSize = 18,
        Value = State.lockPosition,
        Callback = Runtime.setLockPositionEnabled,
    })

    State.autoConveyorToggle = Runtime.uiToggle(tab, {
        Title = "Auto Conveyor",
        Desc = "Kembali saat keluar dari conveyor.",
        Icon = "refresh-cw",
        IconSize = 18,
        Value = State.autoConveyor,
        Callback = Runtime.setAutoConveyorEnabled,
    })

    tab:Space()
    State.backToBaseButton = Runtime.uiButton(tab, {
        Title = "Back to Base",
        Icon = "house",
        Callback = function()
            Runtime.teleportBackToBase(false)
        end,
    })

    State.teleportConveyorButton = Runtime.uiButton(tab, {
        Title = "Go to Conveyor",
        Icon = "navigation",
        Callback = function()
            Runtime.teleportToConveyor(false)
        end,
    })

    return tab
end

function Runtime.createSettingsTab(Window)
    local tab = Window:Tab({
        Title = "Settings",
        Icon = "settings",
        IconSize = 16,
    })
    State.settingsTab = tab

    State.configParagraph = Runtime.uiCard(tab, {
        Title = "Config",
        Desc = "Checking file support...",
        Image = "save",
        ImageSize = 19,
    })

    State.windowKeybindControl = Runtime.compactElement(tab:Keybind({
        Title = "Window Keybind",
        Desc = "Tombol buka/tutup UI.",
        Value = State.windowKeybind,
        Callback = function(keyName)
            local normalized = normalizeKeybindName(keyName)
            local keyCode = Enum.KeyCode[normalized]
            if keyCode then
                State.windowKeybind = normalized
                Window:SetToggleKey(keyCode)
                requestConfigSave()
                setStatus("Window keybind diubah menjadi " .. normalized, COLORS.success)
            end
        end,
    }), 14, 12)

    State.autoSaveToggle = Runtime.uiToggle(tab, {
        Title = "Auto Save",
        Desc = "Simpan config saat berubah.",
        Icon = "save",
        IconSize = 18,
        Value = State.autoSave,
        Callback = function(enabled)
            setAutoSaveEnabled(enabled)
            setStatus(enabled and "Auto Save diaktifkan." or "Auto Save dinonaktifkan.", enabled and COLORS.success or COLORS.muted)
        end,
    })

    State.autoLoadToggle = Runtime.uiToggle(tab, {
        Title = "Auto Load",
        Desc = "Muat config saat startup.",
        Icon = "folder-down",
        IconSize = 18,
        Value = State.autoLoad,
        Callback = function(enabled)
            setAutoLoadEnabled(enabled)
            setStatus(enabled and "Auto Load diaktifkan." or "Auto Load dinonaktifkan.", enabled and COLORS.success or COLORS.muted)
        end,
    })

    State.antiAfkToggle = Runtime.uiToggle(tab, {
        Title = "Anti AFK",
        Desc = "Cegah idle kick.",
        Icon = "keyboard",
        IconSize = 18,
        Value = State.antiAfk,
        Callback = Runtime.setAntiAfkEnabled,
    })

    tab:Space()
    State.saveConfigButton = Runtime.uiButton(tab, {
        Title = "Save",
        Icon = "save",
        Callback = function()
            local success, errorMessage = saveConfigToDisk()
            if success then
                setStatus("Config berhasil disimpan.", COLORS.success)
            else
                setStatus("Gagal menyimpan config: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    })

    State.loadConfigButton = Runtime.uiButton(tab, {
        Title = "Load",
        Icon = "folder-down",
        Callback = function()
            local success, errorMessage = loadConfigFromDisk()
            if success then
                setStatus("Config berhasil dimuat dan diterapkan.", COLORS.success)
            else
                setStatus("Gagal memuat config: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    })

    tab:Space()
    State.rejoinButton = Runtime.uiButton(tab, {
        Title = "Rejoin",
        Icon = "refresh-cw",
        Callback = Runtime.rejoinCurrentServer,
    })

    Runtime.uiButton(tab, {
        Title = "Refresh Data",
        Icon = "refresh-cw",
        Callback = function()
            State.cachedTopCard = nil
            Runtime.fetchPrestigeInfo()
            refreshUI(true)
            setStatus("Data berhasil di-refresh.", COLORS.success)
        end,
    })

    Runtime.uiButton(tab, {
        Title = "Reset Session Stats",
        Desc = "Reset statistik Auto Loan.",
        Icon = "rotate-ccw",
        Callback = function()
            State.stats.autoSent = 0
            State.stats.autoCollected = 0
            State.stats.autoIncome = 0
            State.stats.failures = 0
            State.stats.lastAction = "Dashboard reset"
            State.stats.lastIncome = 0
            State.stats.startedAt = os.time()
            table.clear(State.autoLoanedIds)
            updateDashboardUI()
            setStatus("Statistik sesi di-reset.", COLORS.success)
        end,
    })

    return tab
end

function Runtime.buildGui()
    local WindUI = Runtime.loadWindUI()
    State.windUI = WindUI

    local Window = WindUI:CreateWindow({
        Title = HUB_TITLE,
        Author = "xSansHUB",
        Folder = "xSansHUB_LoanOutManager",
        Icon = "handshake",
        Theme = "Indigo",
        ToggleKey = Enum.KeyCode[State.windowKeybind] or Enum.KeyCode.G,
        Size = UDim2.fromOffset(860, 620),
        MinSize = Vector2.new(720, 500),
        MaxSize = Vector2.new(1080, 780),
        Resizable = true,
        AutoScale = true,
        NewElements = true,
        Radius = 8,
        ElementsRadius = 7,
        IconSize = 17,
        TopBarButtonIconSize = 11,
        SideBarWidth = 150,
        HideSearchBar = true,
        ScrollBarEnabled = true,
        OpenButton = {
            Title = HUB_TITLE,
            Icon = "handshake",
            Enabled = true,
            Draggable = true,
            OnlyMobile = false,
        },
        User = {
            Enabled = false,
            Anonymous = false,
        },
    })

    if not Window then
        error("WindUI gagal membuat window. Hancurkan window lama lalu jalankan ulang script.")
    end

    Window = Runtime.guardWindUIObject(Window)
    State.window = Window
    Environment.LoanOutGUIWindWindow = Window

    Window.Gap = 8
    if Window.ElementConfig then
        Window.ElementConfig.UIPadding = 10
        Window.ElementConfig.UICorner = 8
    end

    Window:Tag({
        Title = "Toggle: " .. tostring(State.windowKeybind),
        Icon = "keyboard",
        Border = true,
    })

    Window:OnOpen(function()
        State.visible = true
        task.defer(function()
            Runtime.selectDashboardTab()
            refreshUI(false)
        end)
    end)

    Window:OnClose(function()
        State.visible = false
    end)

    Runtime.createHomeTab(Window)
    Runtime.createLoansTab(Window)
    Runtime.createAutomationTab(Window)
    Runtime.createPacksTab(Window)
    Runtime.createPrestigeTab(Window)
    Runtime.createWorldCupTab(Window)
    Runtime.createMovementTab(Window)
    Runtime.createSettingsTab(Window)

    setCollectButton("Collect Loans", false)
    setLoanButton("Loan Best", false)
    updateAutomationButtons()
    if Runtime.updatePackShopUI then
        Runtime.updatePackShopUI()
    end
    updateConfigurationVisuals()
    updateDashboardUI()
    updatePrestigeParagraph()
    updateConfigManagerUI()

    if State.autoSave and State.configSupported and not configFileExists() then
        saveConfigToDisk()
    end

    if State.startupConfigLoaded then
        setStatus("Auto Load: config berhasil diterapkan.", COLORS.success)
    elseif State.startupConfigError then
        setStatus("Config startup gagal: " .. tostring(State.startupConfigError), COLORS.danger)
    elseif not State.configSupported then
        setStatus("File config tidak didukung executor ini.", COLORS.warning)
    else
        setStatus(State.lastStatusText, COLORS.warning)
    end

    task.defer(function()
        Runtime.selectDashboardTab()
        refreshUI(true)
    end)

    WindUI:Notify({
        Title = HUB_TITLE,
        Content = "Loaded • " .. tostring(State.windowKeybind) .. " to toggle",
        Icon = "handshake",
        Duration = 4,
    })
end


-- DataChanged sengaja tidak dihubungkan. Signal internal game menjalankan
-- callback pada free thread yang tidak memiliki capability untuk mengubah
-- Instance milik executor/WindUI. Refresh dilakukan melalui polling.
local API = {}

function API.Toggle()
    if State.window and type(State.window.Toggle) == "function" then
        State.window:Toggle()
    else
        Runtime.setVisible(not State.visible)
    end
end

function API.Show()
    Runtime.setVisible(true)
end

function API.Hide()
    Runtime.setVisible(false)
end

function API.Refresh()
    refreshUI(true)
end

function API.CollectAll()
    Runtime.collectAllReadyLoans()
end

function API.LoanTop()
    Runtime.loanOutTopRarity(false)
end

-- Backward compatibility: sekarang mengikuti durasi yang dipilih.
function API.LoanTop5Min()
    Runtime.loanOutTopRarity(false)
end

function API.SetDuration(minutes)
    minutes = tonumber(minutes)
    if not minutes then
        return false, "Duration harus berupa angka"
    end

    local valid = false
    for _, option in ipairs(State.durationOptions) do
        if option == minutes then
            valid = true
            break
        end
    end

    if not valid then
        return false, "Duration tidak tersedia di LoanConfig"
    end

    State.selectedDuration = minutes
    PersistentConfig.duration = minutes
    State.nextAutoLoanAt = 0
    updateConfigurationVisuals()
    refreshUI(false)
    requestConfigSave()
    return true
end

function API.GetDuration()
    return State.selectedDuration
end

function API.SetRarityEnabled(rarity, enabled)
    rarity = tostring(rarity)
    local known = false
    for _, option in ipairs(State.rarityOptions) do
        if option == rarity then
            known = true
            break
        end
    end

    if not known then
        return false, "Rarity tidak dikenal"
    end

    State.rarityWhitelist[rarity] = enabled == true
    PersistentConfig.rarityWhitelist = State.rarityWhitelist
    State.cachedTopCard = nil
    State.nextAutoLoanAt = 0
    updateConfigurationVisuals()
    refreshUI(true)
    requestConfigSave()
    return true
end

function API.ToggleRarity(rarity)
    rarity = tostring(rarity)
    return API.SetRarityEnabled(rarity, not isRarityWhitelisted(rarity))
end

function API.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist harus berupa table"
    end

    for _, rarity in ipairs(State.rarityOptions) do
        if whitelist[rarity] ~= nil then
            State.rarityWhitelist[rarity] = whitelist[rarity] == true
        end
    end

    PersistentConfig.rarityWhitelist = State.rarityWhitelist
    State.cachedTopCard = nil
    State.nextAutoLoanAt = 0
    updateConfigurationVisuals()
    refreshUI(true)
    requestConfigSave()
    return true
end

function API.GetWhitelist()
    local result = {}
    for _, rarity in ipairs(State.rarityOptions) do
        result[rarity] = isRarityWhitelisted(rarity)
    end
    return result
end

function API.ResetDashboard()
    State.stats.autoSent = 0
    State.stats.autoCollected = 0
    State.stats.autoIncome = 0
    State.stats.failures = 0
    State.stats.lastAction = "Dashboard reset"
    State.stats.lastIncome = 0
    State.stats.startedAt = os.time()
    table.clear(State.autoLoanedIds)
    updateDashboardUI()
end

function API.GetDashboardStats()
    return {
        autoSent = State.stats.autoSent,
        active = getTrackedAutoLoanCount(),
        autoCollected = State.stats.autoCollected,
        autoIncome = State.stats.autoIncome,
        failures = State.stats.failures,
        lastAction = State.stats.lastAction,
        lastIncome = State.stats.lastIncome,
        startedAt = State.stats.startedAt,
    }
end

function API.ToggleAutoLoan()
    setAutoLoanEnabled(not State.autoLoan)
end

function API.ToggleAutoCollect()
    setAutoCollectEnabled(not State.autoCollect)
end

function API.ToggleAutoPrestige()
    setAutoPrestigeEnabled(not State.autoPrestige)
end

function API.ToggleAutoOpenPacks()
    setAutoOpenPacksEnabled(not State.autoOpenPacks)
end

function API.ToggleSkipPackAnimation()
    return Runtime.setSkipPackAnimationEnabled(not State.skipPackAnimation)
end

function API.ToggleInstantPacks()
    return Runtime.setInstantPacksEnabled(not State.instantPacks)
end

function API.ToggleAutoBuyPacks()
    return Runtime.setAutoBuyPacksEnabled(not State.autoBuyPacks)
end

function API.TogglePackBuyPrestigePriority()
    return Runtime.setPackBuyPrestigePriorityEnabled(not State.packBuyPrestigePriority)
end


function API.ToggleAutoClaimPlayTimeRewards()
    setAutoClaimPlayTimeRewardsEnabled(not State.autoClaimPlayTimeRewards)
    return State.autoClaimPlayTimeRewards
end

function API.ToggleAutoClaimDailyReward()
    return Runtime.setAutoClaimDailyRewardEnabled(not State.autoClaimDailyReward)
end

function API.ToggleAutoEquipBest()
    setAutoEquipBestEnabled(not State.autoEquipBest)
end

function API.ToggleAutoJoinWorldCup()
    setAutoJoinWorldCupEnabled(not State.autoJoinWorldCup)
    return State.autoJoinWorldCup
end

function API.ToggleAutoCollectWorldCupRewards()
    setAutoCollectWorldCupRewardsEnabled(not State.autoCollectWorldCupRewards)
    return State.autoCollectWorldCupRewards
end

function API.ToggleFillWorldCupVisualBeforeJoin()
    setFillWorldCupVisualEnabled(not State.fillWorldCupVisualBeforeJoin)
    return State.fillWorldCupVisualBeforeJoin
end

function API.ToggleAutoPickupSpawnedPacks()
    setAutoPickupSpawnedPacksEnabled(not State.autoPickupSpawnedPacks)
    return State.autoPickupSpawnedPacks
end

function API.ToggleAutoPlay()
    return setAutoPlayEnabled(not State.autoMatch)
end

-- Alias lama agar loader/config eksternal tidak rusak.
function API.ToggleAutoMatch()
    return API.ToggleAutoPlay()
end

function API.SetAutoLoan(enabled)
    setAutoLoanEnabled(enabled)
end

function API.SetAutoCollect(enabled)
    setAutoCollectEnabled(enabled)
end

function API.SetAutoPrestige(enabled)
    setAutoPrestigeEnabled(enabled)
end

function API.SetAutoOpenPacks(enabled)
    setAutoOpenPacksEnabled(enabled)
end

function API.SetSkipPackAnimation(enabled)
    return Runtime.setSkipPackAnimationEnabled(enabled)
end

function API.SetInstantPacks(enabled)
    return Runtime.setInstantPacksEnabled(enabled)
end

function API.SetAutoBuyPacks(enabled)
    return Runtime.setAutoBuyPacksEnabled(enabled)
end

function API.SetPackBuyPrestigePriority(enabled)
    return Runtime.setPackBuyPrestigePriorityEnabled(enabled)
end

function API.SetPackPickMode(mode)
    return setPackPickMode(mode)
end

function API.GetPackPickMode()
    return State.packPickMode, packPickModeLabel(State.packPickMode)
end


function API.SetAutoClaimPlayTimeRewards(enabled)
    setAutoClaimPlayTimeRewardsEnabled(enabled)
    return State.autoClaimPlayTimeRewards
end

function API.SetAutoClaimDailyReward(enabled)
    return Runtime.setAutoClaimDailyRewardEnabled(enabled)
end

function API.SetAutoEquipBest(enabled)
    setAutoEquipBestEnabled(enabled)
end

function API.SetAutoJoinWorldCup(enabled)
    setAutoJoinWorldCupEnabled(enabled)
    return State.autoJoinWorldCup
end

function API.SetAutoCollectWorldCupRewards(enabled)
    setAutoCollectWorldCupRewardsEnabled(enabled)
    return State.autoCollectWorldCupRewards
end

function API.SetFillWorldCupVisualBeforeJoin(enabled)
    setFillWorldCupVisualEnabled(enabled)
    return State.fillWorldCupVisualBeforeJoin
end

function API.SetAutoPickupSpawnedPacks(enabled)
    setAutoPickupSpawnedPacksEnabled(enabled)
    return State.autoPickupSpawnedPacks
end

function API.SetWorldCupSquadMode(mode)
    return setWorldCupSquadMode(mode)
end

function API.SetAutoPlay(enabled)
    return setAutoPlayEnabled(enabled)
end

function API.SetAutoMatch(enabled)
    return API.SetAutoPlay(enabled)
end

function API.StartAutoPlayNow()
    return setAutoPlayEnabled(true)
end

function API.StopAutoPlay()
    return setAutoPlayEnabled(false)
end

function API.SetPackBuyEnabled(tier, enabled)
    tier = tostring(tier)
    local known = false

    for _, knownTier in ipairs(State.packShopTiers) do
        if knownTier == tier then
            known = true
            break
        end
    end

    if not known then
        return false, "Pack tier tidak dikenal"
    end

    State.packBuyWhitelist[tier] = enabled == true
    PersistentConfig.packBuyWhitelist = State.packBuyWhitelist
    State.nextAutoBuyPackAt = 0
    syncConfigurationControls()
    updateAutomationButtons()
    requestConfigSave()
    return true
end

function API.SetPackBuyWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist harus berupa table"
    end

    for _, tier in ipairs(State.packShopTiers) do
        if whitelist[tier] ~= nil then
            State.packBuyWhitelist[tier] = whitelist[tier] == true
        end
    end

    PersistentConfig.packBuyWhitelist = State.packBuyWhitelist
    State.nextAutoBuyPackAt = 0
    syncConfigurationControls()
    updateAutomationButtons()
    requestConfigSave()
    return true
end

function API.GetPackBuyWhitelist()
    return copyPackBuyWhitelistForConfig()
end

function API.BuyPacksNow()
    return Runtime.buySelectedPacks(false, 1)
end

function API.GetUICapabilityState()
    return {
        failures = State.uiCapabilityFailures,
        lastMethod = State.lastUiCapabilityMethod,
        lastError = State.lastUiCapabilityError,
    }
end

function API.GetPackBuyState()
    return Runtime.getPackBuyState()
end

function API.OpenPacksNow()
    return Runtime.openOwnedPacksAutomatically(false)
end

function API.PreviewPackChoice(cards)
    local index, selected = Runtime.selectPackChoiceIndex(cards)
    return {
        mode = State.packPickMode,
        modeLabel = packPickModeLabel(State.packPickMode),
        index = index,
        selected = selected,
    }
end

function API.GetPackSessionLog()
    local result = {}
    for index, entry in ipairs(State.packSession.entries) do
        result[index] = table.clone(entry)
    end
    return result
end

function API.ClearPackSessionLog()
    return Runtime.clearPackSessionLog(true)
end

function API.SetPackLogRarityEnabled(rarity, enabled)
    rarity = rarityFromDisplayLabel(rarity)
    if RARITY_PRIORITY[rarity] == nil then
        return false, "Rarity tidak dikenal"
    end
    State.packLogRarityWhitelist[rarity] = enabled == true
    PersistentConfig.packLogRarityWhitelist = State.packLogRarityWhitelist
    Runtime.updatePackUI()
    syncConfigurationControls()
    requestConfigSave()
    return true
end


function API.ClaimPlayTimeRewardsNow()
    return Runtime.claimReadyPlayTimeRewards(false)
end

function API.ClaimDailyRewardNow()
    return Runtime.claimDailyReward(false)
end

function API.EquipBestNow()
    return equipBestEleven(false)
end

function API.JoinInternationalCupNow()
    return Runtime.joinInternationalCup(false)
end

function API.FillWorldCupVisualSquad()
    local status = State.worldCupStatus or Runtime.fetchWorldCupStatus()
    local team, teamError = Runtime.selectWorldCupTeam(status)
    if not team then
        return false, teamError
    end
    return Runtime.fillWorldCupVisualSquad(team, false)
end

function API.CollectWorldCupRewardNow()
    return Runtime.collectWorldCupReward(false)
end

function API.PickupSpawnedPacksNow()
    return Runtime.pickupSpawnedPacks(false)
end

function API.CheckInternationalCup()
    return Runtime.fetchWorldCupStatus()
end

function API.ToggleLockPosition()
    return Runtime.setLockPositionEnabled(not State.lockPosition)
end

function API.SetLockPosition(enabled)
    return Runtime.setLockPositionEnabled(enabled)
end

function API.BackToBase()
    return Runtime.teleportBackToBase(false)
end

function API.ToggleAutoConveyor()
    return Runtime.setAutoConveyorEnabled(not State.autoConveyor)
end

function API.SetAutoConveyor(enabled)
    return Runtime.setAutoConveyorEnabled(enabled)
end

function API.TeleportToConveyor()
    return Runtime.teleportToConveyor(false)
end

function API.GetMovementState()
    local plot = Runtime.findOwnedPlot(false)
    local spawnPart = Runtime.getOwnedPlotSpawn(false)
    local conveyor = Runtime.getConveyorTarget()
    return {
        lockPosition = State.lockPosition,
        autoConveyor = State.autoConveyor,
        plot = plot,
        spawn = spawnPart,
        conveyor = conveyor,
        lastBaseTeleportAt = State.lastBaseTeleportAt,
        lastConveyorTeleportAt = State.lastConveyorTeleportAt,
    }
end

function API.ToggleAntiAfk()
    return Runtime.setAntiAfkEnabled(not State.antiAfk)
end

function API.SetAntiAfk(enabled)
    return Runtime.setAntiAfkEnabled(enabled)
end

function API.PulseAntiAfk()
    return Runtime.preventIdleKick("manual")
end

function API.GetAntiAfkState()
    return {
        enabled = State.antiAfk,
        count = State.antiAfkCount,
        lastPreventedAt = State.lastAntiAfkAt,
        nextPulseAt = State.nextAntiAfkPulseAt,
        interval = State.antiAfkInterval,
        method = State.antiAfkMethod,
        lastError = State.lastAntiAfkError,
        busy = State.antiAfkBusy,
        virtualUserAvailable = Runtime.virtualUser ~= nil,
        virtualInputManagerAvailable = Runtime.virtualInputManager ~= nil,
    }
end

function API.Rejoin()
    return Runtime.rejoinCurrentServer()
end

function API.GetAutoJoinWorldCupState()
    local phaseInfo = Runtime.getWorldCupPhase()
    return {
        enabled = State.autoJoinWorldCup,
        running = State.joiningWorldCup,
        autoCollectRewards = State.autoCollectWorldCupRewards,
        fillVisualBeforeJoin = State.fillWorldCupVisualBeforeJoin,
        autoPickupSpawnedPacks = State.autoPickupSpawnedPacks,
        collectingReward = State.collectingWorldCupReward,
        fillingVisual = State.fillingWorldCupVisual,
        pickingSpawnedPacks = State.pickingSpawnedPacks,
        squadMode = State.worldCupSquadMode,
        squadModeLabel = worldCupSquadModeLabel(State.worldCupSquadMode),
        phase = phaseInfo and phaseInfo.phase or nil,
        status = State.worldCupStatus,
        lastJoinedAt = State.lastWorldCupJoinAt,
        lastCollectedAt = State.lastWorldCupCollectAt,
        nextAttemptAt = State.nextWorldCupCheckAt,
        lastVisualFillAt = State.lastWorldCupVisualFillAt,
        lastVisualFillCount = State.lastWorldCupVisualFillCount,
        lastVisualFillError = State.lastWorldCupVisualFillError,
        lastSpawnedPackPickupAt = State.lastSpawnedPackPickupAt,
        lastSpawnedPackPickupCount = State.lastSpawnedPackPickupCount,
    }
end


function API.GetAutoEquipBestState()
    return {
        enabled = State.autoEquipBest,
        running = State.equippingBest,
        matchPlaybackActive = State.matchPlaybackActive,
        lastEquippedAt = State.lastEquipBestAt,
        nextAttemptAt = State.nextAutoEquipBestAt,
        result = State.lastEquipBestResult,
        passes = State.autoEquipBestPasses,
        changed = State.autoEquipBestChanged,
        collectionSignature = State.lastEquipBestSignature,
    }
end

function API.GetAutoOpenPacksState()
    return {
        enabled = State.autoOpenPacks,
        opening = State.openingPacks,
        owned = Runtime.getOwnedPackCount(),
        pickMode = State.packPickMode,
        pickModeLabel = packPickModeLabel(State.packPickMode),
        skipPackAnimation = State.skipPackAnimation,
        instantPacks = State.instantPacks,
        autoBuyPacks = State.autoBuyPacks,
        packBuyPrestigePriority = State.packBuyPrestigePriority,
        packBuyWhitelist = copyPackBuyWhitelistForConfig(),
        packBuyState = Runtime.getPackBuyState(),
        instantPass = Runtime.getData("Passes.InstantOpen") == true,
        instantFallback = State.lastInstantPackFallback,
        sessionTotal = tonumber(State.packSession.totalOpened) or 0,
        sessionPickTotal = tonumber(State.packSession.totalPickPacks) or 0,
        visibleLogCount = #Runtime.getFilteredPackSessionEntries(),
        lastOpenedAt = State.lastPackOpenAt,
        lastOpenedCount = State.lastPackOpenCount,
        lastPickCount = State.lastPackPickCount,
        lastPickAt = State.lastPackPickAt,
        lastPickTier = State.lastPackPickTier,
        lastPickIndex = State.lastPackPickIndex,
        lastPickCard = State.lastPackPickCard,
        lastError = State.lastPackOpenError,
        nextAttemptAt = State.nextAutoOpenPackAt,
    }
end

function API.GetPlayTimeRewardsState()
    local rewardState = Runtime.getPlayTimeRewardState()
    rewardState.enabled = State.autoClaimPlayTimeRewards
    rewardState.claiming = State.claimingPlayTimeRewards
    rewardState.lastClaimAt = State.lastPlayTimeClaimAt
    rewardState.lastClaimCount = State.lastPlayTimeClaimCount
    rewardState.nextAttemptAt = State.nextPlayTimeClaimAt
    return rewardState
end

function API.GetDailyRewardState()
    local rewardState = Runtime.getDailyRewardState()
    rewardState.enabled = State.autoClaimDailyReward
    rewardState.claiming = State.claimingDailyReward
    rewardState.lastClaimAt = State.lastDailyRewardClaimAt
    rewardState.lastClaimDay = State.lastDailyRewardClaimDay
    rewardState.lastResponse = State.lastDailyRewardClaimResponse
    rewardState.lastError = State.lastDailyRewardClaimError
    rewardState.nextAttemptAt = State.nextDailyRewardClaimAt
    return rewardState
end

function API.GetAutoPlayState()
    return {
        enabled = State.autoMatch,
        syncing = State.settingAutoMatch,
        pending = State.autoMatchPendingSync,
        serverValue = Runtime.getData("Settings.AutoMatch"),
        playbackActive = State.matchPlaybackActive,
        flow = "AttemptSendOut -> SetAutoMatch -> MatchPlaybackRequested(background)",
    }
end

function API.GetAutoMatchState()
    return API.GetAutoPlayState()
end

function API.PrestigeNow()
    return Runtime.performPrestige(false)
end

function API.CheckPrestige()
    return Runtime.fetchPrestigeInfo()
end

function API.GetPrestigeState()
    local info = State.prestigeInfo
    return {
        enabled = State.autoPrestige,
        running = State.prestiging,
        eligible = info and info.eligible == true or false,
        count = info and tonumber(info.count) or nil,
        nextNumber = info and tonumber(info.nextNumber) or nil,
        gates = info and info.gates or nil,
    }
end

function API.GetAutomationState()
    return {
        autoLoan = State.autoLoan,
        autoCollect = State.autoCollect,
        autoPrestige = State.autoPrestige,
        autoPlay = State.autoMatch,
        autoMatch = State.autoMatch, -- compatibility
        autoOpenPacks = State.autoOpenPacks,
        packPickMode = State.packPickMode,
        skipPackAnimation = State.skipPackAnimation,
        instantPacks = State.instantPacks,
        autoBuyPacks = State.autoBuyPacks,
        packBuyPrestigePriority = State.packBuyPrestigePriority,
        packBuyWhitelist = copyPackBuyWhitelistForConfig(),
        packLogRarityWhitelist = copyPackLogWhitelistForConfig(),
        autoClaimPlayTimeRewards = State.autoClaimPlayTimeRewards,
        autoClaimDailyReward = State.autoClaimDailyReward,
        autoEquipBest = State.autoEquipBest,
        autoJoinWorldCup = State.autoJoinWorldCup,
        autoCollectWorldCupRewards = State.autoCollectWorldCupRewards,
        fillWorldCupVisualBeforeJoin = State.fillWorldCupVisualBeforeJoin,
        autoPickupSpawnedPacks = State.autoPickupSpawnedPacks,
        lockPosition = State.lockPosition,
        autoConveyor = State.autoConveyor,
        worldCupSquadMode = State.worldCupSquadMode,
        joiningWorldCup = State.joiningWorldCup,
        collectingWorldCupReward = State.collectingWorldCupReward,
        fillingWorldCupVisual = State.fillingWorldCupVisual,
        pickingSpawnedPacks = State.pickingSpawnedPacks,
        openingPacks = State.openingPacks,
        claimingPlayTimeRewards = State.claimingPlayTimeRewards,
        readyPlayTimeRewards = Runtime.getPlayTimeRewardState().readyCount,
        claimingDailyReward = State.claimingDailyReward,
        dailyReward = Runtime.getDailyRewardState(),
        equippingBest = State.equippingBest,
        ownedPacks = Runtime.getOwnedPackCount(),
        settingAutoMatch = State.settingAutoMatch,
        prestiging = State.prestiging,
        duration = State.selectedDuration,
        whitelist = API.GetWhitelist(),
    }
end

function API.SaveConfig()
    return saveConfigToDisk()
end

function API.LoadConfig()
    return loadConfigFromDisk()
end

function API.SetAutoSave(enabled)
    setAutoSaveEnabled(enabled)
    return State.autoSave
end

function API.SetAutoLoad(enabled)
    setAutoLoadEnabled(enabled)
    return State.autoLoad
end

function API.GetConfigState()
    return {
        supported = State.configSupported,
        path = CONFIG_FILE,
        exists = configFileExists(),
        autoSave = State.autoSave,
        autoLoad = State.autoLoad,
        dirty = State.configDirty,
        lastSavedAt = State.configLastSavedAt,
        startupLoaded = State.startupConfigLoaded,
        startupError = State.startupConfigError,
        windowKeybind = State.windowKeybind,
        autoPlay = State.autoMatch,
        autoClaimDailyReward = State.autoClaimDailyReward,
        skipPackAnimation = State.skipPackAnimation,
        instantPacks = State.instantPacks,
        autoBuyPacks = State.autoBuyPacks,
        packBuyPrestigePriority = State.packBuyPrestigePriority,
        packBuyWhitelist = copyPackBuyWhitelistForConfig(),
        packLogRarityWhitelist = copyPackLogWhitelistForConfig(),
        autoJoinWorldCup = State.autoJoinWorldCup,
        autoCollectWorldCupRewards = State.autoCollectWorldCupRewards,
        fillWorldCupVisualBeforeJoin = State.fillWorldCupVisualBeforeJoin,
        autoPickupSpawnedPacks = State.autoPickupSpawnedPacks,
        lockPosition = State.lockPosition,
        autoConveyor = State.autoConveyor,
        antiAfk = State.antiAfk,
        worldCupSquadMode = State.worldCupSquadMode,
    }
end

function API.Stop()
    if not State.running then
        return
    end

    State.running = false
    State.autoLoan = false
    State.autoCollect = false
    State.autoPrestige = false
    State.autoOpenPacks = false
    State.skipPackAnimation = false
    State.instantPacks = false
    State.autoClaimPlayTimeRewards = false
    State.autoClaimDailyReward = false
    State.autoEquipBest = false
    State.autoJoinWorldCup = false
    State.autoCollectWorldCupRewards = false
    State.autoPickupSpawnedPacks = false
    State.lockPosition = false
    State.autoConveyor = false
    State.antiAfk = false
    State.fillWorldCupVisualBeforeJoin = false
    State.openingPacks = false
    State.buyingPacks = false
    State.claimingPlayTimeRewards = false
    State.claimingDailyReward = false
    State.equippingBest = false
    State.joiningWorldCup = false
    State.collectingWorldCupReward = false
    State.fillingWorldCupVisual = false
    State.pickingSpawnedPacks = false
    State.worldCupAutoPlayPaused = false
    State.rejoining = false
    State.autoMatchTransaction = false
    State.settingAutoMatch = false
    State.autoMatchPendingSync = false
    State.prestiging = false
    State.movementOverrideCFrame = nil
    State.movementOverrideUntil = 0
    if Runtime.releaseMovementRoot then
        Runtime.releaseMovementRoot()
    end
    if Runtime.restorePlayerCollisions then
        Runtime.restorePlayerCollisions()
    end
    disconnectAll()
    clearRows()

    if State.window and type(State.window.Destroy) == "function" then
        pcall(function()
            State.window:Destroy()
        end)
    end

    State.window = nil
    State.windUI = nil

    if Environment.LoanOutGUIWindWindow then
        Environment.LoanOutGUIWindWindow = nil
    end
    if Environment.LoanOutGUI == API then
        Environment.LoanOutGUI = nil
    end
end

Environment.LoanOutGUI = API

loadGameModules()
initializeConfigurationOptions()
Runtime.buildGui()
updateAutomationButtons(true)
if Runtime.updatePackUI then
    Runtime.updatePackUI(true)
end


task.spawn(function()
    if not discoverFramework() then
        setCollectButton("Collect All", false)
        setLoanButton("Loan Top", false)
        setStatus("DataService/Networker tidak ditemukan.", COLORS.danger)
        return
    end

    -- Terapkan Auto Play dari config setelah Networker tersedia. Jika tidak
    -- ada nilai config, refreshUI akan mengikuti Settings.AutoMatch milik game.
    if State.autoMatchPendingSync then
        setAutoPlayEnabled(State.autoMatch, false, true)
    end

    ensureMatchPlaybackListeners()

    -- Polling-only mode: jangan hubungkan DataChanged milik game. Callback
    -- ReplicatedStorage.Packages.Signal berjalan pada free thread yang tidak
    -- boleh mengakses Instance/WindUI. Semua data dibaca ulang dari loop ini.
    refreshUI(true, true)

    while State.running do
        task.wait(POLL_INTERVAL)

        -- Polling-only: seluruh pembacaan data dan perubahan WindUI dilakukan
        -- dari loop milik script ini. Tidak ada callback Signal game yang dapat
        -- memanggil SetDesc/SetTitle dari thread tanpa capability.
        refreshUI(false, true)
        Runtime.runAutomationTick()
    end
end)
