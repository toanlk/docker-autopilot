clear 

# curl -X POST http://localhost:9990/computer-use \
#   -H "Content-Type: application/json" \
#   -d '{"action": "move_mouse", "coordinates": {"x": 100, "y": 960}}'

# sleep 1

# curl -X POST http://localhost:9990/computer-use \
#  -H "Content-Type: application/json" \
#  -d '{"action": "click_mouse", "button": "left", "numClicks": 1}'

curl -X POST http://localhost:9990/computer-use \
  -H "Content-Type: application/json" \
  -d '{"action": "type_text", "text": "https://www.google.com", "delay": 30}'

sleep 1

curl -X POST http://localhost:9990/computer-use \
  -H "Content-Type: application/json" \
  -d '{"action": "press_keys", "keys": ["enter"]}'

# Press Ctrl+S to save
# curl -X POST http://localhost:9990/computer-use \
#   -H "Content-Type: application/json" \
#   -d '{"action": "press_key", "key": "a", "modifiers": ["control"]}'