# Roblox Wooden Plank Building System

A focused Roblox/Luau building system extracted from a larger restaurant game project.

The system allows players to equip wooden planks, preview placement, rotate pieces, snap them to other wooden planks, place slanted pieces on top of upright pieces, prevent invalid overlap, place only inside an owned plot, and pick placed planks back up.

## Features

- Wooden-plank-only construction system
- Client-side placement preview
- Plot-local grid snapping
- Face-to-face plank snapping
- Horizontal and vertical placement modes
- 30° yaw and pitch rotation
- Slanted-plank top snapping
- Slanted contact inset to avoid visible gaps
- Overlap prevention
- Held-item visualization
- Client/server placement validation
- Ownership-aware pickup
- Inventory RemoteFunction integration

## Controls

| Control | Action |
|---|---|
| Left Click | Place selected wooden plank |
| Right Click | Rotate yaw by 30° |
| V | Rotate pitch by 30° |
| F | Toggle horizontal / vertical mode |
| Double Right Click | Pick up a placed plank |

## Project Structure

```text
src/
├── client/
│   ├── PlacementController.luau
│   ├── PlacementPreview.luau
│   └── HeldItemController.luau
├── server/
│   └── PlacementService.luau
└── shared/
    ├── PlaceableConfig.luau
    └── SnapGeometry.luau
```

## Architecture

The client is responsible for input, visual previews, and calculating a proposed placement transform.

The server remains authoritative. It verifies that the player owns the selected item, owns the plot, is placing within the plot bounds, and is close enough to the requested placement before creating the final object.

This separation keeps placement responsive while preventing the client from directly creating authoritative world objects.

## Slanted Placement

A normal center-based face snap works for horizontal and vertical pieces, but it can create visible gaps when a plank is rotated.

The slanted-top logic uses the rotated plank geometry to estimate the lower contact edge and aligns it with the top of an upright target.

Two tuning values are intentionally retained:

```lua
SLANTED_TOP_CATCH_FRACTION = 0.65
SLANTED_CONTACT_INSET = 0.045
```

The first controls how much of the upper region of an upright target can trigger the slanted-top snap. The second slightly moves the slanted piece into the contact point to remove small visual gaps caused by mesh bounds.

## Roblox Setup

The sample expects:

```text
ReplicatedStorage
├── PlaceableModels
│   └── Material_WoodenPlank
├── Remotes
│   ├── GetInventorySnapshot
│   ├── PlaceInventoryItem
│   └── PickupPlacedItem
└── BuildingSystem
    ├── PlaceableConfig
    └── SnapGeometry

StarterPlayer
└── StarterPlayerScripts
    └── BuildingSystem
        ├── PlacementController
        ├── PlacementPreview
        └── HeldItemController

ServerScriptService
└── PlacementService
```

`Material_WoodenPlank` should be a Model or BasePart.

Each player plot is expected to be a Model under:

```text
Workspace.PlayerPlots
```

with:

- `OwnerUserId` attribute
- `PlotOrigin` BasePart

The server file contains clearly marked integration points for an existing inventory implementation.

## Notes

This repository is a focused version of a larger Roblox building system. Material-specific branches for window frames, brick walls, stone walls, and cross-material special cases were removed so the core placement architecture is easier to review.
