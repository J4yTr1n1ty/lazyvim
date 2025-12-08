# Remote Docker Debugging for C#/.NET in LazyVim

This document explains the setup for debugging C#/.NET applications running in Docker containers directly from LazyVim using DAP (Debug Adapter Protocol).

## Overview

This debugging setup enables you to:
- Set breakpoints in your local C# source files
- Attach to a .NET application running inside a Docker container
- Step through code, inspect variables, and use all standard debugging features
- Works seamlessly with hot reload (`dotnet watch`)

## Architecture

The debugging system consists of three main components:

1. **netcoredbg** - Runs as a DAP server inside the Docker container on port 4711
2. **nvim-dap** - DAP client in Neovim that connects to netcoredbg
3. **Path Mapping** - Ensures source code paths match between container and host

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│ Your Machine (Host)                                         │
│                                                             │
│  ┌──────────────┐         ┌──────────────────────────┐    │
│  │   LazyVim    │  DAP    │   Docker Container       │    │
│  │              │◄────────►│                          │    │
│  │  nvim-dap    │  :4711  │  netcoredbg (server)     │    │
│  │              │         │         │                 │    │
│  │  dap.lua     │         │         ▼                 │    │
│  │  config      │         │  .NET Application        │    │
│  │              │         │  (with PDB symbols)      │    │
│  └──────────────┘         └──────────────────────────┘    │
│         │                           │                      │
│         │                           │                      │
│   Source Files                 Source Files               │
│   /home/jay/...                /app/...                    │
│         │                           │                      │
│         └───────────────────────────┘                      │
│              Path Mapping:                                 │
│              /app/ → $CAMPLINK_HOST_PATH                   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### LazyVim Plugins

The following plugins must be installed (already configured in `lua/plugins/dap.lua`):
- `mfussenegger/nvim-dap` - DAP client
- `rcarriga/nvim-dap-ui` - UI for debugging
- `theHamsta/nvim-dap-virtual-text` - Show variable values inline
- `nvim-neotest/nvim-nio` - Async I/O library

### Docker Project Requirements

Your project needs:
1. Docker container with .NET SDK
2. `netcoredbg` installed in container
3. Port 4711 exposed for debugger
4. `.csproj` files configured with `PathMap` for proper symbol paths

## Setup Instructions

### For camplink-backend Project

The camplink-backend project is already fully configured. You just need to:

1. **Start the container:**
   ```bash
   docker-compose up -d
   ```

2. **Open Neovim from the project root:**
   ```bash
   cd /home/jay/Projects/work/it5solutions/camplink/camplink-backend
   nvim
   ```

3. **Start debugging** (see Usage Guide below)

### For Other .NET Docker Projects

To set up debugging for a different project:

#### 1. Install netcoredbg in Container

Add to your `docker-compose.yml` or `Dockerfile`:

```yaml
services:
  your_service:
    entrypoint:
      - bash
      - -c
      - |
        if [ ! -f /netcoredbg/netcoredbg ]; then
          mkdir -p /netcoredbg
          curl -sSL https://github.com/Samsung/netcoredbg/releases/download/3.1.0-1031/netcoredbg-linux-amd64.tar.gz | tar xzf - -C /netcoredbg --strip-components=1
        fi
        /netcoredbg/netcoredbg --server --interpreter=vscode --engineLogging=/tmp/netcoredbg.log &
        # Your app startup command here
    ports:
      - "4711:4711"  # Debugger port
    volumes:
      - netcoredbg-volume:/netcoredbg

volumes:
  netcoredbg-volume:
```

#### 2. Configure PathMap in .csproj Files

Add to each `.csproj` file you want to debug:

```xml
<PropertyGroup>
  <DebugType>portable</DebugType>
  <DebugSymbols>true</DebugSymbols>
  <PathMap>/app/=$([System.Environment]::GetEnvironmentVariable('YOUR_PROJECT_HOST_PATH'))/</PathMap>
</PropertyGroup>
```

#### 3. Set Environment Variable in docker-compose.yml

```yaml
environment:
  YOUR_PROJECT_HOST_PATH: ${YOUR_PROJECT_HOST_PATH:-/your/default/path}
```

#### 4. Configure nvim-dap

Create a new configuration in `lua/plugins/dap.lua` for your project (or modify the existing one).

## Configuration Options

### Environment Variables

#### `CAMPLINK_HOST_PATH` (for camplink-backend)

