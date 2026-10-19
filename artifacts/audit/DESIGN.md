# Swatantra UI — professional news-app notes

References: Apple News (lead photo, quiet chrome), The Guardian (kicker + serif hierarchy), Substack (action chips, author desk), Signal (bottom sheets at the moment of need), Linear (spacing scale, radius, skeletons).

| Screen | Ideal | What we shipped |
|---|---|---|
| Feed | Photo-first lead, compact rows, filter chips, skeleton while querying. Never ask for a wallet. | Pill filters, FeedSkeleton, two-pane desktop, no login. |
| Article | Wide serif headline, corroboration seal, capture-verified badge, On Arkiv link. Tips as pills that open a sheet. | CaptureSeal + CorroborationStamp + On Arkiv. Tip / Share / Corroborate / Follow / Report as pills. |
| Post | Camera-first dark capture, then a paper compose column. Sign-in only when capturing or publishing. | Shutter and gallery gate; opening /post does not. |
| Verify | Single paste + file action, match/mismatch as a seal not a dump. | CaptureSeal on match, skeleton while looking up. |
| Tracker | Quiet log of notices; log action gated. | Log a notice → Sign in sheet → Report sheet. Placeholder notices replaced on Tiramisu. |
| Me | Wallet as a small identity card; Anon Aadhaar as a verified-journalist badge. | Wash card, GLM balance, badge, Get GLM. |
| Journalist | Proof first; register gated. Nullifier only. | Prove with saved identity; Create journalist entity is gated. |
| Sheets | Sign in and Tip rise at the action, never on launch. | SignInSheet, TipSheet, ReportSheet. |

Tokens: paper `#FFFFFF`, ink `#111111`, muted `#5C5C5C`, magenta `#DC2460`, wash `#F6F5F2`, line `#E6E4DF`, space 4–48, radius 8/12/16/pill, elevation 8–16px blur.
