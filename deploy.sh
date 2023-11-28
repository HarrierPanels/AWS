#!/bin/bash

[ $(id -u) -ne 0  ] && CMD="sudo" || CMD=""

curl -s https://github.com/HarrierPanels/AWS/blob/main/install-docker.sh | ${CMD} bash
curl -s https://github.com/HarrierPanels/AWS/blob/main/install-nginx.sh | ${CMD} bash
curl -s https://github.com/HarrierPanels/AWS/blob/main/install-playpit.shh | ${CMD} bash
