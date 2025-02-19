#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

set -xg simple (pwd)/performance
set -xg date (date +%Y%m%d)
set -xg datetime (date +%Y%m%d%H%M)
set -xg dest /mnt/buildfiles/performance/Linux/Simple/RAW

if test -z "$ARANGODB_TEST_CONFIG"
  set -xg ARANGODB_TEST_CONFIG run-small-edges.js
end

cleanPrepareLockUpdateClear
and enterprise
and switchBranches $ARANGODB_BRANCH $ENTERPRISE_BRANCH true
and if echo "$ARANGODB_BRANCH" | grep -q "^v"
  pushd work/ArangoDB
  set -xg date (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-8)
  set -xg datetime (git log -1 --format=%aI  | tr -d -- '-:T+' | cut -b 1-12)
  echo "==== date $datetime ===="
  popd
end
and maintainerOff
and releaseMode
and pingDetails
and showConfig
and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem

and sudo rm -rf work/database $simple/results.csv
and echo "==== starting performance run ===="
and docker run \
  -e ARANGO_LICENSE_KEY=$ARANGODB_LICENSE_KEY \
  -v (pwd)/work/ArangoDB:/ArangoDB \
  -v (pwd)/work:/data \
  -v $simple:/performance \
  arangodb/arangodb \
  sh -c "cd /performance && \
    /ArangoDB/build/bin/arangod \
      -c none \
      --javascript.app-path /tmp/app \
      --javascript.startup-directory /ArangoDB/js \
      --server.rest-server false \
      --javascript.module-directory `pwd` \
      --log.foreground-tty \
      /data/database \
      --javascript.script $ARANGODB_TEST_CONFIG"

set -l s $status
set -l resultname (echo $ARANGODB_BRANCH | tr "/" "_")
set -l filename $dest/results-$resultname-$datetime.csv

echo "storing results in $resultname"
awk "{print \"$ARANGODB_BRANCH,$date,\" \$0}" \
  < $simple/results.csv \
  > $filename

sudo rm -rf work/database

cd "$HOME/$NODE_NAME/$OSKAR" ; moveResultsToWorkspace ; unlockDirectory 
exit $s
