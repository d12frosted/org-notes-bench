# Results

Measured 2026-10-08 on AWS EC2 c7gd.2xlarge instances (8 Graviton cores, 16GB, local NVMe for all tool state), eu-central-1, GNU Emacs 30.2 built from source, Org 9.7.11, harness version 4. The sweep ran as five runs on fresh instances of the same type: 1k and 10k notes (3 rounds), the save corpus (3 rounds), 100k notes for org-node and vulpea (2 rounds), 100k notes for org-roam and Supertag (1 round), and Supertag's first run at 100k (1 round). Within a run, tools interleave round by round on one machine. Numbers are medians across rounds.

Supertag was measured again on 2026-10-09 at v0.3.0 (`dcd3dc2`), at 100k notes and on the save corpus (3 rounds each, on two more instances of the same type), with org-node in both runs as an anchor. Its rows below come from those runs; it was not re-measured at 1k and 10k, so those cells are empty. The 0.2.0 numbers are in the 2026-10-08 sweep. Supertag's parser process reads the large files that changed last ahead of time once Emacs is idle; the save benchmark saves after 5 idle seconds, when that read-ahead has been asked for, so its save numbers are for a file being read ahead, not a cold one.

- `vulpea-master` is vulpea's master branch with default settings; `vulpea-tuned` is the same revision with the settings its README recommends for speed (`vulpea-db-async-extraction 'full`, `single-temp-buffer` parsing, no plain-link indexing). The other tools run with their defaults.
- org-roam's first run at 100k was not measured separately: enabling `org-roam-db-autosync-mode` runs `org-roam-db-sync` synchronously, so it is the cold index, blocking throughout.
- Backlinks return different things: org-node returns link records, Supertag one aggregated item per source, org-roam and vulpea full notes with their data. The first call is reported on its own; later calls are averaged over ten, so garbage collection counts evenly for every tool.
- Instances of the same type differ: the same vulpea revision indexed 100k files in 258s on one c7gd.2xlarge and 295s on another, about 15% apart. Rows from one run (one instance, tools interleaved) compare well; rows from different runs only roughly. In the 100k tables, org-node and vulpea come from one run, org-roam from another, and Supertag from a third, where org-node indexed 100k files in 12.9s against 15.4s and started a new session in 13.0s against 15.2s, so that instance was about 15% faster on bulk work; org-node's find and backlinks there were within 6%. On the save corpus, org-node's 1MB save matched the 2026-10-08 run within 2% and its 10MB save was findable 14% sooner.
- The corpus is generated from a seeded random state, but the generator's output depends on the Emacs version: the 1k corpus has 1,429 notes under Emacs 30.2 and 1,431 under Emacs 31. Compare numbers from the same Emacs only.

## Versions

- org-roam: 2.3.1
- org-node: 3.18.3
- supertag: dcd3dc2
- vulpea-master: d9be363
- vulpea-tuned: d9be363

### Cold index (synchronous, nothing else running)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.7s | 1.5min | 73.9min |
| org-node | 250ms | 1.6s | 15.4s |
| supertag | - | - | 2.3min |
| vulpea-master | 2.7s | 27.2s | 4.9min |
| vulpea-tuned | 1.8s | 18.0s | 3.2min |

### First run on an empty index, until every note is indexed

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.9s | 1.5min | - |
| org-node | 519ms | 1.7s | 15.1s |
| supertag | - | - | 1.9min |
| vulpea-master | 2.5s | 19.5s | 3.3min |
| vulpea-tuned | 2.0s | 19.2s | 3.3min |

### First run: longest freeze while indexing

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.9s | 1.5min | - |
| org-node | 36ms | 565ms | 3.4s |
| supertag | - | - | 600ms |
| vulpea-master | 29ms | 78ms | 260ms |
| vulpea-tuned | 19ms | 28ms | 254ms |

### Warm start, until a note can be looked up

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 175ms | 1.7s | 16.1s |
| org-node | 225ms | 1.6s | 15.2s |
| supertag | - | - | 3.5s |
| vulpea-master | 7ms | 8ms | 9ms |
| vulpea-tuned | 7ms | 8ms | 8ms |

### Open the find command (until the minibuffer)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 69ms | 683ms | 7.8s |
| org-node | 0.2ms | 2ms | 19ms |
| supertag | - | - | 37ms |
| vulpea-master | 0.3ms | 2ms | 25ms |
| vulpea-tuned | 0.3ms | 2ms | 21ms |

### Backlinks of the hub note, first call

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 154ms | 1.4s | 14.0s |
| org-node | 0.4ms | 4ms | 47ms |
| supertag | - | - | 407ms |
| vulpea-master | 7ms | 72ms | 807ms |
| vulpea-tuned | 7ms | 71ms | 784ms |

### Backlinks of the hub note, mean of 10 later calls

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 144ms | 1.4s | 14.0s |
| org-node | 0.1ms | 1ms | 26ms |
| supertag | - | - | 414ms |
| vulpea-master | 10ms | 90ms | 983ms |
| vulpea-tuned | 10ms | 91ms | 939ms |

### Saving a large file (1k-note corpus)

| tool | 1MB longest freeze | 1MB until findable | 10MB longest freeze | 10MB until findable |
|---|---|---|---|---|
| org-roam | 6.7s | 6.7s | 35.7s | 35.7s |
| org-node | 42ms | 944ms | 390ms | 17.6s |
| supertag | 12ms | 436ms | 18ms | 1.5s |
| vulpea-master | 182ms | 795ms | 1.8s | 6.2s |
| vulpea-tuned | 3ms | 703ms | 15ms | 5.4s |

### Sanity: what each tool counted

| tool | notes 1000 | notes 10000 | notes 100000 | candidates 1000 | candidates 10000 | candidates 100000 | backlinks 1000 | backlinks 10000 | backlinks 100000 |
|---|---|---|---|---|---|---|---|---|---|
| org-roam | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| org-node | 1429 | 14582 | 144987 | 1613 | 16290 | 151934 | 371 | 3477 | 34971 |
| supertag | - | - | 144987 | - | - | 144987 | - | - | 34968 |
| vulpea-master | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |
| vulpea-tuned | 1429 | 14582 | 144987 | 1620 | 16653 | 165085 | 371 | 3477 | 34971 |

Raw results: [results/sweeps/2026-10-08-aws.jsonl](results/sweeps/2026-10-08-aws.jsonl), and Supertag v0.3.0 with its org-node anchor in [results/sweeps/2026-10-09-aws.jsonl](results/sweeps/2026-10-09-aws.jsonl). The previous sweep is in [results/sweeps/2026-10-05-aws.jsonl](results/sweeps/2026-10-05-aws.jsonl).
