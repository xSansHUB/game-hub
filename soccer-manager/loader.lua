
--[[
    Standalone Loan Out GUI

    Fitur:
      - Tekan G untuk membuka/menutup GUI.
      - Menampilkan seluruh pemain yang sedang loan out.
      - Countdown diperbarui otomatis.
      - Tombol "Collect All" mengambil semua loan yang sudah selesai.
      - Tombol "Loan Top (5 Min)" memilih kartu dengan rarity tertinggi,
        lalu OVR tertinggi, dan mengirimkannya ke loan 5 menit.
      - Toggle Auto Loan terus mengisi slot kosong menggunakan 5 Min Loan.
      - Toggle Auto Collect otomatis mengambil seluruh loan yang selesai.
      - Auto Collect diprioritaskan sebelum Auto Loan.
      - Tidak mengubah atau membutuhkan ClubManager.

    API manual:
      LoanOutGUI.Toggle()
      LoanOutGUI.Show()
      LoanOutGUI.Hide()
      LoanOutGUI.Refresh()
      LoanOutGUI.CollectAll()
      LoanOutGUI.LoanTop5Min()
      LoanOutGUI.ToggleAutoLoan()
      LoanOutGUI.ToggleAutoCollect()
      LoanOutGUI.SetAutoLoan(true/false)
      LoanOutGUI.SetAutoCollect(true/false)
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
local AUTO_LOAN_MINUTES = 5
local TOP_CARD_SCAN_INTERVAL = 2
local AUTO_ACTION_INTERVAL = 0.75
local AUTO_RETRY_DELAY = 2

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

local State = {
    running = true,
    visible = true,
    collecting = false,
    loaning = false,
    autoLoan = false,
    autoCollect = false,

    dataService = nil,
    networker = nil,
    eventBus = nil,

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
    emptyLabel = nil,

    connections = {},
    rowViews = {},
    lastStructureSignature = nil,
    cachedTopCard = nil,
    lastTopCardScan = 0,
    nextAutoLoanAt = 0,
    nextAutoCollectAt = 0,
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
end

local function setAutoLoanEnabled(enabled, announce)
    State.autoLoan = enabled == true
    State.nextAutoLoanAt = 0
    State.cachedTopCard = nil
    updateAutomationButtons()

    if announce ~= false then
        setStatus(
            State.autoLoan
                and "Auto Loan aktif • mengisi slot dengan Top Rarity 5 Min."
                or "Auto Loan dinonaktifkan.",
            State.autoLoan and COLORS.success or COLORS.muted
        )
    end
end

local function setAutoCollectEnabled(enabled, announce)
    State.autoCollect = enabled == true
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
            if card then
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

local function refreshUI(forceRebuild)
    if not State.running or not State.list then
        return
    end

    local rows = buildRows()
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

    local networkReady = isNetworker(State.networker)
    local actionBusy = State.collecting or State.loaning

    if not State.collecting then
        if readyCount > 0 and networkReady and not State.loaning then
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
            setLoanButton("Loan Top (5 Min)", true)
        else
            setLoanButton("Loan Top (5 Min)", false)
        end
    end
end

local function callNetwork(action, payload)
    local networker = State.networker
    if not isNetworker(networker) then
        return nil, "Networker belum ditemukan"
    end

    local success, response = pcall(networker.Call, networker, action, payload)
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

local function collectAllReadyLoans(isAutomatic)
    if State.collecting or State.loaning then
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
            else
                failed += 1
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

local function loanOutTopRarityFiveMinutes(isAutomatic)
    if State.loaning or State.collecting then
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
            setStatus("Tidak ada kartu yang tersedia untuk di-loan.", COLORS.warning)
        end
        State.nextAutoLoanAt = os.clock() + AUTO_RETRY_DELAY
        refreshUI(false)
        return
    end

    State.loaning = true
    setLoanButton("Sending...", false)
    setCollectButton("Collect All", false)
    setStatus(
        string.format(
            "Mengirim %s • %s • %d OVR ke 5 Min Loan...",
            tostring(card.name),
            tostring(card.rarity),
            tonumber(card.rating) or 0
        ),
        COLORS.warning
    )

    task.spawn(function()
        local response, errorMessage = callNetwork("SendLoan", {
            instanceId = card.instanceId,
            mins = AUTO_LOAN_MINUTES,
        })

        State.loaning = false
        State.cachedTopCard = nil
        State.nextAutoLoanAt = os.clock()
            + (response and response.success and AUTO_ACTION_INTERVAL or AUTO_RETRY_DELAY)
        task.wait(0.35)
        refreshUI(true)

        if response and response.success then
            setStatus(
                string.format(
                    "%s (%s, %d OVR) berhasil di-loan selama 5 menit.",
                    tostring(card.name),
                    tostring(card.rarity),
                    tonumber(card.rating) or 0
                ),
                COLORS.success
            )
        else
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
    if not State.running or State.collecting or State.loaning then
        return
    end

    if not tryRediscoverNetworker() then
        return
    end

    local now = os.clock()

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
            loanOutTopRarityFiveMinutes(true)
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
        State.mainFrame.Size = UDim2.fromOffset(600, 0)

        TweenService:Create(
            State.mainFrame,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(600, 474)}
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
        Size = UDim2.fromOffset(600, 474),
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
        "Press G to open / close",
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
        UDim2.new(1, -365, 0, 32),
        UDim2.fromOffset(20, 78),
        Enum.TextXAlignment.Left
    )
    summary.Font = Enum.Font.GothamBold
    summary.TextSize = 14
    State.summaryLabel = summary

    local collectButton = create("TextButton", {
        Name = "CollectAll",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 77),
        Size = UDim2.fromOffset(145, 34),
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

    addConnection(collectButton.MouseEnter:Connect(function()
        if collectButton.Active and not State.collecting then
            collectButton.BackgroundColor3 = COLORS.primaryHover
        end
    end))

    addConnection(collectButton.MouseLeave:Connect(function()
        if collectButton.Active and not State.collecting then
            collectButton.BackgroundColor3 = COLORS.primary
        end
    end))

    addConnection(collectButton.MouseButton1Click:Connect(function()
        if collectButton.Active then
            collectAllReadyLoans(false)
        end
    end))

    local loanButton = create("TextButton", {
        Name = "LoanTopFiveMinutes",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -175, 0, 77),
        Size = UDim2.fromOffset(145, 34),
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
        "Loan Top (5 Min)",
        UDim2.fromScale(1, 1),
        UDim2.fromScale(0, 0),
        Enum.TextXAlignment.Center
    )
    loanLabel.Font = Enum.Font.GothamBold
    loanLabel.TextSize = 12
    loanLabel.TextColor3 = COLORS.background
    State.loanButtonLabel = loanLabel

    addConnection(loanButton.MouseEnter:Connect(function()
        if loanButton.Active and not State.loaning and not State.collecting then
            loanButton.BackgroundColor3 = Color3.fromRGB(102, 235, 155)
        end
    end))

    addConnection(loanButton.MouseLeave:Connect(function()
        if loanButton.Active and not State.loaning and not State.collecting then
            loanButton.BackgroundColor3 = COLORS.success
        end
    end))

    addConnection(loanButton.MouseButton1Click:Connect(function()
        if loanButton.Active then
            loanOutTopRarityFiveMinutes(false)
        end
    end))

    local automationPanel = create("Frame", {
        Name = "Automation",
        Size = UDim2.new(1, -40, 0, 34),
        Position = UDim2.fromOffset(20, 121),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    addCorner(automationPanel, 8)

    local automationTitle = makeText(
        automationPanel,
        "AUTOMATION",
        UDim2.fromOffset(110, 34),
        UDim2.fromOffset(12, 0),
        Enum.TextXAlignment.Left
    )
    automationTitle.TextColor3 = COLORS.muted
    automationTitle.TextSize = 10

    local function createToggleButton(name, title, position)
        local button = create("TextButton", {
            Name = name,
            Position = position,
            Size = UDim2.fromOffset(195, 26),
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
            title .. ": OFF",
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
        UDim2.new(0, 126, 0.5, -13)
    )
    State.autoLoanButton = autoLoanButton
    State.autoLoanLabel = autoLoanLabel
    State.autoLoanIndicator = autoLoanIndicator

    local autoCollectButton, autoCollectLabel, autoCollectIndicator = createToggleButton(
        "AutoCollect",
        "Auto Collect",
        UDim2.new(1, -205, 0.5, -13)
    )
    State.autoCollectButton = autoCollectButton
    State.autoCollectLabel = autoCollectLabel
    State.autoCollectIndicator = autoCollectIndicator

    addConnection(autoLoanButton.MouseButton1Click:Connect(function()
        setAutoLoanEnabled(not State.autoLoan)
    end))

    addConnection(autoCollectButton.MouseButton1Click:Connect(function()
        setAutoCollectEnabled(not State.autoCollect)
    end))

    local columnHeader = create("Frame", {
        Size = UDim2.new(1, -40, 0, 28),
        Position = UDim2.fromOffset(20, 165),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        Parent = main,
    })
    addCorner(columnHeader, 7)

    local playerHeader = makeText(
        columnHeader,
        "PLAYER",
        UDim2.new(0.39, -8, 1, 0),
        UDim2.fromOffset(12, 0),
        Enum.TextXAlignment.Left
    )
    playerHeader.TextColor3 = COLORS.muted
    playerHeader.TextSize = 10

    local ratingHeader = makeText(
        columnHeader,
        "OVR",
        UDim2.new(0.11, 0, 1, 0),
        UDim2.new(0.39, 0, 0, 0),
        Enum.TextXAlignment.Center
    )
    ratingHeader.TextColor3 = COLORS.muted
    ratingHeader.TextSize = 10

    local statusHeader = makeText(
        columnHeader,
        "STATUS",
        UDim2.new(0.22, 0, 1, 0),
        UDim2.new(0.50, 0, 0, 0),
        Enum.TextXAlignment.Center
    )
    statusHeader.TextColor3 = COLORS.muted
    statusHeader.TextSize = 10

    local remainingHeader = makeText(
        columnHeader,
        "REMAINING",
        UDim2.new(0.28, -12, 1, 0),
        UDim2.new(0.72, 0, 0, 0),
        Enum.TextXAlignment.Right
    )
    remainingHeader.TextColor3 = COLORS.muted
    remainingHeader.TextSize = 10

    local list = create("ScrollingFrame", {
        Name = "LoanList",
        Position = UDim2.fromOffset(20, 201),
        Size = UDim2.new(1, -40, 1, -254),
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
        UDim2.new(1, -40, 0, 80),
        UDim2.new(0, 20, 0.5, -10),
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
        UDim2.new(0, 20, 1, -42),
        Enum.TextXAlignment.Left
    )
    statusLabel.TextColor3 = COLORS.warning
    statusLabel.TextSize = 11
    State.statusLabel = statusLabel

    makeDraggable(main, header)
    setCollectButton("Collect All", false)
    setLoanButton("Loan Top (5 Min)", false)
    updateAutomationButtons()
end

local function connectDataChanged()
    local eventBus = State.eventBus
    if eventBus == nil or type(eventBus.Connect) ~= "function" then
        return
    end

    local success, connection = pcall(function()
        return eventBus:Connect("DataChanged", function(change)
            local path = change and change.path
            if type(path) == "string"
                and (
                    string.find(path, "Loans", 1, true) == 1
                    or string.find(path, "Squad.Owned", 1, true) == 1
                    or string.find(path, "Squad.StartingEleven", 1, true) == 1
                    or string.find(path, "Training", 1, true) == 1
                    or string.find(path, "Promotion", 1, true) == 1
                )
            then
                State.cachedTopCard = nil
                task.defer(refreshUI, true)
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

function API.LoanTop5Min()
    loanOutTopRarityFiveMinutes(false)
end

function API.ToggleAutoLoan()
    setAutoLoanEnabled(not State.autoLoan)
end

function API.ToggleAutoCollect()
    setAutoCollectEnabled(not State.autoCollect)
end

function API.SetAutoLoan(enabled)
    setAutoLoanEnabled(enabled)
end

function API.SetAutoCollect(enabled)
    setAutoCollectEnabled(enabled)
end

function API.GetAutomationState()
    return {
        autoLoan = State.autoLoan,
        autoCollect = State.autoCollect,
    }
end

function API.Stop()
    if not State.running then
        return
    end

    State.running = false
    State.autoLoan = false
    State.autoCollect = false
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

buildGui()
loadGameModules()

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
        setLoanButton("Loan Top (5 Min)", false)
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
