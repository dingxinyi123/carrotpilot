import cv2
import numpy as np

class Camera:
  def __init__(self, cam_type_state, stream_type, camera_id):
    try:
      camera_id = int(camera_id)
    except ValueError:
      pass
    self.cam_type_state = cam_type_state
    self.stream_type = stream_type
    self.cur_frame_id = 0

    self.cap = cv2.VideoCapture(camera_id, cv2.CAP_V4L2)
    self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
    self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    self.cap.set(cv2.CAP_PROP_FPS, 20)
    self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    self.W = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    self.H = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

  @staticmethod
  def bgr2nv12(bgr):
    yuv = cv2.cvtColor(bgr, cv2.COLOR_BGR2YUV_I420)
    h, w = bgr.shape[:2]
    y = yuv[:h]
    u = yuv[h:h + h // 4].reshape(h // 2, w // 2)
    v = yuv[h + h // 4:].reshape(h // 2, w // 2)
    uv = np.empty((h // 2, w), dtype=np.uint8)
    uv[:, 0::2] = u
    uv[:, 1::2] = v
    return np.vstack([y, uv])

  def read_frames(self):
    while True:
      ret, frame = self.cap.read()
      if not ret:
        break
      yuv = Camera.bgr2nv12(frame)
      yield yuv.tobytes()
    self.cap.release()
