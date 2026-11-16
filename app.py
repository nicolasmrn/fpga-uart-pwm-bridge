from flask import Flask, render_template
from flask_socketio import SocketIO, emit
import socket
import pyaudio
import numpy as np
import threading
import time
import subprocess
import sys
import colorsys # Pour l'arc-en-ciel
import random   # Pour le feu

# ================= CONFIGURATION =================
ESP_IP = "10.0.0.1"
ESP_PORT = 8080

WIFI_NEXYS_SSID = "Nexys_AP"
WIFI_NEXYS_PASS = "12345678"

# Rate Limiter
FPS_LIMIT = 20           
MIN_TIME_BETWEEN_SENDS = 1.0 / FPS_LIMIT 

# Audio
CHUNK = 1024
RATE = 44100

# ================= VARIABLES =================
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

sock = None
last_tcp_send_time = 0
original_wifi_ssid = None 

state = {
    "current_effect": "manual", # manual, disco, police, pulse, rainbow, fire
    "connected_to_fpga": False,
    "wifi_status": "Déconnecté",
    "r": 0, "g": 0, "b": 0,
    "sensitivity": 1.0,
    "expansion": 2.0
}

rm_bass, rm_mid, rm_treble = 1000.0, 1000.0, 1000.0

# ================= GESTION WIFI =================
def get_current_wifi():
    try:
        cmd = ['networksetup', '-getairportnetwork', 'en0']
        res = subprocess.run(cmd, capture_output=True, text=True)
        if "Current Wi-Fi Network: " in res.stdout:
            return res.stdout.split(": ")[1].strip()
        return None
    except: return None

def switch_wifi(ssid, password=None):
    print(f"🔄 Bascule Wifi vers {ssid}...")
    cmd = ['networksetup', '-setairportnetwork', 'en0', ssid]
    if password: cmd.append(password)
    subprocess.run(cmd)
    
    print("⏳ Attente connexion...")
    for _ in range(12): 
        time.sleep(0.5)
        current = get_current_wifi()
        if current == ssid:
            print("✅ Wifi accroché !")
            time.sleep(1.5)
            return

# ================= GESTION TCP =================
def connect_tcp():
    global sock
    try:
        if sock: sock.close()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.settimeout(2)
        sock.connect((ESP_IP, ESP_PORT))
        state["connected_to_fpga"] = True
        state["wifi_status"] = "Connecté (Nexys)"
        print("✅ TCP Connecté")
        return True
    except Exception as e:
        print(f"❌ Erreur TCP: {e}")
        state["connected_to_fpga"] = False
        state["wifi_status"] = "Erreur TCP"
        return False

def disconnect_tcp():
    global sock
    if sock:
        try:
            sock.send(b"0,0,0\n")
            time.sleep(0.1)
            sock.close()
        except: pass
    sock = None
    state["connected_to_fpga"] = False
    state["wifi_status"] = "Déconnecté"

def send_rgb_tcp(r, g, b, force=False):
    global sock, last_tcp_send_time, state
    if not sock or not state["connected_to_fpga"]: return

    current_time = time.time()
    is_off_command = (r == 0 and g == 0 and b == 0)
    
    if not force and not is_off_command:
        if (current_time - last_tcp_send_time) < MIN_TIME_BETWEEN_SENDS:
            return

    try:
        msg = f"{int(r)},{int(g)},{int(b)}\n"
        sock.send(msg.encode('utf-8'))
        last_tcp_send_time = time.time()
    except:
        state["connected_to_fpga"] = False

# ================= ROUTES WEB =================
@socketio.on('wifi_action')
def handle_wifi(data):
    global original_wifi_ssid
    action = data.get('action')

    if action == 'connect':
        current = get_current_wifi()
        if current and current != WIFI_NEXYS_SSID:
            original_wifi_ssid = current
        
        emit('wifi_progress', {'msg': f"Connexion {WIFI_NEXYS_SSID}..."})
        switch_wifi(WIFI_NEXYS_SSID, WIFI_NEXYS_PASS)
        
        emit('wifi_progress', {'msg': "Connexion TCP..."})
        if connect_tcp():
            emit('wifi_done', {'status': 'connected'})
        else:
            emit('wifi_done', {'status': 'error'})

    elif action == 'disconnect':
        disconnect_tcp()
        if original_wifi_ssid:
            emit('wifi_progress', {'msg': f"Retour {original_wifi_ssid}..."})
            switch_wifi(original_wifi_ssid)
        emit('wifi_done', {'status': 'disconnected'})

@socketio.on('change_color')
def handle_color(data):
    if state["current_effect"] == "manual":
        r, g, b = int(data['r']), int(data['g']), int(data['b'])
        if r == 0 and g == 0 and b == 0:
            send_rgb_tcp(0, 0, 0, force=True)
        else:
            send_rgb_tcp(r, g, b, force=False)
        emit('server_update', data, broadcast=True)

@socketio.on('set_effect')
def handle_effect(data):
    state["current_effect"] = data['effect']
    print(f"✨ Mode : {state['current_effect']}")
    emit('status', state, broadcast=True)

@socketio.on('settings_update')
def handle_settings(data):
    state["sensitivity"] = float(data['sens'])
    state["expansion"] = float(data['exp'])

