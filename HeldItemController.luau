--!strict

local HeldItemController = {}
HeldItemController.__index = HeldItemController

local function getRightHand(character: Model): BasePart?
	for _, name in ipairs({
		"RightHand",
		"RightLowerArm",
		"RightUpperArm",
		"Right Arm",
	}) do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			return limb
		end
	end

	return nil
end

local function collectParts(instance: Instance): {BasePart}
	local parts = {}

	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function rootPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

function HeldItemController.new(player: Player)
	return setmetatable({
		Player = player,
		Model = nil,
		Motor = nil,
	}, HeldItemController)
end

function HeldItemController:Clear()
	if self.Motor then
		self.Motor:Destroy()
		self.Motor = nil
	end

	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
end

function HeldItemController:Show(template: Instance, displayOffset: CFrame)
	self:Clear()

	local character = self.Player.Character
	if not character then
		return
	end

	local hand = getRightHand(character)
	if not hand then
		return
	end

	local clone = template:Clone()
	local root = rootPart(clone)

	if not root then
		clone:Destroy()
		return
	end

	local parts = collectParts(clone)

	for _, part in ipairs(parts) do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
	end

	clone.Parent = character

	for _, part in ipairs(parts) do
		if part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
		end
	end

	root.CFrame = hand.CFrame * displayOffset

	local motor = Instance.new("Motor6D")
	motor.Name = "HeldItemMotor"
	motor.Part0 = hand
	motor.Part1 = root
	motor.C0 = displayOffset
	motor.C1 = CFrame.identity
	motor.Parent = hand

	self.Model = clone
	self.Motor = motor
end

function HeldItemController:SetOffset(displayOffset: CFrame)
	if self.Motor then
		self.Motor.C0 = displayOffset
	end
end

return HeldItemController
