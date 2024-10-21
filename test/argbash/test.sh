#!/bin/bash

#Read the hello and color tests for documentation here

set -e
source dev-container-features-test-lib
check "argbash is in path" which argbash | grep /bin/argbash
check "argbash can be called" argbash --help | grep "/bin/argbash"
# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults