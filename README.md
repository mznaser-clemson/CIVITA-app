# CIVITA v9

**Computational Infrastructure for Validation, Integration, Testing, and Assessment**

CIVITA is a data-entry and data-extraction workbench for experimental results reported in
concrete-research literature, built to assemble the Concrete Grand Challenge database.

It is a **single HTML file**. There is nothing to install, no server, and no build step.

## Run it

Download `CIVITA-v9.html` and double-click it. It opens in your browser as a normal local
page and runs entirely on your machine.

Everything you enter is stored in a structured database of **17 tables** — thirteen canonical
Concrete Grand Challenge template tables (the ones exported to CSV and submitted to the
committee) plus four CIVITA extension tables holding digitized curve points, fitted material
models, model parameters and figure metadata.

There are three ways to enter data:

| Mode | What it is |
| --- | --- |
| **Manual** | Type records directly into schema-aware grids with FK pickers and validation. |
| **AI-assisted** | Upload a paper's PDF and have a model extract records for you to verify. |
| **Webform** | One card per record, with labelled fields, drop-downs for controlled terms, and parent records picked by name instead of by ID. |

A full manual is built into the app — click **Help** in the interface.

### Internet access

The page loads three pinned libraries from public CDNs on first open:

- `pdf.js 3.11.174` — reading PDFs
- `tesseract.js 7.0.0` — OCR in the figure digitizer
- `chart.js 4.5.1` — curve plots

With no network on first load, the page still opens but PDF import, OCR and plotting will not
work. Your browser caches the three files afterwards.

### AI-assisted mode

You supply your own API key (Anthropic or OpenAI) in the interface. The key is kept in your
browser's `localStorage` and is sent only to the provider you chose. No key ships in this repo
and none is needed for Manual or Webform mode.

## Central database (optional)

CIVITA can submit finished records to a shared Supabase backend. **The build published here
ships with that config deliberately blank**:

```js
var CENTRAL_DB_URL = '';       // the Supabase project URL
var CENTRAL_DB_ANON_KEY = '';  // PUBLIC anon key only (NEVER service_role)
```

To run your own instance:

1. Create a Supabase project and apply [`supabase/schema-v4.sql`](supabase/schema-v4.sql).
2. Fill the two lines above **in a private copy** of `CIVITA-v9.html` and distribute that copy
   to your contributors.
3. Never commit the filled-in copy. `.gitignore` denies `*-configured.html` outright, and
   `scripts/check-no-secrets.mjs` blocks any real Supabase JWT at commit time.

Without a central database configured, the submission path is simply unavailable; local entry,
validation, digitizing and CSV export all work as normal.

### Activating the secret gate

After cloning:

```sh
sh scripts/install-hooks.sh          # points git at scripts/githooks
node scripts/check-no-secrets.mjs --all   # audit every tracked file
```

## Tests

**No automated test suite targets v9.** The private development repo carries regression suites,
but those were written against earlier builds (v2–v7) and none of them exercises this version.
Rather than ship a suite that cannot run here, this repo ships none — treat verification as
manual until that changes.

## License

MIT — see [LICENSE](LICENSE).
