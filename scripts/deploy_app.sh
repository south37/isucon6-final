#!/bin/bash

if [ "$1" = "--bundle" ]; then
  echo 'Start bundle install...'
  cd "$HOME/webapp/ruby"
  bundle install
  cd "$HOME"
  echo 'bundle install finished!'
fi

echo 'Restart services...'
  # sudo systemctl restart redis.service
  # Save cache
  # sudo systemctl restart mysql.service
  echo 'Restart isu.ruby...'
  sudo systemctl restart isu.ruby.service
  echo 'Restarted isu.ruby!'

  echo 'Restart isu.react...'
  sudo systemctl restart isu.react.service
  echo 'Restarted isu.react!'
echo 'Restarted!'
