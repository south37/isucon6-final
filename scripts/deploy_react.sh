#!/bin/bash

echo 'Restart isu.react...'
echo 'Building server.js, so wait for a while...'
sudo systemctl restart isu.react.service
echo 'Restarted isu.react!'
