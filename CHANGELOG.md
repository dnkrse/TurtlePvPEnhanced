# Changelog

All notable changes to TurtlePvPEnhanced are documented here.

## [1.1.1] - 2026-03-25

### Added
- **Communication module** — auto-switches chat input to `/bg` when opening the chat box inside a battleground (all channels except Whisper, Raid Warning, and Battleground itself are redirected)
- *New* badge on the Communication settings section, dismissed permanently on first hover or interaction
- Version label displayed subtly next to the addon title in the settings panel
- Hover tooltips on all settings checkboxes across all modules

### Fixed
- Settings tab buttons gap: both tabs now sit flush against the settings frame
- Section frame content width is now symmetric — equal spacing on both left side and scrollbar side
- Death Recap: PvP rank badge now resolves correctly via `GetPVPRankInfo`
- Death Recap: attacker bar segments no longer overflow past the bar boundary
- Death Recap: Physical/Magic tab colors now use dynamic intensity (vivid at high damage, dim at low)
- Death Recap: CC button label cleaned up (removed redundant "CC" prefix)

---

## [1.1.0] - 2026-03-24

### Added
- **Death Recap module** — full damage breakdown of your last death: attackers, spells, CC chain, Physical vs Magic split
- Always Show toggle directly in the Death Recap window
- Icon database (`data/database_icons.lua`) for spell icon resolution in Death Recap
- AV, Blood Ring, and Thorn Gorge stub modules (coming soon)
- Minimap button
- Modular settings panel with Battlegrounds and Utilities tabs
- Module registration system (`TBGH:RegisterModule`)

### Changed
- Addon renamed to **TurtlePvPEnhanced** and restructured into modules
- Death Recap fonts sharpened (OUTLINE), window widened
- BG modules moved to `modules/bgs/`

---

## [1.0.0] - 2026-03-22

### Added
- **Warsong Gulch** overlay — flag carrier tracker with live distance for both factions, auto-announces low health to party
- **Arathi Basin** overlay — projected score and required bases to win
- Auto-release on death in battlegrounds
- Auto-queue for battlegrounds on login
- Totem skip for tab-targeting
- Helmet auto-hide when equipping trinket helmets
