# Results

Measured 2026-10-02 on a MacBook Pro, Apple M1 Pro, 32GB RAM, macOS 26.3.1, GNU Emacs 31.0.50, Org 9.7.11, harness version 3. 1k, 10k and the saves are medians of 3 runs; 100k is a single run.

- `vulpea-master` is unreleased vulpea with default settings; `vulpea-tuned` is the same revision with the settings its README recommends for speed (`vulpea-db-async-extraction 'full`, `single-temp-buffer` parsing, no plain-link indexing). The other tools run with their defaults.
- org-roam's first run at 100k was not measured separately: enabling `org-roam-db-autosync-mode` runs `org-roam-db-sync` synchronously, so it is the cold index (75.5 min), blocking throughout.
- Supertag's first run at 100k was stopped after 211 minutes, not finished.
- Supertag applies the deletion of a removed heading after the save itself (its save runs waited for that before exiting); this does not affect the save numbers.

## Versions

- org-roam: 2.3.1
- org-node: 3.18.3
- supertag: 3cae90e
- vulpea-master: f3af60a
- vulpea-tuned: f3af60a

### Cold index (synchronous, nothing else running)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 6.0s | 1.4min | 75.5min |
| org-node | 558ms | 2.7s | 20.2s |
| supertag | 5.5s | 1.1min | 37.4min |
| vulpea-master | 2.6s | 21.8s | 4.2min |
| vulpea-tuned | 1.8s | 14.3s | 3.0min |

### First run on an empty index, until every note is indexed

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.1s | 48.9s | - |
| org-node | 526ms | 2.9s | 17.2s |
| supertag | 26.3s | 7.9min | not done after 211.0min |
| vulpea-master | 3.1s | 26.9s | 5.6min |
| vulpea-tuned | 3.0s | 22.2s | 5.0min |

### First run: longest freeze while indexing

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 5.1s | 48.9s | - |
| org-node | 21ms | 1.9s | 5.3s |
| supertag | 510ms | 3.7s | not done after 211.0min |
| vulpea-master | 75ms | 233ms | 740ms |
| vulpea-tuned | 14ms | 19ms | 184ms |

### Warm start, until a note can be looked up

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 289ms | 3.3s | 38.7s |
| org-node | 546ms | 2.6s | 18.3s |
| supertag | 181ms | 1.1s | 10.2s |
| vulpea-master | 34ms | 36ms | 40ms |
| vulpea-tuned | 33ms | 38ms | 43ms |

### Open the find command (until the minibuffer)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 67ms | 759ms | 9.6s |
| org-node | 0.2ms | 0.7ms | 8ms |
| supertag | 4ms | 37ms | 925ms |
| vulpea-master | 0.2ms | 0.6ms | 6ms |
| vulpea-tuned | 0.2ms | 0.8ms | 7ms |

### Backlinks of the hub note, first call

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 152ms | 1.4s | 15.8s |
| org-node | 0.8ms | 6ms | 44ms |
| supertag | 6ms | 31ms | 720ms |
| vulpea-master | 14ms | 96ms | 1.7s |
| vulpea-tuned | 14ms | 92ms | 1.8s |

### Backlinks of the hub note, median of 5

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 148ms | 1.3s | 15.8s |
| org-node | 0.2ms | 0.9ms | 23ms |
| supertag | 2ms | 29ms | 395ms |
| vulpea-master | 5ms | 53ms | 794ms |
| vulpea-tuned | 4ms | 52ms | 811ms |

### Saving a large file (1k-note corpus)

| tool | 1MB longest freeze | 1MB until findable | 10MB longest freeze | 10MB until findable |
|---|---|---|---|---|
| org-roam | 4.1s | 4.1s | 23.7s | 23.7s |
| org-node | 19ms | 1.0s | 245ms | 11.3s |
| supertag | 1.2s | 1.7s | 11.3s | 11.8s |
| vulpea-master | 244ms | 1.8s | 1.5s | 7.3s |
| vulpea-tuned | 19ms | 1.6s | 21ms | 5.3s |

### Sanity: what each tool counted

| tool | notes 1000 | notes 10000 | notes 100000 | candidates 1000 | candidates 10000 | candidates 100000 | backlinks 1000 | backlinks 10000 | backlinks 100000 |
|---|---|---|---|---|---|---|---|---|---|
| org-roam | 1431 | 14584 | 144989 | 1621 | 16655 | 165090 | 371 | 3476 | 34961 |
| org-node | 1431 | 14584 | 144989 | 1614 | 16289 | 151938 | 371 | 3476 | 34961 |
| supertag | 1431 | 14584 | 144989 | 1431 | 14584 | 144989 | 369 | 3473 | 34959 |
| vulpea-master | 1431 | 14584 | 144989 | 1621 | 16655 | 165090 | 371 | 3476 | 34961 |
| vulpea-tuned | 1431 | 14584 | 144989 | 1621 | 16655 | 165090 | 371 | 3476 | 34961 |
