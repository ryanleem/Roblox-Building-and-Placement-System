--!strict

local PlacementPreview = {}
PlacementPreview.__index = PlacementPreview

local PREVIEW_TRANSPARENCY = 0.55

local function stylePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = math.max(part.Transparency, PREVIEW_TRANSPARENCY)
end

local function styleInstance(instance: Instance)
	if instance:IsA("BasePart") then
		stylePart(instance)
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			stylePart(descendant)
		end
	end
end

local function pivot(instance: Instance, cframe: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	elseif instance:IsA("BasePart") then
		instance.CFrame = cframe
	end
end

function PlacementPreview.new(template: Instance)
	local self = setmetatable({}, PlacementPreview)

	self.Instance = template:Clone()
	self.Instance.Name = "PlacementPreview"
	styleInstance(self.Instance)
	self.Instance.Parent = workspace

	return self
end

function PlacementPreview:SetCFrame(cframe: CFrame)
	if self.Instance then
		pivot(self.Instance, cframe)
	end
end

function PlacementPreview:GetBounds(): (CFrame?, Vector3?)
	if not self.Instance then
		return nil, nil
	end

	if self.Instance:IsA("Model") then
		return self.Instance:GetBoundingBox()
	end

	if self.Instance:IsA("BasePart") then
		return self.Instance.CFrame, self.Instance.Size
	end

	return nil, nil
end

function PlacementPreview:SetValid(valid: boolean)
	if not self.Instance then
		return
	end

	-- The original project can replace this with green/red highlighting.
	-- Keeping preview styling simple makes the sample easier to read.
	self.IsValid = valid
end

function PlacementPreview:Destroy()
	if self.Instance then
		self.Instance:Destroy()
		self.Instance = nil
	end
end

return PlacementPreview
