--// Fruit Value Display
--// Fitur:
--// - Otomatis membaca Tool dan FruitProxy
--// - Harga hijau dengan stroke hitam
--// - Harga dihitung langsung menggunakan SharedModules.FruitValueCalc
--// - Format harga menggunakan SharedModules.NumberUtils
--// - Harga berada di kiri atas icon
--// - Nama buah dan weight tetap tampil
--// - Toggle Show/Hide Fruit Value
--// - Toggle harga aktual Fruit Stock / harga dasar X1
--// - Sorting harga tertinggi ke terendah
--// - Menampilkan Fruit Stock (tier, multiplier, refresh)
--// - Favorite automation berdasarkan Value Threshold
--// - Mode threshold Above / Below
--// - Auto Favorite / Auto Unfavorite berdasarkan threshold
--// - Auto Favorite All / Auto Unfavorite All
--// - Backpack/Daily Deal totals mengikuti mode Base X1 ON/OFF
--// - Compact + raw totals dengan value berwarna hijau
--// - Tekan L untuk membuka/menutup menu
--// - Hotbar tidak ikut diurutkan

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Backpack = LocalPlayer:WaitForChild("Backpack")

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules")

local NumberUtils = require(
	SharedModules:WaitForChild("NumberUtils")
)

local FruitValueCalc = require(
	SharedModules:WaitForChild("FruitValueCalc")
)

local WeightFormat = require(
	SharedModules:WaitForChild("WeightFormat")
)

local FruitProxyUtil = require(
	SharedModules:WaitForChild("FruitProxyUtil")
)

local MutationData = require(
	SharedModules:WaitForChild("MutationData")
)

local Networking = require(
	SharedModules:WaitForChild("Networking")
)

local SellValueData = require(
	SharedModules:WaitForChild("SellValueData")
)

local SeedShopEnabled = require(
	SharedModules:WaitForChild("SeedShopEnabled")
)

local SellFlags = require(
	SharedModules:WaitForChild("Flags"):WaitForChild("SellFlags")
)

local BackpackGui = PlayerGui:WaitForChild("BackpackGui")

--// =====================================================
--// CONFIG
--// =====================================================

local MENU_KEY = Enum.KeyCode.L
local ACTION_NAME = "ToggleCustomFruitValueMenu"

local PRICE_LABEL_NAME = "FruitValueLabel"
local MENU_GUI_NAME = "FruitValueMenuGui"

local UPDATE_INTERVAL = 0.1

-- Posisi label harga di kiri atas slot/icon.
local PRICE_POSITION = UDim2.new(0, 3, 0, 2)
local PRICE_SIZE = UDim2.new(1, -6, 0, 16)

local PRICE_COLOR = Color3.fromRGB(80, 255, 120)
local PRICE_STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local PRICE_STROKE_TRANSPARENCY = 0

local FruitValueEnabled = true

-- Jika aktif, tampilkan hasil FruitValueCalc secara langsung (X1).
-- Jika nonaktif, hasil X1 dikalikan multiplier Fruit Stock aktif.
local BaseX1PriceEnabled = false

local SortPriceDescendingEnabled = false

--// Favorite automation.
--// Above: nilai >= threshold dianggap cocok.
--// Below: nilai <= threshold dianggap cocok.
local FavoriteThresholdMode = "Above"
local FavoriteValueThreshold = 0

-- Auto Favorite dan Auto Unfavorite sama-sama bekerja pada item
-- yang COCOK dengan Threshold Mode.
-- Contoh Above 10M:
-- Auto Favorite   -> favorite item dengan harga >= 10M.
-- Auto Unfavorite -> unfavorite item dengan harga >= 10M.
-- Kedua mode dibuat eksklusif agar tidak saling bertabrakan.
local AutoFavoriteEnabled = false
local AutoUnfavoriteEnabled = false

-- Mode All mengabaikan threshold dan bersifat eksklusif.
local AutoFavoriteAllEnabled = false
local AutoUnfavoriteAllEnabled = false

-- Beberapa worker memproses request favorite secara paralel supaya
-- inventory besar tidak membutuhkan waktu terlalu lama.
local FAVORITE_WORKER_COUNT = 12
local FAVORITE_REQUEST_DELAY = 0.01

local FavoritePendingActions = {}
local FavoriteRequestQueue = {}
local FavoriteQueueHead = 1
local FavoriteQueueTail = 0
local FavoriteQueuedCount = 0
local FavoriteWorkersStarted = false
local FavoriteAutomationGeneration = 0
local FavoriteActionVersions = {}
local FavoriteAsyncError = nil

local FavoriteLastSummary = "Favorite automation: OFF"

local MenuOpened = false
local Running = true

-- Menyimpan hubungan frame GUI dengan Tool/FruitProxy.
local SlotItemReferences = setmetatable({}, {
	__mode = "k",
})

-- Menyimpan urutan asli slot sebelum sorting.
local NativeLayoutOrders = setmetatable({}, {
	__mode = "k",
})

local MutationSignatureCache = {}

-- Cache kalkulasi agar FruitValueCalc tidak dipanggil ulang
-- setiap 0.1 detik ketika attribute buah tidak berubah.
local FruitValueCalcCache = setmetatable({}, {
	__mode = "k",
})

local FruitValueCalcErrorCache = setmetatable({}, {
	__mode = "k",
})

--// Fruit Stock state.
local FruitStockEntries = {}
local FruitStockLastRefreshUnix = 0
local FruitStockNextRefreshUnix = 0
local FruitStockCycleSeconds = 600
local FruitStockServerOffset = 0

-- Anchor waktu server agar countdown tidak bergantung
-- pada jam perangkat/client.
local FruitStockServerUnixAtSync = nil
local FruitStockLocalTimeAtSync = nil

local FruitStockSnapshotReceived = false
local FruitStockConnection = nil

--// Fruit Stock GUI references (dibuat pada bagian MENU GUI).
local FruitStockList = nil
local FruitStockStatusLabel = nil
local FruitStockTimerLabel = nil

--// Favorite automation GUI references.
local FavoriteStatusLabel = nil
local ThresholdModeButton = nil
local ThresholdValueBox = nil
local AutoFavoriteButton = nil
local AutoUnfavoriteButton = nil
local AutoFavoriteAllButton = nil
local AutoUnfavoriteAllButton = nil

--// Backpack summary GUI references.
local BackpackValueTotalLabel = nil
local BackpackValueNonFavoriteLabel = nil
local DailyDealTotalLabel = nil
local DailyDealNonFavoriteLabel = nil
local BackpackSummaryStatusLabel = nil

-- Timer bawaan game dijadikan sumber utama agar angka yang
-- ditampilkan selalu sama persis dengan GUI FruitStockPrice.
local NativeFruitStockTimerLabel = nil

--// =====================================================
--// CLEANUP INSTANCE LAMA
--// =====================================================

ContextActionService:UnbindAction(ACTION_NAME)

local OldMenu = PlayerGui:FindFirstChild(MENU_GUI_NAME)

if OldMenu then
	OldMenu:Destroy()
end

for _, object in ipairs(BackpackGui:GetDescendants()) do
	if object.Name == PRICE_LABEL_NAME then
		object:Destroy()
	end
end

--// =====================================================
--// FORMAT ANGKA
--// =====================================================

local function FormatCompactNumber(value)
	value = tonumber(value) or 0

	-- Mengikuti formatter harga bawaan game:
	-- maksimal dua angka di belakang desimal.
	return NumberUtils.Abbreviate(value, 2)
end

local function FormatWeight(value)
	value = tonumber(value) or 0

	local success, result = pcall(function()
		return WeightFormat.FormatGrams(value)
	end)

	if success and result ~= nil then
		return tostring(result)
	end

	return string.format("%.2f", value)
end

--// =====================================================
--// FRUIT STOCK
--// =====================================================

local function FormatMultiplier(value)
	value = tonumber(value) or 1

	local rounded = math.floor(value * 100 + 0.5) / 100

	if rounded == math.floor(rounded) then
		return string.format("X%d", rounded)
	end

	return (
		"X" .. string.format("%.2f", rounded)
			:gsub("0+$", "")
			:gsub("%.$", "")
	)
end

local function FormatRawMultiplier(value)
	value = tonumber(value) or 1

	-- Menampilkan nilai snapshot dengan presisi tinggi tanpa
	-- mengubah nilai yang digunakan oleh perhitungan harga.
	return "Raw X" .. string.format("%.12g", value)
end

local function FormatDuration(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))

	local minutes = seconds // 60
	local remainingSeconds = seconds % 60

	return string.format("%dm %02ds", minutes, remainingSeconds)
end

local function GetFruitStockServerUnix()
	-- Gunakan timestamp server dari snapshot sebagai sumber
	-- utama agar countdown sama dengan controller asli.
	-- time() bersifat monotonic dan tidak terpengaruh jam PC.
	if FruitStockServerUnixAtSync
		and FruitStockLocalTimeAtSync
	then
		return FruitStockServerUnixAtSync
			+ (time() - FruitStockLocalTimeAtSync)
	end

	-- Fallback sebelum snapshot pertama diterima.
	local success, serverUnix = pcall(function()
		return workspace:GetServerTimeNow()
	end)

	if success and typeof(serverUnix) == "number" then
		return serverUnix
	end

	return os.time() + FruitStockServerOffset
end

local function GetTierStyle(tier)
	tier = string.lower(tostring(tier or "normal"))

	if tier == "mega" then
		return "MEGA", Color3.fromRGB(236, 116, 255), 1
	end

	if tier == "big" then
		return "BIG", Color3.fromRGB(255, 196, 84), 2
	end

	return "NORMAL", Color3.fromRGB(154, 202, 166), 3
end

local function ParseFruitStockEntries(snapshot)
	local parsedEntries = {}

	if typeof(snapshot) ~= "table" then
		return parsedEntries
	end

	local sourceEntries = snapshot

	if typeof(snapshot.entries) == "table" then
		sourceEntries = snapshot.entries
	end

	for fruitName, entryData in pairs(sourceEntries) do
		if typeof(fruitName) ~= "string"
			or typeof(entryData) ~= "table"
		then
			continue
		end

		-- Abaikan table metadata yang bukan entry buah.
		if entryData.multiplier == nil
			and entryData.tier == nil
		then
			continue
		end

		parsedEntries[fruitName] = {
			multiplier = typeof(entryData.multiplier) == "number"
					and entryData.multiplier
				or 1,

			tier = typeof(entryData.tier) == "string"
					and string.lower(entryData.tier)
				or "normal",
		}
	end

	return parsedEntries
end

-- Mengambil multiplier Fruit Stock berdasarkan nama buah.
-- Lookup kedua bersifat case-insensitive sebagai fallback jika
-- penulisan nama pada Tool dan snapshot sedikit berbeda.
local function GetFruitStockMultiplier(fruitName)
	local normalizedName = tostring(fruitName or "")
	local entry = FruitStockEntries[normalizedName]

	if not entry then
		local lowerName = string.lower(normalizedName)

		for stockFruitName, stockEntry in pairs(FruitStockEntries) do
			if string.lower(tostring(stockFruitName)) == lowerName then
				entry = stockEntry
				break
			end
		end
	end

	local multiplier = tonumber(entry and entry.multiplier) or 1

	-- Hindari pembagian dengan nol atau multiplier invalid.
	if multiplier <= 0 then
		return 1
	end

	return multiplier
end

-- FruitValue tidak dibaca dari attribute item.
-- Harga X1 dihitung oleh FruitValueCalc menggunakan SizeMultiplier.
-- Harga aktual adalah hasil X1 dikalikan multiplier Fruit Stock raw.
local function GetActualFruitValue(data)
	local baseX1Value = tonumber(
		data and data.BaseX1Value
	) or 0

	local stockMultiplier = GetFruitStockMultiplier(
		data and data.FruitName
	)

	return math.floor(baseX1Value * stockMultiplier)
end

