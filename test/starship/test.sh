#!/bin/bash

set -e
source dev-container-features-test-lib



check 'starship executable is installed' which starship | grep starship

reportResults
