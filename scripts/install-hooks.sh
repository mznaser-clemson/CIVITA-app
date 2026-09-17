#!/bin/sh
# One-time per clone: point git at the tracked hooks dir so the secret gate runs on every commit.
# Git ignores a hook without the executable bit, so we also (re)assert +x and verify both.
set -e

git config core.hooksPath scripts/githooks
chmod +x scripts/githooks/pre-commit 2>/dev/null || true

# Verify activation -- fail loudly if either piece is missing (a silent miss = no gate at all).
HP=$(git config --get core.hooksPath || echo '')
if [ "$HP" != "scripts/githooks" ]; then
  echo "✗ core.hooksPath is '$HP' (expected scripts/githooks)"; exit 1
fi
if [ ! -x scripts/githooks/pre-commit ]; then
  # On filesystems without an exec bit (some Windows checkouts) git uses the tracked mode 100755.
  MODE=$(git ls-files -s scripts/githooks/pre-commit | awk '{print $1}')
  if [ "$MODE" != "100755" ]; then
    echo "✗ scripts/githooks/pre-commit is not executable and its tracked mode is '$MODE' (expected 100755)"; exit 1
  fi
fi
echo "✓ core.hooksPath -> scripts/githooks; pre-commit executable — secret gate active"
