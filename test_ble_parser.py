import math

def parse_hr_0x2a37(bytes_data):
    if not bytes_data:
        return {'bpm': 0, 'rr_ms': []}
    
    flags = bytes_data[0]
    is_16bit = (flags & 0x01) != 0
    energy_present = (flags & 0x08) != 0
    rr_present = (flags & 0x10) != 0

    offset = 1
    if is_16bit:
        bpm = bytes_data[offset] | (bytes_data[offset + 1] << 8)
        offset += 2
    else:
        bpm = bytes_data[offset]
        offset += 1

    if energy_present:
        offset += 2

    rr_list = []
    if rr_present:
        while len(bytes_data) >= offset + 2:
            raw_rr = bytes_data[offset] | (bytes_data[offset + 1] << 8)
            rr_ms = (raw_rr / 1024.0) * 1000.0
            rr_list.append(rr_ms)
            offset += 2

    return {'bpm': bpm, 'rr_ms': rr_list}

class RRCircularBuffer:
    def __init__(self, capacity=500):
        self.capacity = capacity
        self.buffer = []

    def add(self, val):
        if len(self.buffer) >= self.capacity:
            self.buffer.pop(0)
        self.buffer.append(val)

    def rmssd(self):
        if len(self.buffer) < 2:
            return 0.0
        diffs_sq = [(self.buffer[i+1] - self.buffer[i])**2 for i in range(len(self.buffer)-1)]
        mean_sq = sum(diffs_sq) / len(diffs_sq)
        return math.sqrt(mean_sq)

def test_ble():
    print("=== TEST PARSER BLE 0x2A37 E RR CIRCULAR BUFFER ===")
    
    test_bytes = [0x10, 65, 0x47, 0x03, 0x5C, 0x03]
    parsed = parse_hr_0x2a37(test_bytes)
    
    print("[PARSED BPM]:", parsed['bpm'])
    print("[PARSED RR MS]:", parsed['rr_ms'])
    
    assert parsed['bpm'] == 65
    assert len(parsed['rr_ms']) == 2
    assert abs(parsed['rr_ms'][0] - 819.33) < 1.0

    buf = RRCircularBuffer(capacity=5)
    for rr in [800.0, 820.0, 810.0, 830.0, 815.0]:
        buf.add(rr)

    rmssd_val = buf.rmssd()
    print("[BUFFER SIZE]:", len(buf.buffer))
    print("[HRV rMSSD MS]:", round(rmssd_val, 2))
    assert rmssd_val > 0.0

    print("[SUCCESS] Tutti i test del parser BLE e Buffer R-R completati con successo!")

if __name__ == "__main__":
    test_ble()
