# Results

Measured 2026-09-24 on a MacBook Pro, Apple M1 Pro, 32GB RAM, macOS 26.3.1, GNU Emacs 31.0.50, Org 9.7.11. Every package ran with its default settings. 1k, 10k and the saves are medians of 3 runs; 100k is a single run. The 100k cold index was capped at 90 minutes; every tool finished within it.

`vulpea-master` is unreleased vulpea (the revision shown), included because it fixes a quadratic slowdown in 2.7.0's full sync.

## Versions

- org-roam: 2.3.1
- org-node: 3.18.3
- supertag: ff2d087
- vulpea: 2.7.0
- vulpea-master: 091828d

### Cold index

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 6.0s | 1.4min | 75.5min |
| org-node | 558ms | 2.7s | 20.2s |
| supertag | 5.8s | 1.1min | 44.7min |
| vulpea | 3.9s | 34.3s | 33.5min |
| vulpea-master | 2.7s | 24.3s | 4.6min |

### Warm start, until a note can be looked up

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 289ms | 3.3s | 38.7s |
| org-node | 546ms | 2.6s | 18.3s |
| supertag | 190ms | 1.2s | 10.6s |
| vulpea | 34ms | 37ms | 43ms |
| vulpea-master | 30ms | 38ms | 46ms |

### Open the find command (until the minibuffer)

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 67ms | 759ms | 9.6s |
| org-node | 0.2ms | 0.7ms | 8ms |
| supertag | 4ms | 39ms | 479ms |
| vulpea | 34ms | 270ms | 5.2s |
| vulpea-master | 48ms | 439ms | 5.3s |

### Backlinks of the hub note, first call

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 152ms | 1.4s | 15.8s |
| org-node | 0.8ms | 6ms | 44ms |
| supertag | 6ms | 36ms | 371ms |
| vulpea | 20ms | 230ms | 1.7s |
| vulpea-master | 42ms | 189ms | 1.9s |

### Backlinks of the hub note, median of 5

| tool | 1000 | 10000 | 100000 |
|---|---|---|---|
| org-roam | 148ms | 1.3s | 15.8s |
| org-node | 0.2ms | 0.9ms | 23ms |
| supertag | 3ms | 32ms | 376ms |
| vulpea | 7ms | 98ms | 1.7s |
| vulpea-master | 7ms | 105ms | 1.7s |

### Saving a large file (1k-note corpus)

| tool | 1MB longest freeze | 1MB until findable | 10MB longest freeze | 10MB until findable |
|---|---|---|---|---|
| org-roam | 4.1s | 4.1s | 23.7s | 23.7s |
| org-node | 25ms | 1.0s | 255ms | 7.6s |
| supertag | 1.1s | 1.6s | 11.0s | 12.7s |
| vulpea | 517ms | 590ms | 5.1s | 5.4s |
| vulpea-master | 494ms | 545ms | 4.6s | 5.0s |

### Sanity: what each tool counted

| tool | notes 1000 | notes 10000 | notes 100000 | candidates 1000 | candidates 10000 | candidates 100000 | backlinks 1000 | backlinks 10000 | backlinks 100000 |
|---|---|---|---|---|---|---|---|---|---|
| org-roam | 1431 | 14584 | 144989 | 1621 | 16655 | 165090 | 371 | 3476 | 34961 |
| org-node | 1431 | 14584 | 144989 | 1614 | 16289 | 151938 | 371 | 3476 | 34961 |
| supertag | 1431 | 14584 | 144989 | 1431 | 14584 | 144989 | 369 | 3473 | 34959 |
| vulpea | 1431 | 14584 | 144989 | 1621 | 16655 | 165090 | 371 | 3476 | 34961 |
| vulpea-master | 1431 | 14584 | 144989 | 1621 | 16655 | 165090 | 371 | 3476 | 34961 |
