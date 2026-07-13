--[[
    Standalone Loan Out Manager - WindUI

    Fitur:
      - Menggunakan WindUI dengan keybind G dan floating OpenButton.
      - Judul otomatis: xSansHUB - nama game saat ini.
      - Menampilkan seluruh pemain yang sedang loan out.
      - Collect All untuk seluruh loan yang sudah selesai.
      - Loan Top berdasarkan whitelist rarity dan durasi yang dipilih.
      - Toggle Auto Loan, Auto Collect, Auto Play, Auto Open Packs, Auto Evolve satu-per-satu, Auto Equip Best, Auto Join International Cup, dan Auto Prestige.
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
      LoanOutGUI.ToggleAutoEvolveCards()
      LoanOutGUI.ToggleAutoEquipBest()
      LoanOutGUI.ToggleAutoJoinWorldCup()
      LoanOutGUI.SetWorldCupSquadMode("last_team" / "best_rarity_ovr")
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
local HUB_TITLE = "xSansHUB - " .. GAME_NAME

local CONFIG_VERSION = 7
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
    if source.autoEvolveCards ~= nil then
        target.autoEvolveCards = source.autoEvolveCards == true
    end
    if source.autoEquipBest ~= nil then
        target.autoEquipBest = source.autoEquipBest == true
    end
    if source.autoJoinWorldCup ~= nil then
        target.autoJoinWorldCup = source.autoJoinWorldCup == true
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
local AUTO_EVOLVE_INTERVAL = 2
local AUTO_EVOLVE_RETRY_DELAY = 6
local AUTO_EQUIP_BEST_RETRY_DELAY = 8
local AUTO_MATCH_PAUSE_TIMEOUT = 3
local WORLD_CUP_CHECK_INTERVAL = 6
local WORLD_CUP_RETRY_DELAY = 12
local WORLD_CUP_SUCCESS_DELAY = 15
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
    autoEvolveCards = PersistentConfig.autoEvolveCards == true,
    autoEquipBest = PersistentConfig.autoEquipBest == true,
    autoJoinWorldCup = PersistentConfig.autoJoinWorldCup == true,
    worldCupSquadMode = normalizeWorldCupSquadMode(PersistentConfig.worldCupSquadMode),
    settingAutoMatch = false,
    openingPacks = false,
    evolvingCards = false,
    equippingBest = false,
    joiningWorldCup = false,
    rejoining = false,
    autoMatchTransaction = false,
    matchPlaybackActive = false,
    matchEventListenersConnected = false,
    autoMatchPendingSync = (PersistentConfig.autoPlay ~= nil or PersistentConfig.autoMatch ~= nil) and StartupConfigLoaded,
    autoMatchSyncIgnoreUntil = 0,
    nextAutoMatchSyncAt = 0,
    nextAutoPlayEnsureAt = 0,
    nextAutoOpenPackAt = 0,
    lastObservedPackCount = 0,
    lastPackOpenAt = 0,
    lastEquipBestSignature = nil,
    lastEquipBestAt = 0,
    worldCupStatus = nil,
    worldCupStatusUpdatedAt = 0,
    lastWorldCupJoinAt = 0,
    lastWorldCupCollectAt = 0,
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
    formationLayout = nil,
    cardResolve = nil,

    windUI = nil,
    window = nil,
    dashboardTab = nil,
    automationTab = nil,
    configurationTab = nil,
    settingsTab = nil,
    worldCupTab = nil,

    summaryParagraph = nil,
    dashboardParagraph = nil,
    statusParagraph = nil,
    loanListParagraph = nil,
    prestigeParagraph = nil,
    prestigeGateParagraphs = {},
    prestigeInfoUpdatedAt = 0,
    configurationParagraph = nil,
    worldCupParagraph = nil,

    collectButton = nil,
    loanButton = nil,
    prestigeButton = nil,
    autoLoanToggle = nil,
    autoCollectToggle = nil,
    autoMatchToggle = nil,
    autoOpenPacksToggle = nil,
    autoEvolveCardsToggle = nil,
    autoEquipBestToggle = nil,
    autoJoinWorldCupToggle = nil,
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
    nextAutoEvolveAt = 0,
    nextAutoEquipBestAt = 0,
    nextWorldCupCheckAt = 0,

    -- DataChanged milik game dijalankan melalui free-thread Signal.
    -- Callback tersebut tidak boleh menyentuh Instance/WindUI secara langsung.
    uiRefreshRequested = false,
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

local function syncPersistentConfig()
    PersistentConfig.autoLoan = State.autoLoan == true
    PersistentConfig.autoCollect = State.autoCollect == true
    PersistentConfig.autoPrestige = State.autoPrestige == true
    PersistentConfig.autoPlay = State.autoMatch == true
    PersistentConfig.autoMatch = State.autoMatch == true -- compatibility untuk config lama
    PersistentConfig.autoOpenPacks = State.autoOpenPacks == true
    PersistentConfig.autoEvolveCards = State.autoEvolveCards == true
    PersistentConfig.autoEquipBest = State.autoEquipBest == true
    PersistentConfig.autoJoinWorldCup = State.autoJoinWorldCup == true
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
        autoEvolveCards = State.autoEvolveCards == true,
        autoEquipBest = State.autoEquipBest == true,
        autoJoinWorldCup = State.autoJoinWorldCup == true,
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

local getDurationLabel
local getEnabledRarityCount
local getOwnedPackCount
local getData
local getEvolvableGroupCount
local getSquadEquipSignature
local getWorldCupPhase
local getWorldCupReservedIds

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
        button:SetDesc(enabled and "Ambil seluruh loan yang sudah selesai." or "Belum ada loan selesai atau automation sedang sibuk.")
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
        button:SetDesc(enabled
            and "Kirim kandidat rarity/OVR tertinggi sesuai whitelist."
            or "Tidak ada kandidat, slot penuh, atau automation sedang sibuk.")
    end
    setElementLocked(button, not enabled)
end

local function updateAutomationButtons()
    if State.autoLoanToggle and type(State.autoLoanToggle.Set) == "function" then
        if State.autoLoanToggle.Value ~= State.autoLoan then
            State.autoLoanToggle:Set(State.autoLoan, false)
        end
        State.autoLoanToggle:SetDesc(string.format(
            "Isi slot kosong otomatis • %s • %d/%d rarity aktif",
            getDurationLabel and getDurationLabel(State.selectedDuration) or tostring(State.selectedDuration),
            getEnabledRarityCount and getEnabledRarityCount() or 0,
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
        if State.autoMatchTransaction then
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

        local packCount = getOwnedPackCount and getOwnedPackCount() or 0
        local packsDesc
        if State.openingPacks then
            packsDesc = string.format("OPENING • memulai auto open untuk %d pack.", packCount)
        elseif State.autoOpenPacks and packCount > 0 then
            packsDesc = string.format("ACTIVE • %d pack tersedia dan akan dibuka otomatis.", packCount)
        elseif State.autoOpenPacks then
            packsDesc = "ACTIVE • menunggu pack baru tersedia."
        else
            packsDesc = string.format("Buka pack otomatis saat tersedia • sekarang %d pack.", packCount)
        end
        State.autoOpenPacksToggle:SetDesc(packsDesc)
    end

    if State.autoEvolveCardsToggle and type(State.autoEvolveCardsToggle.Set) == "function" then
        if State.autoEvolveCardsToggle.Value ~= State.autoEvolveCards then
            State.autoEvolveCardsToggle:Set(State.autoEvolveCards, false)
        end

        local evolvableCount = getEvolvableGroupCount and getEvolvableGroupCount() or 0
        local evolveDesc
        if State.evolvingCards then
            evolveDesc = string.format("EVOLVING • memproses 1 kartu • %d kartu tersisa.", evolvableCount)
        elseif State.autoEvolveCards and evolvableCount > 0 then
            evolveDesc = string.format("ACTIVE • %d kartu siap • diproses satu per satu dengan CombineCards.", evolvableCount)
        elseif State.autoEvolveCards then
            evolveDesc = "ACTIVE • menunggu duplicate yang cukup untuk evolve."
        else
            evolveDesc = string.format("Evolve satu per satu tanpa AutoEvolve game pass • %d kartu benar-benar siap.", evolvableCount)
        end
        State.autoEvolveCardsToggle:SetDesc(evolveDesc)
    end

    if State.autoEquipBestToggle and type(State.autoEquipBestToggle.Set) == "function" then
        if State.autoEquipBestToggle.Value ~= State.autoEquipBest then
            State.autoEquipBestToggle:Set(State.autoEquipBest, false)
        end

        local equipDesc
        if State.equippingBest then
            equipDesc = "EQUIPPING • menyusun Starting Eleven terbaik."
        elseif State.matchPlaybackActive then
            equipDesc = "WAITING • match sedang berlangsung; akan dicoba setelah playback selesai."
        elseif State.autoEquipBest and State.autoMatch then
            equipDesc = "ACTIVE • Auto Play dipause sementara, Equip Best dijalankan, lalu dimulai kembali."
        elseif State.autoEquipBest then
            equipDesc = "ACTIVE • Starting Eleven diperbarui saat koleksi kartu berubah."
        else
            equipDesc = "Susun Starting Eleven terbaik otomatis saat koleksi berubah."
        end
        State.autoEquipBestToggle:SetDesc(equipDesc)
    end

    if State.autoJoinWorldCupToggle and type(State.autoJoinWorldCupToggle.Set) == "function" then
        if State.autoJoinWorldCupToggle.Value ~= State.autoJoinWorldCup then
            State.autoJoinWorldCupToggle:Set(State.autoJoinWorldCup, false)
        end

        local status = State.worldCupStatus
        local phaseInfo = getWorldCupPhase and getWorldCupPhase() or nil
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
                State.worldCupJoinButton:SetDesc(buttonDesc)
            end
            setElementLocked(State.worldCupJoinButton, not buttonEnabled)
        end
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
                and "Auto Open Packs aktif • pack akan dibuka memakai mode AUTO OPEN bawaan game."
                or "Auto Open Packs dinonaktifkan.",
            State.autoOpenPacks and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoEvolveCardsEnabled(enabled, announce)
    State.autoEvolveCards = enabled == true
    PersistentConfig.autoEvolveCards = State.autoEvolveCards
    State.nextAutoEvolveAt = 0
    updateAutomationButtons()
    requestConfigSave()

    if announce ~= false then
        setStatus(
            State.autoEvolveCards
                and "Auto Evolve Cards aktif • duplicate diproses satu per satu dengan CombineCards."
                or "Auto Evolve Cards dinonaktifkan.",
            State.autoEvolveCards and COLORS.success or COLORS.muted
        )
    end
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

local function formatCompactNumber(value)
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

getDurationLabel = function(minutes)
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

getEnabledRarityCount = function()
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
end

getData = function(path)
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


getOwnedPackCount = function()
    local ownedPacks = getData("Packs.Owned")
    if type(ownedPacks) ~= "table" then
        return 0
    end

    local total = 0
    for _, amount in pairs(ownedPacks) do
        total += math.max(0, tonumber(amount) or 0)
    end

    return total
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

    local ownedCards = getData("Squad.Owned") or {}
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
    local startingEleven = getData("Squad.StartingEleven")

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

    addActiveIds(unavailable, getData("Loans.active"))
    addActiveIds(unavailable, getData("Training.active"))

    local promotion = getData("Promotion")
    if type(promotion) == "table" and promotion.active then
        addActiveIds(unavailable, promotion.players)
    end

    return unavailable
end

local function getEvolutionUnavailableCardIds()
    local unavailable = {}
    addActiveIds(unavailable, getData("Loans.active"))
    addActiveIds(unavailable, getData("Training.active"))

    local promotion = getData("Promotion")
    if type(promotion) == "table" and promotion.active then
        addActiveIds(unavailable, promotion.players)
    end

    return unavailable
end

local function getCardMaxUpgrade(baseCard)
    local database = State.playerCardDatabase
    if not database or type(database.MaxUpgrade) ~= "function" or not baseCard then
        return 0
    end

    local success, result = pcall(database.MaxUpgrade, baseCard)
    if success then
        return math.max(0, tonumber(result) or 0)
    end

    return 0
end

local function buildEvolvableGroups()
    local database = State.playerCardDatabase
    local ownedCards = getData("Squad.Owned")
    local storedDupes = getData("Squad.Dupes")

    if not database or type(database.GetById) ~= "function" or type(ownedCards) ~= "table" then
        return {}
    end

    local unavailable = getEvolutionUnavailableCardIds()
    local groupsByBaseId = {}

    local function getOrCreateGroup(rawBaseId, baseCard)
        local baseId = tostring(rawBaseId)
        local group = groupsByBaseId[baseId]
        if group then
            return group
        end

        local baseRating = tonumber(baseCard.rating) or 0
        group = {
            baseId = baseId,
            baseCard = baseCard,
            physicalCount = 0,
            storedDupeCount = 0,
            bestInstanceId = nil,
            bestUpgrade = 0,
            bestRating = baseRating,
            rarity = getRarity(baseCard, baseRating),
        }
        groupsByBaseId[baseId] = group
        return group
    end

    -- Kartu instance nyata yang sedang loan/training/promotion tidak boleh
    -- digunakan sebagai target maupun material evolve.
    for rawInstanceId, cardData in pairs(ownedCards) do
        if type(cardData) == "table" and cardData.baseId ~= nil then
            local instanceId = tostring(rawInstanceId)
            if not unavailable[instanceId] then
                local success, baseCard = pcall(database.GetById, cardData.baseId)
                if success and baseCard then
                    local group = getOrCreateGroup(cardData.baseId, baseCard)
                    local upgrade = tonumber(cardData.upgrade) or 0
                    local rating = (tonumber(baseCard.rating) or 0) + upgrade

                    group.physicalCount += 1
                    if group.bestInstanceId == nil or rating > group.bestRating then
                        group.bestRating = rating
                        group.bestUpgrade = upgrade
                        group.bestInstanceId = instanceId
                        group.rarity = getRarity(baseCard, rating)
                    end
                end
            end
        end
    end

    -- Squad.Dupes dan copy tambahan di Squad.Owned dapat merepresentasikan
    -- duplicate yang sama pada snapshot client tertentu. Karena itu keduanya
    -- tidak dijumlahkan secara mentah. Nilai terbesar dipakai sebagai jumlah
    -- material yang benar-benar tersedia agar kandidat tidak terdeteksi ganda.
    if type(storedDupes) == "table" then
        for rawBaseId, amount in pairs(storedDupes) do
            local dupeCount = math.max(0, math.floor(tonumber(amount) or 0))
            if dupeCount > 0 then
                local success, baseCard = pcall(database.GetById, rawBaseId)
                if success and baseCard then
                    local group = getOrCreateGroup(rawBaseId, baseCard)
                    group.storedDupeCount = math.max(group.storedDupeCount, dupeCount)
                end
            end
        end
    end

    local result = {}
    for _, group in pairs(groupsByBaseId) do
        local maxUpgrade = getCardMaxUpgrade(group.baseCard)

        -- Satu kartu/copy harus disisakan sebagai target evolve.
        local physicalMaterials = math.max(
            0,
            group.physicalCount - (group.bestInstanceId and 1 or 0)
        )
        local storedMaterials = group.storedDupeCount
        if not group.bestInstanceId then
            storedMaterials = math.max(0, storedMaterials - 1)
        end

        -- Gunakan sumber material terbesar, bukan penjumlahan kedua sumber.
        -- Ini memperbaiki false positive seperti 54 kandidat padahal UI game
        -- hanya memiliki beberapa kartu yang benar-benar dapat di-evolve.
        local duplicateCount = math.max(physicalMaterials, storedMaterials)

        if group.bestUpgrade < maxUpgrade and duplicateCount >= 2 then
            group.maxUpgrade = maxUpgrade
            group.duplicateCount = duplicateCount
            group.physicalMaterials = physicalMaterials
            group.storedMaterials = storedMaterials
            group.count = duplicateCount + 1
            result[#result + 1] = group
        end
    end

    table.sort(result, function(a, b)
        local aRank = rarityRank(a.rarity)
        local bRank = rarityRank(b.rarity)
        if aRank ~= bRank then
            return aRank > bRank
        end
        if a.bestRating ~= b.bestRating then
            return a.bestRating > b.bestRating
        end
        return tostring(a.baseId) < tostring(b.baseId)
    end)

    return result
end

getEvolvableGroupCount = function()
    return #buildEvolvableGroups()
end

getSquadEquipSignature = function()
    local parts = {"formation=" .. tostring(getData("Squad.Formation") or "")}
    local ownedCards = getData("Squad.Owned")

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

    appendActive("loan", getData("Loans.active"))
    appendActive("training", getData("Training.active"))

    local promotion = getData("Promotion")
    if type(promotion) == "table" and promotion.active then
        appendActive("promotion", promotion.players)
    end

    table.sort(parts)
    return table.concat(parts, "|")
end

local function findTopAvailableCard()
    local ownedCards = getData("Squad.Owned")
    if type(ownedCards) ~= "table" then
        return nil
    end

    local unavailable = getUnavailableCardIds()

    -- Saat Auto Join Cup aktif, jangan loan pemain yang sedang dicadangkan
    -- untuk Last Team atau Best Rarity/OVR sebelum entry selesai.
    if State.autoJoinWorldCup and getWorldCupReservedIds then
        local reserved = getWorldCupReservedIds()
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
    local activeLoans = getData("Loans.active")
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

    local clubLevel = tonumber(getData("Club.Level")) or 1
    local prestigeCount = tonumber(getData("Prestige.Count")) or 0
    local success, baseSlots = pcall(loanConfig.UnlockedSlots, clubLevel, prestigeCount)

    if not success or type(baseSlots) ~= "number" then
        return nil
    end

    local bonusSlots = 0
    local skillsConfig = State.skillsConfig
    if skillsConfig and type(skillsConfig.BonusLoanSlots) == "function" then
        local ownedSkills = getData("Skills.owned") or {}
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
    local activeLoans = getData("Loans.active")
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
        State.durationDropdown:Select(getDurationLabel(State.selectedDuration))
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
            getDurationLabel(State.selectedDuration),
            getEnabledRarityCount(),
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
    if config.autoEvolveCards ~= nil then
        State.autoEvolveCards = config.autoEvolveCards == true
    end
    if config.autoEquipBest ~= nil then
        State.autoEquipBest = config.autoEquipBest == true
    end
    if config.autoJoinWorldCup ~= nil then
        State.autoJoinWorldCup = config.autoJoinWorldCup == true
    end
    if config.worldCupSquadMode ~= nil then
        State.worldCupSquadMode = normalizeWorldCupSquadMode(config.worldCupSquadMode)
    end

    State.nextAutoLoanAt = 0
    State.nextAutoCollectAt = 0
    State.nextPrestigeCheckAt = 0
    State.nextAutoOpenPackAt = 0
    State.nextAutoEvolveAt = 0
    State.nextAutoEquipBestAt = 0
    State.nextWorldCupCheckAt = 0
    State.lastObservedPackCount = 0
    State.lastEquipBestSignature = nil
    State.cachedTopCard = nil
    State.configDirty = false

    syncPersistentConfig()

    State.syncingConfiguration = false
    State.configLoading = false

    syncConfigurationControls()
    updateAutomationButtons()
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

refreshUI = function(forceRebuild)
    if not State.running or not State.window then
        return
    end

    -- Settings.AutoMatch tetap menjadi status backend Auto Play dari game. Saat config belum
    -- menunggu sinkronisasi dan request tidak sedang berjalan, ikuti perubahan
    -- dari menu/indicator bawaan game (misalnya tombol STOP).
    if not State.settingAutoMatch
        and not State.autoMatchTransaction
        and not State.autoMatchPendingSync
        and os.clock() >= State.autoMatchSyncIgnoreUntil
    then
        local serverAutoMatch = getData("Settings.AutoMatch")
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
            getDurationLabel(State.selectedDuration),
            getEnabledRarityCount(),
            #State.rarityOptions
        ))
    end

    if State.loanListParagraph and type(State.loanListParagraph.SetDesc) == "function" then
        State.loanListParagraph:SetDesc(formatLoanRows(rows))
    end

    updateAutomationButtons()
    updateDashboardUI()
    updatePrestigeParagraph()

    local networkReady = isNetworker(State.networker)
    local actionBusy = State.collecting
        or State.loaning
        or State.prestiging
        or State.evolvingCards
        or State.equippingBest
        or State.autoMatchTransaction

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
            setLoanButton(string.format("Loan Top (%s)", getDurationLabel(State.selectedDuration)), true)
        else
            setLoanButton(string.format("Loan Top (%s)", getDurationLabel(State.selectedDuration)), false)
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

    -- Sebagian action UI seperti AutoFillBestEleven/CombineCards bersifat
    -- fire-and-forget dan dapat mengembalikan nil meskipun request diterima.
    return response ~= nil and response or true, nil
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

    local serverAutoMatch = getData("Settings.AutoMatch") == true

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
            local serverValue = getData("Settings.AutoMatch")
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

local function openOwnedPacksAutomatically(isAutomatic)
    if State.openingPacks then
        return false, "Auto Open Packs sedang diproses"
    end

    local packCount = getOwnedPackCount()
    if packCount <= 0 then
        return false, "Tidak ada pack untuk dibuka"
    end

    State.openingPacks = true
    updateAutomationButtons()

    local success, errorMessage = fireBusEvent("PacksInventoryOpen", {
        auto = true,
    })

    State.openingPacks = false
    State.lastObservedPackCount = packCount
    State.lastPackOpenAt = os.clock()
    State.nextAutoOpenPackAt = os.clock() + AUTO_PACK_RETRY_DELAY
    updateAutomationButtons()

    if success then
        if not isAutomatic then
            setStatus(
                string.format("AUTO OPEN dimulai untuk %d pack.", packCount),
                COLORS.success
            )
        end
        return true
    end

    if not isAutomatic then
        setStatus("Auto Open Packs gagal: " .. tostring(errorMessage), COLORS.danger)
    end
    return false, errorMessage
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
        local current = getData("Settings.AutoMatch")
        if current == expectedValue then
            return true
        end
        task.wait(0.1)
    until os.clock() >= deadline or not State.running

    return getData("Settings.AutoMatch") == expectedValue
end

local function runWithAutoMatchPaused(actionCallback)
    if State.autoMatchTransaction or State.settingAutoMatch then
        return nil, "Auto Play sedang diproses"
    end
    if State.matchPlaybackActive then
        return nil, "Match sedang berlangsung"
    end

    local desiredAutoMatch = State.autoMatch == true
        or getData("Settings.AutoMatch") == true
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
        local serverEnabled = getData("Settings.AutoMatch") == true
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

local function evolveCardsNow(isAutomatic)
    if State.evolvingCards or State.equippingBest or State.collecting or State.loaning or State.prestiging or State.joiningWorldCup then
        return false, "Automation lain sedang berjalan"
    end

    local groups = buildEvolvableGroups()
    local target = groups[1]
    if not target then
        return false, "Tidak ada kartu yang dapat di-evolve"
    end

    local instanceId = target.bestInstanceId
    if not instanceId or tostring(instanceId) == "" then
        instanceId = "dupe:" .. tostring(target.baseId)
    end

    local cardName = target.baseCard and target.baseCard.name
        or tostring(target.baseId)

    State.evolvingCards = true
    updateAutomationButtons()

    task.spawn(function()
        local response, errorMessage = runWithAutoMatchPaused(function()
            return callNetworkLoose("CombineCards", {
                instanceId = instanceId,
                levels = 1,
            })
        end)

        State.evolvingCards = false
        State.nextAutoEvolveAt = os.clock()
            + (response and AUTO_EVOLVE_INTERVAL or AUTO_EVOLVE_RETRY_DELAY)
        State.cachedTopCard = nil
        State.lastEquipBestSignature = nil

        if response then
            setStatus(
                string.format(
                    "Evolve berhasil • %s +1 • %d duplicate digunakan.",
                    tostring(cardName),
                    math.min(2, tonumber(target.duplicateCount) or 2)
                ),
                COLORS.success
            )
            task.wait(0.45)
            refreshUI(true)
        elseif not isAutomatic then
            setStatus("Evolve gagal: " .. tostring(errorMessage), COLORS.danger)
        end

        updateAutomationButtons()
    end)

    return true
end

local function equipBestEleven(isAutomatic)
    if State.equippingBest or State.evolvingCards or State.collecting or State.loaning or State.prestiging or State.joiningWorldCup then
        return false, "Automation lain sedang berjalan"
    end
    if State.matchPlaybackActive then
        State.nextAutoEquipBestAt = os.clock() + AUTO_EQUIP_BEST_RETRY_DELAY
        return false, "Match sedang berlangsung"
    end

    local signature = getSquadEquipSignature()
    State.equippingBest = true
    updateAutomationButtons()

    task.spawn(function()
        local response, errorMessage = runWithAutoMatchPaused(function()
            return callNetworkLoose("AutoFillBestEleven")
        end)

        State.equippingBest = false
        State.nextAutoEquipBestAt = os.clock()
            + (response and AUTO_ACTION_INTERVAL or AUTO_EQUIP_BEST_RETRY_DELAY)

        if response then
            State.lastEquipBestSignature = signature
            State.lastEquipBestAt = os.time()
            setStatus("Starting Eleven terbaik berhasil dipasang.", COLORS.success)
            task.wait(0.35)
            refreshUI(true)
        elseif not isAutomatic then
            setStatus("Equip Best gagal: " .. tostring(errorMessage), COLORS.danger)
        end

        updateAutomationButtons()
    end)

    return true
end

getWorldCupPhase = function()
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

local function fetchWorldCupStatus()
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

local function getWorldCupUnavailableIds()
    local unavailable = {}
    addActiveIds(unavailable, getData("Loans.active"))
    addActiveIds(unavailable, getData("Training.active"))
    return unavailable
end

local function resolveWorldCupCandidate(instanceId, cardData)
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

local function getFormationRoles(formation)
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

local function buildWorldCupCandidatePools()
    local owned = getData("Squad.Owned")
    if type(owned) ~= "table" then
        return nil, "Squad.Owned belum tersedia"
    end

    local unavailable = getWorldCupUnavailableIds()
    local bestByRoleAndBase = {
        GK = {},
        DEF = {},
        MID = {},
        FWD = {},
    }

    for rawInstanceId, cardData in pairs(owned) do
        local instanceId = tostring(rawInstanceId)
        if not unavailable[instanceId] then
            local candidate = resolveWorldCupCandidate(instanceId, cardData)
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

local function buildBestWorldCupTeamForFormation(formation, pools)
    local roles = getFormationRoles(formation)
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

local function buildBestWorldCupTeam()
    local pools, poolError = buildWorldCupCandidatePools()
    if not pools then
        return nil, poolError
    end

    local bestTeam = nil
    local reasons = {}

    for _, formation in ipairs(WORLD_CUP_FORMATIONS) do
        local team, reason = buildBestWorldCupTeamForFormation(formation, pools)
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

local function buildLastWorldCupTeam(status)
    if type(status) ~= "table" then
        return nil, "Status International Cup belum tersedia"
    end

    local lastTeam = status.lastTeam
    local formation = tostring(status.lastFormation or "4-3-3")
    if type(lastTeam) ~= "table" or #lastTeam <= 0 then
        return nil, "Belum ada Last Team"
    end

    local roles = getFormationRoles(formation)
    if not roles then
        return nil, "Formation Last Team tidak valid"
    end

    local owned = getData("Squad.Owned")
    if type(owned) ~= "table" then
        return nil, "Squad.Owned belum tersedia"
    end

    local unavailable = getWorldCupUnavailableIds()
    local candidatesByRole = {GK = {}, DEF = {}, MID = {}, FWD = {}}
    local usedBaseIds = {}

    for _, rawInstanceId in ipairs(lastTeam) do
        local instanceId = tostring(rawInstanceId)
        local cardData = owned[instanceId] or owned[rawInstanceId]
        if type(cardData) == "table" and not unavailable[instanceId] then
            local candidate = resolveWorldCupCandidate(instanceId, cardData)
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

local function selectWorldCupTeam(status)
    if normalizeWorldCupSquadMode(State.worldCupSquadMode) == WORLD_CUP_SQUAD_MODE_LAST then
        return buildLastWorldCupTeam(status)
    end

    return buildBestWorldCupTeam()
end

getWorldCupReservedIds = function()
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
            team = buildLastWorldCupTeam(status)
        end
    else
        team = buildBestWorldCupTeam()
    end

    if type(team) == "table" and type(team.instanceIds) == "table" then
        for _, instanceId in ipairs(team.instanceIds) do
            reserved[tostring(instanceId)] = true
        end
    end

    return reserved
end

local function joinInternationalCup(isAutomatic)
    if State.joiningWorldCup
        or State.collecting
        or State.loaning
        or State.prestiging
        or State.evolvingCards
        or State.equippingBest
        or State.joiningWorldCup
        or State.autoMatchTransaction
    then
        return false, "Automation lain sedang berjalan"
    end

    if State.matchPlaybackActive then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_RETRY_DELAY
        return false, "Match sedang berlangsung"
    end

    local status, statusError = fetchWorldCupStatus()
    if not status then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_RETRY_DELAY
        if not isAutomatic then
            setStatus("Gagal mengecek International Cup: " .. tostring(statusError), COLORS.danger)
        end
        return false, statusError
    end

    -- Reward yang belum diklaim mengunci entry berikutnya. Auto Join mengklaim
    -- reward tersebut terlebih dahulu agar siklus berikutnya dapat dilanjutkan.
    if status.pendingClaim then
        if status.canCollect ~= true then
            State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
            return false, "Reward belum dapat diklaim"
        end

        State.joiningWorldCup = true
        updateAutomationButtons()

        task.spawn(function()
            local response, errorMessage = callNetwork("CollectWorldCup")
            State.joiningWorldCup = false
            State.nextWorldCupCheckAt = os.clock()
                + (response and response.success and AUTO_ACTION_INTERVAL or WORLD_CUP_RETRY_DELAY)

            if response and response.success then
                State.lastWorldCupCollectAt = os.time()
                setStatus(
                    string.format(
                        "Reward International Cup berhasil diklaim%s.",
                        response.label and (" • " .. tostring(response.label)) or ""
                    ),
                    COLORS.success
                )
                State.worldCupStatus = nil
                State.cachedTopCard = nil
            elseif not isAutomatic then
                setStatus(
                    "Collect reward International Cup gagal: " .. tostring(errorMessage),
                    COLORS.danger
                )
            end

            updateAutomationButtons()
            task.wait(0.35)
            refreshUI(true)
        end)

        return true
    end

    if status.youEntered then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
        return false, "Sudah terdaftar"
    end

    local phaseInfo = getWorldCupPhase()
    if not phaseInfo or phaseInfo.phase ~= "entry" then
        State.nextWorldCupCheckAt = os.clock() + WORLD_CUP_CHECK_INTERVAL
        return false, "Entry belum terbuka"
    end

    local team, teamError = selectWorldCupTeam(status)
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
            "Mendaftarkan International Cup • %s • %s...",
            tostring(team.formation),
            worldCupSquadModeLabel(State.worldCupSquadMode)
        ),
        COLORS.warning
    )

    task.spawn(function()
        local response, errorMessage = runWithAutoMatchPaused(function()
            return callNetworkLoose("EnterWorldCup", {
                formation = team.formation,
                instanceIds = team.instanceIds,
            })
        end)

        State.joiningWorldCup = false
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
                    "Berhasil join International Cup • %s • %d pemain.",
                    tostring(team.formation),
                    #team.instanceIds
                ),
                COLORS.success
            )
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

