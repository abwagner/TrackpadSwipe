#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build/signing-check
printf 'int main(void) { return 1; }\n' > build/signing-check/one.c
printf 'int main(void) { return 2; }\n' > build/signing-check/two.c
clang build/signing-check/one.c -o build/signing-check/one
clang build/signing-check/two.c -o build/signing-check/two
for task_version in one two; do
  ./sign.sh "build/signing-check/$task_version"
  codesign -d -r- "build/signing-check/$task_version" 2>&1 \
    | sed -n 's/^designated => //p' > "build/signing-check/$task_version.requirement"
  test -s "build/signing-check/$task_version.requirement"
done
cmp build/signing-check/one.requirement build/signing-check/two.requirement
if cmp -s build/signing-check/one build/signing-check/two; then
  printf 'Expected different test executables.\n' >&2;exit 1
fi
task_requirement=$(cat build/signing-check/one.requirement)
codesign --verify --strict --test-requirement "=$task_requirement" build/signing-check/two
printf 'PASS: different builds share the same certificate-pinned app identity.\n'
