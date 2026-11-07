#include "xparameters.h"
#include "xil_io.h"
#include "xil_types.h"
#include "sleep.h"

#define GPIO0_BASE XPAR_AXI_GPIO_0_BASEADDR
#define GPIO1_BASE XPAR_AXI_GPIO_1_BASEADDR
#define PWM_BASE   XPAR_PWM_AXI_0_BASEADDR

#define GPIO_SW   0x00U
#define GPIO_LED  0x08U
#define SEG_REG   0x00U
#define AN_REG    0x08U

#define PWM_CTRL  0x00U
#define PWM_R     0x04U
#define PWM_G     0x08U
#define PWM_B     0x0CU

static const u8 seg[16] = {
    0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8,
    0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E
};

static void show_hex(u32 value)
{
    for (u32 digit = 0; digit < 4U; ++digit) {
        u32 hex_digit = (value >> (4U * digit)) & 0xFU;

        Xil_Out32(GPIO1_BASE + AN_REG, 0xFFU);  /* All digits off */
        Xil_Out32(GPIO1_BASE + SEG_REG, seg[hex_digit]);
        Xil_Out32(GPIO1_BASE + AN_REG, 0xFFU & ~(1U << digit));
        usleep(1000);
    }
}

int main(void)
{
    Xil_Out32(GPIO1_BASE + 0x04U, 0U);  /* Segments are outputs */
    Xil_Out32(GPIO1_BASE + 0x0CU, 0U);  /* Digit enables are outputs */
    Xil_Out32(GPIO1_BASE + AN_REG, 0xFFU);

    Xil_Out32(PWM_BASE + PWM_CTRL, 1U);

    while (1) {
        u32 sw = Xil_In32(GPIO0_BASE + GPIO_SW) & 0xFFFFU;

        Xil_Out32(GPIO0_BASE + GPIO_LED, sw);
        Xil_Out32(PWM_BASE + PWM_R, (sw & 0xFU) * 17U);
        Xil_Out32(PWM_BASE + PWM_G, ((sw >> 4U) & 0xFU) * 17U);
        Xil_Out32(PWM_BASE + PWM_B, ((sw >> 8U) & 0xFU) * 17U);

        show_hex(sw);
    }
}