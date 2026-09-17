#!/usr/bin/env node
// Repo invariant gate: NO Supabase secret may ever be committed.
//
// HARD RULES this enforces (see the "Central database" section of README.md):
//   1. The distributed config (CENTRAL_DB_URL / CENTRAL_DB_ANON_KEY) must stay BLANK in the
//      repo. The manager fills the anon key only in their private distribution copy.
//   2. The service_role key BYPASSES every grant/RLS policy -- it can read, edit, and delete
//      the entire dataset. It must NEVER appear in any tracked file.
//   3. NO real Supabase JWT of ANY role may be committed anywhere (policy: "no key in the repo").
//      Doc placeholders like 'eyJ...my-key...' are NOT real JWTs and are allowed.
//
// Scans the STAGED content (what the commit will actually contain). Fails CLOSED: a git/read
// error blocks the commit rather than skipping the file. Skips binary blobs (NUL byte) only.
// Run by scripts/githooks/pre-commit; also runnable directly:
//   node scripts/check-no-secrets.mjs          (staged changes)
//   node scripts/check-no-secrets.mjs --all     (every tracked file)
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

let hadError = false;
// Arg-based exec (no shell) so filenames with quotes/spaces/$ can't be misparsed.
function git(args, { allowFail = false } = {}) {
  try {
    return execFileSync('git', args, { encoding: 'buffer', maxBuffer: 256 * 1024 * 1024 });
  } catch (e) {
    if (allowFail) return null;
    console.error('✗ git ' + args.join(' ') + ' failed: ' + (e && e.message ? e.message : e));
    hadError = true;
    return null;
  }
}

// Decode a JWT payload (base64url middle segment); return parsed JSON or null.
function decodeJwtPayload(token) {
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) b64 += '='; // tolerate stripped padding
    return JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
  } catch { return null; }
}

