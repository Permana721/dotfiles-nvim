# Neovim IDE — Keyboard Shortcuts & Keymaps Reference

An exhaustive, professional documentation of all keyboard shortcuts, mouse triggers, header menu actions, and commands in this Neovim configuration (`~/.config/nvim`).

---

## Table of Contents
1. [Top Header & Menu Bar Controls (Tier 1 & Tier 2)](#1-top-header--menu-bar-controls-tier-1--tier-2)
2. [Explorer & File Management (NvimTree)](#2-explorer--file-management-nvimtree)
3. [File, Buffer & Window Management](#3-file-buffer--window-management)
4. [Code Editing & Universal Commenting](#4-code-editing--universal-commenting)
5. [Multi-Language Runner & Stacked Terminal (`ide_term.lua` & `run_history.lua`)](#5-multi-language-runner--stacked-terminal-ide_termlua--run_historylua)
6. [Antigravity AI Assistant Sidebar (`ide_ai_sidebar.lua`)](#6-antigravity-ai-assistant-sidebar-ide_ai_sidebarlua)
7. [Database Tooling (`ide_db.lua`)](#7-database-tooling-ide_dblua)
8. [LSP, Navigation & Diagnostics](#8-lsp-navigation--diagnostics)
9. [Search & Project Navigation (Telescope)](#9-search--project-navigation-telescope)
10. [Essential Vim Motions & Modes](#10-essential-vim-motions--modes)

---

## 1. Top Header & Menu Bar Controls (Tier 1 & Tier 2)

The editor interface features a dual-tier top header inspired by VS Code and JetBrains IDEs.

### Tier 1: Global Menu Bar & Title Header (Screen Row 1)
| UI Element | Trigger / Shortcut | Mode | Description |
| :--- | :--- | :--- | :--- |
| **File Menu** | Click `File` or `<M-f>` | Normal, Insert, Visual | Open File dropdown menu (New File, Open File, Open Folder, Save, Close, Exit) |
| **Edit Menu** | Click `Edit` or `<M-e>` | Normal, Insert, Visual | Open Edit dropdown menu (Find in File, Find across Project, Rename, Code Action) |
| **Run Menu** | Click `Run` or `<M-r>` | Normal, Insert, Visual | Open Run dropdown menu (Configurations & History, Run Program, Stop, Debug) |
| **Terminal Menu** | Click `Terminal`, `<M-T>`, or `<leader>mt` | Normal, Insert, Visual | Open Terminal dropdown menu (Toggle Stacked Terminal, New Tab, Toggle AI Sidebar) |
| **Help Menu** | Click `Help` or `<M-h>` | Normal, Insert, Visual | Open Help dropdown menu with `󰌌 Keyboard Shortcuts & Keymaps` |
| **Global Search** | Click `[ 󰘳 <Project> /  Search files... (^P) ]` or `<C-p>` | Normal, Insert, Visual | Open VS Code-style global file search (Telescope Quick Open) |
| **Run Pill** | Click `[ 󰐊 <Config> ▾ ]` | Normal, Insert, Visual | Open IntelliJ-style Run Configurations & History picker dropdown |
| **Run Button** | Click `[ 󰐊 ]` (or `[ 󰑐 ]` when active) | Normal, Insert, Visual | Execute active run configuration or focused runnable file |
| **Stop Button** | Click `[ ⏹ ]` | Normal, Insert, Visual | Terminate running runner process immediately |
| **AI Sidebar** | Click `󰚩 AI` button | Normal, Insert, Visual | Toggle Antigravity AI CLI assistant sidebar |
| **Theme Toggle** | Click `` icon | Normal, Insert, Visual | Cycle through installed base46 UI color themes |
| **Close All** | Click `󰅖` icon | Normal, Insert, Visual | Close all open editor buffer tabs |

### Tier 2: Explorer & Bufferline Winbar (Screen Row 2)
| Component | UI Element / Trigger | Description |
| :--- | :--- | :--- |
| **NvimTree Header** | `  EXPLORER` | Header aligned with NvimTree width containing quick action icons |
| **New File Icon** | Click `` icon | Trigger NvimTree interactive file creation prompt |
| **New Folder Icon** | Click `` icon | Trigger interactive folder creation dialog with directory auto-completion |
| **Refresh Tree Icon** | Click `` icon | Reload directory tree and synchronize with filesystem changes |
| **Collapse All Icon**| Click `` icon | Collapse all expanded subdirectories in the tree view |
| **Editor Buffer Tabs**| Click buffer tab | Switch active window focus to clicked buffer tab |
| **Tab Close Button** | Click `󰅖` on buffer tab | Close clicked buffer tab without disrupting window splits |

---

## 2. Explorer & File Management (NvimTree)

The file tree explorer sidebar opens on the left with automatic session isolation and non-red Git status indicators.

| Shortcut / Trigger | Context / Mode | Description |
| :--- | :--- | :--- |
| `<C-n>` | Normal | Toggle NvimTree file explorer sidebar |
| `<leader>e` | Normal | Focus cursor into NvimTree window |
| `a` | Normal (Tree) | Create a new file (or append `/` to create a new folder) |
| Click `` icon | Winbar Click | Create a new file under focused node |
| Click `` icon | Winbar Click | Create a new folder under focused node |
| `r` | Normal (Tree) | Rename focused file or directory |
| `d` | Normal (Tree) | Delete focused file or directory (prompts for confirmation) |
| `c` | Normal (Tree) | Copy focused file or directory to clipboard buffer |
| `x` | Normal (Tree) | Cut / move focused file or directory |
| `p` | Normal (Tree) | Paste copied or cut file/directory into selected directory |
| `y` | Normal (Tree) | Copy relative filename to clipboard |
| `Y` | Normal (Tree) | Copy relative path to clipboard |
| `gy` | Normal (Tree) | Copy absolute path to clipboard |
| `R` or Click `` | Normal (Tree) | Refresh explorer view and synchronize filesystem state |
| `W` or Click `` | Normal (Tree) | Collapse all open directory folders |
| `E` | Normal (Tree) | Expand all directory folders recursively |
| `<CR>` or `o` | Normal (Tree) | Open selected file in editor or toggle folder expansion |
| `<2-LeftMouse>` | Normal (Tree) | Double click to open file or toggle folder |
| `P` | Normal (Tree) | Jump to parent directory |
| `H` | Normal (Tree) | Toggle visibility of hidden files / dotfiles |
| `I` | Normal (Tree) | Toggle visibility of git-ignored files |
| `q` | Normal (Tree) | Close NvimTree explorer window |
| `g?` | Normal (Tree) | Open NvimTree built-in keymap help dialog |

---

## 3. File, Buffer & Window Management

| Shortcut / Command | Mode | Description |
| :--- | :--- | :--- |
| `<C-s>` | Normal, Insert, Visual | Save current buffer to disk (`:w`) |
| *Auto-Save* | Automatic | Automatically writes modified buffers on `InsertLeave`, `TextChanged`, `BufLeave` |
| `<C-q>` | Normal | Close current window split (`:q`) |
| `<leader>x` | Normal | Close active buffer tab (`nvchad.tabufline.close_buffer`) |
| `<Tab>` | Normal | Switch to next open buffer tab (`tabufline.next`) |
| `<S-Tab>` | Normal | Switch to previous open buffer tab (`tabufline.prev`) |
| `<leader>b` | Normal | Open clean new empty buffer (`:enew`) |
| `<C-h>` | Normal | Move cursor to window split on the left |
| `<C-j>` | Normal | Move cursor to window split below |
| `<C-k>` | Normal | Move cursor to window split above |
| `<C-l>` | Normal | Move cursor to window split on the right |
| `<leader>v` | Normal | Create vertical split with integrated terminal (`nvchad.term.new`) |
| `<leader>h` | Normal | Create horizontal split with integrated terminal (`nvchad.term.new`) |
| File -> Open Folder... | Top Menu / `<M-f>` | Open native KDE Dolphin folder picker (`kdialog` / `zenity`) to switch workspace |
| File -> Open File... | Top Menu / `<M-f>` | Open native KDE Dolphin file picker (`kdialog` / `zenity`) to edit file |
| `<leader>qs` | Normal | Restore previous workspace session (`persistence.nvim`) |
| `<leader>ql` | Normal | Restore last recorded session (`persistence.nvim`) |
| `<leader>qd` | Normal | Disable session saving for current editing session |
| `<leader>n` | Normal | Toggle line numbers display (`:set nu!`) |
| `<leader>rn` | Normal | Toggle relative line numbers display (`:set rnu!`) |

---

## 4. Code Editing & Universal Commenting

### Universal Commenting
A universal comment engine automatically injects the appropriate syntax comment delimiter based on buffer filetype (`//` for Java/C/C++/JS/TS/Rust/Go, `--` for SQL/Lua, `#` for Shell/Python, `<!-- -->` for HTML/XML).

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| `<C-/>` or `<C-_>` | Normal | Toggle line comment on current line (or `[count]` lines) without moving cursor |
| `<C-/>` or `<C-_>` | Visual | Toggle comment block on highlighted visual selection |
| `<C-/>` or `<C-_>` | Insert | Toggle comment on current line and preserve cursor column offset |
| `<leader>/` | Normal, Visual | Classic NvChad comment toggle (`gcc` in Normal, `gc` in Visual) |

### Intelligent Auto-Completion (`nvim-cmp`)
Completion results are sorted via a high-performance ranking engine prioritizing **Most Frequently Used (MFU)** entries, **Most Recently Used (MRU)** items, and **Project / Workspace Locality** (project packages like `mana.game.shop.*` over obscure internal libraries like `javax.swing.*` or `com.sun.*`).

| Shortcut / Trigger | Mode | Description |
| :--- | :--- | :--- |
| `<Down>` / `<Up>` | Insert | Select next / previous item in completion menu |
| `<Tab>` / `<S-Tab>` | Insert | Navigate forward / backward through completion candidates |
| `<ScrollWheelDown>` / `<ScrollWheelUp>` | Mouse | Smoothly scroll through completion candidates |
| `<LeftMouse>` on item | Mouse | Click directly on completion candidate to select and confirm |
| `<CR>` | Insert | Confirm and insert selected completion candidate |

### Smart Variable Name Suggestion (`var_suggest.lua`)
| Shortcut / Trigger | Mode | Description |
| :--- | :--- | :--- |
| Automatic on Type | Insert | Type a class name in Java followed by Space (e.g. `ItemShopView `) |
| `<C-Space>` | Insert | Manually trigger smart variable name generator popup |
| *Naming Styles Generated* | Candidate list | camelCase (`itemShopView`), PascalCase (`ItemShopView`), snake_case (`item_shop_view`), abbreviation (`isv`), short camelCase (`itemView`), object suffix (`itemShopViewObj`) |

### Clipboard, Undo & Line Manipulation
| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| `<C-z>` | Normal, Insert, Visual | Undo last action (`u` in Normal, `<C-o>u` in Insert, `<Esc>u` in Visual) |
| `<C-y>` | Normal, Insert | Redo last undone action (`<C-r>` in Normal, `<C-o><C-r>` in Insert) |
| `<C-a>` | Normal, Insert | Select all text in active buffer (`ggVG`) |
| `<C-c>` | Visual | Copy highlighted selection to system clipboard (`"+y`) |
| `<C-c>` | Normal | Copy current line to system clipboard (`"+yy`) |
| `<C-x>` | Visual | Cut highlighted selection to system clipboard (`"+d`) |
| `<C-x>` | Normal, Insert | Cut current line to system clipboard (`"+dd`) |
| `<C-v>` | Normal, Insert | Paste from system clipboard (`"+p` in Normal, `<C-r>+` in Insert) |
| `<BS>` / `<Del>` | Visual | Delete selected text into blackhole register without overwriting clipboard (`"_d`) |
| `<C-BS>` / `<C-H>` | Insert | Delete preceding word in insert mode (`<C-w>`) |
| `<M-j>` | Normal, Insert, Visual | Move current line or visual selection down by one line |
| `<M-k>` | Normal, Insert, Visual | Move current line or visual selection up by one line |
| `<leader>fm` | Normal, Visual | Format active file using Conform (`stylua`, LSP fallback) |

---

## 5. Multi-Language Runner & Stacked Terminal (`ide_term.lua` & `run_history.lua`)

A unified execution framework capable of running project configurations and single files across languages with stacked terminal multiplexing.

### Multi-Language Execution Support
| Language | Execution Engine & Behavior |
| :--- | :--- |
| **Java** | High-performance runner script with cached Maven dependency classpath; automatically detects `main` methods and `@Test` classes; manages project root |
| **SQL** | Executes query directly on active database connection (`ide_db.lua`); falls back to CLI execution (`psql`, `mysql`, `sqlite3`) if not connected |
| **C** | Compiles with `gcc -O2 -Wall` into user cache binary directory and executes automatically |
| **C++** | Compiles with `g++ -O2 -Wall -std=c++20` into user cache binary directory and executes automatically |
| **Python** | Executes focused script using `python3` (or `python`) |
| **JavaScript** | Executes script using `bun run` (if installed) or `node` |
| **TypeScript** | Executes script using `bun run`, `ts-node`, or `npx ts-node` |
| **Shell** | Executes focused script using `bash` |
| **Lua** | Executes script in isolated Neovim instance using `nvim -l` |

### Top Header & Statusline Run Controls
| Trigger | UI Location | Description |
| :--- | :--- | :--- |
| Click `[ 󰐊 <Config> ▾ ]` | Top Header Pill | Open Run Configurations & History picker dropdown |
| Click `[ 󰐊 ]` / `[ 󰑐 ]` | Top Header Pill | Execute active configuration / focused runnable file |
| Click `[ ⏹ ]` | Top Header Pill | Terminate active runner process |
| Click `Run` | Statusline (Left) | Execute runnable file under cursor |
| Click `⏹ Stop` | Statusline (Left) | Terminate running runner process |
| `<F5>` (Java) | Keymap (Normal) | Run Java application (`JavaRunnerRunMain`) |
| `<S-F5>` (Java) | Keymap (Normal) | Stop Java application (`JavaRunnerStopMain`) |
| `<leader>jt` (Java) | Keymap (Normal) | Run current Java test class (`JavaTestRunCurrentClass`) |
| `<leader>jd` (Java) | Keymap (Normal) | Debug current Java test class (`JavaTestDebugCurrentClass`) |
| `<leader>jb` (Java) | Keymap (Normal) | Build Java workspace (`JavaBuildBuildWorkspace`) |
| `<leader>jl` (Java) | Keymap (Normal) | Toggle Java application runner logs (`JavaRunnerToggleLogs`) |

### Run History & Configuration Picker Dropdown
Opening the Run Configuration menu presents:
1. **Run Active Configuration**: Immediate execution of current pill target.
2. **Run Focused Buffer**: Execute the currently visible buffer file.
3. **Recent Configurations**: Up to 10 recently executed configurations with language badges.
4. **Scan Project for Runnables**: Project-wide scanner (`ripgrep` / `find`) locating all Java classes with `main()` or `@Test`.
5. **Database Tool Window**: Direct link to open database connection manager.
6. **Stop Running Process**: Kill active background execution.

### Stacked Terminal Multiplexing (`ide_term.lua`)
A bottom docked terminal panel supporting multiple concurrent shell sessions.

| Shortcut / Trigger | Mode | Description |
| :--- | :--- | :--- |
| `<C-\>` or `<M-t>` | Normal, Insert, Terminal | Toggle bottom stacked terminal panel visibility |
| `<M-n>` | Normal, Terminal | Create a new terminal tab in stacked panel |
| `<M-]>` | Normal, Terminal | Switch to next terminal tab |
| `<M-[>` | Normal, Terminal | Switch to previous terminal tab |
| Click Tab in Winbar | Mouse | Switch to clicked terminal tab session |
| Click `x` or Middle Click Tab | Mouse | Kill terminal session and close tab |
| Click `+ New` in Winbar | Mouse | Spawn new terminal session tab |
| Click `_ Hide` in Winbar | Mouse | Hide bottom terminal panel without killing running processes |
| `<A-v>` | Normal, Terminal | NvChad toggleable vertical terminal split |
| `<A-h>` | Normal, Terminal | NvChad toggleable horizontal terminal split |
| `<A-i>` | Normal, Terminal | NvChad toggleable floating terminal popup |

---

## 6. Antigravity AI Assistant Sidebar (`ide_ai_sidebar.lua`)

A persistent vertical sidebar on the right running the Antigravity AI CLI (`agy`).

| Shortcut / Trigger | Mode | Description |
| :--- | :--- | :--- |
| `<C-M-a>` | Normal, Insert, Terminal, Visual | Toggle Antigravity AI sidebar panel |
| `<leader>ai` | Normal, Visual, Terminal | Toggle Antigravity AI sidebar panel |
| Click `󰚩 AI` button | Top Header (Right) | Toggle Antigravity AI sidebar panel |
| Terminal -> Toggle AI | Top Menu / `<M-T>` | Toggle Antigravity AI sidebar panel |
| Click `󰑐 Restart` | AI Winbar Button | Restart `agy` CLI process in a fresh terminal buffer |
| Click `_ Hide` | AI Winbar Button | Hide sidebar window while keeping `agy` process running in background |
| Click `󰅖 Close` | AI Winbar Button | Terminate `agy` process and close sidebar window |

*Features*: Automatic project root discovery, fallback to interactive shell if `agy` binary not found on PATH, and window isolation preventing conflict with bottom terminal.

---

## 7. Database Tooling (`ide_db.lua`)

Integrated database manager supporting **PostgreSQL**, **MySQL / MariaDB**, and **SQLite**.

### Connection & Console Management
| Trigger / Action | Context | Description |
| :--- | :--- | :--- |
| Click `󰆼 DB` / `󰆼 <dbname>` | Statusline (Left) | Open Database Tool Window interactive menu |
| Right-Click `󰆼 <dbname>` | Statusline (Right) | Directly browse tables in connected database |
| `+ New Database Connection...` | DB Menu | Interactive wizard to connect (Host, Port, DB, User, Password) |
| `Connect: <Saved Connection>` | DB Menu | Switch active connection to saved profile |
| `Browse Tables & Data` | DB Menu | Browse schema tables, row counts, and column definitions |
| `Open SQL Query Console` | DB Menu | Open dedicated query scratchpad (`DB_Console_<dbname>.sql`) |
| `Run SQL Query Under Cursor` | DB Menu | Execute SQL statement under cursor or multi-line block (`"""..."""`) |
| `Refresh Database Schema` | DB Menu | Refresh table metadata and completion caches |
| `Disconnect` | DB Menu | Disconnect active database connection |

### SQL Query Execution & Tabular Results
| Shortcut / Action | Context | Description |
| :--- | :--- | :--- |
| `<leader>r` | SQL Console Buffer | Execute query written in scratchpad buffer |
| Tabular Result View | Bottom Split (`dbout`) | Formatted output table displaying returned rows or status |
| Click `x Close` in Result Bar | Winbar Click | Dismiss tabular query result window |

### Intelligent Schema-Aware SQL Completion
Integrated into `nvim-cmp` under the `sql_db` source:
- Table name completion across `FROM`, `JOIN`, `INTO`, `UPDATE`, `TABLE` contexts.
- Column name completion with data type hints across `SELECT`, `WHERE`, `AND`, `OR`, `SET`, `BY` contexts.
- Dot completion: typing `tablename.` lists all columns of that specific table.
- Full `INSERT INTO` boilerplate expansion with column lists and placeholders (`?`).

---

## 8. LSP, Navigation & Diagnostics

| Shortcut / Trigger | Mode | Description |
| :--- | :--- | :--- |
| `gd` | Normal | LSP Go to Definition |
| `<C-LeftMouse>` | Normal, Insert | Smart Go to Definition / Implementation / JDK Source (Mouse) |
| `gD` | Normal | LSP Go to Declaration |
| `gi` | Normal | LSP Go to Implementation |
| `<C-M-LeftMouse>` | Normal, Insert | Mouse Go to Implementation |
| `<leader>D` | Normal | LSP Go to Type Definition |
| `gr` | Normal | LSP Find References across project |
| `K` | Normal | Show hover documentation popup |
| `<leader>ca` | Normal | Open LSP Code Actions / Quick Fixes picker |
| `<M-CR>` | Normal, Insert | Quick Code Action trigger |
| `<RightMouse>` on code | Normal, Insert, Visual | Mouse trigger for LSP Code Actions at cursor position |
| `<leader>ra` | Normal | Rename symbol project-wide (`NvRenamer`) |
| `<leader>fm` | Normal, Visual | Format active buffer using LSP / Conform |
| `<leader>ds` | Normal | Open diagnostics location list in quickfix window (`setloclist`) |
| Click `󰄬` / ` ` | Statusline (Right) | Open diagnostics and problems list |
| `q` or `<Esc>` | Diagnostics Window | Dismiss Problems & Diagnostics window |
| Click ` Close` | Diagnostics Winbar | Dismiss Problems & Diagnostics window |
| `<leader>wa` | Normal | Add folder to LSP workspace |
| `<leader>wr` | Normal | Remove folder from LSP workspace |
| `<leader>wl` | Normal | List LSP workspace folders |
| *Git Line Blame* | Normal, Insert | Real-time inline blame (`󰊤 <author>, <time> • <summary>`); automatically suppressed on lines with compiler diagnostics |

---

## 9. Search & Project Navigation (Telescope)

| Shortcut / Trigger | Mode | Description |
| :--- | :--- | :--- |
| `<C-p>` | Normal, Insert, Visual | VS Code Quick Open: find files by name |
| Top Header Search Bar | Mouse Click | VS Code Quick Open: find files by name |
| `<leader>ff` | Normal | Telescope find files in workspace |
| `<leader>fa` | Normal | Telescope find all files (including hidden and `.gitignore` entries) |
| `<C-f>` | Normal, Insert, Visual | VS Code floating search popup in current buffer |
| `<CR>` / `<Down>` | Floating Search | Jump to next match in floating search |
| `<Up>` | Floating Search | Jump to previous match in floating search |
| `<Esc>` / `<C-f>` | Floating Search | Close floating search popup |
| `<C-S-f>` | Normal, Insert, Visual | Live grep search string across whole project |
| `<leader>fw` | Normal | Live grep search string across whole project |
| `<leader>fb` | Normal | Search and switch active open buffers |
| `<leader>fo` | Normal | Find recent / old files |
| `<leader>fz` | Normal | Fuzzy search lines in current buffer |
| `<leader>cm` | Normal | Search git commits |
| `<leader>gt` | Normal | Search git status / modified files |
| `<leader>ma` | Normal | Search marks in project |
| `<leader>fh` | Normal | Search Neovim help documentation tags |
| `<leader>ch` | Normal | Toggle NvChad Cheatsheet (`NvCheatsheet`) |
| `<leader>th` | Normal | Open interactive color scheme picker (`NvChad Themes`) |
| `<leader>wK` | Normal | WhichKey: view all registered keymaps |
| `<leader>wk` | Normal | WhichKey: query keymap lookup |

---

## 10. Essential Vim Motions & Modes

### Mode Transitions
| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| `i` / `a` | Normal | Enter Insert mode before / after cursor |
| `I` / `A` | Normal | Enter Insert mode at beginning / end of line |
| `o` / `O` | Normal | Open new line below / above and enter Insert mode |
| `v` | Normal | Enter Character Visual mode |
| `V` | Normal | Enter Line Visual mode |
| `<C-v>` | Normal | Enter Block Visual mode |
| `<Esc>` or `jk` | Insert, Visual | Return to Normal mode |
| `;` or `:` | Normal | Enter Ex command line mode |

### Navigation Jumps & Search in Buffer
| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| `gg` | Normal | Jump to first line of buffer |
| `G` | Normal | Jump to last line of buffer |
| `:<number>` or `<number>G`| Normal | Jump directly to line number |
| `0` / `^` | Normal | Jump to start of line / first non-blank character |
| `$` | Normal | Jump to end of line |
| `w` / `b` | Normal | Jump forward / backward by word |
| `e` / `ge` | Normal | Jump to end of current / previous word |
| `%` | Normal | Jump to matching bracket `()`, `{}`, `[]` |
| `/` | Normal | Forward search pattern in buffer |
| `?` | Normal | Backward search pattern in buffer |
| `n` / `N` | Normal | Repeat search in forward / backward direction |
| `<Esc>` | Normal | Clear search highlight pattern (`:noh`) |
| `<C-d>` | Normal | Scroll half-page down and center cursor (`<C-d>zz`) |
| `<C-u>` | Normal | Scroll half-page up and center cursor (`<C-u>zz`) |

### Smart IDE Mouse Interactions
| Mouse Action | Mode / Context | Description |
| :--- | :--- | :--- |
| `<LeftMouse>` | All | Focus clicked window and switch to insert mode automatically in code buffers |
| `<M-LeftMouse>` | Normal, Insert | Jump back to previous cursor position (`<Esc><C-o>`) |
| `<RightMouse>` | Normal, Insert, Visual | Context menu: triggers LSP code actions or terminal focus |
| Smooth Wheel Scroll | All | Scroll completion menu candidates or terminal scrollback smoothly |
