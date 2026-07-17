local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Environment = if type(getgenv) == "function" then getgenv() else _G
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
local function buildModules(root, definitions)
    local result = {}
    for name, path in pairs(definitions) do
        result[name] = requirePath(root, table.unpack(path))
    end
    return result
end
local function buildRemotes(networker, definitions)
    local result = {}
    for name, definition in pairs(definitions) do
        definition = definition or {}
        local getter = definition.isFunction
            and networker.get_remotefunction
            or networker.get_remote
        result[name] = getter(definition.key or name)
    end
    return result
end
local ModuleDefinitions = {
    charm = {"Packages", "charm"},
    PlayerStore = {"Source", "Shared", "State", "PlayerStore"},
    TrophyConfig = {"Source", "Shared", "Configs", "TrophyConfig"},
    CardConfig = {"Source", "Shared", "Configs", "CardConfig"},
    PackConfig = {"Source", "Shared", "Configs", "PackConfig"},
    RebirthConfig = {"Source", "Shared", "Configs", "RebirthConfig"},
    Networker = {"Source", "Shared", "Networker"},
    GemShopState = {"Source", "Shared", "State", "GemShopState"},
    GemShopConfig = {"Source", "Shared", "Configs", "GemShopConfig"},
    ProductConfig = {"Source", "Shared", "Configs", "ProductConfig"},
    SummerQuestConfig = {"Source", "Shared", "Configs", "SummerQuestConfig"},
    SummerShopConfig = {"Source", "Shared", "Configs", "SummerShopConfig"},
    TournamentConfig = {"Source", "Shared", "Configs", "TournamentConfig"},
    ScalingIncome = {"Source", "Shared", "Helpers", "ScalingIncome"},
    TournamentClock = {"Source", "Shared", "Helpers", "TournamentClock"},
    GachaConfig = {"Source", "Shared", "Configs", "GachaConfig"},
    AnimationController = {"Source", "Client", "UI", "Gacha", "AnimationController"},
    PurchaseClient = {"Source", "Client", "Controllers", "PurchaseClient"},
    SlotController = {"Source", "Client", "Controllers", "SlotController"},
    PackAnimationController = {"Source", "Client", "UI", "PackAnimationController"},
    UIService = {"Source", "Client", "UI", "UIService"},
}
local Modules = buildModules(ReplicatedStorage, ModuleDefinitions)
local RemoteDefinitions = {
    CraftTrophy = {},
    SeashellCollect = {},
    SpinWheelRemote = {key = "SpinWheel"},
    SpinWheelData = {isFunction = true},
    BuyGemShopItem = {},
    SummerQuestClaim = {},
    SummerShopBuy = {},
    TournamentServer = {},
    TournamentRemote = {key = "Tournament"},
    TournamentTick = {},
    PerformWish = {isFunction = true},
    ClaimAllIndexGems = {},
    DailyReward = {},
    RedeemCode = {},
    RebirthRemote = {key = "Rebirth"},
    BuyPackRemote = {key = "BuyPack"},
    SetAutoBuyPackRemote = {key = "SetAutoBuy"},
    OpenPack = {},
    GetThroneStatus = {isFunction = true},
    AttemptThrone = {},
    ThroneResult = {},
}
local Remotes = buildRemotes(Modules.Networker, RemoteDefinitions)
local REDEEM_CODES = {
    "OWL-HAPPY",
}
local REDEEM_CODE_GROUP_ID = 520125566
local PackBuyNames = {}
local PackBuyLabels = {}
local PackBuyNameByLabel = {}
local PackBuyLabelByName = {}
local function buildPackBuyOptions()
    local entries = {}
    for packName, packData in pairs(Modules.PackConfig.Packs) do
        if type(packData) == "table"
            and packName ~= "Scarlet"
            and packName ~= "Bonded"
            and packData.HideFromShop ~= true
            and tonumber(packData.Price)
            and tonumber(packData.Price) > 0
            and type(packData.RobuxOptions) ~= "table"
        then
            entries[#entries + 1] = {
                name = tostring(packName),
                label = tostring(
                    packData.DisplayName
                    or packName
                ),
                order = tonumber(packData.LayoutOrder) or 0,
            }
        end
    end
    table.sort(entries, function(left, right)
        if left.order ~= right.order then
            return left.order < right.order
        end
        return left.label < right.label
    end)
    local usedLabels = {}
    for _, entry in ipairs(entries) do
        local label = entry.label
        if usedLabels[label] then
            label = label .. " (" .. entry.name .. ")"
        end
        usedLabels[label] = true
        PackBuyNames[#PackBuyNames + 1] = entry.name
        PackBuyLabels[#PackBuyLabels + 1] = label
        PackBuyNameByLabel[label] = entry.name
        PackBuyLabelByName[entry.name] = label
    end
end
buildPackBuyOptions()
local PackLogOptions = {
    names = {},
    rank = {
        Bronze = 1,
        Silver = 2,
        Gold = 3,
        Legendary = 4,
        Mythic = 5,
        Divine = 6,
        Primordial = 7,
        Oblivion = 8,
        Eternity = 9,
        Astral = 10,
        Sovereign = 11,
        Vandal = 12,
        Tyrant = 13,
        Exclusive = 14,
        ["Secret Exclusive"] = 15,
        Verdant = 16,
        Silvane = 17,
        Lunar = 18,
        Solar = 19,
        Nether = 20,
        Aether = 21,
        Void = 22,
        Lumine = 23,
        Aurora = 24,
        Nebula = 25,
        Era = 26,
        Chrono = 27,
    },
}
do
    local seen = {}
    for _, cardData in pairs(Modules.CardConfig.Cards) do
        if type(cardData) == "table"
            and cardData.Rarity ~= nil
        then
            local rarity = tostring(cardData.Rarity)
            if rarity ~= "" and not seen[rarity] then
                seen[rarity] = true
                PackLogOptions.names[
                    #PackLogOptions.names + 1
                ] = rarity
            end
        end
    end
    table.sort(PackLogOptions.names, function(left, right)
        local leftRank =
            tonumber(PackLogOptions.rank[left]) or 0
        local rightRank =
            tonumber(PackLogOptions.rank[right]) or 0
        if leftRank ~= rightRank then
            return leftRank < rightRank
        end
        return left < right
    end)
    if #PackLogOptions.names == 0 then
        PackLogOptions.names[1] = "Unknown"
    end
end
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
    local gamepasses = Modules.ProductConfig.Gamepasses
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
    local fixedItems = Modules.GemShopConfig.FixedGamepasses
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
    local items = Modules.SummerShopConfig.Items
    if type(items) ~= "table" then
        return
    end
    for _, item in ipairs(items) do
        registerSummerShopOption(item)
    end
end
buildSummerShopOptions()
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
        local cards = Modules.CardConfig.Cards
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
    local rewards = Modules.TournamentConfig.ShopRewards
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
    autoBuyPacks = false,
    autoEnableNativeBuyPacks = false,
    packBuyWhitelist = {},
    packNativeManaged = {},
    packBuyCursor = 0,
    packBuyPollInterval = 0.5,
    packBuyActionCooldown = 1.25,
    packBuyRetryCooldown = 4,
    packBuyPendingTimeout = 8,
    packBuyNextAt = 0,
    packBuyPending = nil,
    packBuyRequests = 0,
    packBuyPurchases = 0,
    packBuyNativeUpdates = 0,
    packBuyFailures = 0,
    packBuyLastItem = "-",
    packBuyLastStatus = "Choose packs from the whitelist.",
    packBuyWhitelistDropdown = nil,
    autoBuyPacksToggle = nil,
    autoEnableNativeBuyPacksToggle = nil,
    autoOpenPacks = false,
    skipPackAnimations = true,
    packOpenPollInterval = 0.15,
    packOpenRequestCooldown = 0.35,
    packOpenRetryCooldown = 2,
    packOpenPendingTimeout = 12,
    packAnimationWaitTimeout = 2,
    packNextOpenAt = 0,
    packOpenPending = nil,
    packCurrentContext = nil,
    packHandledContexts =
        setmetatable({}, {__mode = "k"}),
    packResultRarityWhitelist = (function()
        local result = {}
        for _, rarity in ipairs(PackLogOptions.names) do
            result[rarity] = true
        end
        return result
    end)(),
    packResultHistory = {},
    packResultHistoryLimit = 50,
    packOpenRequests = 0,
    packOpenDetected = 0,
    packOpenSkipped = 0,
    packOpenAdvanced = 0,
    packFallbackClicks = 0,
    packResultsLogged = 0,
    packResultsFiltered = 0,
    packOpenFailures = 0,
    packLastPack = "-",
    packLastCard = "-",
    packLastRarity = "-",
    packLastStatus = "Waiting for available packs.",
    autoOpenPacksToggle = nil,
    skipPackAnimationsToggle = nil,
    packResultRarityDropdown = nil,
    packOpenConnection = nil,
    packUiChildConnection = nil,
    packWatchedUis =
        setmetatable({}, {__mode = "k"}),
    packUiSuppressCount = 0,
    packResultChainDelay = 1.25,
    packAutomationGeneration = 0,
    packControllerResets = 0,
    packAnimationStaleSince = 0,
    packAnimationRecoveryDelay = 5,
    packLocalHideAvailable = false,
    packLocalHideApplied = false,
    packLocalHideFailures = 0,
    packPreservedUi = nil,
    packRestoredUiCount = 0,
    backgroundVisualSupported = false,
    backgroundVisualFailures = 0,
    backgroundPackSuppressed = false,
    backgroundSpinSuppressed = false,
    autoRebirth = false,
    rebirthPollInterval = 0.75,
    rebirthCooldown = 3,
    rebirthRetryCooldown = 5,
    rebirthPendingTimeout = 12,
    rebirthNextAt = 0,
    rebirthPending = false,
    rebirthPendingSince = 0,
    rebirthPendingFrom = nil,
    rebirthAttempts = 0,
    rebirthSuccesses = 0,
    rebirthFailures = 0,
    rebirthLastStatus = "Waiting for requirements.",
    autoRebirthToggle = nil,
    autoEquipBestCards = false,
    equipBestMode = "income",
    equipBestPollInterval = 1,
    equipBestCooldown = 5,
    equipBestSettleDelay = 2,
    equipBestBusy = false,
    equipBestNextAt = 0,
    equipBestLastSignature = nil,
    equipBestRequests = 0,
    equipBestFailures = 0,
    equipBestLastStatus = "Ready.",
    equipBestModeDropdown = nil,
    autoEquipBestCardsToggle = nil,
    syncingEquipBestModeDropdown = false,
    autoCraft = false,
    whitelist = {},
    interval = 1,
    remoteCooldown = 2.5,
    nextCraftAt = 0,
    attempts = 0,
    lastCraft = "-",
    lastStatus = "Choose trophies from the whitelist.",
    window = nil,
    windowKeybind = "G",
    windowKeybindControl = nil,
    keybindTag = nil,
    uiTextConnections = {},
    whitelistDropdown = nil,
    autoCraftToggle = nil,
    autoClaimSeashell = false,
    seashellInterval = 0.75,
    seashellCooldown = 1.25,
    seashellLastScan = 0,
    seashellFound = 0,
    seashellTriggered = 0,
    lastSeashell = "-",
    lastSeashellStatus = "Waiting for Auto Claim.",
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
    spinWheelLastStatus = "Waiting for Spin Wheel.",
    spinWheelSessionStartedAt = os.time(),
    spinWheelLog = {},
    spinWheelLogLimit = 20,
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
    gemShopLastStatus = "Choose items from the whitelist.",
    gemShopWhitelistDropdown = nil,
    autoBuyGemShopToggle = nil,
    autoClaimSummerQuests = false,
    summerQuestPollInterval = 1,
    summerQuestClaimCooldown = 2,
    summerQuestNextAttempt = {},
    summerQuestClaimRequests = 0,
    summerQuestFailures = 0,
    summerQuestLastClaim = "-",
    summerQuestLastStatus = "Waiting for Summer Quests.",
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
    summerShopLastStatus = "Choose Summer Shop items from the whitelist.",
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
    tournamentShopLastStatus = "Choose Tournament Shop rewards from the whitelist.",
    tournamentShopOptionsFingerprint = "",
    tournamentShopWhitelistDropdown = nil,
    autoBuyTournamentShopToggle = nil,
    tournamentShopConnection = nil,
    syncingTournamentShopDropdown = false,
    autoJoinTournament = false,
    autoEquipBestTournament = false,
    tournamentAutomationPollInterval = 0.35,
    tournamentActionDelay = 0.75,
    tournamentEquipCooldown = 3,
    tournamentEquipSettleDelay = 1.25,
    tournamentPendingTimeout = 6,
    tournamentNextActionAt = 0,
    tournamentNextEquipAt = 0,
    tournamentPendingAction = nil,
    tournamentLastEquipSignature = nil,
    tournamentLastEquipTeamFingerprint = "",
    tournamentManualJoinRequested = false,
    tournamentTickState = nil,
    tournamentEquipRequests = 0,
    tournamentJoinRequests = 0,
    tournamentJoins = 0,
    tournamentFailures = 0,
    tournamentLastStatus = "Waiting for tournament.",
    autoJoinTournamentToggle = nil,
    autoEquipBestTournamentToggle = nil,
    tournamentTickConnection = nil,
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
    wishLastStatus = "Waiting for Wish Tickets.",
    wishSessionStartedAt = os.time(),
    wishLog = {},
    wishLogLimit = 20,
    autoSpinWishToggle = nil,
    skipWishAnimationToggle = nil,
    autoClaimIndex = false,
    indexPollInterval = 1,
    indexClaimCooldown = 2,
    indexNextClaimAt = 0,
    indexRequests = 0,
    indexFailures = 0,
    indexLastClaimable = 0,
    indexLastStatus = "Waiting for Index rewards.",
    autoClaimIndexToggle = nil,
    autoTryVulnoneCard = false,
    vulnonePollInterval = 5,
    vulnoneStatusRefreshInterval = 20,
    vulnoneAttemptCooldown = 5,
    vulnoneRetryCooldown = 15,
    vulnonePendingTimeout = 20,
    vulnoneNextStatusAt = 0,
    vulnoneNextAttemptAt = 0,
    vulnonePending = false,
    vulnonePendingSince = 0,
    vulnoneAttempts = 0,
    vulnoneResults = 0,
    vulnoneWins = 0,
    vulnoneLosses = 0,
    vulnoneFailures = 0,
    vulnoneStatus = nil,
    vulnoneLastResult = "-",
    vulnoneLastStatus = "Checking Vulnone status.",
    autoTryVulnoneToggle = nil,
    vulnoneResultConnection = nil,
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
    autoRedeemCodesToggle = nil,
    antiAfk = false,
    antiAfkInterval = 45,
    antiAfkBusy = false,
    nextAntiAfkPulseAt = 0,
    antiAfkCount = 0,
    lastAntiAfkAt = 0,
    antiAfkMethod = "disabled",
    lastAntiAfkError = nil,
    antiAfkLastStatus = "Anti AFK is not active yet.",
    antiAfkToggle = nil,
    antiAfkIdledConnection = nil,
    antiAfkHeartbeatConnection = nil,
    rejoining = false,
    lastRejoinStatus = "Ready.",
    logs = {},
    logsLimit = 150,
    logsDisplayLimit = 40,
    logsFilter = "All",
    logsLastByCategory = {},
    logsSuppressed = 0,
    logsDedupeSeconds = 30,
    logsSuppressedUiInterval = 2,
    logsNextSuppressedUiAt = 0,
    logsParagraph = nil,
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
    configLastError = nil,
    autoSaveToggle = nil,
    autoLoadToggle = nil,
}
local LOG_FILTER_OPTIONS = {
    "All",
    "Hub",
    "Vulnone",
    "Packs",
    "Rebirth",
    "Team",
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
    "no seashells",
    "no index rewards",
    "no claimable rewards",
    "no summer quests",
    "summer quest data is not available yet",
    "no quests",
    "out of stock",
    "not available in stock",
    "unavailable.",
    "not available yet",
    "not available in the shop yet",
    "whitelisted rewards are not currently available",
    "whitelisted rewards are not available",
    "reward list is not available",
    "no wish tickets",
    "no spins",
    "no items",
    "no rewards",
    "waiting for rewards",
    "waiting for wish",
    "waiting for spin",
    "waiting for automation",
    "is still on cooldown",
    "player data is not ready",
    "player store is not ready",
    "choose items from",
    "choose rewards from",
    "choose trophies from",
    "daily reward is not ready",
    "checking daily rewards",
    "checking reward status",
    "daily rewards updated",
    "best income team equipped",
    "best rarity team equipped",
    "player data is loading",
    "all saved codes have been tried",
    "no pending codes",
    "required group has not been joined",
    "keep-alive input sent • periodic",
    "settings saved successfully",
    "window keybind changed to",
    "whitelist updated",
    "filter updated",
    "status updated",
    "refreshed.",
    "synchronized.",
    "loaded from saved settings",
    " enabled.",
    " disabled.",
    " selected.",
    " cleared.",
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
        local normalizedPattern = string.lower(
            LogRuntime.normalizeMessage(pattern)
        )
        if normalizedPattern ~= ""
            and string.find(
                lowered,
                normalizedPattern,
                1,
                true
            )
        then
            return true
        end
    end
    return false
end
function LogRuntime.suppress()
    State.logsSuppressed += 1
    local now = os.clock()
    if now >= State.logsNextSuppressedUiAt then
        State.logsNextSuppressedUiAt =
            now + State.logsSuppressedUiInterval
        LogRuntime.updateUI()
    end
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
    if keepRoutine ~= true
        and level ~= "error"
        and LogRuntime.isRoutineMessage(message)
    then
        LogRuntime.suppress()
        return nil
    end
    local now = os.clock()
    local dedupeKey = category .. "\0" .. message
    local previousAt = State.logsLastByCategory[dedupeKey]
    local dedupeSeconds = level == "error"
        and 8
        or State.logsDedupeSeconds
    if previousAt and now - previousAt < dedupeSeconds then
        LogRuntime.suppress()
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
    State.logsNextSuppressedUiAt = 0
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
        return Modules.charm.peek(Modules.PlayerStore)
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
        return "None"
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
        if Modules.TrophyConfig.Trophies[trophyName] then
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
    State.equipBestNextAt = 0
    State.equipBestLastSignature = nil
    State.equipBestBusy = false
    State.nextCraftAt = 0
    updateStatus("Whitelist updated: " .. formatSelectedTrophies())
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
    updateStatus(enabled and "All trophies selected." or "Whitelist cleared.")
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
            local config = Modules.CardConfig.Cards[rawCardId] or Modules.CardConfig.Cards[cardId]
            local rarity = config and config.Rarity
            if rarity then
                byRarity[rarity] = (byRarity[rarity] or 0) + 1
            end
        end
    end
    return byId, byRarity
end
local function hasEnoughUnlockedCards(trophyName, playerData)
    local trophy = Modules.TrophyConfig.Trophies[trophyName]
    if type(trophy) ~= "table" then
        return false, "Trophy configuration was not found"
    end
    local requirements = trophy.Requirements
    if type(requirements) ~= "table" then
        return true
    end
    local byId, byRarity = buildUnlockedCardCounts(playerData)
    for _, requirement in ipairs(requirements) do
        if requirement.type == "specific" then
            local cardId = tostring(requirement.cardId or "")
            local amount = tonumber(requirement.amount) or 0
            local owned = byId[cardId] or 0
            if owned < amount then
                return false, string.format(
                    "Not enough %s (%d/%d)",
                    cardId,
                    owned,
                    amount
                )
            end
            byId[cardId] = owned - amount
            local rawRequirementId = requirement.cardId
            local card = Modules.CardConfig.Cards[rawRequirementId] or Modules.CardConfig.Cards[cardId]
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
                    "Not enough of any %s (%d/%d)",
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
        return false, "already crafted"
    end
    if stocks[trophyName] ~= true then
        return false, "not available in stock"
    end
    return hasEnoughUnlockedCards(trophyName, playerData)
end
local function craftNextWhitelisted()
    if os.clock() < State.nextCraftAt then
        return false, "Action is on cooldown"
    end
    if countSelectedTrophies() == 0 then
        updateStatus("The whitelist is empty. Select at least one trophy.")
        return false, "Whitelist is empty"
    end
    local playerData = getPlayerData()
    if not playerData then
        updateStatus("Player data is not ready yet.")
        return false, "Player data is not ready"
    end
    local blockedReasons = {}
    for _, trophyName in ipairs(TROPHY_ORDER) do
        if State.whitelist[trophyName] then
            local available, reason = getTrophyAvailability(trophyName, playerData)
            if available then
                State.nextCraftAt = os.clock() + State.remoteCooldown
                State.attempts += 1
                State.lastCraft = trophyName
                updateStatus("Submitting trophy craft: " .. trophyName)
                local success, errorMessage = pcall(function()
                    Remotes.CraftTrophy:FireServer(trophyName)
                end)
                if not success then
                    State.nextCraftAt = os.clock() + 1
                    updateStatus("Action failed: " .. tostring(errorMessage))
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
            or "No trophies can be crafted."
    )
    return false, "No craftable trophies"
end
local function setAutoCraft(enabled)
    State.autoCraft = enabled == true
    State.nextCraftAt = 0
    if State.autoCraft and countSelectedTrophies() == 0 then
        updateStatus("Auto Craft is enabled, but the whitelist is still empty.")
        notify(
            "Auto Craft Trophies",
            "Select at least one trophy from the whitelist.",
            "triangle-alert"
        )
    else
        updateStatus(State.autoCraft and "Auto Craft enabled." or "Auto Craft disabled.")
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
        updateSeashellStatus("Seashells are not available yet.")
        return false, 0, "Seashells are not available yet"
    end
    local seashells = folder:GetChildren()
    State.seashellFound = #seashells
    State.seashellLastScan = os.clock()
    if #seashells == 0 then
        updateSeashellStatus("No seashells are available.")
        return true, 0
    end
    local now = os.clock()
    local sent = 0
    local invalid = 0
    local lastError = nil
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
                    Remotes.SeashellCollect:FireServer(index)
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
            "Collecting %d of %d seashells.",
            sent,
            #seashells
        ))
        return true, sent
    end
    if invalid == #seashells then
        updateSeashellStatus("The object name does not use the Seashell_<index> format.")
        return false, 0, "Could not read the seashell index"
    end
    if lastError then
        updateSeashellStatus("Action failed: " .. lastError)
        return false, 0, lastError
    end
    updateSeashellStatus("All indexes are still on cooldown.")
    return true, 0
