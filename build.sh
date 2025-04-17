clear

docker build -t docker-autopilot .

os_name=$(uname)
if [ "$os_name" = "Linux" ]; then
    
    # Use Docker buildx to build multi-platform images
    # docker buildx build --platform linux/amd64,linux/arm64 -t docker-autopilot . --push

    # docker tag docker-autopilot toanlk/autopilot:latest
    # docker push toanlk/autopilot:latest

    echo "Linux build completed."
fi