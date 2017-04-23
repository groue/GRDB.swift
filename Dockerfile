FROM swift:3.1

WORKDIR /package

COPY . ./

# Not neccessary because dependencies are copied from host
# but let's ensure they're in clean state
RUN swift package fetch
RUN swift package clean

# https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/
RUN apt-get update && \
    apt-get install -y libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Tests are not working yet on Linux
#CMD swift build && swift test --parallel
CMD swift build

