#!/usr/bin/env node
// check-commit-message.mjs
// commit-msg hook 本体。commit message に `#<issue番号>` または `[skip-issue]` が
// 含まれていなければ commit を拒否する。
//
// 呼び出し: node scripts/check-commit-message.mjs <path-to-COMMIT_EDITMSG>
//
// ルール:
// - `#123` のような issue 参照が 1 件以上含まれていれば OK
// - `[skip-issue]` が含まれていれば OK（typo 修正等の雑務用 escape）
// - merge commit / revert commit / fixup / squash などの自動生成メッセージは通す
// - コメント行（`#` で始まる行）は issue 参照の判定対象から除外する

import { readFileSync, existsSync } from 'node:fs';
import { argv, exit } from 'node:process';

const path = argv[2];
if (!path) {
  console.error('[commit-msg] usage: node scripts/check-commit-message.mjs <commit-msg-file>');
  exit(2);
}
if (!existsSync(path)) {
  console.error(`[commit-msg] file not found: ${path}`);
  exit(2);
}

const raw = readFileSync(path, 'utf8');
// CRLF -> LF 正規化（Windows 対策）
const normalized = raw.replace(/\r\n/g, '\n');

// コメント行（Git の `#` 始まり）を除外
const body = normalized
  .split('\n')
  .filter((line) => !line.startsWith('#'))
  .join('\n')
  .trim();

if (body.length === 0) {
  // 空の commit message は Git 自体が弾くのでここでは何もしない
  exit(0);
}

// 自動生成メッセージはスキップ
const autoPatterns = [
  /^Merge /,
  /^Revert "/,
  /^fixup! /,
  /^squash! /,
  /^amend! /,
];
const firstLine = body.split('\n', 1)[0] ?? '';
if (autoPatterns.some((re) => re.test(firstLine))) {
  exit(0);
}

// escape hatch
if (body.includes('[skip-issue]')) {
  exit(0);
}

// issue 参照の検査: `#<数字>` が少なくとも 1 件
// 誤検出を避けるため、英数字直後の `#` は除外（例: `abc#1` は無効）
const issueRefRe = /(^|[\s(\[{])#\d+\b/;
if (issueRefRe.test(body)) {
  exit(0);
}

console.error('');
console.error('[commit-msg] commit message must reference a GitHub Issue.');
console.error('');
console.error('  Include `#<issue-number>` somewhere in the commit message, e.g.:');
console.error('    feat: add date-range filter (#42)');
console.error('');
console.error('  For trivial changes (typo / doc tweak) you may use the escape:');
console.error('    chore: fix typo in README [skip-issue]');
console.error('');
exit(1);