local function GetDisplayedFruitValue(data)
	if BaseX1PriceEnabled then
		return tonumber(data and data.BaseX1Value) or 0
	end

	return GetActualFruitValue(data)
end

-- Daily Deal dihitung per buah lalu dijumlahkan agar mengikuti
-- pembulatan per item pada SellFlags.DailyDealPrice.
local function GetDailyDealMultiplier()
	local multiplier = 5
	local flag = SellFlags.DailyDealMultiplier

	if flag and typeof(flag.Get) == "function" then
		local success, value = pcall(function()
			return flag:Get()
		end)

		if success and typeof(value) == "number" and value > 0 then
			multiplier = value
		end
	end

	return multiplier
end

local function GetDailyDealFruitValue(actualValue, multiplier)
	actualValue = math.max(0, math.floor(
		tonumber(actualValue) or 0
	))

	if actualValue <= 0 then
		return 0
	end

	return math.max(1, math.floor(
		actualValue * (tonumber(multiplier) or 5)
	))
end

local function GetFruitStockRows()
	local rows = {}
	local included = {}

	-- Sama seperti controller asli: semua seed yang aktif tetap ditampilkan.
	for fruitName, baseValue in pairs(SellValueData) do
		local enabled = true

		local success, result = pcall(function()
			return SeedShopEnabled.IsSeedEnabled(fruitName)
		end)

		if success then
			enabled = result == true
		end

		if enabled then
			local entry = FruitStockEntries[fruitName] or {
				multiplier = 1,
				tier = "normal",
			}

			table.insert(rows, {
				FruitName = tostring(fruitName),
				BaseValue = tonumber(baseValue) or 0,
				Multiplier = tonumber(entry.multiplier) or 1,
				Tier = tostring(entry.tier or "normal"),
			})

			included[fruitName] = true
		end
	end

	-- Fallback: tetap tampilkan entry snapshot yang tidak ada di SellValueData.
	for fruitName, entry in pairs(FruitStockEntries) do
		if not included[fruitName] then
			table.insert(rows, {
				FruitName = tostring(fruitName),
				BaseValue = 0,
				Multiplier = tonumber(entry.multiplier) or 1,
				Tier = tostring(entry.tier or "normal"),
			})
		end
	end

	table.sort(rows, function(a, b)
		local _, _, aTierOrder = GetTierStyle(a.Tier)
		local _, _, bTierOrder = GetTierStyle(b.Tier)

		if aTierOrder ~= bTierOrder then
			return aTierOrder < bTierOrder
		end

		if a.Multiplier ~= b.Multiplier then
			return a.Multiplier > b.Multiplier
		end

		if a.BaseValue ~= b.BaseValue then
			return a.BaseValue > b.BaseValue
		end

		return string.lower(a.FruitName)
			< string.lower(b.FruitName)
	end)

	return rows
end

local function ClearFruitStockRows()
	if not FruitStockList then
		return
	end

	for _, child in ipairs(FruitStockList:GetChildren()) do
		if child.Name == "FruitStockRow" then
			child:Destroy()
		end
	end
end

local function RenderFruitStockRows()
	if not FruitStockList then
		return
	end

	ClearFruitStockRows()

	local rows = GetFruitStockRows()

	for index, rowData in ipairs(rows) do
		local tierText, tierColor = GetTierStyle(rowData.Tier)

		local Row = Instance.new("Frame")
		Row.Name = "FruitStockRow"
		Row.LayoutOrder = index
		Row.Size = UDim2.new(1, -2, 0, 42)
		Row.BackgroundColor3 = index % 2 == 0
			and Color3.fromRGB(34, 41, 36)
			or Color3.fromRGB(30, 36, 32)
		Row.BackgroundTransparency = 0.1
		Row.BorderSizePixel = 0
		Row.ZIndex = 106
		Row.Parent = FruitStockList

		local RowCorner = Instance.new("UICorner")
		RowCorner.CornerRadius = UDim.new(0, 5)
		RowCorner.Parent = Row

		local Accent = Instance.new("Frame")
		Accent.Name = "Accent"
		Accent.Size = UDim2.new(0, 3, 1, -10)
		Accent.Position = UDim2.new(0, 5, 0, 5)
		Accent.BackgroundColor3 = tierColor
		Accent.BorderSizePixel = 0
		Accent.ZIndex = 107
		Accent.Parent = Row

		local AccentCorner = Instance.new("UICorner")
		AccentCorner.CornerRadius = UDim.new(1, 0)
		AccentCorner.Parent = Accent

		local FruitNameLabel = Instance.new("TextLabel")
		FruitNameLabel.Name = "FruitName"
		FruitNameLabel.Position = UDim2.new(0, 15, 0, 0)
		FruitNameLabel.Size = UDim2.new(0.55, -15, 1, 0)
		FruitNameLabel.BackgroundTransparency = 1
		FruitNameLabel.Text = rowData.FruitName
		FruitNameLabel.TextColor3 = Color3.fromRGB(232, 243, 235)
		FruitNameLabel.TextSize = 12
		FruitNameLabel.Font = Enum.Font.GothamSemibold
		FruitNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		FruitNameLabel.TextXAlignment = Enum.TextXAlignment.Left
		FruitNameLabel.ZIndex = 107
		FruitNameLabel.Parent = Row

		local TierLabel = Instance.new("TextLabel")
		TierLabel.Name = "Tier"
		TierLabel.Position = UDim2.new(0.55, 0, 0, 0)
		TierLabel.Size = UDim2.new(0.22, 0, 1, 0)
		TierLabel.BackgroundTransparency = 1
		TierLabel.Text = tierText
		TierLabel.TextColor3 = tierColor
		TierLabel.TextSize = 11
		TierLabel.Font = Enum.Font.GothamBold
		TierLabel.TextXAlignment = Enum.TextXAlignment.Center
		TierLabel.ZIndex = 107
		TierLabel.Parent = Row

		local MultiplierLabel = Instance.new("TextLabel")
		MultiplierLabel.Name = "Multiplier"
		MultiplierLabel.Position = UDim2.new(0.72, 0, 0, 3)
		MultiplierLabel.Size = UDim2.new(0.28, -10, 0, 19)
		MultiplierLabel.BackgroundTransparency = 1
		MultiplierLabel.Text = FormatMultiplier(rowData.Multiplier)
		MultiplierLabel.TextColor3 = Color3.fromRGB(112, 255, 151)
		MultiplierLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		MultiplierLabel.TextStrokeTransparency = 0.35
		MultiplierLabel.TextSize = 13
		MultiplierLabel.Font = Enum.Font.GothamBold
		MultiplierLabel.TextXAlignment = Enum.TextXAlignment.Right
		MultiplierLabel.ZIndex = 107
		MultiplierLabel.Parent = Row

		local RawMultiplierLabel = Instance.new("TextLabel")
		RawMultiplierLabel.Name = "RawMultiplier"
		RawMultiplierLabel.Position = UDim2.new(0.64, 0, 0, 21)
		RawMultiplierLabel.Size = UDim2.new(0.36, -10, 0, 16)
		RawMultiplierLabel.BackgroundTransparency = 1
		RawMultiplierLabel.Text = FormatRawMultiplier(rowData.Multiplier)
		RawMultiplierLabel.TextColor3 = Color3.fromRGB(168, 193, 174)
		RawMultiplierLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		RawMultiplierLabel.TextStrokeTransparency = 0.55
		RawMultiplierLabel.TextSize = 9
		RawMultiplierLabel.Font = Enum.Font.Gotham
		RawMultiplierLabel.TextXAlignment = Enum.TextXAlignment.Right
		RawMultiplierLabel.TextTruncate = Enum.TextTruncate.AtEnd
		RawMultiplierLabel.ZIndex = 107
		RawMultiplierLabel.Parent = Row
	end

	if FruitStockStatusLabel then
		if FruitStockSnapshotReceived then
			FruitStockStatusLabel.Text = string.format(
				"Snapshot aktif • %d buah",
				#rows
			)
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(137, 221, 158)
		else
			FruitStockStatusLabel.Text = "Menunggu snapshot Fruit Stock..."
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(225, 190, 116)
		end
	end
end

local function FindNativeFruitStockTimerLabel()
	if NativeFruitStockTimerLabel
		and NativeFruitStockTimerLabel.Parent
	then
		return NativeFruitStockTimerLabel
	end

	NativeFruitStockTimerLabel = nil

	local fruitStockGui = PlayerGui:FindFirstChild(
		"FruitStockPrice"
	)

	if not fruitStockGui then
		return nil
	end

	local frame = fruitStockGui:FindFirstChild("Frame")
	local header = frame and frame:FindFirstChild("Header")
	local refreshIn = header and header:FindFirstChild("RefreshIn")
	local timer = refreshIn and refreshIn:FindFirstChild("Timer")

	if timer and (
		timer:IsA("TextLabel")
		or timer:IsA("TextButton")
	) then
		NativeFruitStockTimerLabel = timer
		return timer
	end

	return nil
end

local function GetNativeFruitStockRemaining()
	local timer = FindNativeFruitStockTimerLabel()

	if not timer then
		return nil, nil
	end

	-- Controller asli hanya memperbarui timer ketika ScreenGui aktif.
	-- Jangan memakai teks lama saat GUI bawaan sedang ditutup.
	local screenGui = timer:FindFirstAncestorWhichIsA("ScreenGui")

	if screenGui and not screenGui.Enabled then
		return nil, nil
	end

	local text = tostring(timer.Text or "")
	local minutesText, secondsText = text:match(
		"(%d+)%s*m%s*(%d+)%s*s"
	)

	local minutes = tonumber(minutesText)
	local seconds = tonumber(secondsText)

	if not minutes or not seconds then
		return nil, nil
	end

	local remaining = minutes * 60 + seconds

	return remaining, string.format(
		"%dm %02ds",
		minutes,
		seconds
	)
end

local function UpdateFruitStockTimer()
	if not FruitStockTimerLabel then
		return
	end

	-- Sumber utama: timer yang sedang ditampilkan oleh GUI asli.
	-- Ini menjamin angka panel sama persis dengan referensi game.
	local nativeRemaining, nativeText =
		GetNativeFruitStockRemaining()

	if nativeRemaining ~= nil and nativeText ~= nil then
		FruitStockTimerLabel.Text = "Refresh: " .. nativeText

		-- Sinkronkan fallback juga. Jika GUI asli kemudian ditutup,
		-- countdown custom akan melanjutkan dari nilai terakhir ini.
		FruitStockNextRefreshUnix =
			GetFruitStockServerUnix() + nativeRemaining

		return
	end

	if not FruitStockSnapshotReceived then
		FruitStockTimerLabel.Text = "Refresh: --"
		return
	end

	-- Fallback ketika GUI FruitStockPrice bawaan tidak sedang aktif.
	local remaining = math.max(
		0,
		FruitStockNextRefreshUnix - GetFruitStockServerUnix()
	)

	FruitStockTimerLabel.Text =
		"Refresh: " .. FormatDuration(remaining)
end

local function ApplyFruitStockSnapshot(snapshot)
	if typeof(snapshot) ~= "table" then
		if FruitStockStatusLabel then
			FruitStockStatusLabel.Text =
				"Snapshot tidak valid: " .. typeof(snapshot)
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(255, 124, 124)
		end
		return
	end

	FruitStockEntries = ParseFruitStockEntries(snapshot)
	FruitStockSnapshotReceived = true

	if typeof(snapshot.lastRefreshUnix) == "number" then
		FruitStockLastRefreshUnix = snapshot.lastRefreshUnix
	end

	if typeof(snapshot.nextRefreshUnix) == "number" then
		FruitStockNextRefreshUnix = snapshot.nextRefreshUnix
	end

	if typeof(snapshot.cycleSeconds) == "number"
		and snapshot.cycleSeconds > 0
	then
		FruitStockCycleSeconds = snapshot.cycleSeconds
	end

	if typeof(snapshot.server_now_unix) == "number" then
		FruitStockServerOffset =
			snapshot.server_now_unix - os.time()

		-- Simpan anchor waktu snapshot. time() bersifat
		-- monotonic sehingga countdown tetap stabil meskipun
		-- jam perangkat berbeda atau berubah.
		FruitStockServerUnixAtSync =
			snapshot.server_now_unix
		FruitStockLocalTimeAtSync = time()
	end

	RenderFruitStockRows()
	UpdateFruitStockTimer()
