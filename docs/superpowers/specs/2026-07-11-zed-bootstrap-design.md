# Bootstrap de ambiente Zed — Design

Data: 2026-07-11
Repositório: `CaduVarela/zed-config` (público)

## Objetivo

Permitir configurar uma máquina nova com um único comando por plataforma, deixando
o Zed Editor instalado, configurado com as settings/keymap/tema pessoais, e com as
extensões necessárias instaladas automaticamente — de forma idempotente e fácil de
estender no futuro.

## Fora de escopo (por enquanto)

- macOS (estrutura prevê adicionar depois, mas não é implementado agora).
- Merge genérico de configs por SO (só existe hoje 1 campo específico de plataforma;
  ver decisão 4). Se surgirem mais diferenças por SO, resolver caso a caso primeiro,
  generalizar só se o padrão se repetir.
- Instalar o Zed dentro do WSL (o Zed real do usuário roda no Windows; o WSL é usado
  apenas como shell do terminal integrado).

## Comando único por plataforma

```powershell
# Windows
irm https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.ps1 | iex
```

```bash
# Linux / WSL
curl -fsSL https://raw.githubusercontent.com/CaduVarela/zed-config/master/bootstrap.sh | bash
```

Reexecutar o mesmo comando é também o mecanismo de **atualização** (repull do repo +
reaplica config). Os entrypoints são propositalmente finos: só garantem `git`, clonam
ou atualizam o repo numa pasta fixa, e chamam o orquestrador local (`src/<os>/install.*`).
Toda a lógica de verdade vive em arquivos versionados, não no one-liner remoto.

## Estrutura de diretórios

```
zed-config/
├── bootstrap.ps1              # entrypoint Windows (irm | iex)
├── bootstrap.sh                # entrypoint Linux/WSL (curl | bash)
├── src/
│   ├── windows/
│   │   ├── install.ps1         # orquestrador Windows
│   │   ├── prerequisites.ps1   # winget: Git, Zed
│   │   └── paths.ps1           # caminhos do Zed no Windows
│   └── linux/
│       ├── install.sh          # orquestrador Linux (detecta WSL vs nativo)
│       ├── prerequisites.sh    # apt/curl: Git, Zed (install.sh oficial)
│       └── paths.sh            # caminhos do Zed no Linux
├── config/
│   ├── settings.json           # settings.json real do usuário, JSON estrito
│   ├── keymap.json             # keymap (hoje vazio — base_keymap "VSCode")
│   └── AGENTS.md               # instruções globais do agente do Zed
├── theme/
│   └── manifest.json           # {"repo": "...cansee-ayu-zed.git", "extension_id": "cansee-ayu-theme"}
├── docs/
│   └── adding-config.md        # receita de como estender
└── README.md
```

## Responsabilidades

| Parte | Responsabilidade |
|---|---|
| `bootstrap.{ps1,sh}` | Garante `git` disponível, clona/atualiza o repo em pasta fixa, chama o `install.*` local. |
| `src/<os>/prerequisites.*` | Instala Zed e Git via gerenciador nativo, se ausentes. |
| `src/<os>/install.*` | Orquestra: prerequisites → sync do tema → copia `config/*` para a pasta real do Zed. |
| `config/settings.json` | Fonte única das settings do usuário — mesmo conteúdo hoje em `%APPDATA%\Zed\settings.json`, versionado. |
| `theme/manifest.json` | Aponta pro repo separado do tema pessoal, desacoplando o bootstrap do conteúdo do tema. |
| `docs/adding-config.md` | Como adicionar extensão/setting/tema/prerequisito sem redescobrir a arquitetura. |

## Caminhos reais do Zed por plataforma (confirmados na máquina do usuário / docs oficiais)

| Item | Windows | Linux |
|---|---|---|
| `settings.json` / `keymap.json` / `AGENTS.md` | `%APPDATA%\Zed\` | `~/.config/zed/` |
| Extensões instaladas | `%LOCALAPPDATA%\Zed\extensions\installed\` | `~/.local/share/zed/extensions/installed/` (ou `$XDG_DATA_HOME/zed/extensions/installed/`) |

## Conteúdo de origem

- `config/settings.json`: portado do `settings.json` real do usuário em
  `%APPDATA%\Zed\settings.json` (convertido para JSON estrito — ver decisão 3).
- `config/AGENTS.md`: portado do `AGENTS.md` real do usuário no mesmo diretório.
- `config/keymap.json`: hoje vazio/template — usuário usa `base_keymap: "VSCode"` sem
  bindings customizados.
- `theme/manifest.json`: `repo = https://github.com/CaduVarela/cansee-ayu-zed.git`,
  `extension_id = cansee-ayu-theme` (confirmado: a raiz desse repo já tem a estrutura
  de extensão do Zed — `extension.toml` + `themes/*.json`).
