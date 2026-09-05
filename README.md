# myzsy — WezTerm + WSL + zsh + tmux

Windows では **WezTerm を表示用**に使い、WSL 内の **zsh でシェル操作、tmux で分割・ウィンドウ・セッション管理**を行う開発環境。
導入方法、設定ファイル、使い方、実際につまずいた点をまとめる。

主な対象は **WSL 2 / Ubuntu 24.04 系、tmux 3.2 以降**。実際のディストリビューション名・バージョンは各自の環境で確認する。
会話中に確認した fzf は **0.44.1**。同梱の zsh 設定はこの版と新しい版の両方を扱う。手順の整理日: **2026-09-05**。

> **すでに導入が終わっている場合、インストールをやり直す必要はない。**
> [日常の使い方](#usage)と[tmux 操作表](#tmux)を参照する。
> 同梱ファイルは会話の設定を整理・補正したテンプレートであり、PC の設定ファイルを直接取得したバックアップではない。

## 目次

- [構成とファイル](#overview)
- [Windows: PowerShell 7 / WezTerm / WSL](#windows)
- [WSL: ツールのインストール](#install)
- [設定の配置・反映](#configuration)
- [日常の使い方](#usage)
- [tmux 操作・セッション管理](#tmux)
- [動作確認](#verification)
- [トラブルシューティング](#troubleshooting)
- [更新・バックアップ・今後の拡張](#maintenance)

<a id="overview"></a>
## 1. 構成とファイル

```text
Windows
└── WezTerm                      表示・フォント・Windows 側のコピー/貼り付け
    └── WSL / Ubuntu
        └── zsh                  補完・履歴・ディレクトリ移動・プロンプト
            └── tmux             分割・ウィンドウ・セッション管理
                ├── editor / コーディングエージェント
                ├── lazygit
                ├── shell / logs
                └── btop
```

| ツール | 主な用途 | 最初に覚える操作 |
|---|---|---|
| zsh | シェル、補完、履歴 | Tab、↑、Ctrl-a / Ctrl-e |
| tmux | 分割と作業セッション | Ctrl-b → `-` / `\|`、Ctrl + 矢印 |
| fzf | あいまい検索 | Ctrl-r |
| zoxide | 訪問履歴から移動 | `z myzsy`、`zi` |
| Starship | Git・言語環境などの表示 | プロンプトを見る |
| zsh-autosuggestions | 履歴から入力候補 | 候補表示中、行末で → |
| zsh-syntax-highlighting | 入力したコマンドの強調表示 | 入力時の色を見る |
| lazygit | 対話的な Git 操作 | `lg` |
| eza | ファイル一覧・ツリー | `ll`、`lt` |
| bat | ファイルを読みやすく表示 | `bat README.md` |
| ripgrep | ファイル内容を検索 | `rg '検索文字列'` |
| fd | ファイル名・ディレクトリ名を検索 | `fd config` |
| jq | JSON の整形・抽出 | `jq . data.json` |
| btop | Linux 側の負荷・プロセス確認 | `btop` |

このリポジトリの内容:

```text
README.md
config/
├── wezterm.lua                  Windows 側の .wezterm.lua
├── zshrc                        WSL 側の ~/.zshrc
└── tmux.conf                    WSL 側の ~/.tmux.conf
scripts/
└── install-lazygit.sh            公式 Release からの導入・更新
```

WezTerm 独自の分割キーは追加しない。SSH 先でも同じ操作をしたい場合、その接続先にも zsh / tmux と必要な設定を用意する。ローカルの設定が SSH 先に自動配布されるわけではない。

<a id="windows"></a>
## 2. Windows 側の準備

### 2.1 PowerShell 7 と WezTerm

**Windows の PowerShell** で実行する。導入済みなら省略する。

```powershell
winget install --id Microsoft.PowerShell --exact --source winget
winget install --id wez.wezterm --exact --source winget
```

インストール後はターミナルを開き直し、確認する。

```powershell
where.exe pwsh
pwsh -NoLogo
$PSVersionTable.PSVersion
```

PowerShell 7 のコマンドは `pwsh.exe`。インストール方法により場所が異なるため、WezTerm からはまず名前で起動する。今回の環境では WindowsApps 配下にあり、`C:\Program Files\PowerShell\7\pwsh.exe` の固定指定では起動できなかった。

PowerShell 7 は Windows 側での管理用。WSL 内の zsh を動かすための必須条件ではない。

出典: [Microsoft の PowerShell 導入手順](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows)、[WezTerm の Windows 導入手順](https://wezterm.org/install/windows.html)。

### 2.2 WSL を確認する

```powershell
wsl -l -v
```

例:

```text
  NAME            STATE           VERSION
* Ubuntu-24.04    Running         2
```

まだ WSL がない場合は、**管理者 PowerShell** で次を実行し、要求された再起動と Linux ユーザー作成を行う。すでにある環境を再インストールしない。

```powershell
wsl --list --online
wsl --install -d Ubuntu-24.04
```

出典: [Microsoft の WSL 導入手順](https://learn.microsoft.com/en-us/windows/wsl/install)。

### 2.3 WezTerm から WSL を直接開く

設定先は **Windows 側**の `$HOME\.wezterm.lua`。WSL 側の `~/.wezterm.lua` ではない。

既存ファイルがあれば、PowerShell でバックアップして編集する。

```powershell
if (Test-Path "$HOME\.wezterm.lua") {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item "$HOME\.wezterm.lua" "$HOME\.wezterm.lua.bak-$stamp"
}
notepad "$HOME\.wezterm.lua"
```

最小構成:

```lua
local wezterm = require('wezterm')
local config = wezterm.config_builder()

config.default_domain = 'WSL:Ubuntu-24.04'
config.hide_tab_bar_if_only_one_tab = true

return config
```

`Ubuntu-24.04` は例。`wsl -l -v` が `Ubuntu` なら **`WSL:Ubuntu`** にする。完全なテンプレートは [config/wezterm.lua](config/wezterm.lua)。

Windows の PowerShell を既定に戻す場合は、`default_domain` の行を外して以下を使う。WSL 用の設定と PowerShell 用の設定を混在させない。

```lua
config.default_prog = { 'pwsh.exe', '-NoLogo' }
```

保存後、新しい WezTerm ウィンドウで起動先を確認する。WindowsApps のバージョン付き実体パスは、更新で変わるので固定しない。

出典: [WezTerm の WSL ドメイン](https://wezterm.org/config/lua/WslDomain.html)、[default_domain](https://wezterm.org/config/lua/config/default_domain.html)。

<a id="install"></a>
## 3. WSL 側のインストール

**以下は WSL の Linux シェル内で実行する。** PowerShell から入る場合は `wsl` を実行する。

### 3.1 基本ツール

```bash
sudo apt update
sudo apt install -y zsh tmux git curl ca-certificates nano less \
  fzf zoxide eza ripgrep fd-find bat jq btop
```

Ubuntu の版や有効なリポジトリによって配布状況は異なる。対象は Ubuntu 24.04 系で、lazygit はこの一括コマンドに含めない。

```bash
. /etc/os-release
printf '%s\n' "$PRETTY_NAME"
tmux -V
fzf --version
```

### 3.2 このリポジトリを取得する

```bash
mkdir -p ~/src
git clone https://github.com/sige0002/myzsy.git ~/src/myzsy
cd ~/src/myzsy
```

すでに clone 済みなら、その作業ディレクトリを使う。手元の変更を確認せずに上書きしない。

### 3.3 zsh を既定にする

```bash
chsh -s "$(command -v zsh)"
getent passwd "$USER" | cut -d: -f7
```

表示が `/usr/bin/zsh` などになったら、新しい WSL ターミナルで確認する。今のシェルだけ切り替える場合:

```bash
exec zsh -l
```

`echo $SHELL` は継承された環境変数なので、変更直後の現在のシェルを確実に判定するものではない。zsh 内なら `echo "$ZSH_VERSION"` でも確認できる。

### 3.4 bat / fd の名前をそろえる

Ubuntu パッケージでは `batcat` / `fdfind` というコマンド名になるため、`~/.local/bin` にリンクを作る。既存のファイル・リンクは上書きしない。

```bash
mkdir -p "$HOME/.local/bin"

if command -v fdfind >/dev/null 2>&1 && \
   [ ! -e "$HOME/.local/bin/fd" ] && [ ! -L "$HOME/.local/bin/fd" ]; then
  ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi
if command -v batcat >/dev/null 2>&1 && \
   [ ! -e "$HOME/.local/bin/bat" ] && [ ! -L "$HOME/.local/bin/bat" ]; then
  ln -s "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

export PATH="$HOME/.local/bin:$PATH"
```

永続的な PATH 設定は同梱の `config/zshrc` に含まれる。

出典: [bat の導入案内](https://github.com/sharkdp/bat#installation)、[fd の導入案内](https://github.com/sharkdp/fd#installation)。

### 3.5 zsh の入力候補・強調表示

```bash
mkdir -p ~/.zsh/plugins
```

**初回だけ**実行する。各 `git clone` は 1 行のままコピーする。

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/plugins/zsh-syntax-highlighting
```

すでにディレクトリがある場合は消してやり直さず、必要なファイルがあるか確認する。

```bash
test -f ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh && echo 'autosuggestions: OK'
test -f ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh && echo 'syntax-highlighting: OK'
```

読み込み行は同梱設定に含まれるため、`.zshrc` に何度も追記しない。強調表示は最後に読み込む。

出典: [autosuggestions の導入案内](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md)、[syntax-highlighting の読み込み順](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md)。

### 3.6 zoxide

3.1 の apt で導入済みなら追加インストールは不要。

```bash
zoxide --version
```

会話中に使った公式インストーラ方式も利用できる。すでに動く版がある場合は重ねて入れない。以下は **公式版を選ぶ場合のみ**実行する例。

```bash
installer="$(mktemp)"
curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$installer" \
  && less "$installer" \
  && sh "$installer"
rm -f -- "$installer"
```

`less` は内容を確認したら `q` で終了する。外部スクリプトの実行は配布元を信頼できることが前提。

**注意:** 新しい zoxide の `zi` などの対話選択は、公式案内上 **fzf 0.51.0 以降**が必要。fzf 0.44.1 の `Ctrl-r` が動くこととは別の条件なので、該当する場合は[更新手順](#fzf-upgrade)を使う。`z 名前` による直接移動とは区別する。

出典: [zoxide の公式 README](https://github.com/ajeetdsouza/zoxide#installation)。

### 3.7 Starship

導入済みなら `starship --version` を確認するだけでよい。新規導入時は公式インストーラを確認してから実行する。

```bash
mkdir -p "$HOME/.local/bin"
installer="$(mktemp)"
curl -fsSL https://starship.rs/install.sh -o "$installer" \
  && less "$installer" \
  && sh "$installer" --yes --bin-dir "$HOME/.local/bin"
rm -f -- "$installer"
starship --version
```

この手順の配置先は `~/.local/bin`。以前 `/usr/local/bin` に導入したものが正常動作していれば移動は不要。

初期化は `eval "$(starship init zsh)"` で行い、同梱設定に含まれている。今回は独自の `starship.toml` は作成していない。

出典: [Starship の導入・シェル設定](https://starship.rs/guide/)。

### 3.8 lazygit

Ubuntu 24.04 など、apt に lazygit がない環境では公式 GitHub Release を利用する。配布条件は変わるため、`sudo apt install lazygit` がすべての Ubuntu で使えるとは考えない。

このリポジトリでは、以下で導入できる。

```bash
cd ~/src/myzsy
bash scripts/install-lazygit.sh
rehash
lazygit --version
```

[install-lazygit.sh](scripts/install-lazygit.sh) は CPU を判定し、公式 Release に実在する Linux アセットを取得する。`Linux` / `linux` の表記差に対応し、`checksums.txt` と SHA-256 を照合してから `~/.local/bin/lazygit` に配置する。sudo は不要。既存の同パスのファイルは番号付きバックアップを作る。

版を固定して入れる場合の例:

```bash
LAZYGIT_VERSION=v0.64.1 bash scripts/install-lazygit.sh
```

これは指定例であり、常に最新版を示すものではない。チェックサム照合はダウンロード内容の整合性確認であり、配布元自体への侵害まで防ぐ独立した署名検証ではない。

会話中の導入先は `/usr/local/bin` だった。すでにその版で動作しているなら再導入不要。複数の版がある場合は次で実行対象を確認する。

```bash
type -a lazygit
```

出典: [lazygit の公式導入手順](https://github.com/jesseduffield/lazygit#debian-and-ubuntu)、[公式 Releases](https://github.com/jesseduffield/lazygit/releases)。

<a id="configuration"></a>
## 4. 設定ファイルの配置・反映

### 4.1 既存設定をバックアップする

**すでに Python / Node / CUDA / プロキシなどの設定がある場合、丸ごと上書きしない。**
以下で内容を退避し、必要な固有設定だけ `~/.zshrc.local` に移すか、テンプレートとの差分をマージする。

```bash
backup_dir="$HOME/.config-backups/myzsy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
for name in .zshrc .tmux.conf .zshrc.local; do
  if [ -f "$HOME/$name" ]; then
    cp -pL -- "$HOME/$name" "$backup_dir/$name"
  fi
done
printf 'Backup: %s\n' "$backup_dir"
```

シンボリックリンクで dotfiles を管理中なら、以下のコピーではなく管理元に変更をマージする。認証情報・秘密鍵・会社固有の設定はこの公開リポジトリに追加しない。

### 4.2 新規構築時、または移行内容を確認した後

```bash
cd ~/src/myzsy
cp config/zshrc ~/.zshrc
cp config/tmux.conf ~/.tmux.conf
```

設定全文は [config/zshrc](config/zshrc)、[config/tmux.conf](config/tmux.conf) を参照する。
`~/.zshrc.local` は存在する場合だけ読み込まれる。以前の `.zshrc` 全体をそこにコピーすると二重初期化になるため、固有の PATH や必要な環境初期化だけを移す。

### 4.3 zsh の反映

**zsh 内で**実行する。

```zsh
source ~/.zshrc
```

構文だけ確認する場合:

```bash
zsh -n ~/.zshrc
```

新しいターミナルでも確認する。Bash 内から `.zshrc` を `source` すると、`bindkey` / `autoload` などが使えずエラーになる。

### 4.4 tmux の初回起動と再読み込み

tmux 外から名前付きセッションを開始する。すでに同名セッションがあれば接続する。

```bash
tmux new-session -A -s main
```

サーバの初回起動時に `~/.tmux.conf` が読み込まれる。**tmux が起動してから**設定を変更した場合:

```bash
tmux source-file ~/.tmux.conf
```

または `Ctrl-b` を押して離し、`r`。
シェルや端末種別などの変更は、既存のペインには反映されず、新しく作ったペインで確認が必要な場合がある。設定のためだけに `tmux kill-server` を実行しない。

### 4.5 会話中の設定から整理した点

- fzf は版を判定し、0.44.1 で非対応の `--zsh` を呼ばない。
- `SHARE_HISTORY` に追記機能があるため、`INC_APPEND_HISTORY` を重ねて有効にしない。
- `zsh-syntax-highlighting` は最後に読み込む。
- `cat` は本来のまま残し、読みやすい表示には `bat` を明示する。`lt` は巨大なツリーを避けるため既定を 2 階層にした。

指定された tmux キーは維持し、`Ctrl-b g` / `Ctrl-b G` の lazygit 起動もテンプレートに含めた。これらは設定ファイルを配置して読み込んだ場合に有効になる。

出典: [zsh の SHARE_HISTORY](https://zsh.sourceforge.io/Doc/Release/Options.html#History)、[fzf のシェル連携](https://github.com/junegunn/fzf#setting-up-shell-integration)。

<a id="usage"></a>
## 5. 日常の使い方

### 5.1 入力・履歴・補完

| 操作 | 動作 |
|---|---|
| Tab | コマンドやパスを補完 |
| Ctrl-r | fzf で過去コマンドを検索 |
| Ctrl-t | fzf で選んだパスをコマンド行に挿入 |
| Alt-c | fzf でディレクトリを選んで移動 |
| → | 行末で薄い入力候補を受け入れる |
| Ctrl-a / Ctrl-e | 入力行の先頭 / 末尾へ移動 |
| Ctrl-u / Ctrl-k | 行を削除 / カーソルから行末まで削除 |

Ctrl-r は文字列を入力して候補を選び、Enter でコマンド行に戻す。**内容を確認してから、もう一度 Enter で実行**する。検索のキャンセルは Esc または Ctrl-c。

fzf 0.44.1 では同梱の配布スクリプトを使う。新しい版限定の機能を無条件に設定しない。

### 5.2 ディレクトリ移動

まず実在するディレクトリへ通常の `cd` で移動する。

```bash
cd ~/src/myzsy
cd ~
z myzsy
```

`z` は訪問したディレクトリから候補を選ぶ。未訪問の場所や、まだ作成していないディレクトリを見つけるコマンドではない。

```bash
zi                    # 対話選択。fzf との版の組み合わせに注意
zoxide query -l       # 記録されている移動先を確認
```

### 5.3 ファイルを見る・探す

```bash
ll                              # 隠しファイル・Git 状態を含む詳細一覧
la                              # 隠しファイルも含めた一覧
lt                              # ツリー、既定は 2 階層
eza --tree --level=3             # 深さを変更
bat README.md                   # 強調表示・行番号付きで読む
bat --paging=never README.md     # ページャを使わず表示
fd config                       # 名前に config が含まれるもの
fd -t d '^test$'                 # test という名前のディレクトリ
fd -t f -e py                   # Python ファイル
rg -n 'ROS_DOMAIN_ID'            # ファイル内容を検索
rg -n 'CYCLONEDDS_URI' -g '*.py'  # Python ファイルに限定
rg --hidden -n 'CYCLONEDDS_URI' -g '!.git/**'
```

`rg` と `fd` は通常、隠しファイルや ignore 対象を除外する。`.env` などが出ない場合は `--hidden`、ignore 対象も調べる場合は `--no-ignore` を用途に応じて追加する。検索結果に秘密情報が含まれていないか、共有前に確認する。

生の内容が必要な場合は `cat` を使う。今回のテンプレートは `alias cat='bat'` を設定しない。

出典: [ripgrep](https://github.com/BurntSushi/ripgrep)、[fd](https://github.com/sharkdp/fd)、[bat](https://github.com/sharkdp/bat)、[eza](https://github.com/eza-community/eza)。

### 5.4 JSON と負荷監視

```bash
jq . data.json                  # JSON を整形
jq -r '.name' data.json          # name の値を文字列で取得
btop                            # Linux 側の負荷とプロセスを確認
```

`jq` には直接ファイルを渡せるので、`cat data.json | jq` とする必要はない。
WSL 内の btop で見ているのは Linux 側の情報であり、Windows 全体の監視とは区別する。

出典: [jq のマニュアル](https://jqlang.org/manual/)、[btop](https://github.com/aristocratos/btop)。

### 5.5 Git と lazygit

Git リポジトリ内で実行する。

```bash
cd ~/src/myzsy
gs                    # git status
gd                    # git diff
gl                    # グラフ付きの直近ログ
lg                    # lazygit を起動
```

lazygit では変更内容の確認、stage / unstage、commit、branch、stash、pull / push などを操作できる。画面下部のキー案内と `?` のヘルプを基準にする。

最初は「変更ファイルを選ぶ → 差分を読む → 必要な変更だけ stage → commit」という流れで使う。削除・変更破棄・reset・rebase などの操作は確認内容を読んで実行する。Git のユーザー名や認証は別設定で、lazygit の導入だけでは完了しない。

### 5.6 Starship の読み方

プロンプトには現在のディレクトリ、Git ブランチ・状態、検出された言語環境などが表示される。Node / Python の表示は、ターミナルがその言語の対話モードになっているという意味ではない。

表示が遅い場合の調査:

```bash
starship timings
```

出典: [Starship の設定・表示項目](https://starship.rs/config/)。

<a id="tmux"></a>
## 6. tmux 操作・セッション管理

### 6.1 キーの押し方

`Ctrl-b → -` は、**Ctrl と b を同時に押して離してから `-`** を押す。
`Ctrl + 矢印` は **Prefix 不要**で、その 2 キーを同時に押す。

| 操作 | キー |
|---|---|
| 上下分割 | Ctrl-b → `-` |
| 左右分割 | Ctrl-b → `\|` |
| 左 / 右 / 上 / 下のペインへ移動 | Ctrl + ← / → / ↑ / ↓ |
| ペインサイズ変更 | Ctrl-b → Shift + 矢印 |
| 今のペインを最大化 / 元に戻す | Ctrl-b → z |
| 新しいウィンドウ | Ctrl-b → c |
| 次 / 前のウィンドウ | Ctrl-b → n / p |
| ウィンドウ選択 | Ctrl-b → w |
| セッション一覧・選択 | Ctrl-b → s（tmux 標準画面） |
| ウィンドウの名前を変える | Ctrl-b → `,` |
| ペイン番号を表示 | Ctrl-b → q（表示中に番号で移動） |
| 右側の新規ペインに lazygit | Ctrl-b → g |
| 新規ウィンドウに lazygit | Ctrl-b → G |
| コピーモード | Ctrl-b → `[` |
| tmux バッファを貼り付け | Ctrl-b → `]` |
| 設定再読み込み | Ctrl-b → r |
| セッションから離れる | Ctrl-b → d |

新しいペイン・ウィンドウは現在ディレクトリを引き継ぐ。`g` / `G` は Git リポジトリ内で使う。lazygit を終了すると、そのために作ったペイン・ウィンドウも閉じる。

**Ctrl + 矢印は tmux が受け取るため、ペイン内の zsh やエディタには届かない。** 単語移動には Emacs 系なら Alt-b / Alt-f など別の操作を使う。WezTerm 側に同じキーを割り当てない。

### 6.2 コピーとスクロール

`Ctrl-b → [` でコピーモードに入る。矢印または `h/j/k/l` で移動し、`v` で範囲選択、`y` で tmux のバッファにコピーする。`Ctrl-b → ]` で貼り付ける。終了は `q`。

マウス操作は有効。ターミナルが受け持つ選択と tmux の選択は別なので、コピー先に注意する。
**この構成には Windows クリップボードへの明示的なコピー連携を入れていない。** 端末側の対応により同期する場合もあるが、この設定では保証しない。

### 6.3 名前付きセッション

**tmux 外**から:

```bash
tmux new-session -A -s main      # main があれば接続、なければ作成
tmux list-sessions               # セッション一覧
tmux attach-session -t main      # 既存の main に接続
```

**tmux 内**から別の既存セッションへ:

```bash
tmux switch-client -t work
```

`work` は例。実在する名前に置き換える。すでに tmux 内にいるのに `tmux` をもう一度起動して入れ子にしない。

### 6.4 作業を中断・再開する

作業を残して離れるなら `Ctrl-b → d`。戻るときは `tmux attach-session -t main`。

**端末との接続が切れても tmux サーバと WSL 環境が生きている間は作業を保持できるが、PC 再起動や `wsl --shutdown` をまたいでプロセスが保存されるわけではない。** `exit` でペイン内のシェルを終了する操作とも異なる。

長時間ジョブを確実に維持する必要がある場合は、WSL のライフサイクルとは別に稼働するサーバやジョブ管理環境を使う。

出典: [tmux の基本操作・セッション](https://github.com/tmux/tmux/wiki/Getting-Started)、[tmux マニュアル](https://github.com/tmux/tmux/blob/master/tmux.1)。

<a id="verification"></a>
## 7. 動作確認

WSL の zsh 内で、導入先を確認する。

```zsh
for cmd in zsh tmux fzf zoxide starship lazygit eza bat fd rg jq btop; do
  printf '%-10s ' "$cmd"
  command -v "$cmd" || true
done

fzf --version
zoxide --version
lazygit --version
zsh -n ~/.zshrc
```

続いて、新しい zsh でエラーなくプロンプトが出ること、Ctrl-r で履歴検索が開くこと、`z myzsy` で移動できること、Git リポジトリ内で `lg` が開くことを確認する。
tmux では上下・左右分割、Ctrl + 矢印移動、`Ctrl-b → z`、detach / attach を試す。

このリポジトリへの記載は、すべての Windows / WSL / ツール版の組み合わせでの実機検証を意味しない。

<a id="troubleshooting"></a>
## 8. トラブルシューティング

### `touch` が PowerShell で使えない

PowerShell に Linux の `touch` が標準である前提にしない。存在しないファイルを作るなら:

```powershell
if (-not (Test-Path "$HOME\.wezterm.lua")) {
    New-Item -Path "$HOME\.wezterm.lua" -ItemType File
}
notepad "$HOME\.wezterm.lua"
```

既存ファイルに `New-Item -Force` を使うと内容を失う場合があるため、上のように存在確認する。

### WezTerm から PowerShell が起動しない

Windows 側で確認する。

```powershell
where.exe pwsh
pwsh -NoLogo -NoProfile
```

まず実在するコマンドを確認し、`default_prog` を `pwsh.exe` にする。存在しない固定パスを指定した失敗と、プロファイル読み込みの問題を区別する。

### `unknown option: --zsh`

fzf 0.44.1 では `fzf --zsh` は使えない。埋め込みのシェル連携は **0.48.0 以降**の機能。
同梱の `config/zshrc` は版によって分岐するため、別の場所に古い `source <(fzf --zsh)` を残さない。

```bash
grep -nE 'fzf|starship|zoxide' ~/.zshrc
fzf --version
dpkg -L fzf | grep -E '(key-bindings|completion)\.zsh$'
```

Ubuntu 0.44.1 で使った読み込み先:

```zsh
source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh
```

この 2 行は **ファイルが実在するときだけ**使う。他の配布形式では場所が異なる。バージョン対応済みの同梱設定に、さらに重ねて追記しない。

出典: [fzf 0.48.0 のリリースノート](https://github.com/junegunn/fzf/releases/tag/0.48.0)。

### `zi` だけが動かない

Ctrl-r が使えても、zoxide の対話選択が対応しているとは限らない。

```bash
zoxide --version
fzf --version
```

新しい zoxide と fzf 0.44.1 の組み合わせなら、次の手順で fzf を更新するか、互換性のある版の組み合わせにそろえる。

<a id="fzf-upgrade"></a>
### fzf を公式版に更新する場合

**任意の更新手順。今回動作した apt 版を無条件に置き換える必要はない。**
初回のみ、空いている保存先に clone する。

```bash
mkdir -p ~/.local/share
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.local/share/fzf
```

`~/.local/share/fzf` が既存の Git clone なら、clone の代わりに次を実行する。

```bash
git -C ~/.local/share/fzf pull --ff-only
```

設定を自動追記しない `--bin` でバイナリだけ導入する。

```bash
bash ~/.local/share/fzf/install --bin
mkdir -p ~/.local/bin
install --backup=numbered -m 0755 ~/.local/share/fzf/bin/fzf ~/.local/bin/fzf
rehash
type -a fzf
fzf --version
```

`~/.local/bin` が PATH の前方にあることを確認し、新しい zsh を開く。同梱設定は新しい版なら `fzf --zsh` に切り替わる。apt 版の `/usr/bin/fzf` はそのまま残る。

### プラグインの `destination path ... already exists`

ディレクトリが存在するだけでは正しく導入済みとは断定できない。3.5 の `test -f` で本体のスクリプトを確認する。Git clone 済みなら、必要なときだけ更新する。

```bash
git -C ~/.zsh/plugins/zsh-autosuggestions pull --ff-only
git -C ~/.zsh/plugins/zsh-syntax-highlighting pull --ff-only
```

変更が競合して失敗した場合はローカル変更を確認する。`reset --hard` で強制的に消さない。

### `Unable to locate package lazygit`

その環境の apt から取得できない状態。`eza` / `bat` と一括指定していた場合、それらもインストールされたと決めつけない。

```bash
sudo apt install -y eza bat
bash ~/src/myzsy/scripts/install-lazygit.sh
```

### `error connecting to /tmp/tmux-1000/default`

`source-file` の接続先サーバがまだ動いていない可能性がある。

```bash
tmux list-sessions
```

作業中のセッションがないことを確認してから `tmux new-session -A -s main` で起動する。別ユーザー、`sudo tmux`、`-L` / `-S` で別ソケットを使った場合も接続先が変わる。作業があるはずなのに見つからない場合は、サーバ停止と決めつけず起動時の条件を確認する。

### プロンプトの記号が四角になる

フォントの対応を確認し、必要なら Nerd Font を **Windows 側**にインストールして WezTerm で選ぶ。WSL 側にフォントを置くだけでは Windows 版 WezTerm の表示設定にはならない。

### `bindkey: command not found` / `autoload: command not found`

Bash などから `.zshrc` を読んでいないか確認する。zsh を起動してから読み込む。

```bash
exec zsh -l
```

<a id="maintenance"></a>
## 9. 更新・バックアップ・今後の拡張

apt で導入したツールは apt、公式インストーラで入れたものは同じ導入方法で更新する。**apt は `~/.local/bin` や `/usr/local/bin` の手動配置版を更新しない。**
更新前後に `type -a ツール名` と `--version` を確認し、複数の版を混同しない。

```bash
# このリポジトリ自体を更新する。設定の配置は別作業。
git -C ~/src/myzsy pull --ff-only

# lazygit を、このリポジトリの方法で更新する場合
bash ~/src/myzsy/scripts/install-lazygit.sh
```

リポジトリを pull しただけでは、コピー済みの `~/.zshrc` / `~/.tmux.conf` は更新されない。差分確認とバックアップ後に再配置する。

### 現時点では未導入のもの

| 拡張候補 | 現状・注意点 |
|---|---|
| tmux-resurrect / tmux-continuum | 未導入。追加しても実行中プロセスのメモリ状態を丸ごと復元する機能ではない |
| Windows クリップボード連携 | 未導入。tmux の内部コピーとは別に設計する |
| fzf による tmux セッション選択 | 未導入。現在の Ctrl-b → s は tmux 標準の一覧 |
| tmux 自動 attach | 未導入。`.zshrc` に無条件で書くと入れ子や detach 後の再接続を招くため、起動経路を決めてから追加する |

**WezTerm = 表示、zsh = 入力・補完、tmux = 作業空間管理**という分担を維持し、必要になった機能を追加する。
