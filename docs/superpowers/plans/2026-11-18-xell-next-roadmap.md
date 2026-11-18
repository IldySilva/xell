# Xell Next: Smart Terminal + Private AI — Release Roadmap

> **For agentic workers:** This is the umbrella roadmap. Do not implement from this file directly. Each phase gets its own detailed TDD plan in `docs/superpowers/plans/`. Phase 1 is already written: `2026-11-18-phase-1-shell-integration-and-blocks.md`. Write each later phase's detailed plan when that phase starts, against the code as it is then.

**Goal:** Make Xell's terminal smart without AI (Warp-class command blocks, suggestions, safety, output intelligence), then add optional, private, bring-your-own-model AI, and finally expose Xell as a secure MCP gateway so external AI agents can use your servers without ever seeing a credential.

**Architecture:** Everything rests on **shell integration**. On connect to a bash or zsh host, Xell injects a small in-memory hook script (no files are written on the server). The hooks emit standard OSC 133 prompt/command marks and OSC 7 working-directory marks. xterm.dart forwards these to Dart through `Terminal.onPrivateOSC`, and a `CommandBlockTracker` turns them into structured `CommandBlock`s (command, cwd, output range, exit code, duration). Every later feature — suggestions, the risk guard, block actions, AI explain/fix and the MCP audit log — reads from that block model instead of guessing from keystrokes.

**Tech Stack:** Flutter 3.50 / Dart 3.14, `xterm` 4.0.0, `dartssh2` 4.1 (after Phase 0), `flutter_secure_storage`, `shared_preferences`. New, later phases only: `http` (AI providers) and `shelf` (MCP gateway HTTP transport). Evaluate the official `dart_mcp` package before hand-rolling JSON-RPC.

---

## Product principles (they apply to every phase)

1. **Clean by default.** No new permanent chrome. Features show up on hover, right-click, shortcuts and the command palette. A first-time user sees the same calm terminal as today.
2. **Keyboard first, mouse friendly.** Every action has a shortcut and a palette entry. Every shortcut has a visible mouse path.
3. **Works without AI.** Phases 1–4 ship real value to people who never turn AI on.
4. **Degrades silently.** If shell integration is unavailable (sh, fish, network gear, tmux without passthrough), the terminal behaves exactly like today. There are no error popups.
5. **Transparent.** Xell never types hidden commands. If injection fails, the user sees exactly what was sent.
6. **Built for three audiences.** Developers (blocks, suggestions, rerun), sysadmins (risk guard, health digest, runbooks) and DevOps (MCP gateway, audit trail, multi-host runbooks).

## Security model (non-negotiable, applies to Phases 5–7)

| Rule | How it is enforced |
|---|---|
| AI is off by default | `AiSettings.enabled = false`; nothing in `features/ai/` runs until it is enabled |
| Bring your own model | Provider interface: Ollama / LM Studio (local), OpenAI-compatible, Anthropic. Xell runs no server of its own |
| API keys stay in the system keychain | Stored through the same `flutter_secure_storage` options as `CredentialStorage` |
| Credentials never reach any model | The redactor runs on every outbound payload; host passwords/keys are never part of the context builder's input |
| Per-host AI policy | New `SshHost.aiPolicy`: `allowed` / `localModelsOnly` / `blocked`. Hosts tagged `prod` default to `localModelsOnly` |
| Nothing auto-executes | AI output can only be *inserted* into the prompt line. The user presses Enter. The risk guard still applies |
| Show what is sent | "Preview request" in every AI surface. Every request and response is appended to a local audit log |
| MCP requires approval | Every tool call is approved in a native Xell dialog, with scopes (read-only / ask / deny) per host and per agent |
| MCP is local only | Bound to `127.0.0.1`, random port, bearer token in a `0600` file, off by default, desktop only |

---

## Release slicing (recommended)

| Version | Phases | Theme |
|---|---|---|
| **v0.2.0** | 0, 1, 2, 3, 4 | "Smart terminal" — no AI, everyone benefits (Phase 0 first: toolchain, deps, host-key verification) |
| **v0.3.0** | 5, 6 | "Private AI" — BYO model, explain / fix / ask |
| **v0.4.0** | 7 | "Xell as MCP gateway" — the differentiator |