// A REAL JWT = 3 base64url segments, the first two starting "eyJ". Placeholders ('eyJ...x...')
// fail because '.' / spaces aren't base64url, so a doc example never trips the gate.
const JWT = /eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g;
// Supabase's NEWER key format (not JWTs): sb_secret_… bypasses RLS (as dangerous as
// service_role); sb_publishable_… is the new anon equivalent (must still ship blank per the
// no-key-in-repo policy). Real keys are base64url (sb_secret_<random>_<checksum>) so the random
// part legitimately contains '-' and '_' — the charset MUST match the JWT regex above, else a
// real key whose first 16 random chars include a '-'/'_' evades the gate. '.' stays excluded so
// doc placeholders (sb_secret_...your-key...) still pass.
const SB_SECRET = /sb_secret_[A-Za-z0-9_-]{16,}/g;
const SB_PUBLISHABLE = /sb_publishable_[A-Za-z0-9_-]{16,}/g;
// service_role only in an ASSIGNMENT / header-credential slot -- not prose/comments (the HTML
// legitimately warns "never paste the service_role key").
const SERVICE_ROLE_CONFIG = /CENTRAL_DB_[A-Z_]*\s*=\s*[^;\n]*service_role/i;
const SERVICE_ROLE_HEADER = /(apikey|Authorization|Bearer)[^;\n]*service_role/i;
// a real JWT assigned to the shipped config.
const CONFIG_KEY_ASSIGN = /CENTRAL_DB_(URL|ANON_KEY)\s*=\s*['"]eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\./;

const all = process.argv.includes('--all');
// Staged paths: -z (NUL-delimited, safe for any filename) and diff-filter=d (everything that
// will be IN the commit -- adds, modifies, renames, copies; excludes Deletions only).
const listBuf = all
  ? git(['ls-files', '-z'])
  : git(['diff', '--cached', '-z', '--name-only', '--diff-filter=d']);
const files = listBuf ? listBuf.toString('utf8').split('\0').filter(Boolean) : [];

function classify(token) {
  const p = decodeJwtPayload(token);
  if (p && String(p.role).toLowerCase() === 'service_role') return 'a SERVICE_ROLE JWT (bypasses all security — never commit)';
  return 'a real Supabase JWT (no key may be committed — config ships blank)';
}

const violations = [];
let scanned = 0;
for (const file of files) {
  // --all audits the working tree as it exists on disk (covers tracked + newly-added files,
  // which aren't in HEAD yet); pre-commit reads the exact STAGED blob from the index.
  let buf;
  if (all) {
    try { buf = readFileSync(file); }
    catch (e) { console.error('✗ cannot read ' + file + ': ' + (e && e.message ? e.message : e)); hadError = true; continue; }
  } else {
    buf = git(['show', ':' + file]);
  }
  if (buf == null) continue; // git() already recorded the error (fail closed via hadError)
  // Do NOT blanket-skip on any NUL byte: on Windows, PowerShell's default text encoding is
  // UTF-16 LE, where every ASCII char is followed by 0x00. Skipping such a file would let an
  // ASCII key hide behind interleaved NULs, silently bypassing the last line of defense.
  let content;
  if (buf.length >= 2 && buf[0] === 0xFF && buf[1] === 0xFE) {
    content = buf.toString('utf16le');                 // UTF-16 LE BOM
  } else if (buf.length >= 2 && buf[0] === 0xFE && buf[1] === 0xFF) {
    const be = Buffer.from(buf); if (be.length % 2 === 0) be.swap16(); // UTF-16 BE BOM -> LE
    content = be.toString('utf16le');
  } else if (buf.includes(0)) {
    // Distinguish BOM-less UTF-16 TEXT from genuine binary by NUL POSITION, not just density.
    // UTF-16LE ASCII puts 0x00 in every ODD byte (c,00,c,00,…); UTF-16BE in every EVEN byte -- and a
    // real key is ASCII, so it hides perfectly behind those interleaved NULs. Genuine binary scatters
    // NULs across BOTH parities. The old blanket ">30% NUL => binary" check skipped BOM-less UTF-16
    // text (~50% NUL) BEFORE the strip-and-scan could run, re-opening the exact hole this gate closes,
    // so classify by parity FIRST and only then fall back to the density cutoff.
    let nul = 0, nulOdd = 0, nulEven = 0;
    for (let k = 0; k < buf.length; k++) {
      if (buf[k] === 0) { nul++; if (k & 1) nulOdd++; else nulEven++; }
    }
    const half = Math.floor(buf.length / 2);
    if (buf.length >= 2 && nulOdd >= half * 0.9 && nulEven <= half * 0.1) {
      content = buf.toString('utf16le');               // BOM-less UTF-16 LE text (NULs on odd bytes)
    } else if (buf.length >= 2 && nulEven >= half * 0.9 && nulOdd <= half * 0.1) {
      const be = Buffer.from(buf); if (be.length % 2 === 0) be.swap16();
      content = be.toString('utf16le');                // BOM-less UTF-16 BE text (NULs on even bytes)
    } else if (nul / buf.length > 0.3) {
      continue;                                        // scattered NULs, high density => genuinely binary
    } else {
      content = Buffer.from(buf.filter(b => b !== 0)).toString('utf8'); // sparse NULs: strip and scan
    }
  } else {
    content = buf.toString('utf8');
  }
  scanned++;
  const lines = content.split('\n');
  lines.forEach((line, i) => {
    const ln = i + 1;
    if (CONFIG_KEY_ASSIGN.test(line)) violations.push({ file, ln, why: 'a JWT key is assigned to CENTRAL_DB_* config (must stay blank)' });
    if (SERVICE_ROLE_CONFIG.test(line) || SERVICE_ROLE_HEADER.test(line)) violations.push({ file, ln, why: 'service_role used as a credential/config value' });
    let m; JWT.lastIndex = 0;
    while ((m = JWT.exec(line))) violations.push({ file, ln, why: classify(m[0]) });
    SB_SECRET.lastIndex = 0;
    while ((m = SB_SECRET.exec(line))) violations.push({ file, ln, why: 'an sb_secret_… key (bypasses RLS — as dangerous as service_role; never commit)' });
    SB_PUBLISHABLE.lastIndex = 0;
    while ((m = SB_PUBLISHABLE.exec(line))) violations.push({ file, ln, why: 'an sb_publishable_… key (config must ship blank — fill it only in the private distribution copy)' });
  });
  // Whole-file pass with string-concat noise collapsed, to catch a key assembled from split
  // literals ('eyJabc' + 'def.eyJ...'). The rigid shapes make accidental matches implausible.
  const collapsed = content.replace(/['"`]\s*\+\s*['"`]/g, '').replace(/\\\r?\n/g, '');
  const splitChecks = [
    [JWT, (t) => classify(t)],
    [SB_SECRET, () => 'an sb_secret_… key (bypasses RLS — never commit)'],
    [SB_PUBLISHABLE, () => 'an sb_publishable_… key (config must ship blank)'],
  ];
  for (const [re, why] of splitChecks) {
    let cm; re.lastIndex = 0;
    while ((cm = re.exec(collapsed))) {
      if (!lines.some(l => l.includes(cm[0]))) { // not already reported on a single line
        violations.push({ file, ln: '?', why: why(cm[0]) + ' (assembled from split literals)' });
      }
    }
  }
}

if (hadError) {
  console.error('\n✗ SECRET GATE: refusing the commit — could not read staged content (failing closed).');
  process.exit(1);
}
if (violations.length) {
  console.error('\n✗ SECRET GATE: refusing the commit — ' + violations.length + ' violation(s):\n');
  for (const v of violations) console.error('  ' + v.file + ':' + v.ln + ' — ' + v.why);
  console.error('\nRemove the secret (config must stay blank; never commit any real key). Bypass only if' +
    ' you are CERTAIN: git commit --no-verify\n');
  process.exit(1);
}
console.log('✓ secret gate: clean (' + scanned + ' file(s) scanned)');
process.exit(0);
