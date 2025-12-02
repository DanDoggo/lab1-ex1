module clock_divider(
    input wire clk, // 100 MHz
    input wire reset, // active high
    output reg tick // 1-cycle pulse at 1 Hz
);

    reg [26:0] count; // <-- CHANGED

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 27'd0; // <-- CHANGED
            tick <= 1'b0;
        end else begin
            if (count == 27'd100_000_000 - 1) begin // <-- CHANGED
                count <= 27'd0; // <-- CHANGED
                tick <= 1'b1;
            end else begin
                count <= count + 1;
                tick <= 1'b0;
            end
        end
    end
endmodule