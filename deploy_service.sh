#!/bin/bash

sudo cp "$HOME/isu.ruby.service" "/etc/systemd/system/isu.ruby.service"
sudo systemctl daemon-reload
