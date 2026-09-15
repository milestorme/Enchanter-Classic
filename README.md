<p align="center">
  <img src="Media/enchanter_icon.png" width="140" alt="Enchanter icon">
</p>

<h1 align="center">Enchanter</h1>

<p align="center">
  Never miss another enchant request in trade chat.
</p>

<p align="center">
  <img src="Media/enchanter_banner.png" width="100%" alt="Enchanter banner">
</p>

## About

**Enchanter** is a lightweight World of Warcraft Classic Era addon for players offering enchanting services. It watches chat for players looking for an enchanter, matches their requests against recipes you actually know, and helps automate responding, material requirements, invitations, and trade history.

- **Interface:** 11509 (WoW Classic Era, patch 1.15.9)
- **Original Author:** Vyscî-Whitemane

## Features

- **Smart request detection** — recognizes generic requests such as "LF Enchanter", specific enchants, multiple enchants in one message, abbreviations, and configurable aliases.
- **Recipe scanning** — `/ec scan` stores your known Enchanting recipes and their material requirements. You only need to scan again after learning new recipes.
- **Automatic whispers** — can ask generic requesters what they need and respond when their follow-up matches an enchant you know.
- **Material links** — replies can include required materials using clickable WoW item links.
- **Multiple enchant matching** — can recognize and respond to multiple requested enchants in the same conversation.
- **Custom enchant aliases** — customize matching terms for every enchant. New default aliases are merged without deleting aliases you added yourself.
- **Auto-invite option** — optionally invite a customer after a valid enchant request is recognized.
- **Blacklist support** — ignore specific players entirely.
- **Delay options** — configurable whisper and invite delays.
- **Anti-spam cooldowns** — prevents repeatedly contacting the same player.
- **Manual rejection cooldowns** — configurable phrases such as "sorry i dont have that" can place a customer on a longer cooldown after you manually decline their request.
- **Persistent listening state** — if Enchanter was listening when you logged out, it automatically resumes the next time you log in and confirms that it is enabled.
- **Lifetime statistics** — keeps lifetime trade and gold totals separately from the rolling journal history.
- **In-game options panel** — `/ec config` opens the full settings UI.

## Enchanter Journal

Version 1.6.8 adds a full in-game **Enchanter Journal** for completed enchanting work.

The Journal keeps the **latest 1,000 completed enchant trades** and records:

- Date and time
- Player
- Enchant performed
- Gold made

Player names use their normal **WoW class colour** when the player's class was captured with the trade.

Both tipped and free enchants are recorded. A completed enchant with no tip is stored as **0c**, while tipped trades record the gold received. Old entries are automatically pruned after 1,000 trades so SavedVariables remain manageable.

Lifetime totals are stored separately, so pruning old Journal entries does not reduce your lifetime statistics.

Use `/ec history` or **Middle Click** the minimap button to open the Journal.

## Minimap Button

Enchanter includes a draggable minimap button with quick access to its main functions:

- **Left Click** — Start/Stop listening
- **Middle Click** — Open Enchanter Journal
- **Right Click** — Open Options
- **Shift + Left Click** — Scan enchanting recipes

The tooltip also shows Enchanter's current listening and recipe status.

## Installation

1. Download the addon ZIP.
2. Extract/rename the folder to `Enchanter` if necessary and place it in `Interface/AddOns/`, so the path is `Interface/AddOns/Enchanter/Enchanter.toc`.
3. Restart WoW or `/reload`.

## Commands

| Command | Description |
|---|---|
| `/ec scan` | Scan and store your known enchant recipes; scan again after learning new recipes |
| `/ec start` | Start monitoring chat for enchant requests |
| `/ec stop` | Stop monitoring chat |
| `/ec history` | Open the Enchanter Journal |
| `/ec summary` | Show earnings/trade summary |
| `/ec config` | Open the settings panel |
| `/ec debug` | Toggle debug messages |
| `/ec reset` | Reset settings to defaults |
| `/ec about` | Show usage information |

`/e` and `/enchanter` also work as command aliases for `/ec`.

## Getting Started

1. Log in on your enchanter and open the Enchanting profession.
2. Run `/ec scan` to store your known recipes.
3. Run `/ec start` to begin watching chat.
4. Optionally run `/ec config` to customize request patterns, aliases, blacklist, auto-invite, delays, and cooldowns.

Your scanned recipes and listening state persist between sessions. You normally only need to scan again after learning another enchant.

## Compatibility

This version targets **World of Warcraft Classic Era, patch 1.15.9** (`## Interface: 11509`) and is focused on Classic Era enchanting data rather than TBC recipes.

## Changelog

See [changelog.txt](changelog.txt) for the full version history.

## Credits

- **Original Author:** Vyscî-Whitemane — creator of the original Enchanter addon and its core chat parsing/options foundation.
- The current Classic Era version expands the addon with updated Classic compatibility, smarter matching and aliases, material responses, persistent statistics, trade tracking, the Enchanter Journal, minimap integration, and additional automation/QoL features.

## License

No license was specified by the original author. If you plan to redistribute or modify this addon, please credit **Vyscî-Whitemane** as the original creator.
