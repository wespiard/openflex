// Simle "hello world" style SV module. 
// The idea taken from https://zipcpu.com/blog/2017/05/19/blinky.html, 
// I just changed it to SystemVerilog and added a parameter to use as
// an OpenFLEX example. 
// Untested.

module blinky #(
    parameter int COUNT = 1000000
) (
    input  logic clk_i,
    input  logic rst_i,
    output logic led_o
);

  logic [$clog2(COUNT)-1:0] counter_r;

  always_ff @(posedge clk_i) begin

    counter_r++;

    if (rst_i) begin
      counter_r <= '0;
    end
  end

  assign led_o = counter_r[$left(counter_r)];

endmodule
