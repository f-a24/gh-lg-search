# fixtures

GitHub REST API のレスポンスから、テストに必要なフィールドだけを抜き出したもの（2026-11-05 取得）。

- `f-a24-user.json` — `GET /users/f-a24` の一部
- `f-a24-repos.json` — `GET /users/f-a24/repos?per_page=100` の一部（53件）

`created_at` は取得時に日付までしか保存していないため、時刻は `T00:00:00Z` で埋めている。
実際のレスポンスには他のフィールドも多数含まれるので、デコーダーは**未知のフィールドを無視する**こと。
