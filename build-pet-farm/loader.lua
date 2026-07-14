--// Tree Clicker - WindUI
--// LocalScript (StarterPlayerScripts)

-------------------------------------------------------
-- Services
-------------------------------------------------------

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-------------------------------------------------------
-- RemoteEvent
-------------------------------------------------------

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local treeClickerRequest = remotesFolder:WaitForChild("TreeClickerRequest")

-------------------------------------------------------
-- Player Plot
-------------------------------------------------------

local plotName = player:GetAttribute("AssignedPlotName")

if not plotName then
	warn("[PlotScanner] Attribute 'AssignedPlotName' belum di-set pada player:", player.Name)
	return
end

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	warn("[PlotScanner] Folder 'Plots' tidak ditemukan")
	return
end

local plotModel = plotsFolder:FindFirstChild(plotName)
if not plotModel then
	warn(("[PlotScanner] Plot '%s' tidak ditemukan"):format(plotName))
	return
end

-------------------------------------------------------
-- Tree Data
-------------------------------------------------------

local trackedTrees = {}
local trackedLookup = {}
local groupWhitelist = {}

-------------------------------------------------------
-- Runtime Settings
-------------------------------------------------------

local LOOP_CYCLE_DELAY = 1

local WINDOW_KEY = Enum.KeyCode.G
local TRIGGER_KEY = Enum.KeyCode.H
local AUTO_KEY = Enum.KeyCode.J

local DEFAULT_APPEARANCE = {
	theme = "Indigo",
	accent = Color3.fromRGB(24, 24, 27),
	background = Color3.fromRGB(16, 16, 16),
	outline = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(255, 255, 255),
	placeholder = Color3.fromRGB(122, 122, 122),
	button = Color3.fromRGB(82, 82, 91),
	icon = Color3.fromRGB(161, 161, 170),
	transparent = true,
}

local appearance = table.clone(DEFAULT_APPEARANCE)
local customThemeRevision = 0

local isTriggeringAll = false
local isLooping = false
local loopThread = nil

-------------------------------------------------------
-- UI References
-------------------------------------------------------

local WindUI
local Window

local dashboardStatusParagraph
local dashboardPlotParagraph
local mainStatusParagraph
local autoToggle

local treeToggleElements = {}
local refreshQueued = false

local windRootGui
local appearanceControls = {}

-------------------------------------------------------
-- Utility
-------------------------------------------------------

local function isTreeModel(instance)
	return instance:IsA("Model")
		and string.find(instance.Name, "Tree", 1, true) ~= nil
end

local function cleanupInvalidTrees()
	for index = #trackedTrees, 1, -1 do
		local tree = trackedTrees[index]

		if not tree
			or not tree.model
			or not trackedLookup[tree.model]
			or tree.model.Parent == nil
		then
			if tree and tree.model then
				trackedLookup[tree.model] = nil
			end

			table.remove(trackedTrees, index)
		end
	end
end

local function getTreeGroups()
	cleanupInvalidTrees()

	local groups = {}

	for _, tree in ipairs(trackedTrees) do
		local treeName = tree.model.Name

		groups[treeName] = (groups[treeName] or 0) + 1

		if groupWhitelist[treeName] == nil then
			groupWhitelist[treeName] = true
		end
	end

	return groups
end

local function getTreeCounts()
	cleanupInvalidTrees()

	local totalTrees = 0
	local enabledTrees = 0
	local totalGroups = 0
	local enabledGroups = 0
	local countedGroups = {}

	for _, tree in ipairs(trackedTrees) do
		local treeName = tree.model.Name
		totalTrees += 1

		if groupWhitelist[treeName] ~= false then
			enabledTrees += 1
		end

		if not countedGroups[treeName] then
			countedGroups[treeName] = true
			totalGroups += 1

			if groupWhitelist[treeName] ~= false then
				enabledGroups += 1
			end
		end
	end

	return {
		totalTrees = totalTrees,
		enabledTrees = enabledTrees,
		totalGroups = totalGroups,
		enabledGroups = enabledGroups,
	}
end

-------------------------------------------------------
-- Manual Click Handler
-------------------------------------------------------

