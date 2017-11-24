#!/bin/bash

for OPT in "$@"; do
  case $OPT in
    '--bundle' )
        FLAG_BUNDLE=1
        ;;
  esac
  shift
done

if [ $FLAG_BUNDLE ]; then
  BUNDLE_OPTION=" --bundle"
else
  BUNDLE_OPTION=""
fi

echo 'Restart services...'
  "$HOME/scripts/deploy_ruby.sh${BUNDLE_OPTION}"
  "$HOME/scripts/deploy_react.sh"
echo 'Restarted!'
