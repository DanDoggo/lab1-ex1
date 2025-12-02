`timescale 1ns / 1ps

//================================================================
//================================================================
//
//          --- PART 1: DESIGN SOURCES ---
//    (These modules will be synthesized and put on the FPGA)
//
//================================================================
//================================================================


//================================================================
// Module 1: clock_divider
// Description: Takes a 100MHz clock and outputs a 1Hz tick.
//================================================================
module clock_divider(
    input wire clk, // 100 MHz
    input wire reset, // active high
    output reg tick // 1-cycle pulse at 1 Hz
);
    reg [26:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 27'd0;
            tick <= 1'b0;
        end else begin
            if (count == 27'd100_000_000 - 1) begin // 100 Million
                count <= 27'd0;
                tick <= 1'b1;
            end else begin
                count <= count + 1;
                tick <= 1'b0;
            end
        end
    end
endmodule

//================================================================
// Module 2: traffic_fsm
// Description: The "brain" of the traffic light.
//              Manages states, timers, and set mode.
//================================================================
module traffic_fsm(
    input wire clk,
    input wire reset,
    input wire tick,
    input wire set_mode,
    input wire inc_A,
    input wire dec_A,
    input wire inc_B,
    input wire dec_B,
    output reg [2:0] A_light,
    output reg [2:0] B_light,
    output reg [3:0] counter_A,
    output reg [3:0] counter_B,
    output reg [3:0] green_time_A,
    output reg [3:0] green_time_B
);
    // --- Fixed Colors (to match XDC) ---
    localparam RED    = 3'b100;
    localparam YELLOW = 3'b110;
    localparam GREEN  = 3'b010;
    // ------------------------------------

    localparam S0 = 2'b00, S1 = 2'b01, S2 = 2'b10, S3 = 2'b11;
    reg [1:0] state;

    localparam Y_TIME = 4'd2; // 2-second yellow light

    // Registers for set mode
    reg inc_A_prev, dec_A_prev, inc_B_prev, dec_B_prev;
    reg [3:0] green_time_temp_A, green_time_temp_B;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S0;
            green_time_A <= 4'd3;
            green_time_temp_A <= 4'd3;
            green_time_B <= 4'd3;
            green_time_temp_B <= 4'd3;
            
            counter_A <= 4'd3; // A starts Green
            counter_B <= 4'd5; // B starts Red (A_Green_Time + Y_Time)
            
            inc_A_prev <= 1'b0;
            dec_A_prev <= 1'b0;
            inc_B_prev <= 1'b0; dec_B_prev <= 1'b0;
        end else begin
            // Store previous button state for edge detection
            inc_A_prev <= inc_A;
            dec_A_prev <= dec_A;
            inc_B_prev <= inc_B; dec_B_prev <= dec_B;
            
            if (set_mode) begin
                // --- Set Mode Logic ---
                // Control Time A
                if (inc_A && !inc_A_prev && (green_time_temp_A < 4'd15))
                    green_time_temp_A <= green_time_temp_A + 1;
                if (dec_A && !dec_A_prev && (green_time_temp_A > 4'd1))
                    green_time_temp_A <= green_time_temp_A - 1;
                // Control Time B
                if (inc_B && !inc_B_prev && (green_time_temp_B < 4'd15))
                    green_time_temp_B <= green_time_temp_B + 1;
                if (dec_B && !dec_B_prev && (green_time_temp_B > 4'd1))
                    green_time_temp_B <= green_time_temp_B - 1;
                
                // Display current settings
                counter_A <= green_time_temp_A;
                counter_B <= green_time_temp_B;

            end else begin
                // --- Running Mode ---
                
                // Apply new times when exiting set mode
                if (green_time_A != green_time_temp_A || green_time_B != green_time_temp_B) begin
                     green_time_A <= green_time_temp_A;
                     green_time_B <= green_time_temp_B;
                     state <= S0; // Reset state machine
                     counter_A <= green_time_temp_A;
                     counter_B <= green_time_temp_A + Y_TIME; // B's red time
                end

                if (tick) begin 
                    
                    // Count both counters down
                    if (counter_A > 4'd0)
                        counter_A <= counter_A - 1;
                    if (counter_B > 4'd0)
                        counter_B <= counter_B - 1;
                        
                    // State transition logic (triggers when a timer is about to hit 0)
                    if (counter_A == 4'd1 || counter_B == 4'd1) begin
                        case (state)
                            S0: begin // A=Green, B=Red. A is about to finish.
                                state <= S1;
                                counter_A <= Y_TIME; // Load A with Yellow
                               end
                            S1: begin // A=Yellow, B=Red. A is about to finish.
                                    state <= S2;
                                    counter_A <= green_time_B + Y_TIME; // Load A with Red
                                    counter_B <= green_time_B; // Load B with Green
                               end
                            S2: begin // A=Red, B=Green. B is about to finish.
                                    state <= S3;
                                    counter_B <= Y_TIME; // Load B with Yellow
                               end
                            S3: begin // A=Red, B=Yellow. B is about to finish.
                                    state <= S0;
                                    counter_B <= green_time_A + Y_TIME; // Load B with Red
                                    counter_A <= green_time_A; // Load A with Green
                               end
                        endcase
                    end
                end
            end
        end
    end

    // Combinational logic for lights
    always @(*) begin
        case (state)
            S0: begin A_light = GREEN;  B_light = RED; end
            S1: begin A_light = YELLOW; B_light = RED; end
            S2: begin A_light = RED;    B_light = GREEN; end
            S3: begin A_light = RED;    B_light = YELLOW; end
            default: begin A_light = RED; B_light = RED; end
        endcase
    end
endmodule

//================================================================
// Module 3: traffic_top (TOP-LEVEL MODULE)
// Description: Connects all modules to the FPGA's 
//              physical inputs and outputs.
//================================================================
module traffic_top(
    input wire CLK100MHZ,
    input wire [3:0] BTN,
    input wire [1:0] SW,
    output wire [2:0] A_RGB,  // LED 4
    output wire [2:0] B_RGB,  // LED 5
    output wire [3:0] SEG_A,  // 7-seg-0
    output wire [3:0] SEG_B   // 7-seg-1
);
    wire tick;
    wire reset = SW[1];        // Use SW[1] as reset
    wire set_mode = SW[0];
    
    // Map all 4 buttons to FSM inputs
    wire inc_A = BTN[0];     // BTN[0] increases Time A
    wire dec_A = BTN[1];     // BTN[1] decreases Time A
    wire inc_B = BTN[2];     // BTN[2] increases Time B
    wire dec_B = BTN[3];     // BTN[3] decreases Time B

    // Instantiate clock divider
    clock_divider u_clkdiv(.clk(CLK100MHZ), .reset(reset), .tick(tick));

    // Internal wires
    wire [2:0] A_light_w, B_light_w;
    wire [3:0] counter_A_w, counter_B_w;
    wire [3:0] green_time_A_w, green_time_B_w;

    // Instantiate FSM
    traffic_fsm u_fsm(
        .clk(CLK100MHZ), 
        .reset(reset), 
        .tick(tick), 
        .set_mode(set_mode),
        .inc_A(inc_A), .dec_A(dec_A),
        .inc_B(inc_B), .dec_B(dec_B),
        .A_light(A_light_w), .B_light(B_light_w), 
        .counter_A(counter_A_w),
        .counter_B(counter_B_w),
        .green_time_A(green_time_A_w),
        .green_time_B(green_time_B_w)
    );
    
    // Connect FSM outputs to top-level outputs
    assign A_RGB = A_light_w;
    assign B_RGB = B_light_w;

    // 7-seg-0 (SEG_A) shows the timer for LED 4 (A)
    assign SEG_A = counter_A_w;
    // 7-seg-1 (SEG_B) shows the timer for LED 5 (B)
    assign SEG_B = counter_B_w;

endmodule

//================================================================
//================================================================
//
//          --- PART 2: SIMULATION SOURCES ---
//    (This module is the testbench and will NOT be synthesized)
//
//================================================================
//================================================================

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