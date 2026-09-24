#!/usr/bin/env bash
# Run the benchmark suite.
#
#   ./run.sh install [TOOL...]           install tools into .deps/
#   ./run.sh corpus N...                 generate corpora of N notes
#   ./run.sh index TOOL... -- N...       cold, warm, find, backlinks
#   ./run.sh save TOOL...                save-1mb and save-10mb
#   ./run.sh report                      print results/raw.jsonl as tables
#
# REPEAT (default 3) sets how many times each operation runs; the report
# takes the median.  EMACS picks the Emacs binary (default: emacs).

set -euo pipefail
cd "$(dirname "$0")"

EMACS=${EMACS:-emacs}
REPEAT=${REPEAT:-3}
ALL_TOOLS=(org-roam org-node supertag vulpea)

corpus_dir() { echo "data/corpus-$1"; }

bench() {
  local tool=$1 corpus=$2 op=$3
  printf '%-14s %-18s %-10s ' "$tool" "$(basename "$corpus")" "$op"
  "$EMACS" -Q --batch -l bench.el "$tool" "$corpus" "$op" 2>&1 \
    | grep -E '^RESULT|Error' | sed 's/^RESULT //' | tail -1
}

cmd=${1:-}; shift || true
case "$cmd" in
  install)
    for tool in "${@:-${ALL_TOOLS[@]}}"; do
      "$EMACS" -Q --batch -l install.el "$tool" 2>&1 | grep -E '^Installed|Error' || true
    done ;;
  corpus)
    for n in "$@"; do
      dir=$(corpus_dir "$n")
      [ -f "$dir/corpus.eld" ] || "$EMACS" -Q --batch -l corpus.el "$dir" "$n"
    done
    [ -f data/corpus-save/corpus.eld ] || "$EMACS" -Q --batch -l corpus.el data/corpus-save 1000 big ;;
  index)
    tools=(); while [ $# -gt 0 ] && [ "$1" != "--" ]; do tools+=("$1"); shift; done
    shift || true
    for n in "$@"; do
      for tool in "${tools[@]}"; do
        for _ in $(seq "$REPEAT"); do
          bench "$tool" "$(corpus_dir "$n")" cold
          for op in warm find backlinks; do bench "$tool" "$(corpus_dir "$n")" "$op"; done
        done
      done
    done ;;
  save)
    for tool in "${@:-${ALL_TOOLS[@]}}"; do
      bench "$tool" data/corpus-save cold
      for _ in $(seq "$REPEAT"); do
        for op in save-1mb save-10mb; do bench "$tool" data/corpus-save "$op"; done
      done
    done ;;
  report)
    "$EMACS" -Q --batch -l report.el ;;
  _one)
    bench "$1" "$2" "$3" ;;
  *)
    sed -n '2,12p' "$0"; exit 1 ;;
esac
