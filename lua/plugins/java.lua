return {
  {
    "nvim-java/nvim-java",
    ft = "java",
    config = function()
      require("java").setup()

      local runtimes = {}
      local jdk21_path = nil
      for _, candidate in ipairs({
        "/usr/lib/jvm/java-21-openjdk",
        vim.fn.expand("~/.jdks/ms-21.0.12.1"),
        "/usr/lib/jvm/default-runtime",
        "/usr/lib/jvm/default",
      }) do
        if vim.fn.isdirectory(candidate) == 1 then
          jdk21_path = candidate
          break
        end
      end

      if jdk21_path then
        table.insert(runtimes, {
          name = "JavaSE-21",
          path = jdk21_path,
          default = true,
        })
      end

      for _, candidate in ipairs({
        "/usr/lib/jvm/java-17-openjdk",
        vim.fn.expand("~/.jdks/openjdk-17"),
      }) do
        if vim.fn.isdirectory(candidate) == 1 then
          table.insert(runtimes, {
            name = "JavaSE-17",
            path = candidate,
          })
          break
        end
      end

      vim.lsp.config("jdtls", {
        root_markers = {
          { "pom.xml", "mvnw", "gradlew", "build.gradle", "build.gradle.kts" },
          { ".git" },
        },
        settings = {
          java = {
            configuration = {
              runtimes = runtimes,
            },
          },
        },
      })

      vim.lsp.enable("jdtls")
    end,
  },
}
