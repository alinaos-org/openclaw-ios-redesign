# OpenClaw for iPhone, simple layout

![The simple layout in light and dark mode: the first-run welcome and pairing screens, chat with plain-language tool cards, the approval card, Ideas and Goals with the agent's proposals, goals in progress, and automations, More, the agent profile's Activity, Upcoming, and Memory tabs, and Connectors](/.github/assets/simple-ui-overview.png)

An unofficial fork of [OpenClaw](https://github.com/openclaw/openclaw)'s iPhone app
with a simpler, friendlier layout. You get one main chat with your agent, five
tabs, and plain-language updates on what it's doing. Everything underneath is
upstream OpenClaw: gateway pairing, device capabilities, voice, approvals, push
notifications, and the Apple Watch app. The original layout is still one tap away.

## What's different

| Tab | What it does |
|---|---|
| **Chat** | One main chat. Side chats live under ☰. Your agent's status ("Browsing the web…") shows under its name. Tap the mascot for its profile: what it did, what it may do without asking, what's coming up, and what it remembers. |
| **Library** | Files your agent keeps in its workspace. |
| **Ideas** | Things your agent proposes to take off your plate, plus ideas to try. Tap one to start it in chat, or ask for more. |
| **Goals** | Goals your agent is working on, with progress and pause or resume. Below them: goals it proposes, a field to start your own, and the automations it's tracking. |
| **More** | **Connectors** (what your agent can reach: iPhone features you can turn on, messaging apps, and skills), plus every screen from the original app: agents, all chats, activity, automations, skills, devices, usage, connection, and settings. |

To switch to the original layout, go to **More → Use classic interface**. To come
back, tap **✨** in the classic sidebar's footer.

## Status

- [x] Shell: tabs, agent header with live status, chats and profile sheets, layout toggle
- [x] Single-row composer, blue accents, and model sign-in only when it's needed
- [x] Four-item chat menu; model and session options moved to a Model & thinking sheet
- [x] Deny/Allow approval card
- [x] Tool activity cards, named in plain language ("Ran a command", "Ran 3 steps")
- [x] Friendlier first run: meet your agent, connect your computer, say hi
- [x] Connectors: iPhone features, messaging apps, and skills in one place
- [x] Ideas and goals proposed by your agent, and goals it works on with progress

The design and plan are in [`apps/ios/SIMPLE_UI.md`](/apps/ios/SIMPLE_UI.md).

## Builds and screenshots

[![Simple UI iOS](https://github.com/mmango7474/openclaw-ios-redesign/actions/workflows/simple-ui-ios.yml/badge.svg?branch=simple-ui)](https://github.com/mmango7474/openclaw-ios-redesign/actions/workflows/simple-ui-ios.yml)

Each push to `simple-ui` builds the app on a GitHub-hosted Mac. The build also runs
the linters and tests and saves simulator screenshots of every screen as the
`simple-ui-screenshots` artifact:

```bash
gh run download -R mmango7474/openclaw-ios-redesign -n simple-ui-screenshots
```

Running it on your own iPhone requires Xcode 26.4 or newer and Apple
Development signing, the same as upstream. See
[`apps/ios/README.md`](/apps/ios/README.md).

## Staying current with upstream

The new layout lives in `apps/ios/Sources/SimpleUI`. Every change to an upstream
file is small and marked `// SIMPLE-UI:`, so upstream releases merge into
`simple-ui` with few conflicts. Don't use GitHub's **Sync fork** button. It
updates `main`, which would run upstream's CI here.

## License

MIT, same as OpenClaw. This fork is not affiliated with the OpenClaw project.
