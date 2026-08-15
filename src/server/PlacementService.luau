--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local buildingSystem = ReplicatedStorage:WaitForChild("BuildingSystem")
local PlaceableConfig = require(buildingSystem:WaitForChild("PlaceableConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeRemote = remotes:WaitForChild("PlaceInventoryItem")
local pickupRemote = remotes:WaitForChild("PickupPlacedItem")

local placeableModels = ReplicatedStorage:WaitForChild("PlaceableModels")
local template = placeableModels:WaitForChild(
	PlaceableConfig.WoodenPlank.ModelName
)

local placedFolder = Workspace:FindFirstChild("PlacedRestaurantObjects")
if not placedFolder then
	placedFolder = Instance.new("Folder")
	placedFolder.Name = "PlacedRestaurantObjects"
	placedFolder.Parent = Workspace
end

local config = PlaceableConfig.WoodenPlank

local function ownedPlot(player: Player): Model?
	local plots = Workspace:FindFirstChild("PlayerPlots")
	if not plots then
		return nil
	end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId") == player.UserId
		then
			return plot
		end
	end

	return nil
end

local function plotOrigin(plot: Model): BasePart?
	local origin = plot:FindFirstChild("PlotOrigin")
	if origin and origin:IsA("BasePart") then
		return origin
	end

	return nil
end

local function withinPlot(plot: Model, placement: CFrame): boolean
	local origin = plotOrigin(plot)
	if not origin then
		return false
	end

	-- PlotOrigin's size is used as the buildable footprint in this sample.
	local localPoint = origin.CFrame:PointToObjectSpace(placement.Position)
	local half = origin.Size / 2

	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Z) <= half.Z
end

local function closeEnough(player: Player, position: Vector3): boolean
	local character = player.Character
	local root = character
		and character:FindFirstChild("HumanoidRootPart")

	if not root or not root:IsA("BasePart") then
		return false
	end

	return (root.Position - position).Magnitude
		<= config.MaxPlacementDistance
end

local function cloneAt(cframe: CFrame): Instance
	local clone = template:Clone()

	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	end

	return clone
end

local function annotatePlacedObject(
	instance: Instance,
	player: Player
)
	instance:SetAttribute("IsRestaurantPlacedObject", true)
	instance:SetAttribute("OwnerUserId", player.UserId)
	instance:SetAttribute(
		"ItemId",
		PlaceableConfig.WOODEN_PLANK_ITEM_ID
	)
	instance:SetAttribute(
		"PlacementId",
		HttpService:GenerateGUID(false)
	)
end

local function findPlacement(placementId: string): Instance?
	for _, object in ipairs(placedFolder:GetChildren()) do
		if object:GetAttribute("PlacementId") == placementId then
			return object
		end
	end

	return nil
end

----------------------------------------------------------------
-- INVENTORY INTEGRATION
--
-- Replace these three functions with the real inventory service
-- used by the game. They are isolated here so the placement
-- architecture can be reviewed independently.
----------------------------------------------------------------

local function selectedInventoryItemId(
	_player: Player,
	_slotIndex: number
): string?
	-- Example integration:
	-- return InventoryService:GetItemInSlot(player, slotIndex).ItemId
	return PlaceableConfig.WOODEN_PLANK_ITEM_ID
end

local function consumeWoodenPlank(
	_player: Player,
	_slotIndex: number
): boolean
	-- Example integration:
	-- return InventoryService:RemoveOneFromSlot(player, slotIndex)
	return true
end

local function returnWoodenPlank(
	_player: Player
): boolean
	-- Example integration:
	-- return InventoryService:AddItem(player, PlaceableConfig.WOODEN_PLANK_ITEM_ID, 1)
	return true
end

placeRemote.OnServerInvoke = function(
	player: Player,
	slotIndex: number,
	requestedCFrame: CFrame
)
	if type(slotIndex) ~= "number"
		or typeof(requestedCFrame) ~= "CFrame"
	then
		return {
			Success = false,
			Reason = "BadRequest",
		}
	end

	local itemId = selectedInventoryItemId(player, slotIndex)

	if itemId ~= PlaceableConfig.WOODEN_PLANK_ITEM_ID then
		return {
			Success = false,
			Reason = "SelectedItemChanged",
		}
	end

	local plot = ownedPlot(player)
	if not plot then
		return {
			Success = false,
			Reason = "NoOwnedPlot",
		}
	end

	if not withinPlot(plot, requestedCFrame) then
		return {
			Success = false,
			Reason = "OutsidePlot",
		}
	end

	if not closeEnough(player, requestedCFrame.Position) then
		return {
			Success = false,
			Reason = "TooFarAway",
		}
	end

	if not consumeWoodenPlank(player, slotIndex) then
		return {
			Success = false,
			Reason = "SelectedSlotEmpty",
		}
	end

	local object = cloneAt(requestedCFrame)
	annotatePlacedObject(object, player)
	object.Parent = placedFolder

	return {
		Success = true,
		PlacementId = object:GetAttribute("PlacementId"),
	}
end

pickupRemote.OnServerInvoke = function(
	player: Player,
	placementId: string
)
	if type(placementId) ~= "string" then
		return {
			Success = false,
			Reason = "BadRequest",
		}
	end

	local object = findPlacement(placementId)
	if not object then
		return {
			Success = false,
			Reason = "NotFound",
		}
	end

	if object:GetAttribute("OwnerUserId") ~= player.UserId then
		return {
			Success = false,
			Reason = "NotOwner",
		}
	end

	if not returnWoodenPlank(player) then
		return {
			Success = false,
			Reason = "InventoryFull",
		}
	end

	object:Destroy()

	return {
		Success = true,
	}
end
