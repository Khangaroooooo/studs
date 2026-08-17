# studs

[![CI](https://github.com/Khangaroooooo/studs/actions/workflows/ci.yml/badge.svg)](https://github.com/Khangaroooooo/studs/actions/workflows/ci.yml)

A Roblox game built as real source — ~27,000 lines of Luau across 87 modules, versioned in
git and synced into Studio with [Rojo](https://github.com/rojo-rbx/rojo), rather than edited
as loose scripts inside the editor.

## What's in it

Server-authoritative systems in `src/ServerScriptService/`:

| System | Does |
|---|---|
| `BattleSystem` | Turn resolution, damage, status effects |
| `TradeSystem` | Two-party trade with confirmation locking |
| `SaveManager` / `ProfileSystem` | Player persistence and session profiles |
| `QuestSystem` / `EventSystem` | Quest state machine and timed world events |
| `ShopSystem` / `MonetizationSystem` | Currency sinks and product grants |
| `BadgeSystem` / `ReferralSystem` / `LeaderboardSystem` | Progression and social loops |
| `WeatherSystem` / `EnvironmentalEffects` | Ambient world state |
| `CompanionSystem` / `TrainerSystem` / `NPCAnimator` | NPC behavior and companions |

Client scripts (`src/StarterCharacterScripts/`) cover sprint, footsteps, and R6 gait; the
save/load UI lives in `src/StarterGui/`.

## Working on it

```bash
rojo serve          # then connect from Studio
rojo build -o studs.rbxlx
```

Edit files in `src/**`. Never edit scripts inside Studio — Rojo owns that tree and will
overwrite them.

## Static analysis

Use the wrapper, not bare `luau-analyze`:

```bash
./scripts/analyze.sh
```

Plain `luau-analyze` knows nothing about the Roblox API. Every file reports
`Unknown global 'game'`, and it only ever catches syntax and scope errors. `scripts/analyze.sh`
runs `luau-lsp` with the Roblox global type definitions and a generated Rojo sourcemap, so
`require` paths and instance types resolve for real. Run `./scripts/analyze.sh --refresh`
every month or two to re-pull the definitions.

## Notes

TidepoolCove terrain is live-edited in Studio and is deliberately **not** in `src/` — git does
not version that geometry. Before any bulk delete or mutate in Studio, dry-run first and never
match instances by name substring.

The bug class this codebase actually produces is durability ordering: state that looks saved
because the write was issued, but wasn't durable when the session ended. Check write-then-ack
ordering before trusting a save path.
