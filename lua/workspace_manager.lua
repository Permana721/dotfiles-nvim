local M = {}

local workspace_file = vim.fn.stdpath("data") .. "/last_workspace.json"

function M.get_file_path()
  return workspace_file
end

function M.find_project_root(path)
  path = path or vim.fn.getcwd()
  if vim.fn.filereadable(path) == 1 then
    path = vim.fn.fnamemodify(path, ":p:h")
  elseif vim.fn.isdirectory(path) == 1 then
    path = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
  end
  local root = vim.fs.root(path, { ".git", "pom.xml", "package.json", "build.gradle", "go.mod", "Cargo.toml" })
  return root or path
end

function M.get_last_workspace()
  if vim.fn.filereadable(workspace_file) == 1 then
    local lines = vim.fn.readfile(workspace_file)
    if lines and #lines > 0 then
      local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
      if ok and decoded and decoded.last_project_path then
        local p = vim.fn.fnamemodify(decoded.last_project_path, ":p"):gsub("/+$", "")
        if vim.fn.isdirectory(p) == 1 then
          return p
        end
      end
    end
  end
  return nil
end

function M.save_workspace(path)
  if not path or path == "" then
    return false
  end
  local real_path = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
  if vim.fn.isdirectory(real_path) ~= 1 then
    return false
  end
  local data = {
    last_project_path = real_path,
    updated_at = os.time(),
  }
  local ok, encoded = pcall(vim.json.encode, data)
  if ok and encoded then
    pcall(vim.fn.writefile, { encoded }, workspace_file)
    return true
  end
  return false
end

function M.switch_project(target_dir)
  if not target_dir or target_dir == "" then
    return
  end
  target_dir = vim.fn.expand(target_dir)
  if vim.fn.isdirectory(target_dir) ~= 1 then
    vim.notify("Directory does not exist: " .. target_dir, vim.log.levels.WARN)
    return
  end
  target_dir = vim.fn.fnamemodify(target_dir, ":p"):gsub("/+$", "")
  pcall(vim.fn.chdir, target_dir)
  M.save_workspace(target_dir)

  local ok_tree, tree_api = pcall(require, "nvim-tree.api")
  if ok_tree then
    pcall(tree_api.tree.change_root, target_dir)
    pcall(tree_api.tree.open)
  end

  vim.cmd("redrawtabline")
  vim.cmd("redraw")
  vim.notify("Workspace switched to: " .. target_dir, vim.log.levels.INFO)
end

function M.fallback_telescope_folder()
  local ok_builtin, builtin = pcall(require, "telescope.builtin")
  if ok_builtin then
    local has_fd = vim.fn.executable("fd") == 1
    local cmd = has_fd and { "fd", "--type", "d", "--hidden", "--exclude", ".git", "--max-depth", "4" }
      or { "find", ".", "-maxdepth", "4", "-type", "d" }
    builtin.find_files({
      prompt_title = " Select Project Folder ",
      find_command = cmd,
      attach_mappings = function(prompt_bufnr, map)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.value then
            local full_path = vim.fn.fnamemodify(selection.value, ":p")
            M.switch_project(full_path)
          end
        end)
        return true
      end,
    })
  else
    vim.ui.input({
      prompt = " Enter Folder Path: ",
      default = vim.fn.getcwd() .. "/",
      completion = "dir",
    }, function(input)
      if input and vim.trim(input) ~= "" then
        M.switch_project(input)
      end
    end)
  end
end

function M.open_folder_dialog()
  local home = vim.fn.expand("$HOME")
  if vim.fn.executable("kdialog") == 1 then
    vim.system({ "kdialog", "--getexistingdirectory", home }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 or not obj.stdout then
          return
        end
        local path = vim.trim(obj.stdout)
        if path == "" then
          return
        end
        if vim.fn.isdirectory(path) == 1 then
          M.switch_project(path)
        else
          vim.notify("Selected path is not a valid directory: " .. path, vim.log.levels.WARN)
        end
      end)
    end)
  elseif vim.fn.executable("zenity") == 1 then
    vim.system({ "zenity", "--file-selection", "--directory", "--filename=" .. home .. "/" }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 or not obj.stdout then
          return
        end
        local path = vim.trim(obj.stdout)
        if path == "" then
          return
        end
        if vim.fn.isdirectory(path) == 1 then
          M.switch_project(path)
        else
          vim.notify("Selected path is not a valid directory: " .. path, vim.log.levels.WARN)
        end
      end)
    end)
  else
    M.fallback_telescope_folder()
  end
