--[[
    Standalone Loan Out Manager - WindUI

    Fitur:
      - Menggunakan WindUI dengan keybind G dan floating OpenButton.
      - Judul otomatis: xSansHUB - nama game saat ini.
      - Menampilkan seluruh pemain yang sedang loan out.
      - Collect All untuk seluruh loan yang sudah selesai.
      - Loan Top berdasarkan whitelist rarity dan durasi yang dipilih.
      - Toggle Auto Loan, Auto Collect, Auto Match, Auto Open Packs, dan Auto Prestige.
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

local CONFIG_VERSION = 3
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
    if source.autoMatch ~= nil then
        target.autoMatch = source.autoMatch == true
    end
    if source.autoOpenPacks ~= nil then
        target.autoOpenPacks = source.autoOpenPacks == true
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
local AUTO_PACK_RETRY_DELAY = 8
local TRACKED_LOAN_GRACE = 5

local FALLBACK_DURATIONS = {5, 15, 30, 60}

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
    autoMatch = PersistentConfig.autoMatch == true,
    autoOpenPacks = PersistentConfig.autoOpenPacks == true,
    settingAutoMatch = false,
    openingPacks = false,
    autoMatchPendingSync = PersistentConfig.autoMatch ~= nil and StartupConfigLoaded,
    autoMatchSyncIgnoreUntil = 0,
    nextAutoMatchSyncAt = 0,
    nextAutoOpenPackAt = 0,
    lastObservedPackCount = 0,
    lastPackOpenAt = 0,
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

    windUI = nil,
    window = nil,
    dashboardTab = nil,
    automationTab = nil,
    configurationTab = nil,
    settingsTab = nil,

    summaryParagraph = nil,
    dashboardParagraph = nil,
    statusParagraph = nil,
    loanListParagraph = nil,
    prestigeParagraph = nil,
    prestigeGateParagraphs = {},
    prestigeInfoUpdatedAt = 0,
    configurationParagraph = nil,

    collectButton = nil,
    loanButton = nil,
    prestigeButton = nil,
    autoLoanToggle = nil,
    autoCollectToggle = nil,
    autoMatchToggle = nil,
    autoOpenPacksToggle = nil,
    autoPrestigeToggle = nil,
    durationDropdown = nil,
    rarityDropdown = nil,
    configParagraph = nil,
    autoSaveToggle = nil,
    autoLoadToggle = nil,
    windowKeybindControl = nil,
    saveConfigButton = nil,
    loadConfigButton = nil,

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
    PersistentConfig.autoMatch = State.autoMatch == true
    PersistentConfig.autoOpenPacks = State.autoOpenPacks == true
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
        autoMatch = State.autoMatch == true,
        autoOpenPacks = State.autoOpenPacks == true,
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
        if State.settingAutoMatch then
            autoMatchDesc = "SYNCING • mengirim pengaturan Auto Match ke server."
        elseif State.autoMatchPendingSync then
            autoMatchDesc = "PENDING • menunggu Networker untuk menerapkan config Auto Match."
        elseif State.autoMatch then
            autoMatchDesc = "ACTIVE • game akan menjalankan match berikutnya secara otomatis."
        else
            autoMatchDesc = "Game tidak akan memulai match berikutnya secara otomatis."
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
end

local function getData(path)
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

local function findTopAvailableCard()
    local ownedCards = getData("Squad.Owned")
    if type(ownedCards) ~= "table" then
        return nil
    end

    local unavailable = getUnavailableCardIds()
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
    if config.autoMatch ~= nil then
        State.autoMatch = config.autoMatch == true
        State.autoMatchPendingSync = true
    end
    if config.autoOpenPacks ~= nil then
        State.autoOpenPacks = config.autoOpenPacks == true
    end

    State.nextAutoLoanAt = 0
    State.nextAutoCollectAt = 0
    State.nextPrestigeCheckAt = 0
    State.nextAutoOpenPackAt = 0
    State.lastObservedPackCount = 0
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

    -- Settings.AutoMatch adalah source of truth dari game. Saat config belum
    -- menunggu sinkronisasi dan request tidak sedang berjalan, ikuti perubahan
    -- dari menu/indicator bawaan game (misalnya tombol STOP).
    if not State.settingAutoMatch
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
    local actionBusy = State.collecting or State.loaning or State.prestiging

    if not State.collecting then
        if readyCount > 0 and networkReady and not State.loaning and not State.prestiging then
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

    if response.success == false then
        return response, tostring(response.reason or "Request gagal")
    end

    return response, nil
end

local function setAutoMatchEnabled(enabled, announce, forceRequest)
    enabled = enabled == true

    if State.settingAutoMatch then
        return false, "Pengaturan Auto Match sedang diproses"
    end

    local previousValue = State.autoMatch
    State.autoMatch = enabled
    PersistentConfig.autoMatch = enabled
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
            setStatus("Auto Match menunggu Networker ditemukan.", COLORS.warning)
        end
        return false, "Networker belum ditemukan"
    end

    State.settingAutoMatch = true
    State.autoMatchPendingSync = false
    updateAutomationButtons()

    task.spawn(function()
        local networker = State.networker
        local success, response = pcall(networker.Call, networker, "SetAutoMatch", {
            enabled = enabled,
        })

        local accepted = success
        local errorMessage = success and nil or tostring(response)
        if success and type(response) == "table" and response.success == false then
            accepted = false
            errorMessage = tostring(response.reason or "Request SetAutoMatch ditolak")
        end

        State.settingAutoMatch = false

        if accepted then
            State.autoMatch = enabled
            PersistentConfig.autoMatch = enabled
            State.autoMatchSyncIgnoreUntil = os.clock() + 5
            State.nextAutoMatchSyncAt = 0
            State.autoMatchPendingSync = false
            requestConfigSave()

            if announce ~= false then
                setStatus(
                    enabled and "Auto Match diaktifkan." or "Auto Match dinonaktifkan.",
                    enabled and COLORS.success or COLORS.muted
                )
            end
        else
            local serverValue = getData("Settings.AutoMatch")
            if type(serverValue) == "boolean" then
                State.autoMatch = serverValue
            else
                State.autoMatch = previousValue
            end
            PersistentConfig.autoMatch = State.autoMatch
            State.autoMatchPendingSync = forceRequest == true
            State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY

            if announce ~= false then
                setStatus("Auto Match gagal: " .. tostring(errorMessage), COLORS.danger)
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
    if State.prestiging or State.collecting or State.loaning then
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
    if State.collecting or State.loaning or State.prestiging then
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
    if State.loaning or State.collecting or State.prestiging then
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
            setAutoMatchEnabled(State.autoMatch, false, true)
        else
            State.nextAutoMatchSyncAt = os.clock() + AUTO_MATCH_RETRY_DELAY
        end
    end

    if State.collecting or State.loaning or State.prestiging then
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

    if State.autoLoan and now >= State.nextAutoLoanAt then
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
        Author = "Auto Loan • Auto Collect • Auto Match • Auto Packs • Auto Prestige",
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
        Title = "Auto Match",
        Desc = "Mulai match berikutnya secara otomatis menggunakan setting bawaan game.",
        Icon = "play",
        IconSize = 18,
        Value = State.autoMatch,
        Callback = function(enabled)
            setAutoMatchEnabled(enabled)
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

function API.ToggleAutoMatch()
    return setAutoMatchEnabled(not State.autoMatch)
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

function API.SetAutoMatch(enabled)
    return setAutoMatchEnabled(enabled)
end

function API.OpenPacksNow()
    return openOwnedPacksAutomatically(false)
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

function API.GetAutoMatchState()
    return {
        enabled = State.autoMatch,
        syncing = State.settingAutoMatch,
        pending = State.autoMatchPendingSync,
        serverValue = getData("Settings.AutoMatch"),
    }
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
        autoMatch = State.autoMatch,
        autoOpenPacks = State.autoOpenPacks,
        openingPacks = State.openingPacks,
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
    State.openingPacks = false
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

    -- Terapkan Auto Match dari config setelah Networker tersedia. Jika tidak
    -- ada nilai config, refreshUI akan mengikuti Settings.AutoMatch milik game.
    if State.autoMatchPendingSync then
        setAutoMatchEnabled(State.autoMatch, false, true)
    end

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