local function fetchPrestigeInfo()
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

local function performPrestige(isAutomatic)
    if State.prestiging or State.collecting or State.loaning or State.joiningWorldCup then
        return false, "Automation lain sedang berjalan"
    end

    local prestigeInfo = State.prestigeInfo
    if not prestigeInfo or not prestigeInfo.eligible then
        local errorMessage
        prestigeInfo, errorMessage = fetchPrestigeInfo()
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
                    fetchPrestigeInfo()
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

local function collectAllReadyLoans(isAutomatic)
    if State.collecting
        or State.loaning
        or State.prestiging
        or State.evolvingCards
        or State.equippingBest
        or State.joiningWorldCup
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

local function loanOutTopRarity(isAutomatic)
    if State.loaning or State.collecting or State.prestiging or State.joiningWorldCup then
        return
    end

    if getEnabledRarityCount() == 0 then
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
    local durationLabel = getDurationLabel(selectedMinutes)

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

local function getReadyLoanCount()
    local readyCount = 0
    for _, row in ipairs(buildRows()) do
        if row.ready then
            readyCount += 1
        end
    end
    return readyCount
end

local function runAutomationTick()
    if not State.running then
        return
    end

    if State.autoMatchPendingSync
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
        or State.evolvingCards
        or State.equippingBest
        or State.joiningWorldCup
        or State.autoMatchTransaction
    then
        return
    end

    local now = os.clock()

    -- Auto Open Packs memakai EventBus bawaan game dan tidak membutuhkan Networker.
    -- Trigger diulang dengan cooldown bila pack masih tersisa atau event sebelumnya
    -- terabaikan karena match/playback sedang berlangsung.
    if State.autoOpenPacks and now >= State.nextAutoOpenPackAt then
        local packCount = getOwnedPackCount()
        if packCount <= 0 then
            State.lastObservedPackCount = 0
            State.nextAutoOpenPackAt = now + AUTO_PACK_RETRY_DELAY
        else
            local opened = openOwnedPacksAutomatically(true)
            State.nextAutoOpenPackAt = now + AUTO_PACK_RETRY_DELAY
            if opened then
                return
            end
        end
    end

    if not tryRediscoverNetworker() then
        return
    end

    ensureMatchPlaybackListeners()

    -- Recovery Auto Play: bila setting masih ON tetapi tidak ada playback yang
    -- terdeteksi, coba alur AUTO PLAY asli lagi. AttemptSendOut akan ditolak
    -- secara aman oleh server apabila sebuah match sebenarnya masih aktif.
    if State.autoMatch
        and not State.matchPlaybackActive
        and not State.settingAutoMatch
        and now >= State.nextAutoPlayEnsureAt
    then
        State.nextAutoPlayEnsureAt = now + AUTO_PLAY_ENSURE_DELAY
        local started = requestAutoPlayStart()
        if started and State.matchPlaybackActive then
            return
        end
    end

    -- Auto Evolve memproses satu grup duplicate per siklus melalui CombineCards.
    -- Tidak memakai AutoUpgradeAll dan tidak membutuhkan game pass AutoEvolve.
    if State.autoEvolveCards and now >= State.nextAutoEvolveAt then
        State.nextAutoEvolveAt = now + AUTO_EVOLVE_RETRY_DELAY
        if getEvolvableGroupCount() > 0 then
            if evolveCardsNow(true) then
                return
            end
        end
    end

    -- Equip Best hanya dijalankan saat koleksi/availability kartu berubah.
    -- Bila Auto Play aktif, setting backend SetAutoMatch dipause sementara
    -- resmi game, AutoFillBestEleven dipanggil, lalu Auto Play dimulai kembali.
    if State.autoEquipBest and now >= State.nextAutoEquipBestAt then
        local currentSignature = getSquadEquipSignature()
        if currentSignature ~= State.lastEquipBestSignature then
            State.nextAutoEquipBestAt = now + AUTO_EQUIP_BEST_RETRY_DELAY
            if equipBestEleven(true) then
                return
            end
        else
            State.nextAutoEquipBestAt = now + AUTO_EQUIP_BEST_RETRY_DELAY
        end
    end

    -- Auto Join International Cup memeriksa entry secara berkala. Mode Last Team
    -- memakai lineup turnamen terakhir; mode Best menyusun 11 pemain berdasarkan
    -- rarity terlebih dahulu lalu OVR, sekaligus memilih formation terbaik.
    local blockAutoLoanForWorldCup = false
    if State.autoJoinWorldCup and now >= State.nextWorldCupCheckAt then
        State.nextWorldCupCheckAt = now + WORLD_CUP_CHECK_INTERVAL
        if joinInternationalCup(true) then
            return
        end

        local phaseInfo = getWorldCupPhase()
        local cupStatus = State.worldCupStatus
        blockAutoLoanForWorldCup = phaseInfo
            and phaseInfo.phase == "entry"
            and not (cupStatus and cupStatus.youEntered)
    end

    -- Prestige memiliki prioritas tertinggi ketika seluruh requirement sudah terpenuhi.
    if State.autoPrestige and now >= State.nextPrestigeCheckAt then
        State.nextPrestigeCheckAt = now + PRESTIGE_CHECK_INTERVAL

        local prestigeInfo = fetchPrestigeInfo()
        if prestigeInfo and prestigeInfo.eligible then
            performPrestige(true)
            return
        end
    end

    -- Collect lebih dahulu supaya slot yang selesai segera tersedia lagi.
    if State.autoCollect and now >= State.nextAutoCollectAt then
        if getReadyLoanCount() > 0 then
            State.nextAutoCollectAt = now + AUTO_ACTION_INTERVAL
            collectAllReadyLoans(true)
            return
        end
    end

    if State.autoLoan and not blockAutoLoanForWorldCup and now >= State.nextAutoLoanAt then
        local hasFreeSlot = getLoanSlotState()
        if hasFreeSlot and getTopAvailableCard(false) then
            State.nextAutoLoanAt = now + AUTO_ACTION_INTERVAL
            loanOutTopRarity(true)
        else
            State.nextAutoLoanAt = now + AUTO_RETRY_DELAY
        end
    end
