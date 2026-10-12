#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "sleep.h"

/* Hardware addresses from this project's generated xparameters.h. */
#define DMA_BASEADDR       XPAR_XAXIDMA_0_BASEADDR
#define BUTTON_GPIO_BASE   XPAR_XGPIO_0_BASEADDR
#define START_GPIO_BASE    XPAR_XGPIO_1_BASEADDR
#define FRAME_RAM_BASE     XPAR_AXI4_FULL_RAM_0_BASEADDR

#define GPIO_CHANNEL       1U
#define GPIO_BIT0          0x1U
#define BUTTON_ACTIVE      1U     /* PYNQ-Z1 pushbutton is active high. */
#define START_ACTIVE       1U

#define FRAME_WIDTH        320U
#define FRAME_HEIGHT       200U
#define FRAME_BYTES        (FRAME_WIDTH * FRAME_HEIGHT) /* 64,000 bytes */
#define FRAME_WORDS        (FRAME_BYTES / 4U)           /* 16,000 words */
#define DMA_WAIT_MS        5000U

#ifdef SIMULATION
#define BUTTON_POLL_US     100U
#define BUTTON_DEBOUNCE_US 200U
#else
#define BUTTON_POLL_US     10000U
#define BUTTON_DEBOUNCE_US 20000U
#endif

static XAxiDma Dma;
static XGpio ButtonGpio;
static XGpio StartGpio;

static int initialize_hardware(void)
{
    int status;
    XAxiDma_Config *dma_config;

    /* In this SDT-based Vitis platform, driver initialization uses base addresses. */
    status = XGpio_Initialize(&ButtonGpio, BUTTON_GPIO_BASE);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: button AXI GPIO init failed: %d\r\n", status);
        return status;
    }

    status = XGpio_Initialize(&StartGpio, START_GPIO_BASE);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: start AXI GPIO init failed: %d\r\n", status);
        return status;
    }

    /* Direction bit 1 means input; bit 0 means output. */
    XGpio_SetDataDirection(&ButtonGpio, GPIO_CHANNEL, GPIO_BIT0);
    XGpio_SetDataDirection(&StartGpio, GPIO_CHANNEL, 0x0U);
    XGpio_DiscreteWrite(&StartGpio, GPIO_CHANNEL, 0x0U);

    dma_config = XAxiDma_LookupConfig(DMA_BASEADDR);
    if (dma_config == NULL) {
        xil_printf("ERROR: AXI DMA configuration not found.\r\n");
        return XST_FAILURE;
    }

    status = XAxiDma_CfgInitialize(&Dma, dma_config);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: AXI DMA init failed: %d\r\n", status);
        return status;
    }

    /* The design is configured for simple mode, not scatter-gather. */
    if (XAxiDma_HasSg(&Dma)) {
        xil_printf("ERROR: DMA is in SG mode; this program expects simple mode.\r\n");
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static int wait_for_button_press(void)
{
    xil_printf("Press BTN0 to capture one frame.\r\n");

    while ((XGpio_DiscreteRead(&ButtonGpio, GPIO_CHANNEL) & GPIO_BIT0) == 0U) {
        usleep(BUTTON_POLL_US);
    }

    /* Basic debounce, then confirm the press is still present. */
    usleep(BUTTON_DEBOUNCE_US);
    if ((XGpio_DiscreteRead(&ButtonGpio, GPIO_CHANNEL) & GPIO_BIT0) == 0U) {
        return XST_FAILURE;
    }

    /* Wait for release so a held button does not immediately retrigger. */
    while ((XGpio_DiscreteRead(&ButtonGpio, GPIO_CHANNEL) & GPIO_BIT0) != 0U) {
        usleep(BUTTON_POLL_US);
    }

    return XST_SUCCESS;
}

static int capture_one_frame(void)
{
    int status;
    u32 elapsed_ms;
    volatile u32 *frame = (volatile u32 *)(UINTPTR)FRAME_RAM_BASE;

    /* Flush any old CPU cache lines before the DMA writes this memory. */
    Xil_DCacheFlushRange((INTPTR)FRAME_RAM_BASE, FRAME_BYTES);

    /* Arm S2MM first so the stream has a ready receiver before start goes high. */
    status = XAxiDma_SimpleTransfer(&Dma,
                                    (UINTPTR)FRAME_RAM_BASE,
                                    FRAME_BYTES,
                                    XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: could not start S2MM transfer: %d\r\n", status);
        XGpio_DiscreteWrite(&StartGpio, GPIO_CHANNEL, 0x0U);
        return status;
    }

    XGpio_DiscreteWrite(&StartGpio, GPIO_CHANNEL, START_ACTIVE);
    xil_printf("Capture started: %u bytes (%u words).\r\n",
               FRAME_BYTES, FRAME_WORDS);

    for (elapsed_ms = 0U;
         (elapsed_ms < DMA_WAIT_MS) &&
         XAxiDma_Busy(&Dma, XAXIDMA_DEVICE_TO_DMA);
         ++elapsed_ms) {
        usleep(1000U);
    }

    /* Stop the receiver after DMA completion or timeout. */
    XGpio_DiscreteWrite(&StartGpio, GPIO_CHANNEL, 0x0U);

    if (XAxiDma_Busy(&Dma, XAXIDMA_DEVICE_TO_DMA)) {
        xil_printf("ERROR: DMA timed out after %u ms. Check TLAST, stream clocks, and RAM AXI responses.\r\n",
                   DMA_WAIT_MS);
        return XST_FAILURE;
    }

    /* Make DMA-written data visible to MicroBlaze before reading it. */
    Xil_DCacheInvalidateRange((INTPTR)FRAME_RAM_BASE, FRAME_BYTES);

    xil_printf("Capture complete. First word = 0x%08x, last word = 0x%08x\r\n",
               (unsigned int)frame[0],
               (unsigned int)frame[FRAME_WORDS - 1U]);

    return XST_SUCCESS;
}

int main(void)
{
    int status;

    xil_printf("MicroBlaze frame capture application\r\n");
    xil_printf("Frame RAM base: 0x%08x\r\n", (unsigned int)FRAME_RAM_BASE);

    status = initialize_hardware();
    if (status != XST_SUCCESS) {
        xil_printf("Hardware initialization failed; stopping.\r\n");
        return XST_FAILURE;
    }

    for (;;) {
        status = wait_for_button_press();
        if (status != XST_SUCCESS) {
            xil_printf("Button press was too short; waiting again.\r\n");
            continue;
        }

        status = capture_one_frame();
        if (status == XST_SUCCESS) {
            xil_printf("Frame stored in axi4_full_ram. Press BTN0 for another frame.\r\n");
        } else {
            xil_printf("Frame capture failed. Press BTN0 to retry.\r\n");
        }
    }
}


