# Results

Measured 2026-10-08 on AWS EC2 c7gd.2xlarge instances (8 Graviton cores, 16GB, local NVMe for all tool state), eu-central-1, GNU Emacs 30.2 built from source, Org 9.7.11, harness version 4. The sweep ran as five runs on fresh instances of the same type: 1k and 10k notes (3 rounds), the save corpus (3 rounds), 100k notes for org-node and vulpea (2 rounds), 100k notes for org-roam and Supertag (1 round), and Supertag's first run at 100k (1 round). Within a run, tools interleave round by round on one machine. Numbers are medians across rounds.

- `vulpea-master` is vulpea's master branch with default settings; `vulpea-tuned` is the same revision with the settings its README recommends for speed (`vulpea-db-async-extraction 'full`, `single-temp-buffer` parsing, no plain-link indexing). The other tools run with their defaults.
- org-roam's first run at 100k was not measured separately: enabling `org-roam-db-autosync-mode` runs `org-roam-db-sync` synchronously, so it is the cold index, blocking throughout.
- Backlinks return different things: org-node returns link records, Supertag one aggregated item per source, org-roam and vulpea full notes with their data. The first call is reported on its own; later calls are averaged over ten, so garbage collection counts evenly for every tool.
- The corpus is generated from a seeded random state, but the generator's output depends on the Emacs version: the 1k corpus has 1,429 notes under Emacs 30.2 and 1,431 under Emacs 31. Compare numbers from the same Emacs only.

## Versions

- org-roam: 2.3.1
- org-node: 3.18.3
- supertag: 1903115
- vulpea-master: d9be363
- vulpea-tuned: d9be363

### Cold index (synchronous, nothing else running)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.7s | 1.5min | 73.9min |
| org-node | 250ms | 1.6s | 15.4s |
| supertag | 1.7s | 16.4s | 2.7min |
| vulpea-master | 2.7s | 27.2s | 4.9min |
| vulpea-tuned | 1.8s | 18.0s | 3.2min |

### First run on an empty index, until every note is indexed

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.9s | 1.5min | - |
| org-node | 519ms | 1.7s | 15.1s |
| supertag | 7.4s | 23.2s | 2.8min |
| vulpea-master | 2.5s | 19.5s | 3.3min |
| vulpea-tuned | 2.0s | 19.2s | 3.3min |

### First run: longest freeze while indexing

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.9s | 1.5min | - |
| org-node | 36ms | 565ms | 3.4s |
| supertag | 139ms | 977ms | 1.6s |
| vulpea-master | 29ms | 78ms | 260ms |
| vulpea-tuned | 19ms | 28ms | 254ms |

### Warm start, until a note can be looked up

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 175ms | 1.7s | 16.1s |
| org-node | 225ms | 1.6s | 15.2s |
| supertag | 115ms | 570ms | 5.4s |
| vulpea-master | 7ms | 8ms | 9ms |
| vulpea-tuned | 7ms | 8ms | 8ms |

### Open the find command (until the minibuffer)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 69ms | 683ms | 7.8s |
| org-node | 0.2ms | 2ms | 19ms |
| supertag | 4ms | 50ms | 709ms |
| vulpea-master | 0.3ms | 2ms | 25ms |
| vulpea-tuned | 0.3ms | 2ms | 21ms |

### Backlinks of the hub note, first call

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 154ms | 1.4s | 14.0s |
| org-node | 0.4ms | 4ms | 47ms |
| supertag | 4ms | 39ms | 411ms |
| vulpea-master | 7ms | 72ms | 807ms |
| vulpea-tuned | 7ms | 71ms | 784ms |

### Backlinks of the hub note, mean of 10 later calls

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 144ms | 1.4s | 14.0s |
| org-node | 0.1ms | 1ms | 26ms |
| supertag | 4ms | 38ms | 454ms |
| vulpea-master | 10ms | 90ms | 983ms |
| vulpea-tuned | 10ms | 91ms | 939ms |

### Saving a large file (1k-note corpus)

| tool | 1MB longest freeze | 1MB until findable | 10MB longest freeze | 10MB until findable |
|---|---|---|---|---|
| org-roam | 6.7s | 6.7s | 35.7s | 35.7s |
| org-node | 42ms | 944ms | 390ms | 17.6s |
| supertag | 733ms | 1.2s | 6.7s | 7.2s |
| vulpea-master | 182ms | 795ms | 1.8s | 6.2s |
| vulpea-tuned | 3ms | 703ms | 15ms | 5.4s |

### Sanity: what each tool counted

| tool | notes 1000 | notes 10000 | notes 100000 | candidates 1000 | candidates 10000 | candidates 100000 | backlinks 1000 | backlinks 10000 | backlinks 100000 |
|---|---|---|---|---|---|---|---|---|---|
| org-roam | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| org-node | 1429 | 14582 | 144987 | 1613 | 16290 | 151934 | 371 | 3477 | 34971 |
| supertag | 1429 | 14582 | 144987 | 1429 | 14582 | 144987 | 369 | 3474 | 34968 |
| vulpea-master | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| vulpea-tuned | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |

Raw results: [results/sweeps/2026-10-08-aws.jsonl](results/sweeps/2026-10-08-aws.jsonl). The previous sweep is in [results/sweeps/2026-10-05-aws.jsonl](results/sweeps/2026-10-05-aws.jsonl).