- Lista de extensões para `auto_install_extensions` (as 18 já instaladas hoje, exceto
  `cansee-ayu-theme` que não é do marketplace):
  `ayu-darker`, `ayu-themes-glass`, `catppuccin-icons`, `chrome-devtools-mcp`, `csv`,
  `dockerfile`, `git-firefly`, `html`, `material-icon-theme`, `mcp-server-context7`,
  `mcp-server-playwright`, `php`, `powershell`, `scss`, `serena-context-server`, `sql`,
  `toml`, `xml`.

## Decisões e justificativas

1. **Extensões de marketplace via `auto_install_extensions` nativo do Zed.**
   Confirmado na doc oficial do Zed: basta declarar `{"auto_install_extensions": {"html": true, ...}}`
   no `settings.json`. O próprio Zed instala/verifica a cada abertura — idempotente por
   natureza, sem reinventar isso em script.

2. **Tema pessoal via clone/pull + cópia espelhada para `extensions/installed/`.**
   O tema já é uma extensão real (não um JSON solto em `themes/`). O fluxo: clonar/
   atualizar `theme/manifest.json:repo` numa pasta de cache → espelhar
   (`robocopy /MIR` no Windows, `rsync -a --delete` no Linux) para dentro de
   `extensions/installed/<extension_id>/`. Idempotente e generalizável para outras
   extensões pessoais futuras.

3. **`settings.json`/`keymap.json` no repo são JSON estrito, sem comentários/vírgula final.**
   O parser do Zed tolera JSONC, mas o `ConvertFrom-Json` do PowerShell não. Como o
   Windows precisa de um patch pontual (decisão 4), a fonte no repo vira JSON estrito.
   Perde o comentário de cabeçalho original, ganha parsing confiável sem dependência
   externa.

4. **Diferença Windows/Linux tratada como patch pontual, não merge genérico de overlays.**
   Hoje existe exatamente 1 campo específico de plataforma: `terminal.shell.program`
   aponta para `wsl.exe` no Windows (o terminal integrado do Zed abre dentro do WSL).
   `install.ps1` aplica esse patch pontual depois de copiar o `settings.json` base.
   Linux não precisa de patch. Um sistema de merge genérico seria over-engineering
   para 1 campo — se surgirem mais diferenças, estender o mesmo padrão de patch.

5. **WSL = só prerequisitos de dev, não uma instância separada do Zed.**
   `install.sh` detecta WSL via `/proc/version` contendo "microsoft". Se for WSL,
   instala só prerequisitos de dev (git, build tools) e não mexe em config/tema do
   Zed (isso é responsabilidade do lado Windows). Se for Linux nativo (Ubuntu/Debian
   fora do WSL), roda o fluxo completo: instala Zed via `curl -f https://zed.dev/install.sh | sh`
   e aplica config/tema nos caminhos Linux.

6. **Prerequisitos via gerenciador nativo, IDs confirmados:**
   - Windows: `winget install -e --id ZedIndustries.Zed` e `winget install -e --id Git.Git`
   - Linux: `curl -f https://zed.dev/install.sh | sh` (instalador oficial, cobre
     Ubuntu/Debian/Arch/Fedora) + `git` via `apt`

## Idempotência

| Etapa | Mecanismo |
|---|---|
| Instalar Zed/Git | winget/apt/script oficial já são no-op se já instalado |
| Atualizar o próprio repo bootstrap | clone se não existe, senão `git pull --ff-only` |
| Aplicar settings/keymap/AGENTS.md | sobrescrita determinística (sempre regenera do repo, nunca "soma") |
| Sincronizar tema | espelhamento (`robocopy /MIR` / `rsync --delete`) — sempre igual à fonte |
| Extensões de marketplace | delegado ao próprio Zed via `auto_install_extensions` |

Antes da primeira sobrescrita de um arquivo gerenciado que já exista e difira do que
será escrito, o script faz um backup (`<arquivo>.bak-<timestamp>`) ao lado do original,
como rede de segurança para configs manuais ainda não portadas para o repo.

## Extensibilidade (vira `docs/adding-config.md`)

- **Nova extensão de marketplace** → adiciona uma linha em `auto_install_extensions`
  no `config/settings.json`, commit, push.
- **Novo setting/keybind pessoal** → edita `config/settings.json`/`config/keymap.json`
  direto.
- **Novo tema/extensão pessoal** → mesmo padrão do `theme/manifest.json`, generalizável
  para uma lista se surgir mais de um.
- **Novo prerequisito** → uma linha em `prerequisites.ps1` (id winget) e/ou
  `prerequisites.sh` (pacote apt).
- **macOS no futuro** → criar `src/macos/` seguindo o mesmo contrato dos outros dois;
  a estrutura já prevê isso.

## Testes / verificação

Não há test suite automatizado tradicional (é um script de infraestrutura pessoal).
Verificação = rodar o comando único numa máquina (ou reexecutar na atual) e confirmar:
- Zed e Git presentes.
- `settings.json`/`keymap.json`/`AGENTS.md` no destino batem com `config/`.
- Tema aparece em `extensions/installed/cansee-ayu-theme/` e é selecionável no Zed.
- Rodar duas vezes seguidas não altera nada na segunda vez além de re-sync do tema
  (que é sempre "idempotente por espelhamento", não por detecção de no-op).
