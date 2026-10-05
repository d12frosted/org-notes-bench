# Results

Measured 2026-10-05 on AWS EC2 c7gd.2xlarge instances (8 Graviton cores, 16GB, local NVMe for all tool state), eu-central-1, GNU Emacs 30.2 built from source, Org 9.7.11, harness version 3. The sweep ran as four runs on four fresh instances of the same type: 1k and 10k notes (3 rounds), the save corpus (3 rounds), 100k notes for org-node and vulpea (2 rounds), and 100k notes for org-roam and Supertag (1 round). Within a run, tools interleave round by round on one machine. Numbers are medians.

- `vulpea-master` is unreleased vulpea with default settings; `vulpea-tuned` is the same revision with the settings its README recommends for speed (`vulpea-db-async-extraction 'full`, `single-temp-buffer` parsing, no plain-link indexing). The other tools run with their defaults.
- First run at 100k was not measured for org-roam and Supertag. Enabling `org-roam-db-autosync-mode` runs `org-roam-db-sync` synchronously, so org-roam's first run is its cold index, blocking throughout. Supertag's first run at 100k did not finish within 3.5 hours in an earlier run.
- Backlinks return different things: org-node returns link records, Supertag one aggregated item per source, org-roam and vulpea full notes with their data.
- Supertag applies the deletion of a removed heading after the save itself; its save runs waited for that before exiting, which does not affect the save numbers.
- The corpus is generated from a seeded random state, but the generator's output depends on the Emacs version: the 1k corpus has 1,429 notes under Emacs 30.2 and 1,431 under Emacs 31. Compare numbers from the same Emacs only.

## Versions

- org-node: 3.18.3
- vulpea-master: 47512ef
- vulpea-tuned: 47512ef
- org-roam: 2.3.1
- supertag: ab53f23

### Cold index (synchronous, nothing else running)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 238ms | 1.6s | 14.7s |
| vulpea-master | 3.0s | 29.3s | 4.3min |
| vulpea-tuned | 2.0s | 19.8s | 2.9min |
| org-roam | 6.4s | 1.7min | 81.9min |
| supertag | 6.9s | 1.5min | 51.2min |

### First run on an empty index, until every note is indexed

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 517ms | 1.7s | 14.5s |
| vulpea-master | 2.6s | 20.7s | 3.1min |
| vulpea-tuned | 2.5s | 24.3s | 3.5min |
| org-roam | 6.9s | 1.7min | - |
| supertag | 27.5s | 8.8min | - |

### First run: longest freeze while indexing

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 44ms | 554ms | 2.8s |
| vulpea-master | 49ms | 73ms | 247ms |
| vulpea-tuned | 19ms | 23ms | 248ms |
| org-roam | 6.9s | 1.7min | - |
| supertag | 237ms | 6.5s | - |

### Warm start, until a note can be looked up

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 218ms | 1.6s | 14.6s |
| vulpea-master | 8ms | 8ms | 7ms |
| vulpea-tuned | 8ms | 8ms | 8ms |
| org-roam | 175ms | 1.7s | 16.0s |
| supertag | 145ms | 906ms | 8.9s |

### Open the find command (until the minibuffer)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 0.3ms | 2ms | 18ms |
| vulpea-master | 0.3ms | 2ms | 21ms |
| vulpea-tuned | 0.3ms | 2ms | 21ms |
| org-roam | 68ms | 707ms | 7.5s |
| supertag | 5ms | 58ms | 641ms |

### Backlinks of the hub note, first call

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 0.5ms | 4ms | 42ms |
| vulpea-master | 7ms | 72ms | 767ms |
| vulpea-tuned | 7ms | 72ms | 1.0s |
| org-roam | 156ms | 1.4s | 13.8s |
| supertag | 5ms | 49ms | 596ms |

### Backlinks of the hub note, median of 5

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-node | 0.1ms | 2ms | 17ms |
| vulpea-master | 7ms | 74ms | 767ms |
| vulpea-tuned | 7ms | 73ms | 1.0s |
| org-roam | 156ms | 1.4s | 13.9s |
| supertag | 5ms | 50ms | 587ms |

### Saving a large file (1k-note corpus)

| tool | 1MB longest freeze | 1MB until findable | 10MB longest freeze | 10MB until findable |
|---|---|---|---|---|
| org-node | 38ms | 947ms | 385ms | 16.0s |
| vulpea-master | 170ms | 772ms | 1.7s | 6.0s |
| vulpea-tuned | 2ms | 652ms | 14ms | 5.0s |
| org-roam | 6.6s | 6.6s | 35.3s | 35.3s |
| supertag | 1.3s | 1.8s | 12.9s | 13.4s |

### Sanity: what each tool counted

| tool | notes 1000 | notes 10000 | notes 100000 | candidates 1000 | candidates 10000 | candidates 100000 | backlinks 1000 | backlinks 10000 | backlinks 100000 |
|---|---|---|---|---|---|---|---|---|---|
| org-node | 1429 | 14582 | 144987 | 1613 | 16290 | 151934 | 371 | 3477 | 34971 |
| vulpea-master | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| vulpea-tuned | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| org-roam | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| supertag | 1429 | 14582 | 144987 | 1429 | 14582 | 144987 | 369 | 3474 | 34968 |

Raw results: [results/sweeps/2026-10-05-aws.jsonl](results/sweeps/2026-10-05-aws.jsonl), all four runs merged.