end

M.prompt_open_project = M.open_folder_dialog

function M.open_file_dialog()
  local home = vim.fn.expand("$HOME")
  if vim.fn.executable("kdialog") == 1 then
    vim.system({ "kdialog", "--getopenfilename", home }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 or not obj.stdout then
          return
        end
        local selected_file = vim.trim(obj.stdout)
        if selected_file ~= "" and vim.fn.filereadable(selected_file) == 1 then
          vim.cmd("edit " .. vim.fn.fnameescape(selected_file))
        end
      end)
    end)
  elseif vim.fn.executable("zenity") == 1 then
    vim.system({ "zenity", "--file-selection", "--filename=" .. home .. "/" }, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code ~= 0 or not obj.stdout then
          return
        end
        local selected_file = vim.trim(obj.stdout)
        if selected_file ~= "" and vim.fn.filereadable(selected_file) == 1 then
          vim.cmd("edit " .. vim.fn.fnameescape(selected_file))
        end
      end)
    end)
  else
    local ok_builtin, builtin = pcall(require, "telescope.builtin")
    if ok_builtin then
      builtin.find_files({ prompt_title = " Open File " })
    else
      vim.ui.input({
        prompt = " Open File: ",
        default = vim.fn.getcwd() .. "/",
        completion = "file",
      }, function(input)
        if input and vim.trim(input) ~= "" and vim.fn.filereadable(vim.trim(input)) == 1 then
          vim.cmd("edit " .. vim.fn.fnameescape(vim.trim(input)))
        end
      end)
    end
  end
end

function M.init_early()

  if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
    local saved = M.get_last_workspace()
    local home = vim.fn.expand("$HOME"):gsub("/+$", "")
    if saved and saved ~= home and vim.fn.isdirectory(saved) == 1 then
      pcall(vim.fn.chdir, saved)
    end
  end
end

function M.setup()
  M.init_early()

  vim.api.nvim_create_autocmd("VimEnter", {
    nested = true,
    callback = function(data)
      local argc = vim.fn.argc()
      local home = vim.fn.expand("$HOME"):gsub("/+$", "")

      if argc == 0 and not vim.g.started_with_stdin then
        local saved = M.get_last_workspace()
        if saved and saved ~= home and vim.fn.isdirectory(saved) == 1 then
          pcall(vim.fn.chdir, saved)
          local ok_tree, tree_api = pcall(require, "nvim-tree.api")
          if ok_tree then
            pcall(tree_api.tree.open, { path = saved })
          end
          local ok_p, persistence = pcall(require, "persistence")
          if ok_p then
            pcall(persistence.load)
          end
        else
          local ok_tree, tree_api = pcall(require, "nvim-tree.api")
          if ok_tree then
            pcall(tree_api.tree.open)
          end
        end
      else
        local target = data.file ~= "" and data.file or vim.fn.argv(0)
        if target and target ~= "" then
          local dir = nil
          if vim.fn.isdirectory(target) == 1 then
            dir = target
          elseif vim.fn.filereadable(target) == 1 then
            dir = M.find_project_root(target)
          end

          if dir then
            local real_dir = vim.fn.fnamemodify(dir, ":p"):gsub("/+$", "")
            if real_dir ~= home and vim.fn.isdirectory(real_dir) == 1 then
              M.save_workspace(real_dir)
              pcall(vim.fn.chdir, real_dir)
              local ok_tree, tree_api = pcall(require, "nvim-tree.api")
              if ok_tree then
                pcall(tree_api.tree.change_root, real_dir)
              end
            end
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local cwd = vim.fn.getcwd()
      local home = vim.fn.expand("$HOME"):gsub("/+$", "")
      if cwd ~= home then
        local root = M.find_project_root(cwd)
        if root and root ~= home then
          M.save_workspace(root)
        end
      end
    end,
  })
end

return M
