#!/usr/bin/env bash

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

# This is the post build file. The file is dependent on cdh cauldron repo.

set -x
set -e

if [ -z "$GBN" ]; then
    echo "GBN not defined"
    exit 1
fi
if [ -z "$PHOENIX_VERSION" ]; then
   echo "PHOENIX_VERSION is not defined"
   exit 1
fi
if [ -z "$CDH_VERSION" ]; then
   echo "CDH_VERSION is not defined"
   exit 1
fi

# Ensure that the s3 creds are generated and available before the build starts.
if [ ! -f /tmp/s3-auth-file ]; then
   echo "S3 creds are not generated"
   exit 1
fi

OUTPUT_REPO=/phoenix/output-repo/

rm -rf $OUTPUT_REPO

VAL=phoenix-$RANDOM
export VIRTUAL_DIR="/tmp/$VAL"

virtualenv $VIRTUAL_DIR
source $VIRTUAL_DIR/bin/activate
cd /cdh/lib/python/cauldron
$VIRTUAL_DIR/bin/pip install --upgrade pip==9.0.1
$VIRTUAL_DIR/bin/pip install --upgrade setuptools==33.1.1
$VIRTUAL_DIR/bin/pip install -r requirements.txt
$VIRTUAL_DIR/bin/python setup.py install

PRODUCT_NAME=phoenix
COMPONENT_NAME=phoenix

mkdir -p $OUTPUT_REPO
cd $OUTPUT_REPO

S3_ROOT=phoenix/${CDH_VERSION}
S3_PARCELS=${S3_ROOT}/parcels
S3_CSD=${S3_ROOT}/csd
S3_MAVEN=${S3_ROOT}/maven-repository

# populate parcels and generate manifest.json
mkdir -p ${S3_PARCELS} ${S3_CSD} ${S3_MAVEN}
cp -v /phoenix/build-parcel/PHOENIX-*.parcel ${S3_PARCELS}
cp -v /phoenix/build-parcel/PHOENIX-*.parcel.sha ${S3_PARCELS}
cp -v /phoenix/build-parcel/csd/${CSD_NAME}.jar ${S3_CSD}
$VIRTUAL_DIR/bin/parcelmanifest ${S3_PARCELS}

# copying maven artifacts
mkdir -p ${S3_MAVEN}/org/apache
cp -a /maven-repo/org/apache/phoenix ${S3_MAVEN}/org/apache

# create build.json
user=jenkins
EXPIRE_DAYS=10
EXPIRATION=$(date --d "+${EXPIRE_DAYS} days" +%Y%m%d-%H%M%S)
if [ -z $RELEASE_CANDIDATE ]; then
	BUILD_JSON_EXIPIRATION="--expiry ${EXPIRATION}"
fi

$VIRTUAL_DIR/bin/buildjson \
	-o build.json -p ${PRODUCT_NAME} --version ${CDH_VERSION} \
	--gbn $GBN -os redhat6 -os redhat7 -os sles12 -os ubuntu1604 \
	--build-environment $BUILD_URL ${BUILD_JSON_EXIPIRATION} \
	--user ${user} \
	add_parcels --product-parcels ${COMPONENT_NAME} ${S3_PARCELS} \
	add_csd --files ${COMPONENT_NAME} ${S3_CSD}/${CSD_NAME}.jar \
	add_maven --product-base ${COMPONENT_NAME} ${S3_MAVEN}

$VIRTUAL_DIR/bin/htmllisting $OUTPUT_REPO

# upload it to s3
$VIRTUAL_DIR/bin/upload s3 \
	--auth-file /tmp/s3-auth-file \
	--base build/${GBN} $OUTPUT_REPO/:.
curl http://builddb.infra.cloudera.com/save?gbn=$GBN

# add tags for gbn
curl "http://builddb.infra.cloudera.com/addtag?gbn=${GBN}&value=FULL_BUILD"
echo "Marking build as official? ${OFFICIAL}"
if [ "${OFFICIAL}" == "true" ]; then
	curl "http://builddb.infra.cloudera.com/addtag?gbn=${GBN}&value=official"
fi
if [[ -n "${RELEASE_CANDIDATE}" ]]; then
	echo "Marking this as Release Candidate #${RELEASE_CANDIDATE}"
	curl "http://builddb.infra.cloudera.com/addtag?gbn=${GBN}&value=release_candidate"
	curl "http://builddb.infra.cloudera.com/addtag?gbn=${GBN}&value=rc-${RELEASE_CANDIDATE}"
fi
curl "http://builddb.infra.cloudera.com/addtag?gbn=${GBN}&value=${PHOENIX_VERSION}"

echo "Tags added to the build are:"
curl "http://builddb.infra.cloudera.com/gettags?gbn=${GBN}"
echo ""