local manualDebounce = false
local MANUAL_DEBOUNCE_TIME = 0.5

local function onTreeClicked(treeModel)
	return function()
		if manualDebounce or treeModel.Parent == nil then
			return
		end

		manualDebounce = true
		treeClickerRequest:FireServer(treeModel, "manual")

		task.delay(MANUAL_DEBOUNCE_TIME, function()
			manualDebounce = false
		end)
	end
end

-------------------------------------------------------
-- Register / Unregister Tree
-------------------------------------------------------

local function registerTree(treeModel)
	if not isTreeModel(treeModel) or trackedLookup[treeModel] then
		return false
	end

	local primaryPart = treeModel.PrimaryPart

	if not primaryPart then
		local startedAt = os.clock()

		while not primaryPart and os.clock() - startedAt < 5 do
			if treeModel.Parent == nil then
				return false
			end

			task.wait(0.1)
			primaryPart = treeModel.PrimaryPart
		end
	end

	if not primaryPart then
		warn("[PlotScanner] PrimaryPart tidak ditemukan untuk:", treeModel.Name)
		return false
	end

	local clickDetector = primaryPart:FindFirstChild("TreeClickDetector")

	if not clickDetector then
		clickDetector = primaryPart:WaitForChild("TreeClickDetector", 5)
	end

	if not clickDetector or not clickDetector:IsA("ClickDetector") then
		return false
	end

	if trackedLookup[treeModel] then
		return false
	end

	clickDetector.MaxActivationDistance = 99999
	trackedLookup[treeModel] = true

	if groupWhitelist[treeModel.Name] == nil then
		groupWhitelist[treeModel.Name] = true
	end

	table.insert(trackedTrees, {
		model = treeModel,
		primaryPart = primaryPart,
		clickDetector = clickDetector,
	})

	clickDetector.MouseClick:Connect(onTreeClicked(treeModel))

	return true
end

local function unregisterTree(treeModel)
	if not trackedLookup[treeModel] then
		return false
	end

	trackedLookup[treeModel] = nil

	for index = #trackedTrees, 1, -1 do
		if trackedTrees[index].model == treeModel then
			table.remove(trackedTrees, index)
			break
		end
	end

	return true
end

local function scanTrees()
	local foundCount = 0
	local newCount = 0

	for _, object in ipairs(plotModel:GetDescendants()) do
		if isTreeModel(object) then
			foundCount += 1

			if registerTree(object) then
				newCount += 1
			end
		end
	end

	cleanupInvalidTrees()

	return foundCount, newCount
end

-------------------------------------------------------
-- Trigger Logic
-------------------------------------------------------

local function fireAllTreesOnce()
	cleanupInvalidTrees()

	local firedCount = 0

	-- Sengaja tidak ada task.wait di dalam loop ini.
	-- Semua RemoteEvent dikirim langsung pada frame yang sama.
	for _, tree in ipairs(trackedTrees) do
		local treeModel = tree.model

		if treeModel.Parent ~= nil
			and groupWhitelist[treeModel.Name] ~= false
		then
			treeClickerRequest:FireServer(treeModel, "auto")
			firedCount += 1
		end
	end

	return firedCount
end

local function triggerOnce()
	if isTriggeringAll then
		return
	end

	isTriggeringAll = true

	local success, result = pcall(fireAllTreesOnce)
	isTriggeringAll = false

	if not success then
		warn("[TreeClicker] Trigger gagal:", result)
	end
end

local function startLooping()
	if isLooping then
		return
	end

	isLooping = true

	loopThread = task.spawn(function()
		while isLooping do
			fireAllTreesOnce()

			if not isLooping then
				break
		end

			if LOOP_CYCLE_DELAY <= 0 then
				task.wait()
			else
				task.wait(LOOP_CYCLE_DELAY)
			end
		end
	end)

end

local function stopLooping()
	if not isLooping then
		return
	end

	isLooping = false

	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end

end

-------------------------------------------------------
-- Initial Scan
-------------------------------------------------------

scanTrees()

-------------------------------------------------------
-- Load WindUI
-------------------------------------------------------

local loadSuccess, loadResult = pcall(function()
	return loadstring(game:HttpGet(
		"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
	))()
end)

