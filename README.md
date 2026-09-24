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
| `backlinks` | Fetching the notes that link to the most linked note: the first call, and the median of five. |
| `save-1mb`, `save-10mb` | Visiting a large file, adding a heading with a new ID, saving, and waiting until the new note can be looked up by ID. Reported as the longest stretch Emacs was blocked (what you feel as a freeze) and the time until the note is findable. |

Some numbers are not like-for-like, by design of the packages:

- org-node keeps nothing on disk and rebuilds its cache in every session, in
  parallel subprocesses, so its `warm` is a full index. It builds its
  completion candidates while indexing, so its `find` has almost nothing
  left to do.
- Supertag's `warm` is loading its saved store; its periodic scan for
  external changes runs every 15 minutes and is not part of any number.
- Several packages memoize query results, which is why `backlinks` reports
  the first call separately.

## How the measurement works

Batch Emacs has no user and is never idle, so `bench.el` plays the user
who saves and then waits: it lets timers and subprocess output run through
`accept-process-output` in 10ms slices, and runs idle timers by hand once
their delay has passed (each once, as in one idle period). Any slice that
overruns is time Emacs spent blocked; the longest overrun is the freeze.

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
Results are appended to `results/raw.jsonl`, one JSON line per run, with
the Emacs, Org and package versions it ran against.

Tools and versions are pinned in `tools.el`: archive packages install the
version MELPA Stable serves, git packages a fixed revision. The adapters
are in `adapters/`; each defines the same eight functions.

## Results

See [RESULTS.md](RESULTS.md) for the latest run, with the machine it ran
on.

## License

GPL-3.0-or-later.
