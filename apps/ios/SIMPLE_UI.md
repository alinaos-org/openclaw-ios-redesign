# Simple layout (fork plan)

This fork gives the OpenClaw iPhone app a **simple layout**: a friendly personal
agent with one main chat, five tabs, and plain-language approvals. Everything
underneath (gateway pairing, node commands, voice, push, approvals, Watch)
stays upstream OpenClaw. The original sidebar layout remains available as the
**classic layout**.

Branch: `simple-ui` · Fork: `alinaos-org/openclaw-ios-redesign` · Upstream
remote: `upstream` (openclaw/openclaw, MIT).

## Why

The current app mirrors the web Control UI. Its black sidebar has 15+
destinations (Overview, Workboard, Usage, Automations, Sessions, Activity, Skill
Workshop, Agents, Instances, Files, Dreaming, Desktop, Terminal, Docs, Settings).
That's useful for operators, but it overwhelms people who just want an
assistant. The simple layout puts the everyday tasks up front and keeps every
power-user screen one tap away under **More**.

## Design spec

| Area | Spec |
|---|---|
| Header | Every tab shares one centered header: the animated OpenClaw mascot overlapping a white name capsule with a soft shadow. A live status line ("Browsing the web…") appears under the name while the agent works. A circular ☰ sits top-left on Chat; some tabs have a circular ⋯ top-right. |
| Navigation | A floating capsule tab bar with 5 icon-only tabs: Chat, Library, Ideas, Goals, More. The selected tab gets a soft grey pill. |
| Chat | One long **main chat**. ☰ opens **Chats** (main chat, side chats, search, new chat, settings). There are no per-message avatars. Agent bubbles are light grey, user bubbles light blue with dark ink, radius about 20. |
| Composer | A pill with `+` (attach), a "Message" placeholder and a mic. |
| Tool cards | An icon tile, a friendly status ("Selecting seats…"), a live preview, and a full-width "Open" button. |
| Approvals | A white card with radius about 28: an icon plus "Your agent wants to …", plain caution copy, details, then **Deny** (grey capsule) and **Allow** (blue capsule) at equal widths. |
| Profile sheet | Tap the mascot to get the agent's profile: its name, status, a stop button while it works, and Activity · Permissions · Upcoming · Memory. |
| Ideas | A large title. Rows show an icon tile, a bold "I can …" headline and a grey paragraph. Tapping one starts the task in chat. |
| Goals | A large title. A "Tracking" section (green dot) and a "Paused" section hold checkbox rows with a status line, then "Create a goal" templates by area. |
| Look | Near-white canvas (#FAFAFA; dark #181819), ink #111112, one accent (#0064D4; dark #1793FF), big continuous radii, capsules, soft diffuse shadows and thin-line icons. Copy is warm and first-person ("I can…"). |

## How OpenClaw maps onto the simple layout

| Surface | OpenClaw backing (exists today) | Plan |
|---|---|---|
| Main chat | `ChatProTab` / `OpenClawChatView` on the main session | Reuse it with `chrome: .simple` for the header, bubble color and starter prompts |
| Side chats | Gateway sessions (`RootSidebarModel.sessions`) | `SimpleChatsSheet`, opened from ☰ |
| Status line | `pendingRunCount`, `pendingToolCalls`, `streamingAssistantText`, talk mode | `SimpleAgentStatus` turns these into friendly phrases plus a mascot mood |
| Avatar | `OpenClawMascotView` (animated lobster with moods) | The header avatar; its mood follows agent state |
| Library | Agent workspace files (`AgentWorkspaceDirectoryList`) | Tab 2 |
| Ideas | `ideas.json` in the agent's workspace (`agents.workspace.get`) | Tab 3: the agent's proposals (Start runs one in chat, Not now hides it on this phone, "Get ideas" asks in chat for more), then curated "I can…" ideas |
| Goals | Session goals (`sessions.list` rows' `goal`, `chat.send` goal intent, `sessions.goal.update`) + cron jobs (`RootSidebarModel.cronJobs`) | Tab 4: "Working on" (goals with status and the latest note), goal proposals (`"kind": "goal"` entries in `ideas.json`), an inline "Start a goal" field, automations as tracked check-ins, and planning templates |
| More | Every classic destination | Tab 5: a grouped list that opens each one as a sheet |
| Approvals | `ExecApprovalPromptDialog` | Phase 2: restyle as the Deny/Allow card |
| Profile sheet | Audit activity (`audit.activity.list`), standing grants (`exec.approval.grants.*`), cron jobs, `MEMORY.md` | Tabs: Activity (what it did, in plain language), Permissions (what automations may run without asking, with Remove), Upcoming (scheduled check-ins), Memory (what it remembers). Each links to the full screen. |
| Connectors | Device permissions, channels, and skills, each only on the dashboard (admin phones) | Phase 3: a native Connectors sheet from More. It covers iPhone features with one-tap turn-on, messaging apps (`channels.status`), and skills (`skills.status`); both calls need only operator.read. On phones that can open the dashboard, messaging-app and skill rows open its Channels and Skills pages |

## Architecture: keep the fork rebasable

Upstream's iOS app gets more than 40 PRs a week. To keep conflicts small:

1. **New code lives in `Sources/SimpleUI/`.** Upstream never touches it.
2. **The hooks into upstream files are small and fenced with `// SIMPLE-UI:` comments**:
   - `RootTabs.swift` chooses the simple shell or the classic sidebar shell, and routes
     `selectSidebarDestination` / `selectSettingsRoute` into tabs or sheets.
   - `ChatProTab.swift` gets a `chrome: .simple` option.
   - `RootSidebar.swift` gets a sparkles button that switches back to the simple layout.
3. **The layout is a runtime preference** (`SimpleShellPreference`, default on). More →
   "Use classic interface" switches to the original layout, which is handy for
   comparison and for checking that upstream behavior still works. The launch flags
   `--openclaw-simple-shell` and `--openclaw-classic-shell` force either one.
4. All lifecycle, onboarding, gateway problem toasts, trust prompts and approval
   dialogs stay owned by `RootTabs`, so both layouts get them unchanged.

## Phases

- **Phase 1: shell (this branch)**
  Theme tokens, floating tab bar, mascot header with live status, Chat / Library /
  Ideas / Goals / More tabs, Chats sheet, simple profile sheet, layout toggle.
- **Phase 2: chat polish.** Composer pill (`+` / Message / mic), tool cards with
  status and an "Open" button, typing dots, the Deny/Allow approval card, artifact cards.
- **Phase 3: onboarding.** A friendly 3-step first run (meet your agent →
  connect your computer by QR → say hi to your agent by name) in front of the
  existing wizard, plus a native Connectors sheet over iPhone features,
  messaging apps, and skills. Connectors turns iPhone features on through the
  same owners as the device settings page; messaging apps and skills are set
  up on the computer, so it reports their status and what's missing.
  The simple screens replace only the wizard's full-screen steps and call its
  actions; setup codes, manual addresses, pairing approval, and recovery stay
  on the wizard's own screens. Naming the agent from the phone is deferred:
  the app never writes agent config to the gateway today.
- **Phase 4: proactive.** Agent-generated Ideas, Goals with progress, and the profile sheet
  with Activity / Permissions / Upcoming / Memory segments. Ideas and goals
  are done. Proposals live in `ideas.json` in the agent's workspace: "Get
  ideas" asks in chat for the agent to add entries (`id`, `kind` idea or
  goal, `title`, `summary`, `prompt`), and the tabs read the file back with
  `agents.workspace.get`. The gateway's own task suggestions can't be used:
  it offers the `suggest_task` tool only to its web and terminal UIs with
  admin access. The phone can't write the workspace, so "Not now" is
  remembered on the phone. Starting a goal sends the objective with the
  `session-goal-start` intent to a new chat key (admission creates the chat);
  each chat holds one goal. The profile sheet's tabs are done too: Activity
  reads the audit feed (finished tool actions, 30 days, in the tool cards'
  plain language), Permissions lists standing grants (automation commands
  allowed without asking; needs operator.approvals), Upcoming lists cron
  jobs by next run, and Memory renders `MEMORY.md`.

## Building without a Mac

GitHub Actions builds every push to `simple-ui` on a hosted macOS runner
(`.github/workflows/simple-ui-ios.yml`). Each run:

1. Lints with the pinned SwiftFormat and SwiftLint.
2. Builds the app for the simulator.
3. Runs the simple-layout and typography unit tests.
4. Runs `SimpleShellSnapshotUITests` in demo mode and uploads screenshots of every tab and sheet as the
   `simple-ui-screenshots` artifact.

To fetch the newest screenshots:

```bash
gh run download -R alinaos-org/openclaw-ios-redesign -n simple-ui-screenshots
```

To put a build on an iPhone, start `.github/workflows/simple-ui-testflight.yml` by hand. It
signs the app as `ai.controlstack.openclaw` and uploads it to TestFlight. One-time setup:
[`TESTFLIGHT.md`](TESTFLIGHT.md).

Local lint on Linux uses the same pinned tools from nixpkgs (`swiftformat` 0.63.1,
`swiftlint` 0.65.1) with `config/swiftformat` and `apps/ios/.swiftlint.yml`.

To build locally on a Mac with Xcode 26.4 or newer:

```bash
git sparse-checkout disable   # materialize the whole monorepo
pnpm install
pnpm ios:open
```