if not loadSuccess then
	warn("[TreeClicker] WindUI gagal dimuat:", loadResult)
	warn("[TreeClicker] Environment harus mendukung game:HttpGet dan loadstring.")
	return
end

WindUI = loadResult

-------------------------------------------------------
-- Window
-------------------------------------------------------

Window = WindUI:CreateWindow({
	Title = "Tree Clicker",
	Icon = "trees",
	Author = "Grouped Tree Controller",
	Folder = "TreeClickerWindUI",
	Size = UDim2.fromOffset(600, 480),
	MinSize = Vector2.new(500, 360),
	MaxSize = Vector2.new(850, 680),
	ToggleKey = WINDOW_KEY,
	Transparent = true,
	Theme = "Indigo",
	Resizable = true,
	SideBarWidth = 180,
	HideSearchBar = true,
	ScrollBarEnabled = true,
})

-------------------------------------------------------
-- Tabs
-------------------------------------------------------

local DashboardTab = Window:Tab({
	Title = "Dashboard",
	Icon = "layout-dashboard",
	Locked = false,
})

local MainTab = Window:Tab({
	Title = "Main",
	Icon = "trees",
	Locked = false,
})

local SettingsTab = Window:Tab({
	Title = "Settings",
	Icon = "settings",
	Locked = false,
})

-------------------------------------------------------
-- Dashboard
-------------------------------------------------------

local OverviewSection = DashboardTab:Section({
	Title = "Overview",
	Box = true,
	Opened = true,
})

dashboardPlotParagraph = OverviewSection:Paragraph({
	Title = "Current Plot",
	Desc = ("Player: %s\nPlot: %s"):format(player.Name, plotName),
})

dashboardStatusParagraph = OverviewSection:Paragraph({
	Title = "Tree Status",
	Desc = "Menyiapkan status tree...",
})

local ShortcutSection = DashboardTab:Section({
	Title = "Shortcuts",
	Box = true,
	Opened = true,
})

local shortcutParagraph = ShortcutSection:Paragraph({
	Title = "Active Keybinds",
	Desc = "Menyiapkan keybind...",
})

-------------------------------------------------------
-- Main
-------------------------------------------------------

local MainControlSection = MainTab:Section({
	Title = "Controls",
	Box = true,
	Opened = true,
})

mainStatusParagraph = MainControlSection:Paragraph({
	Title = "Status",
	Desc = "Menyiapkan status...",
})

local TreeSection = MainTab:Section({
	Title = "Tree Groups",
	Box = true,
	Opened = true,
})

-------------------------------------------------------
-- Settings
-------------------------------------------------------

local TriggerSettingsSection = SettingsTab:Section({
	Title = "Trigger Settings",
	Box = true,
	Opened = true,
})

local WindowSettingsSection = SettingsTab:Section({
	Title = "Window & Keybinds",
	Box = true,
	Opened = true,
})

local AppearanceSection = SettingsTab:Section({
	Title = "Appearance",
	Box = true,
	Opened = true,
})

-------------------------------------------------------
-- Appearance Helpers
-------------------------------------------------------

local function findGuiInstance(value, visited, depth)
	if typeof(value) == "Instance" then
		if value:IsA("ScreenGui") or value:IsA("GuiObject") then
			return value
		end
		return nil
	end

	if type(value) ~= "table" or depth <= 0 then
		return nil
	end

	visited = visited or {}
	if visited[value] then
		return nil
	end
	visited[value] = true

	for _, child in pairs(value) do
		local found = findGuiInstance(child, visited, depth - 1)
		if found then
			return found
		end
	end

	return nil
end

local function resolveWindRootGui()
	if windRootGui and windRootGui.Parent then
		return windRootGui
	end

	local candidate = findGuiInstance(Window, {}, 5)
	if not candidate then
		return nil
	end

	if candidate:IsA("ScreenGui") then
		windRootGui = candidate
	else
		windRootGui = candidate:FindFirstAncestorOfClass("ScreenGui") or candidate
	end

	return windRootGui
end

