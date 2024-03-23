// Greg Stitt
// University of Florida

// Module: mult_tb
// Description: Testbench for mult.sv. 

module mult_tb #(
    parameter int   NUM_TESTS   = 1000,
    parameter int   INPUT_WIDTH = 8,
    parameter logic IS_SIGNED   = 1'b0
);

  logic [INPUT_WIDTH-1:0] in0, in1;
  logic [INPUT_WIDTH*2-1:0] product;

  mult #(
      .IS_SIGNED  (IS_SIGNED),
      .INPUT_WIDTH(INPUT_WIDTH)
  ) dut (
      .*
  );

  initial begin
    logic [INPUT_WIDTH*2-1:0] correct_product;

    for (int i = 0; i < NUM_TESTS; i++) begin
      in0 = $random;
      in1 = $random;

      if (IS_SIGNED) begin
        correct_product = signed'(in0) * signed'(in1);
      end else begin
        correct_product = in0 * in1;
      end

      #10;

      assert (product == correct_product)
      else $error("(time %0t): product = %d instead of %d.", $realtime, product, correct_product);
    end

    $display("Tests completed.");
  end
endmodule  // mult_tb