**Purpose:** Maps the container's `/app` directory to your local project directory.

**Default:** `/home/jay/Projects/work/it5solutions/camplink/camplink-backend`

**How to Override:**

1. **Shell export (session-only):**
   ```bash
   export CAMPLINK_HOST_PATH="/path/to/your/camplink-backend"
   ```

2. **In `.env` file (persistent):**
   ```bash
   # .env in camplink-backend root
   CAMPLINK_HOST_PATH=/path/to/your/camplink-backend
   ```

3. **In shell profile (permanent):**
   ```bash
   # In ~/.bashrc or ~/.zshrc
   export CAMPLINK_HOST_PATH="/path/to/your/camplink-backend"
   ```

**When You Need This:**
- Your project is not in the default location
- Working on a different machine with different path structure
- Multiple developers collaborating (each has different local paths)

### Path Mapping Explained

There are **two** path mappings that must work together:

#### 1. Build-time PathMap (.csproj)

```xml
<PathMap>/app/=$([System.Environment]::GetEnvironmentVariable('CAMPLINK_HOST_PATH'))/</PathMap>
```

- Runs during compilation
- Embeds source file paths into PDB (symbol) files
- Container builds at `/app` but PDB records `$CAMPLINK_HOST_PATH`

#### 2. Runtime sourceFileMap (dap.lua)

```lua
sourceFileMap = {
  ["/app"] = vim.env.CAMPLINK_HOST_PATH or vim.fn.getcwd(),
}
```

- Runs when attaching debugger
- Maps container paths to local paths
- Fallback: uses current working directory if env var not set

**Why Both Are Needed:**
- PathMap: Tells .NET debugger where source files are
- sourceFileMap: Tells nvim-dap where to find those files locally

## Usage Guide

### Starting a Debug Session

1. **Open a C# file in Neovim**
   ```bash
   nvim Camplink.WebApi/Controllers/SomeController.cs
   ```

2. **Set a breakpoint** on a line with code (not whitespace/comments)
   ```
   <leader>db
   ```
   You'll see a red dot appear in the gutter.

3. **Attach to the Docker container**
   ```
   <leader>da
   ```
   You'll see a notification with the PID it's attaching to.
   The DAP UI will open automatically when a breakpoint is hit.

4. **Trigger the breakpoint**
   - Hit the API endpoint (via curl, Postman, browser, etc.)
   - The debugger will pause execution at your breakpoint
   - Variables panel shows current values
   - Call stack shows execution path

5. **Step through code**
   - `<leader>di` - Step Into function
   - `<leader>do` - Step Over (next line)
   - `<leader>dO` - Step Out of function
   - `<leader>dc` - Continue execution

6. **Inspect variables**
   - Hover over variables to see values
   - Use the Variables panel in DAP UI
   - Use the REPL: `<leader>dr`

7. **End the session**
   ```
   <leader>dt
   ```

### Keybindings Reference