end

local function setVisible(visible)
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

local function rejoinCurrentServer()
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

local function loadWindUI()
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

local function getElementBaseFrame(element)
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

local function compactElement(element, titleSize, descSize)
    local frame = getElementBaseFrame(element)
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

    local container = ui.Container
    if container then
        local containerLayout = container:FindFirstChildOfClass("UIListLayout")
        if containerLayout then
            containerLayout.Padding = UDim.new(0, 6)
        end

        local titleFrame = container:FindFirstChild("TitleFrame")
        if titleFrame then
            local inner = titleFrame:FindFirstChild("TitleFrame")
            if inner then
                local innerPadding = inner:FindFirstChildOfClass("UIPadding")
                if innerPadding then
                    innerPadding.PaddingTop = UDim.new(0, 2)
                    innerPadding.PaddingBottom = UDim.new(0, 2)
                    innerPadding.PaddingLeft = UDim.new(0, 2)
                    innerPadding.PaddingRight = UDim.new(0, 2)
                end

                local innerLayout = inner:FindFirstChildOfClass("UIListLayout")
                if innerLayout then
                    innerLayout.Padding = UDim.new(0, 3)
                end
            end
        end
    end

    return element
end

local function compactButton(button)
    compactElement(button, 15, 13)

    local icon = button and button.UIElements and button.UIElements.ButtonIcon
    if icon then
        icon.Size = UDim2.fromOffset(17, 17)
    end

    return button
