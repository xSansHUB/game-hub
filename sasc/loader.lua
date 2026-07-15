--[[
    Spin A Soccer Card Hub
    Made for a simple, clean, and user-friendly experience.

    Main features:
      - Home overview
      - Trophy crafting
      - Summer activities, quests, and shop
      - Spin Wheel and Wish automation
      - Daily rewards
      - Redeem codes from a trusted list
      - Index rewards
      - Gem, Summer, and Tournament shops
      - Anti AFK
      - Central session logs
      - Save and load configuration

    Configurable window keybind
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Environment = if type(getgenv) == "function" then getgenv() else _G

-- Hentikan instance sebelumnya agar loop tidak berjalan ganda.
do
    local previous = Environment.SpinASoccerCardHub

    if type(previous) == "table" and type(previous.Stop) == "function" then
        pcall(previous.Stop)
    end
end

local function requirePath(root, ...)
    local current = root

    for _, name in ipairs({...}) do
        current = current:WaitForChild(name)
    end

    return require(current)
end

local charm = requirePath(ReplicatedStorage, "Packages", "charm")
local PlayerStore = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "State",
    "PlayerStore"
)
local TrophyConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "TrophyConfig"
)
local CardConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "CardConfig"
)
local Networker = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Networker"
)
local GemShopState = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "State",
    "GemShopState"
)
local GemShopConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "GemShopConfig"
)
local ProductConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "ProductConfig"
)
local SummerQuestConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "SummerQuestConfig"
)
local SummerShopConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "SummerShopConfig"
)
local TournamentConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "TournamentConfig"
)
local GachaConfig = requirePath(
    ReplicatedStorage,
    "Source",
    "Shared",
    "Configs",
    "GachaConfig"
)
local AnimationController = requirePath(
    ReplicatedStorage,
    "Source",
    "Client",
    "UI",
    "Gacha",
    "AnimationController"
)
local PurchaseClient = requirePath(
    ReplicatedStorage,
    "Source",
    "Client",
    "Controllers",
    "PurchaseClient"
)

local CraftTrophy = Networker.get_remote("CraftTrophy")
local SeashellCollect = Networker.get_remote("SeashellCollect")
local SpinWheelRemote = Networker.get_remote("SpinWheel")
local SpinWheelData = Networker.get_remotefunction("SpinWheelData")
local BuyGemShopItem = Networker.get_remote("BuyGemShopItem")
local SummerQuestClaim = Networker.get_remote("SummerQuestClaim")
local SummerShopBuy = Networker.get_remote("SummerShopBuy")
local TournamentServer = Networker.get_remote("TournamentServer")
local PerformWish = Networker.get_remotefunction("PerformWish")
local ClaimAllIndexGems = Networker.get_remote("ClaimAllIndexGems")
local DailyReward = Networker.get_remote("DailyReward")
local RedeemCode = Networker.get_remote("RedeemCode")

-- ============================================================================
-- REDEEM CODES
-- Tambahkan kode resmi baru di bawah ini menggunakan format "WORD-WORD".
-- Jangan gunakan generator acak atau brute force.
-- ============================================================================
local REDEEM_CODES = {
    "OWL-HAPPY",

    -- Tambahkan kode baru di bawah baris ini:
    -- "NEW-CODE",
}

local REDEEM_CODE_GROUP_ID = 520125566

local TROPHY_ORDER = {
    "Golden Boot",
    "Champions League",
    "Ballon d'Or",
    "Eternal Crown",
    "Immortal Chalice",
    "Infinite Diadem",
}


local GEM_SHOP_SPECIAL_LUCKY = "lucky"
local GEM_SHOP_SPECIAL_SCARLET = "scarlet"
local GEM_SHOP_FIXED_PREFIX = "fixed:"

local GemShopOptionKeys = {}
local GemShopOptionLabels = {}
local GemShopKeyByLabel = {}
local GemShopFixedConfigByKey = {}

local function getGamepassDisplayName(gamepassId, fallback)
    local gamepasses = ProductConfig.Gamepasses
    local product = type(gamepasses) == "table" and gamepasses[gamepassId]

    if type(product) == "table"
        and type(product.Name) == "string"
        and product.Name ~= ""
    then
        return product.Name
    end

    return tostring(fallback or gamepassId or "Unknown Item")
end

