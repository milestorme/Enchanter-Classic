<p align="center">
  <img src="enchanter_icon.png" width="140" alt="Enchanter icon">
</p>

<h1 align="center">Enchanter</h1>

<p align="center">
  Never miss another enchant request in trade chat.
</p>

<p align="center">
  <img src="enchanter_banner.png" width="100%" alt="Enchanter banner">
</p>

## About

**Enchanter** watches general/trade chat for players looking for enchants and automatically whispers them back with a list of the enchants you know how to make — so you can keep questing, farming, or AFK-ing at the auction house without babysitting chat.

- **Interface:** 11509 (WoW Classic Era, patch 1.15.9)
- **Version:** 1.6.2
- **Original Author:** Vyscî-Whitemane

## Features

- **Automatic scanning** — `/ec scan` reads your known Enchanting recipes directly from your profession window and builds a list of what you can offer, including clickable item links for anyone who asks "what mats do you need?"
- **Smart chat detection** — recognizes both specific requests (someone naming an enchant) and generic ones like "LF Enchanter," then replies with a matching whisper.
- **Configurable tags** — customize the keywords/tags used to match each recipe and the prefixes used to detect requests.
- **Auto-invite option** — optionally invite requesters straight to a trade.
- **Blacklist support** — ignore specific players entirely.
- **Delay options** — add a delay before whispering/inviting so you don't look like a bot.
- **Session earnings tracker** — `/ec summary` prints total gold earned from trades this session.
- **In-game options panel** — `/ec config` for a full settings UI.

## Installation

1. Download this repo (Code → Download ZIP), or clone it.
2. Rename the extracted folder to `Enchanter` (if it isn't already) and place it inside your `Interface/AddOns/` directory, so the path looks like `Interface/AddOns/Enchanter/Enchanter.toc`.
3. Restart WoW or `/reload`.

## Commands

| Command | Description |
|---|---|
| `/e scan` | Scan and store your known enchant recipes (run once, and again after learning new recipes) |
| `/e start` | Start monitoring chat for requests |
| `/e stop` / `/ec pause` | Pause the addon |
| `/e config` / `/ec setup` / `/e options` | Open the settings panel |
| `/e debug` | Toggle debug messages |
| `/e summary` | Show gold earned this session |
| `/e reset` / `/ec default` | Reset all settings to default |
| `/e about` / `/ec usage` | Quick usage reminder |

`/ec` and `/enchanter` also work as aliases for `/e`.

## Getting Started

1. Learn Enchanting and log in on your enchanter.
2. Run `/ec scan` to store your known recipes.
3. Run `/ec start` to begin watching chat.
4. (Optional) Run `/ec config` to tweak tags, blacklist, auto-invite, and delays.

## Compatibility

This fork targets **WoW Classic Era, patch 1.15.9** (`## Interface: 11509`). If you're running a different Classic flavor, you may need to adjust the Interface line in `Enchanter.toc` to match your client version.

## Changelog

See [change_log.txt](change_log.txt) for the full version history.

## Credits

- **Original Author:** Vyscî-Whitemane — created the original Enchanter addon and all core logic, chat parsing, and options.
- This repository packages an interface-version update to keep the addon working on current Classic Era clients (1.15.9).

## License

No license was specified by the original author. If you plan to redistribute or modify this addon, please credit **Vyscî-Whitemane** as the original creator.
