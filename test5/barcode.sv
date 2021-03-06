
module barcode(clk, rst_n, BC, clr_ID_vld, ID, ID_vld); 

input clk, rst_n;
input BC, clr_ID_vld; 
output reg [7:0] ID; 
output reg ID_vld; 

reg negative_edge, positive_edge;
reg FF1, FF2, FF3, FF4;

reg sCLK, sCLK_FF1, sCLK_FF2; 
wire sCLK_rise, sCLK_fall;

//reg start_timer;  
reg [21:0] timer, timer_count;
reg [3:0]bit_count;

localparam byte_done = 4'b1000;

typedef enum reg[1:0] {IDLE, TIME, SHIFT} state_t;
state_t state, nxt_state;

//////////////////////////////////////////////////
//synchronize BC with clock and sCLK.
////////////////////////////////////////////////// 
assign negative_edge = ((FF3) & ~FF2) ? 1'b1: 1'b0; 
assign positive_edge = (~FF3 & FF2) ? 1'b1: 1'b0; 
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		FF1 <= 1'b1; 
		FF2 <= 1'b1; 
		FF3 <= 1'b1;
		FF4 <= 1'b1; 
		end 
	else if(clr_ID_vld) begin
		FF1 <= 1'b1; 
		FF2 <= 1'b1; 
		FF3 <= 1'b1;
		FF4 <= 1'b1; 
		end 
	else	begin
		FF1 <= BC;
		FF2 <= FF1; 
		FF3 <= FF2;
		FF4 <= FF3;  
		end
end

//////////////////////////////////////////////////////////////////////////
//system generated clock that can help us sample BC at its rising edge
//every half cycle is set to the same time as start bit's low. so 
//a rising edge is the time that we are meant to sample. 
//////////////////////////////////////////////////////////////////////////
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) sCLK = 1; 
	else begin
		if(nxt_state==SHIFT) begin
			
		 if(timer_count == timer) begin
			timer_count <= 0; 
			sCLK <= ~sCLK; 
			end
		 else timer_count <= timer_count + 1; 
		end
		else sCLK <= 1; 
end
end
// Run sCLK through two flops to be able to detect a rising and falling edge
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  begin
	    sCLK_FF1 <= 1'b1;
	    sCLK_FF1 <= 1'b1;
	  end
    else if (clr_ID_vld)
	  begin
	    sCLK_FF1 <= 1'b1;
	    sCLK_FF1 <= 1'b1;
	  end
	else
	  begin
	    sCLK_FF1 <= sCLK;
	    sCLK_FF2 <= sCLK_FF1;
	  end  
	  
/////////////////////////////////////////////////////
// If SCLK_ff2 is still high, but SCLK_ff1 is low //
// then a negative edge of SCLK has occurred.    //
//////////////////////////////////////////////////
  assign sCLK_fall = ~sCLK_FF1 & sCLK_FF2;
  assign sCLK_rise = sCLK_FF1 & ~sCLK_FF2;

//////////////////////////////////////////////////
//on rst and clr_ID_vld, the output is set to NULL
//at every rising edge of sCLK, we sample the value
//and increment the bit tracker
//////////////////////////////////////////////////
always @(posedge clk, negedge rst_n) begin
if(!rst_n)	ID <= 8'b0; 

else if(clr_ID_vld) ID <= 8'b0; 

else if(sCLK_rise)begin	ID <= {ID[6:0], FF4};
	bit_count <= bit_count + 1; 
end
end

//////////////////////////////////////////////////
//assign next states a every positive edge
//////////////////////////////////////////////////
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		state <= IDLE;
	else if(clr_ID_vld) state <= IDLE; 
	else
		state <= nxt_state; 
end

//////////////////////////////////////////////////
//COMBINATIONAL LOGIC FOR STATES
////////////////////////////////////////////////// 
always_comb begin
	//DEFAULT 
	 nxt_state = IDLE; 

	case(state)
		//state where system waits for a start bit
		//start bits are started with a falling edge
		IDLE: begin
			if(negative_edge)
				nxt_state = TIME; 
			end

		//On TIME, we move on to SHIFT, once the timing parameter is
		//recorded, in other words, when we see a positive edge, we 
		//start preparing for a negative edge
		TIME: begin
			if(positive_edge) begin
					nxt_state = SHIFT;
					  end 
			else nxt_state = TIME; 
			end

		//On SHIFT, if we see that all bits have been added, we move to 
		//next state. 
		SHIFT: begin 
			if(bit_count == byte_done) begin
					 nxt_state = IDLE;
					end 
			else nxt_state = SHIFT; 
			end


	endcase 
	end

//////////////////////////////////////////////////
//SEQUENTIAL LOGIC FOR FSM
//////////////////////////////////////////////////
always @(posedge clk, negedge rst_n) begin
	//rst_N and clr_ID_vld both set all values to 
	//their initial values
	if(!rst_n) begin
			bit_count <= 4'b0; 
			timer <= 8'b0; 
			timer_count <= 0; 
			ID_vld <= 0; 
		   end
	else if(clr_ID_vld) begin
			bit_count <= 4'b0; 
			timer <= 8'b0; 
			timer_count <= 0; 
			ID_vld <= 0; 
		   end 
	else begin
	case(state)

		//in IDLE we once again reset our timers
		IDLE: begin
			timer <= 8'b0; 
			timer_count <= 0; 
		      end

		//we increment timer until we have reach last TIME state
		TIME: begin
			if(nxt_state == TIME )timer <= timer + 1; 
		      end

		//if we are moving from SHIFT to IDLE we must have finished 
		//with all bits
		SHIFT:begin
			if(nxt_state == IDLE) ID_vld <= 1; 
		      end 

	endcase 

	end 
end


endmodule 