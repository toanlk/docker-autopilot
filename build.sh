clear

# Use Docker buildx to build multi-platform images
docker buildx build --platform linux/amd64,linux/arm64 -t docker-autopilot . --push

docker tag docker-autopilot toanlk/autopilot:latest
docker push toanlk/autopilot:latest