#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

mvn -U -B apache-rat:check package -fae
