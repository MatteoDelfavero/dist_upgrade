#!/bin/bash

sudo apt --fix-missing update
sudo apt clean
sudo apt autoremove
sudo apt update
sudo apt full-upgrade -y
