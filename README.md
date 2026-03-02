# bcc-bridge

## Description

`bcc-bridge` is a standalone RedM framework bridge that provides a unified API for both **VORP** and **RSG** frameworks. Resources built against the bridge work on either server without modification — the correct framework implementation is detected and loaded automatically at startup.

## Features

- Auto-detects VORP or RSG at runtime (falls back to stubs if neither is present)
- Unified API for player/character data, money, inventory, jobs, gangs, metadata, licenses, skills, callbacks, and notifications
- Server-side and client-side exports
- Async `Server*` client exports for round-tripping server data from client code
- Two complete test suites (`test-vorp`, `test-rsg`) for verifying bridge behaviour on your server

## Dependencies

- [oxmysql](https://github.com/overextended/oxmysql)

## Supported Frameworks

The bridge auto-detects which framework is running. No additional configuration is needed — simply have one of the following already started before `bcc-bridge`:

- **VORP:** `vorp_core`, `vorp_inventory`
- **RSG:** `rsg-core`

If neither is detected the bridge loads fallback stubs, so dependent resources will still start without errors.

## Installation

### 1 – Install bcc-bridge

1. Copy the `bcc-bridge` folder into your server's `resources` directory.
2. Add the following line to your `server.cfg` **before** any resource that depends on it:

   ```txt
   ensure bcc-bridge
   ```

---

## Test Suites

Two optional test resources are included to verify the bridge is wired up correctly on your server.

### Installing a test suite

1. Copy either `test-vorp` **or** `test-rsg` (whichever matches your framework) into your `resources` directory alongside `bcc-bridge`.
2. Add it to `server.cfg` **after** `bcc-bridge`:

   ```txt
   ensure bcc-bridge
   ensure test-vorp   # or test-rsg
   ```

3. Restart the server (or `refresh` + `start test-vorp` / `start test-rsg` in the console).

> **Note:** Only run a test suite in a development environment — never on a live production server.

---

### VORP test suite (`test-vorp`)

#### VORP server-side commands

Run these in the **server console**. Replace `<playerId>` with the target player's network ID.

| Command | What it tests |
| --------- | --------------- |
| `vorp_test_all <playerId>` | Every test group |
| `vorp_test_economy <playerId>` | Money & inventory |
| `vorp_test_character <playerId>` | Identity, jobs, gangs |
| `vorp_test_meta <playerId>` | Metadata, licenses, skills |

#### VORP client-side commands

Type these in the **in-game chat** while connected as a player. Run them **after your character has fully spawned**.

| Command | What it tests |
| --------- | --------------- |
| `/vorp_test_client_all` | All instant + async exports |
| `/vorp_test_client_instant` | Cached/immediate exports (GetFramework, GetJob, GetMoney, Notify, TriggerCallbackAwait, …) |
| `/vorp_test_client_async` | All `Server*` round-trip exports |

Results are printed to the **F8 console** as `[PASS]` / `[FAIL]` lines with the returned value.

---

### RSG test suite (`test-rsg`)

#### RSG server-side commands

| Command | What it tests |
| --------- | --------------- |
| `rsg_test_all <playerId>` | Every test group |
| `rsg_test_economy <playerId>` | Money & inventory |
| `rsg_test_character <playerId>` | Identity, jobs, gangs |
| `rsg_test_meta <playerId>` | Metadata, licenses, skills |

#### RSG client-side commands

| Command | What it tests |
| --------- | --------------- |
| `/rsg_test_client_all` | All instant + async exports |
| `/rsg_test_client_instant` | Cached/immediate exports |
| `/rsg_test_client_async` | All `Server*` round-trip exports |

---

### Reading the output

```txt
═══ ECONOMY ═══
[PASS] GetMoney (cash, initial)           → 150
[PASS] AddMoney (cash +500)               → true
[PASS] GetMoney (cash = start+500)        → 650
[PASS] RemoveMoney (cash -500)            → true
[PASS] RemoveMoney insufficient funds     → correctly refused
[FAIL] AddItem (water x3)                 → inventory not available
```

- `[PASS]` — export returned an expected value.
- `[FAIL]` — an assertion failed or an error was thrown; the reason is shown after `→`.

Any `[FAIL]` relating to an inventory or economy call usually points to a misconfigured `vorp_inventory` / RSG inventory resource rather than a bridge bug.
