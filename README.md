# Ethernet MAC (IEEE 802.3) — UVM Verification

UVM-based functional verification environment for an Ethernet MAC RTL supporting full TX and RX datapaths over GMII, CRC-32 computation and validation, Inter-Frame Gap enforcement, and CRC error detection — built entirely from scratch.

---

## DUT — `eth_mac`

| Parameter | Value |
|---|---|
| Protocol | Ethernet MAC — IEEE 802.3 |
| Interface | GMII (Gigabit Media Independent Interface) |
| Clock | 125 MHz (`gtx_clk`) |
| Data Bus | 8-bit GMII (`txd`, `rxd`) |
| Address Fields | 48-bit Destination + 48-bit Source MAC |
| EtherType | 16-bit |
| Payload Size | 46 – 1500 bytes |
| CRC | CRC-32, polynomial `0xEDB88320`, LSB first |
| Preamble | 7 × `0x55` + SFD `0xD5` |
| Inter-Frame Gap | 12 idle cycles (IEEE 802.3 mandatory) |
| Reset | Active-low asynchronous (`rst_n`) |
| RX Error Flag | `rx_crc_err` — asserted 1 cycle on CRC mismatch |

---

## RTL Architecture — 2 Independent FSMs

```
TX FSM (9 states)                  RX FSM (4 states)
─────────────────                  ─────────────────
TX_IDLE                            RX_IDLE
TX_PREAMBLE  ← 7 × 0x55           RX_PREAMBLE  ← waits for SFD 0xD5
TX_SFD       ← 0xD5               RX_DATA      ← 4-byte shift pipeline
TX_DST_ADDR  ← 6 bytes            RX_CRC_CHECK ← compare CRC, assert rx_crc_err
TX_SRC_ADDR  ← 6 bytes
TX_ETH_TYPE  ← 2 bytes
TX_PAYLOAD   ← variable
TX_CRC       ← 4 bytes LSB first
TX_IFG       ← 12 idle cycles
```

Both FSMs operate independently — TX drives the GMII bus while RX monitors it simultaneously. The RX path uses a **4-byte shift pipeline** to strip the CRC before presenting data, ensuring payload bytes are never contaminated by CRC bytes.

---

## Testbench Architecture

```
┌──────────────────────────────────────────────────────────┐
│                        UVM Test                          │
│         (valid / min / max / rand / crc_err / b2b)       │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│                      UVM Environment                     │
│                                                          │
│  ┌───────────────────────────────────────────────────┐   │
│  │                    UVM Agent                      │   │
│  │                                                   │   │
│  │   ┌─────────────┐      ┌─────────────────────┐   │   │
│  │   │  Sequencer  │─────►│      Driver         │───┼───┼──► DUT (GMII TX)
│  │   └─────────────┘      └─────────────────────┘   │   │
│  │                        ┌─────────────────────┐   │   │
│  │                        │      Monitor        │◄──┼───┼─── DUT (GMII TX loopback)
│  │                        └──────────┬──────────┘   │   │
│  └─────────────────────────────────  │  ────────────┘   │
│                          TLM Analysis│Port               │
│              ┌───────────────────────┼──────────────┐   │
│              │                       ▼              │   │
│              │   ┌──────────────────────────────┐   │   │
│              │   │         Predictor            │   │   │
│              │   │   (recomputes expected CRC)  │   │   │
│              │   └──────────────┬───────────────┘   │   │
│              │                  │ TLM                │   │
│              │   ┌──────────────▼───────────────┐   │   │
│              │   │         Scoreboard           │   │   │
│              │   │   (field + CRC comparison)   │   │   │
│              │   └──────────────────────────────┘   │   │
│              │   ┌──────────────────────────────┐   │   │
│              │   │          Coverage            │   │   │
│              │   │  (payload size, CRC err,     │   │   │
│              │   │   EtherType, cross coverage) │   │   │
│              │   └──────────────────────────────┘   │   │
│              └───────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                             │
                    GMII Virtual Interface
                             │
                    ┌────────▼────────┐
                    │    eth_mac      │
                    │      DUT        │
                    └─────────────────┘
```

---

## Directory Structure

