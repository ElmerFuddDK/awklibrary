
test -z "$AWKPROGRAM" && AWKPROGRAM=awk
TEST=$(readlink -f "$0" | awk -F '/' '{ print $(NF-1) FS $NF }')
ERRORCOLOR="\033[0;31m"
GREENCOLOR="\033[0;32m"
CANCELCOLOR="\033[0m"

# Function for extracting contents between sections of the test file
function getContents() { cat "$0" | awk -v cat="$1" '/^---\s+[a-z]+\s+---$/ { if ($0 ~ "^---\\s+" cat "\\s+---$") {f=1; next} else if (f) {exit} } f {print}'; }

EXPECTDATA="$(getContents "expect")"

# If it has data
if awk '/^---\s+data\s+---$/ {r=1; exit} END { exit (r?0:1) }' "$0"
then
  DATA="$("$AWKPROGRAM" ${AWKPARAMS[@]} -f <(getContents "script") 2>&1 < <(getContents "data"))"
else
  DATA="$("$AWKPROGRAM" ${AWKPARAMS[@]} -f <(getContents "script") 2>&1)"
fi

if test "$EXPECTDATA" = "$DATA"
then
  echo -e "$GREENCOLOR$TEST$CANCELCOLOR OK"
  exit 0
elif test -n "$TESTQUIET"
then
  echo -e "$ERRORCOLOR$TEST$CANCELCOLOR failed"
else
  echo -e "$ERRORCOLOR$TEST$CANCELCOLOR failed with"
  echo "$DATA" | awk '{print "  |", $0}'
  echo " Expected:"
  echo "$EXPECTDATA" | awk '{print "  |", $0}'
fi

exit 1
