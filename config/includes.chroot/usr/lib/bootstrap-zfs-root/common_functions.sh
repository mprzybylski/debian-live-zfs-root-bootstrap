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
