#!/bin/bash -eux
RELEASE_TAG=$(basename ${GITHUB_REF})
ldflags="\
  -w -s \
  -X 'github.com/libsgh/PanIndex/module.VERSION=${RELEASE_TAG}' \
  -X 'github.com/libsgh/PanIndex/module.BUILD_TIME=$(date "+%F %T")' \
  -X 'github.com/libsgh/PanIndex/module.GO_VERSION=$(go version)' \
  -X 'github.com/libsgh/PanIndex/module.GIT_COMMIT_SHA=$(git show -s --format=%H)' \
  "
BUILD(){
  cd ${GITHUB_WORKSPACE}
  xgo --targets=linux/* -out PanIndex -ldflags="-s -w $ldflags" .
  xgo --targets=darwin/* -out PanIndex -ldflags="-s -w $ldflags" .
  xgo --targets=windows/* -out PanIndex -ldflags="-s -w $ldflags -H windowsgui" .
  mkdir -p ${GITHUB_WORKSPACE}/dist/compress
  mv PanIndex-* dist
  cd dist
  upx -9 ./PanIndex-linux*
  upx -9 ./PanIndex-windows*
}

BUILD_DOCKER() {
  go build -o ./bin/PanIndex -ldflags="-s -w $ldflags" .
}

BUILD_MUSL(){
  cd ${GITHUB_WORKSPACE}
  BASE="https://musl.cc/"
  FILES=(x86_64-linux-musl-cross aarch64-linux-musl-cross arm-linux-musleabihf-cross mips-linux-musl-cross mips64-linux-musl-cross mips64el-linux-musl-cross mipsel-linux-musl-cross powerpc64le-linux-musl-cross s390x-linux-musl-cross)
  for i in "${FILES[@]}"; do
    url="${BASE}${i}.tgz"
    curl -L -o "${i}.tgz" "${url}"
    sudo tar xf "${i}.tgz" --strip-components 1 -C /usr/local
  done
  OS_ARCHES=(linux-musl-amd64 linux-musl-arm64 linux-musl-arm linux-musl-mips linux-musl-mips64 linux-musl-mips64le linux-musl-mipsle linux-musl-ppc64le linux-musl-s390x)
  CGO_ARGS=(x86_64-linux-musl-gcc aarch64-linux-musl-gcc arm-linux-musleabihf-gcc mips-linux-musl-gcc mips64-linux-musl-gcc mips64el-linux-musl-gcc mipsel-linux-musl-gcc powerpc64le-linux-musl-gcc s390x-linux-musl-gcc)
  for i in "${!OS_ARCHES[@]}"; do
    os_arch=${OS_ARCHES[$i]}
    cgo_cc=${CGO_ARGS[$i]}
    echo building for ${os_arch}
    CGO_ENABLED=1 GOOS=${os_arch%%-*} GOARCH=${os_arch##*-} CC=${cgo_cc} go build -o ${GITHUB_WORKSPACE}/dist/PanIndex-$os_arch -ldflags="$ldflags" -tags=jsoniter .
  done
}

COMPRESS_UI(){
  cd ${GITHUB_WORKSPACE}
  mkdir ui
  cp -R -f static/ ui/static/
  cp -R -f templates/ ui/templates/
  cd ui
  zip -vr ${GITHUB_WORKSPACE}/dist/compress/ui-${RELEASE_TAG}.zip *
  cd ${GITHUB_WORKSPACE}/dist/compress
  sha256sum ui-${RELEASE_TAG}.zip >> ${GITHUB_WORKSPACE}/dist/compress/sha256.list
  ls -n ${GITHUB_WORKSPACE}/dist/compress
}

RELEASE(){
  cp -r LICENSE README.md ${GITHUB_WORKSPACE}/dist
  cd ${GITHUB_WORKSPACE}/dist
  for f in $(find * -type f -name "PanIndex*"); do
    if [[ "$f" =~ "windows" ]]; then
      zip compress/$(echo $f | sed 's/\.[^.]*$//').zip "$f" LICENSE README.md
    else
       tar -czvf compress/"$f".tar.gz "$f" LICENSE README.md
    fi
    sha256sum "$f" >> ${GITHUB_WORKSPACE}/dist/compress/sha256.list
  done
}

if [ "$1" = "docker" ]; then
  BUILD_DOCKER
else
  BUILD
  BUILD_MUSL
  RELEASE
  COMPRESS_UI
fi


