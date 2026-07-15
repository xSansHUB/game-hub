local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==================================================
-- CONFIG
--==================================================

local HIGHLIGHT_KEY = Enum.KeyCode.H
local CROSSHAIR_KEY = Enum.KeyCode.X

local REFRESH_INTERVAL = 1 -- Refresh highlight setiap 1 detik

local HIGHLIGHT_NAME = "TeamHighlight"
local CROSSHAIR_GUI_NAME = "SimpleCrosshair"

local TARGET_TEAMS = {
	Killer = true,
	Survivors = true,
}

local highlightEnabled = true
local crosshairEnabled = true

--==================================================
-- PLAYER HIGHLIGHT
--==================================================

local function removeHighlight(character)
	if not character then
		return
	end

	local highlight = character:FindFirstChild(HIGHLIGHT_NAME)

	if highlight then
		highlight:Destroy()
	end
end

local function updateHighlight(player)
	if player == LocalPlayer then
		removeHighlight(player.Character)
		return
	end

	local character = player.Character

	if not character then
		return
	end

	local team = player.Team
	local highlight = character:FindFirstChild(HIGHLIGHT_NAME)

	local shouldHighlight =
		highlightEnabled
		and team ~= nil
		and TARGET_TEAMS[team.Name] == true

	if not shouldHighlight then
		if highlight then
			highlight:Destroy()
		end

		return
	end

	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = HIGHLIGHT_NAME
		highlight.Adornee = character
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0

		highlight.Parent = character
	end

	-- Refresh warna berdasarkan TeamColor terbaru
	local teamColor = player.TeamColor.Color

	highlight.Adornee = character
	highlight.FillColor = teamColor
	highlight.OutlineColor = teamColor
	highlight.Enabled = true
end

local function updateAllHighlights()
	for _, player in Players:GetPlayers() do
		updateHighlight(player)
	end
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 5)

		task.wait(0.1)
		updateHighlight(player)
	end)

	player.CharacterRemoving:Connect(function(character)
		removeHighlight(character)
	end)

	player:GetPropertyChangedSignal("Team"):Connect(function()
		updateHighlight(player)
	end)

	player:GetPropertyChangedSignal("TeamColor"):Connect(function()
		updateHighlight(player)
	end)

	if player.Character then
		updateHighlight(player)
	end
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

--==================================================
-- CROSSHAIR
--==================================================

local oldCrosshairGui = PlayerGui:FindFirstChild(CROSSHAIR_GUI_NAME)

if oldCrosshairGui then
	oldCrosshairGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = CROSSHAIR_GUI_NAME
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Enabled = crosshairEnabled
screenGui.Parent = PlayerGui

local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(30, 30)
crosshair.BackgroundTransparency = 1
crosshair.Parent = screenGui

local function createCrosshairLine(name, size, position)
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = position
	line.Size = size
	line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	line.BorderSizePixel = 0
	line.Parent = crosshair

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = line

	return line
end

createCrosshairLine(
	"Left",
	UDim2.fromOffset(8, 2),
	UDim2.new(0.5, -7, 0.5, 0)
)

createCrosshairLine(
	"Right",
	UDim2.fromOffset(8, 2),
	UDim2.new(0.5, 7, 0.5, 0)
)

createCrosshairLine(
	"Top",
	UDim2.fromOffset(2, 8),
	UDim2.new(0.5, 0, 0.5, -7)
)

createCrosshairLine(
	"Bottom",
	UDim2.fromOffset(2, 8),
	UDim2.new(0.5, 0, 0.5, 7)
)

local centerDot = Instance.new("Frame")
centerDot.Name = "CenterDot"
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.fromScale(0.5, 0.5)
centerDot.Size = UDim2.fromOffset(3, 3)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
centerDot.BorderSizePixel = 0
centerDot.Parent = crosshair

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = centerDot

local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.fromRGB(0, 0, 0)
dotStroke.Thickness = 1
dotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dotStroke.Parent = centerDot

--==================================================
-- KEYBINDS
--==================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Mencegah keybind aktif saat sedang mengetik
	if UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == HIGHLIGHT_KEY then
		highlightEnabled = not highlightEnabled
		updateAllHighlights()

	elseif input.KeyCode == CROSSHAIR_KEY then
		crosshairEnabled = not crosshairEnabled
		screenGui.Enabled = crosshairEnabled
	end
end)

--==================================================
-- AUTO REFRESH
--==================================================

task.spawn(function()
	while task.wait(REFRESH_INTERVAL) do
		updateAllHighlights()
	end
end)

-- Refresh awal
updateAllHighlights()