end
local function setAutoClaimSeashell(enabled)
    State.autoClaimSeashell = enabled == true
    updateSeashellStatus(
        State.autoClaimSeashell
            and "Auto Claim Seashells enabled."
            or "Auto Claim Seashells disabled."
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
local NativeVisualRuntime = {
    signals = {},
    captured = {
        pack = false,
        spin = false,
    },
    connections = {
        pack = {},
        spin = {},
    },
    disabled = {
        pack = false,
        spin = false,
    },
}

function NativeVisualRuntime.getProvider()
    if type(getconnections) == "function" then
        return getconnections
    end

    if type(get_signal_cons) == "function" then
        return get_signal_cons
    end

    if type(getsignalconnections) == "function" then
        return getsignalconnections
    end

    return nil
end

function NativeVisualRuntime.setConnection(connection, enabled)
    if connection == nil then
        return false
    end

    local methodNames = enabled
        and {"Enable", "enable"}
        or {"Disable", "disable"}

    for _, methodName in ipairs(methodNames) do
        local method

        pcall(function()
            method = connection[methodName]
        end)

        if type(method) == "function" then
            local success = pcall(method, connection)

            if success then
                return true
            end
        end
    end

    local success = pcall(function()
        connection.Enabled = enabled == true
    end)

    return success
end

function NativeVisualRuntime.capture(kind, signal)
    if NativeVisualRuntime.captured[kind] then
        return true
    end

    NativeVisualRuntime.signals[kind] = signal

    local provider = NativeVisualRuntime.getProvider()

    if not provider then
        State.backgroundVisualSupported = false
        return false
    end

    local success, connections = pcall(provider, signal)

    if not success or type(connections) ~= "table" then
        State.backgroundVisualSupported = false
        State.backgroundVisualFailures += 1
        return false
    end

    local target = NativeVisualRuntime.connections[kind]

    table.clear(target)

    for _, connection in ipairs(connections) do
        target[#target + 1] = connection
    end

    NativeVisualRuntime.captured[kind] = true
    State.backgroundVisualSupported = true

    return true
end

function NativeVisualRuntime.shouldSuppress(kind)
    if kind == "pack" then
        return State.autoOpenPacks
            and State.skipPackAnimations
    end

    if kind == "spin" then
        return State.autoSpinWheel
    end

    return false
end

function NativeVisualRuntime.sync(kind)
    local function apply(targetKind)
        local desired =
            NativeVisualRuntime.shouldSuppress(targetKind)

        if NativeVisualRuntime.disabled[targetKind]
            == desired
        then
            return
        end

        local changed = false

        for _, connection in ipairs(
            NativeVisualRuntime.connections[targetKind]
        ) do
            if NativeVisualRuntime.setConnection(
                connection,
                not desired
            ) then
                changed = true
            else
                State.backgroundVisualFailures += 1
            end
        end

        if changed
            or #NativeVisualRuntime.connections[targetKind]
                == 0
        then
            NativeVisualRuntime.disabled[targetKind] =
                desired
        end

        if targetKind == "pack" then
            State.backgroundPackSuppressed =
                NativeVisualRuntime.disabled[targetKind]
        elseif targetKind == "spin" then
            State.backgroundSpinSuppressed =
                NativeVisualRuntime.disabled[targetKind]
        end
    end

    if kind then
        apply(kind)
    else
        apply("pack")
        apply("spin")
    end
end

function NativeVisualRuntime.isSuppressed(kind)
    return NativeVisualRuntime.disabled[kind] == true
end

function NativeVisualRuntime.restoreAll()
    for _, kind in ipairs({"pack", "spin"}) do
        for _, connection in ipairs(
            NativeVisualRuntime.connections[kind]
        ) do
            NativeVisualRuntime.setConnection(
                connection,
                true
            )
        end

        NativeVisualRuntime.disabled[kind] = false
    end

    State.backgroundPackSuppressed = false
    State.backgroundSpinSuppressed = false
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
        return {"No rewards have been collected this session."}
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
    updateSpinWheelStatus("Spin result received: " .. entry.display)
    return entry
end
local function clearSpinWheelLog()
    table.clear(State.spinWheelLog)
    State.spinWheelResults = 0
    State.spinWheelLastReward = "-"
    State.spinWheelSessionStartedAt = os.time()
    updateSpinWheelLogUI()
    updateSpinWheelStatus("Spin Wheel session log cleared.")
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
        return Remotes.SpinWheelData:InvokeServer()
    end)
    if not success then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("Could not load Spin Wheel data: " .. tostring(result))
        return false, nil, tostring(result)
    end
    if type(result) ~= "table" then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("Spin Wheel data is invalid.")
        return false, nil, "Spin Wheel data is invalid"
    end
    State.spinWheelData = copySpinWheelData(result)
    State.spinWheelLastDataAt = now
    updateSpinWheelStatus()
    return true, State.spinWheelData
end
local function claimFreeSpin(force)
    local now = os.clock()
    if not force and now < State.spinWheelNextClaimAt then
        return false, "Claim is on cooldown"
    end
    local success, data, errorMessage = fetchSpinWheelData(force == true)
    if not success then
        return false, errorMessage
    end
    if data.canClaimFree ~= true then
        return false, "Free spin is not available yet"
    end
    State.spinWheelNextClaimAt = now + State.spinWheelClaimCooldown
    local fired, fireError = pcall(function()
        Remotes.SpinWheelRemote:FireServer("claim_free")
    end)
    if not fired then
        State.spinWheelFailures += 1
        State.spinWheelNextClaimAt = now + 1
        updateSpinWheelStatus("Free spin claim failed: " .. tostring(fireError))
        return false, tostring(fireError)
    end
    State.spinWheelClaimRequests += 1
    State.spinWheelLastDataAt = 0
    updateSpinWheelStatus("Free Spin is being processed.")
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
            return false, "Waiting for the spin result"
        end
        State.spinWheelPending = false
        updateSpinWheelStatus("Spin confirmation timed out; retrying.")
    end
    if not force and now < State.spinWheelNextSpinAt then
        return false, "Spin is on cooldown"
    end
    local success, data, errorMessage = fetchSpinWheelData(force == true)
    if not success then
        return false, errorMessage
    end
    if (data.totalSpins or 0) <= 0 then
        return false, "No spins are available"
    end
    State.spinWheelPending = true
    State.spinWheelPendingSince = now
    State.spinWheelNextSpinAt = now + State.spinWheelSpinDelay

    NativeVisualRuntime.sync("spin")

    local fired, fireError = pcall(function()
        Remotes.SpinWheelRemote:FireServer("spin")
    end)
    if not fired then
        State.spinWheelPending = false
        State.spinWheelFailures += 1
        State.spinWheelNextSpinAt = now + 1
        updateSpinWheelStatus("Spin failed: " .. tostring(fireError))
        return false, tostring(fireError)
    end
    State.spinWheelSpinRequests += 1
    State.spinWheelLastDataAt = 0
    updateSpinWheelStatus("Spin started; waiting for the result.")
    return true
end
local function setAutoClaimSpinWheel(enabled)
    State.autoClaimSpinWheel = enabled == true
    State.spinWheelNextClaimAt = 0
    updateSpinWheelStatus(
        State.autoClaimSpinWheel
            and "Auto Claim Spin Wheel enabled."
            or "Auto Claim Spin Wheel disabled."
    )
    return State.autoClaimSpinWheel
end
local function setAutoSpinWheel(enabled)
    State.autoSpinWheel = enabled == true
    State.spinWheelNextSpinAt = 0

    NativeVisualRuntime.sync("spin")

    updateSpinWheelStatus(
        State.autoSpinWheel
            and "Auto Spin Wheel enabled."
            or "Auto Spin Wheel disabled."
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
        updateSpinWheelStatus("The spin result failed or was invalid.")
        return
    end
    if type(payload.reward) ~= "table" then
        State.spinWheelFailures += 1
        updateSpinWheelStatus("The spin result did not include a reward.")
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
        return Modules.charm.peek(Modules.GemShopState)
    end)
    if success and type(state) == "table" then
        return state
    end
    success, state = pcall(function()
        return Modules.GemShopState()
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
        return Modules.PurchaseClient.hasGamepass(gamepassId)
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
    State.gemShopLastStatus = "Gem Shop whitelist updated."
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
        and "All Gem Shop items selected."
        or "Gem Shop whitelist cleared."
end
local function getLuckyItemDisplay(shopState)
    local luckyItem = shopState and shopState.luckyItem
    if type(luckyItem) ~= "table" then
        return "Unavailable", 0, nil
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
            return nil, "configuration was not found"
        end
        if type(itemState) ~= "table" then
            return nil, "state is not available yet"
        end
        if hasGamepass(config.Id) then
            return nil, "already owned"
        end
        if itemState.inStock ~= true then
            return nil, "out of stock"
        end
        local price = math.max(0, math.floor(tonumber(itemState.price) or 0))
        if gems < price then
            return nil, "not enough Gems"
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
            return nil, "Lucky Item is not available yet"
        end
        if hasGamepass(gamepassId) then
            return nil, "Lucky Item is already owned"
        end
        if gems < price then
            return nil, "not enough Gems"
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
            return nil, "out of stock"
        end
        if gems < price then
            return nil, "not enough Gems"
        end
        return {
            optionKey = optionKey,
            purchaseType = "scarlet",
            label = "Scarlet Pack",
            price = price,
            stock = stock,
        }
    end
    return nil, "unknown item"
end
local function sendGemShopPurchase(candidate)
    local success, errorMessage = pcall(function()
        if candidate.purchaseType == "fixed" then
            Remotes.BuyGemShopItem:FireServer("fixed", candidate.purchaseArgument)
        elseif candidate.purchaseType == "lucky" then
            Remotes.BuyGemShopItem:FireServer("lucky")
        elseif candidate.purchaseType == "scarlet" then
            Remotes.BuyGemShopItem:FireServer("scarlet")
        else
            error("Unknown purchase type")
        end
    end)
    if not success then
        State.gemShopFailures += 1
        updateGemShopStatus("Purchase failed: " .. tostring(errorMessage))
        return false, tostring(errorMessage)
    end
    State.gemShopRequests += 1
    State.gemShopLastItem = candidate.label
    updateGemShopStatus(
        "Purchase started: "
            .. candidate.label
            .. " ("
            .. formatCompactNumber(candidate.price)
            .. " Gems)"
    )
    return true
end
local function buyNextGemShopItem(force)
    if countSelectedGemShopItems() == 0 then
        updateGemShopStatus("The Gem Shop whitelist is empty.")
        return false, "Whitelist is empty"
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
        updateGemShopStatus("All whitelisted items are still on cooldown.")
    end
    return false, "No items can be purchased"
end
local function setAutoBuyGemShop(enabled)
    State.autoBuyGemShop = enabled == true
    State.gemShopNextBuyAt = 0
    updateGemShopStatus(
        State.autoBuyGemShop
            and "Auto Buy Gem Shop enabled."
            or "Auto Buy Gem Shop disabled."
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
        config = Modules.SummerQuestConfig.getQuest(quest.id)
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
        updateSummerQuestStatus("Summer Quest data is not available yet.")
        return false, 0, "None quest"
    end
    local now = os.clock()
    local sent = 0
    local lastError = nil
    for index, quest in ipairs(quests) do
        if isSummerQuestClaimable(quest) then
            local nextAttempt = State.summerQuestNextAttempt[index] or 0
            if force == true or now >= nextAttempt then
                State.summerQuestNextAttempt[index] =
                    now + State.summerQuestClaimCooldown
                local success, errorMessage = pcall(function()
                    Remotes.SummerQuestClaim:FireServer(index)
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
            string.format("Processing %d quests.", sent)
        )
        return true, sent
    end
    if lastError then
        updateSummerQuestStatus("Claim failed: " .. lastError)
        return false, 0, lastError
    end
    updateSummerQuestStatus("No Summer Quests can be claimed yet.")
    return true, 0
end
local function setAutoClaimSummerQuests(enabled)
    State.autoClaimSummerQuests = enabled == true
    table.clear(State.summerQuestNextAttempt)
    updateSummerQuestStatus(
        State.autoClaimSummerQuests
            and "Auto Claim Summer Quests enabled."
            or "Auto Claim Summer Quests disabled."
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
    updateSummerShopStatus("Summer Shop whitelist updated.")
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
            and "All Summer Shop items selected."
            or "Summer Shop whitelist cleared."
    )
end
local function ownsSummerShopItem(playerData, item)
    if type(item) ~= "table" or item.OneTime ~= true or not playerData then
        return false
    end
    local grant = item.grant
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
        return false, "invalid configuration"
    end
    if item.NoBuyButton == true then
        return false, "does not have a Seashell purchase button"
    end
    local id = tostring(item.id or "")
    local price = math.max(0, math.floor(tonumber(item.seashellPrice) or 0))
    local seashells =
        math.max(0, math.floor(tonumber(playerData and playerData.seashells) or 0))
    if item.OneTime == true and ownsSummerShopItem(playerData, item) then
        return false, "already owned"
    end
    if item.OneTime ~= true and item.NoStock ~= true then
        local stock = getSummerShopStock(playerData, id)
        if stock <= 0 then
            return false, "out of stock"
        end
    end
    if seashells < price then
        return false, string.format(
            "not enough Seashells (%s/%s)",
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
        return false, "Auto Buy is on cooldown"
    end
    if countSelectedSummerShopItems() == 0 then
        updateSummerShopStatus("The Summer Shop whitelist is still empty.")
        return false, "Whitelist is empty"
    end
    local playerData = getPlayerData()
    if not playerData then
        updateSummerShopStatus("Player data is not ready yet.")
        return false, "Player data is not ready"
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
                        Remotes.SummerShopBuy:FireServer(id)
                    end)
                    if not success then
                        State.summerShopFailures += 1
                        State.summerShopNextBuyAt = now + 1
                        State.summerShopItemNextAttempt[id] = now + 1
                        updateSummerShopStatus(
                            "Purchase failed: " .. tostring(errorMessage)
                        )
                        return false, tostring(errorMessage)
                    end
                    State.summerShopBuyRequests += 1
                    State.summerShopLastItem =
                        tostring(item.displayName or id)
                    updateSummerShopStatus(
                        "Purchase started: "
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
            or "All whitelisted items are still on cooldown."
    )
    return false, "No items can be purchased"
end
local function setAutoBuySummerShop(enabled)
    State.autoBuySummerShop = enabled == true
    State.summerShopNextBuyAt = 0
    updateSummerShopStatus(
        State.autoBuySummerShop
            and "Auto Buy Summer Shop enabled."
            or "Auto Buy Summer Shop disabled."
    )
    return State.autoBuySummerShop
end
local TOURNAMENT_BUY_FAILURE_MESSAGES = {
    tokens = "Not enough Tournament Tokens",
    claimed = "Reward was already purchased",
    outofstock = "Reward is out of stock",
    apply_failed = "The server could not grant the reward",
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
        local card = Modules.CardConfig.Cards[rawCardId]
            or Modules.CardConfig.Cards[cardId]
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
        "Reward list updated."
end
local function setAllTournamentShopItems(enabled)
    for _, id in ipairs(TournamentShopOptionKeys) do
        State.tournamentShopWhitelist[id] = enabled == true
    end
    State.tournamentShopNextBuyAt = 0
    syncTournamentShopWhitelistDropdown()
    State.tournamentShopLastStatus = enabled
        and "All rewards selected."
        or "Tournament Shop whitelist cleared."
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
            .. tostring(Modules.TournamentConfig.ShopRewardsPerTournament or 3),
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
            return false, "Waiting for the previous purchase to finish"
        end
        clearTournamentShopPending()
        State.tournamentShopFailures += 1
        State.tournamentShopLastStatus =
            "Purchase confirmation timed out; retrying."
    end
    if not force and now < State.tournamentShopNextBuyAt then
        return false, "Purchase is on cooldown"
    end
    local shopData = refreshTournamentShopOptions(true)
    if #TournamentShopCurrentEntries == 0 then
        updateTournamentShopStatus(
            "Tournament Shop reward data is not available yet."
        )
        return false, "Tournament Shop is not available yet"
    end
    if countSelectedTournamentShopItems() == 0 then
        updateTournamentShopStatus(
            "The reward list is still empty."
        )
        return false, "Whitelist is empty"
    end
    local blocked = {}
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
                        entry.displayName .. ": not enough Tokens"
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
                        Remotes.TournamentServer:FireServer("buy", entry.index)
                    end)
                    if not success then
                        clearTournamentShopPending()
                        State.tournamentShopFailures += 1
                        State.tournamentShopNextBuyAt = now + 1
                        State.tournamentShopItemNextAttempt[configId] =
                            now + 1
                        updateTournamentShopStatus(
                            "Purchase failed: " .. tostring(errorMessage)
                        )
                        return false, tostring(errorMessage)
                    end
                    State.tournamentShopBuyRequests += 1
                    State.tournamentShopLastItem = entry.displayName
                    updateTournamentShopStatus(
                        "Purchase started: "
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
            or "Whitelisted rewards are not currently available in the shop."
    )
    return false, "No whitelisted rewards can be purchased"
end
local function setAutoBuyTournamentShop(enabled)
    State.autoBuyTournamentShop = enabled == true
    State.tournamentShopNextBuyAt = 0
    table.clear(State.tournamentShopItemNextAttempt)
    updateTournamentShopStatus(
        State.autoBuyTournamentShop
            and "Auto Buy Tournament Shop enabled."
            or "Auto Buy Tournament Shop disabled."
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
            "Purchased %s • Stock %s • Next price %s",
            displayName,
            tostring(payload.newStock ~= nil and payload.newStock or "?"),
            tostring(payload.newPrice ~= nil and payload.newPrice or "?")
        )
    else
        State.tournamentShopFailures += 1
        local reason = tostring(payload.reason or "unknown")
        State.tournamentShopLastStatus =
            TOURNAMENT_BUY_FAILURE_MESSAGES[reason]
                or ("Purchase failed: " .. reason)
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
            and "Auto Claim Index enabled."
            or "Auto Claim Index disabled."
    )
    return State.autoClaimIndex
end
function IndexRuntime.claimAll(force)
    local now = os.clock()
    if force ~= true and now < State.indexNextClaimAt then
        return false, "Index claim is on cooldown"
    end
    local stats = IndexRuntime.getStats()
    State.indexLastClaimable = stats.total
    if not stats.playerDataReady then
        State.indexNextClaimAt = now + 2
        IndexRuntime.updateStatus("Player data is not ready yet.")
        return false, "Player data is not ready yet"
    end
    if stats.total <= 0 then
        State.indexNextClaimAt = now + State.indexClaimCooldown
        IndexRuntime.updateStatus("No Index rewards can be claimed.")
        return false, "No Index rewards"
    end
    State.indexNextClaimAt = now + State.indexClaimCooldown
    local success, errorMessage = pcall(function()
        Remotes.ClaimAllIndexGems:FireServer()
    end)
    if not success then
        State.indexFailures += 1
        State.indexNextClaimAt = now + 1
        IndexRuntime.updateStatus(
            "Index claim failed: " .. tostring(errorMessage)
        )
        return false, tostring(errorMessage)
    end
    State.indexRequests += 1
    IndexRuntime.updateStatus(
        string.format(
            "Processing %d Index rewards.",
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
        minRebirth = tonumber(Modules.GachaConfig.MinRebirth) or 3,
    }
end
function WishRuntime.cardName(cardId)
    local cards = Modules.CardConfig.Cards
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
        return {"No Wish results have been recorded this session."}
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
    WishRuntime.updateStatus("Wish succeeded: " .. display)
    return entry
end
function WishRuntime.clearLog()
    table.clear(State.wishLog)
    State.wishResults = 0
    State.wishLastReward = "-"
    State.wishSessionStartedAt = os.time()
    WishRuntime.updateLogUI()
    WishRuntime.updateStatus("Wish session log cleared.")
end
function WishRuntime.setAutoSpin(enabled)
    State.autoSpinWishTickets = enabled == true
    State.wishNextAt = 0
    WishRuntime.updateStatus(
        State.autoSpinWishTickets
            and "Auto Wish enabled."
            or "Auto Wish disabled."
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
            and "Wish animation will be skipped."
            or "The native Wish animation will play."
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
        if type(Modules.AnimationController.Init) == "function" then
            Modules.AnimationController.Init()
        end
        Modules.AnimationController.play(result, function()
            State.wishAnimationBusy = false
            State.wishAnimationStartedAt = 0
            WishRuntime.updateStatus("Wish animation completed.")
        end)
    end)
    if not success then
        State.wishAnimationBusy = false
        State.wishAnimationStartedAt = 0
        WishRuntime.updateStatus(
            "Wish succeeded, but the animation failed: " .. tostring(errorMessage)
        )
        return false, tostring(errorMessage)
    end
    return true
end
function WishRuntime.perform(force)
    local now = os.clock()
    if State.wishPending then
        return false, "A Wish request is still being processed"
    end
    if State.wishAnimationBusy then
        if now - State.wishAnimationStartedAt < 30 then
            return false, "Waiting for the Wish animation to finish"
        end
        State.wishAnimationBusy = false
        State.wishAnimationStartedAt = 0
    end
    if force ~= true and now < State.wishNextAt then
        return false, "Wish is on cooldown"
    end
    local data = WishRuntime.getData()
    if not data.playerData then
        State.wishNextAt = now + 2
        WishRuntime.updateStatus("Player data is not ready yet.")
        return false, "Player data is not ready yet"
    end
    if data.rebirth < data.minRebirth then
        State.wishNextAt = now + 5
        WishRuntime.updateStatus(
            string.format(
                "Wish is locked and requires Rebirth %d.",
                data.minRebirth
            )
        )
        return false, "Wish is not unlocked yet"
    end
    if data.tickets <= 0 then
        State.wishNextAt = now + 3
        WishRuntime.updateStatus("No Wish Tickets are available.")
        return false, "No Wish Tickets are available"
    end
    State.wishPending = true
    State.wishRequests += 1
    State.wishNextAt = now + State.wishRequestCooldown
    WishRuntime.updateStatus("Processing Wish...")
    local success, result = pcall(function()
        return Remotes.PerformWish:InvokeServer()
    end)
    State.wishPending = false
    if not success then
        State.wishFailures += 1
        State.wishNextAt = os.clock() + State.wishRateLimitCooldown
        WishRuntime.updateStatus("Wish failed: " .. tostring(result))
        return false, tostring(result)
    end
    if type(result) ~= "table" then
        State.wishFailures += 1
        WishRuntime.updateStatus("The Wish result is invalid.")
        return false, "The Wish result is invalid"
    end
    if result.ok ~= true then
        local reason = tostring(result.reason or "unknown")
        if reason ~= "rate_limited" then
            State.wishFailures += 1
        end
        if reason == "no_tickets" then
            State.wishNextAt = os.clock() + 3
            WishRuntime.updateStatus("Server: no Wish Tickets are available.")
            return false, "No Wish Tickets are available"
        elseif reason == "locked_rebirth" then
            State.wishNextAt = os.clock() + 5
            WishRuntime.updateStatus(
                "Server: Wish is not unlocked for the current Rebirth."
            )
            return false, "Wish is not unlocked yet"
        elseif reason == "rate_limited" then
            State.wishNextAt = os.clock() + State.wishRateLimitCooldown
            WishRuntime.updateStatus("Server rate limit reached; retrying later.")
            return false, "Rate limited"
        end
        WishRuntime.updateStatus("Wish failed: " .. reason)
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
    AntiAfkRuntime.virtualUser =
        game:GetService("VirtualUser")
end)
pcall(function()
    AntiAfkRuntime.virtualInputManager =
        game:GetService("VirtualInputManager")
end)
function AntiAfkRuntime.updateStatus(message)
    if message ~= nil then
        State.antiAfkLastStatus = tostring(message)
        LogRuntime.append(
            "Anti AFK",
            State.antiAfkLastStatus
        )
    end
    local lastPulse = "Never"
    if State.lastAntiAfkAt > 0 then
        lastPulse = os.date(
            "%H:%M:%S",
            State.lastAntiAfkAt
        )
    end
    local description = table.concat({
        "Enabled: "
            .. (
                State.antiAfk
                    and "ON"
                    or "OFF"
            ),
        "Interval: "
            .. tostring(State.antiAfkInterval)
            .. "s",
        "Pulses: "
            .. tostring(State.antiAfkCount),
        "Last Pulse: " .. lastPulse,
        "Method: "
            .. tostring(State.antiAfkMethod),
        "Error: "
            .. tostring(
                State.lastAntiAfkError or "-"
            ),
        "Status: "
            .. tostring(State.antiAfkLastStatus),
    }, "\n")
    if State.antiAfkStatusParagraph
        and type(
            State.antiAfkStatusParagraph.SetDesc
        ) == "function"
    then
        pcall(function()
            State.antiAfkStatusParagraph:SetDesc(
                description
            )
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
    return success,
        success and nil or tostring(errorMessage)
end
function AntiAfkRuntime.tryVirtualInputMouse()
    local manager =
        AntiAfkRuntime.virtualInputManager
    if not manager then
        return false,
            "VirtualInputManager unavailable"
    end
    local success, errorMessage = pcall(function()
        local position =
            UserInputService:GetMouseLocation()
        manager:SendMouseMoveEvent(
            position.X + 1,
            position.Y,
            game
        )
        task.wait(0.03)
        manager:SendMouseMoveEvent(
            position.X,
            position.Y,
            game
        )
    end)
    return success,
        success and nil or tostring(errorMessage)
end
function AntiAfkRuntime.tryVirtualInputKey()
    local manager =
        AntiAfkRuntime.virtualInputManager
    if not manager then
        return false,
            "VirtualInputManager unavailable"
    end
    local success, errorMessage = pcall(function()
        manager:SendKeyEvent(
            true,
            Enum.KeyCode.RightControl,
            false,
            game
        )
        task.wait(0.04)
        manager:SendKeyEvent(
            false,
            Enum.KeyCode.RightControl,
            false,
            game
        )
    end)
    return success,
        success and nil or tostring(errorMessage)
end
function AntiAfkRuntime.tryVirtualUser()
    local virtualUser =
        AntiAfkRuntime.virtualUser
    if not virtualUser then
        return false, "VirtualUser unavailable"
    end
    local camera = Workspace.CurrentCamera
    local cameraCFrame =
        camera and camera.CFrame or CFrame.new()
    local point = Vector2.new(0, 0)
    local success, errorMessage = pcall(function()
        virtualUser:CaptureController()
        local clicked = pcall(function()
            virtualUser:ClickButton2(point)
        end)
        if not clicked then
            virtualUser:Button2Down(
                point,
                cameraCFrame
            )
            task.wait(0.06)
            virtualUser:Button2Up(
                point,
                cameraCFrame
            )
        end
    end)
    return success,
        success and nil or tostring(errorMessage)
end
function AntiAfkRuntime.pulse(source, force)
    if not State.running then
        return false, "Hub has stopped"
    end
    if not State.antiAfk
        and force ~= true
    then
        return false, "Anti AFK disabled"
    end
    if State.antiAfkBusy then
        return false,
            "An Anti AFK pulse is already running"
    end
    State.antiAfkBusy = true
    local successfulMethods = {}
    local errors = {}
    local methods = {
        {
            "MouseRel",
            AntiAfkRuntime.tryMouseMoveRelative,
        },
        {
            "VIM Mouse",
            AntiAfkRuntime.tryVirtualInputMouse,
        },
        {
            "VirtualUser",
            AntiAfkRuntime.tryVirtualUser,
        },
        {
            "VIM Key",
            AntiAfkRuntime.tryVirtualInputKey,
        },
    }
    for _, method in ipairs(methods) do
        local name = method[1]
        local callback = method[2]
        local success, errorMessage =
            callback()
        if success then
            successfulMethods[
                #successfulMethods + 1
            ] = name
        elseif errorMessage then
            errors[#errors + 1] =
                name
                .. ": "
                .. tostring(errorMessage)
        end
    end
    State.antiAfkBusy = false
    State.nextAntiAfkPulseAt =
        os.clock()
        + (
            tonumber(State.antiAfkInterval)
            or 45
        )
    if #successfulMethods > 0 then
        State.antiAfkCount += 1
        State.lastAntiAfkAt = os.time()
        State.antiAfkMethod =
            table.concat(
                successfulMethods,
                " + "
            )
        State.lastAntiAfkError =
            #errors > 0
                and table.concat(
                    errors,
                    " | "
                )
                or nil
        AntiAfkRuntime.updateStatus(
            "Keep-alive input sent"
                .. (
                    source
                    and (
                        " • "
                        .. tostring(source)
                    )
                    or ""
                )
        )
        return true, State.antiAfkMethod
    end
    State.antiAfkMethod = "FAILED"
    State.lastAntiAfkError =
        #errors > 0
            and table.concat(
                errors,
                " | "
            )
            or "No supported virtual input method"
    AntiAfkRuntime.updateStatus(
        "All keep-alive methods failed."
    )
    return false, State.lastAntiAfkError
end
function AntiAfkRuntime.setEnabled(enabled)
    State.antiAfk = enabled == true
    State.nextAntiAfkPulseAt = 0
    if not State.antiAfk then
        State.antiAfkMethod = "disabled"
        State.lastAntiAfkError = nil
        AntiAfkRuntime.updateStatus(
            "Anti AFK disabled."
        )
    else
        AntiAfkRuntime.updateStatus(
            "Anti AFK enabled; testing all keep-alive methods."
        )
        task.defer(function()
            if State.running
                and State.antiAfk
            then
                AntiAfkRuntime.pulse(
                    "toggle",
                    false
                )
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
        "Available Codes: " .. tostring(#codes),
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
        Remotes.RedeemCode:FireServer(string.lower(code))
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
local VulnoneRuntime = {}
function VulnoneRuntime.normalizeStatus(payload)
    payload = type(payload) == "table" and payload or {}
    return {
        canAttemptFree = payload.canAttemptFree == true,
        hasCard = payload.hasCard == true,
        freeAttemptCooldown =
            math.max(
                0,
                tonumber(payload.freeAttemptCooldown) or 0
            ),
        cardExpiresIn =
            math.max(
                0,
                tonumber(payload.cardExpiresIn) or 0
            ),
    }
end
function VulnoneRuntime.refresh(force)
    if force ~= true
        and State.vulnoneStatus
        and os.clock() < State.vulnoneNextStatusAt
    then
        return true, State.vulnoneStatus
    end
    local success, payload = pcall(function()
        return Remotes.GetThroneStatus:InvokeServer()
    end)
    State.vulnoneNextStatusAt =
        os.clock() + State.vulnoneStatusRefreshInterval
    if not success or type(payload) ~= "table" then
        State.vulnoneFailures += 1
        State.vulnoneLastStatus =
            "Could not retrieve Vulnone status."
        VulnoneRuntime.updateUI()
        return false, tostring(payload)
    end
    State.vulnoneStatus =
        VulnoneRuntime.normalizeStatus(payload)
    return true, State.vulnoneStatus
end
function VulnoneRuntime.getState(force)
    local success, status =
        VulnoneRuntime.refresh(force == true)
    if success and type(status) == "table" then
        return status
    end
    return State.vulnoneStatus
        or VulnoneRuntime.normalizeStatus(nil)
end
function VulnoneRuntime.statusLabel(status)
    if status.hasCard then
        return "Card Owned"
    end
    if status.canAttemptFree then
        return "Ready"
    end
    if status.freeAttemptCooldown > 0 then
        return "Cooldown "
            .. formatDuration(status.freeAttemptCooldown)
    end
    return "Not Ready"
end
function VulnoneRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.vulnoneLastStatus = tostring(message)
        if shouldLog == true then
            LogRuntime.append(
                "Vulnone",
                State.vulnoneLastStatus
            )
        end
    end
    local status =
        State.vulnoneStatus
        or VulnoneRuntime.normalizeStatus(nil)
    local description = table.concat({
        "Auto Try: "
            .. (State.autoTryVulnoneCard and "ON" or "OFF"),
        "Availability: "
            .. VulnoneRuntime.statusLabel(status),
        "Card Expires In: "
            .. (
                status.hasCard
                    and formatDuration(status.cardExpiresIn)
                    or "-"
            ),
        "Pending: "
            .. (State.vulnonePending and "YES" or "NO"),
        "Attempts: " .. tostring(State.vulnoneAttempts),
        "Results: " .. tostring(State.vulnoneResults),
        "Wins: " .. tostring(State.vulnoneWins),
        "Losses: " .. tostring(State.vulnoneLosses),
        "Failures: " .. tostring(State.vulnoneFailures),
        "Last Result: " .. tostring(State.vulnoneLastResult),
        "Status: " .. tostring(State.vulnoneLastStatus),
    }, "\n")
    if State.vulnoneStatusParagraph
        and type(State.vulnoneStatusParagraph.SetDesc)
            == "function"
    then
        pcall(function()
            State.vulnoneStatusParagraph:SetDesc(description)
        end)
    end
end
function VulnoneRuntime.setAuto(enabled)
    State.autoTryVulnoneCard = enabled == true
    State.vulnoneNextStatusAt = 0
    State.vulnoneNextAttemptAt = 0
    VulnoneRuntime.updateUI(
        State.autoTryVulnoneCard
            and "Auto Try Vulnone Card enabled."
            or "Auto Try Vulnone Card disabled.",
        true
    )
    return State.autoTryVulnoneCard
end
function VulnoneRuntime.clearPending()
    State.vulnonePending = false
    State.vulnonePendingSince = 0
end
function VulnoneRuntime.attempt(force)
    if State.vulnonePending then
        return false, "A Vulnone attempt is still pending"
    end
    local now = os.clock()
    if force ~= true
        and now < State.vulnoneNextAttemptAt
    then
        return false, "Vulnone attempt is on cooldown"
    end
    local status = VulnoneRuntime.getState(true)
    if status.hasCard then
        VulnoneRuntime.updateUI(
            "Vulnone Card is already active."
        )
        return false, "Vulnone Card is already active"
    end
    if not status.canAttemptFree then
        local reason =
            status.freeAttemptCooldown > 0
            and (
                "Next free attempt in "
                .. formatDuration(
                    status.freeAttemptCooldown
                )
            )
            or "The free attempt is not ready"
        VulnoneRuntime.updateUI(reason)
        return false, reason
    end
    local success, errorMessage = pcall(function()
        Remotes.AttemptThrone:FireServer()
    end)
    if not success then
        State.vulnoneFailures += 1
        State.vulnoneNextAttemptAt =
            os.clock() + State.vulnoneRetryCooldown
        VulnoneRuntime.updateUI(
            "Could not submit the Vulnone attempt.",
            true
        )
        return false, tostring(errorMessage)
    end
    State.vulnonePending = true
    State.vulnonePendingSince = now
    State.vulnoneAttempts += 1
    State.vulnoneNextAttemptAt =
        now + State.vulnoneAttemptCooldown
    VulnoneRuntime.updateUI(
        "Vulnone attempt submitted."
    )
    return true, "Attempt submitted"
end
function VulnoneRuntime.handleResult(mode, payload)
    if tostring(mode or "") ~= "free" then
        return
    end
    payload = type(payload) == "table" and payload or {}
    VulnoneRuntime.clearPending()
    State.vulnoneResults += 1
    State.vulnoneNextStatusAt = 0
    State.vulnoneNextAttemptAt =
        os.clock() + State.vulnoneRetryCooldown
    if payload.won == true then
        State.vulnoneWins += 1
        State.vulnoneLastResult = "Won"
        VulnoneRuntime.updateUI(
            "Vulnone Card won.",
            true
        )
    else
        State.vulnoneLosses += 1
        State.vulnoneLastResult = "Lost"
        VulnoneRuntime.updateUI(
            "Vulnone attempt completed without a win.",
            true
        )
    end
    task.delay(1, function()
        if State.running then
            VulnoneRuntime.refresh(true)
            VulnoneRuntime.updateUI()
        end
    end)
end
function VulnoneRuntime.tick()
    if State.vulnonePending then
        if os.clock() - State.vulnonePendingSince
            >= State.vulnonePendingTimeout
        then
            VulnoneRuntime.clearPending()
            State.vulnoneFailures += 1
            State.vulnoneNextStatusAt = 0
            State.vulnoneNextAttemptAt =
                os.clock() + State.vulnoneRetryCooldown
            VulnoneRuntime.updateUI(
                "Vulnone result confirmation timed out.",
                true
            )
        else
            VulnoneRuntime.updateUI()
        end
        return
    end
    if State.autoTryVulnoneCard then
        local status = VulnoneRuntime.getState(false)
        if status.hasCard then
            VulnoneRuntime.updateUI(
                "Vulnone Card is already active."
            )
        elseif status.canAttemptFree
            and os.clock() >= State.vulnoneNextAttemptAt
        then
            VulnoneRuntime.attempt(false)
        else
            VulnoneRuntime.updateUI()
        end
    elseif State.vulnoneStatusParagraph then
        if os.clock() >= State.vulnoneNextStatusAt then
            VulnoneRuntime.refresh(true)
        end
        VulnoneRuntime.updateUI()
    end
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
    State.vulnoneNextStatusAt = 0
    State.vulnoneNextAttemptAt = 0
    VulnoneRuntime.clearPending()
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
        Remotes.DailyReward:FireServer("getState")
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
        Remotes.DailyReward:FireServer("claim")
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
local TournamentRuntime = {}
function TournamentRuntime.copyTeam(team)
    local result = {}
    if type(team) == "table" then
        for index = 1, 5 do
            local uuid = team[index]
            if uuid ~= nil then
                result[index] = tostring(uuid)
            end
        end
    end
    return result
end
function TournamentRuntime.teamCount(team)
    local count = 0
    for index = 1, 5 do
        if type(team) == "table" and team[index] ~= nil then
            count += 1
        end
    end
    return count
end
function TournamentRuntime.teamFingerprint(team)
    local parts = {}
    for index = 1, 5 do
        parts[index] = tostring(
            type(team) == "table" and team[index] or ""
        )
    end
    return table.concat(parts, "|")
end
function TournamentRuntime.getOwnedCards(playerData)
    local cards = {}
    local seen = {}
    local function add(card)
        if type(card) ~= "table" then
            return
        end
        local uuid = tostring(card.uuid or "")
        if uuid == "" or seen[uuid] then
            return
        end
        seen[uuid] = true
        cards[#cards + 1] = card
    end
    if type(playerData) == "table"
        and type(playerData.slots) == "table"
    then
        for _, slotData in pairs(playerData.slots) do
            add(
                type(slotData) == "table"
                    and slotData.card
                    or nil
            )
        end
    end
    if type(playerData) == "table"
        and type(playerData.inventory) == "table"
    then
        for _, card in ipairs(playerData.inventory) do
            add(card)
        end
    end
    return cards
end
function TournamentRuntime.getBestTeam(playerData)
    local cards = TournamentRuntime.getOwnedCards(playerData)
    local incomeMap = {}
    if #cards > 0 then
        local success, result = pcall(function()
            return Modules.ScalingIncome.computeBaseAll(cards)
        end)
        if success and type(result) == "table" then
            incomeMap = result
        end
    end
    table.sort(cards, function(left, right)
        local leftUuid = tostring(left.uuid or "")
        local rightUuid = tostring(right.uuid or "")
        local leftIncome = tonumber(incomeMap[leftUuid]) or 0
        local rightIncome = tonumber(incomeMap[rightUuid]) or 0
        if leftIncome == rightIncome then
            return leftUuid < rightUuid
        end
        return leftIncome > rightIncome
    end)
    local best = {}
    for index = 1, math.min(5, #cards) do
        best[index] = tostring(cards[index].uuid)
    end
    return best, incomeMap
end
function TournamentRuntime.getState()
    local playerData = getPlayerData()
    local tournamentData =
        type(playerData) == "table"
        and type(playerData.tournament) == "table"
        and playerData.tournament
        or {}
    local team = TournamentRuntime.copyTeam(tournamentData.team)
    local phase = "unknown"
    local secondsLeft = 0
    local queueWindowOpen = false
    local tickState = State.tournamentTickState
    if type(tickState) == "table" then
        local elapsed =
            os.clock()
            - (tonumber(tickState.receivedAtClock) or 0)
        secondsLeft = math.max(
            0,
            (tonumber(tickState.secondsLeftAtReceive) or 0)
                - elapsed
        )
        queueWindowOpen = tickState.open == true
        phase = queueWindowOpen and "join_window" or "countdown"
    else
        local success, derivedPhase, derivedSeconds =
            pcall(function()
                return Modules.TournamentClock.derivePhase(
                    Workspace:GetServerTimeNow()
                )
            end)
        if success then
            phase = tostring(derivedPhase or "unknown")
            secondsLeft = tonumber(derivedSeconds) or 0
            queueWindowOpen = phase == "join_window"
        end
    end
    local rebirth =
        tonumber(type(playerData) == "table" and playerData.rebirth)
        or 0
    local cash =
        tonumber(type(playerData) == "table" and playerData.cash)
        or 0
    local entryFee = 0
    local feeSuccess, feeResult = pcall(function()
        return Modules.TournamentClock.computeEntryFee(rebirth, cash)
    end)
    if feeSuccess then
        entryFee = tonumber(feeResult) or 0
    end
    local minRebirth =
        tonumber(Modules.TournamentConfig.MinRebirth) or 0
    return {
        ready = playerData ~= nil,
        playerData = playerData,
        tournamentData = tournamentData,
        team = team,
        teamCount = TournamentRuntime.teamCount(team),
        phase = phase,
        secondsLeft = secondsLeft,
        queueWindowOpen = queueWindowOpen,
        queued = tournamentData.queue ~= nil,
        rebirth = rebirth,
        minRebirth = minRebirth,
        unlocked = rebirth >= minRebirth,
        cash = cash,
        entryFee = entryFee,
        canAfford = cash >= entryFee,
    }
end
function TournamentRuntime.teamMatchesBest(team, best)
    if TournamentRuntime.teamCount(team) ~= 5 or #best < 5 then
        return false
    end
    local currentSet = {}
    local desiredSet = {}
    for index = 1, 5 do
        currentSet[tostring(team[index] or "")] = true
        desiredSet[tostring(best[index] or "")] = true
    end
    for uuid in pairs(desiredSet) do
        if not currentSet[uuid] then
            return false
        end
    end
    for uuid in pairs(currentSet) do
        if not desiredSet[uuid] then
            return false
        end
    end
    return true
end
function TournamentRuntime.getEquipSignature(data)
    data = type(data) == "table"
        and data
        or TournamentRuntime.getState()
    if not data.ready or not data.playerData then
        return nil
    end
    local best, incomeMap =
        TournamentRuntime.getBestTeam(data.playerData)
    if #best < 5 then
        return nil
    end
    local bestParts = {}
    for index = 1, 5 do
        local uuid = tostring(best[index] or "")
        bestParts[index] = table.concat({
            uuid,
            tostring(tonumber(incomeMap[uuid]) or 0),
        }, "=")
    end
    return table.concat({
        table.concat(bestParts, "|"),
        TournamentRuntime.teamFingerprint(data.team),
    }, "#")
end
function TournamentRuntime.markEquipCurrent(data)
    data = type(data) == "table"
        and data
        or TournamentRuntime.getState()
    local signature =
        TournamentRuntime.getEquipSignature(data)
    if not signature or data.teamCount ~= 5 then
        return false
    end
    State.tournamentLastEquipSignature = signature
    State.tournamentLastEquipTeamFingerprint =
        TournamentRuntime.teamFingerprint(data.team)
    return true
end
function TournamentRuntime.isEquipCurrent(data)
    data = type(data) == "table"
        and data
        or TournamentRuntime.getState()
    if data.teamCount ~= 5 or not data.playerData then
        return false
    end
    local best =
        TournamentRuntime.getBestTeam(data.playerData)
    if TournamentRuntime.teamMatchesBest(data.team, best) then
        TournamentRuntime.markEquipCurrent(data)
        return true
    end
    local signature =
        TournamentRuntime.getEquipSignature(data)
    return signature ~= nil
        and signature == State.tournamentLastEquipSignature
end
function TournamentRuntime.formatTime(seconds)
    local value = math.max(
        0,
        math.floor((tonumber(seconds) or 0) + 0.5)
    )
    return string.format(
        "%02d:%02d",
        math.floor(value / 60),
        value % 60
    )
end
function TournamentRuntime.pendingLabel()
    local pending = State.tournamentPendingAction
    if type(pending) ~= "table" then
        return "None"
    end
    local labels = {
        equip_best = "Equipping best team",
        join = "Joining queue",
    }
    return labels[pending.kind] or "Processing"
end
function TournamentRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.tournamentLastStatus = tostring(message)
        if shouldLog == true then
            LogRuntime.append(
                "Tournament",
                State.tournamentLastStatus
            )
        end
    end
    local data = TournamentRuntime.getState()
    local description = table.concat({
        "Auto Join: "
            .. (State.autoJoinTournament and "ON" or "OFF"),
        "Auto Equip Best: "
            .. (State.autoEquipBestTournament and "ON" or "OFF"),
        "Phase: "
            .. (
                data.queueWindowOpen
                    and "Join Open"
                    or (
                        data.phase == "countdown"
                            and "Countdown"
                            or "Waiting"
                    )
            ),
        "Time Left: "
            .. TournamentRuntime.formatTime(data.secondsLeft),
        "Queue: " .. (data.queued and "Joined" or "Not Joined"),
        "Team: " .. tostring(data.teamCount) .. "/5",
        "Best Team: "
            .. (
                TournamentRuntime.isEquipCurrent(data)
                    and "Ready"
                    or "Not Ready"
            ),
        "Entry Fee: $" .. formatCompactNumber(data.entryFee),
        "Cash: $" .. formatCompactNumber(data.cash),
        "Requirement: "
            .. (
                data.unlocked
                    and "Unlocked"
                    or ("Rebirth " .. tostring(data.minRebirth))
            ),
        "Pending: " .. TournamentRuntime.pendingLabel(),
        "Equip Requests: "
            .. tostring(State.tournamentEquipRequests),
        "Joins: " .. tostring(State.tournamentJoins),
        "Failures: " .. tostring(State.tournamentFailures),
        "Status: " .. tostring(State.tournamentLastStatus),
    }, "\n")
    if State.tournamentAutomationStatusParagraph
        and type(
            State.tournamentAutomationStatusParagraph.SetDesc
        ) == "function"
    then
        pcall(function()
            State.tournamentAutomationStatusParagraph:SetDesc(
                description
            )
        end)
    end
end
function TournamentRuntime.setAutoJoin(enabled)
    State.autoJoinTournament = enabled == true
    State.tournamentManualJoinRequested = false
    State.tournamentNextActionAt = 0
    TournamentRuntime.updateUI(
        State.autoJoinTournament
            and "Auto Join enabled."
            or "Auto Join disabled.",
        true
    )
    return State.autoJoinTournament
end
function TournamentRuntime.setAutoEquipBest(enabled)
    State.autoEquipBestTournament = enabled == true
    State.tournamentNextEquipAt = 0
    TournamentRuntime.updateUI(
        State.autoEquipBestTournament
            and "Auto Equip Best enabled."
            or "Auto Equip Best disabled.",
        true
    )
    return State.autoEquipBestTournament
end
function TournamentRuntime.setPending(kind, extra)
    extra = type(extra) == "table" and extra or {}
    extra.kind = kind
    extra.startedAt = os.clock()
    extra.beforeFingerprint =
        TournamentRuntime.teamFingerprint(
            TournamentRuntime.getState().team
        )
    State.tournamentPendingAction = extra
end
function TournamentRuntime.clearPending()
    State.tournamentPendingAction = nil
end
function TournamentRuntime.confirmPending()
    local pending = State.tournamentPendingAction
    if type(pending) ~= "table" then
        return false
    end
    local data = TournamentRuntime.getState()
    local confirmed = false
    local message
    if pending.kind == "equip_best" then
        local best = {}
        local teamFingerprint =
            TournamentRuntime.teamFingerprint(data.team)
        local elapsed =
            os.clock() - (tonumber(pending.startedAt) or 0)
        if data.playerData then
            best = TournamentRuntime.getBestTeam(data.playerData)
        end
        confirmed =
            data.teamCount == 5
            and (
                TournamentRuntime.teamMatchesBest(
                    data.team,
                    best
                )
                or teamFingerprint
                    ~= tostring(
                        pending.beforeFingerprint or ""
                    )
                or elapsed
                    >= State.tournamentEquipSettleDelay
            )
        message = "Best tournament team equipped."
    elseif pending.kind == "join" then
        confirmed = data.queued == true
        message = "Tournament queue joined."
        if confirmed then
            State.tournamentJoins += 1
            State.tournamentManualJoinRequested = false
        end
    end
    if confirmed then
        if pending.kind == "equip_best" then
            TournamentRuntime.markEquipCurrent(data)
        end
        TournamentRuntime.clearPending()
        TournamentRuntime.updateUI(message, true)
        return true
    end
    if os.clock() - (tonumber(pending.startedAt) or 0)
        >= State.tournamentPendingTimeout
    then
        State.tournamentFailures += 1
        TournamentRuntime.clearPending()
        TournamentRuntime.updateUI(
            "Tournament action was not confirmed.",
            true
        )
    end
    return false
end
function TournamentRuntime.equipBest(force)
    local now = os.clock()
    local data = TournamentRuntime.getState()
    if State.tournamentPendingAction then
        return false, "Another action is being processed"
    end
    if force ~= true and now < State.tournamentNextEquipAt then
        return false, "Equip Best is on cooldown"
    end
    if not data.ready then
        return false, "Player data is not ready"
    end
    local best = TournamentRuntime.getBestTeam(data.playerData)
    if #best < 5 then
        return false, "At least five cards are required"
    end
    if TournamentRuntime.isEquipCurrent(data) then
        TournamentRuntime.updateUI(
            "Best tournament team is already equipped."
        )
        return true, "Already equipped"
    end
    local currentSignature =
        TournamentRuntime.getEquipSignature(data)
    if force ~= true
        and currentSignature ~= nil
        and currentSignature
            == State.tournamentLastEquipSignature
    then
        TournamentRuntime.updateUI(
            "No tournament team changes detected."
        )
        return true, "No changes"
    end
    local success, errorMessage = pcall(function()
        Remotes.TournamentRemote:FireServer("equip_best")
    end)
    if not success then
        State.tournamentFailures += 1
        TournamentRuntime.updateUI(
            "Could not equip the best tournament team.",
            true
        )
        return false, tostring(errorMessage)
    end
    State.tournamentEquipRequests += 1
    State.tournamentNextEquipAt =
        now + State.tournamentEquipCooldown
    State.tournamentNextActionAt =
        now + State.tournamentActionDelay
    TournamentRuntime.setPending("equip_best", {
        requestedSignature = currentSignature,
    })
    TournamentRuntime.updateUI(
        "Equipping the best tournament team."
    )
    return true
end
function TournamentRuntime.sendJoin()
    local data = TournamentRuntime.getState()
    if State.tournamentPendingAction
        or os.clock() < State.tournamentNextActionAt
    then
        return false, "Another action is being processed"
    end
    if data.queued then
        State.tournamentManualJoinRequested = false
        return true, "Already queued"
    end
    if not data.unlocked then
        return false, "Tournament is locked"
    end
    if not data.queueWindowOpen then
        return false, "Join window is closed"
    end
    if not data.canAfford then
        TournamentRuntime.updateUI(
            "Not enough cash for the entry fee."
        )
        return false, "Not enough cash"
    end
    if data.teamCount ~= 5 then
        return false, "Tournament team is not ready"
    end
    local success, errorMessage = pcall(function()
        Remotes.TournamentRemote:FireServer("join")
    end)
    if not success then
        State.tournamentFailures += 1
        TournamentRuntime.updateUI(
            "Could not join the tournament queue.",
            true
        )
        return false, tostring(errorMessage)
    end
    State.tournamentJoinRequests += 1
    State.tournamentNextActionAt =
        os.clock() + State.tournamentActionDelay
    TournamentRuntime.setPending("join")
    TournamentRuntime.updateUI(
        "Joining the tournament queue."
    )
    return true
end
function TournamentRuntime.requestManualJoin()
    local data = TournamentRuntime.getState()
    if data.queued then
        return true, "Already queued"
    end
    if not data.queueWindowOpen then
        TournamentRuntime.updateUI(
            "Tournament join window is closed."
        )
        return false, "Join window is closed"
    end
    if not data.unlocked then
        return false, "Tournament is locked"
    end
    State.tournamentManualJoinRequested = true
    State.tournamentNextActionAt = 0
    TournamentRuntime.updateUI(
        "Equipping the best team before joining.",
        true
    )
    return true
end
function TournamentRuntime.runJoinStep()
    local data = TournamentRuntime.getState()
    if data.queued then
        State.tournamentManualJoinRequested = false
        TournamentRuntime.updateUI()
        return
    end
    if not data.ready then
        TournamentRuntime.updateUI(
            "Player data is not ready yet."
        )
        return
    end
    if not data.unlocked then
        State.tournamentManualJoinRequested = false
        TournamentRuntime.updateUI(
            "Tournament is not unlocked yet."
        )
        return
    end
    local best =
        TournamentRuntime.getBestTeam(data.playerData)
    if #best < 5 then
        State.tournamentManualJoinRequested = false
        TournamentRuntime.updateUI(
            "At least five cards are required."
        )
        return
    end
    local teamReady =
        TournamentRuntime.isEquipCurrent(data)
    if not teamReady then
        if os.clock() >= State.tournamentNextEquipAt then
            TournamentRuntime.equipBest(false)
        else
            TournamentRuntime.updateUI(
                "Waiting to equip the best tournament team."
            )
        end
        return
    end
    if not data.queueWindowOpen then
        if State.tournamentManualJoinRequested then
            State.tournamentManualJoinRequested = false
            TournamentRuntime.updateUI(
                "Tournament join window is closed.",
                true
            )
        else
            TournamentRuntime.updateUI(
                "Best team ready. Waiting for the join window."
            )
        end
        return
    end
    TournamentRuntime.sendJoin()
end
function TournamentRuntime.tick()
    if State.tournamentPendingAction then
        TournamentRuntime.confirmPending()
        TournamentRuntime.updateUI()
        return
    end
    local data = TournamentRuntime.getState()
    if data.queued then
        State.tournamentManualJoinRequested = false
        TournamentRuntime.updateUI()
        return
    end
    if State.autoJoinTournament
        or State.tournamentManualJoinRequested
    then
        TournamentRuntime.runJoinStep()
        return
    end
    if State.autoEquipBestTournament
        and os.clock() >= State.tournamentNextEquipAt
    then
        TournamentRuntime.equipBest(false)
        return
    end
    TournamentRuntime.updateUI()
end
function TournamentRuntime.handleTick(payload)
    if type(payload) ~= "table" then
        return
    end
    State.tournamentTickState = {
        open = payload.queueWindowOpen == true,
        secondsLeftAtReceive =
            tonumber(payload.secondsLeft) or 0,
        receivedAtClock = os.clock(),
    }
    TournamentRuntime.updateUI()
end
local PackBuyRuntime = {}
function PackBuyRuntime.getPlayerData()
    local playerData = getPlayerData()
    if type(playerData) ~= "table" then
        return nil
    end
    return playerData
end
function PackBuyRuntime.getPackState(packName, playerData)
    playerData = playerData or PackBuyRuntime.getPlayerData()
    local packData = Modules.PackConfig.Packs[packName]
    if type(packData) ~= "table"
        or type(playerData) ~= "table"
    then
        return nil
    end
    local stocks =
        type(playerData.shop) == "table"
        and type(playerData.shop.stocks) == "table"
        and playerData.shop.stocks
        or {}
    local purchaseCounts =
        type(playerData.packPurchaseCounts) == "table"
        and playerData.packPurchaseCounts
        or {}
    local nativeMap =
        type(playerData.autoBuyPacks) == "table"
        and playerData.autoBuyPacks
        or {}
    local purchaseCount =
        math.max(
            0,
            math.floor(
                tonumber(purchaseCounts[packName]) or 0
            )
        )
    return {
        name = packName,
        label = PackBuyLabelByName[packName] or packName,
        config = packData,
        price = math.max(0, tonumber(packData.Price) or 0),
        rebirthRequired =
            math.max(0, tonumber(packData.RebirthReq) or 0),
        rebirth = math.max(
            0,
            tonumber(playerData.rebirth) or 0
        ),
        cash = math.max(0, tonumber(playerData.cash) or 0),
        stock = math.max(
            0,
            math.floor(tonumber(stocks[packName]) or 0)
        ),
        purchaseCount = purchaseCount,
        unlockRemaining = math.max(0, 5 - purchaseCount),
        nativeUnlocked = purchaseCount >= 5,
        nativeEnabled = nativeMap[packName] == true,
    }
end
function PackBuyRuntime.countSelected()
    local count = 0
    for _, packName in ipairs(PackBuyNames) do
        if State.packBuyWhitelist[packName] then
            count += 1
        end
    end
    return count
end
function PackBuyRuntime.getSelectedLabels()
    local labels = {}
    for _, packName in ipairs(PackBuyNames) do
        if State.packBuyWhitelist[packName] then
            labels[#labels + 1] =
                PackBuyLabelByName[packName] or packName
        end
    end
    return labels
end
function PackBuyRuntime.nameFromSelection(value)
    value = normalizeSelectedValue(value)
    if value == nil then
        return nil
    end
    local normalized = tostring(value)
    if PackBuyNameByLabel[normalized] then
        return PackBuyNameByLabel[normalized]
    end
    if PackBuyLabelByName[normalized] then
        return normalized
    end
    return nil
end
function PackBuyRuntime.syncWhitelistDropdown()
    if not State.packBuyWhitelistDropdown
        or type(State.packBuyWhitelistDropdown.Select)
            ~= "function"
    then
        return
    end
    pcall(function()
        State.packBuyWhitelistDropdown:Select(
            PackBuyRuntime.getSelectedLabels()
        )
    end)
end
function PackBuyRuntime.applyWhitelistSelection(selectedValues)
    local selected = {}
    local function enable(value)
        local packName =
            PackBuyRuntime.nameFromSelection(value)
        if packName then
            selected[packName] = true
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
    table.clear(State.packBuyWhitelist)
    for _, packName in ipairs(PackBuyNames) do
        State.packBuyWhitelist[packName] =
            selected[packName] == true
    end
    State.packBuyNextAt = 0
    PackBuyRuntime.updateUI(
        "Pack whitelist updated.",
        true
    )
end
function PackBuyRuntime.setAll(enabled)
    for _, packName in ipairs(PackBuyNames) do
        State.packBuyWhitelist[packName] =
            enabled == true
    end
    State.packBuyNextAt = 0
    PackBuyRuntime.syncWhitelistDropdown()
    PackBuyRuntime.updateUI(
        enabled
            and "All eligible packs selected."
            or "Pack whitelist cleared.",
        true
    )
end
function PackBuyRuntime.getSummary()
    local playerData = PackBuyRuntime.getPlayerData()
    local summary = {
        selected = 0,
        unlocked = 0,
        locked = 0,
        nativeEnabled = 0,
        readyToUnlock = 0,
    }
    if not playerData then
        return summary
    end
    for _, packName in ipairs(PackBuyNames) do
        local packState =
            PackBuyRuntime.getPackState(
                packName,
                playerData
            )
        if packState then
            if packState.nativeEnabled then
                summary.nativeEnabled += 1
            end
            if State.packBuyWhitelist[packName] then
                summary.selected += 1
                if packState.nativeUnlocked then
                    summary.unlocked += 1
                else
                    summary.locked += 1
                    if packState.rebirth
                            >= packState.rebirthRequired
                        and packState.stock > 0
                        and packState.cash >= packState.price
                    then
                        summary.readyToUnlock += 1
                    end
                end
            end
        end
    end
    return summary
end
function PackBuyRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.packBuyLastStatus = tostring(message)
        if shouldLog == true then
            LogRuntime.append(
                "Packs",
                State.packBuyLastStatus
            )
        end
    end
    local summary = PackBuyRuntime.getSummary()
    local pending = State.packBuyPending
    local pendingText = "None"
    if type(pending) == "table" then
        pendingText =
            tostring(pending.kind or "Action")
            .. " • "
            .. tostring(
                PackBuyLabelByName[pending.packName]
                or pending.packName
                or "-"
            )
    end
    local description = table.concat({
        "Direct Auto Buy: "
            .. (State.autoBuyPacks and "ON" or "OFF"),
        "Native Auto Buy Sync: "
            .. (
                State.autoEnableNativeBuyPacks
                    and "ON"
                    or "OFF"
            ),
        "Whitelist: "
            .. tostring(summary.selected)
            .. "/"
            .. tostring(#PackBuyNames),
        "Native Unlocked: "
            .. tostring(summary.unlocked),
        "Unlock Progress Needed: "
            .. tostring(summary.locked),
        "Ready to Purchase: "
            .. tostring(summary.readyToUnlock),
        "Native Checkboxes ON: "
            .. tostring(summary.nativeEnabled),
        "Pending: " .. pendingText,
        "Purchase Requests: "
            .. tostring(State.packBuyRequests),
        "Confirmed Purchases: "
            .. tostring(State.packBuyPurchases),
        "Checkbox Updates: "
            .. tostring(State.packBuyNativeUpdates),
        "Failures: " .. tostring(State.packBuyFailures),
        "Last Pack: " .. tostring(State.packBuyLastItem),
        "Status: " .. tostring(State.packBuyLastStatus),
    }, "\n")
    if State.packBuyStatusParagraph
        and type(State.packBuyStatusParagraph.SetDesc)
            == "function"
    then
        pcall(function()
            State.packBuyStatusParagraph:SetDesc(description)
        end)
    end
end
function PackBuyRuntime.setAuto(enabled)
    State.autoBuyPacks = enabled == true
    State.packBuyNextAt = 0
    PackBuyRuntime.updateUI(
        State.autoBuyPacks
            and "Direct Auto Buy Packs enabled."
            or "Direct Auto Buy Packs disabled.",
        true
    )
    return State.autoBuyPacks
end
function PackBuyRuntime.setAutoNative(enabled)
    State.autoEnableNativeBuyPacks =
        enabled == true
    State.packBuyNextAt = 0
    PackBuyRuntime.updateUI(
        State.autoEnableNativeBuyPacks
            and "Native Auto Buy synchronization enabled."
            or "Native Auto Buy synchronization disabled.",
        true
    )
    return State.autoEnableNativeBuyPacks
end
function PackBuyRuntime.setPending(kind, packName, data)
    data = type(data) == "table" and data or {}
    data.kind = kind
    data.packName = packName
    data.startedAt = os.clock()
    State.packBuyPending = data
end
function PackBuyRuntime.clearPending()
    State.packBuyPending = nil
end
function PackBuyRuntime.confirmPending()
    local pending = State.packBuyPending
    if type(pending) ~= "table" then
        return false
    end
    local playerData = PackBuyRuntime.getPlayerData()
    local packState = playerData
        and PackBuyRuntime.getPackState(
            pending.packName,
            playerData
        )
    if packState then
        local confirmed = false
        if pending.kind == "Native" then
            confirmed =
                packState.nativeEnabled
                == (pending.desired == true)
        elseif pending.kind == "Purchase" then
            confirmed =
                packState.purchaseCount
                    > (tonumber(pending.beforeCount) or 0)
                or packState.stock
                    < (tonumber(pending.beforeStock) or 0)
        end
        if confirmed then
            if pending.kind == "Native" then
                State.packBuyNativeUpdates += 1
                State.packNativeManaged[
                    pending.packName
                ] = pending.desired == true
                    and true
                    or nil
                State.packBuyLastStatus =
                    (pending.desired and "Enabled " or "Disabled ")
                    .. "native Auto Buy for "
                    .. packState.label
                    .. "."
            else
                State.packBuyPurchases += 1
                State.packBuyLastStatus =
                    "Purchased "
                    .. packState.label
                    .. " through direct Auto Buy."
            end
            State.packBuyLastItem = packState.label
            PackBuyRuntime.clearPending()
            State.packBuyNextAt =
                os.clock() + State.packBuyActionCooldown
            PackBuyRuntime.updateUI(
                State.packBuyLastStatus,
                true
            )
            return true
        end
    end
    if os.clock() - (tonumber(pending.startedAt) or 0)
        >= State.packBuyPendingTimeout
    then
        local label =
            PackBuyLabelByName[pending.packName]
            or tostring(pending.packName or "-")
        PackBuyRuntime.clearPending()
        State.packBuyFailures += 1
        State.packBuyNextAt =
            os.clock() + State.packBuyRetryCooldown
        PackBuyRuntime.updateUI(
            tostring(pending.kind)
                .. " confirmation timed out for "
                .. label
                .. ".",
            true
        )
        return true
    end
    PackBuyRuntime.updateUI()
    return true
end
function PackBuyRuntime.sendNative(packState, desired)
    if State.packBuyPending then
        return false, "Another pack action is pending"
    end
    local success, errorMessage = pcall(function()
        Remotes.SetAutoBuyPackRemote:FireServer(
            packState.name,
            desired == true
        )
    end)
    if not success then
        State.packBuyFailures += 1
        State.packBuyNextAt =
            os.clock() + State.packBuyRetryCooldown
        PackBuyRuntime.updateUI(
            "Could not update the native Auto Buy checkbox.",
            true
        )
        return false, tostring(errorMessage)
    end
    State.packBuyRequests += 1
    State.packBuyLastItem = packState.label
    State.packBuyNextAt =
        os.clock() + State.packBuyActionCooldown
    PackBuyRuntime.setPending(
        "Native",
        packState.name,
        {
            desired = desired == true,
        }
    )
    PackBuyRuntime.updateUI(
        (desired and "Enabling " or "Disabling ")
            .. "native Auto Buy for "
            .. packState.label
            .. "."
    )
    return true
end
function PackBuyRuntime.sendPurchase(packState)
    if State.packBuyPending then
        return false, "Another pack action is pending"
    end
    if packState.rebirth < packState.rebirthRequired then
        return false,
            "Requires Rebirth "
                .. tostring(packState.rebirthRequired)
    end
    if packState.stock <= 0 then
        return false, "Pack is out of stock"
    end
    if packState.cash < packState.price then
        return false, "Not enough cash"
    end
    local success, errorMessage = pcall(function()
        Remotes.BuyPackRemote:FireServer(packState.name)
    end)
    if not success then
        State.packBuyFailures += 1
        State.packBuyNextAt =
            os.clock() + State.packBuyRetryCooldown
        PackBuyRuntime.updateUI(
            "Could not purchase " .. packState.label .. ".",
            true
        )
        return false, tostring(errorMessage)
    end
    State.packBuyRequests += 1
    State.packBuyLastItem = packState.label
    State.packBuyNextAt =
        os.clock() + State.packBuyActionCooldown
    PackBuyRuntime.setPending(
        "Purchase",
        packState.name,
        {
            beforeCount = packState.purchaseCount,
            beforeStock = packState.stock,
        }
    )
    PackBuyRuntime.updateUI(
        "Purchasing "
            .. packState.label
            .. " through direct Auto Buy."
    )
    return true
end
function PackBuyRuntime.findNativeMismatch(playerData)
    for _, packName in ipairs(PackBuyNames) do
        local packState =
            PackBuyRuntime.getPackState(
                packName,
                playerData
            )
        if packState and packState.nativeUnlocked then
            local selected =
                State.packBuyWhitelist[packName] == true
            local desired =
                State.autoEnableNativeBuyPacks
                and selected
            local managed =
                State.packNativeManaged[packName] == true
            if desired and packState.nativeEnabled then
                State.packNativeManaged[packName] = true
            elseif desired
                and not packState.nativeEnabled
            then
                return packState, true
            elseif managed
                and not desired
                and packState.nativeEnabled
            then
                return packState, false
            elseif managed
                and not packState.nativeEnabled
            then
                State.packNativeManaged[packName] = nil
            end
        end
    end
    return nil
end
function PackBuyRuntime.findDirectPurchase(playerData)
    local selected = {}
    local firstReason
    for _, packName in ipairs(PackBuyNames) do
        if State.packBuyWhitelist[packName] then
            selected[#selected + 1] = packName
        end
    end
    if #selected == 0 then
        return nil, "Pack whitelist is empty"
    end
    local start =
        (State.packBuyCursor % #selected) + 1
    for offset = 0, #selected - 1 do
        local index =
            ((start + offset - 1) % #selected) + 1
        local packName = selected[index]
        local packState =
            PackBuyRuntime.getPackState(
                packName,
                playerData
            )
        if packState then
            if packState.nativeEnabled then
                firstReason = firstReason
                    or (
                        packState.label
                        .. " is handled by native Auto Buy"
                    )
            elseif packState.rebirth
                    < packState.rebirthRequired
            then
                firstReason = firstReason
                    or (
                        packState.label
                        .. " requires Rebirth "
                        .. tostring(
                            packState.rebirthRequired
                        )
                    )
            elseif packState.stock <= 0 then
                firstReason = firstReason
                    or (
                        packState.label
                        .. " is out of stock"
                    )
            elseif packState.cash < packState.price then
                firstReason = firstReason
                    or (
                        "Not enough cash for "
                        .. packState.label
                    )
            else
                State.packBuyCursor = index
                return packState
            end
        end
    end
    return nil, firstReason
end
function PackBuyRuntime.process(force)
    if PackBuyRuntime.confirmPending() then
        return false, "Waiting for confirmation"
    end
    if force ~= true
        and os.clock() < State.packBuyNextAt
    then
        return false, "Pack buying is on cooldown"
    end
    local playerData = PackBuyRuntime.getPlayerData()
    if not playerData then
        PackBuyRuntime.updateUI(
            "Player data is not ready."
        )
        return false, "Player data is not ready"
    end
    local mismatch, desired =
        PackBuyRuntime.findNativeMismatch(playerData)
    if mismatch then
        return PackBuyRuntime.sendNative(
            mismatch,
            desired
        )
    end
    if not State.autoBuyPacks then
        PackBuyRuntime.updateUI(
            State.autoEnableNativeBuyPacks
                and "Native Auto Buy checkboxes are synchronized."
                or "Pack buying automation is disabled."
        )
        return false, "Direct Auto Buy Packs is disabled"
    end
    if PackBuyRuntime.countSelected() <= 0 then
        PackBuyRuntime.updateUI(
            "Choose at least one pack from the whitelist."
        )
        return false, "Pack whitelist is empty"
    end
    local packState, reason =
        PackBuyRuntime.findDirectPurchase(playerData)
    if packState then
        return PackBuyRuntime.sendPurchase(packState)
    end
    PackBuyRuntime.updateUI(
        reason
        or "No selected pack can be purchased."
    )
    return false, reason or "No pack can be purchased"
end
function PackBuyRuntime.disableManagedNative()
    local playerData = PackBuyRuntime.getPlayerData()
    if not playerData then
        return
    end
    for packName in pairs(State.packNativeManaged) do
        local packState =
            PackBuyRuntime.getPackState(
                packName,
                playerData
            )
        if packState
            and packState.nativeUnlocked
            and packState.nativeEnabled
        then
            pcall(function()
                Remotes.SetAutoBuyPackRemote:FireServer(
                    packName,
                    false
                )
            end)
        end
    end
    table.clear(State.packNativeManaged)
end
function PackBuyRuntime.tick()
    if State.packBuyPending then
        PackBuyRuntime.confirmPending()
        return
    end
    if State.autoBuyPacks
        or State.autoEnableNativeBuyPacks
        or next(State.packNativeManaged) ~= nil
    then
        PackBuyRuntime.process(false)
    elseif State.packBuyStatusParagraph then
        PackBuyRuntime.updateUI()
    end
end
local PackRuntime = {}
function PackRuntime.syncToggle(toggle, value)
    if toggle and type(toggle.Set) == "function" then
        pcall(function()
            toggle:Set(value == true, false)
        end)
    end
end
function PackRuntime.isAnimating()
    local success, result = pcall(function()
        return Modules.PackAnimationController.isAnimating()
    end)
    return success and result == true
end
function PackRuntime.getUpvalueAccess()
    local getter
    local setter
    if type(debug) == "table"
        and type(debug.getupvalue) == "function"
    then
        getter = debug.getupvalue
    elseif type(getupvalue) == "function" then
        getter = getupvalue
    end
    if type(debug) == "table"
        and type(debug.setupvalue) == "function"
    then
        setter = debug.setupvalue
    elseif type(setupvalue) == "function" then
        setter = setupvalue
    end
    return getter, setter
end
function PackRuntime.setLocalHideMode(enabled)
    enabled = enabled == true
    local callback =
        Modules.PackAnimationController.isMinimized
    local getter, setter =
        PackRuntime.getUpvalueAccess()
    if type(callback) ~= "function"
        or not getter
        or not setter
    then
        State.packLocalHideAvailable = false
        State.packLocalHideApplied = false
        return false, "Local hide access is unavailable"
    end
    for index = 1, 12 do
        local success, first, second =
            pcall(getter, callback, index)
        if not success then
            break
        end
        if first == nil and second == nil then
            break
        end
        local value =
            second ~= nil and second or first
        if type(value) == "boolean" then
            local applied = pcall(
                setter,
                callback,
                index,
                enabled
            )
            if applied then
                local verified, current =
                    pcall(callback)
                if verified and current == enabled then
                    State.packLocalHideAvailable = true
                    State.packLocalHideApplied = enabled
                    return true
                end
            end
        end
    end
    State.packLocalHideAvailable = false
    State.packLocalHideApplied = false
    State.packLocalHideFailures += 1
    return false, "Could not update local hide mode"
end
function PackRuntime.captureCurrentUi()
    local current
    pcall(function()
        current = Modules.UIService.getCurrentUI()
    end)
    if current ~= nil
        and tostring(current) ~= "__PackAnim"
    then
        State.packPreservedUi = current
    elseif current == nil then
        State.packPreservedUi = nil
    end
    return current
end
function PackRuntime.releaseInputBlock()
    local current
    pcall(function()
        current = Modules.UIService.getCurrentUI()
    end)
    if tostring(current) == "__PackAnim" then
        pcall(function()
            Modules.UIService.setBlocked(false)
        end)
        pcall(function()
            Modules.UIService.close(
                "__PackAnim",
                true
            )
        end)
        local afterClose
        pcall(function()
            afterClose =
                Modules.UIService.getCurrentUI()
        end)
        if afterClose == nil
            and State.packPreservedUi ~= nil
        then
            local restored = pcall(function()
                Modules.UIService.open(
                    State.packPreservedUi
                )
            end)
            if restored then
                State.packRestoredUiCount += 1
            end
        end
    elseif current == nil then
        pcall(function()
            Modules.UIService.setBlocked(false)
        end)
    end
    pcall(function()
        game:GetService("StarterGui")
            :SetCoreGuiEnabled(
                Enum.CoreGuiType.Chat,
                true
            )
    end)
end
function PackRuntime.resetControllerState()
    State.packOpenPending = nil
    State.packCurrentContext = nil
    State.packNextOpenAt = 0
    State.packAnimationStaleSince = 0
    State.packAutomationGeneration += 1
    _G.isOpeningPack = false
    pcall(function()
        Modules.PackAnimationController.setAutoOpen(false)
    end)
    local success = pcall(function()
        Modules.PackAnimationController.resetEverything()
    end)
    if success then
        State.packControllerResets += 1
    else
        State.packOpenFailures += 1
    end
    PackRuntime.setLocalHideMode(
        State.skipPackAnimations
    )
    local playerGui =
        LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local root =
        playerGui
        and playerGui:FindFirstChild("PackOpeningUI")
    if root and root.Enabled then
        root.Enabled = false
    end
    PackRuntime.releaseInputBlock()
    return success
end
function PackRuntime.restartAutomation()
    PackRuntime.resetControllerState()
    if not State.autoOpenPacks then
        return false, "Auto Open Available Packs is disabled"
    end
    pcall(function()
        Modules.PackAnimationController.setAutoOpen(true)
    end)
    State.packNextOpenAt = 0
    State.packLastStatus =
        "Pack automation restarted."
    local generation =
        State.packAutomationGeneration
    task.delay(0.15, function()
        if State.running
            and State.autoOpenPacks
            and generation
                == State.packAutomationGeneration
            and not PackRuntime.isAnimating()
        then
            PackRuntime.requestOpen(nil, false)
        end
    end)
    return true
end
function PackRuntime.suppressPackUI(root)
    if typeof(root) ~= "Instance"
        or root.Name ~= "PackOpeningUI"
    then
        return false
    end
    if not State.skipPackAnimations then
        return false
    end
    local changed = root.Enabled == true
    if changed then
        root.Enabled = false
        State.packUiSuppressCount += 1
    end
    PackRuntime.releaseInputBlock()
    return changed
end
function PackRuntime.watchPackUI(root)
    if typeof(root) ~= "Instance"
        or root.Name ~= "PackOpeningUI"
    then
        return
    end
    if State.packWatchedUis[root] then
        PackRuntime.suppressPackUI(root)
        return
    end
    State.packWatchedUis[root] = true
    PackRuntime.suppressPackUI(root)
    root:GetPropertyChangedSignal("Enabled")
        :Connect(function()
            if State.running
                and State.skipPackAnimations
                and root.Parent
                and root.Enabled
            then
                PackRuntime.suppressPackUI(root)
            end
        end)
end
function PackRuntime.installUiSuppressor()
    local playerGui =
        LocalPlayer:FindFirstChildOfClass("PlayerGui")
        or LocalPlayer:WaitForChild("PlayerGui")
    local existing =
        playerGui:FindFirstChild("PackOpeningUI")
    if existing then
        PackRuntime.watchPackUI(existing)
    end
    if State.packUiChildConnection then
        return true
    end
    State.packUiChildConnection =
        playerGui.ChildAdded:Connect(function(child)
            if child.Name == "PackOpeningUI" then
                PackRuntime.watchPackUI(child)
            end
        end)
    return true
end
function PackRuntime.getSelectedRarities()
    local result = {}
    for _, rarity in ipairs(PackLogOptions.names) do
        if State.packResultRarityWhitelist[rarity] then
            result[#result + 1] = rarity
        end
    end
    return result
end
function PackRuntime.countSelectedRarities()
    return #PackRuntime.getSelectedRarities()
end
function PackRuntime.syncRarityDropdown()
    local dropdown = State.packResultRarityDropdown
    if not dropdown then
        return
    end
    if type(dropdown.Refresh) == "function" then
        local success = pcall(function()
            dropdown:Refresh(PackLogOptions.names)
        end)
        if not success then
            pcall(function()
                dropdown:Refresh({
                    Values = PackLogOptions.names,
                })
            end)
        end
    end
    if type(dropdown.Select) == "function" then
        pcall(function()
            dropdown:Select(
                PackRuntime.getSelectedRarities()
            )
        end)
    end
end
function PackRuntime.applyRaritySelection(values)
    local selected = {}
    local function enable(value)
        local normalized = normalizeSelectedValue(value)
        if normalized == nil then
            return
        end
        local rarity = tostring(normalized)
        if table.find(PackLogOptions.names, rarity) then
            selected[rarity] = true
        end
    end
    if type(values) == "table" then
        for key, value in pairs(values) do
            if type(key) == "number" then
                enable(value)
            elseif value == true then
                enable(key)
            elseif type(value) == "table" then
                enable(value)
            end
        end
        if values.Title then
            enable(values)
        end
    elseif values ~= nil then
        enable(values)
    end
    table.clear(State.packResultRarityWhitelist)
    for _, rarity in ipairs(PackLogOptions.names) do
        State.packResultRarityWhitelist[rarity] =
            selected[rarity] == true
    end
    PackRuntime.updateUI(
        "Pack result rarity filter updated."
    )
    PackRuntime.updateResultUI()
end
function PackRuntime.setAllRarities(enabled)
    for _, rarity in ipairs(PackLogOptions.names) do
        State.packResultRarityWhitelist[rarity] =
            enabled == true
    end
    PackRuntime.syncRarityDropdown()
    PackRuntime.updateUI(
        enabled
            and "All pack result rarities selected."
            or "Pack result rarity filter cleared."
    )
    PackRuntime.updateResultUI()
end
function PackRuntime.getPlayerData()
    local playerData = getPlayerData()
    if type(playerData) ~= "table" then
        return nil
    end
    return playerData
end
function PackRuntime.getPacks(playerData)
    playerData = playerData or PackRuntime.getPlayerData()
    if type(playerData) ~= "table"
        or type(playerData.packs) ~= "table"
    then
        return {}
    end
    return playerData.packs
end
function PackRuntime.getTotalPackCount(playerData)
    local total = 0
    for _, amount in pairs(
        PackRuntime.getPacks(playerData)
    ) do
        total += math.max(
            0,
            math.floor(tonumber(amount) or 0)
        )
    end
    return total
end
function PackRuntime.getPackCount(packName, playerData)
    return math.max(
        0,
        math.floor(
            tonumber(
                PackRuntime.getPacks(playerData)[packName]
            ) or 0
        )
    )
end
function PackRuntime.selectNextPack(playerData)
    playerData = playerData or PackRuntime.getPlayerData()
    if not playerData then
        return nil
    end
    local packs = PackRuntime.getPacks(playerData)
    local lastOpened =
        tostring(playerData.lastOpenedPack or "")
    if lastOpened ~= ""
        and PackRuntime.getPackCount(
            lastOpened,
            playerData
        ) > 0
    then
        return lastOpened
    end
    local bestName
    local bestPrice = math.huge
    for packName, rawAmount in pairs(packs) do
        local amount =
            math.max(
                0,
                math.floor(tonumber(rawAmount) or 0)
            )
        if amount > 0 then
            local config =
                Modules.PackConfig.Packs[packName]
            local price =
                type(config) == "table"
                and tonumber(config.Price)
                or 0
            price = price or 0
            if price < bestPrice
                or (
                    price == bestPrice
                    and (
                        bestName == nil
                        or tostring(packName)
                            < tostring(bestName)
                    )
                )
            then
                bestName = tostring(packName)
                bestPrice = price
            end
        end
    end
    return bestName
end
function PackRuntime.canCarryMore(playerData)
    playerData = playerData or PackRuntime.getPlayerData()
    if not playerData then
        return false, 0, 0
    end
    local inventory =
        type(playerData.inventory) == "table"
        and playerData.inventory
        or {}
    local capacity = 200
    local success, hasPass = pcall(function()
        return Modules.PurchaseClient.hasGamepass(
            1688238039
        )
    end)
    if success and hasPass == true then
        capacity += 500
    end
    return #inventory < capacity, #inventory, capacity
end
function PackRuntime.findCardByUuid(uuid)
    uuid = tostring(uuid or "")
    if uuid == "" then
        return nil
    end
    local playerData = PackRuntime.getPlayerData()
    if not playerData then
        return nil
    end
    if type(playerData.inventory) == "table" then
        for _, card in ipairs(playerData.inventory) do
            if type(card) == "table"
                and tostring(
                    card.uuid
                    or card.UUID
                    or card.id
                    or ""
                ) == uuid
            then
                return card
            end
        end
    end
    if type(playerData.slots) == "table" then
        for _, slotData in pairs(playerData.slots) do
            local card =
                type(slotData) == "table"
                and slotData.card
                or nil
            if type(card) == "table"
                and tostring(
                    card.uuid
                    or card.UUID
                    or card.id
                    or ""
                ) == uuid
            then
                return card
            end
        end
    end
    return nil
end
function PackRuntime.resolveCard(cardData, packName)
    cardData = type(cardData) == "table"
        and cardData
        or {}
    local cardId = tostring(
        cardData.id
        or cardData.Id
        or cardData.Name
        or cardData.cardId
        or "Unknown"
    )
    local config =
        type(Modules.CardConfig.Cards) == "table"
        and Modules.CardConfig.Cards[cardId]
        or nil
    if type(config) ~= "table"
        and type(cardData.Data) == "table"
    then
        config = cardData.Data
    end
    config = type(config) == "table" and config or {}
    local displayName = tostring(
        cardData.DisplayName
        or config.DisplayName
        or cardData.Name
        or config.Name
        or cardId
    )
    local rarity = tostring(
        cardData.Rarity
        or config.Rarity
        or "Unknown"
    )
    local mutations = {}
    local rawMutations =
        cardData.mutations
        or cardData.Mutations
        or cardData.mutation
        or cardData.Mutation
    if type(rawMutations) == "table" then
        for key, value in pairs(rawMutations) do
            if type(key) == "number"
                and value ~= nil
            then
                mutations[#mutations + 1] =
                    tostring(value)
            elseif value == true then
                mutations[#mutations + 1] =
                    tostring(key)
            elseif type(value) == "string"
                or type(value) == "number"
            then
                mutations[#mutations + 1] =
                    tostring(value)
            end
        end
    elseif rawMutations ~= nil then
        mutations[1] = tostring(rawMutations)
    end
    table.sort(mutations)
    return {
        cardId = cardId,
        card = displayName,
        rarity = rarity,
        pack = tostring(packName or "Unknown"),
        mutations = mutations,
        timestamp = os.time(),
    }
end
function PackRuntime.formatResult(entry)
    local mutationText = ""
    if type(entry.mutations) == "table"
        and #entry.mutations > 0
    then
        mutationText =
            " • " .. table.concat(entry.mutations, ", ")
    end
    return string.format(
        "%s Pack → %s [%s]%s",
        tostring(entry.pack),
        tostring(entry.card),
        tostring(entry.rarity),
        mutationText
    )
end
function PackRuntime.recordResult(packName, cardData)
    local entry =
        PackRuntime.resolveCard(cardData, packName)
    State.packResultHistory[
        #State.packResultHistory + 1
    ] = entry
    while #State.packResultHistory
        > State.packResultHistoryLimit
    do
        table.remove(State.packResultHistory, 1)
    end
    State.packLastPack = entry.pack
    State.packLastCard = entry.card
    State.packLastRarity = entry.rarity
    if State.packResultRarityWhitelist[entry.rarity]
        == true
    then
        State.packResultsLogged += 1
        LogRuntime.append(
            "Packs",
            PackRuntime.formatResult(entry),
            "info",
            true
        )
    else
        State.packResultsFiltered += 1
    end
    PackRuntime.updateResultUI()
    return entry
end
function PackRuntime.getResultLines()
    local lines = {}
    local shown = 0
    for index = #State.packResultHistory, 1, -1 do
        local entry = State.packResultHistory[index]
        if State.packResultRarityWhitelist[entry.rarity]
            == true
        then
            lines[#lines + 1] = string.format(
                "[%s] %s",
                os.date(
                    "%H:%M:%S",
                    tonumber(entry.timestamp) or os.time()
                ),
                PackRuntime.formatResult(entry)
            )
            shown += 1
            if shown >= 10 then
                break
            end
        end
    end
    if #lines == 0 then
        lines[1] =
            "No matching pack results in this session."
    end
    return lines
end
function PackRuntime.updateResultUI()
    if State.packResultParagraph
        and type(State.packResultParagraph.SetDesc)
            == "function"
    then
        pcall(function()
            State.packResultParagraph:SetDesc(
                table.concat(
                    PackRuntime.getResultLines(),
                    "\n"
                )
            )
        end)
    end
end
function PackRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.packLastStatus = tostring(message)
        if shouldLog == true then
            LogRuntime.append(
                "Packs",
                State.packLastStatus
            )
        end
    end
    local playerData = PackRuntime.getPlayerData()
    local totalPacks =
        PackRuntime.getTotalPackCount(playerData)
    local nextPack =
        PackRuntime.selectNextPack(playerData)
    local pending = State.packOpenPending
    local pendingText = "None"
    if type(pending) == "table" then
        pendingText =
            tostring(pending.packName or "Unknown")
            .. (
                pending.resultReceived
                    and " • Result Received"
                    or " • Waiting for Result"
            )
    end
    local description = table.concat({
        "Auto Open Available Packs: "
            .. (State.autoOpenPacks and "ON" or "OFF"),
        "Skip Animations: "
            .. (State.skipPackAnimations and "ON" or "OFF"),
        "Available Packs: "
            .. tostring(totalPacks),
        "Next Pack: "
            .. tostring(nextPack or "-"),
        "Animation: "
            .. (
                PackRuntime.isAnimating()
                    and "Processing"
                    or "Idle"
            ),
        "Pending: " .. pendingText,
        "Log Rarities: "
            .. tostring(
                PackRuntime.countSelectedRarities()
            )
            .. "/"
            .. tostring(#PackLogOptions.names),
        "Open Requests: "
            .. tostring(State.packOpenRequests),
        "Results: "
            .. tostring(State.packOpenDetected),
        "Skipped: "
            .. tostring(State.packOpenSkipped),
        "UI Fallbacks: "
            .. tostring(State.packFallbackClicks),
        "Hidden UIs: "
            .. tostring(State.packUiSuppressCount),
        "Controller Resets: "
            .. tostring(State.packControllerResets),
        "Local Pre-Hide: "
            .. (
                State.packLocalHideApplied
                    and "ACTIVE"
                    or (
                        State.packLocalHideAvailable
                            and "READY"
                            or "FALLBACK"
                    )
            ),
        "Restored Menus: "
            .. tostring(State.packRestoredUiCount),
        "Logged Results: "
            .. tostring(State.packResultsLogged),
        "Filtered Results: "
            .. tostring(State.packResultsFiltered),
        "Failures: "
            .. tostring(State.packOpenFailures),
        "Last Pack: "
            .. tostring(State.packLastPack),
        "Last Card: "
            .. tostring(State.packLastCard),
        "Last Rarity: "
            .. tostring(State.packLastRarity),
        "Status: "
            .. tostring(State.packLastStatus),
    }, "\n")
    if State.packStatusParagraph
        and type(State.packStatusParagraph.SetDesc)
            == "function"
    then
        pcall(function()
            State.packStatusParagraph:SetDesc(
                description
            )
        end)
    end
end
function PackRuntime.isContext(candidate)
    if typeof(candidate) ~= "table" then
        return false
    end
    local cardData = rawget(candidate, "cardData")
    local currentPieces =
        rawget(candidate, "currentPieces")
    local step = rawget(candidate, "step")
    local skipped = rawget(candidate, "skipped")
    return typeof(cardData) == "table"
        and typeof(currentPieces) == "table"
        and (
            step ~= nil
            or skipped ~= nil
        )
end
function PackRuntime.getFunctionUpvalues(callback)
    local values = {}
    local seen = {}
    local function add(value)
        if value ~= nil and not seen[value] then
            seen[value] = true
            values[#values + 1] = value
        end
    end
    local providers = {}
    if type(getupvalues) == "function" then
        providers[#providers + 1] = getupvalues
    end
    if type(debug) == "table"
        and type(debug.getupvalues) == "function"
    then
        providers[#providers + 1] =
            debug.getupvalues
    end
    for _, provider in ipairs(providers) do
        pcall(function()
            local result = provider(callback)
            if type(result) == "table" then
                for _, value in pairs(result) do
                    add(value)
                end
            end
        end)
    end
    local getter
    if type(getupvalue) == "function" then
        getter = getupvalue
    elseif type(debug) == "table"
        and type(debug.getupvalue) == "function"
    then
        getter = debug.getupvalue
    end
    if getter then
        for index = 1, 100 do
            local success, name, value =
                pcall(getter, callback, index)
            if not success or name == nil then
                break
            end
            add(value)
        end
    end
    return values
end
function PackRuntime.getCurrentContext()
    if PackRuntime.isContext(
        State.packCurrentContext
    ) then
        return State.packCurrentContext
    end
    local callbacks = {
        Modules.PackAnimationController.play,
        Modules.PackAnimationController.forceHide,
        Modules.PackAnimationController.resetEverything,
    }
    for _, callback in ipairs(callbacks) do
        if type(callback) == "function" then
            for _, value in ipairs(
                PackRuntime.getFunctionUpvalues(callback)
            ) do
                if PackRuntime.isContext(value) then
                    State.packCurrentContext = value
                    return value
                end
            end
        end
    end
    return nil
end
function PackRuntime.isContextReady(context)
    if not PackRuntime.isContext(context) then
        return false
    end
    return rawget(context, "contentContainer") ~= nil
        and rawget(context, "packContainer") ~= nil
        and rawget(context, "clickArea") ~= nil
        and typeof(rawget(context, "motions")) == "table"
end
function PackRuntime.waitForContext()
    local startedAt = os.clock()
    while State.running
        and os.clock() - startedAt
            < State.packAnimationWaitTimeout
    do
        local context =
            PackRuntime.getCurrentContext()
        if context
            and PackRuntime.isContextReady(context)
        then
            return context
        end
        task.wait(0.03)
    end
    return nil
end
function PackRuntime.findAnimationButton()
    local playerGui =
        LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local root =
        playerGui
        and playerGui:FindFirstChild("PackOpeningUI")
    if not root or root.Enabled == false then
        return nil
    end
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextButton")
            and descendant.Visible
            and descendant.Text == ""
            and descendant.AbsoluteSize.X > 0
            and descendant.AbsoluteSize.Y > 0
        then
            return descendant
        end
    end
    return nil
end
function PackRuntime.activateButton(button)
    if typeof(button) ~= "Instance"
        or not button:IsA("GuiButton")
    then
        return false
    end
    if type(firesignal) == "function" then
        local success = pcall(function()
            firesignal(button.MouseButton1Click)
        end)
        if success then
            return true
        end
    end
    return pcall(function()
        button:Activate()
    end)
end
function PackRuntime.advanceAnimationFallback()
    local startedAt = os.clock()
    local clicked = false
    while State.running
        and PackRuntime.isAnimating()
        and os.clock() - startedAt < 5
    do
        local button =
            PackRuntime.findAnimationButton()
        if button
            and PackRuntime.activateButton(button)
        then
            State.packFallbackClicks += 1
            clicked = true
        end
        task.wait(0.12)
    end
    return clicked
end
function PackRuntime.skipActiveAnimation()
    PackRuntime.installUiSuppressor()
    local playerGui =
        LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local root =
        playerGui
        and playerGui:FindFirstChild("PackOpeningUI")
    if root then
        PackRuntime.suppressPackUI(root)
    else
        PackRuntime.releaseInputBlock()
    end
    pcall(function()
        Modules.PackAnimationController.setAutoOpen(true)
    end)
    local context = PackRuntime.waitForContext()
    if context then
        local success, errorMessage = pcall(function()
            Modules.PackAnimationController.skipToReveal(
                context
            )
        end)
        if success then
            State.packOpenSkipped += 1
            State.packLastStatus =
                "Pack animation hidden and reveal accelerated."
            PackRuntime.updateUI()
            return true
        end
        State.packLastStatus =
            "Pack UI hidden; local auto advance is active."
                .. " Direct skip returned: "
                .. tostring(errorMessage)
        PackRuntime.updateUI()
        return true
    end
    State.packLastStatus =
        "Pack UI hidden; waiting for local auto advance."
    PackRuntime.updateUI()
    return true
end
function PackRuntime.requestOpen(packName, force)
    NativeVisualRuntime.sync("pack")

    local background =
        NativeVisualRuntime.isSuppressed("pack")

    if not background then
        PackRuntime.installUiSuppressor()
        PackRuntime.captureCurrentUi()
        PackRuntime.setLocalHideMode(
            State.skipPackAnimations
        )
    end

    pcall(function()
        Modules.PackAnimationController.setAutoOpen(
            background and false or State.autoOpenPacks
        )
    end)
    if type(State.packOpenPending) == "table" then
        return false, "A pack request is already pending"
    end
    if PackRuntime.isAnimating() then
        return false, "A pack animation is already running"
    end
    local now = os.clock()
    if force ~= true and now < State.packNextOpenAt then
        return false, "Pack opening is on cooldown"
    end
    local playerData = PackRuntime.getPlayerData()
    if not playerData then
        return false, "Player data is not ready"
    end
    packName = packName
        or PackRuntime.selectNextPack(playerData)
    if not packName
        or PackRuntime.getPackCount(
            packName,
            playerData
        ) <= 0
    then
        return false, "No packs are available"
    end
    local canCarry, current, capacity =
        PackRuntime.canCarryMore(playerData)
    if not canCarry then
        State.packLastStatus =
            string.format(
                "Inventory is full (%d/%d).",
                current,
                capacity
            )
        PackRuntime.updateUI()
        return false, State.packLastStatus
    end
    local beforeCount =
        PackRuntime.getPackCount(
            packName,
            playerData
        )
    local success, errorMessage = pcall(function()
        Remotes.OpenPack:FireServer(packName)
    end)
    if not success then
        State.packOpenFailures += 1
        State.packNextOpenAt =
            os.clock() + State.packOpenRetryCooldown
        PackRuntime.updateUI(
            "Could not submit the pack request.",
            true
        )
        return false, tostring(errorMessage)
    end
    State.packOpenRequests += 1
    State.packOpenPending = {
        packName = tostring(packName),
        beforeCount = beforeCount,
        startedAt = now,
        resultReceived = false,
        resultAt = 0,
    }
    State.packNextOpenAt =
        now + State.packOpenRequestCooldown
    State.packLastStatus =
        "Opening " .. tostring(packName) .. " Pack."
    PackRuntime.updateUI()
    return true, packName
end
function PackRuntime.handleOpenPackEvent(...)
    local arguments = {...}
    if arguments[1] == "x" then
        State.packLastStatus =
            "Pack request acknowledged by the server."
        PackRuntime.updateUI()
        return
    end
    local pending = State.packOpenPending
    local packName =
        tostring(
            arguments[7]
            or (
                type(pending) == "table"
                and pending.packName
            )
            or "Unknown"
        )
    local cardData =
        type(arguments[2]) == "table"
        and arguments[2]
        or nil
    if not cardData then
        cardData =
            PackRuntime.findCardByUuid(arguments[4])
    end
    cardData = type(cardData) == "table"
        and cardData
        or {
            id = tostring(arguments[4] or "Unknown"),
            Name = tostring(arguments[4] or "Unknown"),
            Rarity = "Unknown",
        }
    State.packOpenDetected += 1
    PackRuntime.recordResult(packName, cardData)
    State.packOpenPending = nil
    State.packCurrentContext = nil
    State.packNextOpenAt =
        os.clock() + State.packResultChainDelay
    State.packLastStatus =
        "Received the "
        .. packName
        .. " Pack result."
    PackRuntime.updateUI()

    if State.skipPackAnimations
        and NativeVisualRuntime.isSuppressed("pack")
    then
        PackRuntime.releaseInputBlock()
        return
    end

    if State.skipPackAnimations then
        task.spawn(function()
            local waitStarted = os.clock()

            while State.running
                and not PackRuntime.isAnimating()
                and os.clock() - waitStarted
                    < State.packAnimationWaitTimeout
            do
                task.wait(0.01)
            end

            if State.running then
                PackRuntime.skipActiveAnimation()
            end
        end)
    end
end
function PackRuntime.clearPending(successMessage)
    State.packOpenPending = nil
    State.packCurrentContext = nil
    State.packNextOpenAt =
        os.clock() + State.packOpenRequestCooldown
    if successMessage then
        State.packLastStatus = successMessage
    end
end
function PackRuntime.checkPending()
    local pending = State.packOpenPending
    if type(pending) ~= "table" then
        return false
    end
    local elapsed =
        os.clock() - (tonumber(pending.startedAt) or 0)
    if elapsed >= State.packOpenPendingTimeout then
        State.packOpenFailures += 1
        State.packOpenPending = nil
        State.packCurrentContext = nil
        State.packNextOpenAt =
            os.clock() + State.packOpenRetryCooldown
        pcall(function()
            Modules.PackAnimationController.resetEverything()
        end)
        PackRuntime.releaseInputBlock()
        PackRuntime.updateUI(
            "Pack result confirmation timed out.",
            true
        )
        return false
    end
    PackRuntime.updateUI()
    return true
end
function PackRuntime.setAutoOpen(enabled)
    enabled = enabled == true
    State.autoOpenPacks = enabled

    NativeVisualRuntime.sync("pack")

    local background =
        NativeVisualRuntime.isSuppressed("pack")

    if not background then
        PackRuntime.installUiSuppressor()
    end

    PackRuntime.resetControllerState()

    if enabled then
        if not background then
            PackRuntime.setLocalHideMode(
                State.skipPackAnimations
            )
        end

        pcall(function()
            Modules.PackAnimationController.setAutoOpen(
                background and false or true
            )
        end)
        State.packNextOpenAt = 0
        State.packLastStatus =
            "Auto Open Available Packs enabled."
        local generation =
            State.packAutomationGeneration
        task.delay(0.15, function()
            if State.running
                and State.autoOpenPacks
                and generation
                    == State.packAutomationGeneration
                and not PackRuntime.isAnimating()
            then
                PackRuntime.requestOpen(nil, false)
            end
        end)
    else
        State.packLastStatus =
            "Auto Open Available Packs disabled."
    end
    PackRuntime.updateUI(
        State.packLastStatus,
        true
    )
    return State.autoOpenPacks
end
function PackRuntime.setSkipAnimations(enabled)
    State.skipPackAnimations = enabled == true

    NativeVisualRuntime.sync("pack")

    local background =
        NativeVisualRuntime.isSuppressed("pack")

    if not background then
        PackRuntime.installUiSuppressor()
        PackRuntime.setLocalHideMode(
            State.skipPackAnimations
        )
    else
        PackRuntime.setLocalHideMode(false)
        PackRuntime.releaseInputBlock()
    end

    if not State.skipPackAnimations then
        PackRuntime.releaseInputBlock()
    end

    if State.skipPackAnimations
        and not background
        and PackRuntime.isAnimating()
    then
        task.spawn(PackRuntime.skipActiveAnimation)
    end
    PackRuntime.updateUI(
        State.skipPackAnimations
            and "Pack animation skipping enabled."
            or "Pack animation skipping disabled.",
        true
    )
    return State.skipPackAnimations
end
function PackRuntime.clearHistory()
    table.clear(State.packResultHistory)
    State.packResultsLogged = 0
    State.packResultsFiltered = 0
    State.packLastPack = "-"
    State.packLastCard = "-"
    State.packLastRarity = "-"
    PackRuntime.updateResultUI()
    PackRuntime.updateUI(
        "Pack result history cleared."
    )
    return true
end
function PackRuntime.processCurrent(force)
    if PackRuntime.isAnimating() then
        if State.skipPackAnimations or force == true then
            local success =
                PackRuntime.skipActiveAnimation()
            return success,
                success
                    and "Active pack processed."
                    or "Could not process the active pack"
        end
        return false, "A pack animation is already running"
    end
    return PackRuntime.requestOpen(nil, force == true)
end
function PackRuntime.installHook()
    return true, "OpenPack event listener is active"
end
function PackRuntime.uninstallHook()
    State.skipPackAnimations = false
    PackRuntime.setLocalHideMode(false)
    PackRuntime.resetControllerState()
    State.packPreservedUi = nil
end
function PackRuntime.tick()
    PackRuntime.installUiSuppressor()
    if State.skipPackAnimations
        and not State.packLocalHideApplied
    then
        PackRuntime.setLocalHideMode(true)
    elseif not State.skipPackAnimations
        and State.packLocalHideApplied
    then
        PackRuntime.setLocalHideMode(false)
    end
    pcall(function()
        Modules.PackAnimationController.setAutoOpen(
            State.autoOpenPacks
        )
    end)
    local animating = PackRuntime.isAnimating()
    if State.autoOpenPacks
        and animating
        and State.packOpenPending == nil
    then
        if State.packAnimationStaleSince <= 0 then
            State.packAnimationStaleSince =
                os.clock()
        elseif os.clock()
            - State.packAnimationStaleSince
            >= State.packAnimationRecoveryDelay
        then
            PackRuntime.restartAutomation()
            animating = false
        end
    else
        State.packAnimationStaleSince = 0
    end
    if State.skipPackAnimations
        and animating
    then
        local playerGui =
            LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local root =
            playerGui
            and playerGui:FindFirstChild(
                "PackOpeningUI"
            )
        if root then
            PackRuntime.suppressPackUI(root)
        end
    end
    if PackRuntime.checkPending() then
        return
    end
    if State.autoOpenPacks
        and not animating
        and os.clock() >= State.packNextOpenAt
    then
        local playerData = PackRuntime.getPlayerData()
        local nextPack =
            PackRuntime.selectNextPack(playerData)
        if nextPack then
            local success, result =
                PackRuntime.requestOpen(
                    nextPack,
                    false
                )
            if not success
                and result ~= "Pack opening is on cooldown"
            then
                State.packLastStatus = tostring(result)
            end
        else
            State.packLastStatus =
                "Waiting for available packs."
        end
    end
    if State.packStatusParagraph then
        PackRuntime.updateUI()
        PackRuntime.updateResultUI()
    end
end
local RebirthRuntime = {}
function RebirthRuntime.getOwnedCardIds(playerData)
    local owned = {}
    local function addCard(card)
        if type(card) ~= "table" then
            return
        end
        local cardId = tostring(card.id or "")
        if cardId ~= "" then
            owned[cardId] = true
        end
    end
    if type(playerData) == "table"
        and type(playerData.inventory) == "table"
    then
        for _, card in ipairs(playerData.inventory) do
            addCard(card)
        end
    end
    if type(playerData) == "table"
        and type(playerData.slots) == "table"
    then
        for _, slotData in pairs(playerData.slots) do
            addCard(
                type(slotData) == "table"
                    and slotData.card
                    or nil
            )
        end
    end
    return owned
end
function RebirthRuntime.parseRequirement(requirement)
    local success, isAny, value = pcall(function()
        return Modules.RebirthConfig.ParseCardRequirement(requirement)
    end)
    if not success then
        return nil, nil
    end
    return isAny == true, tostring(value or "")
end
function RebirthRuntime.validateCards(playerData, target)
    local requirements =
        type(target) == "table"
        and type(target.RequiredCards) == "table"
        and target.RequiredCards
        or {}
    if #requirements == 0 then
        return true, "Ready"
    end
    local owned = RebirthRuntime.getOwnedCardIds(playerData)
    local exactRequired = {}
    for _, requirement in ipairs(requirements) do
        local isAny, value =
            RebirthRuntime.parseRequirement(requirement)
        if isAny == nil or value == "" then
            return false, "Invalid card requirement"
        end
        if not isAny then
            exactRequired[value] = true
        end
    end
    local usedAny = {}
    for _, requirement in ipairs(requirements) do
        local isAny, value =
            RebirthRuntime.parseRequirement(requirement)
        if isAny then
            local found = false
            for cardId in pairs(owned) do
                local cardData = Modules.CardConfig.Cards[cardId]
                if not exactRequired[cardId]
                    and not usedAny[cardId]
                    and type(cardData) == "table"
                    and tostring(cardData.Rarity or "") == value
                then
                    usedAny[cardId] = true
                    found = true
                    break
                end
            end
            if not found then
                return false, "Missing any " .. value .. " card"
            end
        elseif not owned[value] then
            local cardData = Modules.CardConfig.Cards[value]
            local displayName =
                type(cardData) == "table"
                and tostring(
                    cardData.DisplayName
                    or cardData.Name
                    or value
                )
                or value
            return false, "Missing " .. displayName
        end
    end
    return true, "Ready"
end
function RebirthRuntime.getState()
    local playerData = getPlayerData()
    if type(playerData) ~= "table" then
        return {
            ready = false,
            canRebirth = false,
            reason = "Player data is not ready",
            current = 0,
            nextLevel = 1,
            maxLevel = 0,
            cash = 0,
            gems = 0,
            cashRequired = 0,
            gemsRequired = 0,
            cardRequirements = 0,
            cardsReady = false,
        }
    end
    local current = tonumber(playerData.rebirth) or 0
    local maxLevel = 0
    pcall(function()
        maxLevel = tonumber(Modules.RebirthConfig.GetMaxRebirth()) or 0
    end)
    if maxLevel > 0 and current >= maxLevel then
        return {
            ready = true,
            canRebirth = false,
            reason = "Maximum Rebirth reached",
            current = current,
            nextLevel = current,
            maxLevel = maxLevel,
            atMax = true,
            cash = tonumber(playerData.cash) or 0,
            gems = tonumber(playerData.gems) or 0,
            cashRequired = 0,
            gemsRequired = 0,
            cardRequirements = 0,
            cardsReady = true,
        }
    end
    local nextLevel = current + 1
    local target
    local targetSuccess = pcall(function()
        target = Modules.RebirthConfig.GetRebirth(nextLevel)
    end)
    if not targetSuccess or type(target) ~= "table" then
        return {
            ready = true,
            canRebirth = false,
            reason = "Rebirth configuration is unavailable",
            current = current,
            nextLevel = nextLevel,
            maxLevel = maxLevel,
            cash = tonumber(playerData.cash) or 0,
            gems = tonumber(playerData.gems) or 0,
            cashRequired = 0,
            gemsRequired = 0,
            cardRequirements = 0,
            cardsReady = false,
        }
    end
    local cash = tonumber(playerData.cash) or 0
    local gems = tonumber(playerData.gems) or 0
    local cashRequired = tonumber(target.CashRequired) or 0
    local gemsRequired = tonumber(target.GemsRequired) or 0
    local requiredCards =
        type(target.RequiredCards) == "table"
        and target.RequiredCards
        or {}
    if cash < cashRequired then
        return {
            ready = true,
            canRebirth = false,
            reason = "Not enough cash",
            current = current,
            nextLevel = nextLevel,
            maxLevel = maxLevel,
            target = target,
            cash = cash,
            gems = gems,
            cashRequired = cashRequired,
            gemsRequired = gemsRequired,
            cardRequirements = #requiredCards,
            cardsReady = false,
        }
    end
    if gemsRequired > 0 then
        local enoughGems = gems >= gemsRequired
        return {
            ready = true,
            canRebirth = enoughGems,
            reason = enoughGems and "Ready" or "Not enough Gems",
            current = current,
            nextLevel = nextLevel,
            maxLevel = maxLevel,
            target = target,
            cash = cash,
            gems = gems,
            cashRequired = cashRequired,
            gemsRequired = gemsRequired,
            cardRequirements = #requiredCards,
            cardsReady = true,
        }
    end
    local cardsReady, cardReason =
        RebirthRuntime.validateCards(playerData, target)
    return {
        ready = true,
        canRebirth = cardsReady,
        reason = cardsReady and "Ready" or cardReason,
        current = current,
        nextLevel = nextLevel,
        maxLevel = maxLevel,
        target = target,
        cash = cash,
        gems = gems,
        cashRequired = cashRequired,
        gemsRequired = gemsRequired,
        cardRequirements = #requiredCards,
        cardsReady = cardsReady,
    }
end
function RebirthRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.rebirthLastStatus = tostring(message)
        if shouldLog == true then
            LogRuntime.append(
                "Rebirth",
                State.rebirthLastStatus
            )
        end
    end
    local data = RebirthRuntime.getState()
    local nextLabel = data.atMax
        and "MAX"
        or tostring(data.nextLevel)
    local descriptions = {
        "Auto Rebirth: "
            .. (State.autoRebirth and "ON" or "OFF"),
        "Current Rebirth: " .. tostring(data.current),
        "Next Rebirth: " .. nextLabel,
        "Cash: "
            .. formatCompactNumber(data.cash)
            .. " / "
            .. formatCompactNumber(data.cashRequired),
    }
    if data.gemsRequired > 0 then
        descriptions[#descriptions + 1] =
            "Gems: "
            .. formatCompactNumber(data.gems)
            .. " / "
            .. formatCompactNumber(data.gemsRequired)
    else
        descriptions[#descriptions + 1] =
            "Cards: "
            .. (
                data.cardsReady
                    and "Ready"
                    or tostring(data.reason)
            )
    end
    descriptions[#descriptions + 1] =
        "Requirements: "
        .. (data.canRebirth and "Ready" or tostring(data.reason))
    descriptions[#descriptions + 1] =
        "Pending: " .. (State.rebirthPending and "YES" or "NO")
    descriptions[#descriptions + 1] =
        "Attempts: " .. tostring(State.rebirthAttempts)
    descriptions[#descriptions + 1] =
        "Completed: " .. tostring(State.rebirthSuccesses)
    descriptions[#descriptions + 1] =
        "Failures: " .. tostring(State.rebirthFailures)
    descriptions[#descriptions + 1] =
        "Status: " .. tostring(State.rebirthLastStatus)
    if State.rebirthStatusParagraph
        and type(State.rebirthStatusParagraph.SetDesc)
            == "function"
    then
        pcall(function()
            State.rebirthStatusParagraph:SetDesc(
                table.concat(descriptions, "\n")
            )
        end)
    end
end
function RebirthRuntime.setAuto(enabled)
    State.autoRebirth = enabled == true
    State.rebirthNextAt = 0
    RebirthRuntime.updateUI(
        State.autoRebirth
            and "Auto Rebirth enabled."
            or "Auto Rebirth disabled.",
        true
    )
    return State.autoRebirth
end
function RebirthRuntime.clearPending()
    State.rebirthPending = false
    State.rebirthPendingSince = 0
    State.rebirthPendingFrom = nil
end
function RebirthRuntime.rebirth(force)
    if State.rebirthPending then
        return false, "A Rebirth request is still being processed"
    end
    local now = os.clock()
    if force ~= true and now < State.rebirthNextAt then
        return false, "Rebirth is on cooldown"
    end
    local data = RebirthRuntime.getState()
    if not data.canRebirth then
        RebirthRuntime.updateUI(data.reason)
        return false, data.reason
    end
    State.rebirthPending = true
    State.rebirthPendingSince = now
    State.rebirthPendingFrom = data.current
    State.rebirthNextAt = now + State.rebirthCooldown
    State.rebirthAttempts += 1
    local success, errorMessage = pcall(function()
        Remotes.RebirthRemote:FireServer()
    end)
    if not success then
        RebirthRuntime.clearPending()
        State.rebirthFailures += 1
        State.rebirthNextAt =
            os.clock() + State.rebirthRetryCooldown
        RebirthRuntime.updateUI(
            "Could not submit the Rebirth request.",
            true
        )
        return false, tostring(errorMessage)
    end
    RebirthRuntime.updateUI(
        "Rebirth request submitted."
    )
    return true, data.nextLevel
end
function RebirthRuntime.tick()
    if State.rebirthPending then
        local data = RebirthRuntime.getState()
        local pendingFrom =
            tonumber(State.rebirthPendingFrom) or data.current
        if data.current > pendingFrom then
            RebirthRuntime.clearPending()
            State.rebirthSuccesses += 1
            State.rebirthNextAt =
                os.clock() + State.rebirthCooldown
            State.equipBestLastSignature = nil
            State.tournamentLastEquipSignature = nil
            State.tournamentLastEquipTeamFingerprint = ""
            RebirthRuntime.updateUI(
                "Rebirth "
                    .. tostring(data.current)
                    .. " completed.",
                true
            )
            return
        end
        if os.clock() - State.rebirthPendingSince
            >= State.rebirthPendingTimeout
        then
            RebirthRuntime.clearPending()
            State.rebirthFailures += 1
            State.rebirthNextAt =
                os.clock() + State.rebirthRetryCooldown
            RebirthRuntime.updateUI(
                "Rebirth confirmation timed out.",
                true
            )
            return
        end
        RebirthRuntime.updateUI()
        return
    end
    if State.autoRebirth
        and os.clock() >= State.rebirthNextAt
    then
        local data = RebirthRuntime.getState()
        if data.canRebirth then
            RebirthRuntime.rebirth(false)
        else
            RebirthRuntime.updateUI(data.reason)
        end
    elseif State.rebirthStatusParagraph then
        RebirthRuntime.updateUI()
    end
end
local EQUIP_BEST_MODE_INCOME = "income"
local EQUIP_BEST_MODE_RARITY = "rarity"
local EQUIP_BEST_MODE_OPTIONS = {
    "Best Income",
    "Best Rarity",
}
local function normalizeEquipBestMode(value)
    local normalized = string.lower(tostring(value or ""))
    if normalized == "rarity"
        or normalized == "best rarity"
    then
        return EQUIP_BEST_MODE_RARITY
    end
    return EQUIP_BEST_MODE_INCOME
end
local function equipBestModeLabel(value)
    if normalizeEquipBestMode(value)
        == EQUIP_BEST_MODE_RARITY
    then
        return "Best Rarity"
    end
    return "Best Income"
end
local EquipBestRuntime = {}
function EquipBestRuntime.getOwnedCards()
    local playerData = getPlayerData()
    local cards = {}
    local seen = {}
    local function addCard(card)
        if type(card) ~= "table" then
            return
        end
        local uuid = tostring(card.uuid or "")
        if uuid == "" or seen[uuid] then
            return
        end
        seen[uuid] = true
        cards[#cards + 1] = card
    end
    if type(playerData) == "table"
        and type(playerData.slots) == "table"
    then
        for _, slotData in pairs(playerData.slots) do
            addCard(
                type(slotData) == "table"
                    and slotData.card
                    or nil
            )
        end
    end
    if type(playerData) == "table"
        and type(playerData.inventory) == "table"
    then
        for _, card in ipairs(playerData.inventory) do
            addCard(card)
        end
    end
    return cards, playerData
end
function EquipBestRuntime.cardSignature(card)
    local cardId = tostring(card.id or "")
    local cardData = Modules.CardConfig.Cards[cardId]
    local rarity = tostring(
        cardData and cardData.Rarity or ""
    )
    local income = 0
    pcall(function()
        income = tonumber(
            Modules.ScalingIncome.getFlatIncome(card)
        ) or 0
    end)
    local mutations = {}
    if type(card.mutations) == "table" then
        for _, mutation in ipairs(card.mutations) do
            mutations[#mutations + 1] = tostring(mutation)
        end
        table.sort(mutations)
    end
    local trophyName = ""
    local trophyStars = 0
    if type(card.trophy) == "table" then
        trophyName = tostring(card.trophy.name or "")
        trophyStars = tonumber(card.trophy.stars) or 0
    end
    return table.concat({
        tostring(card.uuid or ""),
        cardId,
        rarity,
        tostring(income),
        tostring(card.locked == true),
        tostring(card.scalingPercent or ""),
        trophyName,
        tostring(trophyStars),
        tostring(card.worldCup or ""),
        table.concat(mutations, ","),
    }, ":")
end
function EquipBestRuntime.getSignature(mode)
    local cards, playerData = EquipBestRuntime.getOwnedCards()
    local cardParts = {}
    for _, card in ipairs(cards) do
        cardParts[#cardParts + 1] =
            EquipBestRuntime.cardSignature(card)
    end
    table.sort(cardParts)
    local slotParts = {}
    if type(playerData) == "table"
        and type(playerData.slots) == "table"
    then
        local slotIndexes = {}
        for slotIndex in pairs(playerData.slots) do
            slotIndexes[#slotIndexes + 1] = slotIndex
        end
        table.sort(slotIndexes, function(left, right)
            local leftNumber = tonumber(left)
            local rightNumber = tonumber(right)
            if leftNumber and rightNumber then
                return leftNumber < rightNumber
            end
            return tostring(left) < tostring(right)
        end)
        for _, slotIndex in ipairs(slotIndexes) do
            local slotData = playerData.slots[slotIndex]
            local card = type(slotData) == "table"
                and slotData.card
                or nil
            slotParts[#slotParts + 1] =
                tostring(slotIndex)
                .. "="
                .. tostring(card and card.uuid or "")
        end
    end
    return table.concat({
        normalizeEquipBestMode(mode),
        table.concat(cardParts, "|"),
        table.concat(slotParts, "|"),
    }, "#")
end
function EquipBestRuntime.syncModeDropdown()
    if State.syncingEquipBestModeDropdown
        or not State.equipBestModeDropdown
        or type(State.equipBestModeDropdown.Select) ~= "function"
    then
        return
    end
    State.syncingEquipBestModeDropdown = true
    pcall(function()
        State.equipBestModeDropdown:Select(
            equipBestModeLabel(State.equipBestMode)
        )
    end)
    State.syncingEquipBestModeDropdown = false
end
function EquipBestRuntime.updateUI(message, shouldLog)
    if message ~= nil then
        State.equipBestLastStatus = tostring(message)
        if shouldLog == true then
            LogRuntime.append(
                "Team",
                State.equipBestLastStatus
            )
        end
    end
    local cards = EquipBestRuntime.getOwnedCards()
    local description = table.concat({
        "Auto Equip: "
            .. (State.autoEquipBestCards and "ON" or "OFF"),
        "Mode: " .. equipBestModeLabel(State.equipBestMode),
        "Owned Cards: " .. tostring(#cards),
        "Processing: " .. (State.equipBestBusy and "YES" or "NO"),
        "Requests: " .. tostring(State.equipBestRequests),
        "Failures: " .. tostring(State.equipBestFailures),
        "Status: " .. tostring(State.equipBestLastStatus),
    }, "\n")
    if State.equipBestStatusParagraph
        and type(State.equipBestStatusParagraph.SetDesc)
            == "function"
    then
        pcall(function()
            State.equipBestStatusParagraph:SetDesc(description)
        end)
    end
end
function EquipBestRuntime.setMode(value)
    State.equipBestMode = normalizeEquipBestMode(value)
    State.equipBestLastSignature = nil
    State.equipBestNextAt = 0
    EquipBestRuntime.syncModeDropdown()
    EquipBestRuntime.updateUI(
        "Equip mode changed to "
            .. equipBestModeLabel(State.equipBestMode)
            .. ".",
        true
    )
    return State.equipBestMode
end
function EquipBestRuntime.setAuto(enabled)
    State.autoEquipBestCards = enabled == true
    State.equipBestLastSignature = nil
    State.equipBestNextAt = 0
    EquipBestRuntime.updateUI(
        State.autoEquipBestCards
            and "Auto Equip Best enabled."
            or "Auto Equip Best disabled.",
        true
    )
    return State.autoEquipBestCards
end
function EquipBestRuntime.equip(mode, force)
    mode = normalizeEquipBestMode(mode)
    if State.equipBestBusy then
        return false, "Another team update is being processed"
    end
    local now = os.clock()
    if now < State.equipBestNextAt then
        return false, "Equip Best is on cooldown"
    end
    local cards = EquipBestRuntime.getOwnedCards()
    if #cards <= 0 then
        EquipBestRuntime.updateUI("No cards are available yet.")
        return false, "No cards are available"
    end
    State.equipBestBusy = true
    State.equipBestNextAt =
        now + State.equipBestCooldown
    State.equipBestRequests += 1
    local success, errorMessage = pcall(function()
        if mode == EQUIP_BEST_MODE_RARITY then
            Modules.SlotController.equipBestRarityCards()
        else
            Modules.SlotController.equipBestCards()
        end
    end)
    if not success then
        State.equipBestBusy = false
        State.equipBestFailures += 1
        EquipBestRuntime.updateUI(
            "Could not update the main team.",
            true
        )
        return false, tostring(errorMessage)
    end
    EquipBestRuntime.updateUI(
        "Updating the main team with "
            .. equipBestModeLabel(mode)
            .. "."
    )
    task.delay(State.equipBestSettleDelay, function()
        if not State.running then
            return
        end
        State.equipBestBusy = false
        State.equipBestLastSignature =
            EquipBestRuntime.getSignature(mode)
        EquipBestRuntime.updateUI(
            equipBestModeLabel(mode)
                .. " team equipped.",
            true
        )
    end)
    return true
end
function EquipBestRuntime.tick()
    if not State.autoEquipBestCards then
        if State.equipBestStatusParagraph then
            EquipBestRuntime.updateUI()
        end
        return
    end
    if State.equipBestBusy
        or os.clock() < State.equipBestNextAt
    then
        EquipBestRuntime.updateUI()
        return
    end
    local signature =
        EquipBestRuntime.getSignature(State.equipBestMode)
    if signature ~= State.equipBestLastSignature then
        EquipBestRuntime.equip(
            State.equipBestMode,
            false
        )
    else
        EquipBestRuntime.updateUI()
    end
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
local applyWindowKeybind
local function formatScriptVersion(build)
    build = math.max(
        0,
        math.floor(tonumber(build) or 0)
    )
    if build < 100 then
        return string.format(
            "1.%d.0",
            build
        )
    end
    return string.format(
        "1.%d.%d",
        math.floor(build / 100),
        build % 100
    )
end
local ConfigRuntime = {
    version = 28,
    root = "xSansHUB",
    folder = "xSansHUB/SpinASoccerCardHub",
    file = "xSansHUB/SpinASoccerCardHub/" .. tostring(game.PlaceId) .. ".json",
}
ConfigRuntime.scriptVersion =
    formatScriptVersion(ConfigRuntime.version)
local BooleanSettingDefinitions = {
    {
        state = "autoSave",
        control = "autoSaveToggle",
    },
    {
        state = "autoLoad",
        control = "autoLoadToggle",
    },
    {
        state = "autoBuyPacks",
        control = "autoBuyPacksToggle",
        stop = true,
    },
    {
        state = "autoEnableNativeBuyPacks",
        control = "autoEnableNativeBuyPacksToggle",
        stop = true,
    },
    {
        state = "autoOpenPacks",
        control = "autoOpenPacksToggle",
        stop = true,
    },
    {
        state = "skipPackAnimations",
        control = "skipPackAnimationsToggle",
        stop = true,
    },
    {
        state = "autoRebirth",
        control = "autoRebirthToggle",
        stop = true,
    },
    {
        state = "autoEquipBestCards",
        control = "autoEquipBestCardsToggle",
        stop = true,
    },
    {
        state = "autoCraft",
        control = "autoCraftToggle",
        stop = true,
    },
    {
        state = "autoClaimSeashell",
        control = "autoClaimSeashellToggle",
        stop = true,
    },
    {
        state = "autoClaimSpinWheel",
        control = "autoClaimSpinWheelToggle",
        stop = true,
    },
    {
        state = "autoSpinWheel",
        control = "autoSpinWheelToggle",
        stop = true,
    },
    {
        state = "autoSpinWishTickets",
        control = "autoSpinWishToggle",
        stop = true,
    },
    {
        state = "skipWishAnimation",
        control = "skipWishAnimationToggle",
    },
    {
        state = "autoClaimIndex",
        control = "autoClaimIndexToggle",
        stop = true,
    },
    {
        state = "autoTryVulnoneCard",
        control = "autoTryVulnoneToggle",
        stop = true,
    },
    {
        state = "autoClaimDailyRewards",
        control = "autoClaimDailyRewardsToggle",
        stop = true,
    },
    {
        state = "autoRedeemCodes",
        control = "autoRedeemCodesToggle",
        stop = true,
    },
    {
        state = "autoBuyGemShop",
        control = "autoBuyGemShopToggle",
        stop = true,
    },
    {
        state = "autoClaimSummerQuests",
        control = "autoClaimSummerQuestsToggle",
        stop = true,
    },
    {
        state = "autoBuySummerShop",
        control = "autoBuySummerShopToggle",
        stop = true,
    },
    {
        state = "autoJoinTournament",
        control = "autoJoinTournamentToggle",
        stop = true,
    },
    {
        state = "autoEquipBestTournament",
        control = "autoEquipBestTournamentToggle",
        stop = true,
    },
    {
        state = "autoBuyTournamentShop",
        control = "autoBuyTournamentShopToggle",
        stop = true,
    },
    {
        state = "antiAfk",
        control = "antiAfkToggle",
        stop = true,
    },
}
local ValueSettingDefinitions = {
    {
        state = "windowKeybind",
        normalize = normalizeWindowKeybind,
    },
    {
        state = "equipBestMode",
        normalize = normalizeEquipBestMode,
    },
}
local MapSettingDefinitions = {
    {
        key = "packBuyWhitelist",
        state = "packBuyWhitelist",
        values = PackBuyNames,
    },
    {
        key = "packResultRarityWhitelist",
        state = "packResultRarityWhitelist",
        values = PackLogOptions.names,
    },
    {
        key = "trophyWhitelist",
        state = "whitelist",
        values = TROPHY_ORDER,
    },
    {
        key = "codeAttempted",
        state = "codeAttempted",
        apply = function(source, target)
            table.clear(target)
            for code, attempted in pairs(source) do
                local normalized =
                    CodesRuntime.normalize(code)
                if attempted == true
                    and string.match(
                        normalized,
                        "^[A-Z0-9]+%-[A-Z0-9]+$"
                    )
                then
                    target[normalized] = true
                end
            end
        end,
    },
    {
        key = "gemShopWhitelist",
        state = "gemShopWhitelist",
        values = GemShopOptionKeys,
    },
    {
        key = "summerShopWhitelist",
        state = "summerShopWhitelist",
        values = SummerShopOptionIds,
    },
    {
        key = "tournamentShopWhitelist",
        state = "tournamentShopWhitelist",
        apply = function(source, target)
            table.clear(target)
            for key, enabled in pairs(source) do
                if enabled == true then
                    local configId =
                        tournamentConfigIdFromSavedKey(
                            key
                        )
                    if configId then
                        target[configId] = true
                    end
                end
            end
        end,
    },
}
local ConnectionRuntime = {
    fields = {
        "spinWheelConnection",
        "tournamentShopConnection",
        "tournamentTickConnection",
        "packOpenConnection",
        "packUiChildConnection",
        "vulnoneResultConnection",
        "dailyRewardConnection",
        "antiAfkIdledConnection",
        "antiAfkHeartbeatConnection",
    },
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
    for _, field in ipairs(
        ConnectionRuntime.fields
    ) do
        ConnectionRuntime.disconnect(field)
    end
end
local SchedulerRuntime = {}
function SchedulerRuntime.spawn(interval, callback)
    task.spawn(function()
        while State.running do
            pcall(callback)
            local delay = type(interval) == "function"
                and interval()
                or interval
            task.wait(
                math.max(
                    0.05,
                    tonumber(delay) or 1
                )
            )
        end
    end)
end
function SchedulerRuntime.start(definitions)
    for _, definition in ipairs(definitions) do
        SchedulerRuntime.spawn(
            definition.interval,
            definition.callback
        )
    end
end
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
        return false, "Saved settings are unavailable"
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
    }
    for _, definition in ipairs(
        BooleanSettingDefinitions
    ) do
        local key =
            definition.key or definition.state
        snapshot[key] =
            State[definition.state] == true
    end
    for _, definition in ipairs(
        ValueSettingDefinitions
    ) do
        local key =
            definition.key or definition.state
        local value = State[definition.state]
        snapshot[key] = definition.normalize
            and definition.normalize(value)
            or value
    end
    for _, definition in ipairs(
        MapSettingDefinitions
    ) do
        snapshot[definition.key] =
            ConfigRuntime.copyBooleanMap(
                State[definition.state]
            )
    end
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
        return nil, "Saved settings are unavailable"
    end
    if not ConfigRuntime.fileExists() then
        return nil, "No saved settings were found"
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
            and "The saved settings format is invalid"
            or tostring(decoded)
    end
    return decoded
end
function ConfigRuntime.updateStatus(message)
    if message ~= nil then
        State.configLastStatus = tostring(message)
        LogRuntime.append("Config", State.configLastStatus)
    end
    local savedText = "Never"
    if State.configLastSavedAt and State.configLastSavedAt > 0 then
        savedText = os.date("%H:%M:%S", State.configLastSavedAt)
    end
    local description = table.concat({
        "Storage: "
            .. (State.configSupported and "Available" or "Unavailable"),
        "Saved Settings: "
            .. (ConfigRuntime.fileExists() and "Found" or "Not Found"),
        "Auto Save: " .. (State.autoSave and "ON" or "OFF"),
        "Auto Load: " .. (State.autoLoad and "ON" or "OFF"),
        "Keybind: " .. tostring(State.windowKeybind),
        "Changes: " .. (State.configDirty and "Pending" or "Saved"),
        "Last Saved: " .. savedText,
        "Status: " .. tostring(
            State.configLastStatus
                or State.configStartupError
                or "Ready."
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
        if toggle
            and type(toggle.Set) == "function"
        then
            pcall(function()
                toggle:Set(value == true, false)
            end)
        end
    end
    for _, definition in ipairs(
        BooleanSettingDefinitions
    ) do
        if definition.control then
            setToggle(
                State[definition.control],
                State[definition.state]
            )
        end
    end
    applyWindowKeybind(State.windowKeybind, true)
    EquipBestRuntime.syncModeDropdown()
    PackBuyRuntime.syncWhitelistDropdown()
    PackRuntime.syncRarityDropdown()
    syncWhitelistDropdown()
    syncGemShopWhitelistDropdown()
    syncSummerShopWhitelistDropdown()
    refreshTournamentShopOptions(false)
    syncTournamentShopWhitelistDropdown()
    PackBuyRuntime.updateUI()
    PackRuntime.updateUI()
    RebirthRuntime.updateUI()
    EquipBestRuntime.updateUI()
    updateStatus()
    updateSeashellStatus()
    updateSpinWheelStatus()
    WishRuntime.updateStatus()
    WishRuntime.updateLogUI()
    IndexRuntime.updateStatus()
    VulnoneRuntime.updateUI()
    DailyRewardRuntime.updateUI()
    CodesRuntime.updateUI()
    updateGemShopStatus()
    updateSummerQuestStatus()
    updateSummerShopStatus()
    TournamentRuntime.updateUI()
    updateTournamentShopStatus()
    AntiAfkRuntime.updateStatus()
    ConfigRuntime.updateStatus()
end
function ConfigRuntime.resetActionCooldowns()
    State.packBuyNextAt = 0
    PackBuyRuntime.clearPending()
    State.packNextOpenAt = 0
    State.packOpenPending = nil
    State.packCurrentContext = nil
    State.packAnimationStaleSince = 0
    State.packWatchedUis =
        setmetatable({}, {__mode = "k"})
    PackRuntime.resetControllerState()
    pcall(function()
        Modules.PackAnimationController.setAutoOpen(
            State.autoOpenPacks
        )
    end)
    State.packHandledContexts =
        setmetatable({}, {__mode = "k"})
    State.rebirthNextAt = 0
    RebirthRuntime.clearPending()
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
    State.tournamentNextActionAt = 0
    State.tournamentNextEquipAt = 0
    State.tournamentLastEquipSignature = nil
    State.tournamentLastEquipTeamFingerprint = ""
    State.tournamentManualJoinRequested = false
    TournamentRuntime.clearPending()
    State.nextAntiAfkPulseAt = 0
    table.clear(State.gemShopItemNextAttempt)
    table.clear(State.summerQuestNextAttempt)
    table.clear(State.summerShopItemNextAttempt)
    table.clear(State.tournamentShopItemNextAttempt)
end
function ConfigRuntime.apply(config, syncUI)
    if type(config) ~= "table" then
        return false,
            "The saved settings format is invalid"
    end
    State.configLoading = true
    for _, definition in ipairs(
        BooleanSettingDefinitions
    ) do
        local key =
            definition.key or definition.state
        if config[key] ~= nil then
            State[definition.state] =
                config[key] == true
        end
    end
    for _, definition in ipairs(
        ValueSettingDefinitions
    ) do
        local key =
            definition.key or definition.state
        if config[key] ~= nil then
            State[definition.state] =
                definition.normalize
                    and definition.normalize(
                        config[key]
                    )
                    or config[key]
        end
    end
    for _, definition in ipairs(
        MapSettingDefinitions
    ) do
        local source = config[definition.key]
        if type(source) == "table" then
            local target =
                State[definition.state]
            if definition.apply then
                definition.apply(source, target)
            else
                table.clear(target)
                for _, value in ipairs(
                    definition.values or {}
                ) do
                    target[value] =
                        source[value] == true
                end
            end
        end
    end
    State.antiAfkMethod =
        State.antiAfk
            and "pending"
            or "disabled"
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
            "Saved settings are unavailable."
        )
        return false, "Saved settings are unavailable"
    end
    local folderSuccess, folderError = ConfigRuntime.ensureFolders()
    if not folderSuccess then
        State.configLastError = tostring(folderError)
        ConfigRuntime.updateStatus("Could not prepare saved settings.")
        return false, "Could not prepare saved settings"
    end
    local encodeSuccess, encoded = pcall(function()
        return HttpService:JSONEncode(
            ConfigRuntime.buildSnapshot(true)
        )
    end)
    if not encodeSuccess then
        State.configLastError = tostring(encoded)
        ConfigRuntime.updateStatus("Could not prepare saved settings.")
        return false, "Could not prepare saved settings"
    end
    local writeSuccess, writeError = pcall(
        writefile,
        ConfigRuntime.file,
        encoded
    )
    if not writeSuccess then
        State.configLastError = tostring(writeError)
        ConfigRuntime.updateStatus("Could not save settings.")
        return false, "Could not save settings"
    end
    State.configDirty = false
    State.configLastError = nil
    State.configLastSavedAt = os.time()
    State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
    ConfigRuntime.updateStatus("Settings saved successfully.")
    return true
end
function ConfigRuntime.load()
    local config, readError = ConfigRuntime.read()
    if not config then
        State.configLastError = tostring(readError)
        ConfigRuntime.updateStatus("Could not load saved settings.")
        return false, readError
    end
    local success, applyError = ConfigRuntime.apply(config, true)
    if not success then
        State.configLastError = tostring(applyError)
        ConfigRuntime.updateStatus("Could not apply saved settings.")
        return false, applyError
    end
    State.configStartupLoaded = true
    State.configLastError = nil
    ConfigRuntime.updateStatus("Settings loaded successfully.")
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
        local saved = ConfigRuntime.save()
        if not saved then
            State.configDirty = true
            ConfigRuntime.updateStatus(
                "Save pending; retry required."
            )
        end
    end)
end
function ConfigRuntime.setAutoSave(enabled)
    State.autoSave = enabled == true
    if State.configSupported then
        ConfigRuntime.save()
    else
        ConfigRuntime.updateStatus(
            "Auto Save changed, but file storage is unavailable."
        )
    end
    return State.autoSave
end
function ConfigRuntime.setAutoLoad(enabled)
    State.autoLoad = enabled == true
    if State.configSupported then
        ConfigRuntime.save()
    else
        ConfigRuntime.updateStatus(
            "Auto Load changed, but file storage is unavailable."
        )
    end
    return State.autoLoad
end
function ConfigRuntime.initialize()
    State.configInitialized = true
    if not State.configSupported then
        State.configStartupError =
            "Saved settings are unavailable"
        State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
        return false, State.configStartupError
    end
    if not ConfigRuntime.fileExists() then
        State.configLastObservedFingerprint =
            ConfigRuntime.fingerprint()
        if State.autoSave then
            local saved, saveError = ConfigRuntime.save()
            if not saved then
                State.configStartupError = tostring(saveError)
                return false, saveError
            end
            return true, "Default settings saved."
        end
        return true, "No saved settings found; using defaults."
    end
    local config, readError = ConfigRuntime.read()
    if not config then
        State.configLastError = tostring(readError)
        State.configStartupError = tostring(readError)
        State.configLastObservedFingerprint =
            ConfigRuntime.fingerprint()
        return false, readError
    end
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
            State.configLastError = tostring(applyError)
            State.configStartupError = tostring(applyError)
            return false, applyError
        end
        State.configLastError = nil
        State.configStartupLoaded = true
    end
    State.configLastObservedFingerprint = ConfigRuntime.fingerprint()
    return true
end
applyWindowKeybind = function(value, syncControl)
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
    return keyName
end
local function loadWindUI()
    local success, result = pcall(function()
        return loadstring(game:HttpGet(
            "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
        ))()
    end)
    if not success or type(result) ~= "table" then
        error("Could not load WindUI: " .. tostring(result))
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
        ToggleKey = Enum.KeyCode[State.windowKeybind]
            or Enum.KeyCode.G,
        Size = UDim2.fromOffset(700, 500),
        MinSize = Vector2.new(600, 420),
        MaxSize = Vector2.new(900, 680),
        Resizable = true,
        AutoScale = true,
        NewElements = true,
        Radius = 8,
        ElementsRadius = 7,
        IconSize = 17,
        TopBarButtonIconSize = 11,
        SideBarWidth = 155,
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
        error("WindUI could not create the window.")
    end
    State.window = Window
    local function createTab(title, icon)
        return Window:Tab({
            Title = title,
            Icon = icon,
            IconSize = 16,
        })
    end
    local function createSection(parent, title, opened)
        return parent:Section({
            Title = title,
            Box = true,
            Opened = opened == true,
            TextSize = 14,
        })
    end
    local function createToggle(parent, field, options)
        options.TextSize = 13
        options.DescTextSize = 11
        State[field] = parent:Toggle(options)
        return State[field]
    end
    local function createDropdown(parent, field, options)
        options.TextSize = 13
        options.DescTextSize = 11
        options.OptionTextSize = 12
        options.MenuTextSize = 12
        State[field] = parent:Dropdown(options)
        return State[field]
    end
    local function createButton(parent, options)
        options.TextSize = 13
        options.DescTextSize = 11
        return parent:Button(options)
    end
    local function addToggles(parent, specs)
        for _, spec in ipairs(specs) do
            createToggle(parent, spec[1], {
                Title = spec[2],
                Desc = spec[3],
                Icon = spec[4],
                Value = spec[5],
                Callback = spec[6],
            })
        end
    end
    local Tabs = {
        Automation = createTab("Automation", "bot"),
        Summer = createTab("Summer [EVENT]", "sun"),
        Logs = createTab("Logs", "scroll-text"),
        Settings = createTab("Settings", "settings"),
    }
    State.keybindTag = Window:Tag({
        Title = "v" .. tostring(ConfigRuntime.scriptVersion),
        Icon = "badge-info",
        Border = true,
    })
    local Sections = {
        Packs = createSection(
            Tabs.Automation,
            "Packs",
            true
        ),
        Progression = createSection(
            Tabs.Automation,
            "Progression & Team",
            false
        ),
        Daily = createSection(
            Tabs.Automation,
            "Daily & Rewards",
            false
        ),
        Economy = createSection(
            Tabs.Automation,
            "Crafting & Shops",
            false
        ),
        Tournament = createSection(
            Tabs.Automation,
            "Tournament",
            false
        ),
        SummerCollection = createSection(
            Tabs.Summer,
            "Collection & Quests",
            true
        ),
        SummerShop = createSection(
            Tabs.Summer,
            "Summer Shop",
            false
        ),
        Logs = createSection(
            Tabs.Logs,
            "Important Activity",
            true
        ),
        Interface = createSection(
            Tabs.Settings,
            "Interface",
            true
        ),
        Utilities = createSection(
            Tabs.Settings,
            "Utilities",
            false
        ),
        Configuration = createSection(
            Tabs.Settings,
            "Configuration",
            false
        ),
        Session = createSection(
            Tabs.Settings,
            "Session",
            false
        ),
    }
    createDropdown(Sections.Packs, "packBuyWhitelistDropdown", {
        Title = "Pack Buy List",
        Desc = "Select packs for automatic buying.",
        Values = PackBuyLabels,
        Value = PackBuyRuntime.getSelectedLabels(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 280,
        Callback = PackBuyRuntime.applyWhitelistSelection,
    })
    addToggles(Sections.Packs, {
        {
            "autoBuyPacksToggle",
            "Auto Buy Packs",
            "Buy selected packs directly while requirements are met.",
            "shopping-cart",
            State.autoBuyPacks,
            PackBuyRuntime.setAuto,
        },
        {
            "autoEnableNativeBuyPacksToggle",
            "Auto Enable Native Buy",
            "Enable native Auto Buy for selected unlocked packs.",
            "check-check",
            State.autoEnableNativeBuyPacks,
            PackBuyRuntime.setAutoNative,
        },
        {
            "autoOpenPacksToggle",
            "Auto Open Packs",
            "Open every stored pack automatically.",
            "package-open",
            State.autoOpenPacks,
            PackRuntime.setAutoOpen,
        },
        {
            "skipPackAnimationsToggle",
            "Skip Pack Animations",
            "Process results without interrupting other menus.",
            "fast-forward",
            State.skipPackAnimations,
            PackRuntime.setSkipAnimations,
        },
    })
    createDropdown(Sections.Packs, "packResultRarityDropdown", {
        Title = "Result Log Rarity",
        Desc = "Only selected rarities are written to Logs.",
        Values = PackLogOptions.names,
        Value = PackRuntime.getSelectedRarities(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 260,
        Callback = PackRuntime.applyRaritySelection,
    })
    addToggles(Sections.Progression, {
        {
            "autoRebirthToggle",
            "Auto Rebirth",
            "Rebirth when every requirement is ready.",
            "refresh-cw",
            State.autoRebirth,
            RebirthRuntime.setAuto,
        },
        {
            "autoEquipBestCardsToggle",
            "Auto Equip Best Team",
            "Update the main team whenever cards change.",
            "users",
            State.autoEquipBestCards,
            EquipBestRuntime.setAuto,
        },
        {
            "autoClaimIndexToggle",
            "Auto Claim Index",
            "Claim new Index rewards automatically.",
            "book-open-check",
            State.autoClaimIndex,
            IndexRuntime.setAutoClaim,
        },
    })
    createDropdown(Sections.Progression, "equipBestModeDropdown", {
        Title = "Main Team Mode",
        Desc = "Choose Income or Rarity.",
        Values = EQUIP_BEST_MODE_OPTIONS,
        Value = equipBestModeLabel(State.equipBestMode),
        Multi = false,
        AllowNone = false,
        SearchBarEnabled = false,
        MenuWidth = 210,
        Callback = function(value)
            if not State.syncingEquipBestModeDropdown then
                EquipBestRuntime.setMode(
                    normalizeSelectedValue(value) or value
                )
            end
        end,
    })
    addToggles(Sections.Daily, {
        {
            "autoTryVulnoneToggle",
            "Auto Try Vulnone",
            "Use the free attempt automatically.",
            "crown",
            State.autoTryVulnoneCard,
            VulnoneRuntime.setAuto,
        },
        {
            "autoClaimDailyRewardsToggle",
            "Auto Claim Daily Reward",
            "Claim the daily reward automatically.",
            "gift",
            State.autoClaimDailyRewards,
            DailyRewardRuntime.setAutoClaim,
        },
        {
            "autoRedeemCodesToggle",
            "Auto Redeem Codes",
            "Redeem codes from the configured list.",
            "ticket-check",
            State.autoRedeemCodes,
            CodesRuntime.setAutoRedeem,
        },
        {
            "autoClaimSpinWheelToggle",
            "Auto Claim Free Spin",
            "Claim free spins automatically.",
            "gift",
            State.autoClaimSpinWheel,
            setAutoClaimSpinWheel,
        },
        {
            "autoSpinWheelToggle",
            "Auto Spin Wheel",
            "Use available spins automatically.",
            "circle-dot",
            State.autoSpinWheel,
            setAutoSpinWheel,
        },
        {
            "autoSpinWishToggle",
            "Auto Wish",
            "Use Wish Tickets automatically.",
            "sparkles",
            State.autoSpinWishTickets,
            WishRuntime.setAutoSpin,
        },
        {
            "skipWishAnimationToggle",
            "Skip Wish Animation",
            "Show Wish results immediately.",
            "fast-forward",
            State.skipWishAnimation,
            WishRuntime.setSkipAnimation,
        },
    })
    createDropdown(Sections.Economy, "whitelistDropdown", {
        Title = "Trophy Craft List",
        Desc = "Choose trophies to craft.",
        Values = TROPHY_ORDER,
        Value = getSelectedTrophies(),
        Multi = true,
        AllowNone = true,
        SearchBarEnabled = true,
        MenuWidth = 280,
        Callback = applyWhitelistSelection,
    })
    createToggle(Sections.Economy, "autoCraftToggle", {
        Title = "Auto Craft Trophies",
        Desc = "Craft selected trophies whenever possible.",
        Icon = "trophy",
        Value = State.autoCraft,
        Callback = setAutoCraft,
    })
    createDropdown(
        Sections.Economy,
        "gemShopWhitelistDropdown",
        {
            Title = "Gem Shop Purchase List",
            Desc = "Choose Gem Shop items to buy.",
            Values = GemShopOptionLabels,
            Value = getSelectedGemShopLabels(),
            Multi = true,
            AllowNone = true,
            SearchBarEnabled = true,
            MenuWidth = 300,
            Callback = applyGemShopWhitelistSelection,
        }
    )
    createToggle(Sections.Economy, "autoBuyGemShopToggle", {
        Title = "Auto Buy Gem Shop",
        Desc = "Buy selected Gem Shop items automatically.",
        Icon = "gem",
        Value = State.autoBuyGemShop,
        Callback = setAutoBuyGemShop,
    })
    refreshTournamentShopOptions(false)
    addToggles(Sections.Tournament, {
        {
            "autoEquipBestTournamentToggle",
            "Auto Equip Best Tournament Team",
            "Keep the strongest tournament team equipped.",
            "users",
            State.autoEquipBestTournament,
            TournamentRuntime.setAutoEquipBest,
        },
        {
            "autoJoinTournamentToggle",
            "Auto Join Tournament",
            "Equip the best team and join when available.",
            "play",
            State.autoJoinTournament,
            TournamentRuntime.setAutoJoin,
        },
    })
    createDropdown(
        Sections.Tournament,
        "tournamentShopWhitelistDropdown",
        {
            Title = "Reward Purchase List",
            Desc = "Choose Tournament rewards to buy.",
            Values = TournamentShopOptionLabels,
            Value = getSelectedTournamentShopLabels(),
            Multi = true,
            AllowNone = true,
            SearchBarEnabled = true,
            MenuWidth = 350,
            Callback = applyTournamentShopWhitelistSelection,
        }
    )
    createToggle(
        Sections.Tournament,
        "autoBuyTournamentShopToggle",
        {
            Title = "Auto Buy Tournament Rewards",
            Desc = "Buy selected rewards automatically.",
            Icon = "shopping-cart",
            Value = State.autoBuyTournamentShop,
            Callback = setAutoBuyTournamentShop,
        }
    )
    addToggles(Sections.SummerCollection, {
        {
            "autoClaimSeashellToggle",
            "Auto Collect Seashells",
            "Collect seashells as they appear.",
            "shell",
            State.autoClaimSeashell,
            setAutoClaimSeashell,
        },
        {
            "autoClaimSummerQuestsToggle",
            "Auto Claim Quests",
            "Claim completed Summer Quests.",
            "list-checks",
            State.autoClaimSummerQuests,
            setAutoClaimSummerQuests,
        },
    })
    createDropdown(
        Sections.SummerShop,
        "summerShopWhitelistDropdown",
        {
            Title = "Purchase List",
            Desc = "Choose Summer Shop items to buy.",
            Values = SummerShopOptionLabels,
            Value = getSelectedSummerShopLabels(),
            Multi = true,
            AllowNone = true,
            SearchBarEnabled = true,
            MenuWidth = 320,
            Callback = applySummerShopWhitelistSelection,
        }
    )
    createToggle(
        Sections.SummerShop,
        "autoBuySummerShopToggle",
        {
            Title = "Auto Buy Summer Shop",
            Desc = "Buy selected Summer Shop items.",
            Icon = "shopping-bag",
            Value = State.autoBuySummerShop,
            Callback = setAutoBuySummerShop,
        }
    )
    createDropdown(Sections.Logs, "logsFilterDropdown", {
        Title = "Filter",
        Desc = "Show activity from one feature.",
        Values = LOG_FILTER_OPTIONS,
        Value = State.logsFilter,
        Multi = false,
        AllowNone = false,
        SearchBarEnabled = false,
        MenuWidth = 220,
        Callback = function(value)
            LogRuntime.setFilter(
                normalizeSelectedValue(value) or value
            )
        end,
    })
    State.logsParagraph = Sections.Logs:Paragraph({
        Title = "Activity",
        Desc = "No important activity yet.",
        Image = "list",
        ImageSize = 17,
        Size = "Small",
        TextSize = 12,
        DescTextSize = 11,
    })
    createButton(Sections.Logs, {
        Title = "Clear Logs",
        Desc = "Clear this session's activity.",
        Icon = "trash-2",
        Callback = LogRuntime.clear,
    })
    State.windowKeybindControl =
        Sections.Interface:Keybind({
            Title = "Window Keybind",
            Desc = "Choose the key used to show or hide the hub.",
            Value = State.windowKeybind,
            TextSize = 13,
            DescTextSize = 11,
            Callback = function(value)
                applyWindowKeybind(value, false)
            end,
        })
    createToggle(Sections.Utilities, "antiAfkToggle", {
        Title = "Anti AFK",
        Desc = "Keep the session active automatically.",
        Icon = "shield-check",
        Value = State.antiAfk,
        Callback = AntiAfkRuntime.setEnabled,
    })
    createButton(Sections.Utilities, {
        Title = "Rejoin Server",
        Desc = "Reconnect to the current server.",
        Icon = "rotate-cw",
        Callback = function()
            local success, message = ServerRuntime.rejoin()
            if not success then
                notify(
                    "Rejoin",
                    tostring(message),
                    "triangle-alert"
                )
            end
        end,
    })
    addToggles(Sections.Configuration, {
        {
            "autoSaveToggle",
            "Auto Save",
            "Save changes automatically.",
            "save",
            State.autoSave,
            ConfigRuntime.setAutoSave,
        },
        {
            "autoLoadToggle",
            "Auto Load",
            "Load saved settings on startup.",
            "folder-down",
            State.autoLoad,
            ConfigRuntime.setAutoLoad,
        },
    })
    createButton(Sections.Session, {
        Title = "Close Hub",
        Desc = "Stop all automation and close the hub.",
        Icon = "square",
        Callback = function()
            local hub = Environment.SpinASoccerCardHub
            if type(hub) == "table"
                and type(hub.Stop) == "function"
            then
                hub.Stop()
            end
        end,
    })
    local tabTitles = {
        ["Automation"] = true,
        ["Summer [EVENT]"] = true,
        ["Logs"] = true,
        ["Settings"] = true,
    }
    local function styleTextObject(object)
        pcall(function()
            if object:IsA("TextLabel")
                or object:IsA("TextButton")
                or object:IsA("TextBox")
            then
                if not tabTitles[tostring(object.Text)]
                    and object.TextSize > 13
                then
                    object.TextSize = 13
                end
            end
        end)
    end
    local function registerTextRoot(root)
        if typeof(root) ~= "Instance" then
            return
        end
        styleTextObject(root)
        for _, object in ipairs(root:GetDescendants()) do
            styleTextObject(object)
        end
        local success, connection = pcall(function()
            return root.DescendantAdded:Connect(styleTextObject)
        end)
        if success then
            State.uiTextConnections[
                #State.uiTextConnections + 1
            ] = connection
        end
    end
    local function findWindowRoots(container)
        if typeof(container) ~= "Instance" then
            return
        end
        for _, root in ipairs(container:GetChildren()) do
            local matched = false
            for _, object in ipairs(root:GetDescendants()) do
                local isText = object:IsA("TextLabel")
                    or object:IsA("TextButton")
                    or object:IsA("TextBox")
                if isText
                    and tostring(object.Text)
                        == "Spin A Soccer Card"
                then
                    matched = true
                    break
                end
            end
            if matched then
                registerTextRoot(root)
            end
        end
    end
    task.defer(function()
        task.wait(0.2)
        pcall(function()
            findWindowRoots(
                LocalPlayer:FindFirstChildOfClass("PlayerGui")
            )
        end)
        pcall(function()
            findWindowRoots(
                game:GetService("CoreGui")
            )
        end)
    end)
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
                observed =
                    applyWindowKeybind(current, false)
            end
            task.wait(0.25)
        end
    end)
    refreshTournamentShopOptions(true)
    ConfigRuntime.syncControls()
    LogRuntime.updateUI()
    local function selectAutomationTab()
        if type(Tabs.Automation.Select) == "function" then
            return pcall(function()
                Tabs.Automation:Select()
            end)
        end
        if type(Window.SelectTab) == "function" then
            return pcall(function()
                Window:SelectTab(
                    Tabs.Automation.Index or 1
                )
            end)
        end
        return false
    end
    selectAutomationTab()
    task.defer(function()
        pcall(fetchSpinWheelData, true)
        task.wait()
        selectAutomationTab()
    end)
end
local Hub = {
    Version = ConfigRuntime.scriptVersion,
    Build = ConfigRuntime.version,
    Vulnone = {},
    Packs = {},
    Rebirth = {},
    Team = {},
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
    Tournament = {},
    TournamentShop = {},
    Logs = {},
    Utilities = {},
    Config = {},
}
function Hub.Vulnone.SetAutoTry(enabled)
    local value = VulnoneRuntime.setAuto(enabled)
    if State.autoTryVulnoneToggle
        and type(State.autoTryVulnoneToggle.Set)
            == "function"
    then
        pcall(function()
            State.autoTryVulnoneToggle:Set(value)
        end)
    end
    return value
end
function Hub.Vulnone.ToggleAutoTry()
    return Hub.Vulnone.SetAutoTry(
        not State.autoTryVulnoneCard
    )
end
function Hub.Vulnone.TryNow()
    return VulnoneRuntime.attempt(true)
end
function Hub.Vulnone.Refresh()
    local success, result =
        VulnoneRuntime.refresh(true)
    VulnoneRuntime.updateUI()
    return success, result
end
function Hub.Vulnone.GetState()
    local status =
        State.vulnoneStatus
        or VulnoneRuntime.normalizeStatus(nil)
    return {
        autoTry = State.autoTryVulnoneCard,
        canAttemptFree = status.canAttemptFree,
        hasCard = status.hasCard,
        freeAttemptCooldown =
            status.freeAttemptCooldown,
        cardExpiresIn = status.cardExpiresIn,
        pending = State.vulnonePending,
        attempts = State.vulnoneAttempts,
        results = State.vulnoneResults,
        wins = State.vulnoneWins,
        losses = State.vulnoneLosses,
        failures = State.vulnoneFailures,
        lastResult = State.vulnoneLastResult,
        status = State.vulnoneLastStatus,
    }
end
function Hub.Packs.SetAutoBuy(enabled)
    local value = PackBuyRuntime.setAuto(enabled)
    PackRuntime.syncToggle(
        State.autoBuyPacksToggle,
        value
    )
    return value
end
function Hub.Packs.ToggleAutoBuy()
    return Hub.Packs.SetAutoBuy(
        not State.autoBuyPacks
    )
end
function Hub.Packs.SetAutoNativeBuy(enabled)
    local value =
        PackBuyRuntime.setAutoNative(enabled)
    PackRuntime.syncToggle(
        State.autoEnableNativeBuyPacksToggle,
        value
    )
    return value
end
function Hub.Packs.ToggleAutoNativeBuy()
    return Hub.Packs.SetAutoNativeBuy(
        not State.autoEnableNativeBuyPacks
    )
end
function Hub.Packs.SetBuyWhitelist(values)
    PackBuyRuntime.applyWhitelistSelection(values)
    PackBuyRuntime.syncWhitelistDropdown()
    return Hub.Packs.GetBuyWhitelist()
end
function Hub.Packs.GetBuyWhitelist()
    local result = {}
    for _, packName in ipairs(PackBuyNames) do
        if State.packBuyWhitelist[packName] then
            result[#result + 1] = packName
        end
    end
    return result
end
function Hub.Packs.SelectAllBuyPacks()
    PackBuyRuntime.setAll(true)
    return Hub.Packs.GetBuyWhitelist()
end
function Hub.Packs.ClearBuyWhitelist()
    PackBuyRuntime.setAll(false)
    return {}
end
function Hub.Packs.ProcessNextBuy()
    return PackBuyRuntime.process(true)
end
function Hub.Packs.SetAutoOpen(enabled)
    local value = PackRuntime.setAutoOpen(enabled)
    PackRuntime.syncToggle(
        State.autoOpenPacksToggle,
        value
    )
    return value
end
function Hub.Packs.ToggleAutoOpen()
    return Hub.Packs.SetAutoOpen(
        not State.autoOpenPacks
    )
end
function Hub.Packs.SetSkipAnimations(enabled)
    local value =
        PackRuntime.setSkipAnimations(enabled)
    PackRuntime.syncToggle(
        State.skipPackAnimationsToggle,
        value
    )
    return value
end
function Hub.Packs.ToggleSkipAnimations()
    return Hub.Packs.SetSkipAnimations(
        not State.skipPackAnimations
    )
end
function Hub.Packs.SetResultRarityWhitelist(values)
    PackRuntime.applyRaritySelection(values)
    PackRuntime.syncRarityDropdown()
    return Hub.Packs.GetResultRarityWhitelist()
end
function Hub.Packs.GetResultRarityWhitelist()
    return PackRuntime.getSelectedRarities()
end
function Hub.Packs.SelectAllResultRarities()
    PackRuntime.setAllRarities(true)
    return PackRuntime.getSelectedRarities()
end
function Hub.Packs.ClearResultRarityWhitelist()
    PackRuntime.setAllRarities(false)
    return {}
end
function Hub.Packs.ClearResultHistory()
    return PackRuntime.clearHistory()
end
function Hub.Packs.RestartAutomation()
    local success, result =
        PackRuntime.restartAutomation()
    PackRuntime.updateUI(
        success
            and "Pack automation restarted."
            or tostring(result),
        true
    )
    return success, result
end
function Hub.Packs.ProcessCurrent()
    return PackRuntime.processCurrent(true)
end
function Hub.Packs.SetHideAnimation(enabled)
    return Hub.Packs.SetSkipAnimations(enabled)
end
function Hub.Packs.ToggleHideAnimation()
    return Hub.Packs.ToggleSkipAnimations()
end
function Hub.Packs.SetAutoSkip(enabled)
    return Hub.Packs.SetSkipAnimations(enabled)
end
function Hub.Packs.ToggleAutoSkip()
    return Hub.Packs.ToggleSkipAnimations()
end
function Hub.Packs.ApplySettings()
    local success, result =
        PackRuntime.processCurrent(false)
    PackRuntime.updateUI(
        success
            and "Pack automation synchronized."
            or tostring(result)
    )
    return success, result
end
function Hub.Packs.GetState()
    local history = {}
    for index, entry in ipairs(
        State.packResultHistory
    ) do
        history[index] = {
            pack = entry.pack,
            cardId = entry.cardId,
            card = entry.card,
            rarity = entry.rarity,
            mutations = table.clone(
                entry.mutations or {}
            ),
            timestamp = entry.timestamp,
        }
    end
    return {
        autoBuy = State.autoBuyPacks,
        autoNativeBuy =
            State.autoEnableNativeBuyPacks,
        buyWhitelist = Hub.Packs.GetBuyWhitelist(),
        buyPending = State.packBuyPending,
        buyRequests = State.packBuyRequests,
        confirmedPurchases = State.packBuyPurchases,
        nativeCheckboxUpdates =
            State.packBuyNativeUpdates,
        buyFailures = State.packBuyFailures,
        buyStatus = State.packBuyLastStatus,
        autoOpen = State.autoOpenPacks,
        skipAnimations = State.skipPackAnimations,
        hideAnimation = State.skipPackAnimations,
        autoSkip = State.skipPackAnimations,
        animating = PackRuntime.isAnimating(),
        availablePacks =
            PackRuntime.getTotalPackCount(),
        nextPack =
            PackRuntime.selectNextPack(),
        pending = State.packOpenPending,
        openRequests = State.packOpenRequests,
        resultRarityWhitelist =
            PackRuntime.getSelectedRarities(),
        detected = State.packOpenDetected,
        skipped = State.packOpenSkipped,
        autoAdvanced = State.packOpenAdvanced,
        fallbackClicks = State.packFallbackClicks,
        controllerResets = State.packControllerResets,
        automationGeneration =
            State.packAutomationGeneration,
        localHideAvailable =
            State.packLocalHideAvailable,
        localHideApplied =
            State.packLocalHideApplied,
        localHideFailures =
            State.packLocalHideFailures,
        restoredMenus =
            State.packRestoredUiCount,
        backgroundSuppressed =
            State.backgroundPackSuppressed,
        visualSuppressionSupported =
            State.backgroundVisualSupported,
        visualSuppressionFailures =
            State.backgroundVisualFailures,
        loggedResults = State.packResultsLogged,
        filteredResults =
            State.packResultsFiltered,
        failures = State.packOpenFailures,
        lastPack = State.packLastPack,
        lastCard = State.packLastCard,
        lastRarity = State.packLastRarity,
        history = history,
        status = State.packLastStatus,
    }
end
function Hub.Rebirth.SetAuto(enabled)
    local value = RebirthRuntime.setAuto(enabled)
    if State.autoRebirthToggle
        and type(State.autoRebirthToggle.Set) == "function"
    then
        pcall(function()
            State.autoRebirthToggle:Set(value)
        end)
    end
    return value
end
function Hub.Rebirth.ToggleAuto()
    return Hub.Rebirth.SetAuto(
        not State.autoRebirth
    )
end
function Hub.Rebirth.RebirthNow()
    return RebirthRuntime.rebirth(true)
end
function Hub.Rebirth.GetState()
    local data = RebirthRuntime.getState()
    return {
        autoRebirth = State.autoRebirth,
        ready = data.ready,
        canRebirth = data.canRebirth,
        reason = data.reason,
        current = data.current,
        nextLevel = data.nextLevel,
        maxLevel = data.maxLevel,
        atMax = data.atMax == true,
        cash = data.cash,
        cashRequired = data.cashRequired,
        gems = data.gems,
        gemsRequired = data.gemsRequired,
        cardRequirements = data.cardRequirements,
        cardsReady = data.cardsReady,
        pending = State.rebirthPending,
        attempts = State.rebirthAttempts,
        completed = State.rebirthSuccesses,
        failures = State.rebirthFailures,
        status = State.rebirthLastStatus,
    }
end
function Hub.Team.SetAutoEquip(enabled)
    local value = EquipBestRuntime.setAuto(enabled)
    if State.autoEquipBestCardsToggle
        and type(State.autoEquipBestCardsToggle.Set)
            == "function"
    then
        pcall(function()
            State.autoEquipBestCardsToggle:Set(value)
        end)
    end
    return value
end
function Hub.Team.ToggleAutoEquip()
    return Hub.Team.SetAutoEquip(
        not State.autoEquipBestCards
    )
end
function Hub.Team.SetMode(value)
    return EquipBestRuntime.setMode(value)
end
function Hub.Team.GetMode()
    return State.equipBestMode
end
function Hub.Team.EquipBestIncome()
    return EquipBestRuntime.equip(
        EQUIP_BEST_MODE_INCOME,
        true
    )
end
function Hub.Team.EquipBestRarity()
    return EquipBestRuntime.equip(
        EQUIP_BEST_MODE_RARITY,
        true
    )
end
function Hub.Team.EquipNow()
    return EquipBestRuntime.equip(
        State.equipBestMode,
        true
    )
end
function Hub.Team.GetState()
    local cards = EquipBestRuntime.getOwnedCards()
    return {
        autoEquip = State.autoEquipBestCards,
        mode = State.equipBestMode,
        modeLabel = equipBestModeLabel(State.equipBestMode),
        ownedCards = #cards,
        busy = State.equipBestBusy,
        requests = State.equipBestRequests,
        failures = State.equipBestFailures,
        status = State.equipBestLastStatus,
    }
end
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
    if not Modules.TrophyConfig.Trophies[trophyName] then
        return false, "Unknown trophy"
    end
    State.whitelist[trophyName] = enabled == true
    syncWhitelistDropdown()
    updateStatus("Whitelist updated.")
    return true
end
function Hub.Trophies.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist must be a table"
    end
    table.clear(State.whitelist)
    for _, trophyName in ipairs(TROPHY_ORDER) do
        State.whitelist[trophyName] = whitelist[trophyName] == true
    end
    syncWhitelistDropdown()
    updateStatus("Whitelist updated.")
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
        backgroundSuppressed =
            State.backgroundSpinSuppressed,
        visualSuppressionSupported =
            State.backgroundVisualSupported,
        visualSuppressionFailures =
            State.backgroundVisualFailures,
        status = State.spinWheelLastStatus,
        sessionStartedAt = State.spinWheelSessionStartedAt,
    }
end
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
        return false, "Unknown Gem Shop item"
    end
    State.gemShopWhitelist[key] = enabled == true
    State.gemShopNextBuyAt = 0
    syncGemShopWhitelistDropdown()
    updateGemShopStatus("Gem Shop whitelist updated.")
    return true
end
function Hub.GemShop.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist must be a table"
    end
    table.clear(State.gemShopWhitelist)
    for _, key in ipairs(GemShopOptionKeys) do
        local label = gemShopLabelFromKey(key)
        State.gemShopWhitelist[key] =
            whitelist[key] == true or whitelist[label] == true
    end
    State.gemShopNextBuyAt = 0
    syncGemShopWhitelistDropdown()
    updateGemShopStatus("Gem Shop whitelist updated.")
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
    updateGemShopStatus("Gem Shop refreshed.")
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
        return false, "Unknown Summer Shop item"
    end
    State.summerShopWhitelist[itemId] = enabled == true
    syncSummerShopWhitelistDropdown()
    updateSummerShopStatus("Summer Shop whitelist updated.")
    return true
end
function Hub.SummerShop.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist must be a table"
    end
    table.clear(State.summerShopWhitelist)
    for _, id in ipairs(SummerShopOptionIds) do
        State.summerShopWhitelist[id] = whitelist[id] == true
    end
    syncSummerShopWhitelistDropdown()
    updateSummerShopStatus("Summer Shop whitelist updated.")
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
    updateSummerShopStatus("Summer Shop refreshed.")
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
function Hub.Tournament.SetAutoJoin(enabled)
    local value = TournamentRuntime.setAutoJoin(enabled)
    if State.autoJoinTournamentToggle
        and type(State.autoJoinTournamentToggle.Set) == "function"
    then
        pcall(function()
            State.autoJoinTournamentToggle:Set(value)
        end)
    end
    return value
end
function Hub.Tournament.ToggleAutoJoin()
    return Hub.Tournament.SetAutoJoin(
        not State.autoJoinTournament
    )
end
function Hub.Tournament.SetAutoEquipBest(enabled)
    local value =
        TournamentRuntime.setAutoEquipBest(enabled)
    if State.autoEquipBestTournamentToggle
        and type(
            State.autoEquipBestTournamentToggle.Set
        ) == "function"
    then
        pcall(function()
            State.autoEquipBestTournamentToggle:Set(value)
        end)
    end
    return value
end
function Hub.Tournament.ToggleAutoEquipBest()
    return Hub.Tournament.SetAutoEquipBest(
        not State.autoEquipBestTournament
    )
end
function Hub.Tournament.EquipBestNow()
    return TournamentRuntime.equipBest(true)
end
function Hub.Tournament.JoinNow()
    return TournamentRuntime.requestManualJoin()
end
function Hub.Tournament.GetBestTeam()
    local data = TournamentRuntime.getState()
    local best, incomeMap =
        TournamentRuntime.getBestTeam(data.playerData)
    local result = {}
    for index, uuid in ipairs(best) do
        result[index] = {
            uuid = uuid,
            baseIncome = tonumber(incomeMap[uuid]) or 0,
        }
    end
    return result
end
function Hub.Tournament.GetState()
    local data = TournamentRuntime.getState()
    return {
        autoJoin = State.autoJoinTournament,
        autoEquipBest = State.autoEquipBestTournament,
        phase = data.phase,
        secondsLeft = data.secondsLeft,
        queueWindowOpen = data.queueWindowOpen,
        queued = data.queued,
        team = TournamentRuntime.copyTeam(data.team),
        teamCount = data.teamCount,
        bestTeamReady =
            TournamentRuntime.isEquipCurrent(data),
        rebirth = data.rebirth,
        minRebirth = data.minRebirth,
        unlocked = data.unlocked,
        cash = data.cash,
        entryFee = data.entryFee,
        canAfford = data.canAfford,
        pending = State.tournamentPendingAction
            and State.tournamentPendingAction.kind
            or nil,
        equipRequests = State.tournamentEquipRequests,
        equipSignature =
            State.tournamentLastEquipSignature,
        equipTeamFingerprint =
            State.tournamentLastEquipTeamFingerprint,
        joinRequests = State.tournamentJoinRequests,
        joins = State.tournamentJoins,
        failures = State.tournamentFailures,
        status = State.tournamentLastStatus,
    }
end
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
        return false, "Reward is unavailable"
    end
    State.tournamentShopWhitelist[id] = enabled == true
    syncTournamentShopWhitelistDropdown()
    updateTournamentShopStatus(
        "Reward list updated."
    )
    return true
end
function Hub.TournamentShop.SetWhitelist(whitelist)
    if type(whitelist) ~= "table" then
        return false, "Whitelist must be a table"
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
        "Reward list updated."
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
        "Tournament Shop refreshed."
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
        heartbeatConnected =
            State.antiAfkHeartbeatConnection ~= nil,
        idledConnected =
            State.antiAfkIdledConnection ~= nil,
        virtualUserAvailable =
            AntiAfkRuntime.virtualUser ~= nil,
        virtualInputManagerAvailable =
            AntiAfkRuntime.virtualInputManager
                ~= nil,
    }
end
function Hub.Utilities.Rejoin()
    return ServerRuntime.rejoin()
end
function Hub.Utilities.GetServerState()
    return ServerRuntime.getState()
end
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
        lastError = State.configLastError,
        startupLoaded = State.configStartupLoaded,
        startupError = State.configStartupError,
        status = State.configLastStatus,
    }
end
function Hub.GetState()
    return {
        running = State.running,
        vulnone = Hub.Vulnone.GetState(),
        packs = Hub.Packs.GetState(),
        rebirth = Hub.Rebirth.GetState(),
        team = Hub.Team.GetState(),
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
        tournament = Hub.Tournament.GetState(),
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
    for _, definition in ipairs(
        BooleanSettingDefinitions
    ) do
        if definition.stop then
            State[definition.state] = false
        end
    end
    VulnoneRuntime.clearPending()
    PackBuyRuntime.disableManagedNative()
    PackBuyRuntime.clearPending()
    State.packOpenPending = nil
    PackRuntime.uninstallHook()
    RebirthRuntime.clearPending()
    State.equipBestBusy = false
    NativeVisualRuntime.restoreAll()
    State.tournamentManualJoinRequested = false
    TournamentRuntime.clearPending()
    clearTournamentShopPending()
    ConnectionRuntime.disconnectAll()
    for _, connection in ipairs(State.uiTextConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(State.uiTextConnections)
    if State.window and type(State.window.Destroy) == "function" then
        pcall(function()
            State.window:Destroy()
        end)
    end
    if Environment.SpinASoccerCardHub == Hub then
        Environment.SpinASoccerCardHub = nil
    end
end
Hub.SetAutoTryVulnoneCard =
    Hub.Vulnone.SetAutoTry
Hub.ToggleAutoTryVulnoneCard =
    Hub.Vulnone.ToggleAutoTry
Hub.TryVulnoneCardNow = Hub.Vulnone.TryNow
Hub.RefreshVulnoneStatus = Hub.Vulnone.Refresh
Hub.GetVulnoneState = Hub.Vulnone.GetState
Hub.SetAutoBuyPacks = Hub.Packs.SetAutoBuy
Hub.ToggleAutoBuyPacks = Hub.Packs.ToggleAutoBuy
Hub.SetAutoNativeBuyPacks =
    Hub.Packs.SetAutoNativeBuy
Hub.ToggleAutoNativeBuyPacks =
    Hub.Packs.ToggleAutoNativeBuy
Hub.SetPackBuyWhitelist = Hub.Packs.SetBuyWhitelist
Hub.GetPackBuyWhitelist = Hub.Packs.GetBuyWhitelist
Hub.SelectAllBuyPacks = Hub.Packs.SelectAllBuyPacks
Hub.ClearPackBuyWhitelist = Hub.Packs.ClearBuyWhitelist
Hub.ProcessNextPackBuy = Hub.Packs.ProcessNextBuy
Hub.SetAutoOpenPacks = Hub.Packs.SetAutoOpen
Hub.ToggleAutoOpenPacks = Hub.Packs.ToggleAutoOpen
Hub.SetSkipPackAnimations =
    Hub.Packs.SetSkipAnimations
Hub.ToggleSkipPackAnimations =
    Hub.Packs.ToggleSkipAnimations
Hub.SetPackResultRarityWhitelist =
    Hub.Packs.SetResultRarityWhitelist
Hub.GetPackResultRarityWhitelist =
    Hub.Packs.GetResultRarityWhitelist
Hub.SelectAllPackResultRarities =
    Hub.Packs.SelectAllResultRarities
Hub.ClearPackResultRarityWhitelist =
    Hub.Packs.ClearResultRarityWhitelist
Hub.ClearPackResultHistory =
    Hub.Packs.ClearResultHistory
Hub.RestartPackAutomation =
    Hub.Packs.RestartAutomation
Hub.ProcessCurrentPack =
    Hub.Packs.ProcessCurrent
Hub.SetHidePackAnimation =
    Hub.Packs.SetHideAnimation
Hub.ToggleHidePackAnimation =
    Hub.Packs.ToggleHideAnimation
Hub.SetAutoSkipPackAnimation =
    Hub.Packs.SetAutoSkip
Hub.ToggleAutoSkipPackAnimation =
    Hub.Packs.ToggleAutoSkip
Hub.ApplyPackSettings = Hub.Packs.ApplySettings
Hub.GetPacksState = Hub.Packs.GetState
Hub.SetAutoRebirth = Hub.Rebirth.SetAuto
Hub.ToggleAutoRebirth = Hub.Rebirth.ToggleAuto
Hub.RebirthNow = Hub.Rebirth.RebirthNow
Hub.GetRebirthState = Hub.Rebirth.GetState
Hub.SetAutoEquipBestCards = Hub.Team.SetAutoEquip
Hub.ToggleAutoEquipBestCards = Hub.Team.ToggleAutoEquip
Hub.SetEquipBestMode = Hub.Team.SetMode
Hub.GetEquipBestMode = Hub.Team.GetMode
Hub.EquipBestCardsNow = Hub.Team.EquipNow
Hub.EquipBestIncomeNow = Hub.Team.EquipBestIncome
Hub.EquipBestRarityNow = Hub.Team.EquipBestRarity
Hub.GetTeamState = Hub.Team.GetState
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
Hub.SetAutoJoinTournament = Hub.Tournament.SetAutoJoin
Hub.ToggleAutoJoinTournament = Hub.Tournament.ToggleAutoJoin
Hub.SetAutoEquipBestTournament =
    Hub.Tournament.SetAutoEquipBest
Hub.ToggleAutoEquipBestTournament =
    Hub.Tournament.ToggleAutoEquipBest
Hub.EquipBestTournamentNow = Hub.Tournament.EquipBestNow
Hub.JoinTournamentNow = Hub.Tournament.JoinNow
Hub.GetTournamentState = Hub.Tournament.GetState
Hub.GetBestTournamentTeam = Hub.Tournament.GetBestTeam
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

NativeVisualRuntime.capture(
    "spin",
    Remotes.SpinWheelRemote.OnClientEvent
)

do
    local success, connectionOrError = pcall(function()
        return Remotes.SpinWheelRemote.OnClientEvent:Connect(onSpinWheelRemote)
    end)
    if success then
        State.spinWheelConnection = connectionOrError
    else
        State.spinWheelLastStatus =
            "Could not attach the spin-result listener: " .. tostring(connectionOrError)
    end
end
do
    local success, connectionOrError = pcall(function()
        return Remotes.TournamentServer.OnClientEvent:Connect(onTournamentServerRemote)
    end)
    if success then
        State.tournamentShopConnection = connectionOrError
    else
        State.tournamentShopLastStatus =
            "Tournament updates are unavailable."
    end
end
do
    local success, connectionOrError = pcall(function()
        return Remotes.TournamentTick.OnClientEvent:Connect(
            TournamentRuntime.handleTick
        )
    end)
    if success then
        State.tournamentTickConnection = connectionOrError
    else
        State.tournamentLastStatus =
            "Tournament timing is unavailable."
        State.tournamentFailures += 1
    end
end
NativeVisualRuntime.capture(
    "pack",
    Remotes.OpenPack.OnClientEvent
)

do
    local success, connectionOrError = pcall(function()
        return Remotes.OpenPack.OnClientEvent:Connect(
            PackRuntime.handleOpenPackEvent
        )
    end)
    if success then
        State.packOpenConnection = connectionOrError
    else
        State.packOpenFailures += 1
        State.packLastStatus =
            "Could not start the OpenPack result listener."
    end
end
NativeVisualRuntime.sync()

do
    local success, connectionOrError = pcall(function()
        return Remotes.ThroneResult.OnClientEvent:Connect(
            VulnoneRuntime.handleResult
        )
    end)
    if success then
        State.vulnoneResultConnection =
            connectionOrError
    else
        State.vulnoneFailures += 1
        State.vulnoneLastStatus =
            "Could not start the Vulnone result listener."
    end
end
do
    local success, connectionOrError = pcall(function()
        return Remotes.DailyReward.OnClientEvent:Connect(
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
    local success, connectionOrError =
        pcall(function()
            return LocalPlayer.Idled:Connect(
                function()
                    if not State.running
                        or not State.antiAfk
                    then
                        return
                    end
                    State.nextAntiAfkPulseAt = 0
                    task.spawn(function()
                        AntiAfkRuntime.pulse(
                            "Idled",
                            true
                        )
                    end)
                end
            )
        end)
    if success then
        State.antiAfkIdledConnection =
            connectionOrError
    else
        State.lastAntiAfkError =
            "Could not attach the idle listener: "
            .. tostring(connectionOrError)
    end
end
do
    local success, connectionOrError =
        pcall(function()
            return RunService.Heartbeat:Connect(
                function()
                    if not State.running then
                        return
                    end
                    local now = os.clock()
                    if State.antiAfk
                        and not State.antiAfkBusy
                        and now
                            >= State.nextAntiAfkPulseAt
                    then
                        State.nextAntiAfkPulseAt =
                            now
                            + (
                                tonumber(
                                    State.antiAfkInterval
                                )
                                or 45
                            )
                        task.spawn(function()
                            AntiAfkRuntime.pulse(
                                "periodic",
                                false
                            )
                        end)
                    end
                end
            )
        end)
    if success then
        State.antiAfkHeartbeatConnection =
            connectionOrError
    else
        State.lastAntiAfkError =
            "Could not attach the Anti AFK heartbeat: "
            .. tostring(connectionOrError)
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
        warn("[xSansHUB] " .. tostring(errorMessage))
    end
end)
SchedulerRuntime.start({
    {
        interval = function()
            return State.packBuyPollInterval
        end,
        callback = PackBuyRuntime.tick,
    },
    {
        interval = function()
            return State.packOpenPollInterval
        end,
        callback = PackRuntime.tick,
    },
    {
        interval = function()
            return State.rebirthPollInterval
        end,
        callback = RebirthRuntime.tick,
    },
    {
        interval = function()
            return State.equipBestPollInterval
        end,
        callback = EquipBestRuntime.tick,
    },
    {
        interval = function()
            return State.interval
        end,
        callback = function()
            if State.autoCraft then
                craftNextWhitelisted()
            end
        end,
    },
    {
        interval = function()
            return State.seashellInterval
        end,
        callback = function()
            if State.autoClaimSeashell then
                claimAllSeashells(false)
            end
        end,
    },
    {
        interval = function()
            return State.spinWheelPollInterval
        end,
        callback = function()
            if State.autoClaimSpinWheel then
                claimFreeSpin(false)
            end
            if State.autoSpinWheel then
                spinWheelNow(false)
            elseif State.spinWheelData
                and os.clock()
                    - State.spinWheelLastDataAt
                    >= 5
            then
                fetchSpinWheelData(false)
            end
        end,
    },
    {
        interval = function()
            return State.wishPollInterval
        end,
        callback = function()
            if State.autoSpinWishTickets then
                WishRuntime.perform(false)
            end
        end,
    },
    {
        interval = function()
            return State.vulnonePollInterval
        end,
        callback = VulnoneRuntime.tick,
    },
    {
        interval = function()
            return State.dailyRewardPollInterval
        end,
        callback = DailyRewardRuntime.tick,
    },
    {
        interval = 0.5,
        callback = function()
            if State.autoRedeemCodes
                and os.clock()
                    >= State.codeNextRedeemAt
            then
                CodesRuntime.redeemNext(false)
            end
        end,
    },
    {
        interval = function()
            return State.indexPollInterval
        end,
        callback = function()
            if State.autoClaimIndex then
                IndexRuntime.claimAll(false)
            end
        end,
    },
    {
        interval = function()
            return State.gemShopPollInterval
        end,
        callback = function()
            if State.autoBuyGemShop then
                buyNextGemShopItem(false)
            end
        end,
    },
    {
        interval = function()
            return State.summerQuestPollInterval
        end,
        callback = function()
            if State.autoClaimSummerQuests then
                claimSummerQuests(false)
            end
        end,
    },
    {
        interval = function()
            return State.summerShopPollInterval
        end,
        callback = function()
            if State.autoBuySummerShop then
                buyNextSummerShopItem(false)
            end
        end,
    },
    {
        interval = function()
            return State.tournamentAutomationPollInterval
        end,
        callback = TournamentRuntime.tick,
    },
    {
        interval = function()
            return State.tournamentShopPollInterval
        end,
        callback = function()
            refreshTournamentShopOptions(true)
            if State.autoBuyTournamentShop then
                buyNextTournamentShopItem(false)
            end
        end,
    },
    {
        interval = 0.5,
        callback = function()
            if State.configInitialized
                and not State.configLoading
            then
                local fingerprint =
                    ConfigRuntime.fingerprint()
                if fingerprint
                    and State.configLastObservedFingerprint
                    and fingerprint
                        ~= State.configLastObservedFingerprint
                then
                    State.configLastObservedFingerprint =
                        fingerprint
                    ConfigRuntime.requestSave()
                elseif fingerprint
                    and State.configLastObservedFingerprint
                        == nil
                then
                    State.configLastObservedFingerprint =
                        fingerprint
                end
            end
        end,
    },
})
return Hub