```
eth_mac_uvm/
│
├── rtl/
│   └── eth_mac.sv                  ← DUT: TX + RX FSMs, CRC-32, IFG enforcement
│
├── env/
│   ├── eth_interface.sv            ← GMII virtual interface + clocking blocks
│   ├── eth_trans.sv                ← seq_item: frame fields + constraints
│   ├── eth_sequencer.sv            ← UVM sequencer
│   ├── eth_driver.sv               ← Drives GMII bus cycle-accurately
│   ├── eth_monitor.sv              ← Captures GMII bus, reconstructs frames
│   ├── eth_agent.sv                ← Agent: driver + monitor + sequencer
│   ├── eth_predictor.sv            ← Independently recomputes expected CRC
│   ├── eth_scoreboard.sv           ← PASS/FAIL field + CRC comparison
│   ├── eth_coverage.sv             ← Covergroups: payload size, CRC err, EtherType
│   └── eth_environment.sv          ← Env: agent + scoreboard + predictor
│
├── test/
│   ├── eth_pkg.sv                  ← Package — includes all env + test files in order
│   ├── eth_base_test.sv            ← Base test + base sequence
│   ├── eth_valid_frame_test.sv     ← TC1: valid frame test
│   ├── eth_min_frame_test.sv       ← TC2: minimum frame size
│   ├── eth_max_frame_test.sv       ← TC3: maximum frame size
│   ├── eth_rand_test.sv            ← TC4: constrained-random test
│   ├── eth_crc_error_test.sv       ← TC5: CRC error injection
│   └── eth_back2back_test.sv       ← TC6: back-to-back transmission
│
├── top/
│   └── eth_top.sv                  ← Top: DUT + interface + clock + run_test()
│
└── sim/
    └── Makefile                    ← Compile, run, and clean targets
```

---

## Transaction — `eth_trans`

```systemverilog
class eth_trans extends uvm_sequence_item;
   rand bit [47:0] dst_addr;        // Destination MAC address
   rand bit [47:0] src_addr;        // Source MAC address
   rand bit [15:0] eth_type;        // EtherType / Length field
   rand byte        payload[];      // Variable-length payload
   rand bit         inject_crc_err; // CRC corruption flag
   bit  [31:0]      crc;            // Computed/captured CRC value
   bit               rx_er;         // RX error flag from interface
endclass
```

**Constraints:**
- `payload.size()` constrained to `[46:200]` (EDA sim limit; extend to 1500 for local runs)
- `inject_crc_err == 0` by default — overridden in TC5
- `src_addr != dst_addr` — prevents self-addressed frames

---

## Coverage — `eth_coverage`

| Coverpoint | Signal | Bins |
|---|---|---|
| `cp_payload_size` | `payload.size()` | min `[46:63]`, small `[64:255]`, mid `[256:1023]`, large `[1024:1499]`, max `1500` |
| `cp_crc_err` | `inject_crc_err` | `no_err`, `crc_err` |
| `cp_eth_type` | `eth_type` | `ipv4 (0x0800)`, `ipv6 (0x86DD)`, `arp (0x0806)`, `vlan (0x8100)`, `others` |
| `cx_size_err` | cross | `cp_payload_size × cp_crc_err` |

---

## GMII Interface Signals

| Signal | Direction | Width | Description |
|---|---|---|---|
| `gtx_clk` | MAC → PHY | 1 | 125 MHz transmit clock |
| `tx_en` | MAC → PHY | 1 | TX enable — high for entire frame duration |
| `tx_er` | MAC → PHY | 1 | TX error signal |
| `txd[7:0]` | MAC → PHY | 8 | TX data byte |
| `rx_clk` | PHY → MAC | 1 | RX clock — looped from `gtx_clk` in this TB |
| `rx_dv` | PHY → MAC | 1 | RX data valid — mirrors `tx_en` via loopback |
| `rx_er` | PHY → MAC | 1 | RX error flag |
| `rxd[7:0]` | PHY → MAC | 8 | RX data byte — mirrors `txd` via loopback |
| `col` | PHY → MAC | 1 | Collision detect — tied `0` (full-duplex) |
| `crs` | PHY → MAC | 1 | Carrier sense — tied `0` (full-duplex) |

> **GMII Loopback:** `rx_dv = tx_en`, `rxd = txd` — the monitor observes the TX bus directly on the RX side, eliminating the need for a separate PHY model.

---

## Ethernet Frame Structure

```
┌──────────┬─────┬──────────┬──────────┬───────────┬──────────────────┬─────────┬──────┐
│ Preamble │ SFD │ Dst Addr │ Src Addr │ EtherType │     Payload      │  CRC32  │ IFG  │
│  7 bytes │ 1 B │  6 bytes │  6 bytes │  2 bytes  │  46 – 1500 bytes │ 4 bytes │ 12 B │
│  0x55×7  │0xD5 │  48-bit  │  48-bit  │  16-bit   │  variable        │LSB first│ idle │
└──────────┴─────┴──────────┴──────────┴───────────┴──────────────────┴─────────┴──────┘
```