end

local function compactDropdown(dropdown)
    compactElement(dropdown, 15, 13)

    local control = dropdown and dropdown.UIElements and dropdown.UIElements.Dropdown
    if control then
        control.Size = UDim2.new(0, 142, 0, 32)

        local frame = control:FindFirstChild("Frame")
        local inner = frame and frame:FindFirstChild("Frame")
        local label = inner and inner:FindFirstChildWhichIsA("TextLabel")
        if label then
            label.TextSize = 14
        end
    end

    return dropdown
end

local function selectDashboardTab()
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

local function buildGui()
    local WindUI = loadWindUI()
    State.windUI = WindUI

    local Window = WindUI:CreateWindow({
        Title = HUB_TITLE,
        Author = "Loan • Match • Packs • Evolve • Equip Best • International Cup • Prestige",
        Folder = "xSansHUB_LoanOutManager",
        Icon = "handshake",
        Theme = "Indigo",
        ToggleKey = Enum.KeyCode[State.windowKeybind] or Enum.KeyCode.G,
        Size = UDim2.fromOffset(740, 560),
        MinSize = Vector2.new(590, 420),
        MaxSize = Vector2.new(920, 700),
        Resizable = true,
        AutoScale = true,
        NewElements = true,
        Radius = 10,
        ElementsRadius = 9,
        IconSize = 18,
        TopBarButtonIconSize = 10,
        SideBarWidth = 170,
        HideSearchBar = true,
        ScrollBarEnabled = false,
        OpenButton = {
            Title = HUB_TITLE,
            Icon = "handshake",
            Enabled = true,
            Draggable = true,
            OnlyMobile = false,
        },
        Topbar = {
            Height = 40,
            ButtonsType = "Mac",
        },
        User = {
            Enabled = false,
            Anonymous = false,
        },
    })

    if not Window then
        error("WindUI gagal membuat window. Hancurkan window WindUI lama lalu jalankan ulang script.")
    end

    State.window = Window
    Environment.LoanOutGUIWindWindow = Window

    -- Compact visual scale. These values are read when tab elements are created.
    Window.Gap = 4
    Window.ElementConfig.UIPadding = 8
    Window.ElementConfig.UICorner = 9

    Window:Tag({
        Title = "G to Toggle",
        Icon = "keyboard",
        Border = true,
    })

    Window:OnOpen(function()
        State.visible = true
        task.defer(function()
            selectDashboardTab()
            refreshUI(false)
        end)
    end)

    Window:OnClose(function()
        State.visible = false
    end)

    local DashboardTab = Window:Tab({
        Title = "Dashboard",
        Icon = "layout-dashboard",
        IconSize = 16,
    })
    State.dashboardTab = DashboardTab

    State.summaryParagraph = compactElement(DashboardTab:Paragraph({
        Title = "Loan Summary",
        Desc = "Loading loan data...",
        Image = "handshake",
        ImageSize = 21,
        Size = "Small",
    }))

    local actionGroup = DashboardTab:Group({})
    State.loanButton = compactButton(actionGroup:Button({
        Title = "Loan Top",
        Desc = "Kirim kandidat terbaik sesuai konfigurasi.",
        Icon = "send",
        Size = "Small",
        Callback = function()
            if State.loanButtonEnabled then
                loanOutTopRarity(false)
            end
        end,
    }))

    actionGroup:Space()

    State.collectButton = compactButton(actionGroup:Button({
        Title = "Collect All",
        Desc = "Ambil seluruh loan yang sudah selesai.",
        Icon = "package-check",
        Size = "Small",
        Callback = function()
            if State.collectButtonEnabled then
                collectAllReadyLoans(false)
            end
        end,
    }))

    DashboardTab:Space()
    State.dashboardParagraph = compactElement(DashboardTab:Paragraph({
        Title = "Auto Loan Dashboard",
        Desc = "No automation activity yet",
        Image = "chart-no-axes-combined",
        ImageSize = 21,
        Size = "Small",
    }))

    State.loanListParagraph = compactElement(DashboardTab:Paragraph({
        Title = "Active Loans",
        Desc = "Tidak ada pemain yang sedang loan out.",
        Image = "list",
        ImageSize = 20,
        Size = "Small",
    }))

    State.statusParagraph = compactElement(DashboardTab:Paragraph({
        Title = "Activity Status",
        Desc = "[WARNING] Connecting...",
        Image = "activity",
        ImageSize = 20,
        Size = "Small",
    }))

    local AutomationTab = Window:Tab({
        Title = "Automation",
        Icon = "bot",
        IconSize = 16,
    })
    State.automationTab = AutomationTab
    State.configurationTab = AutomationTab

    State.configurationParagraph = compactElement(AutomationTab:Paragraph({
        Title = "Auto Loan Configuration",
        Desc = "Loading configuration...",
        Image = "sliders-horizontal",
        ImageSize = 20,
        Size = "Small",
    }))

    local durationValues = {}
    for _, minutes in ipairs(State.durationOptions) do
        durationValues[#durationValues + 1] = getDurationLabel(minutes)
    end

    State.durationDropdown = compactDropdown(AutomationTab:Dropdown({
        Title = "Loan Duration",
        Desc = "Duration untuk tombol Loan Top dan Auto Loan.",
        Values = durationValues,
        Value = getDurationLabel(State.selectedDuration),
        SearchBarEnabled = false,
        Callback = function(selected)
            if State.syncingConfiguration then
                return
            end

            local selectedText = type(selected) == "table" and selected.Title or selected
            for _, minutes in ipairs(State.durationOptions) do
                if getDurationLabel(minutes) == tostring(selectedText) then
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
    }))

    local rarityValues = {}
    for _, rarity in ipairs(State.rarityOptions) do
        rarityValues[#rarityValues + 1] = tostring(rarity):gsub("WorldClass", "World Class")
    end

    State.rarityDropdown = compactDropdown(AutomationTab:Dropdown({
        Title = "Rarity Whitelist",
        Desc = "Auto Loan hanya memilih rarity yang aktif.",
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
    }))

    local whitelistGroup = AutomationTab:Group({})
    compactButton(whitelistGroup:Button({
        Title = "Enable All Rarities",
        Icon = "list-checks",
        Size = "Small",
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
    }))

    whitelistGroup:Space()
    compactButton(whitelistGroup:Button({
        Title = "Clear Whitelist",
        Icon = "list-x",
        Size = "Small",
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
    }))

    AutomationTab:Space()

    State.autoLoanToggle = AutomationTab:Toggle({
        Title = "Auto Loan",
        Desc = "Isi slot kosong menggunakan rarity whitelist dan duration terpilih.",
        Icon = "send",
        IconSize = 18,
        Value = State.autoLoan,
        Callback = function(enabled)
            setAutoLoanEnabled(enabled)
        end,
    })
    compactElement(State.autoLoanToggle, 15, 13)

    State.autoCollectToggle = AutomationTab:Toggle({
        Title = "Auto Collect",
        Desc = "Collect loan selesai sebelum Auto Loan mengisi slot kembali.",
        Icon = "package-check",
        IconSize = 18,
        Value = State.autoCollect,
        Callback = function(enabled)
            setAutoCollectEnabled(enabled)
        end,
    })
    compactElement(State.autoCollectToggle, 15, 13)

    State.autoMatchToggle = AutomationTab:Toggle({
        Title = "Auto Play",
        Desc = "Mulai match pertama melalui AttemptSendOut, lalu lanjut otomatis di background.",
        Icon = "play",
        IconSize = 18,
        Value = State.autoMatch,
        Callback = function(enabled)
            setAutoPlayEnabled(enabled)
        end,
    })
    compactElement(State.autoMatchToggle, 15, 13)

    State.autoOpenPacksToggle = AutomationTab:Toggle({
        Title = "Auto Open Packs",
        Desc = "Buka seluruh pack yang tersedia menggunakan mode AUTO OPEN bawaan game.",
        Icon = "package",
        IconSize = 18,
        Value = State.autoOpenPacks,
        Callback = function(enabled)
            setAutoOpenPacksEnabled(enabled)
        end,
    })
    compactElement(State.autoOpenPacksToggle, 15, 13)

    State.autoEvolveCardsToggle = AutomationTab:Toggle({
        Title = "Auto Evolve Cards",
        Desc = "Evolve duplicate satu per satu menggunakan CombineCards; tidak memerlukan game pass AutoEvolve.",
        Icon = "sparkles",
        IconSize = 18,
        Value = State.autoEvolveCards,
        Callback = function(enabled)
            setAutoEvolveCardsEnabled(enabled)
        end,
    })
    compactElement(State.autoEvolveCardsToggle, 15, 13)

    State.autoEquipBestToggle = AutomationTab:Toggle({
        Title = "Auto Equip Best",
        Desc = "Susun Starting Eleven terbaik saat koleksi berubah; Auto Play dipause lalu dimulai kembali.",
        Icon = "users",
        IconSize = 18,
        Value = State.autoEquipBest,
        Callback = function(enabled)
            setAutoEquipBestEnabled(enabled)
        end,
    })
    compactElement(State.autoEquipBestToggle, 15, 13)

    State.autoPrestigeToggle = AutomationTab:Toggle({
        Title = "Auto Prestige",
        Desc = "Prestige otomatis saat eligible. Division dan Coins akan di-reset.",
        -- `badge-star` tidak tersedia pada icon set WindUI yang sedang dimuat.
        Icon = "trophy",
        IconSize = 18,
        Value = State.autoPrestige,
        Callback = function(enabled)
            setAutoPrestigeEnabled(enabled)
        end,
    })
    compactElement(State.autoPrestigeToggle, 15, 13)

    AutomationTab:Space()
    State.prestigeParagraph = compactElement(AutomationTab:Paragraph({
        Title = "Prestige Status",
        Desc = "Belum ada data. Tekan Check Prestige untuk memuat status terbaru.",
        Image = "trophy",
        ImageSize = 20,
        Size = "Small",
    }))

    -- Requirement dibuat menjadi kartu 2 kolom agar tidak menumpuk dalam satu paragraph.
    State.prestigeGateParagraphs = {}
    for rowIndex = 1, 3 do
        local gateGroup = AutomationTab:Group({})

        for columnIndex = 1, 2 do
            local gateParagraph = compactElement(gateGroup:Paragraph({
                Title = "Requirement",
                Desc = "Menunggu data...",
                Size = "Small",
            }))

            if gateParagraph.ElementFrame then
                gateParagraph.ElementFrame.Visible = false
            end

            State.prestigeGateParagraphs[#State.prestigeGateParagraphs + 1] = gateParagraph

            if columnIndex == 1 then
                gateGroup:Space()
            end
        end
    end

    AutomationTab:Space()
    local prestigeGroup = AutomationTab:Group({})
    compactButton(prestigeGroup:Button({
        Title = "Check Prestige",
        Desc = "Refresh eligibility dan seluruh requirement prestige.",
        Icon = "refresh-cw",
        Size = "Small",
        Callback = function()
            local info, errorMessage = fetchPrestigeInfo()
            if info then
                updatePrestigeParagraph()
                setStatus("Prestige info berhasil diperbarui.", COLORS.success)
            else
                setStatus("Gagal mengecek prestige: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    }))

    prestigeGroup:Space()
    State.prestigeButton = compactButton(prestigeGroup:Button({
        Title = "Prestige Now",
        Desc = "Menjalankan prestige jika seluruh requirement sudah terpenuhi.",
        Icon = "sparkles",
        Size = "Small",
        Callback = function()
            performPrestige(false)
        end,
    }))

    local WorldCupTab = Window:Tab({
        Title = "International Cup",
        Icon = "trophy",
        IconSize = 16,
    })
    State.worldCupTab = WorldCupTab

    State.worldCupParagraph = compactElement(WorldCupTab:Paragraph({
        Title = "International Cup",
        Desc = "Tekan Check Cup Status untuk memuat fase dan status entry terbaru.",
        Image = "trophy",
        ImageSize = 20,
        Size = "Small",
    }))

    State.worldCupSquadDropdown = compactDropdown(WorldCupTab:Dropdown({
        Title = "Cup Squad Selection",
        Desc = "Last Team memakai tim Cup sebelumnya; Best memilih rarity lalu OVR tertinggi.",
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
    }))

    State.autoJoinWorldCupToggle = WorldCupTab:Toggle({
        Title = "Auto Join International Cup",
        Desc = "Join otomatis ketika entry terbuka dan claim reward sebelumnya bila diperlukan.",
        Icon = "trophy",
        IconSize = 18,
        Value = State.autoJoinWorldCup,
        Callback = function(enabled)
            setAutoJoinWorldCupEnabled(enabled)
        end,
    })
    compactElement(State.autoJoinWorldCupToggle, 15, 13)

    WorldCupTab:Space()
    local worldCupActionGroup = WorldCupTab:Group({})
    State.worldCupCheckButton = compactButton(worldCupActionGroup:Button({
        Title = "Check Cup Status",
        Desc = "Refresh phase, reward, dan status entry International Cup.",
        Icon = "refresh-cw",
        Size = "Small",
        Callback = function()
            local status, errorMessage = fetchWorldCupStatus()
            if status then
                setStatus("Status International Cup berhasil diperbarui.", COLORS.success)
                refreshUI(true)
            else
                setStatus("Gagal mengecek International Cup: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    }))

    worldCupActionGroup:Space()
    State.worldCupJoinButton = compactButton(worldCupActionGroup:Button({
        Title = "Join International Cup",
        Desc = "Join menggunakan squad mode yang dipilih.",
        Icon = "trophy",
        Size = "Small",
        Callback = function()
            joinInternationalCup(false)
        end,
    }))

    local SettingsTab = Window:Tab({
        Title = "Settings",
        Icon = "settings",
        IconSize = 16,
    })
    State.settingsTab = SettingsTab

    State.configParagraph = compactElement(SettingsTab:Paragraph({
        Title = "Configuration Manager",
        Desc = "Memeriksa dukungan file config...",
        Image = "save",
        ImageSize = 20,
        Size = "Small",
    }))

    State.windowKeybindControl = SettingsTab:Keybind({
        Title = "Window Keybind",
        Desc = "Key untuk membuka dan menutup WindUI.",
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
    })
    compactElement(State.windowKeybindControl, 15, 13)

    State.autoSaveToggle = SettingsTab:Toggle({
        Title = "Auto Save Config",
        Desc = "Simpan perubahan konfigurasi secara otomatis.",
        Icon = "save",
        IconSize = 18,
        Value = State.autoSave,
        Callback = function(enabled)
            setAutoSaveEnabled(enabled)
            setStatus(
                enabled and "Auto Save Config diaktifkan." or "Auto Save Config dinonaktifkan.",
                enabled and COLORS.success or COLORS.muted
            )
        end,
    })
    compactElement(State.autoSaveToggle, 15, 13)

    State.autoLoadToggle = SettingsTab:Toggle({
        Title = "Auto Load Config",
        Desc = "Terapkan config tersimpan secara otomatis saat script dijalankan.",
        Icon = "folder-down",
        IconSize = 18,
        Value = State.autoLoad,
        Callback = function(enabled)
            setAutoLoadEnabled(enabled)
            setStatus(
                enabled and "Auto Load Config diaktifkan." or "Auto Load Config dinonaktifkan.",
                enabled and COLORS.success or COLORS.muted
            )
        end,
    })
    compactElement(State.autoLoadToggle, 15, 13)

    local configActionGroup = SettingsTab:Group({})
    State.saveConfigButton = compactButton(configActionGroup:Button({
        Title = "Save Config",
        Desc = "Simpan seluruh pengaturan saat ini ke file.",
        Icon = "save",
        Size = "Small",
        Callback = function()
            local success, errorMessage = saveConfigToDisk()
            if success then
                setStatus("Config berhasil disimpan.", COLORS.success)
            else
                setStatus("Gagal menyimpan config: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    }))

    configActionGroup:Space()
    State.loadConfigButton = compactButton(configActionGroup:Button({
        Title = "Load Config",
        Desc = "Muat dan terapkan file config yang tersimpan.",
        Icon = "folder-down",
        Size = "Small",
        Callback = function()
            local success, errorMessage = loadConfigFromDisk()
            if success then
                setStatus("Config berhasil dimuat dan diterapkan.", COLORS.success)
            else
                setStatus("Gagal memuat config: " .. tostring(errorMessage), COLORS.danger)
            end
        end,
    }))

    SettingsTab:Space()
    State.rejoinButton = compactButton(SettingsTab:Button({
        Title = "Rejoin Server",
        Desc = "Masuk kembali ke server saat ini; fallback ke place yang sama jika JobId tidak tersedia.",
        Icon = "refresh-cw",
        Size = "Small",
        Callback = function()
            rejoinCurrentServer()
        end,
    }))

    compactButton(SettingsTab:Button({
        Title = "Reset Dashboard",
        Desc = "Reset statistik Auto Loan pada sesi ini.",
        Icon = "rotate-ccw",
        Size = "Small",
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
            setStatus("Dashboard automation di-reset.", COLORS.success)
        end,
    }))

    compactButton(SettingsTab:Button({
        Title = "Refresh All Data",
        Desc = "Refresh loan, dashboard, candidate, dan prestige info.",
        Icon = "refresh-cw",
        Size = "Small",
        Callback = function()
            State.cachedTopCard = nil
            fetchPrestigeInfo()
            refreshUI(true)
            setStatus("Seluruh data berhasil di-refresh.", COLORS.success)
        end,
    }))

    setCollectButton("Collect All", false)
    setLoanButton("Loan Top", false)
    updateAutomationButtons()
    updateConfigurationVisuals()
    updateDashboardUI()
    updatePrestigeParagraph()
    updateConfigManagerUI()

    if State.autoSave and State.configSupported and not configFileExists() then
        saveConfigToDisk()
    end

    if State.startupConfigLoaded then
        setStatus("Auto Load: config berhasil diterapkan saat startup.", COLORS.success)
    elseif State.startupConfigError then
        setStatus("Config startup gagal dibaca: " .. tostring(State.startupConfigError), COLORS.danger)
    elseif not State.configSupported then
        setStatus("File config tidak didukung executor ini; pengaturan hanya tersimpan selama sesi.", COLORS.warning)
    else
        setStatus(State.lastStatusText, COLORS.warning)
    end

    -- WindUI does not always select the first tab automatically.
    -- Select Dashboard now and every time the window is reopened.
    task.defer(function()
        selectDashboardTab()
        refreshUI(true)
    end)

    WindUI:Notify({
        Title = HUB_TITLE,
        Content = "WindUI loaded. Tekan G atau klik floating icon untuk membuka/menutup window.",
        Icon = "handshake",
        Duration = 5,
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
        setVisible(not State.visible)
    end
end

function API.Show()
    setVisible(true)
end

function API.Hide()
    setVisible(false)
end

function API.Refresh()
    refreshUI(true)
end

function API.CollectAll()
    collectAllReadyLoans()
end

function API.LoanTop()
    loanOutTopRarity(false)
end

-- Backward compatibility: sekarang mengikuti durasi yang dipilih.
function API.LoanTop5Min()
    loanOutTopRarity(false)
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

function API.ToggleAutoEvolveCards()
    setAutoEvolveCardsEnabled(not State.autoEvolveCards)
end

function API.ToggleAutoEquipBest()
    setAutoEquipBestEnabled(not State.autoEquipBest)
end

function API.ToggleAutoJoinWorldCup()
    setAutoJoinWorldCupEnabled(not State.autoJoinWorldCup)
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

function API.SetAutoEvolveCards(enabled)
    setAutoEvolveCardsEnabled(enabled)
end

function API.SetAutoEquipBest(enabled)
    setAutoEquipBestEnabled(enabled)
end

function API.SetAutoJoinWorldCup(enabled)
    setAutoJoinWorldCupEnabled(enabled)
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

function API.OpenPacksNow()
    return openOwnedPacksAutomatically(false)
end

function API.EvolveCardsNow()
    return evolveCardsNow(false)
end

function API.EquipBestNow()
    return equipBestEleven(false)
end

function API.JoinInternationalCupNow()
    return joinInternationalCup(false)
end

function API.CheckInternationalCup()
    return fetchWorldCupStatus()
end

function API.Rejoin()
    return rejoinCurrentServer()
end

function API.GetAutoJoinWorldCupState()
    local phaseInfo = getWorldCupPhase()
    return {
        enabled = State.autoJoinWorldCup,
        running = State.joiningWorldCup,
        squadMode = State.worldCupSquadMode,
        squadModeLabel = worldCupSquadModeLabel(State.worldCupSquadMode),
        phase = phaseInfo and phaseInfo.phase or nil,
        status = State.worldCupStatus,
        lastJoinedAt = State.lastWorldCupJoinAt,
        lastCollectedAt = State.lastWorldCupCollectAt,
        nextAttemptAt = State.nextWorldCupCheckAt,
    }
end

function API.GetAutoEvolveState()
    local groups = buildEvolvableGroups()
    local nextGroup = groups[1]
    return {
        enabled = State.autoEvolveCards,
        running = State.evolvingCards,
        mode = "CombineCards",
        oneByOne = true,
        evolvableGroups = #groups,
        nextBaseId = nextGroup and nextGroup.baseId or nil,
        nextCardName = nextGroup and nextGroup.baseCard and nextGroup.baseCard.name or nil,
        nextAttemptAt = State.nextAutoEvolveAt,
    }
end

function API.GetAutoEquipBestState()
    return {
        enabled = State.autoEquipBest,
        running = State.equippingBest,
        matchPlaybackActive = State.matchPlaybackActive,
        lastEquippedAt = State.lastEquipBestAt,
        nextAttemptAt = State.nextAutoEquipBestAt,
    }
end

function API.GetAutoOpenPacksState()
    return {
        enabled = State.autoOpenPacks,
        opening = State.openingPacks,
        owned = getOwnedPackCount(),
        lastOpenedAt = State.lastPackOpenAt,
        nextAttemptAt = State.nextAutoOpenPackAt,
    }
end

function API.GetAutoPlayState()
    return {
        enabled = State.autoMatch,
        syncing = State.settingAutoMatch,
        pending = State.autoMatchPendingSync,
        serverValue = getData("Settings.AutoMatch"),
        playbackActive = State.matchPlaybackActive,
        flow = "AttemptSendOut -> SetAutoMatch -> MatchPlaybackRequested(background)",
    }
end

function API.GetAutoMatchState()
    return API.GetAutoPlayState()
end

function API.PrestigeNow()
    return performPrestige(false)
end

function API.CheckPrestige()
    return fetchPrestigeInfo()
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
        autoEvolveCards = State.autoEvolveCards,
        autoEquipBest = State.autoEquipBest,
        autoJoinWorldCup = State.autoJoinWorldCup,
        worldCupSquadMode = State.worldCupSquadMode,
        joiningWorldCup = State.joiningWorldCup,
        openingPacks = State.openingPacks,
        evolvingCards = State.evolvingCards,
        equippingBest = State.equippingBest,
        ownedPacks = getOwnedPackCount(),
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
        autoJoinWorldCup = State.autoJoinWorldCup,
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
    State.autoEvolveCards = false
    State.autoEquipBest = false
    State.autoJoinWorldCup = false
    State.openingPacks = false
    State.evolvingCards = false
    State.equippingBest = false
    State.joiningWorldCup = false
    State.rejoining = false
    State.autoMatchTransaction = false
    State.settingAutoMatch = false
    State.autoMatchPendingSync = false
    State.prestiging = false
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
buildGui()
updateAutomationButtons()


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
    refreshUI(true)

    while State.running do
        task.wait(POLL_INTERVAL)

        -- Polling-only: seluruh pembacaan data dan perubahan WindUI dilakukan
        -- dari loop milik script ini. Tidak ada callback Signal game yang dapat
        -- memanggil SetDesc/SetTitle dari thread tanpa capability.
        refreshUI(false)
        runAutomationTick()
    end
end)
