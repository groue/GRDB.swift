FROM swift:3.1

WORKDIR /package

# https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
RUN apt-get update && \
    apt-get install -y libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

COPY . ./

# Not neccessary because dependencies are copied from host
# but let's ensure they're in clean state
RUN swift package fetch
RUN swift package clean

# --parallel
CMD swift test && \
    swift test -c release -Xswiftc -enable-testing

