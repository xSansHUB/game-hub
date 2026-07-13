--[[
    Standalone Loan Out GUI - Whitelist, Duration & Dashboard

    Fitur:
      - Tekan G untuk membuka/menutup GUI.
      - Menampilkan seluruh pemain yang sedang loan out.
      - Collect All untuk seluruh loan yang sudah selesai.
      - Loan Top berdasarkan whitelist rarity dan durasi yang dipilih.
      - Toggle Auto Loan, Auto Collect, dan Auto Prestige.
      - Whitelist rarity multi-select untuk Auto Loan.
      - Pilihan durasi diambil dari LoanConfig.Durations.
      - Dashboard sesi Auto Loan: terkirim, masih berputar, selesai, dan income.
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
      LoanOutGUI.PrestigeNow()
      LoanOutGUI.Stop()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Environment = if type(getgenv) == "function" then getgenv() else _G

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

if type(PersistentConfig.rarityWhitelist) ~= "table" then
    PersistentConfig.rarityWhitelist = {}
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

    screenGui = nil,
    mainFrame = nil,
    list = nil,
    summaryLabel = nil,
    statusLabel = nil,
    collectButton = nil,
    collectButtonLabel = nil,
    loanButton = nil,
    loanButtonLabel = nil,
    autoLoanButton = nil,
    autoLoanLabel = nil,
    autoLoanIndicator = nil,
    autoCollectButton = nil,
    autoCollectLabel = nil,
    autoCollectIndicator = nil,
    autoPrestigeButton = nil,
    autoPrestigeLabel = nil,
    autoPrestigeIndicator = nil,
    durationContainer = nil,
    rarityContainer = nil,
    durationButtons = {},
    rarityButtons = {},
    rarityCountLabel = nil,
    dashboardSent = nil,
    dashboardActive = nil,
    dashboardCollected = nil,
    dashboardIncome = nil,
    dashboardMeta = nil,
    emptyLabel = nil,

    connections = {},
    rowViews = {},
    lastStructureSignature = nil,
    cachedTopCard = nil,
    lastTopCardScan = 0,
    nextAutoLoanAt = 0,
    nextAutoCollectAt = 0,
    nextPrestigeCheckAt = 0,
}

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

    -- Hentikan logger versi lama agar daftar tidak lagi dicetak ke Output.
    local oldLogger = Environment.LoanOutLogger
    if type(oldLogger) == "table" and type(oldLogger.Stop) == "function" then
        pcall(oldLogger.Stop)
    end

    local parent = CoreGui
    if type(gethui) == "function" then
        local success, hiddenUi = pcall(gethui)
        if success and hiddenUi then
            parent = hiddenUi
        end
    end

    local existing = parent:FindFirstChild(GUI_NAME)
    if existing then
        existing:Destroy()
    end
end

stopPreviousInstances()

local function addConnection(connection)
    if connection then
        State.connections[#State.connections + 1] = connection
    end
    return connection
end

local function create(className, properties)
    local instance = Instance.new(className)

    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then
            instance[property] = value
        end
    end

    instance.Parent = properties and properties.Parent or nil
    return instance
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or COLORS.border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function setStatus(text, color)
    if State.statusLabel then
        State.statusLabel.Text = tostring(text or "")
        State.statusLabel.TextColor3 = color or COLORS.muted
    end
end

local function setCollectButton(text, enabled)
    local button = State.collectButton
    local label = State.collectButtonLabel

    if not button or not label then
        return
    end

    label.Text = text
    button.Active = enabled
    button.AutoButtonColor = false
    button.BackgroundColor3 = enabled and COLORS.primary or Color3.fromRGB(62, 66, 82)
    label.TextColor3 = enabled and COLORS.text or COLORS.muted
end

local function setLoanButton(text, enabled)
    local button = State.loanButton
    local label = State.loanButtonLabel

    if not button or not label then
        return
    end

    label.Text = text
    button.Active = enabled
    button.AutoButtonColor = false
    button.BackgroundColor3 = enabled and COLORS.success or Color3.fromRGB(62, 66, 82)
    label.TextColor3 = enabled and COLORS.background or COLORS.muted
end

local function updateToggleVisual(button, label, indicator, enabled, title)
    if not button or not label or not indicator then
        return
    end

    label.Text = string.format("%s: %s", title, enabled and "ON" or "OFF")
    label.TextColor3 = enabled and COLORS.text or COLORS.muted
    indicator.BackgroundColor3 = enabled and COLORS.success or Color3.fromRGB(90, 95, 114)
    button.BackgroundColor3 = enabled and Color3.fromRGB(42, 67, 57) or COLORS.panelAlt
end

local function updateAutomationButtons()
    updateToggleVisual(
        State.autoLoanButton,
        State.autoLoanLabel,
        State.autoLoanIndicator,
        State.autoLoan,
        "Auto Loan"
    )

    updateToggleVisual(
        State.autoCollectButton,
        State.autoCollectLabel,
        State.autoCollectIndicator,
        State.autoCollect,
        "Auto Collect"
    )

    updateToggleVisual(
        State.autoPrestigeButton,
        State.autoPrestigeLabel,
        State.autoPrestigeIndicator,
        State.autoPrestige,
        "Auto Prestige"
    )

    if State.autoPrestigeLabel and State.autoPrestige then
        if State.prestiging then
            State.autoPrestigeLabel.Text = "Auto Prestige: RUNNING"
            State.autoPrestigeIndicator.BackgroundColor3 = COLORS.warning
        elseif State.prestigeInfo and State.prestigeInfo.eligible then
            State.autoPrestigeLabel.Text = "Auto Prestige: READY"
            State.autoPrestigeIndicator.BackgroundColor3 = COLORS.warning
        end
    end
end

local function setAutoLoanEnabled(enabled, announce)
    State.autoLoan = enabled == true
    PersistentConfig.autoLoan = State.autoLoan
    State.nextAutoLoanAt = 0
    State.cachedTopCard = nil
    updateAutomationButtons()

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

    if announce ~= false then
        setStatus(
            State.autoCollect
                and "Auto Collect aktif • loan selesai akan diambil otomatis."
                or "Auto Collect dinonaktifkan.",
            State.autoCollect and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoPrestigeEnabled(enabled, announce)
    State.autoPrestige = enabled == true
    PersistentConfig.autoPrestige = State.autoPrestige
    State.nextPrestigeCheckAt = 0
    State.prestigeInfo = nil
    updateAutomationButtons()

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

local function getDurationLabel(minutes)
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

local function getEnabledRarityCount()
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
                local eventBus = rawget(core, "EventBus")

                if not foundDataService and isDataService(dataService) then
                    foundDataService = dataService
                end

                if not foundNetworker and isNetworker(networker) then
                    foundNetworker = networker
                end

                if not foundEventBus and eventBus ~= nil then
                    foundEventBus = eventBus
                end

                if foundDataService and foundNetworker then
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
    for _, view in pairs(State.rowViews) do
        if view.frame then
            view.frame:Destroy()
        end
    end

    table.clear(State.rowViews)
end

local function makeText(parent, text, size, position, alignment)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Size = size,
        Position = position,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = COLORS.text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = alignment or Enum.TextXAlignment.Left,
        Parent = parent,
    })
end

local function createRow(row, layoutOrder)
    local frame = create("Frame", {
        Name = "Loan_" .. tostring(row.slot),
        Size = UDim2.new(1, -6, 0, 58),
        BackgroundColor3 = COLORS.panelAlt,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        Parent = State.list,
    })
    addCorner(frame, 8)
    addStroke(frame, COLORS.border, 1, 0.35)

    local accent = create("Frame", {
        Size = UDim2.new(0, 4, 1, -14),
        Position = UDim2.new(0, 7, 0, 7),
        BackgroundColor3 = row.ready and COLORS.success or COLORS.primary,
        BorderSizePixel = 0,
        Parent = frame,
    })
    addCorner(accent, 4)

    local playerLabel = makeText(
        frame,
        row.name,
        UDim2.new(0.39, -18, 0, 22),
        UDim2.new(0, 20, 0, 8),
        Enum.TextXAlignment.Left
    )
    playerLabel.Font = Enum.Font.GothamBold
    playerLabel.TextSize = 14

    local detailLabel = makeText(
        frame,
        string.format("Slot %d • %s • %s", row.slot, row.position, row.rarity),
        UDim2.new(0.39, -18, 0, 20),
        UDim2.new(0, 20, 0, 30),
        Enum.TextXAlignment.Left
    )
    detailLabel.TextColor3 = COLORS.muted
    detailLabel.TextSize = 11

    local ratingLabel = makeText(
        frame,
        tostring(row.rating),
        UDim2.new(0.11, 0, 1, 0),
        UDim2.new(0.39, 0, 0, 0),
        Enum.TextXAlignment.Center
    )
    ratingLabel.Font = Enum.Font.GothamBold
    ratingLabel.TextSize = 16

    local statusLabel = makeText(
        frame,
        row.ready and "READY" or "ON LOAN",
        UDim2.new(0.22, 0, 1, 0),
        UDim2.new(0.50, 0, 0, 0),
        Enum.TextXAlignment.Center
    )
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextColor3 = row.ready and COLORS.success or COLORS.warning

    local remainingLabel = makeText(
        frame,
        row.ready and "Collect now" or formatRemaining(row.remaining),
        UDim2.new(0.28, -14, 1, 0),
        UDim2.new(0.72, 0, 0, 0),
        Enum.TextXAlignment.Right
    )
    remainingLabel.Font = Enum.Font.GothamBold
    remainingLabel.TextColor3 = row.ready and COLORS.success or COLORS.text

    State.rowViews[row.key] = {
        frame = frame,
        accent = accent,
        statusLabel = statusLabel,
        remainingLabel = remainingLabel,
    }
end

local function updateCanvasSize()
    if not State.list then
        return
    end

    local layout = State.list:FindFirstChildOfClass("UIListLayout")
    if layout then
        State.list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end
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

local function updateDashboardUI()
    if State.dashboardSent then
        State.dashboardSent.Text = formatNumber(State.stats.autoSent)
    end
    if State.dashboardActive then
        State.dashboardActive.Text = formatNumber(getTrackedAutoLoanCount())
    end
    if State.dashboardCollected then
        State.dashboardCollected.Text = formatNumber(State.stats.autoCollected)
    end
    if State.dashboardIncome then
        State.dashboardIncome.Text = "£" .. formatCompactNumber(State.stats.autoIncome)
    end
    if State.dashboardMeta then
        State.dashboardMeta.Text = string.format(
            "%s  •  Failed: %d  •  Last income: £%s",
            tostring(State.stats.lastAction),
            tonumber(State.stats.failures) or 0,
            formatCompactNumber(State.stats.lastIncome)
        )
    end
end

local function updateConfigurationVisuals()
    for minutes, buttonData in pairs(State.durationButtons) do
        local selected = tonumber(minutes) == State.selectedDuration
        buttonData.button.BackgroundColor3 = selected and COLORS.primary or COLORS.panelAlt
        buttonData.label.TextColor3 = selected and COLORS.text or COLORS.muted
    end

    for rarity, buttonData in pairs(State.rarityButtons) do
        local enabled = isRarityWhitelisted(rarity)
        buttonData.button.BackgroundColor3 = enabled and Color3.fromRGB(42, 67, 57) or COLORS.panelAlt
        buttonData.indicator.BackgroundColor3 = enabled and COLORS.success or Color3.fromRGB(90, 95, 114)
        buttonData.label.TextColor3 = enabled and COLORS.text or COLORS.muted
    end

    if State.rarityCountLabel then
        State.rarityCountLabel.Text = string.format(
            "%d/%d enabled",
            getEnabledRarityCount(),
            #State.rarityOptions
        )
    end
end

local function refreshUI(forceRebuild)
    if not State.running or not State.list then
        return
    end

    local rows = buildRows()
    reconcileTrackedAutoLoans(rows)
    local signature = buildStructureSignature(rows)
    local topCard = getTopAvailableCard(forceRebuild)
    local hasFreeSlot, activeCount, slotCapacity = getLoanSlotState()
    local readyCount = 0

    for _, row in ipairs(rows) do
        if row.ready then
            readyCount += 1
        end
    end

    if forceRebuild or signature ~= State.lastStructureSignature then
        State.lastStructureSignature = signature
        clearRows()

        for index, row in ipairs(rows) do
            createRow(row, index)
        end

        updateCanvasSize()
    else
        for _, row in ipairs(rows) do
            local view = State.rowViews[row.key]
            if view then
                view.statusLabel.Text = row.ready and "READY" or "ON LOAN"
                view.statusLabel.TextColor3 = row.ready and COLORS.success or COLORS.warning
                view.remainingLabel.Text = row.ready and "Collect now" or formatRemaining(row.remaining)
                view.remainingLabel.TextColor3 = row.ready and COLORS.success or COLORS.text
                view.accent.BackgroundColor3 = row.ready and COLORS.success or COLORS.primary
            end
        end
    end

    if State.emptyLabel then
        State.emptyLabel.Visible = #rows == 0
    end

    if State.summaryLabel then
        local activeText
        if slotCapacity ~= nil then
            activeText = string.format("%d/%d Active", activeCount, slotCapacity)
        else
            activeText = string.format("%d Active Loan%s", #rows, #rows == 1 and "" or "s")
        end

        State.summaryLabel.Text = string.format("%s  •  %d Ready", activeText, readyCount)
    end

    updateAutomationButtons()
    updateConfigurationVisuals()
    updateDashboardUI()

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
            setLoanButton(
                string.format("Loan Top (%s)", getDurationLabel(State.selectedDuration)),
                true
            )
        else
            setLoanButton(
                string.format("Loan Top (%s)", getDurationLabel(State.selectedDuration)),
                false
            )
        end
    end
end

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

local function tryRediscoverNetworker()
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

local function fireBusEvent(eventName, payload)
    local eventBus = State.eventBus
    if eventBus == nil or type(eventBus.Fire) ~= "function" then
        return false
    end

    return pcall(eventBus.Fire, eventBus, eventName, payload)
end

local function fetchPrestigeInfo()
    if not tryRediscoverNetworker() then
        return nil, "Networker belum ditemukan"
    end

    local response, errorMessage = callNetwork("GetPrestigeInfo")
    if response then
        State.prestigeInfo = response
        updateAutomationButtons()
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
    if not State.running or State.collecting or State.loaning or State.prestiging then
        return
    end

    if not tryRediscoverNetworker() then
        return
    end

    local now = os.clock()

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
    State.visible = visible

    if not State.mainFrame then
        return
    end

    if visible then
        State.mainFrame.Visible = true
        State.mainFrame.Size = UDim2.fromOffset(760, 0)

        TweenService:Create(
            State.mainFrame,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(760, 720)}
        ):Play()

        refreshUI(false)
    else
        State.mainFrame.Visible = false
    end
end

local function makeDraggable(frame, handle)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

    addConnection(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            dragStart = input.Position
            startPosition = frame.Position

            addConnection(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end))
        end
    end))

    addConnection(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragInput = input
        end
    end))

    addConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging or input ~= dragInput then
            return
        end

        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end))
