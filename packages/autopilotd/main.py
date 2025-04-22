from flask import Flask, request, jsonify
import pyautogui
import subprocess
import base64
import os
import pyperclip
import requests
import tempfile
import cv2
import numpy as np
import pytesseract
from PIL import Image

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
            subprocess.run(['gnome-screenshot', '-f', screenshot_path], check=True)
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
    elif action == 'locate_on_screen':
        image_data = data.get('image_data')
        confidence = float(data.get('confidence', 0.9))
        if not image_data:
            return jsonify({'error': 'Image data is required'}), 400
        try:
            # Create a temporary file with a random name to store the decoded image
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as temp_file:
                temp_path = temp_file.name
                image_bytes = base64.b64decode(image_data)
                temp_file.write(image_bytes)
            
            # Use the temporary file for screen location detection
            location = pyautogui.locateOnScreen(temp_path, confidence=confidence)
            
            # Clean up the temporary file
            os.remove(temp_path)
            
            if location:
                return jsonify({
                    'status': 'success',
                    'location': {
                        'x': location.left,
                        'y': location.top,
                        'width': location.width,
                        'height': location.height
                    }
                })
            return jsonify({
                'status': 'success',
                'location': None
            })
        except Exception as e:
            # Ensure temporary file is cleaned up even if an error occurs
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return jsonify({'error': str(e)}), 500
    elif action == 'locate_text':
        text_to_find = data.get('text')
        confidence = float(data.get('confidence', 0.7))
        if not text_to_find:
            return jsonify({'error': 'Text to find is required'}), 400
        try:
            # Take a screenshot of the screen
            screenshot = pyautogui.screenshot()
            
            # Convert the PIL image to an OpenCV image (numpy array)
            screenshot_np = np.array(screenshot)
            screenshot_cv = cv2.cvtColor(screenshot_np, cv2.COLOR_RGB2BGR)
            
            # Convert to grayscale for better OCR results
            gray = cv2.cvtColor(screenshot_cv, cv2.COLOR_BGR2GRAY)
            
            # Apply some preprocessing to improve OCR accuracy
            # Apply thresholding to get a binary image
            _, binary = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
            
            # Perform OCR on the image
            ocr_data = pytesseract.image_to_data(binary, output_type=pytesseract.Output.DICT)
            
            # Find the text in the OCR results
            text_locations = []
            for i in range(len(ocr_data['text'])):
                # Get the text and its confidence
                detected_text = ocr_data['text'][i]
                text_confidence = float(ocr_data['conf'][i]) / 100.0  # Convert to 0-1 range
                
                # Check if the text matches (case insensitive) and has sufficient confidence
                if (detected_text.lower() == text_to_find.lower() or text_to_find.lower() in detected_text.lower()) and text_confidence >= confidence:
                    # Get the bounding box
                    x = ocr_data['left'][i]
                    y = ocr_data['top'][i]
                    width = ocr_data['width'][i]
                    height = ocr_data['height'][i]
                    
                    text_locations.append({
                        'x': x,
                        'y': y,
                        'width': width,
                        'height': height,
                        'confidence': text_confidence,
                        'detected_text': detected_text
                    })
            
            if text_locations:
                return jsonify({
                    'status': 'success',
                    'locations': text_locations
                })
            return jsonify({
                'status': 'success',
                'locations': []
            })
        except Exception as e:
            print(f'Error in locate_text: {str(e)}')
            return jsonify({'error': str(e)}), 500
    else:
        return jsonify({'error': 'Invalid action'}), 400

    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9990)