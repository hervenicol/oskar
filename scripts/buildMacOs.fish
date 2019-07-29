#!/usr/bin/env fish
if test "$PARALLELISM" = ""
    set -xg PARALLELISM 64
end
echo "Using parallelism $PARALLELISM"

cd $INNERWORKDIR
mkdir -p .ccache.mac
set -x CCACHE_DIR $INNERWORKDIR/.ccache.mac
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache
end
if test "$CCACHESIZE" = ""
  set -xg CCACHESIZE 100G
end
ccache -M $CCACHESIZE
#ccache -o log_file=$INNERWORKDIR/.ccache.mac.log
ccache -o cache_dir_levels=1
cd $INNERWORKDIR/ArangoDB

if test -z "$NO_RM_BUILD"
  echo "Cleaning build directory"
  rm -rf build
end

echo "Starting build at "(date)" on "(hostname)
test -f $INNERWORKDIR/.ccache.mac.log 
and mv $INNERWORKDIR/.ccache.mac.log $INNERWORKDIR/.ccache.mac.log.old
ccache --zero-stats

rm -rf build
mkdir -p build
cd build

set -g FULLARGS $argv \
      -DCMAKE_BUILD_TYPE=$BUILDMODE \
      -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/g++ \
      -DCMAKE_C_COMPILER=$CCACHEBINPATH/gcc \
      -DUSE_MAINTAINER_MODE=$MAINTAINER \
      -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
      -DCMAKE_SKIP_RPATH=On \
      -DPACKAGING=Bundle \
      -DPACKAGE_TARGET_DIR=$INNERWORKDIR \
      -DOPENSSL_USE_STATIC_LIBS=On

if test "$argv" = ""
  echo "using default architecture 'nehalem'"
  set -g FULLARGS $FULLARGS \
    -DTARGET_ARCHITECTURE=nehalem
end

if test "$MAINTAINER" != "On"
  set -g FULLARGS $FULLARGS \
    -DUSE_CATCH_TESTS=Off \
    -DUSE_GOOGLE_TESTS=Off
end

if test "$ASAN" = "On"
  echo "Building with ASAN"
  set -g FULLARGS $FULLARGS \
         -DUSE_JEMALLOC=Off \
         -DCMAKE_C_FLAGS="-fsanitize=address -fsanitize=undefined -fno-sanitize=alignment" \
         -DCMAKE_CXX_FLAGS="-fsanitize=address -fsanitize=undefined -fno-sanitize=vptr -fno-sanitize=alignment"
else 
  set -g FULLARGS $FULLARGS \
      -DUSE_JEMALLOC=$JEMALLOC_OSKAR
end

echo cmake $FULLARGS ..
echo cmake output in $INNERWORKDIR/cmakeArangoDB.log

cmake $FULLARGS .. ^&1 > $INNERWORKDIR/cmakeArangoDB.log
or exit $status

echo "Finished cmake at "(date)", now starting build"

set -g MAKEFLAGS -j$PARALLELISM 
if test "$VERBOSEBUILD" = "On"
  echo "Building verbosely"
  set -g MAKEFLAGS $MAKEFLAGS V=1 VERBOSE=1 Verbose=1
end

echo Running make, output in $INNERWORKDIR/buildArangoDB.log
and nice make $MAKEFLAGS > $INNERWORKDIR/buildArangoDB.log ^&1 
and echo "Finished at "(date)
and ccache --show-stats
