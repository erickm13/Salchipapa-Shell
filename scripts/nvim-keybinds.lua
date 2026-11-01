-- Vuelca los atajos de Neovim (la config del usuario + LazyVim + plugins) como JSON
-- [{section, keys: [str], desc}] para el glosario de la isla. Lo ejecuta nvim-keybinds.sh con
--   nvim --headless -V1 -i NONE -n -c "luafile nvim-keybinds.lua" -c "qa!"
-- (-V1 para que cada mapeo guarde el archivo y la línea donde se definió).
-- Secciones: "Mis atajos" (lua/config/*.lua de la config), "Mis plugins · <plugin>" (atajos de
-- plugins cuyo lhs aparece en lua/plugins/*.lua) y "LazyVim · <grupo de which-key>" (el resto).

vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
vim.wait(1500, function()
  return false
end)

local config = vim.fn.resolve(vim.fn.stdpath("config"))
local leader = vim.g.mapleader or "\\"

local function norm(lhs)
  return vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, true, true))
end

-- Texto de lua/plugins/*.lua, para saber qué atajos de plugins son del usuario
local mine_text = ""
for _, f in ipairs(vim.fn.glob(config .. "/lua/plugins/**/*.lua", false, true)) do
  local ok, lines = pcall(vim.fn.readfile, f)
  if ok then
    mine_text = mine_text .. "\n" .. table.concat(lines, "\n"):lower()
  end
end

-- Grupos de which-key: { prefijo normalizado = nombre }
local groups = {}
local ok_wk, wk = pcall(function()
  return require("lazy.core.config").plugins["which-key.nvim"]
end)
if ok_wk and wk then
  local opts = require("lazy.core.plugin").values(wk, "opts", false) or {}
  local function walk(t)
    for _, e in ipairs(t or {}) do
      if type(e) == "table" then
        if type(e[1]) == "string" and type(e.group) == "string" then
          groups[norm(e[1])] = e.group
        end
        walk(e)
      end
    end
  end
  walk(opts.spec)
end

-- Atajos de lazy.nvim (se cargan al pulsarlos): id -> plugins
local lazy_keys = {}
local ok_k, K = pcall(function()
  return require("lazy.core.handler").handlers.keys
end)
if ok_k and K and K.active then
  for id, plugins in pairs(K.active) do
    lazy_keys[id] = vim.tbl_keys(plugins)
  end
end

local mode_names = { n = "", x = "visual", v = "visual", i = "insertar", o = "operador", t = "terminal", s = "selección" }

-- Comentario al final de la línea donde se definió el mapeo (o en la línea de arriba)
local function comment_at(file, lnum)
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok or not lines[lnum] then
    return nil
  end
  local c = lines[lnum]:match("%-%-%s*(.-)%s*$")
  if (not c or c == "") and lines[lnum - 1] then
    c = lines[lnum - 1]:match("^%s*%-%-%s*(.-)%s*$")
  end
  return (c and c ~= "") and c or nil
end

local function caps(lhs)
  local k = norm(lhs)
  local out = {}
  local names = { CR = "Enter", Esc = "Esc", Tab = "Tab", BS = "⌫", Space = "Space", lt = "<", Bslash = "\\",
    Up = "↑", Down = "↓", Left = "←", Right = "→", Del = "Supr", Home = "Inicio", End = "Fin" }
  local mods = { C = "Ctrl", M = "Alt", A = "Alt", S = "Shift", D = "Super" }
  local i = 1
  while i <= #k do
    local special = k:match("^<([^<>]+)>", i)
    if special == "NL" then -- <C-j> (keytrans la llama <NL>)
      vim.list_extend(out, { "Ctrl", "J" })
      i = i + 4
    elseif special then
      local parts = vim.split(special, "-", { plain = true })
      local key = table.remove(parts)
      if key == "" then -- <C-->
        key = "-"
        table.remove(parts)
      end
      for _, m in ipairs(parts) do
        table.insert(out, mods[m] or m)
      end
      table.insert(out, names[key] or (#key == 1 and key or key))
      i = i + #special + 2
    else
      table.insert(out, k:sub(i, i))
      i = i + 1
    end
  end
  -- Space al principio = <leader> (si el leader es espacio)
  if leader == " " and out[1] == "Space" and #out > 1 then
    out[1] = "Leader"
  end
  return out
end

local function group_of(lhs)
  local k = norm(lhs)
  local best, name = 0, nil
  for prefix, g in pairs(groups) do
    if #prefix > best and k:sub(1, #prefix) == prefix then
      best, name = #prefix, g
    end
  end
  return name
end

local rows, index = {}, {}
local function add(section, lhs, desc, mode)
  local key = section .. "\0" .. lhs .. "\0" .. desc
  local m = mode_names[mode] or mode
  if index[key] then
    local r = index[key]
    if m ~= "" and not r._modes[m] then
      r._modes[m] = true
    elseif m == "" then
      r._normal = true
    end
    return
  end
  local r = { section = section, keys = caps(lhs), desc = desc, _modes = {}, _normal = m == "" }
  if m ~= "" then
    r._modes[m] = true
  end
  index[key] = r
  table.insert(rows, r)
end

for _, mode in ipairs({ "n", "x", "i", "o", "t" }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    local lhs = m.lhs
    local k = norm(lhs)
    if not k:match("^<Plug>") and not k:match("^<SNR>") and not k:match("^<.-Mouse>") then
      local info = m.sid and m.sid > 0 and vim.fn.getscriptinfo({ sid = m.sid })[1]
      local file = info and vim.fn.resolve(info.name) or ""
      local desc = m.desc
      if file:sub(1, #config + 12) == config .. "/lua/config/" then
        -- Mis atajos: con desc, o el comentario de su línea, o lo que hace
        if not m.callback and (m.rhs or "") == "" then
          desc = "Desactivado" -- <Nop>
        elseif file:match("/discipline%.lua$") then
          desc = "Normal, pero avisa \"Hold it Cowboy!\" si la pulsas 10 veces seguidas (discipline)"
        else
          desc = desc or comment_at(file, m.lnum or 0) or (m.rhs ~= "" and m.rhs) or "(función)"
        end
        add("Mis atajos", lhs, desc, mode)
      elseif desc and desc ~= "" then
        local id = mode == "n" and lhs or (lhs .. " (" .. mode .. ")")
        local plugins = lazy_keys[id] or lazy_keys[lhs]
        local lk = k:gsub("^" .. vim.pesc(norm(leader)), "<leader>"):lower()
        if plugins and mine_text:find(lk, 1, true) then
          add("Mis plugins · " .. table.concat(plugins, ", "), lhs, desc, mode)
        else
          add("LazyVim · " .. (group_of(lhs) or "otros"), lhs, desc, mode)
        end
      end
    end
  end
end

-- Modo entre paréntesis si no es solo normal
for _, r in ipairs(rows) do
  local ms = vim.tbl_keys(r._modes)
  table.sort(ms)
  if #ms > 0 then
    if r._normal then
      table.insert(ms, 1, "normal")
    end
    r.desc = r.desc .. " (" .. table.concat(ms, "/") .. ")"
  end
  r.desc = r.desc:sub(1, 1):upper() .. r.desc:sub(2)
  r._modes, r._normal = nil, nil
end

-- Orden: mis atajos, mis plugins, LazyVim; dentro, por sección y teclas
local rank = function(s)
  return s:match("^Mis atajos") and 0 or s:match("^Mis plugins") and 1 or 2
end
table.sort(rows, function(a, b)
  if a.section ~= b.section then
    if rank(a.section) ~= rank(b.section) then
      return rank(a.section) < rank(b.section)
    end
    return a.section < b.section
  end
  return table.concat(a.keys, " ") < table.concat(b.keys, " ")
end)

io.stdout:write(vim.json.encode(rows))
