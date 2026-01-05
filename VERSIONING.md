---
Title: Versioning Policy (SemVer) — Taj's Mod
Description: This project follows **Semantic Versioning (SemVer)**: `MAJOR.MINOR.PATCH`.
---

> Note: While SemVer treats `0.y.z` as “initial development”, this project still uses SemVer-style rules to keep updates predictable.

---

## 1. What counts as “Public API” for this mod?

The mod’s **Public API** is anything players, configs, or scripts rely on, including:

- **Palette commands / console commands**
  - Command names, arguments, behavior, and output that users rely on.
- **Keybind actions**
  - Action IDs / internal action names exposed to configuration.
  - Default bindings (not strictly breaking to change, but must be documented).
- **Mod settings / config keys**
  - Setting names, types, ranges, meaning, and defaults.
- **Data formats**
  - Any custom save data, JSON export/import formats, or persistent files created by the mod.
- **UI entry points** that are relied upon (e.g., where to access a feature).

If it’s not in the list above and not documented for user consumption, it is usually **not** Public API.

---

## 2. How to bump versions

### PATCH (`x.y.Z`)
Use for:
- Bug fixes.
- Performance fixes.
- Small internal refactors with no user-visible behavior change.
- Localization / typo fixes.
- Minor UI polish that doesn’t change workflows.

**Examples:**
- `0.4.2 -> 0.4.3` (Fix a keybind not saving)
- `1.2.0 -> 1.2.1` (Fix a command argument parsing bug)

---

### MINOR (`x.Y.0`)
Use for:
- New features (new commands, new settings, new UI actions).
- Enhancements that are backwards-compatible.
- Adding new optional config keys.
- Adding new nodes/features that don’t break existing usage.

**Examples:**
- `0.3.15 -> 0.4.0` (Keybind Manager release)
- `1.1.3 -> 1.2.0` (New palette tools, new QoL features)

**Rule of thumb:**
- If users will say “wow, new stuff”, it’s probably **MINOR**.

---

### MAJOR (`X.0.0`)
Use for **breaking changes** (see next section).

**Examples:**
- `1.9.4 -> 2.0.0` (Rename/remove commands or settings, change data format without migration)

---

## 3. What is a breaking change?

A change is **breaking** if a typical user might need to do *anything* like:
- Update their config manually.
- Rebind keys because action IDs changed.
- Change command usage in guides/screenshots/macros.
- Lose compatibility with existing mod data formats.

**Breaking changes include:**
- Removing/renaming a command.
- Changing command arguments in a non-compatible way.
- Removing/renaming a config key.
- Changing the meaning/type/range of a setting in a way that invalidates old values.
- Changing persistent file formats without automatic migration.

Breaking changes MUST bump **MAJOR** (after 1.0.0), or bump **MINOR** while still in `0.y.z` *and* clearly label it as breaking.

---

## 4. Deprecation policy

If something needs to change:
1. **Deprecate first** (keep old behavior working, show a warning in logs/notes).
2. Ship at least **one MINOR release** where both old and new work.
3. Remove in the next **MAJOR release**.

**In release notes:**
- Mark deprecated items with: `DEPRECATED: ...`
- Mark removals with: `REMOVED: ...`

---

## 5. When will 1.0.0 be released?

`1.0.0` means:
- The mod’s **Public API is considered stable**.
- Future breaking changes will be rare and will bump **MAJOR**.
- MINOR and PATCH updates should not break typical user setups.

It is a stability declaration.

---

## 6. Hotfixes and “oops I bumped wrong”

- If a release shipped with the wrong bump (e.g., a feature went out as PATCH):
  - **Do not rewrite history.**
  - Bump correctly on the next release.
  - Mention it in notes: “Version bump correction”.

**Examples:**
- Shipped `0.3.16` with new features by accident.
- Next: `0.4.0` and note the correction.

---

## 7. Release notes rules

Every release should state:
- **Added**
- **Changed**
- **Fixed**
- (If needed) **Deprecated / Removed / Breaking**

If a breaking change exists, include:
- `BREAKING:` bullet(s)
- Migration steps (what the user must do)

---

## 8. Quick decision cheat-sheet

- Only fixes / small polish → **PATCH**
- New feature / new command / new setting / visible improvement → **MINOR**
- Rename/remove/change meaning of Public API, persistent data format changes → **MAJOR** (or “breaking minor” while in 0.x)

---

## 9. Examples

- Add new palette command “Align Left” → `0.4.0` (MINOR)
- Fix “Align Left” not working with multi-select → `0.4.1` (PATCH)
- Rename command “align_left” to “align.left” → breaking → `1.0.0 -> 2.0.0` (MAJOR)
- Add new optional config key with default behavior unchanged → MINOR
- Change default keybinds only (action IDs unchanged) → MINOR or PATCH (document it)