| Field | Details |
|---|---|
| **Preamble** | 7 bytes of `0x55` — clock sync pattern |
| **SFD** | `0xD5` — marks start of actual frame data |
| **Destination Address** | 6-byte MAC address, MSB first |
| **Source Address** | 6-byte MAC address, MSB first |
| **EtherType** | `0x0800` = IPv4, `0x0806` = ARP, `0x86DD` = IPv6 |
| **Payload** | 46 – 1500 bytes of data |
| **CRC-32** | Computed over dst + src + type + payload, transmitted LSB first |
| **IFG** | 12 idle cycles — mandatory gap between frames per IEEE 802.3 |

---

## Test Suite

| TC | Test Name | Burst / Mode | Frames | What it Verifies |
|---|---|---|---|---|
| tc1 | `eth_valid_frame_test` | Constrained-random | 5 | Full frame integrity — addresses, EtherType, payload, CRC end-to-end |
| tc2 | `eth_min_frame_test` | Fixed 46-byte payload | 3 | IEEE 802.3 minimum frame size handling |
| tc3 | `eth_max_frame_test` | Fixed 200-byte payload | 3 | Large frame handling without data corruption |
| tc4 | `eth_rand_test` | Fully random | 20 | Wide coverage of payload sizes, addresses, EtherTypes |
| tc5 | `eth_crc_error_test` | CRC bits flipped | 5 | CRC mismatch detection — scoreboard flags error correctly |
| tc6 | `eth_back2back_test` | Back-to-back | 10 | IFG enforcement, consecutive frame handling |

---

## How to Run

### EDA Playground — Cadence Xcelium

```
Simulator  : Cadence Xcelium 25.03
UVM        : UVM 1.2
Left panel : design.sv   (RTL)
Right panel: testbench.sv (UVM TB)
Run Option : +TEST=tc1
```

| Run Option | Test |
|---|---|
| `+TEST=tc1` | eth_valid_frame_test |
| `+TEST=tc2` | eth_min_frame_test |
| `+TEST=tc3` | eth_max_frame_test |
| `+TEST=tc4` | eth_rand_test |
| `+TEST=tc5` | eth_crc_error_test |
| `+TEST=tc6` | eth_back2back_test |

### Local — Synopsys VCS

```bash
cd sim/
make comp        # compile RTL + testbench
make valid       # tc1
make min         # tc2
make max         # tc3
make rand        # tc4
make crc_err     # tc5
make b2b         # tc6
make all         # compile + run all 6
make clean       # remove build artifacts
```

---

## Simulation Results

All 6 tests completed with `UVM_ERROR : 0 | UVM_FATAL : 0`

**TC1 — Valid Frame Test**
```
[SCO] TIME=1476000 PASS: dst=9dd7097d3b0f | src=49887ebd0756 | type=c6ff | len=150 | crc=6802a0a6
[SCO] TIME=2428000 PASS: dst=1fb81cd14e44 | src=82fae33d6732 | type=eec6 | len=77  | crc=29fa6de6
[SCO] FINAL REPORT: PASS=5  FAIL=0
```

**TC2 — Minimum Frame Test**
```
[SCO] TIME=644000  PASS: dst=bf6827789519 | src=b0b4d257d8bd | type=cf39 | len=46 | crc=f69b8b09
[SCO] TIME=1348000 PASS: dst=4149ee372921 | src=3c3d44b30fa2 | type=45b5 | len=46 | crc=777669be
[SCO] FINAL REPORT: PASS=3  FAIL=0
```

**TC5 — CRC Error Detection**
```
[SCO] TIME=1636000 PASS (CRC ERROR DETECTED): got=9baa4e17 exp=6455b1e8
[SCO] TIME=2580000 PASS (CRC ERROR DETECTED): got=15c6bb75 exp=ea39448a
[SCO] FINAL REPORT: PASS=5  FAIL=0
```

**TC4 — Random Frame Test**
```
[SCO] TIME=27252000 PASS: dst=844b4bbeda7b | src=6f51d0476eec | type=661d | len=164 | crc=f3e328a5
[SCO] FINAL REPORT: PASS=20  FAIL=0
```

---

## Tools

| Tool | Details |
|---|---|
| Simulator | Cadence Xcelium 25.03 / Synopsys VCS |
| Methodology | UVM 1.2 |
| Language | SystemVerilog (IEEE 1800-2012) |
| Waveform | EPWave (EDA Playground) / Verdi |
| Platform | EDA Playground / Linux (Ubuntu) |
| Protocol | IEEE 802.3 Ethernet MAC over GMII |

---

## Author

**Mahendar R**  
ASIC Verification Engineer  
📧 mahendar20r@gmail.com  
🔗 [LinkedIn](https://linkedin.com/in/mahendar-r-155684265)  
🌐 [Portfolio](https://wanderingsonder.github.io/portfolio)
