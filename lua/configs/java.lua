local map = vim.keymap.set

map("n", "<F5>", "<cmd>JavaRunnerRunMain<CR>", {
  desc = "Java: Run Application",
})

map("n", "<S-F5>", "<cmd>JavaRunnerStopMain<CR>", {
  desc = "Java: Stop Application",
})

map("n", "<leader>jl", "<cmd>JavaRunnerToggleLogs<CR>", {
  desc = "Java: Toggle Logs",
})

map("n", "<leader>jb", "<cmd>JavaBuildBuildWorkspace<CR>", {
  desc = "Java: Build Workspace",
})

map("n", "<leader>jt", "<cmd>JavaTestRunCurrentClass<CR>", {
  desc = "Java: Run Tests",
})

map("n", "<leader>jd", "<cmd>JavaTestDebugCurrentClass<CR>", {
  desc = "Java: Debug Tests",
})
