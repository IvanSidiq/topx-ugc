# My Roblox Game

A Roblox game project set up for external development with Rojo and Cursor.

## 🚀 Getting Started

### Prerequisites
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/) (already installed)
- [Selene](https://github.com/Kampfkarren/selene) (already installed)
- [StyLua](https://github.com/JohnnyMorganz/StyLua) (already installed)

### Development Workflow

1. **Start Rojo Server**
   ```bash
   rojo serve
   ```

2. **Connect to Roblox Studio**
   - Open Roblox Studio
   - Create a new place or open an existing one
   - Install the Rojo plugin if you haven't already
   - Click "Connect" in the Rojo plugin panel
   - The default address should be `localhost:34872`

3. **Start Coding**
   - Edit Lua files in the `src/` directory using Cursor
   - Changes will automatically sync to Roblox Studio
   - Test your game in Studio

4. **Code Formatting**
   ```bash
   stylua src/
   ```

5. **Linting**
   ```bash
   selene src/
   ```

## 📁 Project Structure

```
├── src/
│   ├── client/           # Client-side scripts
│   │   └── init.client.lua
│   ├── server/           # Server-side scripts
│   │   └── init.server.lua
│   └── shared/           # Shared modules
│       └── GameConfig.lua
├── default.project.json  # Rojo project configuration
├── selene.toml          # Linting configuration
├── stylua.toml          # Formatting configuration
└── .vscode/settings.json # Editor settings
```

## 🛠️ Available Commands

- `rojo serve` - Start the Rojo development server
- `rojo build` - Build the project to a `.rbxl` file
- `selene src/` - Lint all Lua files
- `stylua src/` - Format all Lua files

## 📝 Tips

- Keep server logic in `src/server/`
- Keep client logic in `src/client/`
- Put shared modules in `src/shared/`
- Use the `GameConfig` module for shared configuration
- Enable auto-format on save in Cursor for consistent code style

## 🔗 Useful Links

- [Rojo Documentation](https://rojo.space/docs/)
- [Roblox Developer Hub](https://developer.roblox.com/)
- [Luau Documentation](https://luau-lang.org/) 