# org-notes-bench

A shared benchmark for Emacs packages that index Org notes by `org-id`:
[org-roam](https://github.com/org-roam/org-roam),
[org-node](https://github.com/meedstrom/org-node),
[Supertag](https://github.com/yibie/supertag) and
[vulpea](https://github.com/d12frosted/vulpea).

It measures what a user waits for, on the same generated notes, with each
package installed at a pinned version into its own package directory and
run in a fresh `emacs -Q --batch`. Everything needed to re-run it is here.

I maintain vulpea. The harness is written so that no tool gets a special
path: every measurement goes through each package's own commands and
public functions, and each adapter is a page of Lisp you can check. If an
adapter does not use your package the way you would, please open an
issue or a pull request; the numbers are only worth something if every
maintainer agrees their tool is measured fairly.

## What is measured

| Operation   | What it times |
|-------------|---------------|
| `cold`      | Building the index from nothing, until it is complete. |
| `warm`      | Starting in a new session with the index from `cold` on disk, the way a user's init would, until a known note can be looked up by ID. |
| `find`      | The package's find command (`org-roam-node-find`, `org-node-find`, `supertag-find-node`, `vulpea-find`) from the call until it opens the minibuffer, plus listing every candidate of its completion table. |
| `backlinks` | Fetching the notes that link to the most linked note: the first call, and the mean of ten calls after it (with their minimum, maximum and garbage collection time per call). |
| `save-1mb`, `save-10mb` | Visiting a large file, adding a heading with a new ID, saving, and waiting until the new note can be looked up by ID. Reported as the longest stretch Emacs was blocked (what you feel as a freeze) and the time until the note is findable. |

Some numbers are not like-for-like, by design of the packages:

- org-node keeps nothing on disk and rebuilds its cache in every session, in
  parallel subprocesses, so its `warm` is a full index. It builds its
  completion candidates while indexing, so its `find` has almost nothing
  left to do.
- Supertag's `warm` is loading its saved store; its periodic scan for
  external changes runs every 15 minutes and is not part of any number.
- Several packages memoize query results, which is why `backlinks` reports
  the first call separately. Later calls are averaged rather than taking a
  median: a call that allocates a lot triggers garbage collection on some
  calls and not others, and a median of a few calls depends on which ones
  catch it.

## How the measurement works

Batch Emacs has no user and is never idle, so `bench.el` plays the user
who saves and then waits: it lets timers and subprocess output run through
`accept-process-output` in 10ms slices, and runs idle timers by hand once
their delay has passed (each once, as in one idle period). Any slice that
overruns is time Emacs spent blocked; the longest overrun is the freeze.
Editor features that run on idle timers and have nothing to do with the
notes (`show-paren-mode`, `global-eldoc-mode`) are turned off, since they
would otherwise run in the visited buffer and count against whichever
tool is being measured.

Each tool's state (database, cache files, `org-id-locations`, even
`user-emacs-directory`) lives under `data/state/TOOL/CORPUS`, so tools
never share anything. `cold` deletes that state first; the other
operations reuse it.

## The corpus

`corpus.el` writes N notes, 100 per directory, from a seeded random
state, so the same N always produces the same bytes. Each note has a
file-level `:ID:`, a `#+title`, `#+filetags`, sometimes `ROAM_ALIASES`,
paragraphs with `id:` links to recent notes, and up to four headings, a
third of which have their own `:ID:`. About a fifth of all notes link to
note 0, the hub used by `backlinks`. The save benchmarks use a separate
corpus of 1000 notes plus a 1MB and a 10MB file of headings.

Aliases use `ROAM_ALIASES`, the convention org-roam and org-node read; the
vulpea adapter is configured to read that property too.

## Running it

```sh
./run.sh install                                   # into .deps/
./run.sh corpus 1000 10000 100000                  # into data/
./run.sh index org-roam org-node supertag vulpea -- 1000 10000
./run.sh save org-roam org-node supertag vulpea
./run.sh report
```

`REPEAT` (default 3) sets how many runs each number is the median of.
Local results are appended to `results/raw.jsonl` (not tracked), one JSON line per run, with
the Emacs, Org and package versions it ran against.

Tools and versions are pinned in `tools.el`: archive packages install the
version MELPA Stable serves, git packages a fixed revision. The adapters
are in `adapters/`; each defines the same eight functions.

### On a clean machine (AWS)

A laptop that is busy with anything else makes the numbers noisy.
`aws/bench.sh` runs the benchmark on a fresh EC2 instance instead and
needs nothing but a valid session (`aws login`) and a default VPC:

```sh
aws/bench.sh --tool vulpea-master --tool org-node --sizes 10000 --ops cold,first-run
aws/bench.sh --tree base=../vulpea-main --tree branch=../vulpea \
  --sizes 10000,100000 --ops first-run --repeat 3
```

The save benchmarks run on their own corpus, `--sizes save`, and need
an index first: `--ops cold,save-1mb,save-10mb`.

`--tool` takes a tool from `tools.el`; `--tree NAME=DIR` benchmarks the
vulpea sources of a local checkout as they are on disk, which is how to
compare a branch with its base. Tools take turns in every round, so
whatever the machine does hits all of them alike.

The default instance, `c7gd.2xlarge` (8 Graviton cores, 16GB), has a
local NVMe disk, and the corpora and every tool's state live on it.
The root disk of an EC2 instance is network storage, where each `fsync`
costs milliseconds; on it, a tool that commits per file looks far
slower than on a laptop. `--state tmpfs` keeps the state in memory
instead, to isolate a change that only saves CPU. `fswatch` is
installed as it usually is on macOS: without it vulpea falls back to
polling for external changes, which dominates a first run at 100k notes.
Emacs is built from source (`--emacs`, default 30.2), which takes about
ten minutes of each run.

The run's results, logs and a summary of medians (`aws/compare.el`)
land in `results/aws/RUN/`. The script removes the instance, its key
pair and its security group when it exits, also on failure or Ctrl-C;
the instance terminates itself after `--max-hours` (default 3) in case
the script cannot. An hour costs about $0.40.

## Results

See [RESULTS.md](RESULTS.md) for the latest run, with the machine it ran
on.

## License

GPL-3.0-or-later.
