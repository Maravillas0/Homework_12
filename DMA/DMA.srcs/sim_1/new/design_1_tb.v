`timescale 1ns / 1ps

module design_1_tb;

    localparam FRAME_WIDTH  = 320;
    localparam FRAME_HEIGHT = 200;
    localparam FRAME_BYTES  = FRAME_WIDTH * FRAME_HEIGHT;
    localparam FRAME_WORDS  = FRAME_BYTES / 4;

    reg clk_125MHz = 1'b0;
    reg [0:0] btn_tri_i = 1'b0;
    reg [7:0] data = 8'h00;
    reg data_valid = 1'b0;
    wire data_ready;

    integer byte_number = 0;
    integer word_number = 0;
    integer base_byte = 0;
    integer errors = 0;
    reg [7:0] expected_b0 = 8'h00;
    reg [7:0] expected_b1 = 8'h00;
    reg [7:0] expected_b2 = 8'h00;
    reg [7:0] expected_b3 = 8'h00;
    reg [31:0] expected_word = 32'h00000000;

    // design_1_wrapper receives the 125 MHz board clock.
    always #4 clk_125MHz = ~clk_125MHz;

    // Instantiate the complete block design, including MicroBlaze and DMA.
    design_1_wrapper dut (
        .btn_tri_i  (btn_tri_i),
        .clk_125MHz (clk_125MHz),
        .data       (data),
        .data_ready (data_ready),
        .data_valid (data_valid)
    );

    initial begin
        // Give the clock wizard, reset logic, and MicroBlaze time to start.
        #2_000_000;

        // SIMULATION firmware polls BTN0 every 100 us and debounces it for 200 us.
        // Hold BTN0 for 1 ms, longer than the simulated polling and debounce delays.
        $display("TB: pressing BTN0 at %0t", $time);
        btn_tri_i[0] = 1'b1;
        #1_000_000;
        btn_tri_i[0] = 1'b0;
        $display("TB: released BTN0 at %0t", $time);

        // Firmware arms S2MM, then asserts start and the packer raises ready.
        wait (data_ready === 1'b1);
        $display("TB: capture started at %0t", $time);

        // Send 320x200 bytes, holding each one until data_ready accepts it.
        for (byte_number = 0; byte_number < FRAME_BYTES; byte_number = byte_number + 1) begin
            @(negedge clk_125MHz);
            data = byte_number[7:0];
            data_valid = 1'b1;
            while (data_ready !== 1'b1)
                @(negedge clk_125MHz);
            @(posedge clk_125MHz);
        end

        @(negedge clk_125MHz);
        data_valid = 1'b0;
        $display("TB: sent %0d input bytes at %0t", FRAME_BYTES, $time);

        // Firmware lowers start after the DMA S2MM transfer completes.
        wait (dut.design_1_i.axi_gpio_1_gpio_io_o[0] === 1'b0);
        #100;

        // Check all words stored by DMA in the custom RAM.
        for (word_number = 0; word_number < FRAME_WORDS; word_number = word_number + 1) begin
            base_byte = (word_number * 4) & 8'hff;
            expected_b0 = base_byte;
            expected_b1 = base_byte + 1;
            expected_b2 = base_byte + 2;
            expected_b3 = base_byte + 3;
            expected_word = {expected_b0, expected_b1, expected_b2, expected_b3};

            if (dut.design_1_i.axi4_full_ram_0.inst.mem[word_number] !== expected_word) begin
                if (errors < 10)
                    $display("ERROR word %0d: RAM=%08h expected=%08h",
                             word_number,
                             dut.design_1_i.axi4_full_ram_0.inst.mem[word_number],
                             expected_word);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: DMA stored all %0d words in axi4_full_ram", FRAME_WORDS);
        else
            $display("FAIL: %0d RAM word mismatches", errors);
        $finish;
    end

    initial begin
        // Allow time for simulated button debounce, frame transfer, and RAM checks.
        #10_000_000;
        $display("ERROR: timeout at %0t; data_ready=%b; bytes attempted=%0d",
                 $time, data_ready, byte_number);
        $display("       start GPIO=%b, clock locked=%b, 100 MHz resetn=%b, 125 MHz resetn=%b",
                 dut.design_1_i.axi_gpio_1_gpio_io_o[0],
                 dut.design_1_i.clk_wiz_1_locked,
                 dut.design_1_i.rst_clk_wiz_1_100M_peripheral_aresetn,
                 dut.design_1_i.rst_clk_wiz_1_125M_peripheral_aresetn);
        $finish;
    end

endmodule



