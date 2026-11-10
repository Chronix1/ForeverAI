# ForeverAI simulated WoW tests (not an actual client test)

Run from `Addon/ForeverAI`:

```sh
python3 Tests/run_lua54.py Tests/test_foreverai.lua .
```

Covers map imports, navigation, bilingual terms, manual AI bridge, the renamed
slash commands, legacy data migration and offline WoW question answering.

The harness uses simulated WoW APIs, fake map IDs, dummy quests and no real AI
account. Passing tests do not establish actual in-game rendering, route
correctness, real login success or guaranteed free API usage.