end

local function SetupFruitStockNetworking()
	local fruitStockNetwork = Networking.FruitStock

	if not fruitStockNetwork then
		if FruitStockStatusLabel then
			FruitStockStatusLabel.Text =
				"Networking.FruitStock tidak ditemukan"
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(255, 124, 124)
		end
		return
	end

	local snapshotSignal = fruitStockNetwork.Snapshot

	if snapshotSignal
		and snapshotSignal.OnClientEvent
	then
		local success, result = pcall(function()
			return snapshotSignal.OnClientEvent:Connect(
				ApplyFruitStockSnapshot
			)
		end)

		if success then
			FruitStockConnection = result
		elseif FruitStockStatusLabel then
			FruitStockStatusLabel.Text =
				"Gagal connect Snapshot: " .. tostring(result)
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(255, 124, 124)
		end
	elseif FruitStockStatusLabel then
		FruitStockStatusLabel.Text =
			"FruitStock.Snapshot tidak tersedia"
		FruitStockStatusLabel.TextColor3 = Color3.fromRGB(255, 124, 124)
	end

	local request = fruitStockNetwork.Request

	if not request then
		if FruitStockStatusLabel then
			FruitStockStatusLabel.Text =
				"FruitStock.Request tidak tersedia"
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(255, 124, 124)
		end
		return
	end

	local success, result = pcall(function()
		return request:Fire()
	end)

	if not success then
		if FruitStockStatusLabel then
			FruitStockStatusLabel.Text =
				"Request gagal: " .. tostring(result)
			FruitStockStatusLabel.TextColor3 = Color3.fromRGB(255, 124, 124)
		end
		return
	end

	-- Beberapa wrapper Networking mengembalikan snapshot langsung,
	-- sebagian lainnya mengirimkannya lewat Snapshot.OnClientEvent.
	if typeof(result) == "table" then
		ApplyFruitStockSnapshot(result)
	elseif FruitStockStatusLabel then
		FruitStockStatusLabel.Text =
			"Request terkirim • menunggu snapshot..."
		FruitStockStatusLabel.TextColor3 = Color3.fromRGB(225, 190, 116)
	end
end

--// =====================================================
--// MUTATION SIGNATURE
--// Membantu membedakan buah dengan nama dan weight sama,
--// tetapi mutation berbeda.
--// =====================================================

local function ColorSequenceSignature(sequence)
	local result = {}

	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(result, string.format(
			"%.4f:%.4f,%.4f,%.4f",
			keypoint.Time,
			keypoint.Value.R,
			keypoint.Value.G,
			keypoint.Value.B
		))
	end

	return table.concat(result, ";")
end

local function NumberSequenceSignature(sequence)
	local result = {}

	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(result, string.format(
			"%.4f:%.4f:%.4f",
			keypoint.Time,
			keypoint.Value,
			keypoint.Envelope
		))
	end

	return table.concat(result, ";")
end

local function GradientSignature(gradient)
	if not gradient
		or not gradient:IsA("UIGradient")
	then
		return "None"
	end

	return table.concat({
		ColorSequenceSignature(gradient.Color),
		NumberSequenceSignature(gradient.Transparency),
		string.format("%.3f", gradient.Rotation),
		tostring(gradient.Enabled),
	}, "|")
end

local function GetMutationSignature(mutationName)
	if mutationName == nil
		or mutationName == ""
	then
		return "None"
	end

	local cached = MutationSignatureCache[mutationName]

	if cached then
		return cached
	end

	local signature =
		"Mutation:" .. tostring(mutationName)

	local success, mutationInfo = pcall(function()
		return MutationData.GetMutation(mutationName)
	end)

	if success
		and mutationInfo
		and mutationInfo.Gradient
	then
		signature = GradientSignature(
			mutationInfo.Gradient
		)
	end

	MutationSignatureCache[mutationName] = signature

	return signature
end

--// =====================================================
--// DATA BUAH
--// =====================================================

local function GetFruitName(item)
	return item:GetAttribute("Fruit")
		or item:GetAttribute("FruitName")
end

local function IsFruitInstance(item)
	if typeof(item) ~= "Instance" then
		return false
	end

	local isFruit = false

	-- Mendeteksi Tool buah maupun FruitProxy.
	local success, result = pcall(function()
		return FruitProxyUtil.IsFruitInstance(item)
	end)

	if success and result then
		isFruit = true
	end

	-- Fallback jika fungsi IsFruitInstance tidak
	-- mengenali jenis tertentu.
	if not isFruit then
		local proxySuccess, isProxy = pcall(function()
			return FruitProxyUtil.IsFruitProxy(item)
		end)

		if proxySuccess and isProxy then
			isFruit = true
		end
	end

	if not isFruit then
		local toolSuccess, isFruitTool = pcall(function()
			return FruitProxyUtil.IsFruitTool(item)
		end)

		if toolSuccess and isFruitTool then
			isFruit = true
		end
	end

	-- Fallback terakhir untuk Tool biasa.
	if not isFruit then
		isFruit =
			item:IsA("Tool")
			and item:GetAttribute("HarvestedFruit") == true
	end

	if not isFruit then
		return false
	end

	return GetFruitName(item) ~= nil
		and tonumber(item:GetAttribute("Weight")) ~= nil
		and tonumber(item:GetAttribute("SizeMultiplier")) ~= nil
end

local function CreateBasicKey(
	fruitName,
	weightText
)
	return string.format(
		"%s\0%s",
		tostring(fruitName),
		tostring(weightText)
	)
end

local function CreateExactKey(
	fruitName,
	weightText,
	mutationSignature
)
	return string.format(
		"%s\0%s\0%s",
		tostring(fruitName),
		tostring(weightText),
		tostring(mutationSignature)
	)
end

local function CalculateBaseX1Value(
	item,
	fruitName,
	sizeMultiplier,
	mutation,
	decayAlpha
)
	local friends = tonumber(
		item:GetAttribute("Friends")
	) or 0

	local signature = table.concat({
		tostring(fruitName),
		tostring(sizeMultiplier),
		tostring(mutation or ""),
		tostring(friends),
		tostring(decayAlpha),
	}, "\0")

	local cached = FruitValueCalcCache[item]

	if cached and cached.Signature == signature then
		return cached.Value
	end

	local success, result = pcall(function()
		return FruitValueCalc(
			tostring(fruitName),
			sizeMultiplier,
			mutation,
			item,
			decayAlpha
		)
	end)

	if not success then
		local errorText = tostring(result)

		if FruitValueCalcErrorCache[item] ~= errorText then
			FruitValueCalcErrorCache[item] = errorText

			warn(
				"[FruitValueCalc] "
					.. tostring(fruitName)
					.. ": "
					.. errorText
			)
		end

		return nil
	end

	local value = tonumber(result)

	if value == nil then
		return nil
	end

	FruitValueCalcErrorCache[item] = nil
	FruitValueCalcCache[item] = {
		Signature = signature,
		Value = value,
	}

	return value
end

local function CollectFruitData()
	local fruitData = {}
	local dataByItem = {}
	local collectedIdentities = {}

	local function ScanContainer(container)
		if not container then
			return
		end

		for _, item in ipairs(container:GetChildren()) do
			if not IsFruitInstance(item) then
				continue
			end

			local fruitName = GetFruitName(item)

			local weight = tonumber(
				item:GetAttribute("Weight")
			)

			local sizeMultiplier = tonumber(
				item:GetAttribute("SizeMultiplier")
			)

			if fruitName == nil
				or weight == nil
				or sizeMultiplier == nil
				or sizeMultiplier <= 0
			then
				continue
			end

			-- Mencegah data ganda ketika proxy sedang
			-- diganti menjadi Tool.
			local fruitId = item:GetAttribute("Id")
			local identity

			if fruitId ~= nil then
				identity = "ID:" .. tostring(fruitId)
			else
				identity = item
			end

			if collectedIdentities[identity] then
				continue
			end

			collectedIdentities[identity] = true

			local mutation =
				item:GetAttribute("Mutation")

			if mutation == "" or mutation == "None" then
				mutation = nil
			end

			local decayAlpha = math.clamp(
				tonumber(
					item:GetAttribute("DecayAlpha")
				) or 0,
				0,
				1
			)

			local baseX1Value = CalculateBaseX1Value(
				item,
				fruitName,
				sizeMultiplier,
				mutation,
				decayAlpha
			)

			if baseX1Value == nil then
				continue
			end

			local weightText =
				FormatWeight(weight)

			local mutationSignature =
				GetMutationSignature(mutation)

			local data = {
				Item = item,
				FruitId = fruitId,
				IsFavorite = item:GetAttribute("IsFavorite") == true,

				FruitName = tostring(fruitName),
				BaseX1Value = baseX1Value,

				SizeMultiplier = sizeMultiplier,
				DecayAlpha = decayAlpha,

				Weight = weight,
				WeightText = weightText,

				Mutation = mutation,
				MutationSignature = mutationSignature,

				BasicKey = CreateBasicKey(
					fruitName,
					weightText
				),

				ExactKey = CreateExactKey(
					fruitName,
					weightText,
					mutationSignature
				),
			}

			table.insert(fruitData, data)
			dataByItem[item] = data
		end
	end

	-- Item yang sedang di-equip.
	ScanContainer(LocalPlayer.Character)

	-- Tool dan proxy di Backpack.
	ScanContainer(Backpack)

	return fruitData, dataByItem
end

--// =====================================================
--// FAVORITE AUTOMATION
--// =====================================================

local function GetFavoriteRemote()
	local backpackNetwork = Networking.Backpack

	if not backpackNetwork then
		return nil
	end

	return backpackNetwork.SetFruitFavorite
end

local function IsThresholdMatch(data)
	local value = GetDisplayedFruitValue(data)
	local threshold = math.max(
		0,
		tonumber(FavoriteValueThreshold) or 0
	)

	if FavoriteThresholdMode == "Below" then
		return value <= threshold, value
	end

	return value >= threshold, value
end

local function GetDesiredFavoriteState(data)
	if AutoFavoriteAllEnabled then
		return true, "ALL"
	end

	if AutoUnfavoriteAllEnabled then
		return false, "ALL"
	end

	local matchesThreshold = IsThresholdMatch(data)

	-- Threshold mode menentukan item TARGET. Auto Favorite maupun
	-- Auto Unfavorite hanya bekerja pada item yang cocok target.
	if not matchesThreshold then
		return nil, "NONE"
	end

	if AutoFavoriteEnabled then
		return true, "THRESHOLD"
	end

	if AutoUnfavoriteEnabled then
		return false, "THRESHOLD"
	end

	return nil, "NONE"
end

local function PopFavoriteRequest()
	if FavoriteQueueHead > FavoriteQueueTail then
		return nil
	end

	local request = FavoriteRequestQueue[FavoriteQueueHead]
	FavoriteRequestQueue[FavoriteQueueHead] = nil
	FavoriteQueueHead += 1
	FavoriteQueuedCount = math.max(0, FavoriteQueuedCount - 1)

	-- Reset index ketika antrean kosong agar tabel tetap ringkas.
	if FavoriteQueueHead > FavoriteQueueTail then
		FavoriteRequestQueue = {}
		FavoriteQueueHead = 1
		FavoriteQueueTail = 0
	end

	return request
end

