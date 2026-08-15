--!strict

local SnapGeometry = {}

local function getBounds(instance: Instance): (CFrame?, Vector3?)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	end

	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end

	return nil, nil
end

function SnapGeometry.roundToGrid(value: number, grid: number): number
	if grid <= 0.0001 then
		return value
	end

	return math.round(value / grid) * grid
end

function SnapGeometry.supportExtent(
	halfSize: Vector3,
	rotation: CFrame,
	worldAxis: Vector3
): number
	local axis = worldAxis.Unit

	return math.abs(axis:Dot(rotation.RightVector)) * halfSize.X
		+ math.abs(axis:Dot(rotation.UpVector)) * halfSize.Y
		+ math.abs(axis:Dot(rotation.LookVector)) * halfSize.Z
end

function SnapGeometry.worldAABB(instance: Instance): (CFrame?, Vector3?)
	return getBounds(instance)
end

function SnapGeometry.snapPointToPlotGrid(
	worldPoint: Vector3,
	plotOrigin: CFrame?,
	gridSize: number
): Vector3
	if not plotOrigin then
		return Vector3.new(
			SnapGeometry.roundToGrid(worldPoint.X, gridSize),
			worldPoint.Y,
			SnapGeometry.roundToGrid(worldPoint.Z, gridSize)
		)
	end

	local localPoint = plotOrigin:PointToObjectSpace(worldPoint)

	local snappedLocal = Vector3.new(
		SnapGeometry.roundToGrid(localPoint.X, gridSize),
		localPoint.Y,
		SnapGeometry.roundToGrid(localPoint.Z, gridSize)
	)

	return plotOrigin:PointToWorldSpace(snappedLocal)
end

local function strongestVerticalAxis(cframe: CFrame): (Vector3, number)
	local axes = {
		cframe.RightVector,
		cframe.UpVector,
		cframe.LookVector,
	}

	local bestAxis = axes[1]
	local bestDot = math.abs(bestAxis:Dot(Vector3.yAxis))

	for i = 2, #axes do
		local dot = math.abs(axes[i]:Dot(Vector3.yAxis))
		if dot > bestDot then
			bestDot = dot
			bestAxis = axes[i]
		end
	end

	if bestAxis:Dot(Vector3.yAxis) < 0 then
		bestAxis = -bestAxis
	end

	return bestAxis, bestDot
end

function SnapGeometry.isMostlyUpright(cframe: CFrame): boolean
	local _, verticalDot = strongestVerticalAxis(cframe)
	return verticalDot >= 0.90
end

function SnapGeometry.faceSnap(
	targetCFrame: CFrame,
	targetSize: Vector3,
	hitPosition: Vector3,
	previewHalfSize: Vector3,
	previewRotation: CFrame
): Vector3
	local localHit = targetCFrame:PointToObjectSpace(hitPosition)

	local nx = math.abs(localHit.X / math.max(targetSize.X / 2, 0.001))
	local ny = math.abs(localHit.Y / math.max(targetSize.Y / 2, 0.001))
	local nz = math.abs(localHit.Z / math.max(targetSize.Z / 2, 0.001))

	local localNormal: Vector3
	if nx >= ny and nx >= nz then
		localNormal = Vector3.new(if localHit.X >= 0 then 1 else -1, 0, 0)
	elseif ny >= nx and ny >= nz then
		localNormal = Vector3.new(0, if localHit.Y >= 0 then 1 else -1, 0)
	else
		localNormal = Vector3.new(0, 0, if localHit.Z >= 0 then 1 else -1)
	end

	local worldNormal = targetCFrame:VectorToWorldSpace(localNormal).Unit

	local targetSupport = SnapGeometry.supportExtent(
		targetSize / 2,
		targetCFrame - targetCFrame.Position,
		worldNormal
	)

	local previewSupport = SnapGeometry.supportExtent(
		previewHalfSize,
		previewRotation,
		worldNormal
	)

	return targetCFrame.Position
		+ worldNormal * (targetSupport + previewSupport)
end

function SnapGeometry.trySlantedTopSnap(
	targetCFrame: CFrame,
	targetSize: Vector3,
	hitPosition: Vector3,
	previewHalfSize: Vector3,
	previewRotation: CFrame,
	catchFraction: number,
	contactInset: number
): Vector3?
	if not SnapGeometry.isMostlyUpright(targetCFrame) then
		return nil
	end

	local verticalAxis, _ = strongestVerticalAxis(targetCFrame)
	local targetHalfHeight = SnapGeometry.supportExtent(
		targetSize / 2,
		targetCFrame - targetCFrame.Position,
		verticalAxis
	)

	local localAimHeight =
		(hitPosition - targetCFrame.Position):Dot(verticalAxis)

	-- Only engage when aiming at the upper portion of the target.
	local minimumAimHeight =
		targetHalfHeight * (1 - math.clamp(catchFraction, 0, 1))

	if localAimHeight < minimumAimHeight then
		return nil
	end

	local targetTop =
		targetCFrame.Position + verticalAxis * targetHalfHeight

	-- The slanted plank must use its lowest rotated support point rather
	-- than its center. This is what prevents the lower end from floating.
	local worldDown = -Vector3.yAxis
	local downwardSupport = SnapGeometry.supportExtent(
		previewHalfSize,
		previewRotation,
		worldDown
	)

	return targetTop
		+ Vector3.yAxis * downwardSupport
		- verticalAxis * contactInset
end

function SnapGeometry.overlapsPlacedObjects(
	workspaceRoot: Workspace,
	cframe: CFrame,
	size: Vector3,
	exclusions: {Instance},
	tolerance: number
): boolean
	local reducedSize = Vector3.new(
		math.max(0.05, size.X - tolerance),
		math.max(0.05, size.Y - tolerance),
		math.max(0.05, size.Z - tolerance)
	)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions

	for _, part in ipairs(workspaceRoot:GetPartBoundsInBox(cframe, reducedSize, params)) do
		if part:GetAttribute("IsRestaurantPlacedObject") == true then
			return true
		end
	end

	return false
end

return SnapGeometry
