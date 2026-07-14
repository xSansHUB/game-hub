local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TARGET_TEAMS = {
	Killer = true,
	Survivors = true,
}

--==================================================
-- PLAYER HIGHLIGHT
--==================================================

local function updateHighlight(player)
	if player == LocalPlayer then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local highlight = character:FindFirstChild("TeamHighlight")
	local team = player.Team
	local shouldHighlight = team and TARGET_TEAMS[team.Name]

	if shouldHighlight then
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "TeamHighlight"
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0
			highlight.Parent = character
		end

		local teamColor = player.TeamColor.Color

		highlight.FillColor = teamColor
		highlight.OutlineColor = teamColor
		highlight.Enabled = true
	elseif highlight then
		highlight:Destroy()
	end
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		updateHighlight(player)
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

local oldCrosshair = PlayerGui:FindFirstChild("SimpleCrosshair")

if oldCrosshair then
	oldCrosshair:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleCrosshair"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = PlayerGui

local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(30, 30)
crosshair.BackgroundTransparency = 1
crosshair.Parent = screenGui

local function createLine(name, size, position)
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
	stroke.Parent = line

	return line
end

-- Garis kiri
createLine(
	"Left",
	UDim2.fromOffset(8, 2),
	UDim2.new(0.5, -7, 0.5, 0)
)

-- Garis kanan
createLine(
	"Right",
	UDim2.fromOffset(8, 2),
	UDim2.new(0.5, 7, 0.5, 0)
)

-- Garis atas
createLine(
	"Top",
	UDim2.fromOffset(2, 8),
	UDim2.new(0.5, 0, 0.5, -7)
)

-- Garis bawah
createLine(
	"Bottom",
	UDim2.fromOffset(2, 8),
	UDim2.new(0.5, 0, 0.5, 7)
)

-- Titik tengah
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
dotStroke.Parent = centerDot
