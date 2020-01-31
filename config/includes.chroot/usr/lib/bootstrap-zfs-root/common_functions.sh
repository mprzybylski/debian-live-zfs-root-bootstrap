TOP_LEVEL_SCRIPT=$(basename "${BASH_SOURCE[$((${#BASH_SOURCE[@]}-1))]}")

# Causes the calling script to exit with an error if GNU getopt is not in $PATH
exit_if_gnu_getopt_not_in_path(){
  if ! [[ $(getopt -V ) =~ ^getopt[[:space:]]from[[:space:]]util-linux[[:space:]][0-9](\.[0-9]+)+ ]]; then
    >&2 echo "Error: $TOP_LEVEL_SCRIPT requires the GNU getopt utility, but it does not appear"
    >&2 echo "to be in \$PATH."
  fi
}

# Causes the calling script to exit with an error if the effective user ID is not root.
exit_if_not_root(){

  if [ $EUID -ne 0 ]; then
    >&2 echo "Error: $TOP_LEVEL_SCRIPT must run as root.  Exiting."
    exit 1
  fi
}

# From zpool(8) man page:
#             The pool name must begin with a let‐
#             ter, and can only contain alphanumeric characters as well as un‐
#             derscore ("_"), dash ("-"), colon (":"), space (" "), and period
#             (".").
# This function returns true, (exit code 0) for a pool name that meets the above requirements
# BUT does not contain spaces.
is_valid_zpool_name_without_spaces(){
  [[ "$1" =~ ^[A-Za-z][-_:.A-Za-z0-9]* ]]
}

ZPOOL_NAME_ERROR_MSG_PART2="As noted in the zpool(8) man page, \"The pool name must begin with a letter, and
can only contain alphanumeric characters as well as underscore ('_'), dash
('-'), colon (':'), ...and period ('.').\""