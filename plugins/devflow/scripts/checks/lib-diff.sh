# Shared by the checks: the lines a branch ADDED, with their line numbers in
# the new file, so a check judges only what this branch wrote and an old
# line never counts against it.
#
# added_lines <base-ref>  ->  "path<TAB>line<TAB>text" for every added line
added_lines() {
  git diff --no-color --no-ext-diff -U0 "$1...HEAD" | awk '
    /^\+\+\+ /   { path = substr($0, 5); sub(/^b\//, "", path); next }
    /^@@ /       { split($3, p, ","); ln = substr(p[1], 2) + 0; next }
    /^\+/        { if (path != "/dev/null") printf "%s\t%d\t%s\n", path, ln, substr($0, 2); ln++; next }
  '
}
