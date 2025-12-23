# Contributing to Taj's Mod

Thanks for your interest in contributing! 🎉  
This project welcomes community contributions (features, fixes, translations, docs) via Pull Requests.

> Quick rule: **PRs are welcome, re-uploads are not.**  
> Please don’t publish builds or redistributed copies from forks. Use forks only to submit PRs.

---

## Ways to Contribute

### 🐛 Reporting Bugs
1. Check if the issue already exists in **Issues**:  
   - https://github.com/tajemniktv/TajsMod/issues
2. If not, create a new issue with:
   - Clear description of the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Game version + mod version
   - Logs and/or screenshots (if applicable)

**Tip:** If the problem is performance-related, include:
- Your GPU/CPU + RAM
- Settings related to the feature (if any)
- A short clip / screenshot of the issue (if visual)

---

### 💡 Feature Requests
1. Open an issue and label it `enhancement` (or write `[Idea]` in the title).
2. Describe:
   - What problem it solves
   - What the ideal UX would look like (screenshots/mockups welcome)
   - Any constraints (performance, compatibility, keybind conflicts, etc.)

---

## 🔧 Code Contributions

### Scope & Expectations
We accept PRs that:
- Fix bugs or improve stability
- Improve UX / QoL in a way that fits the mod’s goals
- Add features that are reasonably scoped and maintainable
- Improve translations/localization
- Improve docs (README, usage guides)

We usually reject PRs that:
- Break mod style/UX or add confusing UI
- Add heavy dependencies / complexity without clear payoff
- Change behavior in a way that breaks existing users without migration notes

**Before big work:** open an issue first and describe the plan.

---

### Getting Started
1. Fork the repository
2. Clone your fork
3. Create a branch:
   - `feature/your-feature-name`
   - `fix/bug-short-name`
   - `i18n/lang-code-short-desc` (e.g. `i18n/pl-menu-strings`)
   - `docs/short-desc`

Example:
```bash
git checkout -b feature/command-palette-search
````

---

### Development Setup (Upload Labs)

1. Locate your Upload Labs installation folder
2. Navigate to:

   * `Upload Labs Source Files/mods-unpacked/`
3. Clone/copy your fork into this location as:

   * `TajemnikTV-TajsModded`
4. Launch the editor to test changes

**Notes**

* Keep local changes minimal and focused.
* If you touch configs / defaults, include a short rationale in the PR.

---

## 🌍 Translations / Localization (i18n)

Translations are welcome!

**Rules**

* Keep translations natural (not ultra-literal).
* Keep terminology consistent across the UI (avoid 3 different words for the same thing).
* Preserve placeholders/tokens exactly as-is (examples: `{0}`, `%s`, `$VALUE`, etc.).
* Don’t change keys/IDs unless the PR is specifically about refactoring localization.

**Recommended workflow**

1. Add/update translation strings in the localization folder/files used by the mod
2. Test in-game (or in whatever preview)
3. If a string is unclear, open an issue asking for context

---

## ✅ Submitting a Pull Request

1. Commit your changes with clear messages (see below)
2. Push to your fork
3. Open a PR into `main`
4. Describe what you changed and why
5. Link related issues (`Fixes #123` / `Closes #123`)

---

## 🧼 Code Style & Quality

* Follow existing patterns in the project
* Prefer readability over cleverness
* Use descriptive variable and function names
* Comment complex logic (why, not what)
* Keep functions focused and modular
* Avoid “magic numbers” unless they’re constants with context

### Commit Message Tips

Use something like:

* `fix: prevent crash when opening settings with empty list`
* `feat: add quick search to command palette`
* `i18n: add Polish translation for settings menu`
* `docs: clarify installation steps`

---

## 🧪 Testing Guidelines (lightweight)

At minimum, try to:

* Launch the game/editor with the mod installed
* Exercise the specific feature you touched
* Confirm no obvious errors/log spam
* If you changed UI: check scaling / different resolutions if possible

If you can’t test (no access to game/editor), say it explicitly in the PR.

---

## 🔒 Legal / Licensing Reminder

By submitting a PR, you agree your contribution can be used, modified, and redistributed as part of **Taj’s Mod** under the project’s license terms.

Forks are allowed **only for PR work** — please do not publish builds, archives, or alternative distribution mirrors.

---

## Questions?

Open an issue if you have questions about contributing, architecture, or where best to place changes. 🙌