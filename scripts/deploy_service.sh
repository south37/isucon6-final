#!/bin/bash

sudo cp "$HOME/isu.ruby.service" "/etc/systemd/system/isu.ruby.service"
sudo cp "$HOME/isu.react.service" "/etc/systemd/system/isu.react.service"
sudo systemctl daemon-reload