end

local function buildGui()
    local parent = CoreGui
    if type(gethui) == "function" then
        local success, hiddenUi = pcall(gethui)
        if success and hiddenUi then
            parent = hiddenUi
        end
    end

    local screenGui = create("ScreenGui", {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parent,
    })
    State.screenGui = screenGui

    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, screenGui)
    end

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(760, 720),
        BackgroundColor3 = COLORS.background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = screenGui,
    })
    State.mainFrame = main
    addCorner(main, 13)
    addStroke(main, COLORS.border, 1, 0.15)

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 66),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })

    local title = makeText(
        header,
        "Loan Out Manager",
        UDim2.new(1, -100, 0, 26),
        UDim2.fromOffset(20, 10),
        Enum.TextXAlignment.Left
    )
    title.Font = Enum.Font.GothamBold
    title.TextSize = 19

    local subtitle = makeText(
        header,
        "Loan automation • Auto Prestige • Press G",
        UDim2.new(1, -100, 0, 20),
        UDim2.fromOffset(20, 36),
        Enum.TextXAlignment.Left
    )
    subtitle.TextColor3 = COLORS.muted
    subtitle.TextSize = 12

    local closeButton = create("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = COLORS.panelAlt,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = COLORS.text,
        TextSize = 22,
        Parent = header,
    })
    addCorner(closeButton, 8)
    addConnection(closeButton.MouseButton1Click:Connect(function()
        setVisible(false)
    end))

    local summary = makeText(
        main,
        "0 Active Loans  •  0 Ready",
        UDim2.new(1, -370, 0, 32),
        UDim2.fromOffset(20, 77),
        Enum.TextXAlignment.Left
    )
    summary.Font = Enum.Font.GothamBold
    summary.TextSize = 14
    State.summaryLabel = summary

    local collectButton = create("TextButton", {
        Name = "CollectAll",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 76),
        Size = UDim2.fromOffset(150, 34),
        BackgroundColor3 = COLORS.primary,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Parent = main,
    })
    addCorner(collectButton, 8)
    State.collectButton = collectButton

    local collectLabel = makeText(
        collectButton,
        "Collect All",
        UDim2.fromScale(1, 1),
        UDim2.fromScale(0, 0),
        Enum.TextXAlignment.Center
    )
    collectLabel.Font = Enum.Font.GothamBold
    collectLabel.TextSize = 13
    State.collectButtonLabel = collectLabel

    addConnection(collectButton.MouseButton1Click:Connect(function()
        if collectButton.Active then
            collectAllReadyLoans(false)
        end
    end))

    local loanButton = create("TextButton", {
        Name = "LoanTopSelectedDuration",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -180, 0, 76),
        Size = UDim2.fromOffset(150, 34),
        BackgroundColor3 = COLORS.success,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Parent = main,
    })
    addCorner(loanButton, 8)
    State.loanButton = loanButton

    local loanLabel = makeText(
        loanButton,
        "Loan Top",
        UDim2.fromScale(1, 1),
        UDim2.fromScale(0, 0),
        Enum.TextXAlignment.Center
    )
    loanLabel.Font = Enum.Font.GothamBold
    loanLabel.TextSize = 12
    loanLabel.TextColor3 = COLORS.background
    State.loanButtonLabel = loanLabel

    addConnection(loanButton.MouseButton1Click:Connect(function()
        if loanButton.Active then
            loanOutTopRarity(false)
        end
    end))

    local automationPanel = create("Frame", {
        Name = "Automation",
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.fromOffset(20, 120),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    addCorner(automationPanel, 8)

    local automationTitle = makeText(
        automationPanel,
        "AUTOMATION",
        UDim2.fromOffset(110, 36),
        UDim2.fromOffset(12, 0),
        Enum.TextXAlignment.Left
    )
    automationTitle.TextColor3 = COLORS.muted
    automationTitle.TextSize = 10

    local function createToggleButton(name, titleText, position)
        local button = create("TextButton", {
            Name = name,
            Position = position,
            Size = UDim2.fromOffset(184, 28),
            BackgroundColor3 = COLORS.panelAlt,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = automationPanel,
        })
        addCorner(button, 7)
        addStroke(button, COLORS.border, 1, 0.45)

        local indicator = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(9, 9),
            BackgroundColor3 = Color3.fromRGB(90, 95, 114),
            BorderSizePixel = 0,
            Parent = button,
        })
        addCorner(indicator, 9)

        local label = makeText(
            button,
            titleText .. ": OFF",
            UDim2.new(1, -32, 1, 0),
            UDim2.fromOffset(27, 0),
            Enum.TextXAlignment.Left
        )
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextColor3 = COLORS.muted
        return button, label, indicator
    end

    local autoLoanButton, autoLoanLabel, autoLoanIndicator = createToggleButton(
        "AutoLoan",
        "Auto Loan",
        UDim2.fromOffset(124, 4)
    )
    State.autoLoanButton = autoLoanButton
    State.autoLoanLabel = autoLoanLabel
    State.autoLoanIndicator = autoLoanIndicator

    local autoCollectButton, autoCollectLabel, autoCollectIndicator = createToggleButton(
        "AutoCollect",
        "Auto Collect",
        UDim2.fromOffset(314, 4)
    )
    State.autoCollectButton = autoCollectButton
    State.autoCollectLabel = autoCollectLabel
    State.autoCollectIndicator = autoCollectIndicator

    local autoPrestigeButton, autoPrestigeLabel, autoPrestigeIndicator = createToggleButton(
        "AutoPrestige",
        "Auto Prestige",
        UDim2.fromOffset(504, 4)
    )
    State.autoPrestigeButton = autoPrestigeButton
    State.autoPrestigeLabel = autoPrestigeLabel
    State.autoPrestigeIndicator = autoPrestigeIndicator

    addConnection(autoLoanButton.MouseButton1Click:Connect(function()
        setAutoLoanEnabled(not State.autoLoan)
    end))
    addConnection(autoCollectButton.MouseButton1Click:Connect(function()
        setAutoCollectEnabled(not State.autoCollect)
    end))
    addConnection(autoPrestigeButton.MouseButton1Click:Connect(function()
        setAutoPrestigeEnabled(not State.autoPrestige)
    end))

    local dashboardPanel = create("Frame", {
        Name = "Dashboard",
        Size = UDim2.new(1, -40, 0, 100),
        Position = UDim2.fromOffset(20, 164),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    addCorner(dashboardPanel, 9)
    addStroke(dashboardPanel, COLORS.border, 1, 0.55)

    local dashboardTitle = makeText(
        dashboardPanel,
        "AUTO LOAN DASHBOARD",
        UDim2.new(1, -20, 0, 22),
        UDim2.fromOffset(12, 4),
        Enum.TextXAlignment.Left
    )
    dashboardTitle.TextColor3 = COLORS.muted
    dashboardTitle.TextSize = 10

    local function createMetricCard(xScale, labelText)
        local card = create("Frame", {
            Position = UDim2.new(xScale, xScale == 0 and 12 or 5, 0, 28),
            Size = UDim2.new(0.25, -13, 0, 48),
            BackgroundColor3 = COLORS.panelAlt,
            BorderSizePixel = 0,
            Parent = dashboardPanel,
        })
        addCorner(card, 7)

        local value = makeText(
            card,
            "0",
            UDim2.new(1, -12, 0, 25),
            UDim2.fromOffset(8, 3),
            Enum.TextXAlignment.Left
        )
        value.Font = Enum.Font.GothamBold
        value.TextSize = 17
        value.TextColor3 = COLORS.success

        local label = makeText(
            card,
            labelText,
            UDim2.new(1, -12, 0, 17),
            UDim2.fromOffset(8, 27),
            Enum.TextXAlignment.Left
        )
        label.TextSize = 9
        label.TextColor3 = COLORS.muted
        return value
    end

    State.dashboardSent = createMetricCard(0, "AUTO SENT")
    State.dashboardActive = createMetricCard(0.25, "IN ROTATION")
    State.dashboardCollected = createMetricCard(0.50, "AUTO COLLECTED")
    State.dashboardIncome = createMetricCard(0.75, "AUTO INCOME")

    local dashboardMeta = makeText(
        dashboardPanel,
        "No automation activity yet",
        UDim2.new(1, -24, 0, 18),
        UDim2.fromOffset(12, 79),
        Enum.TextXAlignment.Left
    )
    dashboardMeta.TextColor3 = COLORS.muted
    dashboardMeta.TextSize = 9
    State.dashboardMeta = dashboardMeta

    local configPanel = create("Frame", {
        Name = "AutoLoanConfiguration",
        Size = UDim2.new(1, -40, 0, 138),
        Position = UDim2.fromOffset(20, 272),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    addCorner(configPanel, 9)
    addStroke(configPanel, COLORS.border, 1, 0.55)

    local durationTitle = makeText(
        configPanel,
        "LOAN DURATION",
        UDim2.fromOffset(110, 24),
        UDim2.fromOffset(12, 5),
        Enum.TextXAlignment.Left
    )
    durationTitle.TextColor3 = COLORS.muted
    durationTitle.TextSize = 10

    local durationContainer = create("ScrollingFrame", {
        Name = "DurationOptions",
        Position = UDim2.fromOffset(118, 5),
        Size = UDim2.new(1, -130, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.X,
        Parent = configPanel,
    })
    State.durationContainer = durationContainer
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = durationContainer,
    })

    for index, minutes in ipairs(State.durationOptions) do
        local button = create("TextButton", {
            Name = "Duration_" .. tostring(minutes),
            Size = UDim2.fromOffset(92, 26),
            BackgroundColor3 = COLORS.panelAlt,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = index,
            Parent = durationContainer,
        })
        addCorner(button, 7)
        addStroke(button, COLORS.border, 1, 0.45)
        local label = makeText(button, getDurationLabel(minutes), UDim2.fromScale(1, 1), UDim2.new(), Enum.TextXAlignment.Center)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        State.durationButtons[minutes] = {button = button, label = label}

        addConnection(button.MouseButton1Click:Connect(function()
            State.selectedDuration = minutes
            PersistentConfig.duration = minutes
            State.nextAutoLoanAt = 0
            updateConfigurationVisuals()
            refreshUI(false)
            setStatus("Durasi Auto Loan: " .. getDurationLabel(minutes), COLORS.success)
        end))
    end

    local rarityTitle = makeText(
        configPanel,
        "RARITY WHITELIST",
        UDim2.fromOffset(130, 20),
        UDim2.fromOffset(12, 39),
        Enum.TextXAlignment.Left
    )
    rarityTitle.TextColor3 = COLORS.muted
    rarityTitle.TextSize = 10

    local rarityCount = makeText(
        configPanel,
        "0/0 enabled",
        UDim2.fromOffset(120, 20),
        UDim2.new(1, -132, 0, 39),
        Enum.TextXAlignment.Right
    )
    rarityCount.TextColor3 = COLORS.muted
    rarityCount.TextSize = 9
    State.rarityCountLabel = rarityCount

    local rarityContainer = create("Frame", {
        Name = "RarityOptions",
        Position = UDim2.fromOffset(12, 61),
        Size = UDim2.new(1, -24, 0, 66),
        BackgroundTransparency = 1,
        Parent = configPanel,
    })
    State.rarityContainer = rarityContainer

    create("UIGridLayout", {
        CellSize = UDim2.new(1 / 6, -7, 0, 28),
        CellPadding = UDim2.fromOffset(7, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirectionMaxCells = 6,
        Parent = rarityContainer,
    })

    for index, rarity in ipairs(State.rarityOptions) do
        local button = create("TextButton", {
            Name = "Rarity_" .. tostring(rarity),
            BackgroundColor3 = COLORS.panelAlt,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = index,
            Parent = rarityContainer,
        })
        addCorner(button, 7)
        addStroke(button, COLORS.border, 1, 0.45)

        local indicator = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = COLORS.success,
            BorderSizePixel = 0,
            Parent = button,
        })
        addCorner(indicator, 8)

        local label = makeText(
            button,
            tostring(rarity):gsub("WorldClass", "World Class"),
            UDim2.new(1, -24, 1, 0),
            UDim2.fromOffset(21, 0),
            Enum.TextXAlignment.Left
        )
        label.Font = Enum.Font.GothamBold
        label.TextSize = 9

        State.rarityButtons[rarity] = {
            button = button,
            label = label,
            indicator = indicator,
        }

        addConnection(button.MouseButton1Click:Connect(function()
            State.rarityWhitelist[rarity] = not isRarityWhitelisted(rarity)
            PersistentConfig.rarityWhitelist = State.rarityWhitelist
            State.cachedTopCard = nil
            State.nextAutoLoanAt = 0
            updateConfigurationVisuals()
            refreshUI(true)
        end))
    end

    local columnHeader = create("Frame", {
        Size = UDim2.new(1, -40, 0, 28),
        Position = UDim2.fromOffset(20, 418),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    addCorner(columnHeader, 7)

    local playerHeader = makeText(columnHeader, "PLAYER", UDim2.new(0.39, -8, 1, 0), UDim2.fromOffset(12, 0), Enum.TextXAlignment.Left)
    playerHeader.TextColor3 = COLORS.muted
    playerHeader.TextSize = 10
    local ratingHeader = makeText(columnHeader, "OVR", UDim2.new(0.11, 0, 1, 0), UDim2.new(0.39, 0, 0, 0), Enum.TextXAlignment.Center)
    ratingHeader.TextColor3 = COLORS.muted
    ratingHeader.TextSize = 10
    local statusHeader = makeText(columnHeader, "STATUS", UDim2.new(0.22, 0, 1, 0), UDim2.new(0.50, 0, 0, 0), Enum.TextXAlignment.Center)
    statusHeader.TextColor3 = COLORS.muted
    statusHeader.TextSize = 10
    local remainingHeader = makeText(columnHeader, "REMAINING", UDim2.new(0.28, -12, 1, 0), UDim2.new(0.72, 0, 0, 0), Enum.TextXAlignment.Right)
    remainingHeader.TextColor3 = COLORS.muted
    remainingHeader.TextSize = 10

    local list = create("ScrollingFrame", {
        Name = "LoanList",
        Position = UDim2.fromOffset(20, 454),
        Size = UDim2.new(1, -40, 1, -506),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLORS.primary,
        CanvasSize = UDim2.new(),
        Parent = main,
    })
    State.list = list

    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })
    addConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize))

    local emptyLabel = makeText(
        main,
        "No active loans",
        UDim2.new(1, -40, 0, 60),
        UDim2.new(0, 20, 0, 495),
        Enum.TextXAlignment.Center
    )
    emptyLabel.Font = Enum.Font.GothamBold
    emptyLabel.TextSize = 15
    emptyLabel.TextColor3 = COLORS.muted
    emptyLabel.Visible = true
    State.emptyLabel = emptyLabel

    local statusLabel = makeText(
        main,
        "Connecting...",
        UDim2.new(1, -40, 0, 30),
        UDim2.new(0, 20, 1, -40),
        Enum.TextXAlignment.Left
    )
    statusLabel.TextColor3 = COLORS.warning
    statusLabel.TextSize = 11
    State.statusLabel = statusLabel

    makeDraggable(main, header)
    setCollectButton("Collect All", false)
    setLoanButton("Loan Top", false)
    updateAutomationButtons()
    updateConfigurationVisuals()
    updateDashboardUI()