local function applyWindowTransparency()
	if not Window or type(Window.ToggleTransparency) ~= "function" then
		warn("[TreeClicker] WindUI versi ini tidak mendukung Window:ToggleTransparency()")
		return
	end

	local success, err = pcall(function()
		Window:ToggleTransparency(appearance.transparent)
	end)

	if not success then
		warn("[TreeClicker] Gagal mengubah transparency window:", err)
	end
end

local function applyCustomTheme()
	customThemeRevision += 1
	local themeName = "TreeClickerCustom_" .. tostring(customThemeRevision)

	local success, err = pcall(function()
		WindUI:AddTheme({
			Name = themeName,
			Accent = appearance.accent,
			Background = appearance.background,
			Outline = appearance.outline,
			Text = appearance.text,
			Placeholder = appearance.placeholder,
			Button = appearance.button,
			Icon = appearance.icon,
		})

		WindUI:SetTheme(themeName)
	end)

	if not success then
		warn("[TreeClicker] Gagal menerapkan custom theme:", err)
	end
end

local function applyPresetTheme(themeName)
	local success, err = pcall(function()
		WindUI:SetTheme(themeName)
	end)

	if success then
		appearance.theme = themeName
	else
		warn("[TreeClicker] Gagal menerapkan preset theme:", err)
	end
end

local function getThemeNames()
	local fallback = { "Dark", "Light" }
	local success, result = pcall(function()
		return WindUI:GetThemes()
	end)

	if not success or type(result) ~= "table" then
		return fallback
	end

	local names = {}
	local lookup = {}

	for key, value in pairs(result) do
		local name
		if type(value) == "string" then
			name = value
		elseif type(value) == "table" then
			name = value.Name or value.name
		elseif type(key) == "string" then
			name = key
		end

		if type(name) == "string" and not lookup[name] then
			lookup[name] = true
			table.insert(names, name)
		end
	end

	if #names == 0 then
		return fallback
	end

	table.sort(names)
	return names
end

-------------------------------------------------------
-- Status Update
-------------------------------------------------------

local function updateStatus()
	local counts = getTreeCounts()
	local autoText = isLooping and "ON" or "OFF"

	if dashboardStatusParagraph then
		dashboardStatusParagraph:SetDesc((
			"Trees enabled: %d / %d\n"
			.. "Groups enabled: %d / %d\n"
			.. "Auto Trigger: %s"
		):format(
			counts.enabledTrees,
			counts.totalTrees,
			counts.enabledGroups,
			counts.totalGroups,
			autoText
		))
	end

	if mainStatusParagraph then
		mainStatusParagraph:SetDesc((
			"Enabled: %d / %d tree | Groups: %d / %d | Auto: %s"
		):format(
			counts.enabledTrees,
			counts.totalTrees,
			counts.enabledGroups,
			counts.totalGroups,
			autoText
		))
	end

	if shortcutParagraph then
		shortcutParagraph:SetDesc((
			"Window: %s\nTrigger Once: %s\nAuto Trigger: %s"
		):format(
			WINDOW_KEY.Name,
			TRIGGER_KEY.Name,
			AUTO_KEY.Name
		))
	end
end

-------------------------------------------------------
-- Tree Group UI
-------------------------------------------------------

local function destroyTreeToggleElements()
	for _, element in ipairs(treeToggleElements) do
		pcall(function()
			element:Destroy()
		end)
	end

	table.clear(treeToggleElements)
end

local function refreshTreeListUI()
	destroyTreeToggleElements()

	local groups = getTreeGroups()
	local names = {}

	for treeName in pairs(groups) do
		table.insert(names, treeName)
	end

	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	if #names == 0 then
		local emptyParagraph = TreeSection:Paragraph({
			Title = "No Trees Found",
			Desc = "Tekan Scan / Refresh Trees untuk memindai ulang plot.",
		})

		table.insert(treeToggleElements, emptyParagraph)
	else
		for _, treeName in ipairs(names) do
			local capturedName = treeName
			local count = groups[capturedName]

			local toggle = TreeSection:Toggle({
				Title = capturedName,
				Desc = ("%d instance — satu toggle mengontrol semuanya"):format(count),
				Icon = "check",
				Type = "Checkbox",
				Value = groupWhitelist[capturedName] ~= false,
				Callback = function(state)
					groupWhitelist[capturedName] = state
					updateStatus()
				end,
			})

			table.insert(treeToggleElements, toggle)
		end
	end

	updateStatus()
