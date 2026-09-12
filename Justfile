run:
    sudo ./build.sh

lint:
    pre-commit run --all-files

docker-qemu:
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

docker-build:
    docker build -t nocturne-builder .

docker-run: docker-build
    mkdir -p local
    docker run --rm --privileged \
        -v "$(pwd)/output:/work/output" \
        -v "$(pwd)/local:/work/local" \
        nocturne-builder:latest

build-nocturned:
    mkdir -p local
    docker run --rm \
        -v "$(pwd)/../nocturned:/src:ro" \
        -v "$(pwd)/local:/out" \
        -e GOOS=linux -e GOARCH=arm -e GOARM=7 -e CGO_ENABLED=0 \
        golang:1.23-alpine \
        sh -c "cd /src && go build -o /out/nocturned ."

build-nocturne-ui:
    mkdir -p local
    cd ../nocturne-ui && bun install && bun run build
    cd ../nocturne-ui/dist && zip -r ../../nocturne/local/nocturne-ui.zip .
