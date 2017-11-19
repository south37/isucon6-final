#!/bin/bash

echo 'Restart services...'
  "$HOME/scripts/deploy_ruby.sh"
  "$HOME/scripts/deploy_react.sh"
echo 'Restarted!'
