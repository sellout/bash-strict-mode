## An ERR trap is not inherited by a shell function unless `errtrace` is set,
## so without it this failure aborts the script with no diagnostic at all —
## `errexit` still exits, but the trap never runs to say why or where.
##
## The `echo` would run if `errexit` stopped applying inside the function, which
## would make this pass for the wrong reason.
fail_in_function() {
  cat nothing-here-man
  echo "kept going"
}

fail_in_function
