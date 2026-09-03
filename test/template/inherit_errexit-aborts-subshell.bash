## This needs the `echo` to make the script succeed if `inherit_errexit` isn’t
## set.
RESULT=$(
  cat nothing-here-man
  echo "kept going"
)
echo "$RESULT"
