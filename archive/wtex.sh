#!/bin/bash

# Default values
verbose=false # Whether to print debug information or not
output="/tmp/wtex.log" # By default, the output of the latex compiler will be redirected to /tmp/wtex.log


# Usage informations
usage() {
  echo "Usage: $0 [-h] <tex file to watch>"
  echo "This script will watch the specified tex file for changes and recompile it"
  echo "The compilation output will be redirected in /tmp/wtex.log and only shown if there are errors"
  echo "At the moment, only pdflatex is supported, configuration will be added in a future release"
  echo ""
  echo "Options:"
  echo "  -h  Show this help message"
  echo "  -v  Enable verbose mode"
}


# Argument parsing
while getopts ":hv" opt; do
  case ${opt} in
    h )
      usage
      exit 0
      ;;
    v )
      echo "Verbose mode enabled"
      verbose=true
      output="/dev/stdout"
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      usage
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))


# Check if file is specified
if [ -z "$1" ]
then
  echo "Usage: $0 <tex file to watch>"
  echo "$0 -h for help"
  exit 1
fi

# Check if file exists
if [ ! -f "$1" ]
then
  echo "File '$1' not found"
  exit 1
fi

# Check if inotifywait is installed
if [ ! -x "$(command -v inotifywait)" ]
then
  echo "inotifywait is not installed. Please install it before running this script"
  exit 1
fi

echo "Watching '$1' for changes..."

while true
do
  inotifywait -qq -e modify "$1"

  echo -n "Compiling $1... "
  pdflatex -interaction=nonstopmode "$1" > $output

  if [ $? -ne 0 ] && [ "$verbose" = false ]
  then
    cat /tmp/wtex.log
  fi

  echo "Done."
done