local function StartFavoriteWorkers()
	if FavoriteWorkersStarted then
		return
	end

	FavoriteWorkersStarted = true

	for _ = 1, FAVORITE_WORKER_COUNT do
		task.spawn(function()
			while Running do
				local request = PopFavoriteRequest()

				if not request then
					task.wait(0.025)
					continue
				end

				local pending =
					FavoritePendingActions[request.Key]

				-- Request lama dibuang jika threshold/mode sudah berubah
				-- atau sudah digantikan request yang lebih baru untuk ID sama.
				if not pending
					or pending.Version ~= request.Version
					or request.Generation ~= FavoriteAutomationGeneration
				then
					task.wait()
					continue
				end

				local favoriteRemote = GetFavoriteRemote()
				local success = false
				local errorMessage = nil

				if favoriteRemote
					and typeof(favoriteRemote.Fire) == "function"
				then
					success, errorMessage = pcall(function()
						favoriteRemote:Fire(
							request.FruitId,
							request.Target
						)
					end)
				else
					errorMessage =
						"Networking.Backpack.SetFruitFavorite tidak tersedia"
				end

				local latestPending =
					FavoritePendingActions[request.Key]

				if latestPending
					and latestPending.Version == request.Version
				then
					FavoritePendingActions[request.Key] = nil
				end

				if not success then
					FavoriteAsyncError = tostring(errorMessage)

					-- Kembalikan visual lokal hanya jika request ini masih
					-- merupakan aksi terbaru untuk item tersebut.
					if request.Item
						and request.Item.Parent
						and FavoriteActionVersions[request.Key]
							== request.Version
					then
						request.Item:SetAttribute(
							"IsFavorite",
							request.PreviousAttribute
						)
					end
				end

				task.wait(FAVORITE_REQUEST_DELAY)
			end
		end)
	end
end

local function InvalidateFavoriteQueue()
	FavoriteAutomationGeneration += 1
	FavoriteRequestQueue = {}
	FavoriteQueueHead = 1
	FavoriteQueueTail = 0
	FavoriteQueuedCount = 0
	FavoritePendingActions = {}
end

local function SetFavoriteState(data, desiredState)
	local item = data and data.Item
	local fruitId = data and data.FruitId

	if not item or not item.Parent then
		return false, "Item tidak valid"
	end

	if fruitId == nil then
		return false, "Fruit Id tidak tersedia"
	end

	local favoriteRemote = GetFavoriteRemote()

	if not favoriteRemote
		or typeof(favoriteRemote.Fire) ~= "function"
	then
		return false,
			"Networking.Backpack.SetFruitFavorite tidak tersedia"
	end

	local pendingKey = tostring(fruitId)
	local currentState =
		item:GetAttribute("IsFavorite") == true
	local pending = FavoritePendingActions[pendingKey]

	if currentState == desiredState
		and (
			not pending
			or pending.Target == desiredState
		)
	then
		return false, nil
	end

	if pending and pending.Target == desiredState then
		return false, nil
	end

	local previousAttribute =
		item:GetAttribute("IsFavorite")

	local version =
		(FavoriteActionVersions[pendingKey] or 0) + 1

	FavoriteActionVersions[pendingKey] = version
	FavoritePendingActions[pendingKey] = {
		Target = desiredState,
		Version = version,
	}

	-- Optimistic local update: icon favorite berubah langsung dan
	-- refresh 0.1 detik tidak memasukkan request yang sama berulang.
	item:SetAttribute(
		"IsFavorite",
		desiredState == true
	)

	data.IsFavorite = desiredState == true

	FavoriteQueueTail += 1
	FavoriteRequestQueue[FavoriteQueueTail] = {
		Key = pendingKey,
		FruitId = fruitId,
		Target = desiredState == true,
		Item = item,
		PreviousAttribute = previousAttribute,
		Version = version,
		Generation = FavoriteAutomationGeneration,
	}

	FavoriteQueuedCount += 1
	StartFavoriteWorkers()

	return true, nil
end

local function IsFavoriteAutomationEnabled()
	return AutoFavoriteEnabled
		or AutoUnfavoriteEnabled
		or AutoFavoriteAllEnabled
		or AutoUnfavoriteAllEnabled
end

local function UpdateFavoriteStatusLabel(text, isError)
	FavoriteLastSummary = tostring(text or "")

	if not FavoriteStatusLabel then
		return
	end

	FavoriteStatusLabel.Text = FavoriteLastSummary
	FavoriteStatusLabel.TextColor3 = isError
		and Color3.fromRGB(255, 132, 132)
		or Color3.fromRGB(166, 190, 172)
end

local function ApplyFavoriteAutomation(fruitData)
	if not IsFavoriteAutomationEnabled() then
		UpdateFavoriteStatusLabel(
			"Favorite automation: OFF",
			false
		)
		return
	end

	local queuedToFavorite = 0
	local queuedToUnfavorite = 0
	local targetCount = 0
	local skippedWithoutId = 0
	local firstError = FavoriteAsyncError
	FavoriteAsyncError = nil

	for _, data in ipairs(fruitData) do
		local desiredState =
			GetDesiredFavoriteState(data)

		if desiredState == nil then
			continue
		end

		targetCount += 1

		if data.FruitId == nil then
			skippedWithoutId += 1
			continue
		end

		local queued, errorMessage =
			SetFavoriteState(data, desiredState)

		if queued then
			if desiredState then
				queuedToFavorite += 1
			else
				queuedToUnfavorite += 1
			end
		elseif errorMessage and not firstError then
			firstError = errorMessage
		end
	end

	if firstError then
		UpdateFavoriteStatusLabel(
			"Favorite error: " .. tostring(firstError),
			true
		)
		return
	end

	local modeText

	if AutoFavoriteAllEnabled then
		modeText = "Favorite ALL"
	elseif AutoUnfavoriteAllEnabled then
		modeText = "Unfavorite ALL"
	else
		modeText = string.format(
			"%s %s",
			FavoriteThresholdMode,
			FormatCompactNumber(FavoriteValueThreshold)
		)
	end

	local summary = string.format(
		"%s • Target %d • Queue +%d/-%d • Sisa %d",
		modeText,
		targetCount,
		queuedToFavorite,
		queuedToUnfavorite,
		FavoriteQueuedCount
	)

	if skippedWithoutId > 0 then
		summary ..= string.format(
			" • Tanpa ID %d",
			skippedWithoutId
		)
	end

	UpdateFavoriteStatusLabel(summary, false)
end

--// =====================================================
--// GUI SLOT
--// =====================================================

local function IsTextObject(object)
	return object
		and (
			object:IsA("TextLabel")
			or object:IsA("TextButton")
		)
end

local function CollectGuiSlots()
	local slots = {}

	for _, object in ipairs(BackpackGui:GetDescendants()) do
		if object.Name ~= "ToolName"
			or not IsTextObject(object)
		then
			continue
		end

		local slotFrame = object.Parent

		if not slotFrame then
			continue
		end

		local toolCount =
			slotFrame:FindFirstChild("ToolCount", true)

		if not IsTextObject(toolCount) then
			continue
		end

		local icon =
			slotFrame:FindFirstChild("Icon", true)

		table.insert(slots, {
			Frame = slotFrame,
			ToolName = object,
			ToolCount = toolCount,
			Icon = icon,
		})
	end

	return slots
end

local function CreateFruitBuckets(fruitData)
	local exactBuckets = {}
	local basicBuckets = {}

	for _, data in ipairs(fruitData) do
		exactBuckets[data.ExactKey] =
			exactBuckets[data.ExactKey] or {}

		basicBuckets[data.BasicKey] =
			basicBuckets[data.BasicKey] or {}

		table.insert(
			exactBuckets[data.ExactKey],
			data
		)

		table.insert(
			basicBuckets[data.BasicKey],
			data
		)
	end

	return exactBuckets, basicBuckets
end

local function TakeUnusedCandidate(
	bucket,
	usedItems
)
	if not bucket then
		return nil
	end

	for _, data in ipairs(bucket) do
		if not usedItems[data.Item] then
			return data
		end
	end

	return nil
end

--// =====================================================
--// LABEL HARGA
--// =====================================================

local function GetHighestSlotZIndex(
	slotFrame,
	priceLabel
)
	local highest = slotFrame.ZIndex

	for _, object in ipairs(slotFrame:GetDescendants()) do
		if not object:IsA("GuiObject") then
			continue
		end

		if object == priceLabel then
			continue
		end

		if priceLabel
			and object:IsDescendantOf(priceLabel)
		then
			continue
		end

		highest = math.max(
			highest,
			object.ZIndex
		)
	end

	-- Minimal 500 dan selalu lebih tinggi
	-- daripada icon/overlay lain.
	return math.max(500, highest + 50)
end

local function EnsurePriceLabel(slot)
	local priceLabel =
		slot.Frame:FindFirstChild(PRICE_LABEL_NAME)

	if priceLabel
		and not IsTextObject(priceLabel)
	then
		priceLabel:Destroy()
		priceLabel = nil
	end

	if priceLabel then
		return priceLabel
	end

	-- Clone ToolCount agar style dasar sama
	-- seperti weight bawaan.
	priceLabel = slot.ToolCount:Clone()

	priceLabel.Name = PRICE_LABEL_NAME
	priceLabel.Parent = slot.Frame

	priceLabel.AnchorPoint = Vector2.new(0, 0)
	priceLabel.Position = PRICE_POSITION
	priceLabel.Size = PRICE_SIZE

	priceLabel.BackgroundTransparency = 1
	priceLabel.BorderSizePixel = 0

	priceLabel.Text = ""
	priceLabel.TextWrapped = false
	priceLabel.TextScaled = false
	priceLabel.RichText = false

	priceLabel.TextXAlignment =
		Enum.TextXAlignment.Left

	priceLabel.TextYAlignment =
		Enum.TextYAlignment.Center

	priceLabel.Visible = false
	priceLabel.Active = false
	priceLabel.Selectable = false

	if priceLabel:IsA("TextButton") then
		priceLabel.AutoButtonColor = false
	end

	-- Gradient hasil clone bisa menimpa warna hijau.
	for _, child in ipairs(priceLabel:GetChildren()) do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end

	return priceLabel
end

local function SynchronizePriceStyle(
	priceLabel,
	toolCount
)
	-- Mengikuti style weight.
	priceLabel.FontFace =
		toolCount.FontFace

	priceLabel.TextSize =
		toolCount.TextSize

	priceLabel.TextTransparency =
		toolCount.TextTransparency

	-- Warna hijau.
	priceLabel.TextColor3 =
		PRICE_COLOR

	-- Stroke hitam.
	priceLabel.TextStrokeColor3 =
		PRICE_STROKE_COLOR

	priceLabel.TextStrokeTransparency =
		PRICE_STROKE_TRANSPARENCY

	priceLabel.BackgroundTransparency = 1
end

local function HidePriceLabel(slot)
	local priceLabel =
		slot.Frame:FindFirstChild(PRICE_LABEL_NAME)

	if priceLabel and IsTextObject(priceLabel) then
		priceLabel.Visible = false
	end
end

local function ShowPriceLabel(slot, data)
	local priceLabel = EnsurePriceLabel(slot)

	SynchronizePriceStyle(
		priceLabel,
		slot.ToolCount
	)

	priceLabel.Position = PRICE_POSITION
	priceLabel.Size = PRICE_SIZE

	priceLabel.Text =
		FormatCompactNumber(
			GetDisplayedFruitValue(data)
		)

	priceLabel.ZIndex =
		GetHighestSlotZIndex(
			slot.Frame,
			priceLabel
		)

	priceLabel.Visible =
		FruitValueEnabled
end

local function SetAllPriceLabelsVisible(visible)
	for _, object in ipairs(BackpackGui:GetDescendants()) do
		if object.Name == PRICE_LABEL_NAME
			and IsTextObject(object)
		then
			object.Visible = visible
		end
	end
end

--// =====================================================
--// VALIDASI SLOT
--// =====================================================

local function IsReferenceValid(slot, data)
	if not data
		or not data.Item
		or not data.Item.Parent
	then
		return false
	end

	if not slot.Frame.Parent
		or not slot.ToolName.Parent
		or not slot.ToolCount.Parent
	then
		return false
	end

	if slot.ToolName.Text ~= data.FruitName then
		return false
	end

	if slot.ToolCount.Text ~= data.WeightText then
		return false
	end

	return true
