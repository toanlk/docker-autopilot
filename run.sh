clear

docker rm -f "docker-autopilot"
docker run --privileged -d \
        -p 9990:9990 -p 5900:5900 -p 6080:6080 -p 6081:6081 \
        --name "docker-autopilot" "docker-autopilot"

docker rm -f "docker-autopilot-2"
docker run --privileged -d \
        -p 9991:9990 -p 6000:5900 -p 6082:6080 -p 6083:6081 \
        --name "docker-autopilot-2" "docker-autopilot"

docker rm -f "docker-autopilot-3"
docker run --privileged -d \
        -p 9992:9990 -p 6100:5900 -p 6084:6080 -p 6085:6081 \
        --name "docker-autopilot-3" "docker-autopilot"

docker rm -f "docker-autopilot-4"
docker run --privileged -d \
        -p 9993:9990 -p 6200:5900 -p 6086:6080 -p 6087:6081 \
        --name "docker-autopilot-4" "docker-autopilot"