end

local function connectDataChanged()
    local eventBus = State.eventBus
    if eventBus == nil or type(eventBus.Connect) ~= "function" then
        return
    end

    local success, connection = pcall(function()
        return eventBus:Connect("DataChanged", function(change)
            local path = change and change.path
            if type(path) ~= "string" then
                return
            end

            local loanRelevant = string.find(path, "Loans", 1, true) == 1
                or string.find(path, "Squad.Owned", 1, true) == 1
                or string.find(path, "Squad.StartingEleven", 1, true) == 1
                or string.find(path, "Training", 1, true) == 1
                or string.find(path, "Promotion", 1, true) == 1

            local prestigeRelevant = path == "Coins"
                or path == "Progression.TotalWins"
                or path == "Division.Current"
                or string.find(path, "Squad", 1, true) == 1

            if loanRelevant then
                State.cachedTopCard = nil
                task.defer(refreshUI, true)
            end

            if prestigeRelevant then
                State.prestigeInfo = nil
                State.nextPrestigeCheckAt = 0
                updateAutomationButtons()
            end
        end)
    end)

    if success and connection then
        addConnection(connection)
    end
end

local API = {}

function API.Toggle()
    setVisible(not State.visible)
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

function API.SetAutoLoan(enabled)
    setAutoLoanEnabled(enabled)
end

function API.SetAutoCollect(enabled)
    setAutoCollectEnabled(enabled)
end

function API.SetAutoPrestige(enabled)
    setAutoPrestigeEnabled(enabled)
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
        prestiging = State.prestiging,
        duration = State.selectedDuration,
        whitelist = API.GetWhitelist(),
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
    State.prestiging = false
    disconnectAll()
    clearRows()

    if State.screenGui then
        State.screenGui:Destroy()
        State.screenGui = nil
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

addConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end

    if input.KeyCode == Enum.KeyCode.G then
        API.Toggle()
    end
end))

task.spawn(function()
    if not discoverFramework() then
        setCollectButton("Collect All", false)
        setLoanButton("Loan Top", false)
        return
    end

    connectDataChanged()
    refreshUI(true)

    while State.running do
        task.wait(POLL_INTERVAL)
        refreshUI(false)
        runAutomationTick()
    end
end)