end

--// =====================================================
--// SORTING
--// =====================================================

local function IsInventorySlot(slot)
	-- Hotbar tidak berada di ScrollingFrame.
	-- Jadi hanya panel inventory yang diurutkan.
	return slot.Frame:
		FindFirstAncestorWhichIsA(
			"ScrollingFrame"
		) ~= nil
end

local function GetNativeLayoutOrder(frame)
	local orderFromName =
		tonumber(frame.Name)

	if orderFromName ~= nil then
		NativeLayoutOrders[frame] =
			orderFromName

		return orderFromName
	end

	local savedOrder =
		NativeLayoutOrders[frame]

	if savedOrder ~= nil then
		return savedOrder
	end

	savedOrder = frame.LayoutOrder

	NativeLayoutOrders[frame] =
		savedOrder

	return savedOrder
end

local function ApplyPriceSorting(
	slots,
	dataByItem
)
	local sortableSlots = {}

	for _, slot in ipairs(slots) do
		if not IsInventorySlot(slot) then
			continue
		end

		local nativeOrder =
			GetNativeLayoutOrder(slot.Frame)

		local item =
			SlotItemReferences[slot.Frame]

		local data =
			item and dataByItem[item]

		table.insert(sortableSlots, {
			Slot = slot,
			Data = data,
			NativeOrder = nativeOrder,
		})
	end

	-- Kembalikan ke urutan asli.
	if not SortPriceDescendingEnabled then
		for _, entry in ipairs(sortableSlots) do
			entry.Slot.Frame.LayoutOrder =
				entry.NativeOrder
		end

		return
	end

	table.sort(sortableSlots, function(a, b)
		local aIsFruit = a.Data ~= nil
		local bIsFruit = b.Data ~= nil

		-- Buah selalu ditempatkan sebelum item lain.
		if aIsFruit ~= bIsFruit then
			return aIsFruit
		end

		-- Item non-fruit mempertahankan urutan asli.
		if not aIsFruit then
			return a.NativeOrder < b.NativeOrder
		end

		local aValue =
			GetDisplayedFruitValue(a.Data)

		local bValue =
			GetDisplayedFruitValue(b.Data)

		-- Harga tertinggi ke terendah.
		if aValue ~= bValue then
			return aValue > bValue
		end

		-- Jika harga sama, urutkan berdasarkan nama.
		local aName =
			string.lower(a.Data.FruitName)

		local bName =
			string.lower(b.Data.FruitName)

		if aName ~= bName then
			return aName < bName
		end

		-- Jika semuanya sama, gunakan urutan asli.
		return a.NativeOrder < b.NativeOrder
	end)

	for order, entry in ipairs(sortableSlots) do
		entry.Slot.Frame.LayoutOrder = order
	end
end

--// =====================================================
--// BACKPACK VALUE SUMMARY
--// =====================================================

local function SetSummaryLabel(label, title, value)
	if not label then
		return
	end

	value = math.max(0, math.floor(
		tonumber(value) or 0
	))

	-- Judul tetap putih, sedangkan compact value dan raw value hijau.
	-- NumberUtils.FormatWithCommas digunakan agar raw mudah dibaca.
	label.Text = string.format(
		'%s: <font color="#50FF78">%s</font>  <font color="#50FF78" size="8">Raw: %s</font>',
		title,
		FormatCompactNumber(value),
		NumberUtils.FormatWithCommas(value)
	)
end

local function UpdateBackpackValueSummary(fruitData)
	local backpackTotal = 0
	local backpackNonFavorite = 0
	local dailyDealTotal = 0
	local dailyDealNonFavorite = 0
	local fruitCount = 0
	local nonFavoriteCount = 0
	local dailyDealMultiplier = GetDailyDealMultiplier()

	for _, data in ipairs(fruitData) do
		-- Total mengikuti tombol Harga Base X1:
		-- ON  = hasil FruitValueCalc X1.
		-- OFF = hasil X1 dikalikan multiplier Fruit Stock raw.
		local selectedValue = math.floor(
			GetDisplayedFruitValue(data)
		)
		local dailyDealValue = GetDailyDealFruitValue(
			selectedValue,
			dailyDealMultiplier
		)
		local isFavorite = data.Item
			and data.Item:GetAttribute("IsFavorite") == true

		backpackTotal += selectedValue
		dailyDealTotal += dailyDealValue
		fruitCount += 1

		if not isFavorite then
			backpackNonFavorite += selectedValue
			dailyDealNonFavorite += dailyDealValue
			nonFavoriteCount += 1
		end
	end

	-- Urutan yang ditampilkan:
	-- 1. Backpack Value Total
	-- 2. Daily Deal Total
	-- 3. Backpack Value Non Favorite
	-- 4. Daily Deal Total Non Favorite
	SetSummaryLabel(
		BackpackValueTotalLabel,
		"Backpack Value Total",
		backpackTotal
	)

	SetSummaryLabel(
		DailyDealTotalLabel,
		"Daily Deal Total",
		dailyDealTotal
	)

	SetSummaryLabel(
		BackpackValueNonFavoriteLabel,
		"Backpack Value Non Favorite",
		backpackNonFavorite
	)

	SetSummaryLabel(
		DailyDealNonFavoriteLabel,
		"Daily Deal Total Non Favorite",
		dailyDealNonFavorite
	)

	if BackpackSummaryStatusLabel then
		BackpackSummaryStatusLabel.Text = string.format(
			"%s • Daily Deal X%s • %d fruits • %d non-favorite",
			BaseX1PriceEnabled and "Base X1" or "Actual Fruit Stock",
			tostring(dailyDealMultiplier),
			fruitCount,
			nonFavoriteCount
		)
	end
end

--// =====================================================
--// REFRESH DATA DAN GUI
--// =====================================================

local function RefreshPrices()
	local fruitData, dataByItem =
		CollectFruitData()

	local slots = CollectGuiSlots()

	local exactBuckets, basicBuckets =
		CreateFruitBuckets(fruitData)

	local usedItems = {}

	-- Validasi referensi sebelumnya.
	for _, slot in ipairs(slots) do
		local referencedItem =
			SlotItemReferences[slot.Frame]

		local referencedData =
			referencedItem
			and dataByItem[referencedItem]

		if referencedData
			and IsReferenceValid(
				slot,
				referencedData
			)
		then
			usedItems[referencedItem] = true
		else
			SlotItemReferences[slot.Frame] = nil
		end
	end

	-- Cocokkan slot GUI dengan Tool/FruitProxy.
	for _, slot in ipairs(slots) do
		if SlotItemReferences[slot.Frame] then
			continue
		end

		local displayedName = slot.ToolName.Text
		local displayedWeight = slot.ToolCount.Text

		if displayedName == ""
			or displayedWeight == ""
		then
			continue
		end

		local gradient =
			slot.ToolName:FindFirstChildOfClass(
				"UIGradient"
			)

		local displayedMutationSignature =
			GradientSignature(gradient)

		local exactKey = CreateExactKey(
			displayedName,
			displayedWeight,
			displayedMutationSignature
		)

		local basicKey = CreateBasicKey(
			displayedName,
			displayedWeight
		)

		-- Prioritas nama + weight + mutation.
		local candidate = TakeUnusedCandidate(
			exactBuckets[exactKey],
			usedItems
		)

		-- Fallback nama + weight.
		if not candidate then
			candidate = TakeUnusedCandidate(
				basicBuckets[basicKey],
				usedItems
			)
		end


		if candidate then
			SlotItemReferences[slot.Frame] =
				candidate.Item

			usedItems[candidate.Item] = true
		end
	end

	-- Render harga terlebih dahulu. Favorite automation sengaja
	-- tidak diletakkan di jalur kritis ini agar kegagalan remote
	-- favorite tidak dapat menghentikan Show Fruit Value.
	for _, slot in ipairs(slots) do
		local item = SlotItemReferences[slot.Frame]
		local data = item and dataByItem[item]

		if data then
			ShowPriceLabel(slot, data)
		else
			HidePriceLabel(slot)
		end
	end

	-- Terapkan ulang sorting karena controller asli dapat
	-- mengembalikan LayoutOrder.
	ApplyPriceSorting(slots, dataByItem)

	-- Favorite automation dijalankan terpisah dan diproteksi.
	-- Error favorite hanya ditampilkan pada status favorite,
	-- tanpa mengganggu label harga dan sorting.
	local favoriteSuccess, favoriteError = pcall(function()
		ApplyFavoriteAutomation(fruitData)
	end)

	if not favoriteSuccess then
		UpdateFavoriteStatusLabel(
			"Favorite error: " .. tostring(favoriteError),
			true
		)
	end

	-- Dijalankan setelah automation agar total Non Favorite langsung
	-- mengikuti optimistic update attribute IsFavorite.
	UpdateBackpackValueSummary(fruitData)
end

--// =====================================================
--// MENU GUI
--// =====================================================

local MenuGui = Instance.new("ScreenGui")
MenuGui.Name = MENU_GUI_NAME
MenuGui.ResetOnSpawn = false
MenuGui.IgnoreGuiInset = true
MenuGui.DisplayOrder = 10000
MenuGui.ZIndexBehavior =
	Enum.ZIndexBehavior.Global
MenuGui.Enabled = true
MenuGui.Parent = PlayerGui

local MenuFrame = Instance.new("Frame")
MenuFrame.Name = "Main"
MenuFrame.AnchorPoint =
	Vector2.new(0.5, 0.5)
MenuFrame.Position =
	UDim2.new(0.5, 0, 0.5, 0)
MenuFrame.Size =
	UDim2.fromOffset(420, 855)
MenuFrame.BackgroundColor3 =
	Color3.fromRGB(22, 25, 24)
MenuFrame.BorderSizePixel = 0
MenuFrame.Visible = false
MenuFrame.Active = true
MenuFrame.ZIndex = 100
MenuFrame.Parent = MenuGui

-- Sesuaikan ukuran menu dengan viewport agar header dan kontrol
-- tidak berada di luar layar pada resolusi yang pendek.
local MenuScale = Instance.new("UIScale")
MenuScale.Name = "ResponsiveScale"
MenuScale.Scale = 1
MenuScale.Parent = MenuFrame

local MenuViewportConnection = nil
local CurrentCameraConnection = nil

local function UpdateMenuScale()
	local camera = workspace.CurrentCamera

	if not camera then
		MenuScale.Scale = 1
		return
	end

	local viewport = camera.ViewportSize
	local horizontalScale = (viewport.X - 24) / 420
	local verticalScale = (viewport.Y - 24) / 855

	MenuScale.Scale = math.clamp(
		math.min(horizontalScale, verticalScale),
		0.45,
		1
	)
end

local function ConnectMenuViewport()
	if MenuViewportConnection then
		MenuViewportConnection:Disconnect()
		MenuViewportConnection = nil
	end

	local camera = workspace.CurrentCamera

	if camera then
		MenuViewportConnection = camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(UpdateMenuScale)
	end

	UpdateMenuScale()
end

CurrentCameraConnection = workspace:GetPropertyChangedSignal(
	"CurrentCamera"
):Connect(ConnectMenuViewport)

ConnectMenuViewport()

local MenuCorner = Instance.new("UICorner")
MenuCorner.CornerRadius =
	UDim.new(0, 8)
MenuCorner.Parent = MenuFrame

local MenuStroke = Instance.new("UIStroke")
MenuStroke.Color =
	Color3.fromRGB(65, 180, 95)
MenuStroke.Thickness = 1
MenuStroke.Transparency = 0.2
MenuStroke.Parent = MenuFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size =
	UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 =
	Color3.fromRGB(29, 38, 32)
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
TitleBar.ZIndex = 101
TitleBar.Parent = MenuFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius =
	UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleBottomCover = Instance.new("Frame")
