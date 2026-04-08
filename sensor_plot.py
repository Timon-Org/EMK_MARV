import queue
import signal
import threading

import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.widgets import Button
import serial

PORT    = '/dev/tty.usbserial-0001'
BAUD    = 9600
LABELS  = ['L_R','L_G','L_B','C_R','C_G','C_B','R_R','R_G','R_B']
HISTORY = 100

# Colour enum order matches assembly: RED=0, GREEN=1, BLUE=2, BLACK=3, WHITE=4
FLOORS       = ['red', 'green', 'blue', 'white', 'black']
MULTIPLIER   = 3       # matching_floor_to_strobe_colour_reading_diff_multiplier_val
SCALE_WB     = 1.375   # applied to white/black totals to normalise against coloured floors

# Race colour the LLI driving state follows (R sensor bit0, C bit1, L bit2)
RACE_COL = 'red'

# ── Serial ────────────────────────────────────────────────────────────────────
frame_queue  = queue.Queue(maxsize=10)
latest_frame = [128] * 9
data         = [[0] * HISTORY for _ in range(9)]
ser          = serial.Serial(PORT, BAUD, timeout=1)

def serial_reader():
    while True:
        if ser.read(1) == b'\xaa':
            raw = ser.read(9)
            if len(raw) == 9:
                try:
                    frame_queue.put_nowait(list(raw))
                except queue.Full:
                    pass

threading.Thread(target=serial_reader, daemon=True).start()

# ── Calibration storage ───────────────────────────────────────────────────────
# Each entry: list of 9 ints [L_R, L_G, L_B, C_R, C_G, C_B, R_R, R_G, R_B]
cal = {f: None for f in FLOORS}

# ── Colour detection ──────────────────────────────────────────────────────────

def _sensor_delta(r, g, b, cal_r, cal_g, cal_b, floor):
    """Delta score for one sensor against one calibrated floor colour."""
    if floor == 'red':
        return abs(cal_r - r) * MULTIPLIER + abs(cal_g - g) + abs(cal_b - b)
    elif floor == 'green':
        return abs(cal_r - r) + abs(cal_g - g) * MULTIPLIER + abs(cal_b - b)
    elif floor == 'blue':
        return abs(cal_r - r) + abs(cal_g - g) + abs(cal_b - b) * MULTIPLIER
    else:  # white / black — no dominant channel, scale total
        return (abs(cal_r - r) + abs(cal_g - g) + abs(cal_b - b)) * SCALE_WB

def detect_sensor_colour(frame, offset):
    """Return the best-matching floor name for a single sensor.
    offset: 0=L, 3=C, 6=R  (matches frame byte order)"""
    r, g, b = frame[offset], frame[offset + 1], frame[offset + 2]
    best, best_score = '???', float('inf')
    for floor in FLOORS:
        if cal[floor] is None:
            continue
        score = _sensor_delta(r, g, b,
                              cal[floor][offset],
                              cal[floor][offset + 1],
                              cal[floor][offset + 2],
                              floor)
        if score < best_score:
            best_score, best = score, floor
    return best

def calc_driving_state(l_col, c_col, r_col):
    """Replicate set_bits_on_colour_perception_array + set_driving_state logic."""
    if l_col == 'black' and c_col == 'black' and r_col == 'black':
        return 'STOP'
    bits = ((1 if l_col == RACE_COL else 0) << 2 |
            (1 if c_col == RACE_COL else 0) << 1 |
            (1 if r_col == RACE_COL else 0))
    if bits in (0b001, 0b011):
        return 'RIGHT'
    if bits == 0b010:
        return 'CENTRE'
    if bits in (0b100, 0b110):
        return 'LEFT'
    return 'LOST'

# ── Figure layout ─────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(13, 8))
fig.patch.set_facecolor('#1a1a1a')

ax_plot = fig.add_axes([0.07, 0.38, 0.90, 0.56])
ax_plot.set_facecolor('#252525')
ax_plot.set_ylim(0, 255)
ax_plot.set_xlim(0, HISTORY)
ax_plot.tick_params(colors='#aaaaaa')
for sp in ax_plot.spines.values():
    sp.set_edgecolor('#555555')

PLOT_CLR = ['#ff4444','#44dd44','#4488ff',
            '#ff9999','#99dd99','#99bbff',
            '#ffcccc','#ccffcc','#ccddff']
