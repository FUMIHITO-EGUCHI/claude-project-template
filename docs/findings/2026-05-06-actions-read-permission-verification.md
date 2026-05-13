---
date: 2026-05-06
related-issue: PR #50
status: open
---

# `actions: read` 権限追加の検証

## 背景

claude-code-action が job link を attach する目的で `GET /repos/:owner/:repo/actions/runs` を叩く。default の `GITHUB_TOKEN` 権限が read-only な repo では 403 になる可能性があり、PR #50 で 3つの claude-* workflow に `actions: read` を追加した。

PR #50 自身は workflow file を編集する PR のため `claude-code-action` の workflow validation で 401 になる（既知制約・bootstrap.md §3）。よって PR #50 自体では検証できない。

本 finding は workflow file を一切編集しない別 PR を立て、`claude-pr-review.yml` が main の workflow（`actions: read` 追加版）で正常完走するかを観測する目的で作成した。

## 期待結果

- `claude-pr-review.yml` の `review` job が SUCCESS
- 5軸レビューと verdict classifier が完走
- `actions: read` 不足による 403 が出ない

## 実測

（merge 後の追記欄。検証完了後に結果を書き戻す）
