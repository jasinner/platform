#!/bin/bash

#
# Script responsible to build & publish the snapshots of the Obsidian Project
#
# Example :
# ./deploy-snapshots.sh nexus-infra.172.28.128.4.xip.io/content/repositories/snapshots
#
#
# For local deployment, verify that you have added within your maven settings.xml file a server id for
# <id>jboss-releases-repository</id> and <id>jboss-snapshots-repository</id> containing the username/password
#

: ${1:?"Must specify Alternate Maven Repo to publish. Ex: nexus-infra.172.28.128.4.xip.io/content/repositories/snapshots"}

ORG="obsidian-toaster-quickstarts"
MAVEN_REPO=$1

CURRENT=$(pwd)

WORK_DIR=`mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir'`
echo "Working in temp directory $WORK_DIR"
cd $WORK_DIR

function mvnDeploy {
  REPO=$1
  REPODIR=$2

  git clone $REPO $REPODIR
  cd $REPODIR
  mvn clean deploy -DskipTests=true -Djboss.snapshots.repo.url=http://$MAVEN_REPO -DskipStaging=true
  cd -
}

# Step 1. : Release Platform. Archetypes should be previously generated and pushed
# Generate from the QuickStarts the Maven corresponding archetypes
# Generate a Maven POM file containing the different archetypes to be used
#
echo Press any key to deploy the Platform...
read junk
git clone https://github.com/obsidian-toaster/platform platform
cd platform/archetype-builder
mvn clean compile exec:java -Dgithub.organisation=$ORG

cd ..
mvn clean deploy -DskipTests=true -Djboss.snapshots.repo.url=http://$MAVEN_REPO -DskipStaging=true
cd ..


#
# Step 2. : Deploy Obsidian Forge addon
#
echo Press any key to deploy the Obsidian addon...
read junk
mvnDeploy https://github.com/obsidian-toaster/obsidian-addon.git obsidian-addon

#
# Step 3. : Release Backend (PROD is not required)
#
# CATALOG_URL : List of the Archetypes that we will use to generate the code (zip file downloaded by the user)
#
echo Press any key to deploy the Backend...
read junk
mvnDeploy https://github.com/obsidian-toaster/generator-backend.git generator-backend

#
# Step 4. : Release Frontend (PROD is not required)
# This is HTML/javascript project
# It uses REST Api exposed by the backend to access the services
# FORGE_URL : REST endpoint
#
echo Press any key to deploy the Frontend...
read junk
git clone https://github.com/obsidian-toaster/generator-frontend.git
cd generator-frontend
npm install package-json-io
#node -e "var pkg = require('package-json-io'); pkg.read(function(err, data) { data.version = '$REL'.replace(/(?:[^\.]*\.){3}/, function(x){return x.substring(0, x.length - 1) + '-'}); pkg.update(data, function(){}); })"

git clone https://github.com/obsidian-toaster/obsidian-toaster.github.io.git build
cd build
rm -rf *
cd -
npm install
npm run build:prod
cp -r dist/* build
cd build
git add .
git commit -a -m "Released snapshot of generator-frontend on master branche"
git push origin master
cd -

# clean up
echo "Cleaning up temp directory $WORK_DIR"
rm -rf $WORK_DIR