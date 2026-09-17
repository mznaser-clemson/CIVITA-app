# Contributing to CIVITA

We are looking for collaborators. Contributions are welcome whether or not you use git daily —
if the steps below are unfamiliar, open an issue and describe what you want to change, and we
will help from there.

## Ways to contribute

- **Report a problem or request a feature** — open an [issue](https://github.com/mznaser-clemson/CIVITA-app/issues).
  A clear description of what you did, what happened and what you expected is enough.
- **Suggest a schema or vocabulary change** — open an issue first. The table schemas are shared
  across every contributor's data, so changes are discussed before they are made.
- **Change the code** — fork, edit, open a pull request. See below.

## Fork → branch → pull request

1. **Fork** this repository: <https://github.com/mznaser-clemson/CIVITA-app/fork>.
   That gives you your own full copy under your account; nothing you do there affects this one.
2. **Clone** your fork and make a branch:
   ```sh
   git clone https://github.com/YOUR-USERNAME/CIVITA-app.git
   cd CIVITA-app
   git checkout -b short-description-of-change
   ```
3. **Edit.** CIVITA is a single HTML file — `CIVITA-v9.html` — with no build step. Open it in a
   browser to see your change; there is nothing to compile or install.
4. **Commit and push** to your fork:
   ```sh
   git commit -am "what you changed and why"
   git push origin short-description-of-change
   ```
5. **Open a pull request** from your branch back to this repository. Describe what you changed,
   why, and how you checked it.

## Before you open a pull request

- **Never commit a filled-in backend config.** `CENTRAL_DB_URL` and `CENTRAL_DB_ANON_KEY` must
  stay empty in any committed file. A repository hook enforces this — activate it once per
  clone with `sh scripts/install-hooks.sh`, and check any time with
  `node scripts/check-no-secrets.mjs --all`.
- **Say how you tested it.** There is no automated test suite for this version, so describe the
  steps you actually ran in the browser.
- **Keep changes focused.** One concern per pull request is easier to review than several.

## Questions

Open an [issue](https://github.com/mznaser-clemson/CIVITA-app/issues) or start a
[discussion](https://github.com/mznaser-clemson/CIVITA-app/discussions). That is the fastest way
to reach us, and the answer stays visible for the next person with the same question.