The phases can also ship together as one release. Splitting them lets the AI work build on a block model that real users have already exercised.

---

## Phase 0 — Toolchain, dependencies, host-key verification

**Detailed plan:** `2026-11-18-phase-0-toolchain-and-dependency-upgrade.md`

- Dart SDK `^3.14.0`, Flutter pinned to 3.50.0 in CI, `flutter test` added to CI.
- `dartssh2` 2.17 → 4.1, `window_manager` 0.7, `file_picker` 13, `desktop_drop` 0.9, `cupertino_icons` 2, plus minor bumps.
- `flutter_secure_storage` 9 → **10 only**, with Android cipher migration. 11 comes one release later, otherwise stored Android passwords become unreadable.
- **Security fix:** SSH host keys are verified with trust-on-first-use (SHA-256 fingerprints, a warning dialog when a key changes). Today any host key is accepted.
- Clear error message for servers that only offer legacy algorithms (dartssh2 4 disables SHA-1 / `ssh-rsa` / CBC by default).

## Phase 1 — Shell integration + command blocks (foundation)

**Detailed plan:** `2026-11-18-phase-1-shell-integration-and-blocks.md`

What users get:
- Every command becomes a block: command, cwd, exit code and duration.
- Right-click a block: **Copy command · Copy output · Run again · Insert command · Save as snippet**.
- A tab status dot: running (accent pulse), failed (red), ok (none — stays quiet).
- In-app notice when a command longer than 10s finishes while you are on another tab.
- More accurate history: the real command (including tab completion and ↑ recall), with host, cwd, exit code and duration.
- Settings → Terminal → "Shell integration" toggle (default on).

Key files: new `lib/features/terminal/shell_integration/` (events parser, bootstrap script, output gate, block model, tracker), modified `terminal_controller.dart`, `terminal_session.dart`, `terminal_widget.dart`, `terminal_page.dart`, `command_history_entry.dart`.

## Phase 2 — Smart input (no AI)

1. **Ghost-text autosuggestions.** While typing at a prompt, show the best history match as dimmed text after the cursor. Accept with `→` at end of line or `Ctrl+F`; accept one word with `Alt+→`.
   - The current input is read from the screen: buffer text from the block's `inputStart` anchor to the cursor. This is accurate after tab completion and history recall.
   - Ranking (`SuggestionEngine`, pure Dart): same host + same cwd > same host > global; then success (exit 0) over failure; then recency and frequency. Failed commands are never suggested first.
   - Rendering: a `CustomPaint` overlay positioned from cell size (measure with `TextPainter` using `TerminalStyle.toTextStyle()`) and `buffer.cursorX/cursorY`. Shown only when the viewport is at the bottom and not in the alt buffer.
   - Mobile: the suggestion appears as a chip in `terminal_keyboard_toolbar.dart`.
2. **History search palette (`Ctrl+R` override, opt-in setting).** Fuzzy search over enriched history, with filters `host:`, `cwd:`, `failed`. Enter inserts the command and `⌘Enter` runs it.
3. **Command risk guard.** `RiskClassifier` (pure Dart, rule table with tests for each rule) runs when Enter is pressed during the input phase:
   - Critical: `rm -rf /`, `rm -rf ~`, `rm -rf *` at `/`, `mkfs*`, `dd of=/dev/sd*`, `:(){ :|:& };:`, `chmod -R 777 /`, `> /dev/sda`, `DROP DATABASE`, `iptables -F` over SSH.
   - Warning: `rm -rf` (any), `shutdown/reboot/halt`, `systemctl stop sshd`, `kill -9 1`, `git push --force` to main/master, `kubectl delete` (no dry-run), `docker system prune -a`, `truncate`, `chown -R`.
   - The Enter key (`\r`) is held in `xterm.onOutput`. Critical commands always show a confirm sheet (on any host). Warnings show one only on hosts tagged `prod`/`production` or marked "Protected" in host settings. The sheet shows the exact command, which rule matched and why; buttons **Cancel** (default) / **Run anyway**. With no shell integration the guard is inactive (we cannot read the line reliably).
4. **Snippet `{{params}}` (prep for runbooks).** `Snippet.command` may contain `{{name}}` or `{{name:default}}`. Running it opens a tiny inline form. Parser is pure Dart and tested.

