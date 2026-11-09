return {
  {
    "stevearc/conform.nvim",

    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true,
        callback = function()
          if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
            require("persistence").load()
          end
        end,
      })
    end,
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },
  {
  "3rd/image.nvim",
  event = "VeryLazy",
  opts = {
    backend = "kitty",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        filetypes = { "markdown", "vimwiki" },
      },
      html = { enabled = false },
      css = { enabled = false },
    },
    max_width = 100,
    max_height = 25,
    max_width_window_percentage = math.huge,
    max_height_window_percentage = math.huge,
    window_overlap_clear_enabled = false,
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = false,
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
  },
},
{
    "nvim-tree/nvim-tree.lua",
    opts = {
      renderer = {
        highlight_git = "name",
        icons = {
          git_placement = "after",
          glyphs = {
            git = {
              unstaged = " M ",
              staged = " S ",
              untracked = " U ",
            },
          },
        },
      },
    },
  },
{
    "andweeb/presence.nvim",
    lazy = false,
    opts = {
      auto_update                = true,
      neovim_image_text          = "The One True Text Editor",
      main_image                 = "neovim",
      client_id                  = "793271441293967371",
      log_level                  = nil,
      debounce_timeout           = 10,
      enable_line_number         = false,
      blacklist                  = {},
      buttons                    = true,
      file_assets                = {},
      show_time                  = true,

      reset_time_on_buffer_leave = false,

      editing_text               = "Editing %s",
      file_explorer_text         = "Browsing %s",
      git_commit_text            = "Committing changes",
      plugin_manager_text        = "Managing plugins",
      reading_text               = "Reading %s",
      workspace_text             = "Working on %s",
      line_number_text           = "Line %s out of %s",

      buttons = {
        { label = "View Project", url = "https://github.com/permana-sd/MGS" },
      },
    },
  },
{
    "wakatime/vim-wakatime",
    lazy = false,
},

}
