# Integration Notes

This repository is intentionally focused on the placement system.

The `PlacementService.luau` file contains three small inventory adapter functions:

- `selectedInventoryItemId`
- `consumeWoodenPlank`
- `returnWoodenPlank`

They are placeholders because the full restaurant-game inventory service was not included in the exported code sample.

When integrating back into the full game, replace those adapters with calls to the existing inventory service.

The rest of the placement architecture is independent of the inventory implementation.
