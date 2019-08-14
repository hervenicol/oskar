#!/usr/bin/env fish
set -l c 0

cd $INNERWORKDIR
and rm -rf combined
and mkdir combined

and for i in gcov/????????????????????????????????
  if test $c -eq 0
    echo "first file $i"
    and cp -a $i combined/1
    and set c 1
  else if test $c -eq 1
    echo "merging $i"
    and rm -rf combined/2
    and gcov-tool merge $i combined/1 -o combined/2
    and set c 2
  else if test $c -eq 2
    echo "merging $i"
    and rm -rf combined/1
    and gcov-tool merge $i combined/2 -o combined/1
    and set c 1
  end
end

and if test $c -eq 1
  mv combined/1 combined/result
else if test $c -eq 2
  mv combined/2 combined/result
end

and rm -rf combined/1 combined/2 /tmp/gcno

and echo "creating gcno tar"
and pushd ArangoDB/build
and tar c -f /tmp/gcno.tar (find . -name "*.gcno")
and popd
and echo "copying gcno files"
and tar x -f /tmp/gcno.tar -C /work/combined/result

and gcovr --root /work/ArangoDB -x -e 3rdParty/ -o combined/coverage.xml

and begin
  cat combined/coverage.xml \
    | sed -e "s:filename=\":filename=\"/home/jenkins/$NODE_NAME/oskar/work/ArangoDB/:g" \
    > combined/coverage.xml.tmp
  and mv combined/coverage.xml.tmp combined/coverage.xml
end
