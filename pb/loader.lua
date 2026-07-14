local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function isEnemy(player)
	local myTeam = LocalPlayer:GetAttribute("CurrentTeam")
	local theirTeam = player:GetAttribute("CurrentTeam")

	if not myTeam or not theirTeam then
		return false
	end

	return myTeam ~= theirTeam
end

local function removeESP(character)
	for _, name in ipairs({"EnemyHighlight","EnemyBillboard","TracerAttachment","TracerBeam"}) do
		local obj = character:FindFirstChild(name)
		if obj then
			obj:Destroy()
		end
	end

	if workspace.CurrentCamera then
		local a = workspace.CurrentCamera:FindFirstChild("LocalTracerAttachment")
		if a then
			local beam = a:FindFirstChild(character.Name .. "_Beam")
			if beam then
				beam:Destroy()
			end
		end
	end
end

local function setupCharacter(player, character)
	local head = character:WaitForChild("Head")
	local hrp = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	-- Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "EnemyHighlight"
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.OutlineColor = Color3.new(1,1,1)
	highlight.FillTransparency = 0.7
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	-- Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyBillboard"
	billboard.Size = UDim2.new(0,200,0,40)
	billboard.StudsOffset = Vector3.new(0,3.5,0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1,1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1,0.2,0.2)
	label.Parent = billboard

	-- Tracer
	local camera = workspace.CurrentCamera

	local localAttach = camera:FindFirstChild("LocalTracerAttachment")
	if not localAttach then
		localAttach = Instance.new("Attachment")
		localAttach.Name = "LocalTracerAttachment"
		localAttach.Parent = camera
	end

	local enemyAttach = Instance.new("Attachment")
	enemyAttach.Name = "TracerAttachment"
	enemyAttach.Parent = hrp

	local beam = Instance.new("Beam")
	beam.Name = character.Name .. "_Beam"
	beam.Attachment0 = localAttach
	beam.Attachment1 = enemyAttach
	beam.FaceCamera = true
	beam.Width0 = 0.01
	beam.Width1 = 0.01
	beam.Color = ColorSequence.new(Color3.fromRGB(255,0,0))
	beam.Parent = localAttach

	RunService.RenderStepped:Connect(function()
		if not character.Parent then
			return
		end

		local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not myHRP then
			return
		end

		local enemy = isEnemy(player)

		highlight.Enabled = enemy
		billboard.Enabled = enemy
		beam.Enabled = enemy

		if enemy then
			localAttach.WorldPosition = myHRP.Position

			local hpPercent = humanoid.Health / humanoid.MaxHealth

            local hpColor
            if hpPercent > 0.6 then
                hpColor = "#00FF00"
            elseif hpPercent > 0.3 then
                hpColor = "#FFFF00"
            else
                hpColor = "#FF0000"
            end

            local distance = math.floor((hrp.Position - myHRP.Position).Magnitude)

            local distanceColor
            if distance < 30 then
                distanceColor = "#00FF00" -- dekat
            elseif distance < 75 then
                distanceColor = "#FFFF00" -- sedang
            else
                distanceColor = "#FF5555" -- jauh
            end

            label.RichText = true
            label.Text = string.format(
                "<font color='#FF4444'>%s</font>\n" ..
                "<font color='%s'>HP: %d/%d</font>\n" ..
                "<font color='%s'>%d studs</font>",
                player.DisplayName,
                hpColor,
                math.floor(humanoid.Health),
                math.floor(humanoid.MaxHealth),
                distanceColor,
                distance
            )

			if hpPercent > 0.6 then
				label.TextColor3 = Color3.fromRGB(0,255,0)
			elseif hpPercent > 0.3 then
				label.TextColor3 = Color3.fromRGB(255,255,0)
			else
				label.TextColor3 = Color3.fromRGB(255,0,0)
			end
		end
	end)
end

local function setupPlayer(player)
	if player == LocalPlayer then
		return
	end

	if player.Character then
		setupCharacter(player, player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		setupCharacter(player, char)
	end)

	player:GetAttributeChangedSignal("CurrentTeam"):Connect(function()
		if player.Character then
			removeESP(player.Character)
			setupCharacter(player, player.Character)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