All debug commands use the `<leader>d` prefix:

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>db` | Toggle Breakpoint | Set/remove breakpoint on current line |
| `<leader>da` | Attach to Docker | Connect to netcoredbg in container |
| `<leader>dc` | Continue | Resume execution until next breakpoint |
| `<leader>di` | Step Into | Enter the function being called |
| `<leader>do` | Step Over | Execute current line, don't enter functions |
| `<leader>dO` | Step Out | Exit current function |
| `<leader>dr` | Open REPL | Evaluate expressions at runtime |
| `<leader>dt` | Terminate | Stop debugging session |
| `<leader>du` | Toggle UI | Show/hide DAP UI panels |
| `<leader>dl` | Run Last | Re-run previous debug configuration |

### Typical Workflow

```
1. Set breakpoints in your code
2. Start/restart your app (or it's already running with dotnet watch)
3. <leader>da to attach debugger
4. Trigger your code (hit API endpoint, run test, etc.)
5. Debugger pauses at breakpoint
6. Inspect, step through, investigate
7. <leader>dc to continue or <leader>dt to stop
```

## Troubleshooting

### Breakpoint Shows "R" (Rejected)

**Problem:** Breakpoint appears as "R" and is not hit.

**Causes:**
1. Path mismatch between PDB and local files
2. PDB symbols not loaded
3. Code not yet JIT-compiled

**Solutions:**
1. Verify `CAMPLINK_HOST_PATH` is set correctly:
   ```bash
   echo $CAMPLINK_HOST_PATH
   ```

2. Rebuild with clean PDB files:
   ```bash
   docker exec camplink_backend dotnet clean
   docker exec camplink_backend dotnet build
   docker-compose restart camplink_backend
   ```

3. Warm up the code path first:
   - Hit the endpoint once without breakpoint
   - Then set breakpoint and hit it again

4. Check netcoredbg logs:
   ```bash
   docker exec camplink_backend tail -50 /tmp/netcoredbg.log
   ```

### Cannot Find Process ID

**Problem:** "Could not find Camplink.WebApi process" error.

**Solutions:**
1. Verify container is running:
   ```bash
   docker ps | grep camplink_backend
   ```

2. Check if app is running in container:
   ```bash
   docker exec camplink_backend sh -c "ls /app/Camplink.WebApi/bin/Debug/net8.0/"
   ```

3. Restart container:
   ```bash
   docker-compose restart camplink_backend
   ```

### Debugger Not Connecting

**Problem:** Timeout or connection refused when attaching.

**Solutions:**
1. Verify port 4711 is exposed:
   ```bash
   docker ps --format "{{.Ports}}" | grep 4711
   ```

2. Check netcoredbg is running:
   ```bash
   docker exec camplink_backend sh -c "netstat -tlnp | grep 4711" 2>/dev/null || \
   docker exec camplink_backend sh -c "ss -tlnp | grep 4711"
   ```

3. Restart netcoredbg:
   ```bash
   docker-compose restart camplink_backend
   ```

### Wrong Source File Opened

**Problem:** Debugger stops but shows wrong file or location.

**Cause:** Path mapping mismatch.

**Solution:**
1. Ensure you opened nvim from the project root:
   ```bash
   cd /home/jay/Projects/work/it5solutions/camplink/camplink-backend
   nvim
   ```

2. Or set the environment variable explicitly:
   ```bash
   export CAMPLINK_HOST_PATH="$(pwd)"
   ```

### Debugging Slow or Laggy

**Problem:** Stepping through code is very slow.

**Solutions:**
1. Set `justMyCode: true` in dap.lua configuration (skip framework code)
2. Disable virtual text temporarily:
   ```vim
   :lua require("nvim-dap-virtual-text").toggle()
   ```

## Technical Details

### Why Only Camplink.* Projects?

PathMap is configured **only** for the core Camplink projects:
- Camplink.WebApi
- Camplink.Common
- Camplink.Business
- Camplink.Business.Impl
- Camplink.DataAccess
- Camplink.Realtime

**Not configured for:**
- C1ApiClient.* (third-party API client)
- AbaNinja.* (third-party API client)

**Reasoning:**
- These are external API client libraries
- Debugging is rarely needed in these components
- Keeps configuration simple and focused
- You can still step *through* these libraries, just can't set breakpoints in them

If you need to debug these libraries, add the same PathMap configuration to their `.csproj` files.

### How netcoredbg Works

netcoredbg is a debugger for .NET Core that implements the Debug Adapter Protocol (DAP):

1. Runs as a server inside the container (port 4711)
2. Listens for DAP commands from nvim-dap
3. Controls the .NET runtime debugger API
4. Reads PDB symbol files to map IL code to source lines
5. Sends back variable values, call stacks, etc.

### PDB Symbol Files

PDB (Program Database) files contain debug symbols:
- Map compiled IL code to source code lines
- Store variable names and types
- Include source file paths (this is where PathMap matters!)

With `PathMap`, the PDB contains host paths instead of container paths, so the debugger knows where to find source files on your local machine.

### Environment Variable Resolution Order

When attaching to the debugger, paths are resolved in this order:

1. `vim.env.CAMPLINK_HOST_PATH` - Environment variable
2. `vim.fn.getcwd()` - Current working directory
3. PDB embedded path (from PathMap during build)

For best results:
- Open nvim from project root, OR
- Set `CAMPLINK_HOST_PATH` environment variable

## Additional Resources

- [nvim-dap Documentation](https://github.com/mfussenegger/nvim-dap)
- [netcoredbg GitHub](https://github.com/Samsung/netcoredbg)
- [DAP Specification](https://microsoft.github.io/debug-adapter-protocol/)
- [LazyVim Docs](https://www.lazyvim.org/)

## Notes

- This setup was created and tested with .NET 8.0
- netcoredbg version 3.1.0-1031
- Works on Linux (tested on Arch Linux)
- Should work on macOS with Docker Desktop
- Windows may require additional configuration (paths, line endings)