lines = [ax_plot.plot([], [], color=PLOT_CLR[i], label=LABELS[i], linewidth=1)[0]
         for i in range(9)]
ax_plot.legend(loc='upper right', facecolor='#252525', labelcolor='#cccccc', fontsize=7)

# ── Calibration buttons ───────────────────────────────────────────────────────
BTN_CFG = [
    ('red',   'Cal Red',   '#992222', 'white'),
    ('green', 'Cal Green', '#226622', 'white'),
    ('blue',  'Cal Blue',  '#224488', 'white'),
    ('white', 'Cal White', '#cccccc', 'black'),
    ('black', 'Cal Black', '#444444', 'white'),
]

btn_objects  = []
cal_dots     = []

for i, (floor, label, face, txtcol) in enumerate(BTN_CFG):
    ax_btn = fig.add_axes([0.07 + i * 0.178, 0.22, 0.155, 0.09])
    btn = Button(ax_btn, label, color=face, hovercolor=face)
    btn.label.set_color(txtcol)
    btn.label.set_fontsize(9)
    btn.label.set_fontweight('bold')
    btn_objects.append(btn)

    # Calibrated indicator dot (grey until calibrated)
    dot = fig.text(0.148 + i * 0.178, 0.205, '●', color='#444444',
                   fontsize=10, ha='center', va='center')
    cal_dots.append(dot)

DOT_CLR = ['#ff5555', '#55cc55', '#5599ff', '#dddddd', '#999999']

def make_cal_cb(floor, idx):
    def cb(event):
        cal[floor] = list(latest_frame)
        cal_dots[idx].set_color(DOT_CLR[idx])
        fig.canvas.draw_idle()
    return cb

for i, (floor, *_) in enumerate(BTN_CFG):
    btn_objects[i].on_clicked(make_cal_cb(floor, i))

# ── Status bar ────────────────────────────────────────────────────────────────
ax_status = fig.add_axes([0.07, 0.03, 0.90, 0.14])
ax_status.set_facecolor('#252525')
ax_status.axis('off')
for sp in ax_status.spines.values():
    sp.set_edgecolor('#555555')

SENSOR_X = [0.15, 0.42, 0.68]
sensor_labels = ['L', 'C', 'R']
sensor_txts = []
for x, lbl in zip(SENSOR_X, sensor_labels):
    ax_status.text(x, 0.78, lbl, color='#888888', fontsize=9,
                   ha='center', va='center', transform=ax_status.transAxes)
    t = ax_status.text(x, 0.35, '---', color='#888888', fontsize=14,
                       ha='center', va='center', fontweight='bold',
                       transform=ax_status.transAxes)
    sensor_txts.append(t)

drive_txt = ax_status.text(0.88, 0.5, 'Drive: ---', color='#ffff44',
                            fontsize=13, ha='center', va='center',
                            fontweight='bold', transform=ax_status.transAxes)

COLOUR_CLR = {
    'red':   '#ff5555',
    'green': '#55dd55',
    'blue':  '#6699ff',
    'white': '#ffffff',
    'black': '#999999',
    '???':   '#666666',
}
DRIVE_CLR = {
    'CENTRE': '#55dd55',
    'LEFT':   '#ffaa33',
    'RIGHT':  '#ffaa33',
    'STOP':   '#ff4444',
    'LOST':   '#ff44ff',
}

# ── Animation update ──────────────────────────────────────────────────────────

def update(_):
    global latest_frame
    try:
        frame = frame_queue.get_nowait()
        latest_frame = frame

        for i, val in enumerate(frame):
            data[i].append(val)
            data[i] = data[i][-HISTORY:]
            lines[i].set_data(range(len(data[i])), data[i])

        if any(cal[f] is not None for f in FLOORS):
            colours = [detect_sensor_colour(frame, off) for off in (0, 3, 6)]
            state   = calc_driving_state(*colours)
            for txt, col in zip(sensor_txts, colours):
                txt.set_text(col.capitalize())
                txt.set_color(COLOUR_CLR.get(col, '#888888'))
            drive_txt.set_text(f'Drive: {state}')
            drive_txt.set_color(DRIVE_CLR.get(state, '#ffff44'))

    except queue.Empty:
        pass
    return lines

signal.signal(signal.SIGINT, lambda *_: plt.close('all'))
ani = animation.FuncAnimation(fig, update, interval=50, blit=False)
plt.show()
ser.close()
