--!strict

local PlaceableConfig = {}

PlaceableConfig.WOODEN_PLANK_ITEM_ID = "Material_WoodenPlank"

PlaceableConfig.WoodenPlank = {
	ItemId = PlaceableConfig.WOODEN_PLANK_ITEM_ID,
	ModelName = "Material_WoodenPlank",

	TargetLongestSide = 7,
	HeldLongestSide = 3.3,
	GroundGridSize = 1,

	SnapMagnetDistance = 2.25,
	AlignmentMagnetDistance = 0.60,

	-- Retained from the original slanted placement tuning.
	SLANTED_TOP_CATCH_FRACTION = 0.65,
	SLANTED_CONTACT_INSET = 0.045,

	OverlapTolerance = 0.04,
	MaxPlacementDistance = 40,
}

return PlaceableConfig
