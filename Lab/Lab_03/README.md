# Lab 3 — MicroBlaze GPIO and PWM

The MicroBlaze application reads the Nexys A7 switches through AXI GPIO
and mirrors their states on the LEDs. It uses memory-mapped registers
to refresh the four seven-segment digits one at a time, displaying the
switch value in hexadecimal. The custom PWM IP from Lab 1 controls the
red, green, and blue channels of the RGB LED.

- [Vivado block design](Screenshot%202026-11-06%20002341.png)
- [Lab 3 utilization report](lab3_utilization.rpt)
- [Application source](main.c)

## Implementation utilization

Both reports were generated after routing for the same FPGA
(`xc7a100tcsg324-1`). The table compares the **Used** counts.

| Resource | Lab 2 used | Lab 3 used | Change |
|---|---:|---:|---:|
| Slice LUTs | 1,518 | 1,741 | +223 |
| Slice Registers | 1,487 | 2,033 | +546 |
| Block RAM Tiles | 32 | 32 | 0 |
| DSPs | 0 | 0 | 0 |

Lab 3 adds two AXI GPIO blocks and the custom PWM IP. The design uses
more logic and registers while keeping the same block RAM and DSP usage.

## Board demo

Turn on one switch at a time and check the display and LEDs:

| Switch | Seven-segment display | Individual LED | RGB LED |
|---|---|---|---|
| SW3 | `0008` | LED 3 | Red |
| SW7 | `0080` | LED 7 | Green |
| SW11 | `0800` | LED 11 | Blue |
