from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
import pyautogui
import subprocess
import base64
import os
import pyperclip
import requests
import tempfile
import cv2
import numpy as np
import easyocr
from PIL import Image
from typing import Optional, List, Dict, Any
from pydantic import BaseModel

app = FastAPI()

class MouseCoordinates(BaseModel):
    x: int
    y: int

class Point(BaseModel):
    x: int
    y: int

class FileUpload(BaseModel):
    path: str
    content: str

class ComputerUseRequest(BaseModel):
    action: str
    coordinates: Optional[MouseCoordinates] = None
    button: Optional[str] = None
    numClicks: Optional[int] = 1
    text: Optional[str] = None
    delay: Optional[int] = 0
    keys: Optional[List[str]] = None
    modifiers: Optional[List[str]] = None
    command: Optional[str] = None
    url: Optional[str] = None
    headers: Optional[Dict[str, str]] = {}
    data: Optional[Dict[str, Any]] = {}
    method: Optional[str] = 'POST'
    files: Optional[List[FileUpload]] = None
    path: Optional[List[Point]] = None
    holdKeys: Optional[List[str]] = None
    direction: Optional[str] = 'down'
    amount: Optional[int] = 100
    text_to_find: Optional[str] = None
    confidence: Optional[float] = 0.7

@app.post('/computer-use')
async def computer_use(request: ComputerUseRequest):
    if request.action == 'move_mouse':
        subprocess.run(['xdotool', 'mousemove', str(request.coordinates.x), str(request.coordinates.y)])
    elif request.action == 'click_mouse':
        subprocess.run(['xdotool', 'click', '--repeat', str(request.numClicks), request.button])
    elif request.action == 'type_text':
        subprocess.run(['xdotool', 'type', '--delay', str(request.delay), request.text])
    elif request.action == 'mouse_move':
        pyautogui.moveTo(x=request.coordinates.x, y=request.coordinates.y, duration=request.delay)
    elif request.action == 'mouse_click':
        pyautogui.click(button=request.button)
    elif request.action == 'press_keys':
        for modifier in request.modifiers or []:
            pyautogui.keyDown(modifier)
        for key in request.keys:
            pyautogui.press(key)
        for modifier in request.modifiers or []:
            pyautogui.keyUp(modifier)
    elif request.action == 'hotkey':
        pyautogui.hotkey(*request.keys)
    elif request.action == 'screenshot':
        screenshot_path = '/tmp/screenshot.png'
        try:
            subprocess.run(['gnome-screenshot', '-f', screenshot_path], check=True)
            with open(screenshot_path, 'rb') as image_file:
                encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
            os.remove(screenshot_path)
            return {'status': 'success', 'image_data': encoded_string}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'type_keys':
        if not request.keys:
            raise HTTPException(status_code=400, detail='Keys are required')
        try:
            for key in request.keys:
                pyautogui.press(key)
                if request.delay > 0:
                    pyautogui.sleep(request.delay / 1000)  # Convert milliseconds to seconds
            return {'status': 'success'}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'execute_command':
        if not request.command:
            raise HTTPException(status_code=400, detail='Command is required')
        try:
            result = subprocess.run(request.command, shell=True, capture_output=True, text=True)
            return {
                'status': 'success',
                'stdout': result.stdout,
                'stderr': result.stderr,
                'return_code': result.returncode
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'clipboard':
        try:
            clipboard_content = pyperclip.paste()
            return {
                'status': 'success',
                'content': clipboard_content
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'cursor_position':
        try:
            x, y = pyautogui.position()
            return {
                'status': 'success',
                'position': {
                    'x': x,
                    'y': y
                }
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'scroll':
        scroll_amount = -request.amount if request.direction == 'up' else request.amount
        pyautogui.scroll(scroll_amount)
        return {'status': 'success'}
    elif request.action == 'trace_mouse':
        for key in request.holdKeys or []:
            pyautogui.keyDown(key)
        try:
            for point in request.path or []:
                pyautogui.moveTo(point.x, point.y)
            for key in request.holdKeys or []:
                pyautogui.keyUp(key)
            return {'status': 'success'}
        except Exception as e:
            for key in request.holdKeys or []:
                pyautogui.keyUp(key)
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'drag_mouse':
        try:
            if request.path:
                pyautogui.moveTo(request.path[0].x, request.path[0].y)
                pyautogui.mouseDown(button=request.button or 'left')
                for point in request.path[1:]:
                    pyautogui.moveTo(point.x, point.y)
                pyautogui.mouseUp(button=request.button or 'left')
            return {'status': 'success'}
        except Exception as e:
            pyautogui.mouseUp(button=request.button or 'left')
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'call_api':
        try:
            if not request.url:
                raise HTTPException(status_code=400, detail='URL is required')
            response = requests.request(
                method=request.method,
                url=request.url,
                headers=request.headers,
                json=request.data
            )
            return {
                'status': 'success',
                'status_code': response.status_code,
                'response': response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text
            }
        except requests.exceptions.RequestException as e:
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'upload_files':
        if not request.files:
            raise HTTPException(status_code=400, detail='Files are required')
        try:
            for file in request.files:
                directory = os.path.dirname(file.path)
                if not os.path.exists(directory):
                    os.makedirs(directory)
                with open(file.path, 'w') as f:
                    f.write(file.content)
            return {'status': 'success'}
        except Exception as e:
            print(e)
            raise HTTPException(status_code=500, detail=str(e))
    elif request.action == 'locate_text':
        try:
            screenshot = pyautogui.screenshot()
            screenshot_np = np.array(screenshot)
            screenshot_cv = cv2.cvtColor(screenshot_np, cv2.COLOR_RGB2BGR)
            gray = cv2.cvtColor(screenshot_cv, cv2.COLOR_BGR2GRAY)
            _, binary = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
            reader = easyocr.Reader(['en'])
            results = reader.readtext(screenshot_cv)
            
            text_locations = []
            for (bbox, detected_text, text_confidence) in results:
                if not request.text_to_find or (
                    (detected_text.lower() == request.text_to_find.lower() or 
                    request.text_to_find.lower() in detected_text.lower())) and text_confidence >= request.confidence:
                    # bbox format: [[x1,y1], [x2,y1], [x2,y2], [x1,y2]]
                    x1, y1 = bbox[0]
                    x2, y2 = bbox[2]
                    text_locations.append({
                        'x': int(x1),
                        'y': int(y1),
                        'width': int(x2 - x1),
                        'height': int(y2 - y1),
                        'confidence': text_confidence,
                        'detected_text': detected_text
                    })
            
            return {
                'status': 'success',
                'locations': text_locations
            }
        except Exception as e:
            print(f'Error in locate_text: {str(e)}')
            raise HTTPException(status_code=500, detail=str(e))
    else:
        raise HTTPException(status_code=400, detail='Invalid action')

    return {'status': 'success'}

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=9990)