return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "nvim-neotest/nvim-nio",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    -- Setup dap-ui
    dapui.setup()

    -- Setup virtual text
    require("nvim-dap-virtual-text").setup()

    -- netcoredbg adapter for remote Docker debugging via TCP
    dap.adapters.coreclr = {
      type = "server",
      host = "127.0.0.1",
      port = 4711,
    }

    dap.configurations.cs = {
      {
        type = "coreclr",
        name = "Attach to Docker Container",
        request = "attach",
        processId = function()
          -- Find the dotnet process in the container using /proc
          local cmd = [[docker exec camplink_backend sh -c "for pid in \$(ls /proc | grep '^[0-9]*\$'); do cmdline=\$(cat /proc/\$pid/cmdline 2>/dev/null | tr '\\0' ' '); if echo \"\$cmdline\" | grep -q 'Camplink.WebApi/bin/Debug'; then echo \$pid; break; fi; done"]]
          local handle = io.popen(cmd)
          local result = handle:read("*a")
          handle:close()
          local pid = result:gsub("%s+", "")
          if pid == "" then
            vim.notify("Could not find Camplink.WebApi process in container", vim.log.levels.ERROR)
            return nil
          end
          vim.notify("Attaching to PID: " .. pid, vim.log.levels.INFO)
          return tonumber(pid)
        end,
        justMyCode = false,
        -- Map container paths to local paths
        sourceFileMap = {
          ["/app"] = vim.env.CAMPLINK_HOST_PATH or vim.fn.getcwd(),
        },
      },
    }

    -- Auto-open/close dap-ui
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end
  end,
  keys = {
    -- Debugging keymaps
    {
      "<leader>db",
      function()
        require("dap").toggle_breakpoint()
      end,
      desc = "Toggle Breakpoint",
    },
    {
      "<leader>dc",
      function()
        require("dap").continue()
      end,
      desc = "Continue",
    },
    {
      "<leader>da",
      function()
        require("dap").continue()
      end,
      desc = "Attach to Docker",
    },
    {
      "<leader>di",
      function()
        require("dap").step_into()
      end,
      desc = "Step Into",
    },
    {
      "<leader>do",
      function()
        require("dap").step_over()
      end,
      desc = "Step Over",
    },
    {
      "<leader>dO",
      function()
        require("dap").step_out()
      end,
      desc = "Step Out",
    },
    {
      "<leader>dr",
      function()
        require("dap").repl.open()
      end,
      desc = "Open REPL",
    },
    {
      "<leader>dl",
      function()
        require("dap").run_last()
      end,
      desc = "Run Last",
    },
    {
      "<leader>dt",
      function()
        require("dap").terminate()
      end,
      desc = "Terminate",
    },
    {
      "<leader>du",
      function()
        require("dapui").toggle()
      end,
      desc = "Toggle UI",
    },
  },
}