end

local function queueTreeUIRefresh()
	if refreshQueued then
		return
	end

	refreshQueued = true

	task.defer(function()
		refreshQueued = false
		refreshTreeListUI()
	end)
end

-------------------------------------------------------
-- Main Controls
-------------------------------------------------------

MainControlSection:Button({
	Title = "Scan / Refresh Trees",
	Desc = "Scan tree baru dan perbarui semua grup.",
	Icon = "refresh-cw",
	Locked = false,
	Callback = function()
		scanTrees()
		refreshTreeListUI()
	end,
})

MainControlSection:Button({
	Title = "Trigger Once",
	Desc = "Trigger semua tree enabled tanpa delay antar-tree.",
	Icon = "zap",
	Locked = false,
	Callback = function()
		triggerOnce()
		updateStatus()
	end,
})

autoToggle = MainControlSection:Toggle({
	Title = "Enable Auto Trigger",
	Desc = "Trigger semua grup enabled setiap siklus.",
	Icon = "check",
	Type = "Checkbox",
	Value = false,
	Callback = function(state)
		if state then
			startLooping()
		else
			stopLooping()
		end

		updateStatus()
	end,
})

MainControlSection:Button({
	Title = "Enable All Groups",
	Desc = "Aktifkan seluruh grup tree.",
	Icon = "check-check",
	Locked = false,
	Callback = function()
		local groups = getTreeGroups()

		for treeName in pairs(groups) do
			groupWhitelist[treeName] = true
		end

		refreshTreeListUI()
	end,
})

MainControlSection:Button({
	Title = "Disable All Groups",
	Desc = "Nonaktifkan seluruh grup tree.",
	Icon = "x",
	Locked = false,
	Callback = function()
		local groups = getTreeGroups()

		for treeName in pairs(groups) do
			groupWhitelist[treeName] = false
		end

		refreshTreeListUI()
	end,
})

-------------------------------------------------------
-- Trigger Settings
-------------------------------------------------------

TriggerSettingsSection:Input({
	Title = "Loop Cycle Delay",
	Desc = "Jeda antar-siklus auto trigger. Tidak ada delay antar-tree.",
	Value = tostring(LOOP_CYCLE_DELAY),
	InputIcon = "timer",
	Type = "Input",
	Placeholder = "Contoh: 1",
	Callback = function(input)
		local value = tonumber(input)

		if value and value >= 0 then
			LOOP_CYCLE_DELAY = value
			updateStatus()
		else
			warn("[TreeClicker] Loop delay harus berupa angka >= 0")
		end
	end,
})

-------------------------------------------------------
-- Window & Keybind Settings
-------------------------------------------------------

WindowSettingsSection:Keybind({
	Title = "Window Keybind",
	Desc = "Buka atau tutup window WindUI.",
	Value = WINDOW_KEY.Name,
	Callback = function(value)
		local keyCode = Enum.KeyCode[value]

		if keyCode then
			WINDOW_KEY = keyCode
			Window:SetToggleKey(keyCode)
			updateStatus()
		end
	end,
})

WindowSettingsSection:Keybind({
	Title = "Trigger Once Keybind",
	Desc = "Trigger semua tree enabled satu kali.",
	Value = TRIGGER_KEY.Name,
	Callback = function(value)
		local keyCode = Enum.KeyCode[value]

		if keyCode then
			TRIGGER_KEY = keyCode
			updateStatus()
		end
	end,
})

WindowSettingsSection:Keybind({
	Title = "Auto Trigger Keybind",
	Desc = "Aktifkan atau matikan auto trigger.",
	Value = AUTO_KEY.Name,
	Callback = function(value)
		local keyCode = Enum.KeyCode[value]

		if keyCode then
			AUTO_KEY = keyCode
			updateStatus()
		end
	end,
})

-------------------------------------------------------
-- Appearance Settings
-------------------------------------------------------

