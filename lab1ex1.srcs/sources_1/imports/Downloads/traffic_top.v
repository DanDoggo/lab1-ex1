//
// === NEW traffic_top.v ===
//
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
wire reset = SW[1];        // <-- Use the new RST port
wire set_mode = SW[0];

// Map all 4 buttons to new FSM inputs
wire inc_A = BTN[0];     // BTN[0] increases Time A
wire dec_A = BTN[1];     // BTN[1] decreases Time A
wire inc_B = BTN[2];     // BTN[2] increases Time B
wire dec_B = BTN[3];     // BTN[3] decreases Time B

clock_divider u_clkdiv(.clk(CLK100MHZ), .reset(reset), .tick(tick));

wire [2:0] A_light_w, B_light_w;
wire [3:0] counter_A_w, counter_B_w;
wire [3:0] green_time_A_w, green_time_B_w;

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

assign A_RGB = A_light_w;
assign B_RGB = B_light_w;

// 7-seg-0 (SEG_A) shows the timer for LED 4
assign SEG_A = counter_A_w;

// 7-seg-1 (SEG_B) shows the timer for LED 5
assign SEG_B = counter_B_w;

endmodule