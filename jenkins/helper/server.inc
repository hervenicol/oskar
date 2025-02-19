if [ -z "$ARANGO_AUTH" ]; then ARANGO_AUTH="auth"; fi
if [ -z "$ARANGO_BRANCH" ]; then ARANGO_BRANCH="devel"; fi
if [ -z "$ARANGO_DOCKER_REG" ]; then ARANGO_DOCKER_REG="docker.io/arangodb"; fi
if [ -z "$ARANGO_DOCKER_TAG" ]; then ARANGO_DOCKER_TAG="$ARANGO_BRANCH"; fi

if [ "$USE_PREVIEW_DOCKER" == "true" ]
then 
    PREVIEW="-preview"
fi

case ${ARANGO_EDITION,,} in
     "enterprise")
          DOCKER_IMAGE="$ARANGO_DOCKER_REG/enterprise$PREVIEW:$ARANGO_DOCKER_TAG"
      ;;
     *)
          DOCKER_IMAGE="$ARANGO_DOCKER_REG/arangodb$PREVIEW:$ARANGO_DOCKER_TAG"
      ;;
esac

for name in ARANGO_DOCKER_NAME ARANGO_PORT ARANGO_MODE ARANGO_STORAGE_ENGINE ARANGO_EDITION ARANGO_AUTH; do
    if [ -z "${!name}" ]; then
        echo "$name missing"
        exit 1
    fi
done

echo "NAME: $ARANGO_DOCKER_NAME"

if [ "$ARANGO_MODE" == "cluster" ]; then
  if [[ -v ARANGO_PORTS ]]; then
    IFS=', ' read -r -a ARANGO_PORTS <<< "$ARANGO_PORTS"
  fi
  if [[ ${#ARANGO_PORTS[@]} > 0 ]]; then
    #port_shift=29
    for i in "${ARANGO_PORTS[@]}"; do
      echo "PORT $i to export"
      EXPORT_PORTS="$EXPORT_PORTS -p $i:$i"
      #EXPORT_PORTS="$EXPORT_PORTS -p $i:$(expr 8500 + $port_shift)"
      #port_shift=$(expr $port_shift + 10)
    done
  else 
    EXPORT_PORTS="-p $ARANGO_PORT:$ARANGO_PORT"
  fi
else
  EXPORT_PORTS="-p $ARANGO_PORT:$ARANGO_PORT"
fi
echo "PORTS: $EXPORT_PORTS"
echo "MODE: $ARANGO_MODE"
echo "ENGINE: $ARANGO_STORAGE_ENGINE"
echo "AUTH: $ARANGO_AUTH"
echo "EDITION: $ARANGO_EDITION"
echo

docker kill $ARANGO_DOCKER_NAME > /dev/null 2>&1 || true
docker rm -fv $ARANGO_DOCKER_NAME > /dev/null 2>&1 || true
docker pull $DOCKER_IMAGE
docker run --cap-add SYS_NICE $DOCKER_IMAGE arangosh --version

OUTDIR="`pwd`/output"
rm -rf $OUTDIR
mkdir $OUTDIR
DOCKER_AUTH=""
STARTER_AUTH=""
DOCKER_CMD="docker run --cap-add SYS_NICE --name $ARANGO_DOCKER_NAME -d $EXPORT_PORTS -v $OUTDIR:/testrun"
#DOCKER_IMAGE="registry.arangodb.biz:5000/arangodb/linux-${ARANGO_EDITION}-maintainer:$ARANGO_BRANCH"
STARTER_CMD="arangodb --starter.local --server.storage-engine $ARANGO_STORAGE_ENGINE --starter.data-dir /testrun"
STARTER_MODE=""

if [ "$ARANGO_AUTH" == "auth" ]; then
  JWTDIR="`pwd`/jwtsecret"
  rm -rf $JWTDIR
  mkdir $JWTDIR
  echo "geheim" > $JWTDIR/geheim
  DOCKER_AUTH="-v $JWTDIR:/jwtsecret -e ARANGO_ROOT_PASSWORD=$ARANGO_ROOT_PASSWORD -e ARANGODB_DEFAULT_ROOT_PASSWORD=$ARANGO_ROOT_PASSWORD"
  STARTER_AUTH="--auth.jwt-secret /jwtsecret/geheim" 
fi

if [ "$ARANGO_MODE" == "cluster" ]; then
  STARTER_MODE="--starter.mode cluster"
  if [[ "$ARANGO_MODE" == "cluster" && -v ARANGO_PORTS && ${#ARANGO_PORTS[@]} > 0 ]]; then
    STARTER_MODE="$STARTER_MODE --starter.port $(expr ${ARANGO_PORTS[0]} - 1)"
  else
    STARTER_MODE="$STARTER_MODE --starter.port $(expr $ARANGO_PORT - 1)"
  fi
elif [ "$ARANGO_MODE" == "singleserver" ]; then
  STARTER_MODE="--starter.mode single --starter.port $(expr $ARANGO_PORT - 1)"
else
    echo "unknown mode $ARANGO_MODE"
    exit 1
fi

cat > $OUTDIR/starter.sh << 'EOF'
#!/bin/sh
cd /testrun
pwd
ulimit -a
$*
EOF
chmod 755 $OUTDIR/starter.sh

echo "Starting the container with the following command:"
command="$DOCKER_CMD $DOCKER_AUTH $DOCKER_IMAGE /testrun/starter.sh $STARTER_CMD $STARTER_MODE $STARTER_AUTH"
echo $command
$command

trap "$(trap -p | grep EXIT | sed "s/.*-- '\(.*\)'.EXIT/\1;/g")docker rm -fv $ARANGO_DOCKER_NAME ; sudo chown jenkins:jenkins -R output ; tar czf arango_data.tar.gz output" EXIT

echo "Waiting until ArangoDB is ready on port $ARANGO_PORT"

if [ "$ARANGO_AUTH" == "auth" ]; then
    CURL_USER="-uroot:$ARANGO_ROOT_PASSWORD"
else
    CURL_USER=""
fi

count=0

while [ "$count" -lt 240 ]; do
  responseCode=`curl -s -I $CURL_USER http://127.0.0.1:$ARANGO_PORT/_api/version | head -n 1 | cut -d$' ' -f2`
  if [ -n "${responseCode}" ];
  then
    if [ $responseCode -eq 200 ];
    then
          echo "We are finally ready and authenticated."
          break
    fi
  fi

  count=`expr $count + 1`
  echo "waiting ($count)..."
  sleep 2s
done

if [ $count -ge 240 ]; then
    echo "docker logs:"
    docker logs $ARANGO_DOCKER_NAME

    echo
    echo "curl:"
    curl $CURL_USER -v http://127.0.0.1:$ARANGO_PORT/_api/version

    echo "ArangoDB did not start"
    exit 1
fi

echo "ArangoDB is up"
