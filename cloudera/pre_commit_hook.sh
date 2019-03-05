#!/bin/bash
#
# This script (pre_commit_hook.sh) is executed by pre-commit jobs
#

set -ex

# If this build was to use jdk7, this is how you'd do it:
## because we are using the cdh6 infrastructure, jdk1.8 is the default.  Since this is for C5, we should build/test with java7.
#export JAVA7_BUILD="true"
#. /opt/toolchain/toolchain.sh

echo "Using JAVA_HOME $JAVA_HOME"
echo "Using java $(command -v java)"
java -version
mvn -version

# TODO: uncomment this when we move to cdh6
# activate mvn-gbn wrapper
#mv "$(command -v mvn-gbn-wrapper)" "$(dirname "$(command -v mvn-gbn-wrapper)")/mvn"

mvn -U -B package -fae
