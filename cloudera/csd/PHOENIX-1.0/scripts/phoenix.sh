#!/bin/bash
##
#
# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##

add_to_hbase_site() {
  FILE=$(find . -name hbase-site.xml | tail -1)
  if [ ! -f "$FILE" ]; then
    echo "Could not find hbase-site.xml in " $(pwd)
    exit 1
  fi

  CONF_END="</configuration>"
  NEW_PROPERTY="<property><name>$1</name><value>$2</value></property>"
  TMP_FILE=$CONF_DIR/tmp-hbase-site
  cat $FILE | sed "s#$CONF_END#$NEW_PROPERTY#g" > $TMP_FILE
  cp $TMP_FILE $FILE
  rm -f $TMP_FILE
  echo $CONF_END >> $FILE
}

merge_configs() {
  HBASE_CONF=$(find . -name hbase-site.xml | tail -1)
  PHOENIX_CONF=$(find . -name phoenix-site.xml | tail -1)
  sed -i '$ d' $HBASE_CONF
  grep -E "<?property>|<?name>|<?value>" $PHOENIX_CONF >> $HBASE_CONF
  echo "</configuration>" >> $HBASE_CONF
}

set -x

# Source the common script to use acquire_kerberos_tgt
. $COMMON_SCRIPT

DEFAULT_PHOENIX_HOME=/usr/lib/phoenix
PHOENIX_HOME=${PHOENIX_HOME:-$DEFAULT_PHOENIX_HOME}

# Save command argument
CMD=$1
shift 1

case $CMD in

  (start)
    # Merging phoenix-site.xml (Kerberos conf) with hbase-site.xml
    merge_configs

    if [ "$phoenix_principal" != "" ]; then
      add_to_hbase_site phoenix.queryserver.keytab.file $CONF_DIR/phoenix.keytab
    fi
    if [ "$spnego_principal" != "" ]; then
      add_to_hbase_site phoenix.queryserver.http.keytab.file $CONF_DIR/phoenix.keytab
    fi

    export HBASE_CONF_DIR=${PWD}/hbase-conf

    # Starting without arguments will start PQS in the foreground
    exec ${PHOENIX_HOME}/bin/queryserver.py
    ;;

  (*)
    echo "Don't understand [$1]"
    exit 1
    ;;

esac