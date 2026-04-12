---
description: "Project instructions for Spacial Factory Game - Roblox development with Rojo and Wally"
---

# Spacial Factory Game - Copilot Instructions

## Project Overview

**Spacial Factory Game** is a Roblox game built with modern Lua/Luau tooling. The project uses:

- **Rojo**: File synchronization system for Roblox development (enables local editing)
- **Wally**: Package manager for Lua dependencies
- **Aftman**: Toolchain manager for managing Rojo and Wally versions
- **Selene**: Lua linter for code quality
- **Luau**: Typed Lua dialect used for script development

## Project Structure

```
src/
├── client/          # Client-side scripts (StarterPlayer.StarterCharacterScripts)
├── server/          # Server-side scripts (ServerScriptService)
└── shared/          # Shared modules (ReplicatedStorage)
Packages/            # Wally dependencies (via ReplicatedStorage.Packages)
default.project.json # Rojo project configuration
aftman.toml         # Aftman toolchain manifest
wally.toml          # Wally dependencies manifest
```

## Development Setup & Conventions

### Getting Started

1. Install tools via Aftman: `aftman install`
2. Install Lua packages via Wally: `wally install`
3. Start Rojo server: `rojo serve` (connects local files to Roblox Studio)

### File Organization

- **Client scripts**: Use `.client.luau` extension, placed in `src/client/`
- **Server scripts**: Use `.server.luau` extension, placed in `src/server/`
- **Shared modules**: Use `.luau` extension, placed in `src/shared/`
- **Dependencies**: Manage via `wally.toml`, auto-synced to `ReplicatedStorage.Packages`
- **React UI**: Keep UI entry files in `src/client/UI/`, client-only components in `src/client/components/`, and reusable hooks/helpers in `src/shared/`

### Code Style

- Follow **Selene** linting rules (see `selene.toml`)
- Use **Luau typing** where applicable for better type safety
- Module structure: return a single table or function from modules
- Signal/event handling: Use the `signal` package from `ReplicatedStorage.Packages.signal`
- For new interface work, prefer **React Lua** (`react` + `react-roblox`) instead of imperative ScreenGui assembly

### React UI Conventions

- Mount the client UI from `src/client/init.client.luau` with `ReactRoblox.createRoot()` into `PlayerGui`.
- Prefer functional components and hooks over class components for new UI code.
- Require packages from `ReplicatedStorage.Packages` using the Wally shims: `react`, `react-roblox`, and other installed modules.
- Keep root screens and app composition in `src/client/UI/` and leaf widgets or HUD elements in `src/client/components/`.
- Shared hooks that connect Roblox signals or replicated state to UI belong in `src/shared/hooks/`.
- When UI needs game state updates, bridge Roblox events/signals into React state with hooks instead of manually mutating GuiObjects.

## Testing Workflow

🚀 **IMPORTANT**: When performing testing or development:

- The **Rojo serve** is already running and open in the user's environment
- **Do NOT start a new Rojo server** - files are already being synchronized
- All code changes in `src/` will automatically sync to Roblox Studio
- Simply edit files locally; changes appear in Studio immediately

### Testing Best Practices

1. Keep an open Roblox Studio window with the game place
2. Code in your editor; Rojo automatically syncs changes
3. Test in Studio's play mode (Studio play-testing handles all sync)
4. Check Rojo status in terminal if sync issues occur

### Roblox Studio MCP Usage

- When a test or verification step requires moving the player character to a location in the world, use `mcp_roblox_studio_character_navigation` instead of simulating manual movement.
- Prefer `instance_path` when the destination is a known object in the hierarchy, such as `game.Workspace.SpawnLocation`.
- Use explicit `x`, `y`, and `z` coordinates only when there is no stable instance path to target.
- Before using Roblox Studio MCP tools to inspect or modify the running game, confirm the correct Studio instance is active.
- Use character navigation mainly for reproducible testing flows, such as reaching machines, triggers, checkpoints, or interaction areas quickly.

## Common Tasks

### Adding a New Package Dependency

1. Add dependency to `wally.toml` under `[dependencies]`
2. Run `wally install`
3. Import in your script: `local MyPackage = require(game.ReplicatedStorage.Packages.MyPackage)`

### Creating a New Script

1. Create `.luau` file in appropriate folder (`src/client`, `src/server`, `src/shared`)
2. For client: Use `.client.luau` extension
3. For server: Use `.server.luau` extension
4. Rojo automatically syncs to Studio

### Debugging

- Check `sourcemap.json` for source mapping information
- Use Studio's Output window to view print() statements
- Use Studio's Script Analysis for type errors

## Tools Reference

| Tool   | Command                         | Purpose                                                     |
| ------ | ------------------------------- | ----------------------------------------------------------- |
| Rojo   | `rojo serve`                    | Sync local files to Roblox Studio (stay running during dev) |
| Rojo   | `rojo build --output game.rbxl` | Generate .rbxl file for deployment                          |
| Wally  | `wally install`                 | Install dependencies from `wally.toml`                      |
| Selene | `selene src/`                   | Lint all Lua files in src/                                  |
| Aftman | `aftman install`                | Install all tools listed in `aftman.toml`                   |

## Documentation

- [Rojo Documentation](https://rojo.space/)
- [Wally Package Repository](https://wally.run/)
- [Luau Documentation](https://luau-lang.org/)
- [Roblox API Reference](https://developer.roblox.com/en-us/api-reference)
