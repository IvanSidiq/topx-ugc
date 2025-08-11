# StarterGui Migration Guide

This folder contains all GUI elements that will be placed in StarterGui.

## Folder Structure

Each ScreenGui from your Roblox Studio should have its own folder here:

```
src/gui/
├── MainMenu/
│   ├── init.client.lua        # LocalScript for the GUI
│   ├── structure.lua          # GUI element creation
│   └── README.md             # Notes about this GUI
├── HUD/
│   ├── init.client.lua
│   ├── structure.lua
│   └── README.md
└── InventoryGUI/
    ├── init.client.lua
    ├── structure.lua
    └── README.md
```

## Migration Steps

1. **Copy your ScreenGui's LocalScript content** to `init.client.lua`
2. **Create GUI structure** in `structure.lua` 
3. **Update any require() paths** to match the new project structure
4. **Test in Roblox Studio** after syncing with Rojo

## Example Structure

See the `ExampleGUI/` folder for a template of how to organize your GUI code. 