TitleBottomCover.Position =
	UDim2.new(0, 0, 1, -8)
TitleBottomCover.Size =
	UDim2.new(1, 0, 0, 8)
TitleBottomCover.BackgroundColor3 =
	TitleBar.BackgroundColor3
TitleBottomCover.BorderSizePixel = 0
TitleBottomCover.ZIndex = 101
TitleBottomCover.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Position =
	UDim2.new(0, 12, 0, 0)
TitleLabel.Size =
	UDim2.new(1, -50, 1, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "xSans Fruit Value & Stock"
TitleLabel.TextColor3 =
	Color3.fromRGB(225, 255, 233)
TitleLabel.TextSize = 15
TitleLabel.Font =
	Enum.Font.GothamBold
TitleLabel.TextXAlignment =
	Enum.TextXAlignment.Left
TitleLabel.ZIndex = 102
TitleLabel.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.Position =
	UDim2.new(1, -35, 0, 5)
CloseButton.Size =
	UDim2.fromOffset(28, 28)
CloseButton.BackgroundTransparency = 1
CloseButton.Text = "×"
CloseButton.TextColor3 =
	Color3.fromRGB(190, 210, 195)
CloseButton.TextSize = 22
CloseButton.Font = Enum.Font.Gotham
CloseButton.ZIndex = 103
CloseButton.Parent = TitleBar

--// Toggle Fruit Value

local ValueToggleButton =
	Instance.new("TextButton")

ValueToggleButton.Name =
	"ToggleFruitValue"

ValueToggleButton.Position =
	UDim2.new(0, 12, 0, 51)

ValueToggleButton.Size =
	UDim2.new(1, -24, 0, 40)

ValueToggleButton.BackgroundColor3 =
	Color3.fromRGB(42, 130, 70)

ValueToggleButton.BorderSizePixel = 0

ValueToggleButton.TextColor3 =
	Color3.fromRGB(255, 255, 255)

ValueToggleButton.TextSize = 14
ValueToggleButton.Font =
	Enum.Font.GothamSemibold

ValueToggleButton.AutoButtonColor = true
ValueToggleButton.ZIndex = 102
ValueToggleButton.Parent = MenuFrame

local ValueToggleCorner =
	Instance.new("UICorner")

ValueToggleCorner.CornerRadius =
	UDim.new(0, 6)

ValueToggleCorner.Parent =
	ValueToggleButton

--// Toggle Base X1 Price

local BaseX1ToggleButton =
	Instance.new("TextButton")

BaseX1ToggleButton.Name =
	"ToggleBaseX1Price"

BaseX1ToggleButton.Position =
	UDim2.new(0, 12, 0, 99)

BaseX1ToggleButton.Size =
	UDim2.new(1, -24, 0, 40)

BaseX1ToggleButton.BackgroundColor3 =
	Color3.fromRGB(48, 62, 52)

BaseX1ToggleButton.BorderSizePixel = 0

BaseX1ToggleButton.TextColor3 =
	Color3.fromRGB(235, 255, 240)

BaseX1ToggleButton.TextSize = 13
BaseX1ToggleButton.Font =
	Enum.Font.GothamSemibold

BaseX1ToggleButton.AutoButtonColor = true
BaseX1ToggleButton.ZIndex = 102
BaseX1ToggleButton.Parent = MenuFrame

local BaseX1ToggleCorner =
	Instance.new("UICorner")

BaseX1ToggleCorner.CornerRadius =
	UDim.new(0, 6)

BaseX1ToggleCorner.Parent =
	BaseX1ToggleButton

--// Sort Button

local SortButton = Instance.new("TextButton")
SortButton.Name =
	"SortPriceDescending"

SortButton.Position =
	UDim2.new(0, 12, 0, 147)

SortButton.Size =
	UDim2.new(1, -24, 0, 40)

SortButton.BackgroundColor3 =
	Color3.fromRGB(48, 62, 52)

SortButton.BorderSizePixel = 0

SortButton.TextColor3 =
	Color3.fromRGB(235, 255, 240)

SortButton.TextSize = 13
SortButton.Font =
	Enum.Font.GothamSemibold

SortButton.AutoButtonColor = true
SortButton.ZIndex = 102
SortButton.Parent = MenuFrame

local SortCorner = Instance.new("UICorner")
SortCorner.CornerRadius =
	UDim.new(0, 6)
SortCorner.Parent = SortButton


--// Fruit Stock Panel

local FruitStockPanel = Instance.new("Frame")
FruitStockPanel.Name = "FruitStockPanel"
FruitStockPanel.Position = UDim2.new(0, 12, 0, 199)
FruitStockPanel.Size = UDim2.new(1, -24, 0, 208)
FruitStockPanel.BackgroundColor3 = Color3.fromRGB(26, 31, 28)
FruitStockPanel.BorderSizePixel = 0
FruitStockPanel.ZIndex = 102
FruitStockPanel.Parent = MenuFrame

local FruitStockPanelCorner = Instance.new("UICorner")
FruitStockPanelCorner.CornerRadius = UDim.new(0, 7)
FruitStockPanelCorner.Parent = FruitStockPanel

local FruitStockPanelStroke = Instance.new("UIStroke")
FruitStockPanelStroke.Color = Color3.fromRGB(62, 94, 70)
FruitStockPanelStroke.Thickness = 1
FruitStockPanelStroke.Transparency = 0.45
FruitStockPanelStroke.Parent = FruitStockPanel

local FruitStockTitle = Instance.new("TextLabel")
FruitStockTitle.Name = "Title"
FruitStockTitle.Position = UDim2.new(0, 10, 0, 7)
FruitStockTitle.Size = UDim2.new(0.5, -10, 0, 20)
FruitStockTitle.BackgroundTransparency = 1
FruitStockTitle.Text = "Fruit Stock"
FruitStockTitle.TextColor3 = Color3.fromRGB(224, 241, 229)
FruitStockTitle.TextSize = 13
FruitStockTitle.Font = Enum.Font.GothamBold
FruitStockTitle.TextXAlignment = Enum.TextXAlignment.Left
FruitStockTitle.ZIndex = 104
FruitStockTitle.Parent = FruitStockPanel

FruitStockTimerLabel = Instance.new("TextLabel")
FruitStockTimerLabel.Name = "RefreshTimer"
FruitStockTimerLabel.Position = UDim2.new(0.5, 0, 0, 7)
FruitStockTimerLabel.Size = UDim2.new(0.5, -10, 0, 20)
FruitStockTimerLabel.BackgroundTransparency = 1
FruitStockTimerLabel.Text = "Refresh: --"
FruitStockTimerLabel.TextColor3 = Color3.fromRGB(166, 190, 172)
FruitStockTimerLabel.TextSize = 11
FruitStockTimerLabel.Font = Enum.Font.GothamSemibold
FruitStockTimerLabel.TextXAlignment = Enum.TextXAlignment.Right
FruitStockTimerLabel.ZIndex = 104
FruitStockTimerLabel.Parent = FruitStockPanel

FruitStockStatusLabel = Instance.new("TextLabel")
FruitStockStatusLabel.Name = "Status"
FruitStockStatusLabel.Position = UDim2.new(0, 10, 0, 28)
FruitStockStatusLabel.Size = UDim2.new(1, -20, 0, 18)
FruitStockStatusLabel.BackgroundTransparency = 1
FruitStockStatusLabel.Text = "Menyiapkan Fruit Stock..."
FruitStockStatusLabel.TextColor3 = Color3.fromRGB(225, 190, 116)
FruitStockStatusLabel.TextSize = 10
FruitStockStatusLabel.Font = Enum.Font.Gotham
FruitStockStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
FruitStockStatusLabel.ZIndex = 104
FruitStockStatusLabel.Parent = FruitStockPanel

FruitStockList = Instance.new("ScrollingFrame")
FruitStockList.Name = "List"
FruitStockList.Position = UDim2.new(0, 8, 0, 53)
FruitStockList.Size = UDim2.new(1, -16, 1, -61)
FruitStockList.BackgroundTransparency = 1
FruitStockList.BorderSizePixel = 0
FruitStockList.CanvasSize = UDim2.new()
FruitStockList.AutomaticCanvasSize = Enum.AutomaticSize.Y
FruitStockList.ScrollBarThickness = 4
FruitStockList.ScrollBarImageColor3 = Color3.fromRGB(72, 145, 91)
FruitStockList.ScrollingDirection = Enum.ScrollingDirection.Y
FruitStockList.ZIndex = 104
FruitStockList.Parent = FruitStockPanel

local FruitStockListLayout = Instance.new("UIListLayout")
FruitStockListLayout.Padding = UDim.new(0, 5)
FruitStockListLayout.SortOrder = Enum.SortOrder.LayoutOrder
FruitStockListLayout.Parent = FruitStockList

local FruitStockListPadding = Instance.new("UIPadding")
FruitStockListPadding.PaddingBottom = UDim.new(0, 2)
FruitStockListPadding.PaddingRight = UDim.new(0, 2)
FruitStockListPadding.Parent = FruitStockList

--// Favorite Automation Panel

local FavoritePanel = Instance.new("Frame")
FavoritePanel.Name = "FavoriteAutomationPanel"
FavoritePanel.Position = UDim2.new(0, 12, 0, 417)
FavoritePanel.Size = UDim2.new(1, -24, 0, 238)
FavoritePanel.BackgroundColor3 = Color3.fromRGB(26, 31, 28)
FavoritePanel.BorderSizePixel = 0
FavoritePanel.ZIndex = 102
FavoritePanel.Parent = MenuFrame

local FavoritePanelCorner = Instance.new("UICorner")
FavoritePanelCorner.CornerRadius = UDim.new(0, 7)
FavoritePanelCorner.Parent = FavoritePanel

local FavoritePanelStroke = Instance.new("UIStroke")
FavoritePanelStroke.Color = Color3.fromRGB(62, 94, 70)
FavoritePanelStroke.Thickness = 1
FavoritePanelStroke.Transparency = 0.45
FavoritePanelStroke.Parent = FavoritePanel

local FavoriteTitle = Instance.new("TextLabel")
FavoriteTitle.Name = "Title"
FavoriteTitle.Position = UDim2.new(0, 10, 0, 7)
FavoriteTitle.Size = UDim2.new(1, -20, 0, 20)
FavoriteTitle.BackgroundTransparency = 1
FavoriteTitle.Text = "Favorite Automation"
FavoriteTitle.TextColor3 = Color3.fromRGB(224, 241, 229)
FavoriteTitle.TextSize = 13
FavoriteTitle.Font = Enum.Font.GothamBold
FavoriteTitle.TextXAlignment = Enum.TextXAlignment.Left
FavoriteTitle.ZIndex = 104
FavoriteTitle.Parent = FavoritePanel

ThresholdModeButton = Instance.new("TextButton")
ThresholdModeButton.Name = "ThresholdMode"
ThresholdModeButton.Position = UDim2.new(0, 10, 0, 34)
ThresholdModeButton.Size = UDim2.new(0.38, -5, 0, 38)
ThresholdModeButton.BackgroundColor3 = Color3.fromRGB(48, 62, 52)
ThresholdModeButton.BorderSizePixel = 0
ThresholdModeButton.TextColor3 = Color3.fromRGB(235, 255, 240)
ThresholdModeButton.TextSize = 12
ThresholdModeButton.Font = Enum.Font.GothamSemibold
ThresholdModeButton.AutoButtonColor = true
ThresholdModeButton.ZIndex = 104
ThresholdModeButton.Parent = FavoritePanel

local ThresholdModeCorner = Instance.new("UICorner")
ThresholdModeCorner.CornerRadius = UDim.new(0, 6)
ThresholdModeCorner.Parent = ThresholdModeButton

ThresholdValueBox = Instance.new("TextBox")
ThresholdValueBox.Name = "ValueThreshold"
ThresholdValueBox.Position = UDim2.new(0.38, 5, 0, 34)
ThresholdValueBox.Size = UDim2.new(0.62, -15, 0, 38)
ThresholdValueBox.BackgroundColor3 = Color3.fromRGB(38, 47, 41)
ThresholdValueBox.BorderSizePixel = 0
ThresholdValueBox.TextColor3 = Color3.fromRGB(235, 255, 240)
ThresholdValueBox.PlaceholderColor3 = Color3.fromRGB(130, 150, 136)
ThresholdValueBox.PlaceholderText = "Value Threshold, contoh: 10M"
ThresholdValueBox.Text = "0"
ThresholdValueBox.ClearTextOnFocus = false
ThresholdValueBox.TextSize = 12
ThresholdValueBox.Font = Enum.Font.GothamSemibold
ThresholdValueBox.TextXAlignment = Enum.TextXAlignment.Center
ThresholdValueBox.ZIndex = 104
ThresholdValueBox.Parent = FavoritePanel

local ThresholdValueCorner = Instance.new("UICorner")
ThresholdValueCorner.CornerRadius = UDim.new(0, 6)
ThresholdValueCorner.Parent = ThresholdValueBox

AutoFavoriteButton = Instance.new("TextButton")
AutoFavoriteButton.Name = "AutoFavorite"
AutoFavoriteButton.Position = UDim2.new(0, 10, 0, 80)
AutoFavoriteButton.Size = UDim2.new(0.5, -15, 0, 38)
AutoFavoriteButton.BackgroundColor3 = Color3.fromRGB(48, 62, 52)
AutoFavoriteButton.BorderSizePixel = 0
AutoFavoriteButton.TextColor3 = Color3.fromRGB(235, 255, 240)
AutoFavoriteButton.TextSize = 12
AutoFavoriteButton.Font = Enum.Font.GothamSemibold
AutoFavoriteButton.AutoButtonColor = true
AutoFavoriteButton.ZIndex = 104
AutoFavoriteButton.Parent = FavoritePanel

local AutoFavoriteCorner = Instance.new("UICorner")
AutoFavoriteCorner.CornerRadius = UDim.new(0, 6)
AutoFavoriteCorner.Parent = AutoFavoriteButton

AutoUnfavoriteButton = Instance.new("TextButton")
AutoUnfavoriteButton.Name = "AutoUnfavorite"
AutoUnfavoriteButton.Position = UDim2.new(0.5, 5, 0, 80)
AutoUnfavoriteButton.Size = UDim2.new(0.5, -15, 0, 38)
AutoUnfavoriteButton.BackgroundColor3 = Color3.fromRGB(48, 62, 52)
AutoUnfavoriteButton.BorderSizePixel = 0
AutoUnfavoriteButton.TextColor3 = Color3.fromRGB(235, 255, 240)
AutoUnfavoriteButton.TextSize = 12
AutoUnfavoriteButton.Font = Enum.Font.GothamSemibold
AutoUnfavoriteButton.AutoButtonColor = true
AutoUnfavoriteButton.ZIndex = 104
AutoUnfavoriteButton.Parent = FavoritePanel

local AutoUnfavoriteCorner = Instance.new("UICorner")
AutoUnfavoriteCorner.CornerRadius = UDim.new(0, 6)
AutoUnfavoriteCorner.Parent = AutoUnfavoriteButton

AutoFavoriteAllButton = Instance.new("TextButton")
AutoFavoriteAllButton.Name = "AutoFavoriteAll"
AutoFavoriteAllButton.Position = UDim2.new(0, 10, 0, 126)
AutoFavoriteAllButton.Size = UDim2.new(0.5, -15, 0, 38)
AutoFavoriteAllButton.BackgroundColor3 = Color3.fromRGB(48, 62, 52)
AutoFavoriteAllButton.BorderSizePixel = 0
AutoFavoriteAllButton.TextColor3 = Color3.fromRGB(235, 255, 240)
AutoFavoriteAllButton.TextSize = 12
AutoFavoriteAllButton.Font = Enum.Font.GothamSemibold
AutoFavoriteAllButton.AutoButtonColor = true
AutoFavoriteAllButton.ZIndex = 104
AutoFavoriteAllButton.Parent = FavoritePanel

local AutoFavoriteAllCorner = Instance.new("UICorner")
AutoFavoriteAllCorner.CornerRadius = UDim.new(0, 6)
AutoFavoriteAllCorner.Parent = AutoFavoriteAllButton

AutoUnfavoriteAllButton = Instance.new("TextButton")
AutoUnfavoriteAllButton.Name = "AutoUnfavoriteAll"
AutoUnfavoriteAllButton.Position = UDim2.new(0.5, 5, 0, 126)
AutoUnfavoriteAllButton.Size = UDim2.new(0.5, -15, 0, 38)
AutoUnfavoriteAllButton.BackgroundColor3 = Color3.fromRGB(48, 62, 52)
AutoUnfavoriteAllButton.BorderSizePixel = 0
AutoUnfavoriteAllButton.TextColor3 = Color3.fromRGB(235, 255, 240)
AutoUnfavoriteAllButton.TextSize = 12
AutoUnfavoriteAllButton.Font = Enum.Font.GothamSemibold
AutoUnfavoriteAllButton.AutoButtonColor = true
AutoUnfavoriteAllButton.ZIndex = 104
AutoUnfavoriteAllButton.Parent = FavoritePanel

local AutoUnfavoriteAllCorner = Instance.new("UICorner")
AutoUnfavoriteAllCorner.CornerRadius = UDim.new(0, 6)
AutoUnfavoriteAllCorner.Parent = AutoUnfavoriteAllButton

FavoriteStatusLabel = Instance.new("TextLabel")
FavoriteStatusLabel.Name = "Status"
FavoriteStatusLabel.Position = UDim2.new(0, 10, 0, 174)
FavoriteStatusLabel.Size = UDim2.new(1, -20, 0, 52)
FavoriteStatusLabel.BackgroundTransparency = 1
FavoriteStatusLabel.Text = FavoriteLastSummary
FavoriteStatusLabel.TextColor3 = Color3.fromRGB(166, 190, 172)
FavoriteStatusLabel.TextSize = 10
FavoriteStatusLabel.Font = Enum.Font.Gotham
FavoriteStatusLabel.TextWrapped = true
FavoriteStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
FavoriteStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
FavoriteStatusLabel.ZIndex = 104
FavoriteStatusLabel.Parent = FavoritePanel

--// Backpack Value Summary Panel

local BackpackSummaryPanel = Instance.new("Frame")
BackpackSummaryPanel.Name = "BackpackValueSummaryPanel"
BackpackSummaryPanel.Position = UDim2.new(0, 12, 0, 665)
BackpackSummaryPanel.Size = UDim2.new(1, -24, 0, 145)
BackpackSummaryPanel.BackgroundColor3 = Color3.fromRGB(26, 31, 28)
BackpackSummaryPanel.BorderSizePixel = 0
BackpackSummaryPanel.ZIndex = 102
BackpackSummaryPanel.Parent = MenuFrame

local BackpackSummaryCorner = Instance.new("UICorner")
BackpackSummaryCorner.CornerRadius = UDim.new(0, 7)
BackpackSummaryCorner.Parent = BackpackSummaryPanel

local BackpackSummaryStroke = Instance.new("UIStroke")
BackpackSummaryStroke.Color = Color3.fromRGB(62, 94, 70)
BackpackSummaryStroke.Thickness = 1
BackpackSummaryStroke.Transparency = 0.45
BackpackSummaryStroke.Parent = BackpackSummaryPanel

local BackpackSummaryTitle = Instance.new("TextLabel")
BackpackSummaryTitle.Name = "Title"
BackpackSummaryTitle.Position = UDim2.new(0, 10, 0, 6)
BackpackSummaryTitle.Size = UDim2.new(1, -20, 0, 18)
BackpackSummaryTitle.BackgroundTransparency = 1
BackpackSummaryTitle.Text = "Backpack Value Summary"
BackpackSummaryTitle.TextColor3 = Color3.fromRGB(224, 241, 229)
BackpackSummaryTitle.TextSize = 13
BackpackSummaryTitle.Font = Enum.Font.GothamBold
BackpackSummaryTitle.TextXAlignment = Enum.TextXAlignment.Left
BackpackSummaryTitle.ZIndex = 104
BackpackSummaryTitle.Parent = BackpackSummaryPanel

local function CreateSummaryValueLabel(name, title, yPosition)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.new(0, 10, 0, yPosition)
	label.Size = UDim2.new(1, -20, 0, 23)
	label.BackgroundColor3 = Color3.fromRGB(38, 47, 41)
	label.BorderSizePixel = 0
	label.Text = title .. ": 0  Raw: 0"
	label.RichText = true
	label.TextColor3 = Color3.fromRGB(235, 255, 240)
	label.TextSize = 10
	label.Font = Enum.Font.GothamSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 104
	label.Parent = BackpackSummaryPanel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = label

	return label
end

BackpackValueTotalLabel = CreateSummaryValueLabel(
	"BackpackValueTotal",
	"Backpack Value Total",
	27
)

DailyDealTotalLabel = CreateSummaryValueLabel(
	"DailyDealTotal",
	"Daily Deal Total",
	53
)

BackpackValueNonFavoriteLabel = CreateSummaryValueLabel(
	"BackpackValueNonFavorite",
	"Backpack Value Non Favorite",
	79
)

DailyDealNonFavoriteLabel = CreateSummaryValueLabel(
	"DailyDealTotalNonFavorite",
	"Daily Deal Total Non Favorite",
	105
)

BackpackSummaryStatusLabel = Instance.new("TextLabel")
BackpackSummaryStatusLabel.Name = "Status"
BackpackSummaryStatusLabel.Position = UDim2.new(0, 10, 1, -15)
BackpackSummaryStatusLabel.Size = UDim2.new(1, -20, 0, 12)
BackpackSummaryStatusLabel.BackgroundTransparency = 1
BackpackSummaryStatusLabel.Text = "Menghitung total backpack..."
BackpackSummaryStatusLabel.TextColor3 = Color3.fromRGB(145, 165, 150)
BackpackSummaryStatusLabel.TextSize = 8
BackpackSummaryStatusLabel.Font = Enum.Font.Gotham
BackpackSummaryStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
BackpackSummaryStatusLabel.ZIndex = 104
BackpackSummaryStatusLabel.Parent = BackpackSummaryPanel

--// Key Hint

local KeyHint = Instance.new("TextLabel")
KeyHint.Name = "KeyHint"
KeyHint.Position =
	UDim2.new(0, 12, 1, -32)
KeyHint.Size =
	UDim2.new(1, -24, 0, 20)
KeyHint.BackgroundTransparency = 1
KeyHint.Text =
	"Tekan L untuk membuka/menutup menu"
KeyHint.TextColor3 =
	Color3.fromRGB(145, 165, 150)
KeyHint.TextSize = 11
KeyHint.Font = Enum.Font.Gotham
KeyHint.TextXAlignment =
	Enum.TextXAlignment.Center
KeyHint.ZIndex = 102
KeyHint.Parent = MenuFrame

-- Mulai listener Fruit Stock setelah seluruh GUI siap.
task.defer(SetupFruitStockNetworking)

--// =====================================================
--// MENU FUNCTIONS
--// =====================================================

local function UpdateValueToggleButton()
	if FruitValueEnabled then
		ValueToggleButton.Text =
			"Show Fruit Value: ON"

		ValueToggleButton.BackgroundColor3 =
			Color3.fromRGB(42, 130, 70)
	else
		ValueToggleButton.Text =
			"Show Fruit Value: OFF"

		ValueToggleButton.BackgroundColor3 =
			Color3.fromRGB(115, 55, 55)
	end
end

local function UpdateBaseX1ToggleButton()
	if BaseX1PriceEnabled then
		BaseX1ToggleButton.Text =
			"Harga Base X1: ON"

		BaseX1ToggleButton.BackgroundColor3 =
			Color3.fromRGB(42, 130, 70)
	else
		BaseX1ToggleButton.Text =
			"Harga Base X1: OFF (Aktual)"

		BaseX1ToggleButton.BackgroundColor3 =
			Color3.fromRGB(48, 62, 52)
	end
end

local function UpdateSortButton()
	if SortPriceDescendingEnabled then
		SortButton.Text =
			"Urut Harga: Tinggi → Rendah (ON)"

		SortButton.BackgroundColor3 =
			Color3.fromRGB(42, 130, 70)
	else
		SortButton.Text =
			"Urut Harga: OFF"

		SortButton.BackgroundColor3 =
			Color3.fromRGB(48, 62, 52)
	end
end

local function SetToggleVisual(button, label, enabled)
	if not button then
		return
	end

	button.Text = string.format(
		"%s: %s",
		label,
		enabled and "ON" or "OFF"
	)

	button.BackgroundColor3 = enabled
		and Color3.fromRGB(42, 130, 70)
		or Color3.fromRGB(48, 62, 52)
end

local function UpdateFavoriteControls()
	if ThresholdModeButton then
		ThresholdModeButton.Text =
			"Threshold Mode: " .. FavoriteThresholdMode
	end

	if ThresholdValueBox
		and not ThresholdValueBox:IsFocused()
	then
		ThresholdValueBox.Text =
			FormatCompactNumber(FavoriteValueThreshold)
	end

	SetToggleVisual(
		AutoFavoriteButton,
		"Auto Favorite",
		AutoFavoriteEnabled
	)

	SetToggleVisual(
		AutoUnfavoriteButton,
		"Auto Unfavorite",
		AutoUnfavoriteEnabled
	)

	SetToggleVisual(
		AutoFavoriteAllButton,
		"Auto Favorite All",
		AutoFavoriteAllEnabled
	)

	SetToggleVisual(
		AutoUnfavoriteAllButton,
		"Auto Unfavorite All",
		AutoUnfavoriteAllEnabled
	)
end

local function DisableAllModes()
	AutoFavoriteAllEnabled = false
	AutoUnfavoriteAllEnabled = false
end

local function DisableThresholdModes()
	AutoFavoriteEnabled = false
	AutoUnfavoriteEnabled = false
end

local function RefreshFavoriteAutomationNow()
	-- Batalkan request antrean dari konfigurasi lama agar perubahan
	-- Above/Below atau threshold langsung berlaku.
	InvalidateFavoriteQueue()

	local success, errorMessage = pcall(function()
		local fruitData = CollectFruitData()
		ApplyFavoriteAutomation(fruitData)
	end)

	if not success then
		UpdateFavoriteStatusLabel(
			"Favorite error: " .. tostring(errorMessage),
			true
		)
	end
end

local function SetFruitValueEnabled(enabled)
	FruitValueEnabled = enabled

	if FruitValueEnabled then
		-- Tampilkan kembali label yang sudah tersedia secara langsung,
		-- lalu lakukan rematch/refresh seluruh slot.
		SetAllPriceLabelsVisible(true)

		local success, errorMessage =
			pcall(RefreshPrices)

		if not success then
			warn(
				"[FruitValueDisplay] "
					.. tostring(errorMessage)
			)
		end
	else
		SetAllPriceLabelsVisible(false)
	end

	UpdateValueToggleButton()
end

local function SetBaseX1PriceEnabled(enabled)
	BaseX1PriceEnabled = enabled

	-- Refresh label dan sorting agar keduanya langsung
	-- mengikuti mode harga yang baru dipilih.
	local success, errorMessage =
		pcall(RefreshPrices)

	if not success then
		warn(
			"[FruitValueBaseX1] "
				.. tostring(errorMessage)
		)
	end

	UpdateBaseX1ToggleButton()
end

local function SetSortEnabled(enabled)
	SortPriceDescendingEnabled = enabled

	local success, errorMessage =
		pcall(RefreshPrices)

	if not success then
		warn(
			"[FruitValueSort] "
				.. tostring(errorMessage)
		)
	end

	UpdateSortButton()
end

local function SetMenuOpened(opened)
	MenuOpened = opened == true

	if MenuOpened then
		MenuGui.Enabled = true
		UpdateMenuScale()
	end

	MenuFrame.Visible = MenuOpened
end

ValueToggleButton.MouseButton1Click:Connect(function()
	SetFruitValueEnabled(
		not FruitValueEnabled
	)
end)

BaseX1ToggleButton.MouseButton1Click:Connect(function()
	SetBaseX1PriceEnabled(
		not BaseX1PriceEnabled
	)
end)

SortButton.MouseButton1Click:Connect(function()
	SetSortEnabled(
		not SortPriceDescendingEnabled
	)
end)

ThresholdModeButton.MouseButton1Click:Connect(function()
	FavoriteThresholdMode =
		FavoriteThresholdMode == "Above"
		and "Below"
		or "Above"

	UpdateFavoriteControls()
	RefreshFavoriteAutomationNow()
end)

ThresholdValueBox.FocusLost:Connect(function()
	local success, parsedValue = pcall(function()
		return NumberUtils.Parse(
			ThresholdValueBox.Text,
			0
		)
	end)

	if not success then
		parsedValue = 0
	end

	FavoriteValueThreshold = math.max(
		0,
		tonumber(parsedValue) or 0
	)

	UpdateFavoriteControls()
	RefreshFavoriteAutomationNow()
end)

AutoFavoriteButton.MouseButton1Click:Connect(function()
	AutoFavoriteEnabled = not AutoFavoriteEnabled

	if AutoFavoriteEnabled then
		-- Threshold Favorite dan Unfavorite bersifat eksklusif.
		AutoUnfavoriteEnabled = false
		DisableAllModes()
	end

	UpdateFavoriteControls()
	RefreshFavoriteAutomationNow()
end)

AutoUnfavoriteButton.MouseButton1Click:Connect(function()
	AutoUnfavoriteEnabled = not AutoUnfavoriteEnabled

	if AutoUnfavoriteEnabled then
		-- Above 10M + Auto Unfavorite berarti item >= 10M
		-- yang di-unfavorite, bukan item di bawah threshold.
		AutoFavoriteEnabled = false
		DisableAllModes()
	end

	UpdateFavoriteControls()
	RefreshFavoriteAutomationNow()
end)

AutoFavoriteAllButton.MouseButton1Click:Connect(function()
	AutoFavoriteAllEnabled = not AutoFavoriteAllEnabled

	if AutoFavoriteAllEnabled then
		AutoUnfavoriteAllEnabled = false
		DisableThresholdModes()
	end

	UpdateFavoriteControls()
	RefreshFavoriteAutomationNow()
end)

AutoUnfavoriteAllButton.MouseButton1Click:Connect(function()
	AutoUnfavoriteAllEnabled = not AutoUnfavoriteAllEnabled

	if AutoUnfavoriteAllEnabled then
		AutoFavoriteAllEnabled = false
		DisableThresholdModes()
	end

	UpdateFavoriteControls()
	RefreshFavoriteAutomationNow()
end)

CloseButton.MouseButton1Click:Connect(function()
	SetMenuOpened(false)
end)

UpdateValueToggleButton()
UpdateBaseX1ToggleButton()
UpdateSortButton()
UpdateFavoriteControls()

--// =====================================================
--// DRAG MENU
--// =====================================================

local Dragging = false
local DragInput = nil
local DragStart = nil
local StartPosition = nil

local function UpdateDrag(input)
	if not Dragging
		or not DragStart
		or not StartPosition
	then
		return
	end

	local delta =
		input.Position - DragStart

	MenuFrame.Position = UDim2.new(
		StartPosition.X.Scale,
		StartPosition.X.Offset + delta.X,
		StartPosition.Y.Scale,
		StartPosition.Y.Offset + delta.Y
	)
end

TitleBar.InputBegan:Connect(function(input)
	local inputType = input.UserInputType

	if inputType ~= Enum.UserInputType.MouseButton1
		and inputType ~= Enum.UserInputType.Touch
	then
		return
	end

	Dragging = true
	DragStart = input.Position
	StartPosition = MenuFrame.Position

	input.Changed:Connect(function()
		if input.UserInputState
			== Enum.UserInputState.End
		then
			Dragging = false
		end
	end)
end)

TitleBar.InputChanged:Connect(function(input)
	local inputType = input.UserInputType

	if inputType
			== Enum.UserInputType.MouseMovement
		or inputType
			== Enum.UserInputType.Touch
	then
		DragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == DragInput then
		UpdateDrag(input)
	end
end)

--// =====================================================
--// KEYBIND L
--// =====================================================

local Runtime = {
	MenuInputConnection = nil,
	LastMenuToggleAt = 0,
	LastError = nil,
	CleanupStarted = false,
}

function Runtime.ToggleMenuFromInput()
	-- Jangan membuka/menutup menu ketika sedang mengetik.
	if UserInputService:GetFocusedTextBox() then
		return false
	end

	-- ContextActionService dan UserInputService dapat menerima
	-- input yang sama. Debounce mencegah toggle dua kali.
	local currentTime = os.clock()

	if currentTime - Runtime.LastMenuToggleAt < 0.15 then
		return true
	end

	Runtime.LastMenuToggleAt = currentTime
	SetMenuOpened(not MenuOpened)

	return true
end

-- Fallback langsung. Ini tetap bekerja pada environment yang
-- tidak meneruskan keybind executor ke ContextActionService.
Runtime.MenuInputConnection = UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode ~= MENU_KEY then
		return
	end

	Runtime.ToggleMenuFromInput()
end)