appearanceControls.theme = AppearanceSection:Dropdown({
	Title = "Theme Preset",
	Desc = "Gunakan salah satu preset theme bawaan WindUI.",
	Values = getThemeNames(),
	Value = appearance.theme,
	Multi = false,
	AllowNone = false,
	Callback = function(value)
		local selected = type(value) == "table" and value[1] or value
		if type(selected) == "string" then
			applyPresetTheme(selected)
		end
	end,
})

appearanceControls.accent = AppearanceSection:Colorpicker({
	Title = "Accent Color",
	Desc = "Warna aksen utama custom theme.",
	Default = appearance.accent,
	Transparency = 0,
	Locked = false,
	Callback = function(color)
		appearance.accent = color
		applyCustomTheme()
	end,
})

appearanceControls.background = AppearanceSection:Colorpicker({
	Title = "Background Color",
	Desc = "Warna background utama window.",
	Default = appearance.background,
	Transparency = 0,
	Locked = false,
	Callback = function(color)
		appearance.background = color
		applyCustomTheme()
	end,
})

appearanceControls.outline = AppearanceSection:Colorpicker({
	Title = "Outline Color",
	Desc = "Warna border dan garis pemisah.",
	Default = appearance.outline,
	Transparency = 0,
	Locked = false,
	Callback = function(color)
		appearance.outline = color
		applyCustomTheme()
	end,
})

appearanceControls.text = AppearanceSection:Colorpicker({
	Title = "Text Color",
	Desc = "Warna teks utama.",
	Default = appearance.text,
	Transparency = 0,
	Locked = false,
	Callback = function(color)
		appearance.text = color
		applyCustomTheme()
	end,
})

appearanceControls.button = AppearanceSection:Colorpicker({
	Title = "Button Color",
	Desc = "Warna tombol dan elemen interaktif.",
	Default = appearance.button,
	Transparency = 0,
	Locked = false,
	Callback = function(color)
		appearance.button = color
		applyCustomTheme()
	end,
})

appearanceControls.icon = AppearanceSection:Colorpicker({
	Title = "Icon Color",
	Desc = "Warna icon pada window dan elemen.",
	Default = appearance.icon,
	Transparency = 0,
	Locked = false,
	Callback = function(color)
		appearance.icon = color
		applyCustomTheme()
	end,
})

appearanceControls.transparent = AppearanceSection:Toggle({
	Title = "Transparent Window",
	Desc = "Aktifkan efek transparency bawaan WindUI.",
	Icon = "check",
	Type = "Checkbox",
	Value = appearance.transparent,
	Callback = function(state)
		appearance.transparent = state
		applyWindowTransparency()
	end,
})

AppearanceSection:Button({
	Title = "Reset Appearance",
	Desc = "Kembalikan theme, warna, dan transparency.",
	Icon = "rotate-ccw",
	Locked = false,
	Callback = function()
		appearance = table.clone(DEFAULT_APPEARANCE)
		applyPresetTheme(appearance.theme)
		applyWindowTransparency()

		if appearanceControls.theme then
			appearanceControls.theme:Select(appearance.theme)
		end
		if appearanceControls.transparent then
			appearanceControls.transparent:Set(appearance.transparent)
		end
	end,
})

-------------------------------------------------------
-- Dynamic Tree Detection
-------------------------------------------------------

plotModel.DescendantAdded:Connect(function(object)
	if not isTreeModel(object) then
		return
	end

	task.spawn(function()
		if registerTree(object) then
			queueTreeUIRefresh()
		end
	end)
end)

plotModel.DescendantRemoving:Connect(function(object)
	if unregisterTree(object) then
		queueTreeUIRefresh()
	end
end)

-------------------------------------------------------
-- Runtime Keybinds
-------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == TRIGGER_KEY then
		triggerOnce()
		updateStatus()

	elseif input.KeyCode == AUTO_KEY then
		if autoToggle then
			autoToggle:Set(not isLooping)
		elseif isLooping then
			stopLooping()
		else
			startLooping()
		end

		updateStatus()
	end
end)

-------------------------------------------------------
-- Initialize UI
-------------------------------------------------------

DashboardTab:Select()
refreshTreeListUI()
updateStatus()

task.defer(function()
end)
