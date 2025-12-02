`timescale 1ns/1ps

module traffic_tb;

    // Inputs
    reg clk = 0;
    reg [3:0] btn = 4'b0000;
    reg [1:0] sw = 2'b00;

    // Outputs
    wire [2:0] a_rgb;
    wire [2:0] b_rgb;
    wire [3:0] seg_a;
    wire [3:0] seg_b;

    // Instantiate the Device Under Test (DUT)
    traffic_top dut (
        .CLK100MHZ(clk),
        .BTN(btn),
        .SW(sw),
        .A_RGB(a_rgb),
        .B_RGB(b_rgb),
        .SEG_A(seg_a),
        .SEG_B(seg_b)
    );

    // 1. Clock Generation (100 MHz)
    always #5 clk = ~clk; // 5ns high, 5ns low = 10ns period (100 MHz)

    // 2. Main Simulation Sequence
    initial begin
        // Setup waveform dumping
        $dumpfile("traffic_tb.vcd");
        $dumpvars(0, traffic_tb);

        // Setup console monitor
        // This monitor shows the state of the FSM, the LEDs,
        // and the values on both 7-segment displays.
        $monitor("Time=%0t SW=%b BTN=%b | A_Light=%b B_Light=%b | SegA=%d (G_TimeA=%d) | SegB=%d (G_TimeB=%d) | State=%b",
                 $time, sw, btn, a_rgb, b_rgb,
                 seg_a, dut.u_fsm.green_time_A,
                 seg_b, dut.u_fsm.green_time_B,
                 dut.u_fsm.state);

        // ---
        // === Phase 1: Reset the System ===
        // ---
        // SW[1] is our master reset
        sw = 2'b0010; // Assert reset
        #200;         // Hold reset for 200 ns
        sw = 2'b0000; // De-assert reset
        #100;
        
        // ---
        // === Phase 2: Run with Default Times ===
        // ---
        // Let the system run with defaults (Green=3, Yellow=2)
        // Wait for 20 seconds
        #20_000_000_000;

        // ---
        // === Phase 3: Test "Set Mode" (SW[0]) ===
        // ---
        sw[0] = 1'b1; // Enter Set Mode
        #2_000_000_000; // Wait 2 seconds

        // ---
        // === Phase 4: Modify Time A (LED 4 / 7-seg-0) ===
        // ---
        
        // ** Test Increase for A: Default (3) -> 5 **
        // seg_a should show 4
        btn[0] = 1'b1; #100; btn[0] = 1'b0; // Press BTN[0] (inc A)
        #2_000_000_000; // Wait 2s
        // seg_a should show 5
        btn[0] = 1'b1; #100; btn[0] = 1'b0; // Press BTN[0] (inc A)
        #2_000_000_000; // Wait 2s

        // ** Test Decrease for A: 5 -> 4 **
        // seg_a should show 4
        btn[1] = 1'b1; #100; btn[1] = 1'b0; // Press BTN[1] (dec A)
        #2_000_000_000; // Wait 2s
        
        // ---
        // === Phase 5: Modify Time B (LED 5 / 7-seg-1) ===
        // ---

        // ** Test Increase for B: Default (3) -> 6 **
        // seg_b should show 4
        btn[2] = 1'b1; #100; btn[2] = 1'b0; // Press BTN[2] (inc B)
        #2_000_000_000; // Wait 2s
        // seg_b should show 5
        btn[2] = 1'b1; #100; btn[2] = 1'b0; // Press BTN[2] (inc B)
        #2_000_000_000; // Wait 2s
        // seg_b should show 6
        btn[2] = 1'b1; #100; btn[2] = 1'b0; // Press BTN[2] (inc B)
        #2_000_000_000; // Wait 2s

        // ** Test Decrease for B: 6 -> 5 **
        // seg_b should show 5
        btn[3] = 1'b1; #100; btn[3] = 1'b0; // Press BTN[3] (dec B)
        #2_000_000_000; // Wait 2s

        // ---
        // === Phase 6: Exit Set Mode & Run with Custom Times ===
        // ---
        sw[0] = 1'b0; // Exit Set Mode
        #2_000_000_000; // Wait 2 seconds
        
        // System now runs with Time A = 4, Time B = 5, Yellow = 2
        // Let it run for 30 seconds
        #30_000_000_000;

        // ---
        // === Phase 7: Test Reset During Operation ===
        // ---
        sw = 2'b0010; // Assert reset (SW[1])
        #200;
        sw = 2'b0000; // De-assert reset
        #100;

        // ---
        // === Phase 8: Run with Default Times Again ===
        // ---
        // System should be back to defaults (Green=3, Yellow=2)
        // Let it run for 20 seconds
        #20_000_000_000;

        // 7. Finish Simulation
        $finish;
    end

endmodule