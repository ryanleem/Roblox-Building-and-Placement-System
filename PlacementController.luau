--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local buildingSystem = ReplicatedStorage:WaitForChild("BuildingSystem")
local PlaceableConfig = require(buildingSystem:WaitForChild("PlaceableConfig"))
local SnapGeometry = require(buildingSystem:WaitForChild("SnapGeometry"))

local localModules = script.Parent
local PlacementPreview = require(localModules:WaitForChild("PlacementPreview"))
local HeldItemController = require(localModules:WaitForChild("HeldItemController"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getInventorySnapshotRemote = remotes:WaitForChild("GetInventorySnapshot")
local placeInventoryItemRemote = remotes:WaitForChild("PlaceInventoryItem")
local pickupPlacedItemRemote = remotes:WaitForChild("PickupPlacedItem")

local placeableModels = ReplicatedStorage:WaitForChild("PlaceableModels")
local woodenPlankTemplate = placeableModels:WaitForChild(
	PlaceableConfig.WoodenPlank.ModelName
)

local config = PlaceableConfig.WoodenPlank
local heldItem = HeldItemController.new(player)

local preview = nil
local previewCFrame: CFrame? = nil
local previewValid = false

local currentYawDegrees = 0
local currentPitchDegrees = 0
local verticalMode = false

local selectedSlot = 1
local selectedItemId: string? = nil
local lastRightClickTime = 0

local function requestSelectedItem()
	local success, snapshot = pcall(function()
		return getInventorySnapshotRemote:InvokeServer()
	end)

	if not success or type(snapshot) ~= "table" then
		selectedItemId = nil
		return
	end

	local slots = snapshot.Slots
		or (snapshot.Snapshot and snapshot.Snapshot.Slots)

	if type(slots) ~= "table" then
		selectedItemId = nil
		return
	end

	local slot = slots[selectedSlot]
	if type(slot) == "table"
		and type(slot.Item) == "table"
		and type(slot.Item.ItemId) == "string"
	then
		selectedItemId = slot.Item.ItemId
	else
		selectedItemId = nil
	end
end

local function getPlotOrigin(): CFrame?
	local plots = Workspace:FindFirstChild("PlayerPlots")
	if not plots then
		return nil
	end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId") == player.UserId
		then
			local origin = plot:FindFirstChild("PlotOrigin")
			if origin and origin:IsA("BasePart") then
				return origin.CFrame
			end
		end
	end

	return nil
end

local function rotationCFrame(): CFrame
	local yaw = CFrame.Angles(0, math.rad(currentYawDegrees), 0)
	local pitch = CFrame.Angles(math.rad(currentPitchDegrees), 0, 0)

	local mode =
		if verticalMode
		then CFrame.Angles(0, 0, math.rad(90))
		else CFrame.identity

	return yaw * pitch * mode
end

local function heldOffset(): CFrame
	return CFrame.new(0, -0.45, -0.55)
		* CFrame.Angles(math.rad(90), 0, math.rad(90))
		* rotationCFrame()
end

local function ensurePreview()
	if selectedItemId ~= PlaceableConfig.WOODEN_PLANK_ITEM_ID then
		if preview then
			preview:Destroy()
			preview = nil
		end

		heldItem:Clear()
		return false
	end

	if not preview then
		preview = PlacementPreview.new(woodenPlankTemplate)
	end

	if not heldItem.Model then
		heldItem:Show(woodenPlankTemplate, heldOffset())
	else
		heldItem:SetOffset(heldOffset())
	end

	return true
end

local function mouseRaycast(): RaycastResult?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local exclusions = {}

	if player.Character then
		table.insert(exclusions, player.Character)
	end

	if preview and preview.Instance then
		table.insert(exclusions, preview.Instance)
	end

	params.FilterDescendantsInstances = exclusions

	return Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end

local function placedRootFromHit(hit: Instance?): Instance?
	local current = hit

	while current and current ~= Workspace do
		if current:GetAttribute("IsRestaurantPlacedObject") == true
			and current:GetAttribute("ItemId")
				== PlaceableConfig.WOODEN_PLANK_ITEM_ID
		then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function updatePreview()
	if not ensurePreview() then
		return
	end

	local result = mouseRaycast()
	if not result then
		previewValid = false
		return
	end

	local rotation = rotationCFrame()

	-- First apply the rotation so the preview reports its rotated bounds.
	preview:SetCFrame(CFrame.new(result.Position) * rotation)

	local _, size = preview:GetBounds()
	if not size then
		previewValid = false
		return
	end

	local previewHalfSize = size / 2
	local target = placedRootFromHit(result.Instance)
	local position: Vector3

	if target then
		local targetCF, targetSize = SnapGeometry.worldAABB(target)

		if targetCF and targetSize then
			local isSlanted = (currentPitchDegrees % 180) ~= 0

			local slantedPosition =
				if isSlanted
				then SnapGeometry.trySlantedTopSnap(
					targetCF,
					targetSize,
					result.Position,
					previewHalfSize,
					rotation,
					config.SLANTED_TOP_CATCH_FRACTION,
					config.SLANTED_CONTACT_INSET
				)
				else nil

			position = slantedPosition
				or SnapGeometry.faceSnap(
					targetCF,
					targetSize,
					result.Position,
					previewHalfSize,
					rotation
				)
		else
			position = result.Position
		end
	else
		local support =
			SnapGeometry.supportExtent(
				previewHalfSize,
				rotation,
				result.Normal
			)

		position =
			result.Position + result.Normal * support

		if result.Normal.Y > 0.7 then
			position = SnapGeometry.snapPointToPlotGrid(
				position,
				getPlotOrigin(),
				config.GroundGridSize
			)
		end
	end

	previewCFrame = CFrame.new(position) * rotation
	preview:SetCFrame(previewCFrame)

	local boundsCF, boundsSize = preview:GetBounds()
	if not boundsCF or not boundsSize then
		previewValid = false
		return
	end

	local exclusions = {}
	if player.Character then
		table.insert(exclusions, player.Character)
	end
	if preview.Instance then
		table.insert(exclusions, preview.Instance)
	end
	if target then
		table.insert(exclusions, target)
	end

	previewValid = not SnapGeometry.overlapsPlacedObjects(
		Workspace,
		boundsCF,
		boundsSize,
		exclusions,
		config.OverlapTolerance
	)

	preview:SetValid(previewValid)
end

local function placePreview()
	if not previewValid
		or not previewCFrame
		or selectedItemId ~= PlaceableConfig.WOODEN_PLANK_ITEM_ID
	then
		return
	end

	local success, response = pcall(function()
		return placeInventoryItemRemote:InvokeServer(
			selectedSlot,
			previewCFrame
		)
	end)

	if not success or type(response) ~= "table" then
		return
	end

	requestSelectedItem()
end

local function pickupUnderMouse()
	local result = mouseRaycast()
	if not result then
		return
	end

	local root = placedRootFromHit(result.Instance)
	if not root then
		return
	end

	local placementId = root:GetAttribute("PlacementId")
	if type(placementId) ~= "string" then
		return
	end

	pcall(function()
		pickupPlacedItemRemote:InvokeServer(placementId)
	end)

	requestSelectedItem()
end

local function rotateYaw()
	currentYawDegrees = (currentYawDegrees + 30) % 360
	heldItem:SetOffset(heldOffset())
end

local function rotatePitch()
	currentPitchDegrees = (currentPitchDegrees + 30) % 360
	heldItem:SetOffset(heldOffset())
end

local function toggleVertical()
	verticalMode = not verticalMode
	currentPitchDegrees = 0
	heldItem:SetOffset(heldOffset())
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		placePreview()

	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		local now = os.clock()

		if now - lastRightClickTime <= 0.28 then
			pickupUnderMouse()
			lastRightClickTime = 0
		else
			lastRightClickTime = now
			rotateYaw()
		end

	elseif input.KeyCode == Enum.KeyCode.V then
		rotatePitch()

	elseif input.KeyCode == Enum.KeyCode.F then
		toggleVertical()

	elseif input.KeyCode.Value >= Enum.KeyCode.One.Value
		and input.KeyCode.Value <= Enum.KeyCode.Six.Value
	then
		selectedSlot =
			input.KeyCode.Value - Enum.KeyCode.One.Value + 1

		requestSelectedItem()
	end
end)

player.CharacterAdded:Connect(function()
	heldItem:Clear()
	task.delay(0.5, requestSelectedItem)
end)

requestSelectedItem()

RunService.RenderStepped:Connect(updatePreview)
