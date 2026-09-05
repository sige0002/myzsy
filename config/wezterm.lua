-- Windows 側の %USERPROFILE%\.wezterm.lua に配置する。
local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- PowerShell で wsl -l -v を実行し、実際のディストリビューション名に合わせる。
-- 例: Ubuntu なら 'WSL:Ubuntu'。
config.default_domain = 'WSL:Ubuntu-24.04'

-- 分割・セッション管理は tmux に任せ、WezTerm の独自キーは追加しない。
config.hide_tab_bar_if_only_one_tab = true

-- Windows の PowerShell 7 を既定に戻す場合は、上の default_domain を
-- コメントアウトして、次の行を有効にする。WSL 設定と混在させない。
-- config.default_prog = { 'pwsh.exe', '-NoLogo' }

return config
