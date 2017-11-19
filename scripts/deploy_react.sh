#!/bin/bash

echo 'Restart isu.react...'
echo 'Building server.js, so wait for a while...'
echo "isucon" | sudo -S systemctl restart isu.react.service
echo 'Restarted isu.react!'