-- Tetap bind melalui ContextActionService agar tombol L tidak
-- ikut membuka menu game lain ketika script menerima inputnya.
ContextActionService:BindActionAtPriority(
	ACTION_NAME,

	function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end

		if Runtime.ToggleMenuFromInput() then
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end,

	false,
	Enum.ContextActionPriority.High.Value + 2000,
	MENU_KEY
)

--// =====================================================
--// UPDATE LOOP
--// =====================================================

task.spawn(function()
	while Running
		and BackpackGui.Parent
		and MenuGui.Parent
	do
		local success, errorMessage = pcall(RefreshPrices)

		if not success then
			if errorMessage ~= Runtime.LastError then
				Runtime.LastError = errorMessage

				warn(
					"[FruitValueDisplay] "
						.. tostring(errorMessage)
				)
			end
		else
			Runtime.LastError = nil
		end

		UpdateFruitStockTimer()
		task.wait(UPDATE_INTERVAL)
	end
end)

-- Langsung jalankan tanpa menunggu loop.
task.defer(function()
	local success, errorMessage = pcall(RefreshPrices)

	if not success then
		warn(
			"[FruitValueDisplay] "
				.. tostring(errorMessage)
		)
	end
end)

--// =====================================================
--// CLEANUP
--// =====================================================

function Runtime.Stop()
	if Runtime.CleanupStarted then
		return
	end

	Runtime.CleanupStarted = true
	Running = false

	ContextActionService:UnbindAction(ACTION_NAME)

	if FruitStockConnection then
		pcall(function()
			FruitStockConnection:Disconnect()
		end)

		FruitStockConnection = nil
	end

	if Runtime.MenuInputConnection then
		pcall(function()
			Runtime.MenuInputConnection:Disconnect()
		end)

		Runtime.MenuInputConnection = nil
	end

	if MenuViewportConnection then
		pcall(function()
			MenuViewportConnection:Disconnect()
		end)

		MenuViewportConnection = nil
	end

	if CurrentCameraConnection then
		pcall(function()
			CurrentCameraConnection:Disconnect()
		end)

		CurrentCameraConnection = nil
	end
end

function Runtime.Cleanup()
	Runtime.Stop()

	if MenuGui and MenuGui.Parent then
		MenuGui:Destroy()
	end
end

if typeof(script) == "Instance" then
	script.Destroying:Connect(Runtime.Cleanup)
end

if MenuGui then
	MenuGui.Destroying:Connect(Runtime.Stop)
end
