#!/bin/bash -eux
BUILD(){
  cd ${GITHUB_WORKSPACE}
  RELEASE_TAG=$(basename ${GITHUB_REF})
  ldflags="\
  -w -s \
  -X 'github.com/libsgh/PanIndex/module.VERSION=${RELEASE_TAG}' \
  -X 'github.com/libsgh/PanIndex/module.BUILD_TIME=$(date "+%F %T")' \
  -X 'github.com/libsgh/PanIndex/module.GO_VERSION=$(go version)' \
  -X 'github.com/libsgh/PanIndex/module.GIT_COMMIT_SHA=$(git show -s --format=%H)' \
  "
  packr2
  docker images
  xgo -out PanIndex -ldflags="$ldflags" .
  mkdir -p dist
  mv PanIndex-* dist
  cd dist
  upx -9 ./PanIndex-linux*
  upx -9 ./PanIndex-windows*
}

RELEASE(){
  mkdir compress
  for i in $(find . -type f -name "PanIndex*"); do
    if [ [[ "$i" =~ "windows" ]] ]; then
      zip compress/$(echo $i | sed 's/\.[^.]*$//').zip "$i"
    else
       tar -czvf compress/"$i".tar.gz "$i"
    fi
    sha256sum "$i" >> ${GITHUB_WORKSPACE}/dist/compress/sha256.list
  done
  cd ../
  mkdir ui
  cp -R -f static/ ui/static/
  cp -R -f templates/ ui/templates/
  cd ui
  zip -vr dist/compress/ui-${RELEASE_TAG}.zip *
  sha256sum ui-${RELEASE_TAG}.zip >> ${GITHUB_WORKSPACE}/dist/compress/sha256.list
  cd dist/compress
  ls -n
  cd ../../..
}

BUILD
RELEASE

