from flask import Flask, request, jsonify
import pyautogui
import subprocess
import base64
import os
import pyperclip  # Add this import at the top
import requests  # Add this import for making HTTP requests

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
    elif action == 'screenshot':
        screenshot_path = '/tmp/screenshot.png'
        try:
            subprocess.run(['scrot', screenshot_path], check=True)
            with open(screenshot_path, 'rb') as image_file:
                encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
            os.remove(screenshot_path)
            return jsonify({'status': 'success', 'image_data': encoded_string})
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    elif action == 'type_keys':
        keys = data.get('keys', [])
        delay = data.get('delay', 0)
        if not keys:
            return jsonify({'error': 'Keys are required'}), 400
        try:
            for key in keys:
                pyautogui.press(key)
                if delay > 0:
                    pyautogui.sleep(delay / 1000)  # Convert milliseconds to seconds
            return jsonify({'status': 'success'})
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    elif action == 'execute_command':
        command = data.get('command')
        if not command:
            return jsonify({'error': 'Command is required'}), 400
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            return jsonify({
                'status': 'success',
                'stdout': result.stdout,
                'stderr': result.stderr,
                'return_code': result.returncode
            })
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    elif action == 'clipboard':
        try:
            clipboard_content = pyperclip.paste()
            return jsonify({
                'status': 'success',
                'content': clipboard_content
            })
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    elif action == 'cursor_position':
        try:
            x, y = pyautogui.position()
            return jsonify({
                'status': 'success',
                'position': {
                    'x': x,
                    'y': y
                }
            })
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    elif action == 'scroll':
        direction = data.get('direction', 'down')
        amount = data.get('amount', 100)
        # Convert amount to negative for upward scrolling
        scroll_amount = -amount if direction == 'up' else amount
        pyautogui.scroll(scroll_amount)
        return jsonify({'status': 'success'})
    elif action == 'trace_mouse':
        path = data.get('path', [])
        hold_keys = data.get('holdKeys', [])
        
        # Hold the specified keys
        for key in hold_keys:
            pyautogui.keyDown(key)
            
        try:
            # Move mouse through each point in the path
            for point in path:
                x = point['x']
                y = point['y']
                pyautogui.moveTo(x, y)
            
            # Release the held keys
            for key in hold_keys:
                pyautogui.keyUp(key)
                
            return jsonify({'status': 'success'})
        except Exception as e:
            # Ensure keys are released even if an error occurs
            for key in hold_keys:
                pyautogui.keyUp(key)
            return jsonify({'error': str(e)}), 500
    elif action == 'drag_mouse':
        path = data.get('path', [])
        button = data.get('button', 'left')
        
        try:
            # Move to start position
            if path:
                x = path[0]['x']
                y = path[0]['y']
                pyautogui.moveTo(x, y)
                
                # Hold the mouse button
                pyautogui.mouseDown(button=button)
                
                # Move through the path
                for point in path[1:]:
                    x = point['x']
                    y = point['y']
                    pyautogui.moveTo(x, y)
                
                # Release the mouse button
                pyautogui.mouseUp(button=button)
                
            return jsonify({'status': 'success'})
        except Exception as e:
            # Ensure mouse button is released even if an error occurs
            pyautogui.mouseUp(button=button)
            return jsonify({'error': str(e)}), 500
    elif action == 'call_api':
        try:
            url = data.get('url')
            headers = data.get('headers', {})
            api_data = data.get('data', {})
            method = data.get('method', 'POST')
            
            if not url:
                return jsonify({'error': 'URL is required'}), 400
                
            response = requests.request(
                method=method,
                url=url,
                headers=headers,
                json=api_data
            )
            
            return jsonify({
                'status': 'success',
                'status_code': response.status_code,
                'response': response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text
            })
        except requests.exceptions.RequestException as e:
            return jsonify({'error': str(e)}), 500
    elif action == 'upload_files':
        files = data.get('files', [])
        if not files:
            return jsonify({'error': 'Files are required'}), 400
        try:
            for file in files:
                path = file['path']
                content = file['content']
                directory = os.path.dirname(path)
                if not os.path.exists(directory):
                    os.makedirs(directory)
                with open(path, 'w') as f:
                    f.write(content)
            return jsonify({'status': 'success'})
        except Exception as e:
            print(e)
            return jsonify({'error': str(e)}), 500
    else:
        return jsonify({'error': 'Invalid action'}), 400

    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9990)