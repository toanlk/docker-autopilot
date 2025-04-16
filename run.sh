clear

docker rm -f "docker-autopilot"

docker run --privileged -d \
        -p 9990:9990 -p 5900:5900 -p 6080:6080 -p 6081:6081 \
        --name "docker-autopilot" "docker-autopilot"