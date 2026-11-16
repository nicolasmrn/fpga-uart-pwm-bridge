# FPGA UART-to-PWM Bridge & Wi-Fi Controller

![HDL](https://img.shields.io/badge/HDL-VHDL-blue.svg)
![Target](https://img.shields.io/badge/FPGA-Digilent%20Nexys%20A7--100T-success.svg)
![Interface](https://img.shields.io/badge/Protocol-UART%20%2F%20Wi--Fi%20(ESP32)-orange.svg)

A complete hardware/software embedded system implementing a **Wi-Fi-to-FPGA communication bridge** and a **3-channel RGB PWM controller** in pure **VHDL** on a **Nexys A7-100T (Artix-7)** board.

A Python/WebSocket host interface (`app.py`) sends real-time lighting commands over Wi-Fi to a **Pmod ESP32** module, which forwards serial frames to the FPGA where a custom RTL pipeline buffers, parses, and executes hardware PWM modulation and animation patterns.

---

## System Architecture

```mermaid
flowchart LR
    classDef sw fill:#1e293b,stroke:#94a3b8,stroke-width:1px,color:#f8fafc
    classDef hw fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#e2e8f0
    classDef fifo fill:#334155,stroke:#f59e0b,stroke-width:2px,color:#fef3c7

    subgraph HOST ["Host & Wireless Link"]
        WEB["Web UI & Flask/SocketIO<br/>(app.py / index.html)"]:::sw
        ESP["Pmod ESP32<br/>(Wi-Fi to UART)"]:::sw
        WEB <-->|"WebSocket / Wi-Fi"| ESP
    end

    subgraph FPGA ["Artix-7 FPGA RTL Pipeline (VHDL)"]
        direction LR
        WIFI["Wi-Fi Init Controller<br/>(wifi_controller.vhd)"]:::hw
        UART["UART RX / TX<br/>(uart_recv / transmetteur)"]:::hw
        FIFO[("Synchronous FIFO<br/>(fifo.vhd)")]:::fifo
        FSM["Control FSM & Parser<br/>(fsm.vhd / parser.vhd)"]:::hw
        ANIM["Animation Engine & Mux<br/>(led_animation / multiplexeur)"]:::hw
        PWM["3-Channel PWM Gen<br/>(PWM.vhd)"]:::hw

        WIFI <--> UART
        ESP <-->|"UART 115200 bps"| UART
        UART --> FIFO
        FIFO --> FSM
        FSM --> ANIM
        ANIM --> PWM
    end

    PWM --> LED["RGB LEDs<br/>(Nexys A7)"]:::sw
