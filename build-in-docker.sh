#! /bin/bash

docker run --rm -it -e CI=1 -v $(readlink -f .):/ws ubuntu:xenial sh -exc "
    cd /ws && \
    apt-get update && \
    apt-get install -y openjdk-8-jdk wget tree file
    bash build-appimage.sh
"
