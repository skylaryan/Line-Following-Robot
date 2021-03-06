// Casey Loyda, Sadeq Hashemi Nejad, Skylar Yan, Tristen Hallock
// Command and Control Module

module cmd_cntrl(clk, rst_n, cmd, cmd_rdy, OK2Move, ID, ID_vld, 
			clr_cmd_rdy, in_transit, go, buzz, buzz_n, clr_ID_vld);

input [7:0] cmd, ID;
input clk, rst_n;
input cmd_rdy, OK2Move, ID_vld;

output go;
output reg in_transit, clr_cmd_rdy, clr_ID_vld, buzz, buzz_n;
reg [5:0] dest_ID;
reg [13:0] buzz_cnt;
reg latch_ID, set_in_transit, clr_in_transit;

wire [1:0] stop_go = cmd[7:6];
wire en; 

// values of the go and stop commands
localparam GO_CMD = 2'b01;
localparam STOP_CMD = 2'b00;

localparam INIT_VALUE = 0; 
localparam EXP_VALUE = 12500; 

//define states and state logic
typedef enum reg {STOP, GO} state_t;
state_t state, nxt_state;

assign go = in_transit & OK2Move; 
assign en = in_transit & ~OK2Move;
assign buzz_n = (en)? ~buzz : buzz; // Inversion only when enabled to vibrate. 

always @(posedge clk or negedge rst_n) begin

  if (!rst_n) begin
    buzz <= 1'b0; // The initial value doesn't really matter, but always good to initialize.
    buzz_cnt <= INIT_VALUE; // What should INIT_VALUE be?
  end

  else begin
    if (en) // Increase when enabled
      buzz_cnt <= buzz_cnt + 1'b1;
    if (buzz_cnt >= EXP_VALUE/2) // 50% duty
        buzz <= 1'b1;
    else
        buzz <= 1'b0;
    end
    if (buzz_cnt == EXP_VALUE) // Don't just let it overflow. What should EXP_VALUE be?
        buzz_cnt <= INIT_VALUE;
 end


// state transition logic
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= STOP;
	else
		state <= nxt_state;

// reset logic
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n) begin
		dest_ID <= 0;
		in_transit <= 0;
	end
	else begin

		// latch destination ID
		if(latch_ID) dest_ID <= cmd[5:0]; 
		else dest_ID <= dest_ID; 
	
		// in transit
		if(set_in_transit) in_transit <= 1;
		else if(clr_in_transit) in_transit <= 0;

	end
	

always_comb begin
	//default outputs
	nxt_state = STOP;
	clr_cmd_rdy = 0;
	clr_ID_vld = 0;
	set_in_transit = 0;
	clr_in_transit = 0;
	latch_ID = 0;
	
	//mimic changes in state diagram
	case (state)
		STOP :	// "go" command received. Latch destination ID
			if (cmd_rdy && (stop_go == GO_CMD)) begin
				clr_cmd_rdy = 1;
				set_in_transit = 1;
				nxt_state = GO;
				latch_ID = 1; 
			end

			// otherwise stay stationary
			else nxt_state = STOP;

		GO : 	// New "go" command received, update Destination ID
			if (cmd_rdy && (stop_go == GO_CMD)) begin
				clr_cmd_rdy = 1;
				nxt_state = GO;
				latch_ID = 1; 
		     	end
			else if (cmd_rdy && (stop_go == STOP_CMD)) begin
				clr_cmd_rdy = 1;
				clr_in_transit = 1;
				nxt_state = STOP;
			end
			// Barcode ID received, but not our destination. Keep moving
			else if (ID_vld && (ID[5:0] != dest_ID)) begin
				clr_ID_vld = 1;
				nxt_state = GO;
			end
			// Stop command received

			// Arrived at the destination. Stop.
			else if (ID_vld && (ID[5:0] == dest_ID)) begin
				clr_ID_vld = 1;
				clr_in_transit = 1;
				nxt_state = STOP;
			end

			// otherwise keep going
			else nxt_state = GO;

		// if error occurs, go back to STOP state
		default: nxt_state = STOP;
	endcase
end

endmodule
