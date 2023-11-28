#!/bin/bash

[ $(id -u) -ne 0  ] && CMD="sudo" || CMD=""

curl -s http://assets.playpit.net/install-docker.sh  | ${CMD} bash
curl -s http://assets.playpit.net/install-nginx.sh   | ${CMD} bash
curl -s http://assets.playpit.net/install-playpit.sh | ${CMD} bash
