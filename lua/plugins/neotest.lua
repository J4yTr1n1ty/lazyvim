return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "Issafalcon/neotest-dotnet",
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      table.insert(
        opts.adapters,
        require("neotest-dotnet")({
          discovery_root = "solution",
          dap = { justMyCode = false },
          dotnet_additional_args = { "--no-restore" },

          -- Enhanced test discovery settings
          custom_test_project_patterns = { "Test", "Tests", "Testing", ".Tests", ".Test", "Spec", ".Spec" },
          custom_test_file_patterns = { "Test", "Tests", ".Test", ".Tests", "Spec", ".Spec" },

          -- Enable solution-wide test discovery
          allow_full_solution_discovery = true,
          -- Explicitly tell the adapter to discover the test tree on startup
          discover_on_start = true,
        })
      )
    end,
  },
}
