#!/usr/bin/env bash
# On the instance: install the tools, generate the corpora, run the
# benchmark matrix.
#
#   remote-run.sh "TREES" "TOOLS" SIZES OPS ROUNDS
#
# TREES are the names of vulpea checkouts copied to /mnt/bench/trees;
# TOOLS lists every tool to run, trees included.  SIZES and OPS are
# comma separated.  Each round runs every tool once per size and op, so
# tools interleave and drift on the machine hits them alike.
set -euo pipefail
TREES=$1
TOOLS=$2
SIZES=${3//,/ }
OPS=${4//,/ }
ROUNDS=$5
cd /mnt/bench/onb

for name in $TREES; do
  # A tool for the tree: vulpea's dependencies from the archives, and
  # vulpea itself as a package directory made from the copied sources
  sed -i "s|^(provide 'tools)|(setq bench-tools (append bench-tools '(($name :adapter vulpea :packages (emacsql s dash)))))\n(provide 'tools)|" tools.el
  emacs -Q --batch -l install.el "$name" 2>&1 | grep -E '^Installed|Error' || true
  pkg=.deps/$name/vulpea-0
  mkdir -p "$pkg"
  cp "/mnt/bench/trees/$name"/*.el "$pkg/"
  rm -f "$pkg/vulpea-pkg.el" "$pkg/vulpea-autoloads.el"
  echo "(define-package \"vulpea\" \"0\" \"$name\" '((emacs \"29.1\")))" > "$pkg/vulpea-pkg.el"
  emacs -Q --batch --eval "(progn (require 'package) (package-generate-autoloads \"vulpea\" (expand-file-name \"$pkg\")))"
  emacs -Q --batch --eval "(progn (setq package-user-dir (expand-file-name \".deps/$name\")) (package-initialize))" \
    -f batch-byte-compile $(ls "$pkg"/vulpea*.el | grep -v -e '-pkg\.el$' -e '-autoloads\.el$') \
    > "compile-$name.log" 2>&1 || true
  if grep -E ':[0-9]+:[0-9]+: Error' "compile-$name.log"; then exit 1; fi
  [ "$(ls "$pkg"/*.elc | wc -l)" -gt 10 ] || { cat "compile-$name.log"; exit 1; }
  echo "tree $name installed"
done
for tool in $TOOLS; do
  case " $TREES " in *" $tool "*) ;; *)
    emacs -Q --batch -l install.el "$tool" 2>&1 | grep -E '^Installed|Error' || true ;;
  esac
done

for n in $SIZES; do
  [ -f "data/corpus-$n/corpus.eld" ] || emacs -Q --batch -l corpus.el "data/corpus-$n" "$n" | tail -1
done

for round in $(seq "$ROUNDS"); do
  for n in $SIZES; do
    for tool in $TOOLS; do
      for op in $OPS; do
        printf 'round %s %-12s corpus-%-7s %-10s ' "$round" "$tool" "$n" "$op"
        emacs -Q --batch -l bench.el "$tool" "data/corpus-$n" "$op" 2>&1 \
          | grep -E '^RESULT|Error' | sed 's/^RESULT //' | tail -1
      done
    done
  done
done
echo RUN-OK
