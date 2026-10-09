# Full-player fresh start — 2026-10-09

Authorized scope: every player.

The next published build uses GemSoul_PlayerData_v2. Profiles, inventory, currency, equipment, tutorial/task completion and other profile progression start from normal new-player defaults. Equipment trade recovery follows the profile namespace automatically. MarketVersion 2 isolates old listings, mailbox payouts and cross-server notifications. Referrals and leaderboard scores now follow the profile namespace too.

FreshStart remains false: this is a one-time reset per account on first join to this generation, not a reset on every join. Old stores remain untouched as inactive backups; no records were deleted directly from Roblox. Feedback reports and global item serial counters are retained because they are operational records rather than player progression. Roblox account entitlements such as game passes are external to saved profiles and are not revoked.

Deployment: sync the updated project in Studio, publish to the existing Saga Miners place, then restart all outdated servers. Until publication, the live game still uses the old data. Do not change the namespace again after deployment unless intentionally starting another wipe. Do not run old servers alongside the new build during testing; an old server will still show old progress. Keep the v2 build configured while playtesting to verify that new progress persists on a second join.

Check: first join shows starter flow and new-player defaults; previous inventory and objectives are absent; Market and leaderboards have no prior-generation records; complete one task, leave and rejoin, and verify the new progress saves.
