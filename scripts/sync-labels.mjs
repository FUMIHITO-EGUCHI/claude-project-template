#!/usr/bin/env node
// sync-labels.mjs
// .github/labels.yml を読み、gh label create --force で repo に同期する。
// labels.yml に存在しないラベルは削除しない（手動追加分の保護）。
//
// 環境変数:
//   GH_REPO=owner/name   gh が向くリポを上書き（未設定なら現リポ）
//
// 依存: gh, node 18+

import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const path = '.github/labels.yml';
const text = readFileSync(path, 'utf8');

// 軽量 YAML パース（このファイルが扱う形式に限定）
const items = [];
let cur = null;
for (const raw of text.split(/\r?\n/)) {
  const line = raw.replace(/\s+$/, '');
  if (line.startsWith('#') || line.trim() === '') continue;

  const m = line.match(/^- name:\s*"?(.+?)"?\s*$/);
  if (m) {
    if (cur) items.push(cur);
    cur = { name: m[1] };
    continue;
  }

  const k = line.match(/^\s+(color|description):\s*"?(.*?)"?\s*$/);
  if (k && cur) cur[k[1]] = k[2];
}
if (cur) items.push(cur);

console.log(`[sync-labels] syncing ${items.length} labels...`);

let failed = 0;
for (const it of items) {
  const args = ['label', 'create', it.name, '--force', '--color', it.color || 'cccccc'];
  if (it.description) {
    args.push('--description', it.description);
  }
  const r = spawnSync('gh', args, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });
  if (r.status !== 0) {
    failed += 1;
    console.error(`  FAIL: ${it.name} — ${r.stderr.trim() || r.stdout.trim()}`);
  } else {
    console.log(`  OK:   ${it.name}`);
  }
}

if (failed > 0) {
  console.error(`[sync-labels] ${failed} label(s) failed.`);
  process.exit(1);
}
console.log('[sync-labels] done.');
