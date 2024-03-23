// Greg Stitt
// University of Florida

// Module: mult
// Description: Implements a multiplier that prevents overflow by producing
// a product that is twice the width of the inputs. It uses a paremeter to
// specify the input width, and whether or not the inputs are signed.

module mult #(
    parameter logic IS_SIGNED   = 1'b0,
    parameter int   INPUT_WIDTH
) (
    input  logic [  INPUT_WIDTH-1:0] in0,
    input  logic [  INPUT_WIDTH-1:0] in1,
    output logic [INPUT_WIDTH*2-1:0] product
);

  always_comb begin
    if (IS_SIGNED) product = signed'(in0) * signed'(in1);
    else product = in0 * in1;

  end
endmodule  // mult
