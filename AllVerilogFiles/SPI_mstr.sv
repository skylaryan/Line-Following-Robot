module SPI_mstr(clk, rst_n, wrt, cmd, done, rd_data, SCLK, SS_n, MOSI, MISO);

// inputs
input clk, rst_n, wrt, MISO;
input [15:0] cmd;

// outputs
output reg SCLK, MOSI;
output reg done, SS_n;
output [15:0] rd_data; //SHIFT FUCKING REGISTER t-.-t

typedef enum reg[1:0] {IDLE,SHIFT,BACK_PORCH} state_t;

// Registers needed in design declared next
state_t state, nxt_state; 

reg[15:0] shft_reg;

//shift count to keep track of status of shift
//SCLK count to detect initiation of shift
reg [4:0] shift_count, sclk_count;

//SM outputs declared as type logic next
logic clr_done, set_done, rst_count, start_count, shift;

// dummy signals
reg repeat_cntr, reset_repeat_cntr, en_repeat_cntr;

// output signals
assign MOSI = shft_reg[15];
assign rd_data = shft_reg[15:0];  

// initiates bit shift some time after the rising edge of SCLK
always_ff @ (posedge clk, negedge rst_n)
	if (!rst_n) 
		sclk_count <= 30;
	else if (rst_count)
		sclk_count <= 30;
	else if (!SS_n)
		sclk_count <= sclk_count + 1;
	else	
		sclk_count <= 30;

assign SCLK = sclk_count[4];

// Implement done and SS_n as a set/reset flop 
always_ff @(posedge clk, negedge rst_n)
    	if (!rst_n) begin
	  	done <= 0;
	  	SS_n <= 1;
	end
	else if (clr_done) begin
	 	 done <= 0;
	  	SS_n <= 0;
	end
	else if (set_done)begin
	  	done <= 1;
	  	SS_n <= 1;
	end
	  
// used to keep track of the completion of shifting  
always_ff @ (posedge clk, negedge rst_n)
	if (!rst_n) 
		shift_count <= 0;
	else if (shift_count[4])
		shift_count <= 0;
	else if (start_count)
		shift_count <= shift_count + 1;
			
	  
// SPI shift register
always_ff @(posedge clk, negedge rst_n)
    	if (!rst_n)
	  	shft_reg <= 0;
	else if (wrt)
	  	shft_reg <= cmd;
	else if (shift)
	  	shft_reg <= {shft_reg[14:0],MISO};
		
// dummy counter
always_ff @ (posedge clk, negedge rst_n)
	if (!rst_n) 
		repeat_cntr <= 0;
	else if (reset_repeat_cntr)
		repeat_cntr <= 0;
	else if (en_repeat_cntr)
		repeat_cntr <= repeat_cntr + 1;
			
		

		

// Infer state register next
always @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else 
		state <= nxt_state;	

always_comb
    begin	// Default outputs
		shift = 0;
		set_done = 0;
		clr_done = 0;
		rst_count = 0;
		start_count = 0;
		reset_repeat_cntr = 0;
		en_repeat_cntr = 0;
		nxt_state = IDLE;
		
		case (state)
			IDLE: begin
				rst_count = 1;
				//shift = 1'b0; 
				// next state when wrt is asserted
				if (wrt) begin
					nxt_state = SHIFT;
					reset_repeat_cntr = 1;
					clr_done = 1;
				end
				else
					nxt_state = IDLE;
			end
			SHIFT: begin	
				start_count = (sclk_count == 19) ? 1 : 0;
				shift = (sclk_count == 19) ? 1 : 0;
				if (shift_count[4] && repeat_cntr) begin
					nxt_state = BACK_PORCH;
					rst_count = 1; 
				end
				else if (shift_count[4]) begin
					en_repeat_cntr = 1;
					nxt_state = SHIFT;
				end				                                                    
				else
					nxt_state = SHIFT;
			end
			BACK_PORCH: begin
				//shift = 1'b0; 
				if (sclk_count == 0) begin
					nxt_state = IDLE;
					set_done = 1;
				end
				else
					nxt_state = BACK_PORCH;
			end
			default: nxt_state = IDLE;
		endcase
	end
	
endmodule