local function registerGemShopOption(key, label)
    key = tostring(key)
    label = tostring(label)

    GemShopOptionKeys[#GemShopOptionKeys + 1] = key
    GemShopOptionLabels[#GemShopOptionLabels + 1] = label
    GemShopKeyByLabel[label] = key
end

local function buildGemShopOptions()
    table.clear(GemShopOptionKeys)
    table.clear(GemShopOptionLabels)
    table.clear(GemShopKeyByLabel)
    table.clear(GemShopFixedConfigByKey)

    local fixedItems = GemShopConfig.FixedGamepasses

    if type(fixedItems) == "table" then
        for _, config in ipairs(fixedItems) do
            if type(config) == "table" and config.Key ~= nil then
                local rawKey = tostring(config.Key)
                local optionKey = GEM_SHOP_FIXED_PREFIX .. rawKey
                local itemName = getGamepassDisplayName(config.Id, rawKey)
                local label = "Fixed • " .. itemName

                GemShopFixedConfigByKey[rawKey] = config
                registerGemShopOption(optionKey, label)
            end
        end
    end

    registerGemShopOption(GEM_SHOP_SPECIAL_LUCKY, "Lucky Item")
    registerGemShopOption(GEM_SHOP_SPECIAL_SCARLET, "Scarlet Pack")
end

buildGemShopOptions()

local SummerShopOptionIds = {}
local SummerShopOptionLabels = {}
local SummerShopIdByLabel = {}
local SummerShopConfigById = {}

local function registerSummerShopOption(item)
    if type(item) ~= "table" or item.id == nil then
        return
    end

    local id = tostring(item.id)
    local displayName = tostring(item.displayName or id)
    local price = math.max(0, math.floor(tonumber(item.seashellPrice) or 0))
    local label = displayName .. " • " .. tostring(price) .. " Seashells"

    if SummerShopIdByLabel[label] ~= nil then
        label = label .. " • " .. id
    end

    SummerShopOptionIds[#SummerShopOptionIds + 1] = id
    SummerShopOptionLabels[#SummerShopOptionLabels + 1] = label
    SummerShopIdByLabel[label] = id
    SummerShopConfigById[id] = item
end

local function buildSummerShopOptions()
    table.clear(SummerShopOptionIds)
    table.clear(SummerShopOptionLabels)
    table.clear(SummerShopIdByLabel)
    table.clear(SummerShopConfigById)

    local items = SummerShopConfig.Items

    if type(items) ~= "table" then
        return
    end

    for _, item in ipairs(items) do
        registerSummerShopOption(item)
    end
end

buildSummerShopOptions()

-- Tournament Shop whitelist berasal dari TournamentConfig.ShopRewards.
-- ID config bersifat stabil walaupun tiga reward aktif, harga, stock, pack,
-- trophy, atau potion berubah mengikuti tournament dan Rebirth.
local TournamentShopOptionKeys = {}
local TournamentShopOptionLabels = {}
local TournamentShopKeyByLabel = {}
local TournamentShopConfigById = {}
local TournamentShopEntryByKey = {}
local TournamentShopCurrentEntries = {}

local function tournamentRangeText(minimum, maximum)
    local minValue = math.max(0, math.floor(tonumber(minimum) or 0))
    local maxValue = math.max(minValue, math.floor(tonumber(maximum) or minValue))

    if minValue == maxValue then
        return tostring(minValue)
    end

    return tostring(minValue) .. "-" .. tostring(maxValue)
end

local function tournamentPerTierValues(config)
    local values = {}
    local seen = {}
    local perTier = type(config) == "table" and config.perTier

    if type(perTier) == "table" then
        for _, value in pairs(perTier) do
            local textValue = tostring(value)
            if not seen[textValue] then
                seen[textValue] = true
                values[#values + 1] = value
            end
        end
    end

    table.sort(values, function(a, b)
        if type(a) == type(b) and type(a) == "number" then
            return a < b
        end
        return tostring(a) < tostring(b)
    end)

    return values
end

local function tournamentConfigDisplayName(config)
    if type(config) ~= "table" then
        return "Unknown Reward"
    end

    local kind = tostring(config.kind or "unknown")
    local id = tostring(config.id or kind)

    if kind == "card" then
        local rawCardId = config.cardId
        local cardId = tostring(rawCardId or "")
        local cards = CardConfig.Cards
        local card = type(cards) == "table"
            and (cards[rawCardId] or cards[cardId])

        return tostring(
            type(card) == "table" and card.DisplayName
                or cardId ~= "" and cardId
                or id
        )
    elseif kind == "wctrophy" then
        return "World Cup Trophy"
    elseif kind == "misprintpotion" then
        return "Misprint Potion"
    elseif kind == "spin" then
        return tostring(config.amount or 1) .. "x Spin Wheel"
    elseif kind == "wish" then
        return tostring(config.amount or 1) .. "x Wish Tickets"
    end

    local tierValues = tournamentPerTierValues(config)

    if kind == "gems" then
        local minimum
        local maximum

        for _, value in ipairs(tierValues) do
            local amount = tonumber(value)
            if amount then
                minimum = minimum and math.min(minimum, amount) or amount
                maximum = maximum and math.max(maximum, amount) or amount
            end
        end

        if minimum then
            return tournamentRangeText(minimum, maximum) .. " Gems by Rebirth"
        end

        return "Gems"
    end

    if #tierValues == 1 then
        local value = tostring(tierValues[1])

        if kind == "pack" then
            return value .. " Pack"
        elseif kind == "trophy" then
            return value .. " Trophy"
        end

        return value
    elseif #tierValues > 1 then
        if kind == "pack" then
            return "Pack by Rebirth"
        elseif kind == "trophy" then
            return "Trophy by Rebirth"
        elseif kind == "potion" then
            return "Potion by Rebirth"
        end
    end

    if kind == "pack" then
        return "Pack"
    elseif kind == "trophy" then
        return "Trophy"
    elseif kind == "potion" then
        return id
    end

    return id
end

local function buildTournamentShopConfigOptions()
    table.clear(TournamentShopOptionKeys)
    table.clear(TournamentShopOptionLabels)
    table.clear(TournamentShopKeyByLabel)
    table.clear(TournamentShopConfigById)

    local rewards = TournamentConfig.ShopRewards
    if type(rewards) ~= "table" then
        return
    end

    for _, config in ipairs(rewards) do
        if type(config) == "table" and config.id ~= nil then
            local id = tostring(config.id)
            local displayName = tournamentConfigDisplayName(config)
            local priceText = tournamentRangeText(
                config.minPrice,
                config.maxPrice
            )
            local stockText = tournamentRangeText(
                config.minStock,
                config.maxStock
            )
            local label = string.format(
                "[%s] %s • %s Tokens • Stock %s",
                id,
                displayName,
                priceText,
                stockText
            )

            TournamentShopOptionKeys[#TournamentShopOptionKeys + 1] = id
            TournamentShopOptionLabels[#TournamentShopOptionLabels + 1] = label
            TournamentShopKeyByLabel[label] = id
            TournamentShopConfigById[id] = config
        end
    end
end

buildTournamentShopConfigOptions()

local State = {
    running = true,
    autoCraft = false,
    whitelist = {},
    interval = 1,
    remoteCooldown = 2.5,
    nextCraftAt = 0,
    attempts = 0,
    lastCraft = "-",
    lastStatus = "Pilih trophy pada whitelist.",
    window = nil,
    homeStatusParagraph = nil,
    statusParagraph = nil,

    windowKeybind = "G",
    windowKeybindControl = nil,
    keybindTag = nil,
    whitelistDropdown = nil,
    autoCraftToggle = nil,

    autoClaimSeashell = false,
    seashellInterval = 0.75,
    seashellCooldown = 1.25,
    seashellLastScan = 0,
    seashellFound = 0,
    seashellTriggered = 0,
    lastSeashell = "-",
    lastSeashellStatus = "Menunggu Auto Claim.",
    seashellStatusParagraph = nil,
    autoClaimSeashellToggle = nil,
    seashellTriggerTimes = {},

    autoClaimSpinWheel = false,
    autoSpinWheel = false,
    spinWheelPollInterval = 1,
    spinWheelDataCacheDuration = 0.65,
    spinWheelClaimCooldown = 2,
    spinWheelSpinDelay = 6,
    spinWheelPendingTimeout = 15,
    spinWheelNextClaimAt = 0,
    spinWheelNextSpinAt = 0,
    spinWheelLastDataAt = 0,
    spinWheelData = nil,
    spinWheelPending = false,
    spinWheelPendingSince = 0,
    spinWheelClaimRequests = 0,
    spinWheelSpinRequests = 0,
    spinWheelResults = 0,
    spinWheelFailures = 0,
    spinWheelLastReward = "-",
    spinWheelLastStatus = "Menunggu Spin Wheel.",
    spinWheelSessionStartedAt = os.time(),
    spinWheelLog = {},
    spinWheelLogLimit = 40,
    spinWheelStatusParagraph = nil,
    spinWheelLogParagraph = nil,
    autoClaimSpinWheelToggle = nil,
    autoSpinWheelToggle = nil,
    spinWheelConnection = nil,

    autoBuyGemShop = false,
    gemShopWhitelist = {},
    gemShopPollInterval = 1,
    gemShopBuyCooldown = 1.5,
    gemShopRetryCooldown = 4,
    gemShopNextBuyAt = 0,
    gemShopItemNextAttempt = {},
    gemShopRequests = 0,
    gemShopFailures = 0,
    gemShopLastItem = "-",
    gemShopLastStatus = "Pilih item pada whitelist.",
    gemShopStatusParagraph = nil,
    gemShopWhitelistDropdown = nil,
    autoBuyGemShopToggle = nil,

    autoClaimSummerQuests = false,
    summerQuestPollInterval = 1,
    summerQuestClaimCooldown = 2,
    summerQuestNextAttempt = {},
    summerQuestClaimRequests = 0,
    summerQuestFailures = 0,
    summerQuestLastClaim = "-",
    summerQuestLastStatus = "Menunggu Summer Quests.",
    summerQuestStatusParagraph = nil,
    autoClaimSummerQuestsToggle = nil,

    autoBuySummerShop = false,
    summerShopWhitelist = {},
    summerShopPollInterval = 1,
    summerShopBuyCooldown = 1.5,
    summerShopRetryCooldown = 3.5,
    summerShopNextBuyAt = 0,
    summerShopItemNextAttempt = {},
    summerShopBuyRequests = 0,
    summerShopFailures = 0,
    summerShopLastItem = "-",
    summerShopLastStatus = "Pilih item Summer Shop pada whitelist.",
    summerShopStatusParagraph = nil,
    summerShopWhitelistDropdown = nil,
    autoBuySummerShopToggle = nil,

    autoBuyTournamentShop = false,
    tournamentShopWhitelist = {},
    tournamentShopPollInterval = 1,
    tournamentShopBuyCooldown = 1.5,
    tournamentShopRetryCooldown = 4,
    tournamentShopPendingTimeout = 12,
    tournamentShopNextBuyAt = 0,
    tournamentShopItemNextAttempt = {},
    tournamentShopPending = false,
    tournamentShopPendingSince = 0,
    tournamentShopPendingIndex = nil,
    tournamentShopPendingKey = nil,
    tournamentShopPendingDisplay = nil,
    tournamentShopBuyRequests = 0,
    tournamentShopPurchases = 0,
    tournamentShopFailures = 0,
    tournamentShopLastItem = "-",
    tournamentShopLastStatus = "Pilih reward Tournament Shop pada whitelist.",
    tournamentShopOptionsFingerprint = "",
    tournamentShopStatusParagraph = nil,
    tournamentShopWhitelistDropdown = nil,
    autoBuyTournamentShopToggle = nil,
    tournamentShopConnection = nil,
    syncingTournamentShopDropdown = false,

    autoSpinWishTickets = false,
    skipWishAnimation = true,
    wishPollInterval = 0.6,
    wishRequestCooldown = 1.5,
    wishRateLimitCooldown = 3,
    wishNextAt = 0,
    wishPending = false,
    wishAnimationBusy = false,
    wishAnimationStartedAt = 0,
    wishRequests = 0,
    wishResults = 0,
    wishFailures = 0,
    wishLastReward = "-",
    wishLastStatus = "Menunggu Wish Tickets.",
    wishSessionStartedAt = os.time(),
    wishLog = {},
    wishLogLimit = 50,
    wishStatusParagraph = nil,
    wishLogParagraph = nil,
    autoSpinWishToggle = nil,
    skipWishAnimationToggle = nil,

    autoClaimIndex = false,
    indexPollInterval = 1,
    indexClaimCooldown = 2,
    indexNextClaimAt = 0,
    indexRequests = 0,
    indexFailures = 0,
    indexLastClaimable = 0,
    indexLastStatus = "Menunggu reward Index.",
    indexStatusParagraph = nil,
    autoClaimIndexToggle = nil,

    autoClaimDailyRewards = false,
    dailyRewardPollInterval = 1,
    dailyRewardStateRefreshInterval = 15,
    dailyRewardClaimCooldown = 3,
    dailyRewardPendingTimeout = 10,
    dailyRewardNextStateAt = 0,
    dailyRewardNextClaimAt = 0,
    dailyRewardPending = false,
    dailyRewardPendingAt = 0,
    dailyRewardState = nil,
    dailyRewardStateRequests = 0,
    dailyRewardClaimRequests = 0,
    dailyRewardClaims = 0,
    dailyRewardFailures = 0,
    dailyRewardLastClaimedDay = nil,
    dailyRewardLastStatus = "Checking reward status.",
    dailyRewardStatusParagraph = nil,
    autoClaimDailyRewardsToggle = nil,
    dailyRewardConnection = nil,

    autoRedeemCodes = false,
    codeRedeemInterval = 1.1,
    codeNextRedeemAt = 0,
    codeGroupCheckAt = 0,
    codeGroupMember = nil,
    codeRequests = 0,
    codeSkipped = 0,
    codeFailures = 0,
    codeLastCode = "-",
    codeLastStatus = "Ready.",
    codeAttempted = {},
    codeStatusParagraph = nil,
    autoRedeemCodesToggle = nil,

    antiAfk = false,
    antiAfkInterval = 45,
    antiAfkBusy = false,
    nextAntiAfkPulseAt = 0,
    antiAfkCount = 0,
    lastAntiAfkAt = 0,
    antiAfkMethod = "disabled",
    lastAntiAfkError = nil,
    antiAfkLastStatus = "Anti AFK belum aktif.",
    antiAfkStatusParagraph = nil,
    antiAfkToggle = nil,
    antiAfkIdledConnection = nil,

    rejoining = false,
    lastRejoinStatus = "Ready.",

    logs = {},
    logsLimit = 250,
    logsDisplayLimit = 80,
    logsFilter = "All",
    logsLastByCategory = {},
    logsSuppressed = 0,
    logsDedupeSeconds = 30,
    logsParagraph = nil,
    logsSummaryParagraph = nil,
    logsFilterDropdown = nil,

    autoSave = true,
    autoLoad = true,
    configSupported = type(readfile) == "function" and type(writefile) == "function",
    configLoading = false,
    configInitialized = false,
    configDirty = false,
    configSaveToken = 0,
    configLastSavedAt = 0,
    configLastObservedFingerprint = nil,
    configStartupLoaded = false,
    configStartupError = nil,
    configStatusParagraph = nil,
    autoSaveToggle = nil,
    autoLoadToggle = nil,
}

local LOG_FILTER_OPTIONS = {
    "All",
    "Hub",
    "Trophies",
    "Summer",
    "Spin Wheel",
    "Wish",
    "Daily",
    "Codes",
    "Index",
    "Gem Shop",
    "Tournament",
    "Anti AFK",
    "Config",
}

local LogRuntime = {}

local LOG_ROUTINE_PATTERNS = {
    "tidak ada seashell",
    "tidak ada reward index",
    "tidak ada reward yang dapat",
    "tidak ada summer quest",
    "belum ada summer quest",
    "tidak ada quest",
    "stock habis",
    "tidak tersedia pada stock",
    "tidak tersedia di stock",
    "tidak tersedia.",
    "belum tersedia",
    "belum muncul pada shop",
    "belum muncul di shop",
    "reward whitelist belum muncul",
    "reward list belum muncul",
    "tidak ada wish tickets",
    "tidak ada spin",
    "tidak ada item",
    "tidak ada reward",
    "menunggu reward",
    "menunggu wish",
    "menunggu spin",
    "menunggu auto",
    "masih cooldown",
    "data pemain belum siap",
    "playerstore belum",
    "choose items from",
    "choose rewards from",
    "choose trophies from",
    "daily reward is not ready",
    "checking daily rewards",
    "checking reward status",
    "daily rewards updated",
    "player data is loading",
    "all saved codes have been tried",
    "no pending codes",
    "required group has not been joined",
    "ready.",
}

function LogRuntime.normalizeMessage(message)
    return tostring(message or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
        :gsub("%s+", " ")
end

function LogRuntime.isRoutineMessage(message)
    local lowered = string.lower(
        LogRuntime.normalizeMessage(message)
    )

    for _, pattern in ipairs(LOG_ROUTINE_PATTERNS) do
        if string.find(lowered, pattern, 1, true) then
            return true
        end
    end

    return false
end

function LogRuntime.getLines()
    local lines = {}
    local shown = 0
    local selectedFilter = tostring(State.logsFilter or "All")

    for index = #State.logs, 1, -1 do
        local entry = State.logs[index]

        if selectedFilter == "All"
            or tostring(entry.category) == selectedFilter
        then
            lines[#lines + 1] = string.format(
                "[%s] [%s] %s",
                tostring(entry.time),
                tostring(entry.category),
                tostring(entry.message)
            )
            shown += 1

            if shown >= State.logsDisplayLimit then
                break
            end
        end
    end

    if #lines == 0 then
        lines[1] = "No important activity yet."
    end

    return lines
end

function LogRuntime.updateUI()
    if State.logsSummaryParagraph
        and type(State.logsSummaryParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.logsSummaryParagraph:SetDesc(table.concat({
                "Entries: " .. tostring(#State.logs),
                "Noise Filtered: " .. tostring(State.logsSuppressed),
                "Filter: " .. tostring(State.logsFilter),
                "Showing: latest " .. tostring(State.logsDisplayLimit),
                "Routine idle messages are hidden.",
            }, "\n"))
        end)
    end

    if State.logsParagraph
        and type(State.logsParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.logsParagraph:SetDesc(
                table.concat(LogRuntime.getLines(), "\n")
            )
        end)
    end
end

function LogRuntime.append(category, message, level, keepRoutine)
    if message == nil then
        return nil
    end

    category = tostring(category or "Hub")
    message = LogRuntime.normalizeMessage(message)
    level = tostring(level or "info")

    if message == "" then
        return nil
    end

    -- Polling status belongs in each feature's status panel, not in Logs.
    -- Manual notifications may pass keepRoutine=true so their result is kept.
    if keepRoutine ~= true
        and level ~= "error"
        and LogRuntime.isRoutineMessage(message)
    then
        State.logsSuppressed += 1
        LogRuntime.updateUI()
        return nil
    end

    local now = os.clock()
    local dedupeKey = category .. "\0" .. message
    local previousAt = State.logsLastByCategory[dedupeKey]
    local dedupeSeconds = level == "error"
        and 8
        or State.logsDedupeSeconds

    -- Dedupe is keyed by category + message, so interleaved polling from
    -- other features cannot cause the same line to be added repeatedly.
    if previousAt and now - previousAt < dedupeSeconds then
        State.logsSuppressed += 1
        LogRuntime.updateUI()
        return nil
    end

    State.logsLastByCategory[dedupeKey] = now

    local entry = {
        id = #State.logs + 1,
        timestamp = os.time(),
        time = os.date("%H:%M:%S"),
        category = category,
        level = level,
        message = message,
    }

    State.logs[#State.logs + 1] = entry

    while #State.logs > State.logsLimit do
        table.remove(State.logs, 1)
    end

    LogRuntime.updateUI()
    return entry
end

function LogRuntime.clear()
    table.clear(State.logs)
    table.clear(State.logsLastByCategory)
    State.logsSuppressed = 0
    LogRuntime.updateUI()
end

function LogRuntime.setFilter(value)
    local selected = tostring(value or "All")
    local valid = false

    for _, option in ipairs(LOG_FILTER_OPTIONS) do
        if option == selected then
            valid = true
            break
        end
    end

    State.logsFilter = valid and selected or "All"
    LogRuntime.updateUI()

    return State.logsFilter
end


local function getGameName()
    local fallback = tostring(game.Name or "Spin A Soccer Card Hub")

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

    return fallback ~= "" and fallback or "Spin A Soccer Card Hub"
end

local function getPlayerData()
    local success, store = pcall(function()
        return charm.peek(PlayerStore)
    end)

    if not success or type(store) ~= "table" then
        return nil
    end

    local players = store.players
    if type(players) ~= "table" then
        return nil
    end

    return players[tostring(LocalPlayer.UserId)]
end

local function countSelectedTrophies()
    local count = 0

    for _, trophyName in ipairs(TROPHY_ORDER) do
        if State.whitelist[trophyName] then
            count += 1
        end
    end

    return count
end

local function getSelectedTrophies()
    local selected = {}

    for _, trophyName in ipairs(TROPHY_ORDER) do
        if State.whitelist[trophyName] then
            selected[#selected + 1] = trophyName
        end
    end

    return selected
end

local function formatSelectedTrophies()
    local selected = getSelectedTrophies()

    if #selected == 0 then
        return "Tidak ada"
    end

    return table.concat(selected, ", ")
end

local function updateStatus(message)
    if message ~= nil then
        State.lastStatus = tostring(message)
        LogRuntime.append("Trophies", State.lastStatus)
    end

    local description = table.concat({
        "Auto Craft: " .. (State.autoCraft and "ON" or "OFF"),
        "Whitelist: " .. tostring(countSelectedTrophies()) .. "/" .. tostring(#TROPHY_ORDER),
        "Attempts: " .. tostring(State.attempts),
        "Last Craft: " .. tostring(State.lastCraft),
        "Status: " .. tostring(State.lastStatus),
    }, "\n")

    if State.statusParagraph and type(State.statusParagraph.SetDesc) == "function" then
        pcall(function()
            State.statusParagraph:SetDesc(description)
        end)
    end
end

local function notify(title, content, icon)
    LogRuntime.append(
        tostring(title or "Hub"),
        tostring(content or ""),
        icon == "triangle-alert" and "error" or "info",
        true
    )

    local windUI = State.windUI
    if windUI and type(windUI.Notify) == "function" then
        pcall(function()
            windUI:Notify({
                Title = title,
                Content = content,
                Icon = icon or "trophy",
                Duration = 4,
            })
        end)
    end
end

local function normalizeSelectedValue(value)
    if type(value) == "table" then
        return value.Title or value.Name or value.Value
    end

    return value
end

local function applyWhitelistSelection(selectedValues)
    local enabled = {}

    local function enableValue(value)
        local trophyName = tostring(normalizeSelectedValue(value) or "")
        if TrophyConfig.Trophies[trophyName] then
            enabled[trophyName] = true
        end
    end

    if type(selectedValues) == "table" then
        local foundArrayValue = false

        for key, value in pairs(selectedValues) do
            if type(key) == "number" then
                foundArrayValue = true
                enableValue(value)
            elseif value == true then
                enableValue(key)
            elseif type(value) == "table" then
                enableValue(value)
            end
        end

        if not foundArrayValue and selectedValues.Title then
            enableValue(selectedValues)
        end
    elseif selectedValues ~= nil then
        enableValue(selectedValues)
    end

    table.clear(State.whitelist)

    for _, trophyName in ipairs(TROPHY_ORDER) do
        State.whitelist[trophyName] = enabled[trophyName] == true
    end

    State.nextCraftAt = 0
    updateStatus("Whitelist diperbarui: " .. formatSelectedTrophies())
end

local function syncWhitelistDropdown()
    if not State.whitelistDropdown or type(State.whitelistDropdown.Select) ~= "function" then
        return
    end

    pcall(function()
        State.whitelistDropdown:Select(getSelectedTrophies())
    end)
end

local function setAllTrophies(enabled)
    for _, trophyName in ipairs(TROPHY_ORDER) do
        State.whitelist[trophyName] = enabled == true
    end

    State.nextCraftAt = 0
    syncWhitelistDropdown()
    updateStatus(enabled and "Semua trophy dipilih." or "Whitelist dikosongkan.")
end

local function getCraftShopState(playerData)
    local craftShop = playerData and playerData.craftShop

    if type(craftShop) ~= "table" then
        return {}, {}
    end

    return type(craftShop.stocks) == "table" and craftShop.stocks or {},
        type(craftShop.crafted) == "table" and craftShop.crafted or {}
end

local function buildUnlockedCardCounts(playerData)
    local byId = {}
    local byRarity = {}
    local inventory = playerData and playerData.inventory

    if type(inventory) ~= "table" then
        return byId, byRarity
    end

    for _, card in ipairs(inventory) do
        if type(card) == "table" and card.id and not card.locked then
            local rawCardId = card.id
            local cardId = tostring(rawCardId)
            byId[cardId] = (byId[cardId] or 0) + 1

            local config = CardConfig.Cards[rawCardId] or CardConfig.Cards[cardId]
            local rarity = config and config.Rarity
            if rarity then
                byRarity[rarity] = (byRarity[rarity] or 0) + 1
            end
        end
    end

    return byId, byRarity
end

local function hasEnoughUnlockedCards(trophyName, playerData)
    local trophy = TrophyConfig.Trophies[trophyName]
    if type(trophy) ~= "table" then
        return false, "Config trophy tidak ditemukan"
    end

    local requirements = trophy.Requirements
    if type(requirements) ~= "table" then
        return true
    end

    local byId, byRarity = buildUnlockedCardCounts(playerData)

    -- Proses kartu specific lebih dulu agar kartu yang sama tidak dihitung
    -- ulang oleh requirement "any" dengan rarity yang sama.
    for _, requirement in ipairs(requirements) do
        if requirement.type == "specific" then
            local cardId = tostring(requirement.cardId or "")
            local amount = tonumber(requirement.amount) or 0
            local owned = byId[cardId] or 0

            if owned < amount then
                return false, string.format(
                    "%s kurang (%d/%d)",
                    cardId,
                    owned,
                    amount
                )
            end

            byId[cardId] = owned - amount

            local rawRequirementId = requirement.cardId
            local card = CardConfig.Cards[rawRequirementId] or CardConfig.Cards[cardId]
            local rarity = card and card.Rarity
            if rarity then
                byRarity[rarity] = math.max(0, (byRarity[rarity] or 0) - amount)
            end
        end
    end

    for _, requirement in ipairs(requirements) do
        if requirement.type == "any" then
            local rarity = tostring(requirement.rarity or "")
            local amount = tonumber(requirement.amount) or 0
            local owned = byRarity[rarity] or 0

            if owned < amount then
                return false, string.format(
                    "Any %s kurang (%d/%d)",
                    rarity,
                    owned,
                    amount
                )
            end

            byRarity[rarity] = owned - amount
        end
    end

    return true
end

local function getTrophyAvailability(trophyName, playerData)
    local stocks, crafted = getCraftShopState(playerData)

    if crafted[trophyName] == true then
        return false, "sudah crafted"
    end

    if stocks[trophyName] ~= true then
        return false, "tidak tersedia pada stock"
    end

    return hasEnoughUnlockedCards(trophyName, playerData)
end

local function craftNextWhitelisted()
    if os.clock() < State.nextCraftAt then
        return false, "Cooldown remote"
    end

    if countSelectedTrophies() == 0 then
        updateStatus("Whitelist kosong. Pilih minimal satu trophy.")
        return false, "Whitelist kosong"
    end

    local playerData = getPlayerData()
    if not playerData then
        updateStatus("Data pemain belum siap.")
        return false, "Data pemain belum siap"
    end

    local blockedReasons = {}

    for _, trophyName in ipairs(TROPHY_ORDER) do
        if State.whitelist[trophyName] then
            local available, reason = getTrophyAvailability(trophyName, playerData)

            if available then
                State.nextCraftAt = os.clock() + State.remoteCooldown
                State.attempts += 1
                State.lastCraft = trophyName
                updateStatus("Mengirim CraftTrophy: " .. trophyName)

                local success, errorMessage = pcall(function()
                    CraftTrophy:FireServer(trophyName)
                end)

                if not success then
                    State.nextCraftAt = os.clock() + 1
                    updateStatus("Aksi gagal: " .. tostring(errorMessage))
                    return false, tostring(errorMessage)
                end

                return true, trophyName
            end

            blockedReasons[#blockedReasons + 1] = trophyName .. ": " .. tostring(reason)
        end
    end

    updateStatus(
        #blockedReasons > 0
            and table.concat(blockedReasons, " | ")
            or "Tidak ada trophy yang dapat dicraft."
    )

    return false, "Tidak ada trophy craftable"
end

local function setAutoCraft(enabled)
    State.autoCraft = enabled == true
    State.nextCraftAt = 0

    if State.autoCraft and countSelectedTrophies() == 0 then
        updateStatus("Auto Craft aktif, tetapi whitelist masih kosong.")
        notify(
            "Auto Craft Trophies",
            "Pilih minimal satu trophy pada dropdown whitelist.",
            "triangle-alert"
        )
    else
        updateStatus(State.autoCraft and "Auto Craft diaktifkan." or "Auto Craft dinonaktifkan.")
    end

    return State.autoCraft
end

local function getSeashellFolder()
    return Workspace:FindFirstChild("LocalSeashells")
end

local function getSeashellIndex(seashell)
    if not seashell then
        return nil
    end

    local rawIndex = tostring(seashell.Name):match("^Seashell_(.+)$")
    if not rawIndex or rawIndex == "" then
        return nil
    end

    return tonumber(rawIndex) or rawIndex
end

local function updateSeashellStatus(message)
    if message ~= nil then
        State.lastSeashellStatus = tostring(message)
        LogRuntime.append("Summer", "Seashells • " .. State.lastSeashellStatus)
    end

    local description = table.concat({
        "Auto Claim: " .. (State.autoClaimSeashell and "ON" or "OFF"),
        "Available: " .. tostring(State.seashellFound),
        "Collected: " .. tostring(State.seashellTriggered),
        "Last Index: " .. tostring(State.lastSeashell),
        "Status: " .. tostring(State.lastSeashellStatus),
    }, "\n")

    if State.seashellStatusParagraph
        and type(State.seashellStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.seashellStatusParagraph:SetDesc(description)
        end)
    end
end

local function claimAllSeashells(force)
    local folder = getSeashellFolder()

    if not folder then
        State.seashellFound = 0
        updateSeashellStatus("Seashell belum tersedia.")
        return false, 0, "Seashell belum tersedia"
    end

    local seashells = folder:GetChildren()
    State.seashellFound = #seashells
    State.seashellLastScan = os.clock()

    if #seashells == 0 then
        updateSeashellStatus("Tidak ada seashell yang tersedia.")
        return true, 0
    end

    local now = os.clock()
    local sent = 0
    local invalid = 0
    local lastError = nil

    -- Semua remote dikirim dalam siklus yang sama tanpa task.wait antar-seashell.
    for _, seashell in ipairs(seashells) do
        local index = getSeashellIndex(seashell)

        if index == nil then
            invalid += 1
        else
            local requestKey = tostring(index)
            local lastRequestAt = State.seashellTriggerTimes[requestKey] or 0
            local canRequest = force == true
                or (now - lastRequestAt) >= State.seashellCooldown

            if canRequest then
                local success, errorMessage = pcall(function()
                    SeashellCollect:FireServer(index)
                end)

                if success then
                    State.seashellTriggerTimes[requestKey] = now
                    State.seashellTriggered += 1
                    State.lastSeashell = index
                    sent += 1
                else
                    lastError = tostring(errorMessage)
                end
            end
        end
    end

    if sent > 0 then
        updateSeashellStatus(string.format(
            "Mengumpulkan %d dari %d seashell.",
            sent,
            #seashells
        ))
        return true, sent
    end

    if invalid == #seashells then
        updateSeashellStatus("Nama object tidak memakai format Seashell_<index>.")
        return false, 0, "Index seashell tidak dapat dibaca"
    end

    if lastError then
        updateSeashellStatus("Aksi gagal: " .. lastError)
        return false, 0, lastError
    end

    updateSeashellStatus("Semua index masih dalam cooldown.")
    return true, 0
end

local function setAutoClaimSeashell(enabled)
    State.autoClaimSeashell = enabled == true

    updateSeashellStatus(
        State.autoClaimSeashell
            and "Auto Claim Seashell diaktifkan."
            or "Auto Claim Seashell dinonaktifkan."
    )

    return State.autoClaimSeashell
end


local function formatCompactNumber(value)
    local number = tonumber(value) or 0
    local absolute = math.abs(number)

    local suffixes = {
        {1e12, "T"},
        {1e9, "B"},
        {1e6, "M"},
        {1e3, "K"},
    }

    for _, suffixData in ipairs(suffixes) do
        local threshold = suffixData[1]
        local suffix = suffixData[2]

        if absolute >= threshold then
            local scaled = number / threshold
            local formatted

            if math.abs(scaled) >= 100 then
                formatted = string.format("%.0f", scaled)
            elseif math.abs(scaled) >= 10 then
                formatted = string.format("%.1f", scaled)
            else
                formatted = string.format("%.2f", scaled)
            end

            formatted = formatted:gsub("%.?0+$", "")
            return formatted .. suffix
        end
    end

    return tostring(math.floor(number))
end

local function formatDuration(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local remainingSeconds = total % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, remainingSeconds)
    end

    return string.format("%d:%02d", minutes, remainingSeconds)
end

local function copySpinWheelData(data)
    if type(data) ~= "table" then
        return nil
    end

    return {
        spins = tonumber(data.spins) or 0,
        paidSpins = tonumber(data.paidSpins) or 0,
        totalSpins = (tonumber(data.spins) or 0) + (tonumber(data.paidSpins) or 0),
        canClaimFree = data.canClaimFree == true,
        timeRemaining = tonumber(data.timeRemaining) or 0,
        dailyDealAvailable = data.dailyDealAvailable == true,
    }
end

local function formatSpinReward(reward)
    if type(reward) ~= "table" then
        return "Unknown Reward"
    end

    local rewardType = tostring(reward.type or "unknown")
    local displayName = reward.displayName

    if rewardType == "cash_small" then
        return "$" .. formatCompactNumber(reward.value) .. " Cash"
    elseif rewardType == "cash_big" then
        return "$" .. formatCompactNumber(reward.value) .. " BIG Cash"
    elseif rewardType == "gems" then
        return formatCompactNumber(reward.value) .. " Gems"
    elseif rewardType == "mutation_potion" then
        return tostring(displayName or reward.mutation or "Mutation Potion")
    elseif rewardType == "pack1" or rewardType == "pack2" then
        return tostring(displayName or "Pack")
    elseif rewardType == "grand_prize" then
        return tostring(displayName or "Limited Card / Chrono Vozinha")
    end

    if displayName ~= nil then
        return tostring(displayName)
    end

    if reward.value ~= nil then
        return rewardType .. " (" .. formatCompactNumber(reward.value) .. ")"
    end

    return rewardType
end

local function getSpinLogLines()
    local lines = {}
    local totalEntries = #State.spinWheelLog
    local firstIndex = math.max(1, totalEntries - 11)

    for index = totalEntries, firstIndex, -1 do
        local entry = State.spinWheelLog[index]
        lines[#lines + 1] = string.format(
            "#%d [%s] %s | Slot %s",
            entry.id,
            entry.time,
            entry.display,
            tostring(entry.slot or "-")
        )
    end

    if #lines == 0 then
        return {"Belum ada hadiah pada session ini."}
    end

    return lines
end

local function updateSpinWheelLogUI()
    if not State.spinWheelLogParagraph
        or type(State.spinWheelLogParagraph.SetDesc) ~= "function"
    then
        return
    end

    local lines = getSpinLogLines()

    pcall(function()
        State.spinWheelLogParagraph:SetDesc(table.concat(lines, "\n"))
    end)
end

local function updateSpinWheelStatus(message)
    if message ~= nil then
        State.spinWheelLastStatus = tostring(message)
        LogRuntime.append("Spin Wheel", State.spinWheelLastStatus)
    end

    local data = State.spinWheelData or {}
    local description = table.concat({
        "Auto Claim: " .. (State.autoClaimSpinWheel and "ON" or "OFF"),
        "Auto Spin: " .. (State.autoSpinWheel and "ON" or "OFF"),
        "Free Spins: " .. tostring(data.spins or 0),
        "Lucky Spins: " .. tostring(data.paidSpins or 0),
        "Free Claim: " .. ((data.canClaimFree == true) and "READY" or "Not Ready"),
        "Next Free: " .. formatDuration(data.timeRemaining or 0),
        "Claims: " .. tostring(State.spinWheelClaimRequests),
        "Spins: " .. tostring(State.spinWheelSpinRequests),
        "Results: " .. tostring(State.spinWheelResults),
        "Last Reward: " .. tostring(State.spinWheelLastReward),
        "Status: " .. tostring(State.spinWheelLastStatus),
    }, "\n")

    if State.spinWheelStatusParagraph
        and type(State.spinWheelStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.spinWheelStatusParagraph:SetDesc(description)
        end)
    end
end

local function appendSpinWheelLog(reward)
    local entry = {
        id = State.spinWheelResults + 1,
        timestamp = os.time(),
        time = os.date("%H:%M:%S"),
        type = tostring(reward.type or "unknown"),
        display = formatSpinReward(reward),
        value = reward.value,
        slot = reward.slot,
        raw = reward,
    }

    State.spinWheelResults += 1
    entry.id = State.spinWheelResults
    State.spinWheelLastReward = entry.display

    State.spinWheelLog[#State.spinWheelLog + 1] = entry

    while #State.spinWheelLog > State.spinWheelLogLimit do
        table.remove(State.spinWheelLog, 1)
    end

    updateSpinWheelLogUI()
    updateSpinWheelStatus("Spin result diterima: " .. entry.display)

    return entry
end

local function clearSpinWheelLog()
    table.clear(State.spinWheelLog)
    State.spinWheelResults = 0
    State.spinWheelLastReward = "-"
    State.spinWheelSessionStartedAt = os.time()

    updateSpinWheelLogUI()
    updateSpinWheelStatus("Session Spin Wheel log di-reset.")
end

local function fetchSpinWheelData(force)
    local now = os.clock()

    if not force
        and State.spinWheelData
        and (now - State.spinWheelLastDataAt) < State.spinWheelDataCacheDuration
    then
        return true, State.spinWheelData
    end

    local success, result = pcall(function()
        return SpinWheelData:InvokeServer()
    end)

    if not success then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("Data Spin Wheel gagal dimuat: " .. tostring(result))
        return false, nil, tostring(result)
    end

    if type(result) ~= "table" then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("Data Spin Wheel tidak valid.")
        return false, nil, "Data Spin Wheel tidak valid"
    end

    State.spinWheelData = copySpinWheelData(result)
    State.spinWheelLastDataAt = now

    updateSpinWheelStatus()
    return true, State.spinWheelData
end

local function claimFreeSpin(force)
    local now = os.clock()

    if not force and now < State.spinWheelNextClaimAt then
        return false, "Claim masih cooldown"
    end

    local success, data, errorMessage = fetchSpinWheelData(force == true)

    if not success then
        return false, errorMessage
    end

    if data.canClaimFree ~= true then
        return false, "Free spin belum tersedia"
    end

    State.spinWheelNextClaimAt = now + State.spinWheelClaimCooldown

    local fired, fireError = pcall(function()
        SpinWheelRemote:FireServer("claim_free")
    end)

    if not fired then
        State.spinWheelFailures += 1
        State.spinWheelNextClaimAt = now + 1
        updateSpinWheelStatus("Claim free spin gagal: " .. tostring(fireError))
        return false, tostring(fireError)
    end

    State.spinWheelClaimRequests += 1
    State.spinWheelLastDataAt = 0
    updateSpinWheelStatus("Free Spin sedang diproses.")

    task.delay(0.5, function()
        if State.running then
            pcall(fetchSpinWheelData, true)
        end
    end)

    return true
end

local function spinWheelNow(force)
    local now = os.clock()

    if State.spinWheelPending then
        if (now - State.spinWheelPendingSince) < State.spinWheelPendingTimeout then
            return false, "Menunggu spin_result"
        end

        State.spinWheelPending = false
        updateSpinWheelStatus("Pending spin timeout; mencoba ulang.")
    end

    if not force and now < State.spinWheelNextSpinAt then
        return false, "Spin masih cooldown"
    end

    local success, data, errorMessage = fetchSpinWheelData(force == true)

    if not success then
        return false, errorMessage
    end

    if (data.totalSpins or 0) <= 0 then
        return false, "Tidak ada spin tersedia"
    end

    State.spinWheelPending = true
    State.spinWheelPendingSince = now
    State.spinWheelNextSpinAt = now + State.spinWheelSpinDelay

    local fired, fireError = pcall(function()
        SpinWheelRemote:FireServer("spin")
    end)

    if not fired then
        State.spinWheelPending = false
        State.spinWheelFailures += 1
        State.spinWheelNextSpinAt = now + 1
        updateSpinWheelStatus("Spin gagal: " .. tostring(fireError))
        return false, tostring(fireError)
    end

    State.spinWheelSpinRequests += 1
    State.spinWheelLastDataAt = 0
    updateSpinWheelStatus("Spin dimulai; menunggu hasil.")

    return true
end

local function setAutoClaimSpinWheel(enabled)
    State.autoClaimSpinWheel = enabled == true
    State.spinWheelNextClaimAt = 0

    updateSpinWheelStatus(
        State.autoClaimSpinWheel
            and "Auto Claim Spin Wheel diaktifkan."
            or "Auto Claim Spin Wheel dinonaktifkan."
    )

    return State.autoClaimSpinWheel
end

local function setAutoSpinWheel(enabled)
    State.autoSpinWheel = enabled == true
    State.spinWheelNextSpinAt = 0

    updateSpinWheelStatus(
        State.autoSpinWheel
            and "Auto Spin Wheel diaktifkan."
            or "Auto Spin Wheel dinonaktifkan."
    )

    return State.autoSpinWheel
end

local function onSpinWheelRemote(action, payload)
    if action ~= "spin_result" then
        return
    end

    State.spinWheelPending = false
    State.spinWheelNextSpinAt = os.clock() + State.spinWheelSpinDelay
    State.spinWheelLastDataAt = 0

    if type(payload) ~= "table" or payload.success ~= true then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("Spin result gagal atau tidak valid.")
        return
    end

    if type(payload.reward) ~= "table" then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("Spin result tidak memiliki reward.")
        return
    end

    appendSpinWheelLog(payload.reward)

    task.delay(0.5, function()
        if State.running then
            pcall(fetchSpinWheelData, true)
        end
    end)
end


local function getGemShopStateData()
    local success, state = pcall(function()
        return charm.peek(GemShopState)
    end)

    if success and type(state) == "table" then
        return state
    end

    success, state = pcall(function()
        return GemShopState()
    end)

    if success and type(state) == "table" then
        return state
    end

    return {}
end

local function getCurrentGems()
    local playerData = getPlayerData()
    return math.max(0, math.floor(tonumber(playerData and playerData.gems) or 0))
end

local function hasGamepass(gamepassId)
    if gamepassId == nil then
        return false
    end

    local success, owned = pcall(function()
        return PurchaseClient.hasGamepass(gamepassId)
    end)

    return success and owned == true
end

local function gemShopKeyFromSelection(value)
    local selected = normalizeSelectedValue(value)

    if selected == nil then
        return nil
    end

    local textValue = tostring(selected)

    if GemShopKeyByLabel[textValue] then
        return GemShopKeyByLabel[textValue]
    end

    for _, key in ipairs(GemShopOptionKeys) do
        if key == textValue then
            return key
        end
    end

    return nil
end

local function gemShopLabelFromKey(key)
    key = tostring(key)

    for index, optionKey in ipairs(GemShopOptionKeys) do
        if optionKey == key then
            return GemShopOptionLabels[index]
        end
    end

    return key
end

local function getSelectedGemShopLabels()
    local labels = {}

    for index, key in ipairs(GemShopOptionKeys) do
        if State.gemShopWhitelist[key] then
            labels[#labels + 1] = GemShopOptionLabels[index]
        end
    end

    return labels
end

local function countSelectedGemShopItems()
    local count = 0

    for _, key in ipairs(GemShopOptionKeys) do
        if State.gemShopWhitelist[key] then
            count += 1
        end
    end

    return count
end

local function applyGemShopWhitelistSelection(selectedValues)
    local selectedKeys = {}

    local function enable(value)
        local key = gemShopKeyFromSelection(value)
        if key then
            selectedKeys[key] = true
        end
    end

    if type(selectedValues) == "table" then
        local foundArrayValue = false

        for key, value in pairs(selectedValues) do
            if type(key) == "number" then
                foundArrayValue = true
                enable(value)
            elseif value == true then
                enable(key)
            elseif type(value) == "table" then
                enable(value)
            end
        end

        if not foundArrayValue and selectedValues.Title then
            enable(selectedValues)
        end
    elseif selectedValues ~= nil then
        enable(selectedValues)
    end

    table.clear(State.gemShopWhitelist)

    for _, key in ipairs(GemShopOptionKeys) do
        State.gemShopWhitelist[key] = selectedKeys[key] == true
    end

    State.gemShopNextBuyAt = 0
    State.gemShopLastStatus = "Whitelist Gem Shop diperbarui."
end

local function syncGemShopWhitelistDropdown()
    if not State.gemShopWhitelistDropdown
        or type(State.gemShopWhitelistDropdown.Select) ~= "function"
    then
        return
    end

    pcall(function()
        State.gemShopWhitelistDropdown:Select(getSelectedGemShopLabels())
    end)
end

local function setAllGemShopItems(enabled)
    for _, key in ipairs(GemShopOptionKeys) do
        State.gemShopWhitelist[key] = enabled == true
    end

    State.gemShopNextBuyAt = 0
    syncGemShopWhitelistDropdown()
    State.gemShopLastStatus = enabled
        and "Semua item Gem Shop dipilih."
        or "Whitelist Gem Shop dikosongkan."
end

local function getLuckyItemDisplay(shopState)
    local luckyItem = shopState and shopState.luckyItem

    if type(luckyItem) ~= "table" then
        return "Tidak tersedia", 0, nil
    end

    local gamepassId = luckyItem.gamepassId
    local name = getGamepassDisplayName(gamepassId, "Lucky Item")
    local price = math.max(0, math.floor(tonumber(luckyItem.price) or 0))

    return name, price, gamepassId
end

local function getScarletStock()
    local playerData = getPlayerData()
    local scarletShop = playerData and playerData.scarletShop

    if type(scarletShop) ~= "table" then
        return 0
    end

    return math.max(0, math.floor(tonumber(scarletShop.stock) or 0))
end

local function updateGemShopStatus(message)
    if message ~= nil then
        State.gemShopLastStatus = tostring(message)
        LogRuntime.append("Gem Shop", State.gemShopLastStatus)
    end

    local shopState = getGemShopStateData()
    local luckyName, luckyPrice = getLuckyItemDisplay(shopState)
    local description = table.concat({
        "Auto Buy: " .. (State.autoBuyGemShop and "ON" or "OFF"),
        "Gems: " .. formatCompactNumber(getCurrentGems()),
        "Whitelist: "
            .. tostring(countSelectedGemShopItems())
            .. "/"
            .. tostring(#GemShopOptionKeys),
        "Lucky Item: " .. luckyName .. " • " .. formatCompactNumber(luckyPrice) .. " Gems",
        "Scarlet Stock: " .. tostring(getScarletStock()) .. " • 500 Gems",
        "Purchases: " .. tostring(State.gemShopRequests),
        "Failures: " .. tostring(State.gemShopFailures),
        "Last Item: " .. tostring(State.gemShopLastItem),
        "Status: " .. tostring(State.gemShopLastStatus),
    }, "\n")

    if State.gemShopStatusParagraph
        and type(State.gemShopStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.gemShopStatusParagraph:SetDesc(description)
        end)
    end
end

local function getGemShopCandidate(optionKey, shopState, gems)
    if string.sub(optionKey, 1, #GEM_SHOP_FIXED_PREFIX) == GEM_SHOP_FIXED_PREFIX then
        local rawKey = string.sub(optionKey, #GEM_SHOP_FIXED_PREFIX + 1)
        local config = GemShopFixedConfigByKey[rawKey]
        local originalKey = type(config) == "table" and config.Key or rawKey
        local fixedItems = shopState and shopState.fixedItems
        local itemState = type(fixedItems) == "table"
            and (fixedItems[originalKey] or fixedItems[rawKey])

        if type(config) ~= "table" then
            return nil, "config tidak ditemukan"
        end

        if type(itemState) ~= "table" then
            return nil, "state belum tersedia"
        end

        if hasGamepass(config.Id) then
            return nil, "sudah dimiliki"
        end

        if itemState.inStock ~= true then
            return nil, "stock habis"
        end

        local price = math.max(0, math.floor(tonumber(itemState.price) or 0))

        if gems < price then
            return nil, "gems kurang"
        end

        return {
            optionKey = optionKey,
            purchaseType = "fixed",
            purchaseArgument = originalKey,
            label = gemShopLabelFromKey(optionKey),
            price = price,
        }
    end

    if optionKey == GEM_SHOP_SPECIAL_LUCKY then
        local luckyName, price, gamepassId = getLuckyItemDisplay(shopState)

        if gamepassId == nil then
            return nil, "lucky item belum tersedia"
        end

        if hasGamepass(gamepassId) then
            return nil, "lucky item sudah dimiliki"
        end

        if gems < price then
            return nil, "gems kurang"
        end

        return {
            optionKey = optionKey,
            purchaseType = "lucky",
            label = "Lucky Item • " .. luckyName,
            price = price,
            gamepassId = gamepassId,
        }
    end

    if optionKey == GEM_SHOP_SPECIAL_SCARLET then
        local stock = getScarletStock()
        local price = 500

        if stock <= 0 then
            return nil, "stock habis"
        end

        if gems < price then
            return nil, "gems kurang"
        end

        return {
            optionKey = optionKey,
            purchaseType = "scarlet",
            label = "Scarlet Pack",
            price = price,
            stock = stock,
        }
    end

    return nil, "item tidak dikenal"
end

local function sendGemShopPurchase(candidate)
    local success, errorMessage = pcall(function()
        if candidate.purchaseType == "fixed" then
            BuyGemShopItem:FireServer("fixed", candidate.purchaseArgument)
        elseif candidate.purchaseType == "lucky" then
            BuyGemShopItem:FireServer("lucky")
        elseif candidate.purchaseType == "scarlet" then
            BuyGemShopItem:FireServer("scarlet")
        else
            error("Purchase type tidak dikenal")
        end
    end)

    if not success then
        State.gemShopFailures += 1
        updateGemShopStatus("Pembelian gagal: " .. tostring(errorMessage))
        return false, tostring(errorMessage)
    end

    State.gemShopRequests += 1
    State.gemShopLastItem = candidate.label
    updateGemShopStatus(
        "Pembelian diproses: "
            .. candidate.label
            .. " ("
            .. formatCompactNumber(candidate.price)
            .. " Gems)"
    )

    return true
end

local function buyNextGemShopItem(force)
    if countSelectedGemShopItems() == 0 then
        updateGemShopStatus("Whitelist Gem Shop kosong.")
        return false, "Whitelist kosong"
    end

    local now = os.clock()

    if not force and now < State.gemShopNextBuyAt then
        return false, "Buy cooldown"
    end

    local shopState = getGemShopStateData()
    local gems = getCurrentGems()
    local reasons = {}

    for _, optionKey in ipairs(GemShopOptionKeys) do
        if State.gemShopWhitelist[optionKey] then
            local itemNextAttempt = State.gemShopItemNextAttempt[optionKey] or 0

            if force or now >= itemNextAttempt then
                local candidate, reason = getGemShopCandidate(optionKey, shopState, gems)

                if candidate then
                    local sent, errorMessage = sendGemShopPurchase(candidate)

                    if sent then
                        local retryDelay = candidate.purchaseType == "scarlet"
                            and State.gemShopBuyCooldown
                            or State.gemShopRetryCooldown

                        State.gemShopNextBuyAt = now + State.gemShopBuyCooldown
                        State.gemShopItemNextAttempt[optionKey] = now + retryDelay

                        return true, candidate.label
                    end

                    State.gemShopNextBuyAt = now + 1
                    State.gemShopItemNextAttempt[optionKey] =
                        now + State.gemShopRetryCooldown

                    return false, errorMessage
                end

                reasons[#reasons + 1] =
                    gemShopLabelFromKey(optionKey) .. ": " .. tostring(reason)
            end
        end
    end

    if #reasons > 0 then
        updateGemShopStatus(table.concat(reasons, " | "))
    else
        updateGemShopStatus("Semua item whitelist masih dalam cooldown.")
    end

    return false, "Tidak ada item yang dapat dibeli"
end

local function setAutoBuyGemShop(enabled)
    State.autoBuyGemShop = enabled == true
    State.gemShopNextBuyAt = 0

    updateGemShopStatus(
        State.autoBuyGemShop
            and "Auto Buy Gem Shop diaktifkan."
            or "Auto Buy Gem Shop dinonaktifkan."
    )

    return State.autoBuyGemShop
end


local updateSummerShopStatus

local function getSummerQuestList()
    local playerData = getPlayerData()
    local summerQuests = playerData and playerData.summerQuests
    local quests = summerQuests and summerQuests.quests

    if type(quests) ~= "table" then
        return {}, playerData
    end

    return quests, playerData
end

local function getSummerQuestName(quest)
    if type(quest) ~= "table" then
        return "Unknown Quest"
    end

    local config
    pcall(function()
        config = SummerQuestConfig.getQuest(quest.id)
    end)

    if type(config) == "table"
        and type(config.name) == "string"
        and config.name ~= ""
    then
        return config.name
    end

    return tostring(quest.id or "Unknown Quest")
end

local function isSummerQuestClaimable(quest)
    if type(quest) ~= "table" or quest.claimed == true then
        return false
    end

    local target = tonumber(quest.target) or 0
    local progress = tonumber(quest.progress) or 0

    return target <= math.min(progress, target)
end

local function getSummerQuestStats()
    local quests, playerData = getSummerQuestList()
    local completed = 0
    local claimable = 0
    local claimed = 0

    for _, quest in ipairs(quests) do
        if quest.claimed == true then
            claimed += 1
        elseif isSummerQuestClaimable(quest) then
            completed += 1
            claimable += 1
        end
    end

    return {
        total = #quests,
        completed = completed,
        claimable = claimable,
        claimed = claimed,
        seashells = math.max(0, math.floor(tonumber(playerData and playerData.seashells) or 0)),
    }
end

local function updateSummerQuestStatus(message)
    if message ~= nil then
        State.summerQuestLastStatus = tostring(message)
        LogRuntime.append("Summer", "Quests • " .. State.summerQuestLastStatus)
    end

    local stats = getSummerQuestStats()
    local description = table.concat({
        "Auto Claim: " .. (State.autoClaimSummerQuests and "ON" or "OFF"),
        "Quests: " .. tostring(stats.total),
        "Claimable: " .. tostring(stats.claimable),
        "Claimed: " .. tostring(stats.claimed),
        "Seashells: " .. formatCompactNumber(stats.seashells),
        "Claims: " .. tostring(State.summerQuestClaimRequests),
        "Last Quest: " .. tostring(State.summerQuestLastClaim),
        "Status: " .. tostring(State.summerQuestLastStatus),
    }, "\n")

    if State.summerQuestStatusParagraph
        and type(State.summerQuestStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.summerQuestStatusParagraph:SetDesc(description)
        end)
    end
end

local function claimSummerQuests(force)
    local quests = getSummerQuestList()

    if #quests == 0 then
        updateSummerQuestStatus("Data Summer Quests belum tersedia.")
        return false, 0, "Tidak ada quest"
    end

    local now = os.clock()
    local sent = 0
    local lastError = nil

    -- Semua quest yang selesai dapat diklaim pada siklus yang sama.
    for index, quest in ipairs(quests) do
        if isSummerQuestClaimable(quest) then
            local nextAttempt = State.summerQuestNextAttempt[index] or 0

            if force == true or now >= nextAttempt then
                State.summerQuestNextAttempt[index] =
                    now + State.summerQuestClaimCooldown

                local success, errorMessage = pcall(function()
                    SummerQuestClaim:FireServer(index)
                end)

                if success then
                    sent += 1
                    State.summerQuestClaimRequests += 1
                    State.summerQuestLastClaim = getSummerQuestName(quest)
                else
                    State.summerQuestFailures += 1
                    lastError = tostring(errorMessage)
                    State.summerQuestNextAttempt[index] = now + 1
                end
            end
        end
    end

    if sent > 0 then
        updateSummerQuestStatus(
            string.format("Memproses %d quest.", sent)
        )
        return true, sent
    end

    if lastError then
        updateSummerQuestStatus("Claim gagal: " .. lastError)
        return false, 0, lastError
    end

    updateSummerQuestStatus("Belum ada Summer Quest yang dapat diklaim.")
    return true, 0
end

local function setAutoClaimSummerQuests(enabled)
    State.autoClaimSummerQuests = enabled == true
    table.clear(State.summerQuestNextAttempt)

    updateSummerQuestStatus(
        State.autoClaimSummerQuests
            and "Auto Claim Summer Quests diaktifkan."
            or "Auto Claim Summer Quests dinonaktifkan."
    )

    return State.autoClaimSummerQuests
end

local function summerShopIdFromSelection(value)
    local selected = tostring(normalizeSelectedValue(value) or "")

    if SummerShopConfigById[selected] then
        return selected
    end

    return SummerShopIdByLabel[selected]
end

local function countSelectedSummerShopItems()
    local count = 0

    for _, id in ipairs(SummerShopOptionIds) do
        if State.summerShopWhitelist[id] then
            count += 1
        end
    end

    return count
end

local function getSelectedSummerShopLabels()
    local selected = {}

    for _, label in ipairs(SummerShopOptionLabels) do
        local id = SummerShopIdByLabel[label]

        if id and State.summerShopWhitelist[id] then
            selected[#selected + 1] = label
        end
    end

    return selected
end

local function applySummerShopWhitelistSelection(selectedValues)
    local enabled = {}

    local function enable(value)
        local id = summerShopIdFromSelection(value)

        if id then
            enabled[id] = true
        end
    end

    if type(selectedValues) == "table" then
        local foundArrayValue = false

        for key, value in pairs(selectedValues) do
            if type(key) == "number" then
                foundArrayValue = true
                enable(value)
            elseif value == true then
                enable(key)
            elseif type(value) == "table" then
                enable(value)
            end
        end

        if not foundArrayValue and selectedValues.Title then
            enable(selectedValues)
        end
    elseif selectedValues ~= nil then
        enable(selectedValues)
    end

    table.clear(State.summerShopWhitelist)

    for _, id in ipairs(SummerShopOptionIds) do
        State.summerShopWhitelist[id] = enabled[id] == true
    end

    State.summerShopNextBuyAt = 0
    updateSummerShopStatus("Whitelist Summer Shop diperbarui.")
end

local function syncSummerShopWhitelistDropdown()
    if not State.summerShopWhitelistDropdown
        or type(State.summerShopWhitelistDropdown.Select) ~= "function"
    then
        return
    end

    pcall(function()
        State.summerShopWhitelistDropdown:Select(
            getSelectedSummerShopLabels()
        )
    end)
end

local function setAllSummerShopItems(enabled)
    for _, id in ipairs(SummerShopOptionIds) do
        State.summerShopWhitelist[id] = enabled == true
    end

    State.summerShopNextBuyAt = 0
    syncSummerShopWhitelistDropdown()
    updateSummerShopStatus(
        enabled
            and "Semua item Summer Shop dipilih."
            or "Whitelist Summer Shop dikosongkan."
    )
end

local function ownsSummerShopItem(playerData, item)
    if type(item) ~= "table" or item.OneTime ~= true or not playerData then
        return false
    end

    local grant = item.grant

    -- Sama seperti SummerShopController: ownership OneTime yang diketahui
    -- adalah booth skin.
    if type(grant) ~= "table" or grant.kind ~= "boothSkin" then
        return false
    end

    local boothSkins = playerData.boothSkins

    if type(boothSkins) ~= "table" then
        return false
    end

    for _, skin in ipairs(boothSkins) do
        if type(skin) == "table" and skin.id == grant.skin then
            return true
        end
    end

    return false
end

local function getSummerShopStock(playerData, itemId)
    local summerShop = playerData and playerData.summerShop
    local stock = summerShop and summerShop.stock

    if type(stock) ~= "table" then
        return 0
    end

    return math.max(0, math.floor(tonumber(stock[itemId]) or 0))
end

local function getSummerShopItemAvailability(playerData, item)
    if type(item) ~= "table" then
        return false, "config tidak valid"
    end

    if item.NoBuyButton == true then
        return false, "tidak memiliki tombol Seashell Buy"
    end

    local id = tostring(item.id or "")
    local price = math.max(0, math.floor(tonumber(item.seashellPrice) or 0))
    local seashells =
        math.max(0, math.floor(tonumber(playerData and playerData.seashells) or 0))

    if item.OneTime == true and ownsSummerShopItem(playerData, item) then
        return false, "sudah dimiliki"
    end

    if item.OneTime ~= true and item.NoStock ~= true then
        local stock = getSummerShopStock(playerData, id)

        if stock <= 0 then
            return false, "stock habis"
        end
    end

    if seashells < price then
        return false, string.format(
            "seashell kurang (%s/%s)",
            formatCompactNumber(seashells),
            formatCompactNumber(price)
        )
    end

    return true
end

updateSummerShopStatus = function(message)
    if message ~= nil then
        State.summerShopLastStatus = tostring(message)
        LogRuntime.append("Summer", "Shop • " .. State.summerShopLastStatus)
    end

    local playerData = getPlayerData()
    local seashells =
        math.max(0, math.floor(tonumber(playerData and playerData.seashells) or 0))

    local description = table.concat({
        "Auto Buy: " .. (State.autoBuySummerShop and "ON" or "OFF"),
        "Seashells: " .. formatCompactNumber(seashells),
        "Whitelist: "
            .. tostring(countSelectedSummerShopItems())
            .. "/"
            .. tostring(#SummerShopOptionIds),
        "Purchases: " .. tostring(State.summerShopBuyRequests),
        "Failures: " .. tostring(State.summerShopFailures),
        "Last Item: " .. tostring(State.summerShopLastItem),
        "Status: " .. tostring(State.summerShopLastStatus),
    }, "\n")

    if State.summerShopStatusParagraph
        and type(State.summerShopStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.summerShopStatusParagraph:SetDesc(description)
        end)
    end
end

local function buyNextSummerShopItem(force)
    local now = os.clock()

    if not force and now < State.summerShopNextBuyAt then
        return false, "Auto Buy masih cooldown"
    end

    if countSelectedSummerShopItems() == 0 then
        updateSummerShopStatus("Whitelist Summer Shop masih kosong.")
        return false, "Whitelist kosong"
    end

    local playerData = getPlayerData()

    if not playerData then
        updateSummerShopStatus("Data pemain belum siap.")
        return false, "Data pemain belum siap"
    end

    local blocked = {}

    for _, id in ipairs(SummerShopOptionIds) do
        if State.summerShopWhitelist[id] then
            local item = SummerShopConfigById[id]
            local nextAttempt = State.summerShopItemNextAttempt[id] or 0

            if force == true or now >= nextAttempt then
                local available, reason =
                    getSummerShopItemAvailability(playerData, item)

                if available then
                    State.summerShopNextBuyAt =
                        now + State.summerShopBuyCooldown
                    State.summerShopItemNextAttempt[id] =
                        now + State.summerShopRetryCooldown

                    local success, errorMessage = pcall(function()
                        SummerShopBuy:FireServer(id)
                    end)

                    if not success then
                        State.summerShopFailures += 1
                        State.summerShopNextBuyAt = now + 1
                        State.summerShopItemNextAttempt[id] = now + 1
                        updateSummerShopStatus(
                            "Buy gagal: " .. tostring(errorMessage)
                        )
                        return false, tostring(errorMessage)
                    end

                    State.summerShopBuyRequests += 1
                    State.summerShopLastItem =
                        tostring(item.displayName or id)
                    updateSummerShopStatus(
                        "Pembelian diproses: "
                            .. tostring(item.displayName or id)
                    )
                    return true, id
                end

                blocked[#blocked + 1] =
                    tostring(item and item.displayName or id)
                    .. ": "
                    .. tostring(reason)
            end
        end
    end

    updateSummerShopStatus(
        #blocked > 0
            and table.concat(blocked, " | ")
            or "Semua item whitelist masih dalam cooldown."
    )

    return false, "Tidak ada item yang dapat dibeli"
end

local function setAutoBuySummerShop(enabled)
    State.autoBuySummerShop = enabled == true
    State.summerShopNextBuyAt = 0

    updateSummerShopStatus(
        State.autoBuySummerShop
            and "Auto Buy Summer Shop diaktifkan."
            or "Auto Buy Summer Shop dinonaktifkan."
    )

    return State.autoBuySummerShop
end


local TOURNAMENT_BUY_FAILURE_MESSAGES = {
    tokens = "Tournament Tokens tidak cukup",
    claimed = "Reward sudah pernah dibeli",
    outofstock = "Stock reward habis",
    apply_failed = "Server gagal memberikan reward",
}

local function getTournamentShopData()
    local playerData = getPlayerData()
    local tournament = playerData and playerData.tournament
    local shop = type(tournament) == "table" and tournament.shop
    local rewards = type(shop) == "table" and shop.rewards

    return {
        playerData = playerData,
        tournament = type(tournament) == "table" and tournament or {},
        shop = type(shop) == "table" and shop or {},
        rewards = type(rewards) == "table" and rewards or {},
        tokens = math.max(
            0,
            math.floor(tonumber(type(tournament) == "table" and tournament.tokens) or 0)
        ),
    }
end

local function tournamentRewardDisplayName(entry)
    if type(entry) ~= "table" then
        return "Unknown Reward"
    end

    local payload = type(entry.payload) == "table" and entry.payload or {}
    local kind = tostring(payload.kind or "unknown")

    if kind == "card" then
        local rawCardId = payload.cardId
        local cardId = tostring(rawCardId or "")
        local card = CardConfig.Cards[rawCardId]
            or CardConfig.Cards[cardId]

        return tostring(
            card and card.DisplayName
                or cardId ~= "" and cardId
                or "Mystery Card"
        )
    elseif kind == "wctrophy" then
        return "World Cup Trophy"
    elseif kind == "misprintpotion" then
        return "Misprint Potion"
    elseif kind == "gems" then
        return formatCompactNumber(payload.amount or 0) .. " Gems"
    elseif kind == "cash" then
        return "$" .. formatCompactNumber(payload.amount or 0) .. " Cash"
    elseif kind == "spin" then
        return tostring(payload.amount or 1) .. "x Spin Wheel"
    elseif kind == "wish" then
        return tostring(payload.amount or 1) .. "x Wish Tickets"
    elseif kind == "pack" then
        return tostring(payload.packName or "Mystery") .. " Pack"
    elseif kind == "trophy" then
        return tostring(payload.trophyName or "Mystery") .. " Trophy"
    elseif kind == "potion" then
        return tostring(payload.potionId or "Mystery Potion")
    end

    return tostring(kind)
end

local function normalizeTournamentIdentity(value)
    return tostring(value or "")
        :lower()
        :gsub("[^%w]", "")
end

local function tournamentConfigMatchesValue(config, value)
    local expected = normalizeTournamentIdentity(value)
    if expected == "" or type(config) ~= "table" then
        return false
    end

    local candidates = {
        config.id,
        config.cardId,
        config.amount,
    }

    for _, candidate in ipairs(candidates) do
        if candidate ~= nil
            and normalizeTournamentIdentity(candidate) == expected
        then
            return true
        end
    end

    local perTier = config.perTier
    if type(perTier) == "table" then
        for _, candidate in pairs(perTier) do
            if normalizeTournamentIdentity(candidate) == expected then
                return true
            end
        end
    end

    return false
end

local function tournamentConfigIdFromEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local payload = type(entry.payload) == "table" and entry.payload or {}
    local directCandidates = {
        entry.configId,
        entry.rewardId,
        entry.sourceId,
        entry.id,
        payload.configId,
        payload.rewardId,
        payload.sourceId,
        payload.id,
    }

    for _, candidate in ipairs(directCandidates) do
        local id = candidate ~= nil and tostring(candidate)
        if id and TournamentShopConfigById[id] then
            return id
        end
    end

    local kind = tostring(payload.kind or entry.kind or "unknown")
    local matchingConfigs = {}

    for _, id in ipairs(TournamentShopOptionKeys) do
        local config = TournamentShopConfigById[id]
        if config and tostring(config.kind or "unknown") == kind then
            matchingConfigs[#matchingConfigs + 1] = config
        end
    end

    if #matchingConfigs == 1 then
        return tostring(matchingConfigs[1].id)
    end

    local detailCandidates = {
        payload.cardId,
        payload.packName,
        payload.trophyName,
        payload.potionId,
        payload.amount,
        payload.name,
        payload.displayName,
        entry.displayName,
    }

    for _, config in ipairs(matchingConfigs) do
        for _, detail in ipairs(detailCandidates) do
            if detail ~= nil and tournamentConfigMatchesValue(config, detail) then
                return tostring(config.id)
            end
        end
    end

    -- Saat dua config sama-sama berjenis potion, nama potion membedakan
    -- AdminWeatherPotion dari Potion reguler.
    if kind == "potion" then
        local potionName = normalizeTournamentIdentity(
            payload.potionId
                or payload.name
                or payload.displayName
                or entry.displayName
        )

        if potionName:find("adminweather", 1, true) then
            return TournamentShopConfigById.AdminWeatherPotion
                and "AdminWeatherPotion"
                or nil
        elseif potionName ~= "" then
            return TournamentShopConfigById.Potion and "Potion" or nil
        end
    end

    return nil
end

local function tournamentConfigIdFromSavedKey(value)
    local raw = tostring(value or "")

    if TournamentShopConfigById[raw] then
        return raw
    end

    return TournamentShopKeyByLabel[raw]
end

local function tournamentShopKeyFromSelection(value)
    local selected = normalizeSelectedValue(value)
    if selected == nil then
        return nil
    end

    return tournamentConfigIdFromSavedKey(selected)
end

local function getSelectedTournamentShopLabels()
    local labels = {}

    for index, id in ipairs(TournamentShopOptionKeys) do
        if State.tournamentShopWhitelist[id] then
            labels[#labels + 1] = TournamentShopOptionLabels[index]
        end
    end

    return labels
end

local function syncTournamentShopWhitelistDropdown()
    local dropdown = State.tournamentShopWhitelistDropdown
    if not dropdown then
        return
    end

    State.syncingTournamentShopDropdown = true

    if type(dropdown.Refresh) == "function" then
        local refreshed = pcall(function()
            dropdown:Refresh(TournamentShopOptionLabels)
        end)

        if not refreshed then
            pcall(function()
                dropdown:Refresh({
                    Values = TournamentShopOptionLabels,
                })
            end)
        end
    end

    if type(dropdown.Select) == "function" then
        pcall(function()
            dropdown:Select(getSelectedTournamentShopLabels())
        end)
    end

    State.syncingTournamentShopDropdown = false
end

local function refreshTournamentShopOptions(updateDropdown)
    local shopData = getTournamentShopData()
    local fingerprintParts = {}

    table.clear(TournamentShopEntryByKey)
    table.clear(TournamentShopCurrentEntries)

    for index, entry in ipairs(shopData.rewards) do
        if type(entry) == "table" then
            local configId = tournamentConfigIdFromEntry(entry)
            local displayName = tournamentRewardDisplayName(entry)
            local price = math.max(0, math.floor(tonumber(entry.price) or 0))
            local stock = math.max(0, math.floor(tonumber(entry.stock) or 0))
            local maxStock = math.max(
                0,
                math.floor(tonumber(entry.maxStock) or stock)
            )

            local normalizedEntry = {
                key = configId,
                configId = configId,
                index = index,
                displayName = displayName,
                kind = tostring(
                    type(entry.payload) == "table"
                        and entry.payload.kind
                        or "unknown"
                ),
                price = price,
                stock = stock,
                maxStock = maxStock,
                payload = type(entry.payload) == "table"
                    and entry.payload
                    or {},
                raw = entry,
            }

            TournamentShopCurrentEntries[#TournamentShopCurrentEntries + 1] =
                normalizedEntry

            if configId and not TournamentShopEntryByKey[configId] then
                TournamentShopEntryByKey[configId] = normalizedEntry
            end

            fingerprintParts[#fingerprintParts + 1] = table.concat({
                tostring(configId or "unknown"),
                tostring(index),
                tostring(price),
                tostring(stock),
                tostring(maxStock),
                displayName,
            }, "|")
        end
    end

    local fingerprint = table.concat(fingerprintParts, ";")
    local changed = fingerprint ~= State.tournamentShopOptionsFingerprint
    State.tournamentShopOptionsFingerprint = fingerprint

    if updateDropdown and changed then
        syncTournamentShopWhitelistDropdown()
    end

    return shopData, changed
end

local function countSelectedTournamentShopItems()
    local count = 0

    for _, id in ipairs(TournamentShopOptionKeys) do
        if State.tournamentShopWhitelist[id] then
            count += 1
        end
    end

    return count
end

local function applyTournamentShopWhitelistSelection(selectedValues)
    if State.syncingTournamentShopDropdown then
        return
    end

    local selectedIds = {}

    local function enable(value)
        local id = tournamentShopKeyFromSelection(value)
        if id then
            selectedIds[id] = true
        end
    end

    if type(selectedValues) == "table" then
        local foundArrayValue = false

        for key, value in pairs(selectedValues) do
            if type(key) == "number" then
                foundArrayValue = true
                enable(value)
            elseif value == true then
                enable(key)
            elseif type(value) == "table" then
                enable(value)
            end
        end

        if not foundArrayValue and selectedValues.Title then
            enable(selectedValues)
        end
    elseif selectedValues ~= nil then
        enable(selectedValues)
    end

    table.clear(State.tournamentShopWhitelist)

    for _, id in ipairs(TournamentShopOptionKeys) do
        State.tournamentShopWhitelist[id] = selectedIds[id] == true
    end

    State.tournamentShopNextBuyAt = 0
    State.tournamentShopLastStatus =
        "Reward List diperbarui."
end

local function setAllTournamentShopItems(enabled)
    for _, id in ipairs(TournamentShopOptionKeys) do
        State.tournamentShopWhitelist[id] = enabled == true
    end

    State.tournamentShopNextBuyAt = 0
    syncTournamentShopWhitelistDropdown()
    State.tournamentShopLastStatus = enabled
        and "Semua reward dipilih."
        or "Whitelist Tournament Shop dikosongkan."
end

local function updateTournamentShopStatus(message)
    if message ~= nil then
        State.tournamentShopLastStatus = tostring(message)
        LogRuntime.append("Tournament", State.tournamentShopLastStatus)
    end

    local shopData = getTournamentShopData()
    local affordable = 0
    local selectedAvailable = 0
    local recognized = 0

    for _, entry in ipairs(TournamentShopCurrentEntries) do
        if entry.configId then
            recognized += 1

            if State.tournamentShopWhitelist[entry.configId] then
                selectedAvailable += 1

                if entry.stock > 0 and shopData.tokens >= entry.price then
                    affordable += 1
                end
            end
        end
    end

    local description = table.concat({
        "Auto Buy: " .. (State.autoBuyTournamentShop and "ON" or "OFF"),
        "Tournament Tokens: " .. formatCompactNumber(shopData.tokens),
        "Config Rewards: " .. tostring(#TournamentShopOptionKeys),
        "Current Rewards: "
            .. tostring(#TournamentShopCurrentEntries)
            .. "/"
            .. tostring(TournamentConfig.ShopRewardsPerTournament or 3),
        "Recognized Current: " .. tostring(recognized),
        "Whitelist: "
            .. tostring(countSelectedTournamentShopItems())
            .. "/"
            .. tostring(#TournamentShopOptionKeys),
        "Selected Available: " .. tostring(selectedAvailable),
        "Affordable Selected: " .. tostring(affordable),
        "Pending: " .. (State.tournamentShopPending and "YES" or "NO"),
        "Purchases: " .. tostring(State.tournamentShopBuyRequests),
        "Purchases: " .. tostring(State.tournamentShopPurchases),
        "Failures: " .. tostring(State.tournamentShopFailures),
        "Last Item: " .. tostring(State.tournamentShopLastItem),
        "Status: " .. tostring(State.tournamentShopLastStatus),
    }, "\n")

    if State.tournamentShopStatusParagraph
        and type(State.tournamentShopStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.tournamentShopStatusParagraph:SetDesc(description)
        end)
    end
end

local function clearTournamentShopPending()
    State.tournamentShopPending = false
    State.tournamentShopPendingSince = 0
    State.tournamentShopPendingIndex = nil
    State.tournamentShopPendingKey = nil
    State.tournamentShopPendingDisplay = nil
end

local function buyNextTournamentShopItem(force)
    local now = os.clock()

    if State.tournamentShopPending then
        if (now - State.tournamentShopPendingSince)
            < State.tournamentShopPendingTimeout
        then
            return false, "Menunggu pembelian sebelumnya selesai"
        end

        clearTournamentShopPending()
        State.tournamentShopFailures += 1
        State.tournamentShopLastStatus =
            "Pending purchase timeout; mencoba ulang."
    end

    if not force and now < State.tournamentShopNextBuyAt then
        return false, "Buy masih cooldown"
    end

    local shopData = refreshTournamentShopOptions(true)

    if #TournamentShopCurrentEntries == 0 then
        updateTournamentShopStatus(
            "Data reward Tournament Shop belum tersedia."
        )
        return false, "Tournament Shop belum tersedia"
    end

    if countSelectedTournamentShopItems() == 0 then
        updateTournamentShopStatus(
            "Reward List masih kosong."
        )
        return false, "Whitelist kosong"
    end

    local blocked = {}

    -- Iterasi berdasarkan slot aktif. Whitelist tetap memakai ID config,
    -- sedangkan remote server tetap membutuhkan index slot saat ini.
    for _, entry in ipairs(TournamentShopCurrentEntries) do
        local configId = entry.configId

        if configId and State.tournamentShopWhitelist[configId] then
            local nextAttempt =
                State.tournamentShopItemNextAttempt[configId] or 0

            if force == true or now >= nextAttempt then
                if entry.stock <= 0 then
                    blocked[#blocked + 1] =
                        entry.displayName .. ": out of stock"
                    State.tournamentShopItemNextAttempt[configId] =
                        now + State.tournamentShopRetryCooldown
                elseif shopData.tokens < entry.price then
                    blocked[#blocked + 1] =
                        entry.displayName .. ": tokens kurang"
                    State.tournamentShopItemNextAttempt[configId] =
                        now + State.tournamentShopRetryCooldown
                else
                    State.tournamentShopPending = true
                    State.tournamentShopPendingSince = now
                    State.tournamentShopPendingIndex = entry.index
                    State.tournamentShopPendingKey = configId
                    State.tournamentShopPendingDisplay = entry.displayName
                    State.tournamentShopNextBuyAt =
                        now + State.tournamentShopBuyCooldown
                    State.tournamentShopItemNextAttempt[configId] =
                        now + State.tournamentShopRetryCooldown

                    local success, errorMessage = pcall(function()
                        TournamentServer:FireServer("buy", entry.index)
                    end)

                    if not success then
                        clearTournamentShopPending()
                        State.tournamentShopFailures += 1
                        State.tournamentShopNextBuyAt = now + 1
                        State.tournamentShopItemNextAttempt[configId] =
                            now + 1
                        updateTournamentShopStatus(
                            "Buy gagal: " .. tostring(errorMessage)
                        )
                        return false, tostring(errorMessage)
                    end

                    State.tournamentShopBuyRequests += 1
                    State.tournamentShopLastItem = entry.displayName
                    updateTournamentShopStatus(
                        "Pembelian diproses: "
                            .. entry.displayName
                            .. " ["
                            .. configId
                            .. "]"
                    )

                    return true, entry.displayName
                end
            end
        end
    end

    updateTournamentShopStatus(
        #blocked > 0
            and table.concat(blocked, " | ")
            or "Reward whitelist belum muncul pada shop saat ini."
    )

    return false, "Tidak ada reward whitelist yang dapat dibeli"
end

local function setAutoBuyTournamentShop(enabled)
    State.autoBuyTournamentShop = enabled == true
    State.tournamentShopNextBuyAt = 0
    table.clear(State.tournamentShopItemNextAttempt)

    updateTournamentShopStatus(
        State.autoBuyTournamentShop
            and "Auto Buy Tournament Shop diaktifkan."
            or "Auto Buy Tournament Shop dinonaktifkan."
    )

    return State.autoBuyTournamentShop
end

local function onTournamentServerRemote(action, payload)
    if action ~= "buy_result" or type(payload) ~= "table" then
        return
    end

    local index = tonumber(payload.index)
    local isPendingPurchase = State.tournamentShopPending
        and index ~= nil
        and index == tonumber(State.tournamentShopPendingIndex)

    if not isPendingPurchase then
        task.defer(function()
            if State.running then
                refreshTournamentShopOptions(true)
                updateTournamentShopStatus()
            end
        end)
        return
    end

    local displayName =
        State.tournamentShopPendingDisplay or "Tournament Reward"
    local pendingKey = State.tournamentShopPendingKey
    clearTournamentShopPending()
    State.tournamentShopNextBuyAt =
        os.clock() + State.tournamentShopBuyCooldown

    if payload.ok == true then
        State.tournamentShopPurchases += 1
        State.tournamentShopLastItem = displayName
        State.tournamentShopLastStatus = string.format(
            "Berhasil membeli %s • Stock %s • Next price %s",
            displayName,
            tostring(payload.newStock ~= nil and payload.newStock or "?"),
            tostring(payload.newPrice ~= nil and payload.newPrice or "?")
        )
    else
        State.tournamentShopFailures += 1
        local reason = tostring(payload.reason or "unknown")
        State.tournamentShopLastStatus =
            TOURNAMENT_BUY_FAILURE_MESSAGES[reason]
                or ("Purchase gagal: " .. reason)

        if pendingKey then
            State.tournamentShopItemNextAttempt[pendingKey] =
                os.clock() + State.tournamentShopRetryCooldown
        end
    end

    task.delay(0.35, function()
        if State.running then
            refreshTournamentShopOptions(true)
            updateTournamentShopStatus()
        end
    end)
end



local IndexRuntime = {}

function IndexRuntime.getStats()
    local playerData = getPlayerData()
    local unlockedCards =
        type(playerData and playerData.unlockedCards) == "table"
            and playerData.unlockedCards
            or {}
    local claimedIndexGems =
        type(playerData and playerData.claimedIndexGems) == "table"
            and playerData.claimedIndexGems
            or {}

    local stats = {
        playerDataReady = playerData ~= nil,
        total = 0,
        basic = 0,
        mutations = 0,
        unlockedCards = unlockedCards,
        claimedIndexGems = claimedIndexGems,
    }

    -- Sama seperti IndexController: setiap key unlocked yang bernilai true
    -- dan belum terdapat pada claimedIndexGems dihitung sebagai claimable.
    for claimKey, unlocked in pairs(unlockedCards) do
        if unlocked == true and claimedIndexGems[claimKey] ~= true then
            stats.total += 1

            if string.match(tostring(claimKey), "^%d+_") then
                stats.mutations += 1
            else
                stats.basic += 1
            end
        end
    end

    return stats
end

function IndexRuntime.updateStatus(message)
    if message ~= nil then
        State.indexLastStatus = tostring(message)
        LogRuntime.append("Index", State.indexLastStatus)
    end

    local stats = IndexRuntime.getStats()
    State.indexLastClaimable = stats.total

    local description = table.concat({
        "Auto Claim: " .. (State.autoClaimIndex and "ON" or "OFF"),
        "Claimable Total: " .. tostring(stats.total),
        "Basic Cards: " .. tostring(stats.basic),
        "Mutation Cards: " .. tostring(stats.mutations),
        "Claims: " .. tostring(State.indexRequests),
        "Failures: " .. tostring(State.indexFailures),
        "Status: " .. tostring(State.indexLastStatus),
    }, "\n")

    if State.indexStatusParagraph
        and type(State.indexStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.indexStatusParagraph:SetDesc(description)
        end)
    end

    return stats
end

function IndexRuntime.setAutoClaim(enabled)
    State.autoClaimIndex = enabled == true
    State.indexNextClaimAt = 0

    IndexRuntime.updateStatus(
        State.autoClaimIndex
            and "Auto Claim Index diaktifkan."
            or "Auto Claim Index dinonaktifkan."
    )

    return State.autoClaimIndex
end

function IndexRuntime.claimAll(force)
    local now = os.clock()

    if force ~= true and now < State.indexNextClaimAt then
        return false, "Claim Index masih cooldown"
    end

    local stats = IndexRuntime.getStats()
    State.indexLastClaimable = stats.total

    if not stats.playerDataReady then
        State.indexNextClaimAt = now + 2
        IndexRuntime.updateStatus("PlayerStore belum tersedia.")
        return false, "PlayerStore belum tersedia"
    end

    if stats.total <= 0 then
        State.indexNextClaimAt = now + State.indexClaimCooldown
        IndexRuntime.updateStatus("Tidak ada reward Index yang dapat diklaim.")
        return false, "Tidak ada reward Index"
    end

    State.indexNextClaimAt = now + State.indexClaimCooldown

    local success, errorMessage = pcall(function()
        ClaimAllIndexGems:FireServer()
    end)

    if not success then
        State.indexFailures += 1
        State.indexNextClaimAt = now + 1
        IndexRuntime.updateStatus(
            "Claim Index gagal: " .. tostring(errorMessage)
        )
        return false, tostring(errorMessage)
    end

    State.indexRequests += 1
    IndexRuntime.updateStatus(
        string.format(
            "Memproses %d reward Index.",
            stats.total
        )
    )

    return true, stats.total
end


local WishRuntime = {}

function WishRuntime.getData()
    local playerData = getPlayerData()
    local wishData = playerData and playerData.wish

    return {
        playerData = playerData,
        wish = wishData,
        tickets = tonumber(wishData and wishData.tickets) or 0,
        rebirth = tonumber(playerData and playerData.rebirth) or 0,
        minRebirth = tonumber(GachaConfig.MinRebirth) or 3,
    }
end

function WishRuntime.cardName(cardId)
    local cards = CardConfig.Cards
    local card = type(cards) == "table" and cards[cardId]

    if type(card) == "table" then
        return tostring(
            card.DisplayName
                or card.Name
                or card.name
                or cardId
                or "Unknown Card"
        )
    end

    return tostring(cardId or "Unknown Card")
end

function WishRuntime.formatResult(result)
    if type(result) ~= "table" then
        return "Unknown Wish Result", "unknown"
    end

    local outcome = tostring(result.outcome or "normal")

    if outcome == "exclusive" then
        return "Exclusive • " .. WishRuntime.cardName(result.cardId), outcome
    elseif outcome == "secret" then
        return "Secret Exclusive • " .. WishRuntime.cardName(result.cardId), outcome
    end

    local reward = result.reward
    if type(reward) ~= "table" then
        return "Wish Reward", outcome
    end

    local rewardType = tostring(reward.type or "unknown")
    local amount = tonumber(reward.amount or reward.value) or 0
    local name = tostring(
        reward.name
            or reward.displayName
            or reward.packName
            or reward.potionId
            or reward.trophyName
            or ""
    )

    if rewardType == "cash" then
        return "$" .. formatCompactNumber(amount) .. " Cash", rewardType
    elseif rewardType == "gems" then
        return formatCompactNumber(amount) .. " Gems", rewardType
    elseif rewardType == "pack" then
        return tostring(math.max(amount, 1)) .. "x "
            .. (name ~= "" and name or "Mystery") .. " Pack", rewardType
    elseif rewardType == "potion" then
        return tostring(math.max(amount, 1)) .. "x "
            .. (name ~= "" and name or "Mystery Potion"), rewardType
    elseif rewardType == "trophy" then
        return tostring(math.max(amount, 1)) .. "x "
            .. (name ~= "" and name or "Mystery") .. " Trophy", rewardType
    elseif rewardType == "tradetoken" then
        return formatCompactNumber(amount) .. " Trade Tokens", rewardType
    end

    if name ~= "" then
        return name, rewardType
    end

    if amount > 0 then
        return rewardType .. " • " .. formatCompactNumber(amount), rewardType
    end

    return rewardType, rewardType
end

function WishRuntime.logLines()
    local lines = {}
    local total = #State.wishLog
    local firstIndex = math.max(1, total - 11)

    for index = total, firstIndex, -1 do
        local entry = State.wishLog[index]
        lines[#lines + 1] = string.format(
            "#%d [%s] %s",
            entry.id,
            entry.time,
            entry.display
        )
    end

    if #lines == 0 then
        return {"Belum ada hasil Wish pada session ini."}
    end

    return lines
end

function WishRuntime.updateLogUI()
    if State.wishLogParagraph
        and type(State.wishLogParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.wishLogParagraph:SetDesc(
                table.concat(WishRuntime.logLines(), "\n")
            )
        end)
    end
end

function WishRuntime.updateStatus(message)
    if message ~= nil then
        State.wishLastStatus = tostring(message)
        LogRuntime.append("Wish", State.wishLastStatus)
    end

    local data = WishRuntime.getData()
    local description = table.concat({
        "Auto Spin: " .. (State.autoSpinWishTickets and "ON" or "OFF"),
        "Skip Animation: " .. (State.skipWishAnimation and "ON" or "OFF"),
        "Tickets: " .. tostring(data.tickets),
        "Rebirth: " .. tostring(data.rebirth)
            .. " / Required " .. tostring(data.minRebirth),
        "Pending: " .. (State.wishPending and "YES" or "NO"),
        "Wishes: " .. tostring(State.wishRequests),
        "Results: " .. tostring(State.wishResults),
        "Failures: " .. tostring(State.wishFailures),
        "Last Reward: " .. tostring(State.wishLastReward),
        "Status: " .. tostring(State.wishLastStatus),
    }, "\n")

    if State.wishStatusParagraph
        and type(State.wishStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.wishStatusParagraph:SetDesc(description)
        end)
    end
end

function WishRuntime.appendLog(result)
    local display, resultType = WishRuntime.formatResult(result)

    State.wishResults += 1

    local entry = {
        id = State.wishResults,
        timestamp = os.time(),
        time = os.date("%H:%M:%S"),
        type = resultType,
        outcome = result.outcome,
        cardId = result.cardId,
        reward = result.reward,
        display = display,
    }

    State.wishLastReward = display
    State.wishLog[#State.wishLog + 1] = entry

    while #State.wishLog > State.wishLogLimit do
        table.remove(State.wishLog, 1)
    end

    WishRuntime.updateLogUI()
    WishRuntime.updateStatus("Wish berhasil: " .. display)

    return entry
end

function WishRuntime.clearLog()
    table.clear(State.wishLog)
    State.wishResults = 0
    State.wishLastReward = "-"
    State.wishSessionStartedAt = os.time()

    WishRuntime.updateLogUI()
    WishRuntime.updateStatus("Wish session log di-reset.")
end

function WishRuntime.setAutoSpin(enabled)
    State.autoSpinWishTickets = enabled == true
    State.wishNextAt = 0

    WishRuntime.updateStatus(
        State.autoSpinWishTickets
            and "Auto Spin Wish Tickets diaktifkan."
            or "Auto Spin Wish Tickets dinonaktifkan."
    )

    return State.autoSpinWishTickets
end

function WishRuntime.setSkipAnimation(enabled)
    State.skipWishAnimation = enabled == true

    if State.skipWishAnimation then
        State.wishAnimationBusy = false
        State.wishAnimationStartedAt = 0
    end

    WishRuntime.updateStatus(
        State.skipWishAnimation
            and "Wish animation akan dilewati."
            or "Wish animation native akan diputar."
    )

    return State.skipWishAnimation
end

function WishRuntime.playAnimation(result)
    if State.skipWishAnimation then
        return false
    end

    State.wishAnimationBusy = true
    State.wishAnimationStartedAt = os.clock()

    local success, errorMessage = pcall(function()
        if type(AnimationController.Init) == "function" then
            AnimationController.Init()
        end

        AnimationController.play(result, function()
            State.wishAnimationBusy = false
            State.wishAnimationStartedAt = 0
            WishRuntime.updateStatus("Wish animation selesai.")
        end)
    end)

    if not success then
        State.wishAnimationBusy = false
        State.wishAnimationStartedAt = 0
        WishRuntime.updateStatus(
            "Wish berhasil, tetapi animation gagal: " .. tostring(errorMessage)
        )
        return false, tostring(errorMessage)
    end

    return true
end

function WishRuntime.perform(force)
    local now = os.clock()

    if State.wishPending then
        return false, "Wish request masih diproses"
    end

    if State.wishAnimationBusy then
        if now - State.wishAnimationStartedAt < 30 then
            return false, "Menunggu Wish animation selesai"
        end

        State.wishAnimationBusy = false
        State.wishAnimationStartedAt = 0
    end

    if force ~= true and now < State.wishNextAt then
        return false, "Wish masih cooldown"
    end

    local data = WishRuntime.getData()

    if not data.playerData then
        State.wishNextAt = now + 2
        WishRuntime.updateStatus("PlayerStore belum tersedia.")
        return false, "PlayerStore belum tersedia"
    end

    if data.rebirth < data.minRebirth then
        State.wishNextAt = now + 5
        WishRuntime.updateStatus(
            string.format(
                "Wish terkunci: membutuhkan Rebirth %d.",
                data.minRebirth
            )
        )
        return false, "Wish belum terbuka"
    end

    if data.tickets <= 0 then
        State.wishNextAt = now + 3
        WishRuntime.updateStatus("Tidak ada Wish Tickets.")
        return false, "Tidak ada Wish Tickets"
    end

    State.wishPending = true
    State.wishRequests += 1
    State.wishNextAt = now + State.wishRequestCooldown
    WishRuntime.updateStatus("Memproses Wish...")

    local success, result = pcall(function()
        return PerformWish:InvokeServer()
    end)

    State.wishPending = false

    if not success then
        State.wishFailures += 1
        State.wishNextAt = os.clock() + State.wishRateLimitCooldown
        WishRuntime.updateStatus("Wish gagal: " .. tostring(result))
        return false, tostring(result)
    end

    if type(result) ~= "table" then
        State.wishFailures += 1
        WishRuntime.updateStatus("Hasil Wish tidak valid.")
        return false, "Hasil Wish tidak valid"
    end

    if result.ok ~= true then
        local reason = tostring(result.reason or "unknown")

        if reason ~= "rate_limited" then
            State.wishFailures += 1
        end

        if reason == "no_tickets" then
            State.wishNextAt = os.clock() + 3
            WishRuntime.updateStatus("Server: tidak ada Wish Tickets.")
            return false, "Tidak ada Wish Tickets"
        elseif reason == "locked_rebirth" then
            State.wishNextAt = os.clock() + 5
            WishRuntime.updateStatus(
                "Server: Wish belum terbuka untuk Rebirth saat ini."
            )
            return false, "Wish belum terbuka"
        elseif reason == "rate_limited" then
            State.wishNextAt = os.clock() + State.wishRateLimitCooldown
            WishRuntime.updateStatus("Server rate limit; mencoba lagi nanti.")
            return false, "Rate limited"
        end

        WishRuntime.updateStatus("Wish gagal: " .. reason)
        return false, reason
    end

    local entry = WishRuntime.appendLog(result)
    State.wishNextAt = os.clock() + State.wishRequestCooldown

    if not State.skipWishAnimation then
        WishRuntime.playAnimation(result)
    end

    return true, entry.display
end


local AntiAfkRuntime = {
    virtualUser = nil,
    virtualInputManager = nil,
}

pcall(function()
    AntiAfkRuntime.virtualUser = game:GetService("VirtualUser")
end)

pcall(function()
    AntiAfkRuntime.virtualInputManager =
        game:GetService("VirtualInputManager")
end)

function AntiAfkRuntime.updateStatus(message)
    if message ~= nil then
        State.antiAfkLastStatus = tostring(message)
        LogRuntime.append("Anti AFK", State.antiAfkLastStatus)
    end

    local lastPulse = "Belum pernah"
    if State.lastAntiAfkAt > 0 then
        lastPulse = os.date("%H:%M:%S", State.lastAntiAfkAt)
    end

    local description = table.concat({
        "Enabled: " .. (State.antiAfk and "ON" or "OFF"),
        "Interval: " .. tostring(State.antiAfkInterval) .. "s",
        "Pulses: " .. tostring(State.antiAfkCount),
        "Last Pulse: " .. lastPulse,
        "Method: " .. tostring(State.antiAfkMethod),
        "Error: " .. tostring(State.lastAntiAfkError or "-"),
        "Status: " .. tostring(State.antiAfkLastStatus),
    }, "\n")

    if State.antiAfkStatusParagraph
        and type(State.antiAfkStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.antiAfkStatusParagraph:SetDesc(description)
        end)
    end
end

function AntiAfkRuntime.tryMouseMoveRelative()
    local mover

    if type(Environment) == "table" then
        mover = Environment.mousemoverel
            or Environment.mouse_move_relative
            or Environment.mouserel
    end

    if type(mover) ~= "function"
        and type(mousemoverel) == "function"
    then
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

function AntiAfkRuntime.tryVirtualInputMouse()
    local manager = AntiAfkRuntime.virtualInputManager
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

function AntiAfkRuntime.getSafePulseKey()
    local blockedKey = normalizeWindowKeybind(State.windowKeybind)
    local candidates = {
        "F15",
        "F14",
        "F13",
        "LeftBracket",
        "RightBracket",
        "BackSlash",
        "RightControl",
        "LeftControl",
    }

    for _, keyName in ipairs(candidates) do
        local keyCode = Enum.KeyCode[keyName]

        if keyCode and keyName ~= blockedKey then
            return keyCode
        end
    end

    return nil
end

function AntiAfkRuntime.tryVirtualInputKey()
    local manager = AntiAfkRuntime.virtualInputManager
    if not manager then
        return false, "VirtualInputManager unavailable"
    end

    local keyCode = AntiAfkRuntime.getSafePulseKey()
    if not keyCode then
        return false, "No safe key available"
    end

    local success, errorMessage = pcall(function()
        manager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.04)
        manager:SendKeyEvent(false, keyCode, false, game)
    end)

    return success, success and nil or tostring(errorMessage)
end

function AntiAfkRuntime.tryVirtualUser()
    local virtualUser = AntiAfkRuntime.virtualUser
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

function AntiAfkRuntime.pulse(source, force)
    if not State.running then
        return false, "Script sudah berhenti"
    end

    if not State.antiAfk and force ~= true then
        return false, "Anti AFK disabled"
    end

    if State.antiAfkBusy then
        return false, "Anti AFK pulse sedang berjalan"
    end

    State.antiAfkBusy = true

    local successfulMethods = {}
    local errors = {}
    local methods = {
        {"MouseRel", AntiAfkRuntime.tryMouseMoveRelative},
        {"VIM Mouse", AntiAfkRuntime.tryVirtualInputMouse},
        {"VirtualUser", AntiAfkRuntime.tryVirtualUser},
        {"VIM Key", AntiAfkRuntime.tryVirtualInputKey},
    }

    for _, method in ipairs(methods) do
        local name = method[1]
        local callback = method[2]
        local success, errorMessage = callback()

        if success then
            successfulMethods[#successfulMethods + 1] = name
        elseif errorMessage then
            errors[#errors + 1] =
                name .. ": " .. tostring(errorMessage)
        end
    end

    State.antiAfkBusy = false
    State.nextAntiAfkPulseAt =
        os.clock() + (tonumber(State.antiAfkInterval) or 45)

    if #successfulMethods > 0 then
        State.antiAfkCount += 1
        State.lastAntiAfkAt = os.time()
        State.antiAfkMethod = table.concat(successfulMethods, " + ")
        State.lastAntiAfkError =
            #errors > 0 and table.concat(errors, " | ") or nil

        AntiAfkRuntime.updateStatus(
            "Keep-alive berhasil"
                .. (source and (" • " .. tostring(source)) or "")
        )
        return true, State.antiAfkMethod
    end

    State.antiAfkMethod = "FAILED"
    State.lastAntiAfkError =
        #errors > 0 and table.concat(errors, " | ")
        or "No supported virtual input method"

    AntiAfkRuntime.updateStatus("Semua metode keep-alive gagal.")
    return false, State.lastAntiAfkError
end

function AntiAfkRuntime.setEnabled(enabled)
    State.antiAfk = enabled == true
    State.nextAntiAfkPulseAt = 0

    if not State.antiAfk then
        State.antiAfkMethod = "disabled"
        State.lastAntiAfkError = nil
        AntiAfkRuntime.updateStatus("Anti AFK dinonaktifkan.")
    else
        AntiAfkRuntime.updateStatus(
            "Anti AFK aktif; menguji metode keep-alive."
        )

        task.defer(function()
            if State.running and State.antiAfk then
                AntiAfkRuntime.pulse("toggle", false)
            end
        end)
    end

    return State.antiAfk
end


local ServerRuntime = {}

function ServerRuntime.rejoin()
    if State.rejoining then
        return false, "Rejoin is already in progress."
    end

    State.rejoining = true
    State.lastRejoinStatus = "Rejoining current server..."
    LogRuntime.append(
        "Hub",
        State.lastRejoinStatus,
        "info",
        true
    )

    task.spawn(function()
        local success, errorMessage = pcall(function()
            local jobId = tostring(game.JobId or "")

            if jobId ~= "" then
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    jobId,
                    LocalPlayer
                )
            else
                TeleportService:Teleport(
                    game.PlaceId,
                    LocalPlayer
                )
            end
        end)

        if not success then
            State.rejoining = false
            State.lastRejoinStatus =
                "Rejoin failed: " .. tostring(errorMessage)

            LogRuntime.append(
                "Hub",
                State.lastRejoinStatus,
                "error",
                true
            )

            notify(
                "Rejoin",
                State.lastRejoinStatus,
                "triangle-alert"
            )
        end
    end)

    return true, State.lastRejoinStatus
end

function ServerRuntime.getState()
    return {
        rejoining = State.rejoining,
        status = State.lastRejoinStatus,
        placeId = game.PlaceId,
        jobId = tostring(game.JobId or ""),
    }
end


local CodesRuntime = {}

function CodesRuntime.normalize(code)
    return string.upper(
        tostring(code or "")
            :gsub("^%s+", "")
            :gsub("%s+$", "")
    )
end

function CodesRuntime.getCodes()
    local result = {}
    local seen = {}

    for _, rawCode in ipairs(REDEEM_CODES) do
        local code = CodesRuntime.normalize(rawCode)

        if code ~= ""
            and #code >= 3
            and string.match(code, "^[A-Z0-9]+%-[A-Z0-9]+$")
            and not seen[code]
        then
            seen[code] = true
            result[#result + 1] = code
        end
    end

    return result
end

function CodesRuntime.getPendingCodes()
    local pending = {}

    for _, code in ipairs(CodesRuntime.getCodes()) do
        if State.codeAttempted[code] ~= true then
            pending[#pending + 1] = code
        end
    end

    return pending
end

function CodesRuntime.checkGroup(force)
    local now = os.clock()

    if force ~= true
        and State.codeGroupMember ~= nil
        and now < State.codeGroupCheckAt
    then
        return State.codeGroupMember
    end

    local success, result = pcall(function()
        return LocalPlayer:IsInGroupAsync(REDEEM_CODE_GROUP_ID)
    end)

    State.codeGroupCheckAt = now + 60

    if not success then
        State.codeGroupMember = nil
        State.codeFailures += 1
        State.codeLastStatus = "Could not check group membership."
        LogRuntime.append("Codes", State.codeLastStatus, "error")
        return false, tostring(result)
    end

    State.codeGroupMember = result == true

    if not State.codeGroupMember then
        State.codeLastStatus =
            "Join the required group before redeeming codes."
    end

    return State.codeGroupMember
end

function CodesRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.codeLastStatus = tostring(message)

        if shouldLog == true then
            LogRuntime.append("Codes", State.codeLastStatus)
        end
    end

    local codes = CodesRuntime.getCodes()
    local pending = CodesRuntime.getPendingCodes()
    local groupText

    if State.codeGroupMember == true then
        groupText = "Joined"
    elseif State.codeGroupMember == false then
        groupText = "Not Joined"
    else
        groupText = "Not Checked"
    end

    local description = table.concat({
        "Auto Redeem: " .. (State.autoRedeemCodes and "ON" or "OFF"),
        "Saved Codes: " .. tostring(#codes),
        "Pending: " .. tostring(#pending),
        "Attempted: " .. tostring(#codes - #pending),
        "Group: " .. groupText,
        "Requests: " .. tostring(State.codeRequests),
        "Skipped: " .. tostring(State.codeSkipped),
        "Failures: " .. tostring(State.codeFailures),
        "Last Code: " .. tostring(State.codeLastCode),
        "Status: " .. tostring(State.codeLastStatus),
    }, "\n")

    if State.codeStatusParagraph
        and type(State.codeStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.codeStatusParagraph:SetDesc(description)
        end)
    end
end

function CodesRuntime.setAutoRedeem(enabled)
    State.autoRedeemCodes = enabled == true
    State.codeNextRedeemAt = 0

    CodesRuntime.updateUI(
        State.autoRedeemCodes
            and "Auto Redeem enabled."
            or "Auto Redeem disabled.",
        true
    )

    return State.autoRedeemCodes
end

function CodesRuntime.redeem(code, force)
    local now = os.clock()
    code = CodesRuntime.normalize(code)

    if code == ""
        or not string.match(code, "^[A-Z0-9]+%-[A-Z0-9]+$")
    then
        return false, "Invalid code format"
    end

    if force ~= true and now < State.codeNextRedeemAt then
        return false, "Redeem is on cooldown"
    end

    if force ~= true and State.codeAttempted[code] == true then
        State.codeSkipped += 1
        return false, "Code was already attempted"
    end

    local isMember, groupError = CodesRuntime.checkGroup(false)
    if not isMember then
        CodesRuntime.updateUI(
            groupError or "Join the required group before redeeming codes."
        )
        return false, groupError or "Required group has not been joined"
    end

    State.codeNextRedeemAt = now + State.codeRedeemInterval
    State.codeLastCode = code

    local success, errorMessage = pcall(function()
        -- CodesController sends lowercase text to the server.
        RedeemCode:FireServer(string.lower(code))
    end)

    if not success then
        State.codeFailures += 1
        State.codeNextRedeemAt = now + 2

        CodesRuntime.updateUI(
            "Could not submit code " .. code .. ".",
            true
        )

        return false, tostring(errorMessage)
    end

    -- The provided client controller does not receive a redemption result.
    -- Store this as attempted/submitted, not as a confirmed successful reward.
    State.codeAttempted[code] = true
    State.codeRequests += 1

    CodesRuntime.updateUI(
        "Submitted code: " .. code,
        true
    )

    return true, code
end

function CodesRuntime.redeemNext(force)
    local pending = CodesRuntime.getPendingCodes()

    if #pending <= 0 then
        CodesRuntime.updateUI("All saved codes have been tried.")
        return false, "No pending codes"
    end

    return CodesRuntime.redeem(pending[1], force == true)
end

function CodesRuntime.redeemAll()
    local pending = CodesRuntime.getPendingCodes()

    if #pending <= 0 then
        CodesRuntime.updateUI("All saved codes have been tried.")
        return false, "No pending codes"
    end

    local submitted = 0
    local failed = 0
    local firstError

    for _, code in ipairs(pending) do
        if not State.running then
            break
        end

        local success, result = CodesRuntime.redeem(code, false)

        if success then
            submitted += 1
        elseif result ~= "Redeem is on cooldown" then
            failed += 1
            firstError = firstError or result

            if result == "Required group has not been joined" then
                break
            end
        end

        task.wait(State.codeRedeemInterval)
    end

    CodesRuntime.updateUI(
        string.format(
            "Submitted %d code%s%s",
            submitted,
            submitted == 1 and "" or "s",
            failed > 0 and (" • " .. tostring(failed) .. " failed") or ""
        ),
        submitted > 0 or failed > 0
    )

    return submitted > 0, submitted, failed, firstError
end

function CodesRuntime.clearHistory()
    table.clear(State.codeAttempted)
    State.codeNextRedeemAt = 0
    State.codeSkipped = 0

    CodesRuntime.updateUI(
        "Code history cleared.",
        true
    )
end


local DailyRewardRuntime = {}

function DailyRewardRuntime.getPlayerState()
    local playerData = getPlayerData()
    local dailyData = playerData and playerData.dailyRewards

    return {
        ready = playerData ~= nil,
        rebirth = tonumber(playerData and playerData.rebirth) or 0,
        completed = type(dailyData) == "table"
            and dailyData.completed == true,
    }
end

function DailyRewardRuntime.getCachedState()
    return type(State.dailyRewardState) == "table"
        and State.dailyRewardState
        or nil
end

function DailyRewardRuntime.formatRemaining(nextClaimTime)
    local timestamp = tonumber(nextClaimTime) or 0
    local remaining = math.max(0, timestamp - os.time())

    if remaining <= 0 then
        return "Ready"
    end

    local hours = math.floor(remaining / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local seconds = remaining % 60

    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, seconds)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds)
    end

    return string.format("%ds", seconds)
end

function DailyRewardRuntime.getStatusLabel()
    local playerState = DailyRewardRuntime.getPlayerState()
    local rewardState = DailyRewardRuntime.getCachedState()

    if playerState.completed
        or (rewardState and rewardState.completed == true)
    then
        return "Completed"
    end

    if not playerState.ready then
        return "Loading"
    end

    if playerState.rebirth < 1 then
        return "Locked"
    end

    if not rewardState then
        return "Checking"
    end

    if rewardState.canClaim == true then
        return "Ready"
    end

    return "Waiting"
end

function DailyRewardRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.dailyRewardLastStatus = tostring(message)

        if shouldLog == true then
            LogRuntime.append(
                "Daily",
                State.dailyRewardLastStatus
            )
        end
    end

    local playerState = DailyRewardRuntime.getPlayerState()
    local rewardState = DailyRewardRuntime.getCachedState()
    local currentDay = tonumber(rewardState and rewardState.currentDay) or 0
    local phase = tonumber(rewardState and rewardState.phase) or 0
    local nextClaimTime = tonumber(
        rewardState and rewardState.nextClaimTime
    ) or 0

    local description = table.concat({
        "Auto Claim: "
            .. (State.autoClaimDailyRewards and "ON" or "OFF"),
        "Status: " .. DailyRewardRuntime.getStatusLabel(),
        "Phase: " .. (phase > 0 and tostring(phase) or "-"),
        "Current Day: "
            .. (currentDay > 0 and tostring(currentDay) or "-"),
        "Next Reward: "
            .. (
                nextClaimTime > 0
                    and DailyRewardRuntime.formatRemaining(nextClaimTime)
                    or "-"
            ),
        "Pending: " .. (State.dailyRewardPending and "YES" or "NO"),
        "Claims: " .. tostring(State.dailyRewardClaims),
        "Failures: " .. tostring(State.dailyRewardFailures),
        "Last Status: " .. tostring(State.dailyRewardLastStatus),
    }, "\n")

    if State.dailyRewardStatusParagraph
        and type(State.dailyRewardStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.dailyRewardStatusParagraph:SetDesc(description)
        end)
    end
end

function DailyRewardRuntime.setAutoClaim(enabled)
    State.autoClaimDailyRewards = enabled == true
    State.dailyRewardNextStateAt = 0
    State.dailyRewardNextClaimAt = 0

    DailyRewardRuntime.updateUI(
        State.autoClaimDailyRewards
            and "Auto Claim Daily Rewards enabled."
            or "Auto Claim Daily Rewards disabled.",
        true
    )

    return State.autoClaimDailyRewards
end

function DailyRewardRuntime.requestState(force)
    local now = os.clock()
    local playerState = DailyRewardRuntime.getPlayerState()

    if not playerState.ready then
        State.dailyRewardNextStateAt = now + 2
        DailyRewardRuntime.updateUI("Player data is loading.")
        return false, "Player data is loading"
    end

    if playerState.completed then
        State.dailyRewardState = {
            completed = true,
        }
        State.dailyRewardNextStateAt =
            now + State.dailyRewardStateRefreshInterval
        DailyRewardRuntime.updateUI("All Daily Rewards completed.")
        return false, "Daily Rewards completed"
    end

    if playerState.rebirth < 1 then
        State.dailyRewardNextStateAt = now + 10
        DailyRewardRuntime.updateUI(
            "Daily Rewards unlock after Rebirth 1."
        )
        return false, "Daily Rewards are locked"
    end

    if force ~= true and now < State.dailyRewardNextStateAt then
        return false, "Status refresh is on cooldown"
    end

    State.dailyRewardNextStateAt =
        now + State.dailyRewardStateRefreshInterval

    local success, errorMessage = pcall(function()
        DailyReward:FireServer("getState")
    end)

    if not success then
        State.dailyRewardFailures += 1
        State.dailyRewardNextStateAt = now + 3
        DailyRewardRuntime.updateUI(
            "Could not refresh Daily Rewards.",
            true
        )
        return false, tostring(errorMessage)
    end

    State.dailyRewardStateRequests += 1
    DailyRewardRuntime.updateUI("Checking Daily Rewards.")

    return true
end

function DailyRewardRuntime.clearPending()
    State.dailyRewardPending = false
    State.dailyRewardPendingAt = 0
end

function DailyRewardRuntime.claim(force)
    local now = os.clock()
    local playerState = DailyRewardRuntime.getPlayerState()
    local rewardState = DailyRewardRuntime.getCachedState()

    if State.dailyRewardPending then
        return false, "A claim is already being processed"
    end

    if force ~= true and now < State.dailyRewardNextClaimAt then
        return false, "Claim is on cooldown"
    end

    if not playerState.ready then
        State.dailyRewardNextStateAt = 0
        DailyRewardRuntime.requestState(true)
        return false, "Player data is loading"
    end

    if playerState.completed
        or (rewardState and rewardState.completed == true)
    then
        DailyRewardRuntime.updateUI("All Daily Rewards completed.")
        return false, "Daily Rewards completed"
    end

    if playerState.rebirth < 1 then
        DailyRewardRuntime.updateUI(
            "Daily Rewards unlock after Rebirth 1."
        )
        return false, "Daily Rewards are locked"
    end

    if not rewardState then
        State.dailyRewardNextStateAt = 0
        DailyRewardRuntime.requestState(true)
        return false, "Checking reward status"
    end

    if rewardState.canClaim ~= true then
        local nextClaimTime = tonumber(rewardState.nextClaimTime) or 0

        if nextClaimTime > 0 and nextClaimTime <= os.time() then
            State.dailyRewardNextStateAt = 0
            DailyRewardRuntime.requestState(true)
        end

        DailyRewardRuntime.updateUI("Daily Reward is not ready yet.")
        return false, "Daily Reward is not ready"
    end

    State.dailyRewardPending = true
    State.dailyRewardPendingAt = now
    State.dailyRewardNextClaimAt =
        now + State.dailyRewardClaimCooldown
    State.dailyRewardClaimRequests += 1

    local currentDay = tonumber(rewardState.currentDay) or 0

    local success, errorMessage = pcall(function()
        DailyReward:FireServer("claim")
    end)

    if not success then
        DailyRewardRuntime.clearPending()
        State.dailyRewardFailures += 1
        State.dailyRewardNextClaimAt = now + 2

        DailyRewardRuntime.updateUI(
            "Daily Reward claim failed.",
            true
        )
        return false, tostring(errorMessage)
    end

    DailyRewardRuntime.updateUI(
        currentDay > 0
            and ("Claiming Day " .. tostring(currentDay) .. " reward.")
            or "Claiming Daily Reward."
    )

    return true, currentDay
end

function DailyRewardRuntime.handleMessage(payload)
    if type(payload) ~= "table" then
        return
    end

    local action = tostring(payload.action or "")
    local incomingState = payload.state

    if type(incomingState) == "table" then
        State.dailyRewardState = incomingState

        local nextClaimTime =
            tonumber(incomingState.nextClaimTime) or 0
        local now = os.clock()

        if nextClaimTime > os.time() then
            State.dailyRewardNextStateAt = math.min(
                now + State.dailyRewardStateRefreshInterval,
                now + math.max(1, nextClaimTime - os.time())
            )
        else
            State.dailyRewardNextStateAt =
                now + State.dailyRewardStateRefreshInterval
        end
    end

    local claimedDay = tonumber(payload.claimedDay)

    if claimedDay then
        local shouldCount =
            State.dailyRewardPending
            or State.dailyRewardLastClaimedDay ~= claimedDay

        DailyRewardRuntime.clearPending()

        if shouldCount then
            State.dailyRewardClaims += 1
            State.dailyRewardLastClaimedDay = claimedDay

            DailyRewardRuntime.updateUI(
                "Day " .. tostring(claimedDay)
                    .. " reward claimed.",
                true
            )
        end

        task.delay(0.5, function()
            if State.running then
                State.dailyRewardNextStateAt = 0
                DailyRewardRuntime.requestState(true)
            end
        end)

        return
    end

    if State.dailyRewardPending
        and type(incomingState) == "table"
        and incomingState.canClaim ~= true
    then
        DailyRewardRuntime.clearPending()
    end

    if type(incomingState) == "table" then
        if incomingState.completed == true then
            DailyRewardRuntime.updateUI(
                "All Daily Rewards completed.",
                true
            )
        elseif incomingState.canClaim == true then
            local day = tonumber(incomingState.currentDay) or 0

            DailyRewardRuntime.updateUI(
                day > 0
                    and ("Day " .. tostring(day)
                        .. " reward is ready.")
                    or "Daily Reward is ready."
            )

            if State.autoClaimDailyRewards then
                task.defer(function()
                    if State.running and State.autoClaimDailyRewards then
                        DailyRewardRuntime.claim(false)
                    end
                end)
            end
        else
            DailyRewardRuntime.updateUI(
                action == "init"
                    and "Daily Rewards updated."
                    or nil
            )
        end
    end
end

function DailyRewardRuntime.tick()
    local now = os.clock()
    local playerState = DailyRewardRuntime.getPlayerState()
    local rewardState = DailyRewardRuntime.getCachedState()

    if State.dailyRewardPending
        and now - State.dailyRewardPendingAt
            >= State.dailyRewardPendingTimeout
    then
        DailyRewardRuntime.clearPending()
        State.dailyRewardFailures += 1
        State.dailyRewardNextStateAt = 0

        DailyRewardRuntime.updateUI(
            "Claim confirmation timed out.",
            true
        )
    end

    if playerState.completed then
        if not rewardState or rewardState.completed ~= true then
            State.dailyRewardState = {
                completed = true,
            }
        end

        DailyRewardRuntime.updateUI()
        return
    end

    if now >= State.dailyRewardNextStateAt then
        DailyRewardRuntime.requestState(false)
    end

    rewardState = DailyRewardRuntime.getCachedState()

    if State.autoClaimDailyRewards
        and rewardState
        and rewardState.canClaim == true
    then
        DailyRewardRuntime.claim(false)
    else
        DailyRewardRuntime.updateUI()
    end
end


local ConfigRuntime = {
    version = 8,
    root = "xSansHUB",
    folder = "xSansHUB/SpinASoccerCardHub",
    file = "xSansHUB/SpinASoccerCardHub/" .. tostring(game.PlaceId) .. ".json",
}

function ConfigRuntime.copyBooleanMap(source)
    local result = {}

    if type(source) == "table" then
        for key, enabled in pairs(source) do
            if enabled == true then
                result[tostring(key)] = true
            end
        end
    end

    return result
end

function ConfigRuntime.fileExists()
    if not State.configSupported then
        return false
    end

    if type(isfile) == "function" then
        local success, exists = pcall(isfile, ConfigRuntime.file)
        return success and exists == true
    end

    local success = pcall(readfile, ConfigRuntime.file)
    return success
end

function ConfigRuntime.ensureFolders()
    if not State.configSupported then
        return false, "Executor tidak mendukung readfile/writefile"
    end

    if type(makefolder) ~= "function" then
        return true
    end

    local folders = {
        ConfigRuntime.root,
        ConfigRuntime.folder,
    }

    for _, folder in ipairs(folders) do
        local exists = false

        if type(isfolder) == "function" then
            local success, result = pcall(isfolder, folder)
            exists = success and result == true
        end

        if not exists then
            local success, errorMessage = pcall(makefolder, folder)

            if not success and type(isfolder) == "function" then
                local checkSuccess, checkResult = pcall(isfolder, folder)

                if not (checkSuccess and checkResult == true) then
                    return false, tostring(errorMessage)
                end
            elseif not success then
                -- Beberapa executor error saat folder sudah ada tetapi tidak
                -- menyediakan isfolder. Dalam kasus itu, lanjut dan biarkan
                -- writefile menjadi validasi terakhir.
            end
        end
    end

    return true
end

function ConfigRuntime.buildSnapshot(includeSaveMetadata)
    local snapshot = {
        version = ConfigRuntime.version,
        placeId = game.PlaceId,
        gameName = getGameName(),

        autoSave = State.autoSave == true,
        autoLoad = State.autoLoad == true,
        windowKeybind = normalizeWindowKeybind(State.windowKeybind),

        autoCraft = State.autoCraft == true,
        trophyWhitelist = ConfigRuntime.copyBooleanMap(State.whitelist),

        autoClaimSeashell = State.autoClaimSeashell == true,

        autoClaimSpinWheel = State.autoClaimSpinWheel == true,
        autoSpinWheel = State.autoSpinWheel == true,

        autoSpinWishTickets = State.autoSpinWishTickets == true,
        skipWishAnimation = State.skipWishAnimation == true,

        autoClaimIndex = State.autoClaimIndex == true,

        autoClaimDailyRewards =
            State.autoClaimDailyRewards == true,

        autoRedeemCodes = State.autoRedeemCodes == true,
        codeAttempted =
            ConfigRuntime.copyBooleanMap(State.codeAttempted),

        autoBuyGemShop = State.autoBuyGemShop == true,
        gemShopWhitelist = ConfigRuntime.copyBooleanMap(State.gemShopWhitelist),

        autoClaimSummerQuests = State.autoClaimSummerQuests == true,

        autoBuySummerShop = State.autoBuySummerShop == true,
        summerShopWhitelist = ConfigRuntime.copyBooleanMap(State.summerShopWhitelist),

        autoBuyTournamentShop = State.autoBuyTournamentShop == true,
        tournamentShopWhitelist =
            ConfigRuntime.copyBooleanMap(State.tournamentShopWhitelist),

        antiAfk = State.antiAfk == true,
    }

    if includeSaveMetadata ~= false then
        snapshot.savedAt = os.time()
    end

    return snapshot
end

function ConfigRuntime.fingerprint()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(
            ConfigRuntime.buildSnapshot(false)
        )
    end)

    if not success then
        return nil, tostring(encoded)
    end

    return encoded
end

function ConfigRuntime.read()
    if not State.configSupported then
        return nil, "Executor tidak mendukung readfile/writefile"
    end

    if not ConfigRuntime.fileExists() then
        return nil, "Config belum tersimpan"
    end

    local readSuccess, raw = pcall(readfile, ConfigRuntime.file)
    if not readSuccess then
        return nil, tostring(raw)
    end

    local decodeSuccess, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not decodeSuccess or type(decoded) ~= "table" then
        return nil, decodeSuccess
            and "Format config tidak valid"
            or tostring(decoded)
    end

    return decoded
end

function ConfigRuntime.updateStatus(message)
    if message ~= nil then
        State.configLastStatus = tostring(message)
        LogRuntime.append("Config", State.configLastStatus)
    end

    local savedText = "Belum pernah"
    if State.configLastSavedAt and State.configLastSavedAt > 0 then
        savedText = os.date("%H:%M:%S", State.configLastSavedAt)
    end

    local description = table.concat({
        "Support: " .. (State.configSupported and "YES" or "NO"),
        "Path: " .. ConfigRuntime.file,
        "Exists: " .. (ConfigRuntime.fileExists() and "YES" or "NO"),
        "Auto Save: " .. (State.autoSave and "ON" or "OFF"),
        "Auto Load: " .. (State.autoLoad and "ON" or "OFF"),
        "Keybind: " .. tostring(State.windowKeybind),
        "Dirty: " .. (State.configDirty and "YES" or "NO"),
        "Last Saved: " .. savedText,
        "Status: " .. tostring(
            State.configLastStatus
                or State.configStartupError
                or "Config siap."
        ),
    }, "\n")

    if State.configStatusParagraph
        and type(State.configStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.configStatusParagraph:SetDesc(description)
        end)
    end
end

function ConfigRuntime.syncControls()
    local function setToggle(toggle, value)
        if toggle and type(toggle.Set) == "function" then
            pcall(function()
                toggle:Set(value == true)
            end)
        end
    end

    setToggle(State.autoCraftToggle, State.autoCraft)
    setToggle(State.autoClaimSeashellToggle, State.autoClaimSeashell)
    setToggle(State.autoClaimSpinWheelToggle, State.autoClaimSpinWheel)
    setToggle(State.autoSpinWheelToggle, State.autoSpinWheel)
    setToggle(State.autoSpinWishToggle, State.autoSpinWishTickets)
    setToggle(State.skipWishAnimationToggle, State.skipWishAnimation)
    setToggle(State.autoClaimIndexToggle, State.autoClaimIndex)
    setToggle(
        State.autoClaimDailyRewardsToggle,
        State.autoClaimDailyRewards
    )
    setToggle(State.autoRedeemCodesToggle, State.autoRedeemCodes)
    setToggle(State.autoBuyGemShopToggle, State.autoBuyGemShop)
    setToggle(State.autoClaimSummerQuestsToggle, State.autoClaimSummerQuests)
    setToggle(State.autoBuySummerShopToggle, State.autoBuySummerShop)
    setToggle(State.autoBuyTournamentShopToggle, State.autoBuyTournamentShop)
    setToggle(State.antiAfkToggle, State.antiAfk)
    setToggle(State.autoSaveToggle, State.autoSave)
    setToggle(State.autoLoadToggle, State.autoLoad)

    applyWindowKeybind(State.windowKeybind, true)

    syncWhitelistDropdown()
    syncGemShopWhitelistDropdown()
    syncSummerShopWhitelistDropdown()
    refreshTournamentShopOptions(false)
    syncTournamentShopWhitelistDropdown()

    updateStatus()
    updateSeashellStatus()
    updateSpinWheelStatus()
    WishRuntime.updateStatus()
    WishRuntime.updateLogUI()
    IndexRuntime.updateStatus()
    DailyRewardRuntime.updateUI()
    CodesRuntime.updateUI()
    updateGemShopStatus()
    updateSummerQuestStatus()
    updateSummerShopStatus()
    updateTournamentShopStatus()
    AntiAfkRuntime.updateStatus()
    ConfigRuntime.updateStatus()
end

function ConfigRuntime.resetActionCooldowns()
    State.nextCraftAt = 0
    State.gemShopNextBuyAt = 0
    State.summerShopNextBuyAt = 0
    State.tournamentShopNextBuyAt = 0
    State.spinWheelNextClaimAt = 0
    State.spinWheelNextSpinAt = 0
    State.wishNextAt = 0
    State.indexNextClaimAt = 0
    State.dailyRewardNextStateAt = 0
    State.dailyRewardNextClaimAt = 0
    DailyRewardRuntime.clearPending()
    State.codeNextRedeemAt = 0
    State.nextAntiAfkPulseAt = 0

    table.clear(State.gemShopItemNextAttempt)
    table.clear(State.summerQuestNextAttempt)
    table.clear(State.summerShopItemNextAttempt)
    table.clear(State.tournamentShopItemNextAttempt)
end

function ConfigRuntime.apply(config, syncUI)
    if type(config) ~= "table" then
        return false, "Format config tidak valid"
    end

    State.configLoading = true

    if config.autoSave ~= nil then
        State.autoSave = config.autoSave == true
    end
    if config.autoLoad ~= nil then
        State.autoLoad = config.autoLoad == true
    end
    if config.windowKeybind ~= nil then
        State.windowKeybind =
            normalizeWindowKeybind(config.windowKeybind)
    end

    if config.autoCraft ~= nil then
        State.autoCraft = config.autoCraft == true
    end
    if type(config.trophyWhitelist) == "table" then
        table.clear(State.whitelist)
        for _, trophyName in ipairs(TROPHY_ORDER) do
            State.whitelist[trophyName] =
                config.trophyWhitelist[trophyName] == true
        end
    end

    if config.autoClaimSeashell ~= nil then
        State.autoClaimSeashell = config.autoClaimSeashell == true
    end

    if config.autoClaimSpinWheel ~= nil then
        State.autoClaimSpinWheel = config.autoClaimSpinWheel == true
    end
    if config.autoSpinWheel ~= nil then
        State.autoSpinWheel = config.autoSpinWheel == true
    end

    if config.autoSpinWishTickets ~= nil then
        State.autoSpinWishTickets =
            config.autoSpinWishTickets == true
    end
    if config.skipWishAnimation ~= nil then
        State.skipWishAnimation =
            config.skipWishAnimation == true
    end

    if config.autoClaimIndex ~= nil then
        State.autoClaimIndex = config.autoClaimIndex == true
    end

    if config.autoClaimDailyRewards ~= nil then
        State.autoClaimDailyRewards =
            config.autoClaimDailyRewards == true
    end

    if config.autoRedeemCodes ~= nil then
        State.autoRedeemCodes = config.autoRedeemCodes == true
    end
    if type(config.codeAttempted) == "table" then
        table.clear(State.codeAttempted)

        for code, attempted in pairs(config.codeAttempted) do
            local normalized = CodesRuntime.normalize(code)

            if attempted == true
                and string.match(
                    normalized,
                    "^[A-Z0-9]+%-[A-Z0-9]+$"
                )
            then
                State.codeAttempted[normalized] = true
            end
        end
    end

    if config.autoBuyGemShop ~= nil then
        State.autoBuyGemShop = config.autoBuyGemShop == true
    end
    if type(config.gemShopWhitelist) == "table" then
        table.clear(State.gemShopWhitelist)
        for _, key in ipairs(GemShopOptionKeys) do
            State.gemShopWhitelist[key] =
                config.gemShopWhitelist[key] == true
        end
    end

    if config.autoClaimSummerQuests ~= nil then
        State.autoClaimSummerQuests =
            config.autoClaimSummerQuests == true
    end

    if config.autoBuySummerShop ~= nil then
        State.autoBuySummerShop = config.autoBuySummerShop == true
    end
    if type(config.summerShopWhitelist) == "table" then
        table.clear(State.summerShopWhitelist)
        for _, itemId in ipairs(SummerShopOptionIds) do
            State.summerShopWhitelist[itemId] =
                config.summerShopWhitelist[itemId] == true
        end
    end

    if config.autoBuyTournamentShop ~= nil then
        State.autoBuyTournamentShop =
            config.autoBuyTournamentShop == true
    end
    if type(config.tournamentShopWhitelist) == "table" then
        table.clear(State.tournamentShopWhitelist)

        for key, enabled in pairs(config.tournamentShopWhitelist) do
            if enabled == true then
                local configId = tournamentConfigIdFromSavedKey(key)
                if configId then
                    State.tournamentShopWhitelist[configId] = true
                end
            end
        end
    end

    if config.antiAfk ~= nil then
        State.antiAfk = config.antiAfk == true
        State.antiAfkMethod =
            State.antiAfk and "pending" or "disabled"
    end

    ConfigRuntime.resetActionCooldowns()
    State.configDirty = false
    State.configLoading = false

    local fingerprint = ConfigRuntime.fingerprint()
    State.configLastObservedFingerprint = fingerprint

    if syncUI ~= false then
        ConfigRuntime.syncControls()
    end

    return true
end

function ConfigRuntime.save()
    if not State.configSupported then
        ConfigRuntime.updateStatus(
            "Executor tidak mendukung readfile/writefile."
        )
        return false, "Executor tidak mendukung readfile/writefile"
    end

    local folderSuccess, folderError = ConfigRuntime.ensureFolders()
    if not folderSuccess then
        ConfigRuntime.updateStatus("Gagal membuat folder: " .. tostring(folderError))
        return false, folderError
    end

    local encodeSuccess, encoded = pcall(function()
        return HttpService:JSONEncode(
            ConfigRuntime.buildSnapshot(true)
        )
    end)

    if not encodeSuccess then
        ConfigRuntime.updateStatus("JSON encode gagal: " .. tostring(encoded))
        return false, tostring(encoded)
    end

    local writeSuccess, writeError = pcall(
        writefile,
        ConfigRuntime.file,
        encoded
    )

    if not writeSuccess then
        ConfigRuntime.updateStatus("writefile gagal: " .. tostring(writeError))
        return false, tostring(writeError)
    end

    State.configDirty = false
    State.configLastSavedAt = os.time()
    State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
    ConfigRuntime.updateStatus("Config berhasil disimpan.")

    return true
end

function ConfigRuntime.load()
    local config, readError = ConfigRuntime.read()
    if not config then
        ConfigRuntime.updateStatus(tostring(readError))
        return false, readError
    end

    local success, applyError = ConfigRuntime.apply(config, true)
    if not success then
        ConfigRuntime.updateStatus(tostring(applyError))
        return false, applyError
    end

    State.configStartupLoaded = true
    ConfigRuntime.updateStatus("Config berhasil dimuat dan diterapkan.")

    return true
end

function ConfigRuntime.requestSave()
    if State.configLoading then
        return
    end

    State.configDirty = true
    ConfigRuntime.updateStatus()

    if not State.autoSave or not State.configSupported then
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

        ConfigRuntime.save()
    end)
end

function ConfigRuntime.setAutoSave(enabled)
    State.autoSave = enabled == true

    -- Perubahan pilihan Auto Save disimpan langsung, termasuk ketika toggle
    -- sedang dimatikan.
    if State.configSupported then
        ConfigRuntime.save()
    else
        ConfigRuntime.updateStatus(
            "Auto Save berubah, tetapi file config tidak didukung."
        )
    end

    return State.autoSave
end

function ConfigRuntime.setAutoLoad(enabled)
    State.autoLoad = enabled == true

    -- Metadata Auto Load harus langsung tersimpan agar startup berikutnya tahu
    -- apakah isi config perlu diterapkan.
    if State.configSupported then
        ConfigRuntime.save()
    else
        ConfigRuntime.updateStatus(
            "Auto Load berubah, tetapi file config tidak didukung."
        )
    end

    return State.autoLoad
end

function ConfigRuntime.initialize()
    State.configInitialized = true

    if not State.configSupported then
        State.configStartupError =
            "Executor tidak mendukung readfile/writefile"
        State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
        return false, State.configStartupError
    end

    if not ConfigRuntime.fileExists() then
        State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
        return true, "Config belum ada; memakai default."
    end

    local config, readError = ConfigRuntime.read()
    if not config then
        State.configStartupError = tostring(readError)
        State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
        return false, readError
    end

    -- Auto Save/Auto Load selalu dibaca sebagai metadata. Isi config lainnya
    -- hanya diterapkan saat Auto Load aktif.
    if config.autoSave ~= nil then
        State.autoSave = config.autoSave == true
    end
    if config.autoLoad ~= nil then
        State.autoLoad = config.autoLoad == true
    end
    if config.windowKeybind ~= nil then
        State.windowKeybind =
            normalizeWindowKeybind(config.windowKeybind)
    end

    if State.autoLoad then
        local success, applyError = ConfigRuntime.apply(config, false)
        if not success then
            State.configStartupError = tostring(applyError)
            return false, applyError
        end

        State.configStartupLoaded = true
    end

    State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
    return true
end

local function normalizeWindowKeybind(value)
    local keyName

    if typeof(value) == "EnumItem" then
        keyName = value.Name
    else
        keyName = tostring(value or "G")
    end

    if Enum.KeyCode[keyName] then
        return keyName
    end

    return "G"
end

local function updateWindowKeybindTag()
    if State.keybindTag
        and type(State.keybindTag.SetTitle) == "function"
    then
        pcall(function()
            State.keybindTag:SetTitle(
                "Toggle: " .. tostring(State.windowKeybind)
            )
        end)
    end
end

local function applyWindowKeybind(value, syncControl)
    local keyName = normalizeWindowKeybind(value)
    local keyCode = Enum.KeyCode[keyName]

    State.windowKeybind = keyName

    if State.window
        and keyCode
        and type(State.window.SetToggleKey) == "function"
    then
        pcall(function()
            State.window:SetToggleKey(keyCode)
        end)
    end

    if syncControl ~= false
        and State.windowKeybindControl
        and type(State.windowKeybindControl.Set) == "function"
        and State.windowKeybindControl.Value ~= keyName
    then
        pcall(function()
            State.windowKeybindControl:Set(keyName)
        end)
    end

    updateWindowKeybindTag()
    return keyName
end

local HomeRuntime = {}

function HomeRuntime.getActiveFeatures()
    local features = {}

    local entries = {
        {State.autoCraft, "Trophies"},
        {State.autoClaimSeashell, "Seashells"},
        {State.autoClaimSpinWheel, "Free Spin"},
        {State.autoSpinWheel, "Spin Wheel"},
        {State.autoSpinWishTickets, "Wish"},
        {State.autoClaimDailyRewards, "Daily"},
        {State.autoRedeemCodes, "Codes"},
        {State.autoClaimIndex, "Index"},
        {State.autoBuyGemShop, "Gem Shop"},
        {State.autoClaimSummerQuests, "Summer Quests"},
        {State.autoBuySummerShop, "Summer Shop"},
        {State.autoBuyTournamentShop, "Tournament Shop"},
        {State.antiAfk, "Anti AFK"},
    }

    for _, entry in ipairs(entries) do
        if entry[1] then
            features[#features + 1] = entry[2]
        end
    end

    return features
end

function HomeRuntime.update(message)
    local playerData = getPlayerData() or {}
    local wishData = WishRuntime.getData()
    local tournamentData = getTournamentShopData()
    local indexData = IndexRuntime.getStats()
    local dailyStatus = DailyRewardRuntime.getStatusLabel()
    local pendingCodes = #CodesRuntime.getPendingCodes()
    local activeFeatures = HomeRuntime.getActiveFeatures()

    local activeText = #activeFeatures > 0
        and table.concat(activeFeatures, ", ")
        or "None"

    local description = table.concat({
        message or "Manage every feature from the tabs on the left.",
        "",
        "Active: " .. activeText,
        "",
        "Gems: " .. formatCompactNumber(getCurrentGems()),
        "Seashells: " .. formatCompactNumber(playerData.seashells or 0),
        "Wish Tickets: " .. formatCompactNumber(wishData.tickets),
        "Tournament Tokens: " .. formatCompactNumber(tournamentData.tokens),
        "",
        "Spin Rewards: " .. tostring(State.spinWheelResults),
        "Wish Rewards: " .. tostring(State.wishResults),
        "Daily Reward: " .. tostring(dailyStatus),
        "Codes Pending: " .. tostring(pendingCodes),
        "Index Ready: " .. tostring(indexData.total),
    }, "\n")

    if State.homeStatusParagraph
        and type(State.homeStatusParagraph.SetDesc) == "function"
    then
        pcall(function()
            State.homeStatusParagraph:SetDesc(description)
        end)
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

local function buildGui()
    local WindUI = loadWindUI()
    State.windUI = WindUI

    local Window = WindUI:CreateWindow({
        Title = "Spin A Soccer Card",
        Author = "xSansHUB",
        Folder = "xSansHUB_SpinASoccerCardHub",
        Icon = "layout-dashboard",
        Theme = "Indigo",
        ToggleKey = Enum.KeyCode[State.windowKeybind] or Enum.KeyCode.G,
        Size = UDim2.fromOffset(720, 520),
        MinSize = Vector2.new(620, 440),
        MaxSize = Vector2.new(900, 680),
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
            Title = "Spin A Soccer Card",
            Icon = "layout-dashboard",
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
        error("WindUI gagal membuat window.")
    end

    State.window = Window

    State.keybindTag = Window:Tag({
        Title = "Toggle: " .. tostring(State.windowKeybind),
        Icon = "keyboard",
        Border = true,
    })

    local HomeTab = Window:Tab({
        Title = "Home",
        Icon = "house",
        IconSize = 16,
    })

    HomeTab:Paragraph({
        Title = "Welcome",
        Desc = "Choose a feature from the left. Use your configured keybind to show or hide the hub.",
        Image = "layout-dashboard",
        ImageSize = 19,
        Size = "Small",
    })

    State.homeStatusParagraph = HomeTab:Paragraph({
        Title = "Overview",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    HomeTab:Button({
        Title = "Refresh Overview",
        Desc = "Update balances and activity.",
        Icon = "refresh-cw",
        Callback = function()
            HomeRuntime.update("Overview updated.")
        end,
    })

    HomeTab:Paragraph({
        Title = "Getting Started",
        Desc = table.concat({
            "1. Open a feature tab.",
            "2. Choose items when a purchase list is available.",
            "3. Enable the automation you need.",
            "4. Settings are saved automatically.",
        }, "\n"),
        Image = "circle-help",
        ImageSize = 19,
        Size = "Small",
    })

    local DailyTab = Window:Tab({
        Title = "Daily",
        Icon = "calendar-check",
        IconSize = 16,
    })

    State.dailyRewardStatusParagraph = DailyTab:Paragraph({
        Title = "Daily Reward",
        Desc = "Loading...",
        Image = "gift",
        ImageSize = 19,
        Size = "Small",
    })

    DailyTab:Button({
        Title = "Refresh",
        Desc = "Update the current Daily Reward status.",
        Icon = "refresh-cw",
        Callback = function()
            State.dailyRewardNextStateAt = 0
            local success, errorMessage =
                DailyRewardRuntime.requestState(true)

            notify(
                "Daily",
                success
                    and "Daily Reward status updated."
                    or tostring(errorMessage),
                success and "refresh-cw" or "triangle-alert"
            )
        end,
    })

    DailyTab:Button({
        Title = "Claim Now",
        Desc = "Claim the reward when it is ready.",
        Icon = "gift",
        Callback = function()
            local success, result =
                DailyRewardRuntime.claim(true)

            notify(
                "Daily",
                success
                    and (
                        tonumber(result) and tonumber(result) > 0
                            and ("Claiming Day "
                                .. tostring(result) .. " reward.")
                            or "Claiming Daily Reward."
                    )
                    or tostring(result),
                success and "gift" or "triangle-alert"
            )
        end,
    })

    State.autoClaimDailyRewardsToggle = DailyTab:Toggle({
        Title = "Auto Claim",
        Desc = "Claim Daily Rewards automatically when ready.",
        Icon = "calendar-check",
        Value = State.autoClaimDailyRewards,
        Callback = DailyRewardRuntime.setAutoClaim,
    })

    local CodesTab = Window:Tab({
        Title = "Codes",
        Icon = "ticket-check",
        IconSize = 16,
    })

    State.codeStatusParagraph = CodesTab:Paragraph({
        Title = "Redeem Codes",
        Desc = "Loading...",
        Image = "ticket",
        ImageSize = 19,
        Size = "Small",
    })

    CodesTab:Button({
        Title = "Redeem Available",
        Desc = "Submit every saved code that has not been tried.",
        Icon = "ticket-check",
        Callback = function()
            task.spawn(function()
                local success, submitted, failed, errorMessage =
                    CodesRuntime.redeemAll()

                if success then
                    notify(
                        "Codes",
                        string.format(
                            "Submitted %d code%s.",
                            tonumber(submitted) or 0,
                            tonumber(submitted) == 1 and "" or "s"
                        ),
                        "ticket-check"
                    )
                else
                    notify(
                        "Codes",
                        tostring(
                            errorMessage
                                or submitted
                                or "No pending codes"
                        ),
                        "triangle-alert"
                    )
                end
            end)
        end,
    })

    State.autoRedeemCodesToggle = CodesTab:Toggle({
        Title = "Auto Redeem",
        Desc = "Submit newly added saved codes automatically.",
        Icon = "refresh-cw",
        Value = State.autoRedeemCodes,
        Callback = CodesRuntime.setAutoRedeem,
    })

    CodesTab:Button({
        Title = "Clear Attempt History",
        Desc = "Allow saved codes to be submitted again.",
        Icon = "rotate-ccw",
        Callback = function()
            CodesRuntime.clearHistory()
            notify(
                "Codes",
                "Code attempt history cleared.",
                "rotate-ccw"
            )
        end,
    })

    CodesTab:Paragraph({
        Title = "Adding New Codes",
        Desc = table.concat({
            "Open the script and find the REDEEM_CODES section.",
            "Add official codes using the format WORD-WORD.",
            "Example: \\\"NEW-CODE\\\"",
        }, "\n"),
        Image = "circle-help",
        ImageSize = 19,
        Size = "Small",
    })

    local TrophyTab = Window:Tab({
        Title = "Trophies",
        Icon = "trophy",
        IconSize = 16,
    })

    State.statusParagraph = TrophyTab:Paragraph({
        Title = "Trophy Status",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    State.whitelistDropdown = TrophyTab:Dropdown({
        Title = "Craft List",
        Desc = "Choose the trophies you want to craft.",
        Values = TROPHY_ORDER,
        Value = getSelectedTrophies(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 300,
        Callback = applyWhitelistSelection,
    })

    TrophyTab:Space()

    TrophyTab:Button({
        Title = "Select All",
        Desc = "Pilih seluruh trophy.",
        Icon = "list-checks",
        Callback = function()
            setAllTrophies(true)
        end,
    })

    TrophyTab:Button({
        Title = "Clear All",
        Desc = "Kosongkan whitelist trophy.",
        Icon = "list-x",
        Callback = function()
            setAllTrophies(false)
        end,
    })

    TrophyTab:Button({
        Title = "Craft Now",
        Desc = "Craft one available trophy from your list.",
        Icon = "hammer",
        Callback = function()
            local crafted, result = craftNextWhitelisted()

            if crafted then
                notify("Craft Trophy", "Craft diproses: " .. tostring(result), "trophy")
            else
                notify("Craft Trophy", tostring(result), "triangle-alert")
            end
        end,
    })

    TrophyTab:Space()

    State.autoCraftToggle = TrophyTab:Toggle({
        Title = "Auto Craft",
        Desc = "Craft selected trophies whenever possible.",
        Icon = "refresh-cw",
        Value = State.autoCraft,
        Callback = setAutoCraft,
    })

    local SpinWheelTab = Window:Tab({
        Title = "Spin Wheel",
        Icon = "circle-dot",
        IconSize = 16,
    })

    State.spinWheelStatusParagraph = SpinWheelTab:Paragraph({
        Title = "Wheel Status",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    SpinWheelTab:Button({
        Title = "Refresh",
        Desc = "Update spins and free claim status.",
        Icon = "refresh-cw",
        Callback = function()
            local success, _, errorMessage = fetchSpinWheelData(true)

            if success then
                notify("Spin Wheel", "Data berhasil diperbarui.", "circle-dot")
            else
                notify(
                    "Spin Wheel",
                    tostring(errorMessage or "Gagal mengambil data."),
                    "triangle-alert"
                )
            end
        end,
    })

    SpinWheelTab:Button({
        Title = "Claim Free Spin",
        Desc = "Claim the free spin when ready.",
        Icon = "gift",
        Callback = function()
            local success, errorMessage = claimFreeSpin(true)

            notify(
                "Spin Wheel",
                success and "Free Spin sedang diproses."
                    or tostring(errorMessage),
                success and "gift" or "triangle-alert"
            )
        end,
    })

    SpinWheelTab:Button({
        Title = "Spin Once",
        Desc = "Use one available spin.",
        Icon = "rotate-cw",
        Callback = function()
            local success, errorMessage = spinWheelNow(true)

            notify(
                "Spin Wheel",
                success and "Spin dimulai."
                    or tostring(errorMessage),
                success and "rotate-cw" or "triangle-alert"
            )
        end,
    })

    SpinWheelTab:Space()

    State.autoClaimSpinWheelToggle = SpinWheelTab:Toggle({
        Title = "Auto Claim Free Spin",
        Desc = "Claim free spins automatically.",
        Icon = "gift",
        Value = State.autoClaimSpinWheel,
        Callback = setAutoClaimSpinWheel,
    })

    State.autoSpinWheelToggle = SpinWheelTab:Toggle({
        Title = "Auto Spin",
        Desc = "Use available spins automatically.",
        Icon = "refresh-cw",
        Value = State.autoSpinWheel,
        Callback = setAutoSpinWheel,
    })

    SpinWheelTab:Space()

    State.spinWheelLogParagraph = SpinWheelTab:Paragraph({
        Title = "Session Rewards",
        Desc = "Belum ada hadiah pada session ini.",
        Image = "scroll-text",
        ImageSize = 19,
        Size = "Small",
    })

    SpinWheelTab:Button({
        Title = "Clear Log",
        Desc = "Clear the rewards collected this session.",
        Icon = "trash-2",
        Callback = function()
            clearSpinWheelLog()
            notify("Spin Wheel", "Session log berhasil di-reset.", "trash-2")
        end,
    })

    local WishTab = Window:Tab({
        Title = "Wish",
        Icon = "sparkles",
        IconSize = 16,
    })

    State.wishStatusParagraph = WishTab:Paragraph({
        Title = "Wish Status",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    WishTab:Button({
        Title = "Wish Once",
        Desc = "Use one Wish Ticket.",
        Icon = "sparkles",
        Callback = function()
            local success, result = WishRuntime.perform(true)

            notify(
                "Wish",
                success
                    and ("Wish berhasil: " .. tostring(result))
                    or tostring(result),
                success and "sparkles" or "triangle-alert"
            )
        end,
    })

    State.autoSpinWishToggle = WishTab:Toggle({
        Title = "Auto Wish",
        Desc = "Use Wish Tickets automatically.",
        Icon = "refresh-cw",
        Value = State.autoSpinWishTickets,
        Callback = WishRuntime.setAutoSpin,
    })

    State.skipWishAnimationToggle = WishTab:Toggle({
        Title = "Skip Animation",
        Desc = "Show results immediately.",
        Icon = "fast-forward",
        Value = State.skipWishAnimation,
        Callback = WishRuntime.setSkipAnimation,
    })

    WishTab:Space()

    State.wishLogParagraph = WishTab:Paragraph({
        Title = "Session Rewards",
        Desc = "Belum ada hasil Wish pada session ini.",
        Image = "scroll-text",
        ImageSize = 19,
        Size = "Small",
    })

    WishTab:Button({
        Title = "Clear Log",
        Desc = "Clear the rewards collected this session.",
        Icon = "trash-2",
        Callback = function()
            WishRuntime.clearLog()
            notify("Wish", "Wish session log di-reset.", "trash-2")
        end,
    })

    local IndexTab = Window:Tab({
        Title = "Index",
        Icon = "book-open-check",
        IconSize = 16,
    })

    State.indexStatusParagraph = IndexTab:Paragraph({
        Title = "Index Status",
        Desc = "Loading...",
        Image = "gem",
        ImageSize = 19,
        Size = "Small",
    })

    IndexTab:Button({
        Title = "Claim Now",
        Desc = "Claim every available Index reward.",
        Icon = "gift",
        Callback = function()
            local success, result = IndexRuntime.claimAll(true)

            notify(
                "Index",
                success
                    and string.format(
                        "%d reward sedang diproses.",
                        tonumber(result) or 0
                    )
                    or tostring(result),
                success and "gift" or "triangle-alert"
            )
        end,
    })

    State.autoClaimIndexToggle = IndexTab:Toggle({
        Title = "Auto Claim",
        Desc = "Claim new Index rewards automatically.",
        Icon = "book-open-check",
        Value = State.autoClaimIndex,
        Callback = IndexRuntime.setAutoClaim,
    })

    local GemShopTab = Window:Tab({
        Title = "Gem Shop",
        Icon = "gem",
        IconSize = 16,
    })

    State.gemShopStatusParagraph = GemShopTab:Paragraph({
        Title = "Shop Status",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    State.gemShopWhitelistDropdown = GemShopTab:Dropdown({
        Title = "Purchase List",
        Desc = "Choose the items you want to buy.",
        Values = GemShopOptionLabels,
        Value = getSelectedGemShopLabels(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 320,
        Callback = function(selectedValues)
            applyGemShopWhitelistSelection(selectedValues)
            updateGemShopStatus()
        end,
    })

    GemShopTab:Space()

    GemShopTab:Button({
        Title = "Select All",
        Desc = "Pilih seluruh fixed item, Lucky Item, dan Scarlet Pack.",
        Icon = "list-checks",
        Callback = function()
            setAllGemShopItems(true)
            updateGemShopStatus()
        end,
    })

    GemShopTab:Button({
        Title = "Clear All",
        Desc = "Kosongkan whitelist Gem Shop.",
        Icon = "list-x",
        Callback = function()
            setAllGemShopItems(false)
            updateGemShopStatus()
        end,
    })

    GemShopTab:Button({
        Title = "Buy Now",
        Desc = "Buy one available item from your list.",
        Icon = "shopping-cart",
        Callback = function()
            local success, result = buyNextGemShopItem(true)

            notify(
                "Gem Shop",
                success and ("Pembelian diproses: " .. tostring(result))
                    or tostring(result),
                success and "shopping-cart" or "triangle-alert"
            )
        end,
    })

    GemShopTab:Button({
        Title = "Refresh",
        Desc = "Update balance, items, and stock.",
        Icon = "refresh-cw",
        Callback = function()
            updateGemShopStatus("Gem Shop berhasil di-refresh.")
        end,
    })

    GemShopTab:Space()

    State.autoBuyGemShopToggle = GemShopTab:Toggle({
        Title = "Auto Buy",
        Desc = "Buy selected items whenever possible.",
        Icon = "shopping-bag",
        Value = State.autoBuyGemShop,
        Callback = setAutoBuyGemShop,
    })

    GemShopTab:Paragraph({
        Title = "Purchase Notes",
        Desc = table.concat({
            "Owned or unavailable items are skipped.",
            "Purchases stop when stock or Gems run out.",
        }, "\n"),
        Image = "info",
        ImageSize = 19,
        Size = "Small",
    })

    local SummerTab = Window:Tab({
        Title = "Summer",
        Icon = "sun",
        IconSize = 16,
    })

    State.seashellStatusParagraph = SummerTab:Paragraph({
        Title = "Seashells",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    SummerTab:Button({
        Title = "Collect Seashells",
        Desc = "Collect every available seashell.",
        Icon = "hand",
        Callback = function()
            local success, amount, errorMessage = claimAllSeashells(true)

            if success and amount > 0 then
                notify(
                    "Claim Seashells",
                    string.format("%d request collect berhasil dikirim.", amount),
                    "shell"
                )
            elseif success then
                notify("Claim Seashells", "Tidak ada seashell tersedia.", "info")
            else
                notify(
                    "Claim Seashells",
                    tostring(errorMessage or "Tidak ada seashell yang berhasil."),
                    "triangle-alert"
                )
            end
        end,
    })

    SummerTab:Space()

    State.autoClaimSeashellToggle = SummerTab:Toggle({
        Title = "Auto Collect Seashells",
        Desc = "Collect seashells as they appear.",
        Icon = "refresh-cw",
        Value = State.autoClaimSeashell,
        Callback = setAutoClaimSeashell,
    })

    SummerTab:Space()

    State.summerQuestStatusParagraph = SummerTab:Paragraph({
        Title = "Summer Quests",
        Desc = "Loading...",
        Image = "list-checks",
        ImageSize = 19,
        Size = "Small",
    })

    SummerTab:Button({
        Title = "Claim Quests",
        Desc = "Claim every completed quest.",
        Icon = "gift",
        Callback = function()
            local success, amount, errorMessage = claimSummerQuests(true)

            if success and amount > 0 then
                notify(
                    "Summer Quests",
                    tostring(amount) .. " quest diproses.",
                    "gift"
                )
            elseif success then
                notify(
                    "Summer Quests",
                    "Belum ada quest yang dapat diklaim.",
                    "info"
                )
            else
                notify(
                    "Summer Quests",
                    tostring(errorMessage or "Claim gagal."),
                    "triangle-alert"
                )
            end
        end,
    })

    State.autoClaimSummerQuestsToggle = SummerTab:Toggle({
        Title = "Auto Claim Quests",
        Desc = "Claim completed quests automatically.",
        Icon = "refresh-cw",
        Value = State.autoClaimSummerQuests,
        Callback = setAutoClaimSummerQuests,
    })

    SummerTab:Space()

    State.summerShopStatusParagraph = SummerTab:Paragraph({
        Title = "Summer Shop",
        Desc = "Loading...",
        Image = "shopping-bag",
        ImageSize = 19,
        Size = "Small",
    })

    State.summerShopWhitelistDropdown = SummerTab:Dropdown({
        Title = "Purchase List",
        Desc = "Choose the items you want to buy.",
        Values = SummerShopOptionLabels,
        Value = getSelectedSummerShopLabels(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 340,
        Callback = applySummerShopWhitelistSelection,
    })

    SummerTab:Button({
        Title = "Select All",
        Desc = "Select every shop item.",
        Icon = "list-checks",
        Callback = function()
            setAllSummerShopItems(true)
        end,
    })

    SummerTab:Button({
        Title = "Clear All",
        Desc = "Clear the purchase list.",
        Icon = "list-x",
        Callback = function()
            setAllSummerShopItems(false)
        end,
    })

    SummerTab:Button({
        Title = "Buy Now",
        Desc = "Buy one available item from your list.",
        Icon = "shopping-cart",
        Callback = function()
            local success, result = buyNextSummerShopItem(true)

            notify(
                "Summer Shop",
                success
                    and ("Pembelian diproses: " .. tostring(result))
                    or tostring(result),
                success and "shopping-cart" or "triangle-alert"
            )
        end,
    })

    State.autoBuySummerShopToggle = SummerTab:Toggle({
        Title = "Auto Buy Shop",
        Desc = "Buy selected items whenever possible.",
        Icon = "refresh-cw",
        Value = State.autoBuySummerShop,
        Callback = setAutoBuySummerShop,
    })

    refreshTournamentShopOptions(false)

    local TournamentShopTab = Window:Tab({
        Title = "Tournament",
        Icon = "trophy",
        IconSize = 16,
    })

    State.tournamentShopStatusParagraph = TournamentShopTab:Paragraph({
        Title = "Shop Status",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    State.tournamentShopWhitelistDropdown = TournamentShopTab:Dropdown({
        Title = "Reward List",
        Desc = "Choose the rewards you want to buy.",
        Values = TournamentShopOptionLabels,
        Value = getSelectedTournamentShopLabels(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 390,
        Callback = function(selectedValues)
            applyTournamentShopWhitelistSelection(selectedValues)
            updateTournamentShopStatus()
        end,
    })

    TournamentShopTab:Button({
        Title = "Select All",
        Desc = "Select every reward.",
        Icon = "list-checks",
        Callback = function()
            setAllTournamentShopItems(true)
            updateTournamentShopStatus()
        end,
    })

    TournamentShopTab:Button({
        Title = "Clear All",
        Desc = "Clear the reward list.",
        Icon = "list-x",
        Callback = function()
            setAllTournamentShopItems(false)
            updateTournamentShopStatus()
        end,
    })

    TournamentShopTab:Button({
        Title = "Buy Now",
        Desc = "Buy one available reward from your list.",
        Icon = "shopping-cart",
        Callback = function()
            local success, result = buyNextTournamentShopItem(true)

            notify(
                "Tournament Shop",
                success
                    and ("Pembelian diproses: " .. tostring(result))
                    or tostring(result),
                success and "shopping-cart" or "triangle-alert"
            )
        end,
    })

    TournamentShopTab:Button({
        Title = "Refresh",
        Desc = "Update rewards, prices, stock, and tokens.",
        Icon = "refresh-cw",
        Callback = function()
            refreshTournamentShopOptions(true)
            updateTournamentShopStatus("Tournament Shop berhasil di-refresh.")
        end,
    })

    State.autoBuyTournamentShopToggle = TournamentShopTab:Toggle({
        Title = "Auto Buy",
        Desc = "Buy selected rewards whenever possible.",
        Icon = "refresh-cw",
        Value = State.autoBuyTournamentShop,
        Callback = setAutoBuyTournamentShop,
    })

    TournamentShopTab:Paragraph({
        Title = "Purchase Notes",
        Desc = table.concat({
            "Selected rewards are bought when they appear.",
            "Purchases stop when stock or Tokens run out.",
        }, "\n"),
        Image = "info",
        ImageSize = 19,
        Size = "Small",
    })

    local LogsTab = Window:Tab({
        Title = "Logs",
        Icon = "scroll-text",
        IconSize = 16,
    })

    State.logsSummaryParagraph = LogsTab:Paragraph({
        Title = "Session Logs",
        Desc = "Loading...",
        Image = "activity",
        ImageSize = 19,
        Size = "Small",
    })

    State.logsFilterDropdown = LogsTab:Dropdown({
        Title = "Filter",
        Desc = "Show logs from one feature or all features.",
        Values = LOG_FILTER_OPTIONS,
        Value = State.logsFilter,
        Multi = false,
        AllowNone = false,
        SearchBarEnabled = false,
        MenuWidth = 240,
        Callback = function(selectedValue)
            local value = selectedValue

            if type(selectedValue) == "table" then
                value = selectedValue.Title
                    or selectedValue.Value
                    or selectedValue.Name
                    or selectedValue[1]

                if value == nil then
                    for candidate, enabled in pairs(selectedValue) do
                        if enabled == true then
                            value = candidate
                            break
                        end
                    end
                end
            end

            LogRuntime.setFilter(value)
        end,
    })

    State.logsParagraph = LogsTab:Paragraph({
        Title = "Important Activity",
        Desc = "No important activity yet.",
        Image = "list",
        ImageSize = 19,
        Size = "Small",
    })

    LogsTab:Button({
        Title = "Refresh Logs",
        Desc = "Refresh the current log view.",
        Icon = "refresh-cw",
        Callback = function()
            LogRuntime.updateUI()
        end,
    })

    LogsTab:Button({
        Title = "Clear Logs",
        Desc = "Clear important activity from this session.",
        Icon = "trash-2",
        Callback = function()
            LogRuntime.clear()
            LogRuntime.append("Hub", "Session logs cleared.", "info", true)
        end,
    })

    local SettingsTab = Window:Tab({
        Title = "Settings",
        Icon = "settings",
        IconSize = 16,
    })

    SettingsTab:Paragraph({
        Title = "About",
        Desc = table.concat({
            "Spin A Soccer Card Hub",
            "Current keybind: " .. tostring(State.windowKeybind),
            "Your toggles and purchase lists can be saved automatically.",
            "Session reward logs reset when the script restarts.",
        }, "\n"),
        Image = "info",
        ImageSize = 19,
        Size = "Small",
    })

    SettingsTab:Space()

    State.windowKeybindControl = SettingsTab:Keybind({
        Title = "Window Keybind",
        Desc = "Click, then press the key used to show or hide the hub.",
        Value = State.windowKeybind,
        Callback = function(keyName)
            local normalized = applyWindowKeybind(keyName, false)

            ConfigRuntime.updateStatus(
                "Window keybind changed to " .. normalized .. "."
            )
        end,
    })

    -- Apply the captured value as soon as WindUI finishes key selection.
    task.spawn(function()
        local observed = State.windowKeybind

        while State.running
            and State.windowKeybindControl
            and State.window == Window
        do
            local current = normalizeWindowKeybind(
                State.windowKeybindControl.Value
            )

            if current ~= observed then
                observed = applyWindowKeybind(current, false)

                ConfigRuntime.updateStatus(
                    "Window keybind changed to " .. observed .. "."
                )
            end

            task.wait(0.1)
        end
    end)

    State.antiAfkStatusParagraph = SettingsTab:Paragraph({
        Title = "Anti AFK",
        Desc = "Loading...",
        Image = "shield-check",
        ImageSize = 19,
        Size = "Small",
    })

    State.antiAfkToggle = SettingsTab:Toggle({
        Title = "Anti AFK",
        Desc = "Keep your session active automatically.",
        Icon = "shield-check",
        Value = State.antiAfk,
        Callback = AntiAfkRuntime.setEnabled,
    })

    SettingsTab:Button({
        Title = "Test Anti AFK",
        Desc = "Run a quick keep-alive test.",
        Icon = "mouse-pointer-click",
        Callback = function()
            local success, result =
                AntiAfkRuntime.pulse("manual", true)

            notify(
                "Anti AFK",
                success
                    and ("Pulse berhasil: " .. tostring(result))
                    or tostring(result),
                success and "shield-check" or "triangle-alert"
            )
        end,
    })

    SettingsTab:Button({
        Title = "Rejoin Server",
        Desc = "Reconnect to the current server.",
        Icon = "rotate-cw",
        Callback = function()
            local success, message = ServerRuntime.rejoin()

            if success then
                notify(
                    "Rejoin",
                    "Rejoining current server...",
                    "rotate-cw"
                )
            else
                notify(
                    "Rejoin",
                    tostring(message),
                    "triangle-alert"
                )
            end
        end,
    })

    SettingsTab:Space()

    State.configStatusParagraph = SettingsTab:Paragraph({
        Title = "Config Status",
        Desc = "Loading...",
        Image = "database",
        ImageSize = 19,
        Size = "Small",
    })

    State.autoSaveToggle = SettingsTab:Toggle({
        Title = "Auto Save",
        Desc = "Save changes automatically.",
        Icon = "save",
        Value = State.autoSave,
        Callback = function(enabled)
            local value = ConfigRuntime.setAutoSave(enabled)
            ConfigRuntime.updateStatus(
                value
                    and "Auto Save diaktifkan."
                    or "Auto Save dinonaktifkan."
            )
        end,
    })

    State.autoLoadToggle = SettingsTab:Toggle({
        Title = "Auto Load",
        Desc = "Load saved settings on startup.",
        Icon = "folder-down",
        Value = State.autoLoad,
        Callback = function(enabled)
            local value = ConfigRuntime.setAutoLoad(enabled)
            ConfigRuntime.updateStatus(
                value
                    and "Auto Load diaktifkan."
                    or "Auto Load dinonaktifkan."
            )
        end,
    })

    SettingsTab:Button({
        Title = "Save Config",
        Desc = "Save all current settings.",
        Icon = "save",
        Callback = function()
            local success, errorMessage = ConfigRuntime.save()

            notify(
                "Configuration",
                success
                    and "Config berhasil disimpan."
                    or tostring(errorMessage),
                success and "save" or "triangle-alert"
            )
        end,
    })

    SettingsTab:Button({
        Title = "Load Config",
        Desc = "Load your saved settings.",
        Icon = "folder-down",
        Callback = function()
            local success, errorMessage = ConfigRuntime.load()

            notify(
                "Configuration",
                success
                    and "Config berhasil dimuat."
                    or tostring(errorMessage),
                success and "folder-down" or "triangle-alert"
            )
        end,
    })

    SettingsTab:Button({
        Title = "Stop Script",
        Desc = "Stop every automation and close the hub.",
        Icon = "square",
        Callback = function()
            local hub = Environment.SpinASoccerCardHub
            if type(hub) == "table" and type(hub.Stop) == "function" then
                hub.Stop()
            end
        end,
    })

    updateStatus("Choose trophies from the Craft List.")
    updateSeashellStatus("Ready.")
    updateSpinWheelStatus("Ready.")
    updateSpinWheelLogUI()
    WishRuntime.updateStatus("Ready.")
    WishRuntime.updateLogUI()
    IndexRuntime.updateStatus("Ready.")
    DailyRewardRuntime.updateUI("Checking reward status.")
    CodesRuntime.updateUI("Ready.")
    updateGemShopStatus("Choose items from the Purchase List.")
    updateSummerQuestStatus("Ready.")
    updateSummerShopStatus("Choose items from the Purchase List.")
    refreshTournamentShopOptions(true)
    updateTournamentShopStatus("Choose rewards from the Reward List.")
    AntiAfkRuntime.updateStatus(
        State.antiAfk
            and "Anti AFK dimuat dari config."
            or "Anti AFK belum aktif."
    )
    ConfigRuntime.updateStatus(
        State.configStartupLoaded
            and "Auto Load: config berhasil diterapkan."
            or State.configStartupError
            or "Config siap."
    )
    HomeRuntime.update()
    LogRuntime.append("Hub", "Hub ready.", "info", true)
    LogRuntime.updateUI()

    local function selectHomeTab()
        if type(HomeTab.Select) == "function" then
            return pcall(function()
                HomeTab:Select()
            end)
        end

        if type(Window.SelectTab) == "function" then
            return pcall(function()
                Window:SelectTab(HomeTab.Index or 1)
            end)
        end

        return false
    end

    -- Select once immediately and once after UI tasks settle.
    selectHomeTab()

    task.defer(function()
        pcall(fetchSpinWheelData, true)
        task.wait()
        selectHomeTab()
    end)

    WindUI:Notify({
        Title = "Spin A Soccer Card Hub",
        Content = "Ready • Keybind: " .. tostring(State.windowKeybind),
        Icon = "layout-dashboard",
        Duration = 4,
    })
end

local Hub = {
    Trophies = {},
    Seashells = {},
    SpinWheel = {},
    Wish = {},
    DailyRewards = {},
    Codes = {},
    Index = {},
    GemShop = {},
    SummerQuests = {},
    SummerShop = {},
    TournamentShop = {},
    Logs = {},
    Utilities = {},
    Config = {},
}

-- Trophies module ------------------------------------------------------------

function Hub.Trophies.SetAutoCraft(enabled)
    local value = setAutoCraft(enabled)

    if State.autoCraftToggle and type(State.autoCraftToggle.Set) == "function" then
        pcall(function()
            State.autoCraftToggle:Set(value)
        end)
    end

    return value
end

function Hub.Trophies.ToggleAutoCraft()
    return Hub.Trophies.SetAutoCraft(not State.autoCraft)
end

function Hub.Trophies.SetEnabled(trophyName, enabled)
    trophyName = tostring(trophyName)

    if not TrophyConfig.Trophies[trophyName] then
        return false, "Trophy tidak dikenal"
    end

    State.whitelist[trophyName] = enabled == true
    syncWhitelistDropdown()
    updateStatus("Whitelist diperbarui.")

    return true
end

function Hub.Trophies.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist harus berupa table"
    end

    table.clear(State.whitelist)

    for _, trophyName in ipairs(TROPHY_ORDER) do
        State.whitelist[trophyName] = whitelist[trophyName] == true
    end

    syncWhitelistDropdown()
    updateStatus("Whitelist diperbarui.")

    return true
end

function Hub.Trophies.GetWhitelist()
    local result = {}

    for _, trophyName in ipairs(TROPHY_ORDER) do
        result[trophyName] = State.whitelist[trophyName] == true
    end

    return result
end

function Hub.Trophies.SelectAll()
    setAllTrophies(true)
end

function Hub.Trophies.ClearAll()
    setAllTrophies(false)
end

function Hub.Trophies.CraftNow()
    return craftNextWhitelisted()
end

-- Seashells module -----------------------------------------------------------

function Hub.Seashells.SetAutoClaim(enabled)
    local value = setAutoClaimSeashell(enabled)

    if State.autoClaimSeashellToggle
        and type(State.autoClaimSeashellToggle.Set) == "function"
    then
        pcall(function()
            State.autoClaimSeashellToggle:Set(value)
        end)
    end

    return value
end

function Hub.Seashells.ToggleAutoClaim()
    return Hub.Seashells.SetAutoClaim(not State.autoClaimSeashell)
end

function Hub.Seashells.ClaimNow()
    return claimAllSeashells(true)
end

function Hub.Seashells.GetState()
    return {
        enabled = State.autoClaimSeashell,
        available = State.seashellFound,
        requestsSent = State.seashellTriggered,
        lastIndex = State.lastSeashell,
        status = State.lastSeashellStatus,
    }
end


-- Spin Wheel module ----------------------------------------------------------

function Hub.SpinWheel.SetAutoClaim(enabled)
    local value = setAutoClaimSpinWheel(enabled)

    if State.autoClaimSpinWheelToggle
        and type(State.autoClaimSpinWheelToggle.Set) == "function"
    then
        pcall(function()
            State.autoClaimSpinWheelToggle:Set(value)
        end)
    end

    return value
end

function Hub.SpinWheel.ToggleAutoClaim()
    return Hub.SpinWheel.SetAutoClaim(not State.autoClaimSpinWheel)
end

function Hub.SpinWheel.SetAutoSpin(enabled)
    local value = setAutoSpinWheel(enabled)

    if State.autoSpinWheelToggle
        and type(State.autoSpinWheelToggle.Set) == "function"
    then
        pcall(function()
            State.autoSpinWheelToggle:Set(value)
        end)
    end

    return value
end

function Hub.SpinWheel.ToggleAutoSpin()
    return Hub.SpinWheel.SetAutoSpin(not State.autoSpinWheel)
end

function Hub.SpinWheel.ClaimNow()
    return claimFreeSpin(true)
end

function Hub.SpinWheel.SpinNow()
    return spinWheelNow(true)
end

function Hub.SpinWheel.Refresh()
    return fetchSpinWheelData(true)
end

function Hub.SpinWheel.ClearLog()
    clearSpinWheelLog()
end

function Hub.SpinWheel.GetLog()
    local result = {}

    for index, entry in ipairs(State.spinWheelLog) do
        result[index] = {
            id = entry.id,
            timestamp = entry.timestamp,
            time = entry.time,
            type = entry.type,
            display = entry.display,
            value = entry.value,
            slot = entry.slot,
        }
    end

    return result
end

function Hub.SpinWheel.GetState()
    return {
        autoClaim = State.autoClaimSpinWheel,
        autoSpin = State.autoSpinWheel,
        pending = State.spinWheelPending,
        data = copySpinWheelData(State.spinWheelData),
        claimRequests = State.spinWheelClaimRequests,
        spinRequests = State.spinWheelSpinRequests,
        results = State.spinWheelResults,
        failures = State.spinWheelFailures,
        lastReward = State.spinWheelLastReward,
        status = State.spinWheelLastStatus,
        sessionStartedAt = State.spinWheelSessionStartedAt,
    }
end



-- Wish module ----------------------------------------------------------------

function Hub.Wish.SetAutoSpin(enabled)
    local value = WishRuntime.setAutoSpin(enabled)

    if State.autoSpinWishToggle
        and type(State.autoSpinWishToggle.Set) == "function"
    then
        pcall(function()
            State.autoSpinWishToggle:Set(value)
        end)
    end

    return value
end

function Hub.Wish.ToggleAutoSpin()
    return Hub.Wish.SetAutoSpin(not State.autoSpinWishTickets)
end

function Hub.Wish.SetSkipAnimation(enabled)
    local value = WishRuntime.setSkipAnimation(enabled)

    if State.skipWishAnimationToggle
        and type(State.skipWishAnimationToggle.Set) == "function"
    then
        pcall(function()
            State.skipWishAnimationToggle:Set(value)
        end)
    end

    return value
end

function Hub.Wish.ToggleSkipAnimation()
    return Hub.Wish.SetSkipAnimation(not State.skipWishAnimation)
end

function Hub.Wish.WishNow()
    return WishRuntime.perform(true)
end

function Hub.Wish.ClearLog()
    WishRuntime.clearLog()
end

function Hub.Wish.GetLog()
    local result = {}

    for index, entry in ipairs(State.wishLog) do
        result[index] = {
            id = entry.id,
            timestamp = entry.timestamp,
            time = entry.time,
            type = entry.type,
            outcome = entry.outcome,
            cardId = entry.cardId,
            display = entry.display,
        }
    end

    return result
end

function Hub.Wish.GetState()
    local data = WishRuntime.getData()

    return {
        autoSpin = State.autoSpinWishTickets,
        skipAnimation = State.skipWishAnimation,
        tickets = data.tickets,
        rebirth = data.rebirth,
        minRebirth = data.minRebirth,
        pending = State.wishPending,
        animationBusy = State.wishAnimationBusy,
        requests = State.wishRequests,
        results = State.wishResults,
        failures = State.wishFailures,
        lastReward = State.wishLastReward,
        status = State.wishLastStatus,
        sessionStartedAt = State.wishSessionStartedAt,
    }
end




-- Daily Rewards module -------------------------------------------------------

function Hub.DailyRewards.SetAutoClaim(enabled)
    local value = DailyRewardRuntime.setAutoClaim(enabled)

    if State.autoClaimDailyRewardsToggle
        and type(State.autoClaimDailyRewardsToggle.Set) == "function"
    then
        pcall(function()
            State.autoClaimDailyRewardsToggle:Set(value)
        end)
    end

    return value
end

function Hub.DailyRewards.ToggleAutoClaim()
    return Hub.DailyRewards.SetAutoClaim(
        not State.autoClaimDailyRewards
    )
end

function Hub.DailyRewards.ClaimNow()
    return DailyRewardRuntime.claim(true)
end

function Hub.DailyRewards.Refresh()
    State.dailyRewardNextStateAt = 0
    return DailyRewardRuntime.requestState(true)
end

function Hub.DailyRewards.GetState()
    local rewardState = DailyRewardRuntime.getCachedState()
    local playerState = DailyRewardRuntime.getPlayerState()

    return {
        autoClaim = State.autoClaimDailyRewards,
        status = DailyRewardRuntime.getStatusLabel(),
        completed = playerState.completed
            or (rewardState and rewardState.completed == true)
            or false,
        rebirth = playerState.rebirth,
        phase = tonumber(rewardState and rewardState.phase) or 0,
        currentDay =
            tonumber(rewardState and rewardState.currentDay) or 0,
        canClaim =
            rewardState and rewardState.canClaim == true or false,
        nextClaimTime =
            tonumber(rewardState and rewardState.nextClaimTime) or 0,
        pending = State.dailyRewardPending,
        stateRequests = State.dailyRewardStateRequests,
        claimRequests = State.dailyRewardClaimRequests,
        claims = State.dailyRewardClaims,
        failures = State.dailyRewardFailures,
        lastStatus = State.dailyRewardLastStatus,
    }
end



-- Codes module ---------------------------------------------------------------

function Hub.Codes.SetAutoRedeem(enabled)
    local value = CodesRuntime.setAutoRedeem(enabled)

    if State.autoRedeemCodesToggle
        and type(State.autoRedeemCodesToggle.Set) == "function"
    then
        pcall(function()
            State.autoRedeemCodesToggle:Set(value)
        end)
    end

    return value
end

function Hub.Codes.ToggleAutoRedeem()
    return Hub.Codes.SetAutoRedeem(not State.autoRedeemCodes)
end

function Hub.Codes.RedeemAvailable()
    return CodesRuntime.redeemAll()
end

function Hub.Codes.Redeem(code)
    return CodesRuntime.redeem(code, true)
end

function Hub.Codes.ClearHistory()
    CodesRuntime.clearHistory()
end

function Hub.Codes.GetList()
    return CodesRuntime.getCodes()
end

function Hub.Codes.GetPending()
    return CodesRuntime.getPendingCodes()
end

function Hub.Codes.GetState()
    local codes = CodesRuntime.getCodes()
    local pending = CodesRuntime.getPendingCodes()

    return {
        autoRedeem = State.autoRedeemCodes,
        total = #codes,
        pending = #pending,
        attempted = #codes - #pending,
        groupMember = State.codeGroupMember,
        requests = State.codeRequests,
        skipped = State.codeSkipped,
        failures = State.codeFailures,
        lastCode = State.codeLastCode,
        status = State.codeLastStatus,
    }
end


-- Index module ---------------------------------------------------------------

function Hub.Index.SetAutoClaim(enabled)
    local value = IndexRuntime.setAutoClaim(enabled)

    if State.autoClaimIndexToggle
        and type(State.autoClaimIndexToggle.Set) == "function"
    then
        pcall(function()
            State.autoClaimIndexToggle:Set(value)
        end)
    end

    return value
end

function Hub.Index.ToggleAutoClaim()
    return Hub.Index.SetAutoClaim(not State.autoClaimIndex)
end

function Hub.Index.ClaimNow()
    return IndexRuntime.claimAll(true)
end

function Hub.Index.GetState()
    local stats = IndexRuntime.getStats()

    return {
        autoClaim = State.autoClaimIndex,
        claimable = stats.total,
        basic = stats.basic,
        mutations = stats.mutations,
        requests = State.indexRequests,
        failures = State.indexFailures,
        status = State.indexLastStatus,
    }
end


-- Gem Shop module ------------------------------------------------------------

function Hub.GemShop.SetAutoBuy(enabled)
    local value = setAutoBuyGemShop(enabled)

    if State.autoBuyGemShopToggle
        and type(State.autoBuyGemShopToggle.Set) == "function"
    then
        pcall(function()
            State.autoBuyGemShopToggle:Set(value)
        end)
    end

    return value
end

function Hub.GemShop.ToggleAutoBuy()
    return Hub.GemShop.SetAutoBuy(not State.autoBuyGemShop)
end

function Hub.GemShop.SetItemEnabled(itemKeyOrLabel, enabled)
    local key = gemShopKeyFromSelection(itemKeyOrLabel)

    if not key then
        return false, "Item Gem Shop tidak dikenal"
    end

    State.gemShopWhitelist[key] = enabled == true
    State.gemShopNextBuyAt = 0
    syncGemShopWhitelistDropdown()
    updateGemShopStatus("Whitelist Gem Shop diperbarui.")

    return true
end

function Hub.GemShop.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist harus berupa table"
    end

    table.clear(State.gemShopWhitelist)

    for _, key in ipairs(GemShopOptionKeys) do
        local label = gemShopLabelFromKey(key)
        State.gemShopWhitelist[key] =
            whitelist[key] == true or whitelist[label] == true
    end

    State.gemShopNextBuyAt = 0
    syncGemShopWhitelistDropdown()
    updateGemShopStatus("Whitelist Gem Shop diperbarui.")

    return true
end

function Hub.GemShop.GetWhitelist()
    local result = {}

    for _, key in ipairs(GemShopOptionKeys) do
        result[key] = State.gemShopWhitelist[key] == true
    end

    return result
end

function Hub.GemShop.GetOptions()
    local result = {}

    for index, key in ipairs(GemShopOptionKeys) do
        result[index] = {
            key = key,
            label = GemShopOptionLabels[index],
        }
    end

    return result
end

function Hub.GemShop.SelectAll()
    setAllGemShopItems(true)
    updateGemShopStatus()
end

function Hub.GemShop.ClearAll()
    setAllGemShopItems(false)
    updateGemShopStatus()
end

function Hub.GemShop.BuyNow()
    return buyNextGemShopItem(true)
end

function Hub.GemShop.Refresh()
    updateGemShopStatus("Gem Shop berhasil di-refresh.")
    return true
end

function Hub.GemShop.GetState()
    local shopState = getGemShopStateData()
    local luckyName, luckyPrice, luckyGamepassId = getLuckyItemDisplay(shopState)

    return {
        autoBuy = State.autoBuyGemShop,
        gems = getCurrentGems(),
        whitelist = Hub.GemShop.GetWhitelist(),
        requests = State.gemShopRequests,
        failures = State.gemShopFailures,
        lastItem = State.gemShopLastItem,
        status = State.gemShopLastStatus,
        luckyItem = {
            name = luckyName,
            price = luckyPrice,
            gamepassId = luckyGamepassId,
        },
        scarletStock = getScarletStock(),
    }
end


-- Summer Quests module -------------------------------------------------------

function Hub.SummerQuests.SetAutoClaim(enabled)
    local value = setAutoClaimSummerQuests(enabled)

    if State.autoClaimSummerQuestsToggle
        and type(State.autoClaimSummerQuestsToggle.Set) == "function"
    then
        pcall(function()
            State.autoClaimSummerQuestsToggle:Set(value)
        end)
    end

    return value
end

function Hub.SummerQuests.ToggleAutoClaim()
    return Hub.SummerQuests.SetAutoClaim(
        not State.autoClaimSummerQuests
    )
end

function Hub.SummerQuests.ClaimNow()
    return claimSummerQuests(true)
end

function Hub.SummerQuests.GetState()
    local stats = getSummerQuestStats()

    return {
        autoClaim = State.autoClaimSummerQuests,
        total = stats.total,
        claimable = stats.claimable,
        claimed = stats.claimed,
        seashells = stats.seashells,
        claimRequests = State.summerQuestClaimRequests,
        failures = State.summerQuestFailures,
        lastQuest = State.summerQuestLastClaim,
        status = State.summerQuestLastStatus,
    }
end

-- Summer Shop module ---------------------------------------------------------

function Hub.SummerShop.SetAutoBuy(enabled)
    local value = setAutoBuySummerShop(enabled)

    if State.autoBuySummerShopToggle
        and type(State.autoBuySummerShopToggle.Set) == "function"
    then
        pcall(function()
            State.autoBuySummerShopToggle:Set(value)
        end)
    end

    return value
end

function Hub.SummerShop.ToggleAutoBuy()
    return Hub.SummerShop.SetAutoBuy(not State.autoBuySummerShop)
end

function Hub.SummerShop.SetItemEnabled(itemId, enabled)
    itemId = tostring(itemId)

    if not SummerShopConfigById[itemId] then
        return false, "Item Summer Shop tidak dikenal"
    end

    State.summerShopWhitelist[itemId] = enabled == true
    syncSummerShopWhitelistDropdown()
    updateSummerShopStatus("Whitelist Summer Shop diperbarui.")

    return true
end

function Hub.SummerShop.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist harus berupa table"
    end

    table.clear(State.summerShopWhitelist)

    for _, id in ipairs(SummerShopOptionIds) do
        State.summerShopWhitelist[id] = whitelist[id] == true
    end

    syncSummerShopWhitelistDropdown()
    updateSummerShopStatus("Whitelist Summer Shop diperbarui.")

    return true
end

function Hub.SummerShop.GetWhitelist()
    local result = {}

    for _, id in ipairs(SummerShopOptionIds) do
        result[id] = State.summerShopWhitelist[id] == true
    end

    return result
end

function Hub.SummerShop.GetOptions()
    local result = {}

    for index, id in ipairs(SummerShopOptionIds) do
        local item = SummerShopConfigById[id]

        result[index] = {
            id = id,
            label = SummerShopOptionLabels[index],
            displayName = item and item.displayName or id,
            seashellPrice = tonumber(item and item.seashellPrice) or 0,
            oneTime = item and item.OneTime == true,
            noStock = item and item.NoStock == true,
            noBuyButton = item and item.NoBuyButton == true,
        }
    end

    return result
end

function Hub.SummerShop.SelectAll()
    setAllSummerShopItems(true)
end

function Hub.SummerShop.ClearAll()
    setAllSummerShopItems(false)
end

function Hub.SummerShop.BuyNow()
    return buyNextSummerShopItem(true)
end

function Hub.SummerShop.Refresh()
    buildSummerShopOptions()
    syncSummerShopWhitelistDropdown()
    updateSummerShopStatus("Summer Shop berhasil di-refresh.")
    return true
end

function Hub.SummerShop.GetState()
    local playerData = getPlayerData()

    return {
        autoBuy = State.autoBuySummerShop,
        seashells =
            math.max(
                0,
                math.floor(tonumber(playerData and playerData.seashells) or 0)
            ),
        whitelist = Hub.SummerShop.GetWhitelist(),
        requests = State.summerShopBuyRequests,
        failures = State.summerShopFailures,
        lastItem = State.summerShopLastItem,
        status = State.summerShopLastStatus,
    }
end


-- Tournament Shop module -----------------------------------------------------

function Hub.TournamentShop.SetAutoBuy(enabled)
    local value = setAutoBuyTournamentShop(enabled)

    if State.autoBuyTournamentShopToggle
        and type(State.autoBuyTournamentShopToggle.Set) == "function"
    then
        pcall(function()
            State.autoBuyTournamentShopToggle:Set(value)
        end)
    end

    return value
end

function Hub.TournamentShop.ToggleAutoBuy()
    return Hub.TournamentShop.SetAutoBuy(
        not State.autoBuyTournamentShop
    )
end

function Hub.TournamentShop.SetItemEnabled(id, enabled)
    id = tournamentConfigIdFromSavedKey(id)

    if not id or not TournamentShopConfigById[id] then
        return false, "Reward tidak tersedia"
    end

    State.tournamentShopWhitelist[id] = enabled == true
    syncTournamentShopWhitelistDropdown()
    updateTournamentShopStatus(
        "Reward List diperbarui."
    )

    return true
end

function Hub.TournamentShop.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist harus berupa table"
    end

    table.clear(State.tournamentShopWhitelist)

    for key, enabled in pairs(whitelist) do
        if enabled == true then
            local id = tournamentConfigIdFromSavedKey(key)
            if id then
                State.tournamentShopWhitelist[id] = true
            end
        end
    end

    syncTournamentShopWhitelistDropdown()
    updateTournamentShopStatus(
        "Reward List diperbarui."
    )

    return true
end

function Hub.TournamentShop.GetWhitelist()
    local result = {}

    for _, id in ipairs(TournamentShopOptionKeys) do
        result[id] = State.tournamentShopWhitelist[id] == true
    end

    return result
end

function Hub.TournamentShop.GetOptions()
    refreshTournamentShopOptions(false)
    local result = {}

    for index, id in ipairs(TournamentShopOptionKeys) do
        local config = TournamentShopConfigById[id]
        local current = TournamentShopEntryByKey[id]

        result[index] = {
            id = id,
            key = id,
            label = TournamentShopOptionLabels[index],
            displayName = tournamentConfigDisplayName(config),
            kind = tostring(config and config.kind or "unknown"),
            weight = tonumber(config and config.weight) or 0,
            minPrice = tonumber(config and config.minPrice) or 0,
            maxPrice = tonumber(config and config.maxPrice) or 0,
            minStock = tonumber(config and config.minStock) or 0,
            maxStock = tonumber(config and config.maxStock) or 0,

            available = current ~= nil,
            currentIndex = current and current.index or nil,
            currentDisplayName =
                current and current.displayName or nil,
            currentPrice = current and current.price or nil,
            currentStock = current and current.stock or nil,
            currentMaxStock = current and current.maxStock or nil,
        }
    end

    return result
end

function Hub.TournamentShop.GetCurrentRewards()
    refreshTournamentShopOptions(false)
    local result = {}

    for index, entry in ipairs(TournamentShopCurrentEntries) do
        result[index] = {
            configId = entry.configId,
            index = entry.index,
            displayName = entry.displayName,
            kind = entry.kind,
            price = entry.price,
            stock = entry.stock,
            maxStock = entry.maxStock,
        }
    end

    return result
end

function Hub.TournamentShop.SelectAll()
    setAllTournamentShopItems(true)
end

function Hub.TournamentShop.ClearAll()
    setAllTournamentShopItems(false)
end

function Hub.TournamentShop.BuyNow()
    return buyNextTournamentShopItem(true)
end

function Hub.TournamentShop.Refresh()
    refreshTournamentShopOptions(true)
    updateTournamentShopStatus(
        "Tournament Shop berhasil di-refresh."
    )
    return true
end

function Hub.TournamentShop.GetState()
    local shopData = refreshTournamentShopOptions(false)

    return {
        autoBuy = State.autoBuyTournamentShop,
        tokens = shopData.tokens,
        pending = State.tournamentShopPending,
        pendingIndex = State.tournamentShopPendingIndex,
        pendingConfigId = State.tournamentShopPendingKey,
        whitelist = Hub.TournamentShop.GetWhitelist(),
        options = #TournamentShopOptionKeys,
        currentRewards = #TournamentShopCurrentEntries,
        requests = State.tournamentShopBuyRequests,
        purchases = State.tournamentShopPurchases,
        failures = State.tournamentShopFailures,
        lastItem = State.tournamentShopLastItem,
        status = State.tournamentShopLastStatus,
    }
end




-- Logs module ----------------------------------------------------------------

function Hub.Logs.Get()
    local result = {}

    for index, entry in ipairs(State.logs) do
        result[index] = {
            id = entry.id,
            timestamp = entry.timestamp,
            time = entry.time,
            category = entry.category,
            level = entry.level,
            message = entry.message,
        }
    end

    return result
end

function Hub.Logs.Clear()
    LogRuntime.clear()
end

function Hub.Logs.Add(category, message, level)
    return LogRuntime.append(category, message, level, true)
end

function Hub.Logs.SetFilter(value)
    return LogRuntime.setFilter(value)
end

function Hub.Logs.GetState()
    return {
        count = #State.logs,
        suppressed = State.logsSuppressed,
        filter = State.logsFilter,
        limit = State.logsLimit,
        displayLimit = State.logsDisplayLimit,
        dedupeSeconds = State.logsDedupeSeconds,
    }
end


-- Utilities module -----------------------------------------------------------

function Hub.Utilities.SetAntiAfk(enabled)
    local value = AntiAfkRuntime.setEnabled(enabled)

    if State.antiAfkToggle
        and type(State.antiAfkToggle.Set) == "function"
    then
        pcall(function()
            State.antiAfkToggle:Set(value)
        end)
    end

    return value
end

function Hub.Utilities.ToggleAntiAfk()
    return Hub.Utilities.SetAntiAfk(not State.antiAfk)
end

function Hub.Utilities.PulseAntiAfk()
    return AntiAfkRuntime.pulse("api", true)
end

function Hub.Utilities.GetAntiAfkState()
    return {
        enabled = State.antiAfk,
        interval = State.antiAfkInterval,
        busy = State.antiAfkBusy,
        pulses = State.antiAfkCount,
        lastPulseAt = State.lastAntiAfkAt,
        method = State.antiAfkMethod,
        error = State.lastAntiAfkError,
        status = State.antiAfkLastStatus,
    }
end

function Hub.Utilities.Rejoin()
    return ServerRuntime.rejoin()
end

function Hub.Utilities.GetServerState()
    return ServerRuntime.getState()
end


-- Configuration module -------------------------------------------------------

function Hub.Config.Save()
    return ConfigRuntime.save()
end

function Hub.Config.Load()
    return ConfigRuntime.load()
end

function Hub.Config.SetAutoSave(enabled)
    local value = ConfigRuntime.setAutoSave(enabled)

    if State.autoSaveToggle and type(State.autoSaveToggle.Set) == "function" then
        pcall(function()
            State.autoSaveToggle:Set(value)
        end)
    end

    return value
end

function Hub.Config.ToggleAutoSave()
    return Hub.Config.SetAutoSave(not State.autoSave)
end

function Hub.Config.SetAutoLoad(enabled)
    local value = ConfigRuntime.setAutoLoad(enabled)

    if State.autoLoadToggle and type(State.autoLoadToggle.Set) == "function" then
        pcall(function()
            State.autoLoadToggle:Set(value)
        end)
    end

    return value
end

function Hub.Config.ToggleAutoLoad()
    return Hub.Config.SetAutoLoad(not State.autoLoad)
end

function Hub.Config.SetKeybind(value)
    local keyName = applyWindowKeybind(value, true)

    ConfigRuntime.updateStatus(
        "Window keybind changed to " .. keyName .. "."
    )

    return keyName
end

function Hub.Config.GetKeybind()
    return State.windowKeybind
end


function Hub.Config.GetState()
    return {
        supported = State.configSupported,
        path = ConfigRuntime.file,
        exists = ConfigRuntime.fileExists(),
        autoSave = State.autoSave,
        autoLoad = State.autoLoad,
        keybind = State.windowKeybind,
        dirty = State.configDirty,
        lastSavedAt = State.configLastSavedAt,
        startupLoaded = State.configStartupLoaded,
        startupError = State.configStartupError,
    }
end

-- General hub API ------------------------------------------------------------

function Hub.GetState()
    return {
        running = State.running,
        trophies = {
            autoCraft = State.autoCraft,
            whitelist = Hub.Trophies.GetWhitelist(),
            attempts = State.attempts,
            lastCraft = State.lastCraft,
            status = State.lastStatus,
        },
        seashells = Hub.Seashells.GetState(),
        spinWheel = Hub.SpinWheel.GetState(),
        wish = Hub.Wish.GetState(),
        dailyRewards = Hub.DailyRewards.GetState(),
        codes = Hub.Codes.GetState(),
        index = Hub.Index.GetState(),
        gemShop = Hub.GemShop.GetState(),
        summerQuests = Hub.SummerQuests.GetState(),
        summerShop = Hub.SummerShop.GetState(),
        tournamentShop = Hub.TournamentShop.GetState(),
        logs = Hub.Logs.GetState(),
        antiAfk = Hub.Utilities.GetAntiAfkState(),
        server = Hub.Utilities.GetServerState(),
        config = Hub.Config.GetState(),
    }
end

function Hub.Toggle()
    if State.window and type(State.window.Toggle) == "function" then
        pcall(function()
            State.window:Toggle()
        end)
        return true
    end

    return false
end

function Hub.Stop()
    if not State.running then
        return
    end

    if State.autoSave and State.configSupported and State.configDirty then
        pcall(ConfigRuntime.save)
    end

    State.running = false
    State.autoCraft = false
    State.autoClaimSeashell = false
    State.autoClaimSpinWheel = false
    State.autoSpinWheel = false
    State.autoSpinWishTickets = false
    State.autoClaimDailyRewards = false
    State.autoRedeemCodes = false
    State.autoClaimIndex = false
    State.antiAfk = false
    State.autoBuyGemShop = false
    State.autoClaimSummerQuests = false
    State.autoBuySummerShop = false
    State.autoBuyTournamentShop = false
    clearTournamentShopPending()

    if State.spinWheelConnection then
        pcall(function()
            State.spinWheelConnection:Disconnect()
        end)
        State.spinWheelConnection = nil
    end

    if State.tournamentShopConnection then
        pcall(function()
            State.tournamentShopConnection:Disconnect()
        end)
        State.tournamentShopConnection = nil
    end

    if State.dailyRewardConnection then
        pcall(function()
            State.dailyRewardConnection:Disconnect()
        end)
        State.dailyRewardConnection = nil
    end

    if State.antiAfkIdledConnection then
        pcall(function()
            State.antiAfkIdledConnection:Disconnect()
        end)
        State.antiAfkIdledConnection = nil
    end

    if State.window and type(State.window.Destroy) == "function" then
        pcall(function()
            State.window:Destroy()
        end)
    end

    if Environment.SpinASoccerCardHub == Hub then
        Environment.SpinASoccerCardHub = nil
    end
end

-- API ringkas untuk penggunaan melalui console.
Hub.SetAutoCraft = Hub.Trophies.SetAutoCraft
Hub.ToggleAutoCraft = Hub.Trophies.ToggleAutoCraft
Hub.SetTrophyEnabled = Hub.Trophies.SetEnabled
Hub.SetTrophyWhitelist = Hub.Trophies.SetWhitelist
Hub.CraftTrophyNow = Hub.Trophies.CraftNow

Hub.SetAutoClaimSeashell = Hub.Seashells.SetAutoClaim
Hub.ToggleAutoClaimSeashell = Hub.Seashells.ToggleAutoClaim
Hub.ClaimSeashellsNow = Hub.Seashells.ClaimNow

Hub.SetAutoClaimSpinWheel = Hub.SpinWheel.SetAutoClaim
Hub.ToggleAutoClaimSpinWheel = Hub.SpinWheel.ToggleAutoClaim
Hub.SetAutoSpinWheel = Hub.SpinWheel.SetAutoSpin
Hub.ToggleAutoSpinWheel = Hub.SpinWheel.ToggleAutoSpin
Hub.ClaimSpinWheelNow = Hub.SpinWheel.ClaimNow
Hub.SpinWheelNow = Hub.SpinWheel.SpinNow
Hub.GetSpinWheelLog = Hub.SpinWheel.GetLog
Hub.ClearSpinWheelLog = Hub.SpinWheel.ClearLog

Hub.SetAutoSpinWishTickets = Hub.Wish.SetAutoSpin
Hub.ToggleAutoSpinWishTickets = Hub.Wish.ToggleAutoSpin
Hub.SetSkipWishAnimation = Hub.Wish.SetSkipAnimation
Hub.ToggleSkipWishAnimation = Hub.Wish.ToggleSkipAnimation
Hub.WishNow = Hub.Wish.WishNow
Hub.GetWishSessionLog = Hub.Wish.GetLog
Hub.ClearWishSessionLog = Hub.Wish.ClearLog

Hub.SetAutoClaimDailyRewards = Hub.DailyRewards.SetAutoClaim
Hub.ToggleAutoClaimDailyRewards = Hub.DailyRewards.ToggleAutoClaim
Hub.ClaimDailyRewardNow = Hub.DailyRewards.ClaimNow
Hub.RefreshDailyRewards = Hub.DailyRewards.Refresh
Hub.GetDailyRewardsState = Hub.DailyRewards.GetState

Hub.SetAutoRedeemCodes = Hub.Codes.SetAutoRedeem
Hub.ToggleAutoRedeemCodes = Hub.Codes.ToggleAutoRedeem
Hub.RedeemAvailableCodes = Hub.Codes.RedeemAvailable
Hub.RedeemCode = Hub.Codes.Redeem
Hub.ClearCodeHistory = Hub.Codes.ClearHistory
Hub.GetRedeemCodes = Hub.Codes.GetList
Hub.GetPendingCodes = Hub.Codes.GetPending
Hub.GetCodesState = Hub.Codes.GetState

Hub.SetAutoClaimIndex = Hub.Index.SetAutoClaim
Hub.ToggleAutoClaimIndex = Hub.Index.ToggleAutoClaim
Hub.ClaimIndexNow = Hub.Index.ClaimNow
Hub.GetIndexState = Hub.Index.GetState

Hub.SetAutoBuyGemShop = Hub.GemShop.SetAutoBuy
Hub.ToggleAutoBuyGemShop = Hub.GemShop.ToggleAutoBuy
Hub.SetGemShopWhitelist = Hub.GemShop.SetWhitelist
Hub.BuyGemShopNow = Hub.GemShop.BuyNow

Hub.SetAutoClaimSummerQuests = Hub.SummerQuests.SetAutoClaim
Hub.ToggleAutoClaimSummerQuests = Hub.SummerQuests.ToggleAutoClaim
Hub.ClaimSummerQuestsNow = Hub.SummerQuests.ClaimNow

Hub.SetAutoBuySummerShop = Hub.SummerShop.SetAutoBuy
Hub.ToggleAutoBuySummerShop = Hub.SummerShop.ToggleAutoBuy
Hub.SetSummerShopWhitelist = Hub.SummerShop.SetWhitelist
Hub.BuySummerShopNow = Hub.SummerShop.BuyNow

Hub.SetAutoBuyTournamentShop = Hub.TournamentShop.SetAutoBuy
Hub.ToggleAutoBuyTournamentShop = Hub.TournamentShop.ToggleAutoBuy
Hub.SetTournamentShopWhitelist = Hub.TournamentShop.SetWhitelist
Hub.BuyTournamentShopNow = Hub.TournamentShop.BuyNow

Hub.GetLogs = Hub.Logs.Get
Hub.ClearLogs = Hub.Logs.Clear
Hub.AddLog = Hub.Logs.Add
Hub.SetLogsFilter = Hub.Logs.SetFilter

Hub.SetAntiAfk = Hub.Utilities.SetAntiAfk
Hub.ToggleAntiAfk = Hub.Utilities.ToggleAntiAfk
Hub.PulseAntiAfk = Hub.Utilities.PulseAntiAfk
Hub.GetAntiAfkState = Hub.Utilities.GetAntiAfkState
Hub.Rejoin = Hub.Utilities.Rejoin
Hub.GetServerState = Hub.Utilities.GetServerState

Hub.SaveConfig = Hub.Config.Save
Hub.LoadConfig = Hub.Config.Load
Hub.SetAutoSave = Hub.Config.SetAutoSave
Hub.ToggleAutoSave = Hub.Config.ToggleAutoSave
Hub.SetAutoLoad = Hub.Config.SetAutoLoad
Hub.ToggleAutoLoad = Hub.Config.ToggleAutoLoad
Hub.SetKeybind = Hub.Config.SetKeybind
Hub.GetKeybind = Hub.Config.GetKeybind
Hub.GetConfigState = Hub.Config.GetState

do
    local success, result, errorMessage = pcall(function()
        local initialized, initializeMessage = ConfigRuntime.initialize()
        return initialized, initializeMessage
    end)

    if not success then
        State.configInitialized = true
        State.configStartupError = tostring(result)
    elseif result ~= true and errorMessage then
        State.configStartupError = tostring(errorMessage)
    end
end

Environment.SpinASoccerCardHub = Hub

do
    local success, connectionOrError = pcall(function()
        return SpinWheelRemote.OnClientEvent:Connect(onSpinWheelRemote)
    end)

    if success then
        State.spinWheelConnection = connectionOrError
    else
        State.spinWheelLastStatus =
            "Gagal memasang listener spin_result: " .. tostring(connectionOrError)
    end
end

do
    local success, connectionOrError = pcall(function()
        return TournamentServer.OnClientEvent:Connect(onTournamentServerRemote)
    end)

    if success then
        State.tournamentShopConnection = connectionOrError
    else
        State.tournamentShopLastStatus =
            "Gagal memasang listener buy_result: " .. tostring(connectionOrError)
    end
end

do
    local success, connectionOrError = pcall(function()
        return DailyReward.OnClientEvent:Connect(
            DailyRewardRuntime.handleMessage
        )
    end)

    if success then
        State.dailyRewardConnection = connectionOrError
    else
        State.dailyRewardLastStatus =
            "Could not start Daily Rewards listener."
        State.dailyRewardFailures += 1
    end
end

do
    local success, connectionOrError = pcall(function()
        return LocalPlayer.Idled:Connect(function()
            State.nextAntiAfkPulseAt = 0

            task.spawn(function()
                AntiAfkRuntime.pulse("Idled", false)
            end)
        end)
    end)

    if success then
        State.antiAfkIdledConnection = connectionOrError
    else
        State.lastAntiAfkError =
            "Gagal memasang Idled listener: " .. tostring(connectionOrError)
    end
end

if State.antiAfk then
    task.defer(function()
        if State.running and State.antiAfk then
            AntiAfkRuntime.pulse("Auto Load", false)
        end
    end)
end

task.spawn(function()
    local success, errorMessage = pcall(buildGui)

    if not success then
        State.lastStatus = "GUI error: " .. tostring(errorMessage)
        warn("[SpinASoccerCardHub] " .. tostring(errorMessage))
    end
end)

task.spawn(function()
    while State.running do
        if State.autoCraft then
            pcall(craftNextWhitelisted)
        end

        task.wait(State.interval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoClaimSeashell then
            pcall(claimAllSeashells, false)
        end

        task.wait(State.seashellInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoClaimSpinWheel then
            pcall(claimFreeSpin, false)
        end

        if State.autoSpinWheel then
            pcall(spinWheelNow, false)
        elseif State.spinWheelData
            and (os.clock() - State.spinWheelLastDataAt) >= 5
        then
            pcall(fetchSpinWheelData, false)
        end

        task.wait(State.spinWheelPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoSpinWishTickets then
            pcall(WishRuntime.perform, false)
        elseif State.wishStatusParagraph then
            pcall(WishRuntime.updateStatus)
        end

        task.wait(State.wishPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        pcall(DailyRewardRuntime.tick)
        task.wait(State.dailyRewardPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoRedeemCodes
            and os.clock() >= State.codeNextRedeemAt
        then
            pcall(CodesRuntime.redeemNext, false)
        elseif State.codeStatusParagraph then
            pcall(CodesRuntime.updateUI)
        end

        task.wait(0.5)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoClaimIndex then
            pcall(IndexRuntime.claimAll, false)
        elseif State.indexStatusParagraph then
            pcall(IndexRuntime.updateStatus)
        end

        task.wait(State.indexPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoBuyGemShop then
            pcall(buyNextGemShopItem, false)
        elseif State.gemShopStatusParagraph then
            pcall(updateGemShopStatus)
        end

        task.wait(State.gemShopPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoClaimSummerQuests then
            pcall(claimSummerQuests, false)
        elseif State.summerQuestStatusParagraph then
            pcall(updateSummerQuestStatus)
        end

        task.wait(State.summerQuestPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.autoBuySummerShop then
            pcall(buyNextSummerShopItem, false)
        elseif State.summerShopStatusParagraph then
            pcall(updateSummerShopStatus)
        end

        task.wait(State.summerShopPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        pcall(refreshTournamentShopOptions, true)

        if State.autoBuyTournamentShop then
            pcall(buyNextTournamentShopItem, false)
        elseif State.tournamentShopStatusParagraph then
            pcall(updateTournamentShopStatus)
        end

        task.wait(State.tournamentShopPollInterval)
    end
end)

task.spawn(function()
    while State.running do
        if State.antiAfk
            and not State.antiAfkBusy
            and os.clock() >= State.nextAntiAfkPulseAt
        then
            State.nextAntiAfkPulseAt =
                os.clock() + (tonumber(State.antiAfkInterval) or 45)

            task.spawn(function()
                AntiAfkRuntime.pulse("periodic", false)
            end)
        elseif State.antiAfkStatusParagraph then
            pcall(AntiAfkRuntime.updateStatus)
        end

        task.wait(1)
    end
end)

task.spawn(function()
    while State.running do
        if State.homeStatusParagraph then
            pcall(HomeRuntime.update)
        end

        task.wait(1)
    end
end)

task.spawn(function()
    while State.running do
        if State.configInitialized and not State.configLoading then
            local fingerprint = ConfigRuntime.fingerprint()

            if fingerprint
                and State.configLastObservedFingerprint
                and fingerprint ~= State.configLastObservedFingerprint
            then
                State.configLastObservedFingerprint = fingerprint
                ConfigRuntime.requestSave()
            elseif fingerprint
                and State.configLastObservedFingerprint == nil
            then
                State.configLastObservedFingerprint = fingerprint
            end
        end

        task.wait(0.5)
    end
end)

return Hub
