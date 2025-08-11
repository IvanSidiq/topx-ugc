# ServerScriptService Migration Guide

This folder contains all server-side scripts that will be placed in ServerScriptService.

## Folder Structure

Organize your scripts logically:

```
src/server/
├── init.server.lua           # Main server initialization
├── modules/                  # ModuleScripts for server logic
│   ├── PlayerManager.lua
│   ├── GameManager.lua
│   └── DataManager.lua
├── events/                   # RemoteEvent/RemoteFunction handlers
│   ├── PlayerEvents.lua
│   ├── GameEvents.lua
│   └── init.server.lua
└── services/                 # Service-like modules
    ├── ShopService.lua
    ├── InventoryService.lua
    └── init.server.lua
```

## Migration Steps

1. **Copy each ServerScript** to its own `.lua` file
2. **Organize ModuleScripts** into the `modules/` folder
3. **Group RemoteEvent handlers** in the `events/` folder
4. **Update require() paths** to match the new structure
5. **Test functionality** after syncing with Rojo

## Example Organization

- `init.server.lua` - Main server startup and player events
- `modules/` - Reusable server-side logic
- `events/` - Network communication handlers
- `services/` - Game systems and managers 