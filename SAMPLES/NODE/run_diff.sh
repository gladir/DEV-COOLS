#!/bin/sh
# Compare la sortie de chaque programme (JSCW32 -run) a celle de Node.
# Usage : SAMPLES/NODE/run_diff.sh [chemin du compilateur]
JC=${1:-./JSCW32}
fail=0
for f in "$(dirname "$0")"/*.js; do
  "$JC" -run "$f" > /tmp/jscw_out.txt 2>&1
  node "$f" > /tmp/node_out.txt 2>&1
  if cmp -s /tmp/jscw_out.txt /tmp/node_out.txt; then echo "OK    $f"; else echo "DIFF  $f"; fail=1; fi
done
exit $fail