## Phase 3 — Output intelligence (no AI)

1. **Block navigation:** `⌘↑` / `⌘↓` jump between prompts, and `⌘⇧↑` selects the current block's output. Scroll offset = `promptLine.y × cellHeight` via `TerminalView.scrollController`.
2. **Block gutter (subtle):** a 2px left-edge bar per block, green on success and red on failure, only on hover or for failed blocks. Hovering the bar shows `exit 1 · 2.3s · ~/app`.
3. **Sticky running header:** while a command runs longer than 3s and its prompt has scrolled out of view, a one-line header shows `▶ npm run build · 00:12`. Click to jump to it.
4. **Smart links** (via `TerminalController.highlight` plus a tap handler):
   - URLs → open in browser.
   - Absolute and cwd-relative file paths (`/etc/nginx/nginx.conf`, `src/app.ts:42`) → open in Xell's remote editor (exists today) through SFTP.
   - `host:port` → "Forward this port" (pre-fills the tunnel form).
   - Git SHAs → copy.
5. **Error highlighting:** `ErrorPatternMatcher` (pure Dart) marks lines like `error:`, `Traceback`, `panic:`, `FATAL`, `npm ERR!`, `Permission denied`, `command not found`. It feeds the failed-block badge and, in Phase 6, the "Fix" action.
6. **Find, scoped to blocks:** extends the existing search with "only in this block" and "only failed blocks".
7. **Command-not-found hints (offline):** a bundled map from common binaries to install commands per detected OS (`OsType` already exists). For example, `htop` on Ubuntu → `sudo apt install htop`. Offered as an insertable hint, never auto-run.

## Phase 4 — Runbooks + host health (no AI)

1. **Runbooks** (an evolution of snippets; old snippets stay valid as one-step runbooks): ordered steps, each with `{{params}}`, `continueOnError`, an optional `confirm: true`, and a target selection (current host / a host tag / chosen hosts).
   - Runs inside the terminal as blocks, so the output stays where users expect it.
   - Multi-host runs open one tab per host in a new workspace (workspaces exist today) and show a summary sheet: ✓/✗ per host per step.
   - Import/export as plain YAML so runbooks can live in git (open-format promise).
