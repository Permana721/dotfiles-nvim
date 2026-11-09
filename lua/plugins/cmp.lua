return {
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require("cmp")

      cmp.register_source(
        "java_var",
        require("var_suggest")
      )

      cmp.register_source(
        "sql_db",
        require("ide_db").cmp_source
      )

      opts.sources = opts.sources or {}

      local java_var_exists = false
      local sql_db_exists = false

      for _, source in ipairs(opts.sources) do
        if source.name == "java_var" then
          java_var_exists = true
        elseif source.name == "sql_db" then
          sql_db_exists = true
        end
      end

      if not java_var_exists then
        table.insert(opts.sources, {
          name = "java_var",
          priority = 900,
          keyword_length = 0,
          trigger_characters = { " " },
        })
      end

      if not sql_db_exists then
        table.insert(opts.sources, {
          name = "sql_db",
          priority = 950,
          keyword_length = 0,
          trigger_characters = { " ", ".", "(", "," },
        })
      end

      opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
        ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
        ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
      })

      local cmp_ranking = require("configs.cmp")
      opts = cmp_ranking.setup(opts)

      return opts
    end,
  },
}
