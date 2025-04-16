from flask import Flask, request, jsonify
import pyautogui
import subprocess
import base64
import os

app = Flask(__name__)

@app.route('/computer-use', methods=['POST'])
def computer_use():
    data = request.json
    action = data.get('action')

    if action == 'move_mouse':
        x = data['coordinates']['x']
        y = data['coordinates']['y']
        subprocess.run(['xdotool', 'mousemove', str(x), str(y)])
    elif action == 'click_mouse':
        button = data['button']
        num_clicks = data.get('numClicks', 1)
        subprocess.run(['xdotool', 'click', '--repeat', str(num_clicks), button])
    elif action == 'type_text':
        text = data['text']
        delay = data.get('delay', 0)
        subprocess.run(['xdotool', 'type', '--delay', str(delay), text])
    elif action == 'press_keys':
        keys = data['keys']
        modifiers = data.get('modifiers', [])
        for modifier in modifiers:
            pyautogui.keyDown(modifier)
        for key in keys:
            pyautogui.press(key)
        for modifier in modifiers:
            pyautogui.keyUp(modifier)
    elif action == 'hotkey':
        keys = data['keys']
        pyautogui.hotkey(*keys)
    elif action == 'take_screenshot':
        screenshot_path = '/tmp/screenshot.png'
        try:
            subprocess.run(['scrot', screenshot_path], check=True)
            with open(screenshot_path, 'rb') as image_file:
                encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
            os.remove(screenshot_path)
            return jsonify({'status': 'success', 'image_data': encoded_string})
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    else:
        return jsonify({'error': 'Invalid action'}), 400

    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9990)