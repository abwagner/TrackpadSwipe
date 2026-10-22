#!/bin/sh
# Keep routine development out of the public release repository.
set -eu
cd "$(dirname "$0")/.."
task_private_url=$(git remote get-url --push origin)
task_public_url=$(git remote get-url public-release)
if [ "$task_private_url" = "$task_public_url" ]; then
  printf 'Refusing to synchronize development into the public release repository.\n' >&2
  exit 1
fi
git push forgejo main
git push forgejo --tags
git fetch forgejo main --tags
git push origin refs/remotes/forgejo/main:refs/heads/main
git push origin --tags