@app.route('/')
def index(): return render_template('index.html')

@socketio.on('connect')
def handle_connect():
    ssid = get_current_wifi()
    if ssid == WIFI_NEXYS_SSID:
        state["connected_to_fpga"] = True
        state["wifi_status"] = "Connecté (Nexys)"
    else:
        state["connected_to_fpga"] = False
        state["wifi_status"] = "Déconnecté"
    emit('status', state)

# ================= MOTEUR D'EFFETS =================
def lighting_engine():
    global rm_bass, rm_mid, rm_treble
    p = pyaudio.PyAudio()
    try: stream = p.open(format=pyaudio.paInt16, channels=1, rate=RATE, input=True, frames_per_buffer=CHUNK)
    except: stream = None
    
    MIN_VOL_THRESHOLD = 80.0 

    while True:
        socketio.sleep(0.01)
        effect = state["current_effect"]

        # Si pas connecté ou manuel, on purge juste l'audio
        if effect == "manual" or not state["connected_to_fpga"]:
            if stream and stream.get_read_available() > CHUNK: 
                try: stream.read(CHUNK, exception_on_overflow=False)
                except: pass
            continue
        
        # Rate Limiter
        if (time.time() - last_tcp_send_time) < MIN_TIME_BETWEEN_SENDS:
             if stream and stream.get_read_available() > CHUNK: 
                 try: stream.read(CHUNK, exception_on_overflow=False)
                 except: pass
             continue 

        r_final, g_final, b_final = 0, 0, 0

        # --- 1. DISCO (Audio) ---
        if effect == "disco" and stream:
            try:
                data = np.frombuffer(stream.read(CHUNK, exception_on_overflow=False), dtype=np.int16)
                fft_data = np.abs(np.fft.rfft(data))
                freqs = np.fft.rfftfreq(len(data), 1.0/RATE)
                
                bass_idx = np.where((freqs >= 60) & (freqs < 200))[0]
                mid_idx = np.where((freqs >= 400) & (freqs < 3000))[0]
                treble_idx = np.where((freqs >= 5000) & (freqs < 16000))[0]

                b_raw = np.max(fft_data[bass_idx]) if len(bass_idx)>0 else 0
                m_raw = np.mean(fft_data[mid_idx]) if len(mid_idx)>0 else 0
                t_raw = np.mean(fft_data[treble_idx]) if len(treble_idx)>0 else 0

                rm_bass = max(rm_bass * 0.95, b_raw)
                rm_mid = max(rm_mid * 0.95, m_raw)
                rm_treble = max(rm_treble * 0.95, t_raw)

                if rm_bass < MIN_VOL_THRESHOLD: rm_bass = MIN_VOL_THRESHOLD
                if rm_mid < MIN_VOL_THRESHOLD: rm_mid = MIN_VOL_THRESHOLD
                if rm_treble < MIN_VOL_THRESHOLD: rm_treble = MIN_VOL_THRESHOLD

                r = min(1.0, (b_raw / rm_bass) * state["sensitivity"])
                g = min(1.0, (m_raw / rm_mid) * 1.8 * state["sensitivity"])
                b = min(1.0, (t_raw / rm_treble) * 2.5 * state["sensitivity"])

                r_final = int(pow(r, state["expansion"]) * 255)
                g_final = int(pow(g, state["expansion"]) * 255)
                b_final = int(pow(b, state["expansion"]) * 255)

                if r_final < 20: r_final = 0
                if g_final < 20: g_final = 0
                if b_final < 20: b_final = 0

            except: pass

        # --- 2. POLICE (Gyrophare) ---
        elif effect == "police":
            t = time.time()
            if (t % 0.6) < 0.3:
                r_final, g_final, b_final = 255, 0, 0
            else:
                r_final, g_final, b_final = 0, 0, 255

        # --- 3. PULSE (Respiration) ---
        elif effect == "pulse":
            intensity = (np.sin(time.time() * 2) + 1) / 2 
            r_final = int(180 * intensity)
            b_final = int(255 * intensity)

        # --- 4. RAINBOW (Arc-en-ciel) ---
        elif effect == "rainbow":
            # On fait varier la teinte (Hue) selon le temps
            hue = (time.time() * 0.2) % 1.0 # Cycle complet toutes les 5 sec
            rgb = colorsys.hsv_to_rgb(hue, 1.0, 1.0)
            r_final, g_final, b_final = int(rgb[0]*255), int(rgb[1]*255), int(rgb[2]*255)

        # --- 5. FIRE (Feu) ---
        elif effect == "fire":
            # Base Rouge, un peu de vert pour faire du Jaune/Orange
            flicker = random.randint(0, 60)
            r_final = 255 - random.randint(0, 20) # Rouge toujours fort
            g_final = max(0, 100 + flicker - 40)  # Vert varie pour faire l'orange
            b_final = 0

        # Envoi
        send_rgb_tcp(r_final, g_final, b_final)
        socketio.emit('server_update', {'r':r_final, 'g':g_final, 'b':b_final})

if __name__ == '__main__':
    threading.Thread(target=lighting_engine, daemon=True).start()
    print("🌍 SERVEUR PRET : http://127.0.0.1:5001")
    socketio.run(app, host='0.0.0.0', port=5001)