2. **Host health digest:** a fixed, read-only probe set run over `client.execute` (separate exec channel, never typed into the user's shell): `uptime`, `df -hP`, `free -m` / `vm_stat`, `systemctl --failed --no-legend`, `journalctl -p err -n 20 --no-pager`, `ss -tln`. Parsers are pure Dart and tested against fixture outputs from Ubuntu, Debian, Alpine and macOS. The result is a compact card in the host detail and right sidebar (disk %, memory %, load, failed units, open ports), with thresholds coloring only what needs attention.

## Phase 5 — Private AI foundation

New feature folder `lib/features/ai/`:
- `providers/ai_provider.dart` — `abstract interface class AiProvider { Stream<String> complete(AiRequest r); Future<List<String>> listModels(); bool get isLocal; }`
- `providers/ollama_provider.dart`, `openai_compatible_provider.dart` (covers LM Studio, llama.cpp server, OpenRouter and others), `anthropic_provider.dart`. All use streaming HTTP and no SDK dependencies.
- `privacy/redactor.dart` — pure Dart, heavily tested. Handles PEM private keys, `AKIA…` AWS keys, GitHub/GitLab/Slack/Stripe/OpenAI/Anthropic token shapes, JWTs, `password=`/`secret=`/`token=` key-values, `.env`-style lines, bearer headers, URLs with credentials, and optionally IPv4/IPv6, hostnames and usernames (the "Strict" level). Output keeps the structure: `‹redacted:aws-key›`.
- `privacy/ai_audit_log.dart` — append-only JSONL in app support dir. Each line holds time, host, provider, model, the redacted request and the response. Viewer in Settings → AI → Activity, with "Clear log".
- `context/context_builder.dart` — assembles OS, shell, cwd, the last N blocks (command + exit + truncated output) and the user's question. It **never** reads `CredentialStorage`, and it enforces a token budget.
- `ai_policy.dart` — resolves the effective policy from global settings + `SshHost.aiPolicy` + provider locality.
- Settings → **AI** section: Enabled (off), Provider, Endpoint, Model (fetched via `listModels`), API key (keychain), Redaction level (Standard / Strict), "Test connection", Activity log.

## Phase 6 — AI features (all optional, all insert-only)

1. **Ask → command (`⌘I`):** an inline bar above the prompt. "find files over 1GB changed this week" → a command plus a one-line explanation. **Enter** inserts it into the prompt line (no execution); **Tab** cycles alternatives. The risk guard applies when the user runs it.
2. **Explain** (right-click a block or a selection): streams into the right sidebar.
3. **Fix this** (appears on failed blocks only): diagnosis plus up to 3 suggested commands, each insertable.
4. **Remote editor assist:** "Explain this file" and "Change…" produce a diff the user accepts or rejects in `remote_file_editor_page.dart`.
5. **Session recap** (opt-in, on disconnect): a summary of the session's blocks, saved to `SshHost.notes` after the user confirms.
6. **Runbook from history:** select blocks, then "Make runbook". AI proposes the step names and `{{params}}`, and the user edits them before saving.

## Phase 7 — Xell as a secure MCP gateway (desktop)

- `lib/features/mcp_gateway/` with a Streamable-HTTP MCP server on `127.0.0.1:<random>`. The token is written to `~/.config/xell/mcp.json` (mode 0600). Settings shows a copyable `claude mcp add` / Cursor config snippet.
- Tools: `list_hosts` (name, tags, OS — never credentials), `run_command(host, command, timeout)`, `read_file(host, path, maxBytes)`, `list_dir(host, path)`, `tail_file(host, path, lines)`, `health(host)` (reuses Phase 4 probes), `run_runbook(name, params, hosts)`.
- **Approval dialog** (native, focused window): agent name, host, the exact command, risk classification (from the Phase 2 classifier), and the choices **Allow once / Always allow read-only on this host / Deny**.
- **Scopes:** per agent token × per host: `deny` (default for `prod`), `ask` (default), `readOnly` (auto-allows commands the classifier marks as read-only), `allow`.
- Execution uses a separate SSH exec channel and a dedicated session per agent. The user's interactive tabs are never touched. Output is size-capped and redacted before it is returned.
- **Audit:** every call is logged with agent, host, command, decision, exit code and duration. A "Gateway activity" view supports filtering and export to JSONL.
- Kill switch: one toggle in the menu bar / tray stops the server immediately.

---

## Cross-cutting work

- **Tests:** the repo has only `test/widget_test.dart` today. Every pure-Dart unit (parsers, tracker, classifier, redactor, ranking, health parsers) gets a unit test under `test/` mirroring `lib/`. CI: add `flutter analyze && flutter test` to the existing GitHub workflow.
- **Performance budget:** the OSC handling and tracker run on the output hot path. Neither may allocate per byte. Measure with `cat` of a 50MB file before and after Phase 1 (target: under 5% slowdown).
- **Docs:** README "What it is" section, plus a new `docs/shell-integration.md` that explains exactly what the hook script does (transparency).
- **Landing page (xell.pro):** "Smart terminal, no AI required" for v0.2.0. "Your model, your keys, your servers" for v0.3.0 / v0.4.0.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Injection visibly echoes or pollutes history | Leading space (ignored by bash `HISTCONTROL=ignorespace`), output gate hides the echo, timeout releases everything transparently. Document zsh without `HIST_IGNORE_SPACE` as a known limitation |
| Hooks clash with user frameworks (oh-my-zsh, starship, bash-preexec) | Use `add-zsh-hook` (composable); in bash, prepend to `PROMPT_COMMAND` instead of replacing it; QA matrix includes oh-my-zsh + starship |
| `sudo -i`, `exec bash`, nested SSH lose the hooks | Blocks stop and the terminal stays normal. Later: "Re-enable integration" palette action re-injects |
| Ghost text overlay misaligns (fonts, scaling) | Measure the cell size from the same `TerminalStyle`; hide on any resize until the next keystroke |
| AI leaks secrets | Redactor + preview + audit + per-host policy + local-only mode; redactor has a test corpus of real-shaped secrets |
| MCP misuse by a malicious local process | Token file 0600, localhost only, approval on every non-read-only call, off by default, kill switch |
