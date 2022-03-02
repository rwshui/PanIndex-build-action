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
  xgo --targets=linux/amd64,windows/* -out PanIndex -ldflags="$ldflags" .
  mkdir -p ${GITHUB_WORKSPACE}/dist/compress
  mv PanIndex-* dist
  cd dist
  upx -9 ./PanIndex-linux*
  upx -9 ./PanIndex-windows*
}

COMPRESS_UI(){
  cd ${GITHUB_WORKSPACE}
  mkdir ui
  cp -R -f static/ ui/static/
  cp -R -f templates/ ui/templates/
  cd ui
  zip -vr ${GITHUB_WORKSPACE}/dist/compress/ui-${RELEASE_TAG}.zip *
  sha256sum ui-${RELEASE_TAG}.zip >> ${GITHUB_WORKSPACE}/dist/compress/sha256.list
}

RELEASE(){
  cp -r LICENSE README.md ${GITHUB_WORKSPACE}/dist
  for f in $(find ${GITHUB_WORKSPACE}/dist -type f -name "PanIndex*"); do
    echo $f
    if [[ "$f" =~ "windows" ]]; then
      echo "compress/$(echo $f | sed 's/\.[^.]*$//').zip"
      zip compress/$(echo $f | sed 's/\.[^.]*$//').zip "$f" LICENSE README.md
    else
       tar -czvf compress/"$f".tar.gz "$f" LICENSE README.md
    fi
    sha256sum "$f" >> ${GITHUB_WORKSPACE}/dist/compress/sha256.list
  done
  COMPRESS_UI
  ls -n ${GITHUB_WORKSPACE}/dist/compress
}

BUILD
COMPRESS_UI

