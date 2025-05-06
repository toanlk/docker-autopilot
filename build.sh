clear

docker build -t docker-autopilot .

platform=$(uname -m)
if [ "$platform" = "x86_64" ]; then
    echo "Building for x86_64 architecture..."
    # docker build -t docker-autopilot .

    os_name=$(uname)
    echo "Operating System: $os_name"

    if [ "$os_name" = "Darwin" ]; then
        
        # Use Docker buildx to build multi-platform images
        # docker buildx build --platform linux/amd64,linux/arm64 -t docker-autopilot . --push

        docker tag docker-autopilot toanlk/autopilot:latest
        docker push toanlk/autopilot:latest

        echo "Darwin build completed."
    fi
    
elif [ "$platform" = "aarch64" ]; then
    echo "Building for aarch64 architecture..."
    # docker build -t docker-autopilot .
else
    echo "Unsupported architecture: $platform"
    exit 1
fi