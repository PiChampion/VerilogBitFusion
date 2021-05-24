module project564
(
	//Control Signals
	input wire		clock,		//Clock
	input wire 		reset_b,	//Active low reset_b
	input wire		run,		//Start processing
	output wire		busy,		//Processing in progress
	//SRAM interface
	input wire [15:0]	read_data_inputs,		//SRAM read data for inputs
	output reg [11:0]	read_address_inputs,	//SRAM read address for inputs
	input wire [15:0]	read_data_weights,		//SRAM read data for weights
	output reg [11:0]	read_address_weights,	//SRAM read address for weights
	//SRAM write interface
	output reg write_enable,					//SRAM write enable for outputs
	output reg [11:0] write_address,			//SRAM write address for outputs
	output reg signed [15:0] write_data			//SRAM write data for outputs
);

	//Parameters
	localparam s0  = 3'b000;
	localparam s1  = 3'b001;
	localparam s2  = 3'b010;
	localparam s3  = 3'b011;
	localparam s4  = 3'b100;
	localparam s5  = 3'b101;
	localparam s6  = 3'b110;
	localparam s7  = 3'b111;
	localparam s8  = 4'b1000;
	localparam s9  = 4'b1001;
	localparam s10  = 4'b1010;
	
	//Reg declaration
	reg [15:0]				input_counter;			//Keeps track of the number of inputs needed to be accessed in SRAM for a specific problem
	reg [15:0]				weight_counter;			//Keeps track of the number of weights needed to be accessed in SRAM for a specific problem
	reg [15:0]				weight_counter_group;	//Keeps track of the number of weight groups needed to be accessed in SRAM for a specific problem
	reg signed [7:0]		inputs[0:127];			//Array of all inputs needed for matrix multiplication
	reg signed [7:0]		weights[0:127];			//Array of group of weights needed for matrix multiplication
	reg [15:0]				input_size;				//Current size of inputs
	reg [15:0]				weight_size;			//Current size of weights
	reg [15:0]				input_number;			//Current number of inputs
	reg [15:0]				input_control;			//Register for controlling local input storage
	reg [15:0]				weight_control;			//Register for controlling local weight storage
	reg [15:0]				weight_addresses;		//Register for remembering number of weight addresses per group
	reg [15:0]				mult_input;				//Register for controlling multiplication of inputs
	reg signed  [15:0]		accumulator;			//Accumulator to keep track of output value during multiplications
	
	reg [3:0]				current_state;			//FSM current state
	reg [3:0]				next_state;				//FSM next state
	reg [1:0]				read_address_inputs_select;
	reg [2:0]				input_counter_select;
	reg 					input_size_select;
	reg 					input_number_select;
	reg [1:0]				record_inputs_select;
	reg [2:0]				input_control_select;
	reg [1:0]				read_address_weights_select;
	reg [2:0]				weight_counter_select;
	reg [1:0]				weight_counter_group_select;
	reg [2:0]				weight_addresses_select;
	reg 					weight_size_select;
	reg [1:0]				record_weights_select;
	reg [2:0]				weight_control_select;
	reg 					mult_input_select;
	reg [1:0]				accumulate_select;
	reg 					write_select;
	reg [1:0]				write_address_select;

	//--------------code start--------------//
	
	//Control Path
		
	//FSM
	always @(posedge clock or negedge reset_b) begin
		if (!reset_b)
			current_state <= 4'b0;
		else
			current_state <= next_state;
	end	
	
	
	always @(*) begin
		casex (current_state)
			s0 : begin 				//Reset state
				read_address_inputs_select = 0;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				read_address_weights_select = 0;
				weight_counter_select = 0;
				weight_counter_group_select = 0;
				weight_addresses_select = 0;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
				write_address_select = 0;
				
				if (run == 1'b1) begin
					next_state = s10;
					end
				else
					next_state = s0;
			end
			s10 : begin 			//State for beginning data transfer
				write_address_select = 2;					//Stay at same write address after writing data from last problem
				read_address_inputs_select = 1;				//Move to the next address in the SRAM
				if (read_data_inputs == 16'hFF) begin
					next_state = s0;
					end
				else
					next_state = s1;
					
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				read_address_weights_select = 2;
				weight_counter_select = 3; 
				weight_counter_group_select = 3;
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
			end
			s1 : begin 				//State for obtaining number of inputs
				write_address_select = 2;				//Stay at same write address after writing data from last problem
				input_counter_select = 1;				//Read the number of inputs from SRAM into input_counter
				input_number_select = 1;				//Read the number of inputs from SRAM into input_number
				read_address_inputs_select = 1;			//Move to the next address in the SRAM
				next_state = s2; 
				
				input_size_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				read_address_weights_select = 2;
				weight_counter_select = 3; 
				weight_counter_group_select = 3;
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
			end
			s2 : begin				//State for obtaining size of inputs
				input_number_select = 0;				//Keep number of inputs for future calculations
				input_size_select = 1;					//Record size of input into input_size
				read_address_inputs_select = 1;			//Move to the next address in the SRAM
				casex(read_data_inputs)
					16'h0008: begin 
						input_counter_select = 4; 		//If input size is 8, divide the input counter by 2 to obtain memory addresses to be accessed
						end
					16'h0004: begin 
						input_counter_select = 5;  		//If input size is 4, divide the input counter by 4 to obtain memory addresses to be accessed
						end
					16'h0002: begin 
						input_counter_select = 6;  		//If input size is 2, divide the input counter by 8 to obtain memory addresses to be accessed
						end
					default: input_counter_select = 3'bxxx; 	// *SHOULDNT HAPPEN*
				endcase
				next_state = s3; 
				
				record_inputs_select = 0;
				input_control_select = 0;
				read_address_weights_select = 2;
				weight_counter_select = 3; 
				weight_counter_group_select = 3;
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
				write_address_select = 2;
			end
			s3 : begin				//State for recording inputs into storage for later multiplication
				input_size_select = 0;					//Keep the size of inputs for future calculations
				casex(input_size)
					16'h0008: begin 
						if(input_counter > 1) begin				//If more addresses to be accessed, access the next address
							record_inputs_select = 1; 			//Record the inputs in the memory location into storage
							input_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							input_control_select = 1;			//Move to the next spots in storage
							read_address_inputs_select = 1;		//Move to the next address in the SRAM
							read_address_weights_select = 2;	//Stay at address in the SRAM
							next_state = s3;
							end
						else if(input_counter == 1) begin		//If more addresses to be accessed, access the next address
							record_inputs_select = 1; 			//Record the inputs in the memory location into storage
							input_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							input_control_select = 1;			//Move to the next spots in storage
							read_address_inputs_select = 2;		//Stay at the same address for next input problem run
							read_address_weights_select = 2;	//Stay at address in the SRAM
							next_state = s3;
							end
						else begin								//Done with reading inputs
							record_inputs_select = 0; 			//Stop recording the inputs into storage
							input_counter_select = 0;			//Reset counter to 0
							input_control_select = 0;			//Reset input storage controller to 0
							read_address_inputs_select = 2;		//Stay at the same address for next input problem run
							read_address_weights_select = 1;	//Move to the next address in the SRAM
							next_state = s4;
							end
					end
					16'h0004: begin 
						if(input_counter > 1) begin				//If more addresses to be accessed, access the next address
							record_inputs_select = 2; 			//Record the inputs in the memory location into storage
							input_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							input_control_select = 2;			//Move to the next spots in storage
							read_address_inputs_select = 1;		//Move to the next address in the SRAM
							read_address_weights_select = 2;	//Stay at address in the SRAM
							next_state = s3;
							end
						else if(input_counter == 1) begin		//If more addresses to be accessed, access the next address
							record_inputs_select = 2; 			//Record the inputs in the memory location into storage
							input_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							input_control_select = 2;			//Move to the next spots in storage
							read_address_inputs_select = 2;		//Stay at the same address for next input problem run
							read_address_weights_select = 2;	//Stay at address in the SRAM
							next_state = s3;
							end
						else begin								//Done with reading inputs
							record_inputs_select = 0; 			//Stop recording the inputs into storage
							input_counter_select = 0;			//Reset counter to 0
							input_control_select = 0;			//Reset input storage controller to 0
							read_address_inputs_select = 2;		//Stay at the same address for next input problem run
							read_address_weights_select = 1;	//Move to the next address in the SRAM
							next_state = s4;
							end
					end
					16'h0002: begin 
						if(input_counter > 1) begin				//If more addresses to be accessed, access the next address
							record_inputs_select = 3; 			//Record the inputs in the memory location into storage
							input_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							input_control_select = 3;			//Move to the next spots in storage
							read_address_inputs_select = 1;		//Move to the next address in the SRAM
							read_address_weights_select = 2;	//Stay at address in the SRAM
							next_state = s3;
							end
						else if(input_counter == 1) begin		//If more addresses to be accessed, access the next address
							record_inputs_select = 3; 			//Record the inputs in the memory location into storage
							input_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							input_control_select = 3;			//Move to the next spots in storage
							read_address_inputs_select = 2;		//Stay at the same address for next input problem run
							read_address_weights_select = 2;	//Stay at address in the SRAM
							next_state = s3;
							end
						else begin								//Done with reading inputs
							record_inputs_select = 0; 			//Stop recording the inputs into storage
							input_counter_select = 0;			//Reset counter to 0
							input_control_select = 0;			//Reset input storage controller to 0
							read_address_inputs_select = 2;		//Stay at the same address for next input problem run
							read_address_weights_select = 1;	//Move to the next address in the SRAM
							next_state = s4;
							end
					end
					default: begin								//*SHOULDNT HAPPEN*
						record_inputs_select = 2'bxx; 			//*SHOULDNT HAPPEN*
						input_counter_select = 3'bxxx;			//*SHOULDNT HAPPEN*
						input_control_select = 3'bxxx;			//*SHOULDNT HAPPEN*
						read_address_inputs_select = 2'bxx;		//*SHOULDNT HAPPEN*
						read_address_weights_select = 2'bxx;	//*SHOULDNT HAPPEN*
						next_state = s4;
						end
				endcase
				
				input_size_select = 0;
				input_number_select = 0;
				weight_counter_select = 3; 
				weight_counter_group_select = 3;
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
				write_address_select = 2;
			end
			s4 : begin 				//state for obtaining number of weights
				weight_counter_select = 1;				//Read the number of weights from SRAM into weight_counter
				weight_counter_group_select = 1;		//Read the number of weights from SRAM into weight_counter_group
				weight_addresses_select = 1;			//Read the number of weights from SRAM into weight_addresses
				read_address_weights_select = 1;		//Move to the next address in the SRAM
				next_state = s5;
				
				read_address_inputs_select = 2;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
				write_address_select = 2;
			end
			s5 : begin				//state for obtaining size of weights
				weight_size_select = 1;					//Record size of weights into weight_size
				weight_counter_group_select = 3;		//Keep number of weight groups for future calculations
				read_address_weights_select = 1;		//Move to the next address in the SRAM
				casex(read_data_weights)
					16'h0008: begin 
						weight_counter_select = 4; 		//If weight size is 8, divide the weight counter by 2 to obtain memory addresses to be accessed
						weight_addresses_select = 4; 	//If weight size is 8, divide the number of weight addresses to be accessed by 2
						end
					16'h0004: begin 
						weight_counter_select = 5;  	//If weight size is 4, divide the weight counter by 4 to obtain memory addresses to be accessed
						weight_addresses_select = 5;	//If weight size is 4, divide the number of weight addresses to be accessed by 4
						end
					16'h0002: begin 
						weight_counter_select = 6;  	//If weight size is 2, divide the weight counter by 8 to obtain memory addresses to be accessed
						weight_addresses_select = 6;	//If weight size is 2, divide the number of weight addresses to be accessed by 8
						end
					default: begin 
						weight_counter_select = 3'bxxx;		// *SHOULDNT HAPPEN*
						weight_addresses_select = 3'bxxx;	// *SHOULDNT HAPPEN*
						end
				endcase
				next_state = s6; 
				
				read_address_inputs_select = 2;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
				write_address_select = 2;
			end
			s6 : begin				//State for recording weights into storage for later multiplication
				weight_addresses_select = 2;			//Keep the number of weight addresses per group for future calculations
				weight_size_select = 0;					//Keep the size of weights for future calculations
				write_address_select = 2;				//Stay at same write address
				casex(weight_size)
					16'h0008: begin 
						if(weight_counter > 1) begin			//If more addresses to be accessed, access the next address
							record_weights_select = 1; 			//Record the weights in the memory location into storage
							weight_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							weight_control_select = 1;			//Move to the next spots in storage
							read_address_weights_select = 1;	//Move to the next address in the SRAM
							next_state = s6;
							end
						else if(weight_counter == 1) begin		//If more addresses to be accessed, access the next address
							record_weights_select = 1; 			//Record the weights in the memory location into storage
							weight_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							weight_control_select = 1;			//Move to the next spots in storage
							read_address_weights_select = 2;	//Stay at the same address for next weight problem run
							next_state = s6;
							end
						else begin								//Done with reading weights
							record_weights_select = 0; 			//Stop recording the weights into storage
							weight_counter_select = 7;			//Reset counter to number of addresses to be accessed in the next group
							weight_control_select = 0;			//Reset weight storage controller to 0
							read_address_weights_select = 2;	//Stay at the same address for next weight problem run
							next_state = s7;
							end
					end
					16'h0004: begin 
						if(weight_counter > 1) begin			//If more addresses to be accessed, access the next address
							record_weights_select = 2; 			//Record the weights in the memory location into storage
							weight_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							weight_control_select = 2;			//Move to the next spots in storage
							read_address_weights_select = 1;	//Move to the next address in the SRAM
							next_state = s6;
							end
						else if(weight_counter == 1) begin		//If more addresses to be accessed, access the next address
							record_weights_select = 2; 			//Record the weights in the memory location into storage
							weight_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							weight_control_select = 2;			//Move to the next spots in storage
							read_address_weights_select = 2;	//Stay at the same address for next weight problem run
							next_state = s6;
							end
						else begin								//Done with reading weights
							record_weights_select = 0; 			//Stop recording the weights into storage
							weight_counter_select = 7;			//Reset counter to number of addresses to be accessed in the next group
							weight_control_select = 0;			//Reset weight storage controller to 0
							read_address_weights_select = 2;	//Stay at the same address for next weight problem run
							next_state = s7;
							end
					end
					16'h0002: begin 
						if(weight_counter > 1) begin			//If more addresses to be accessed, access the next address
							record_weights_select = 3; 			//Record the weights in the memory location into storage
							weight_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							weight_control_select = 3;			//Move to the next spots in storage
							read_address_weights_select = 1;	//Move to the next address in the SRAM
							next_state = s6;
							end
						else if(weight_counter == 1) begin		//If more addresses to be accessed, access the next address
							record_weights_select = 3; 			//Record the weights in the memory location into storage
							weight_counter_select = 2;			//Decrement the counter for memory addresses to be accessed
							weight_control_select = 3;			//Move to the next spots in storage
							read_address_weights_select = 2;	//Stay at the same address for next weight problem run
							next_state = s6;
							end
						else begin								//Done with reading weights
							record_weights_select = 0; 			//Stop recording the weights into storage
							weight_counter_select = 7;			//Reset counter to number of addresses to be accessed in the next group
							weight_control_select = 0;			//Reset weight storage controller to 0
							read_address_weights_select = 2;	//Stay at the same address for next weight problem run
							next_state = s7;
							end
					end
					default: begin								//*SHOULDNT HAPPEN*
						record_weights_select = 2'bxx; 			//*SHOULDNT HAPPEN*
						weight_counter_select = 3'bxxx;			//*SHOULDNT HAPPEN*
						weight_control_select = 3'bxxx;			//*SHOULDNT HAPPEN*
						read_address_weights_select = 2'bxx;	//*SHOULDNT HAPPEN*
						next_state = s0;
						end
				endcase
				
				read_address_inputs_select = 2;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				weight_counter_group_select = 3;
				mult_input_select = 0;
				accumulate_select = 0;
				write_select = 0;
			end
			s7 : begin				//State for multiplying the inputs and weights
				//Check if all inputs have been multiplied and more weights to be multiplied, signalling to start a new row
				if((mult_input >= input_number) && (weight_counter_group > 1)) begin
					mult_input_select = 0;				//Reset input multiplication counter
					weight_counter_group_select = 2; 	//Decrement the number of groups to be multiplied
					write_select = 1;					//Move data from accumulator to write_data and enable writing
					accumulate_select = 2; 				//Keep accumulator the same
					write_address_select = 2;			//Stay at same write address
					next_state = s8;
					end
				//Check if all inputs have been multiplied and no more weights to be multiplied, signalling to end problem
				else if((mult_input >= input_number) && (weight_counter_group <= 1)) begin
					mult_input_select = 0;				//Reset input multiplication counter
					weight_counter_group_select = 3;	//Stay at same number of weight groups
					write_select = 1;					//Move data from accumulator to write_data and enable writing
					accumulate_select = 2; 				//Keep accumulator the same
					write_address_select = 2;			//Stay at same write address
					next_state = s9;
					end
				else begin
					weight_counter_group_select = 3;
					accumulate_select = 1;				//Multiply inputs and weights and accumulate them
					mult_input_select = 1;				//Move to next input to multiply
					write_address_select = 2;			//Stay at same write address
					write_select = 0;
					next_state = s7;
					end
					
				read_address_inputs_select = 2;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				read_address_weights_select = 2;
				weight_counter_select = 3; 
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
			end
			s8 : begin				//Reset state for accumulator after row of weights have been multiplied
				weight_counter_group_select = 3; 	//Keep the number of groups to be multiplied
				write_select = 0;					//Disable writing	
				write_address_select = 1;			//Move to next write address
				accumulate_select = 0; 				//Reset accumulator
				weight_counter_select = 7; 			//Reload the counter with the number of addresses per group
				read_address_weights_select = 1;		//Move to the next address in the SRAM
				next_state = s6;
				
				read_address_inputs_select = 2;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
			end
			s9 : begin				//Reset state for accumulating all inputs and weights have been multiplied
				write_select = 0;					//Disable writing	
				write_address_select = 1;			//Move to next write address
				accumulate_select = 0; 				//Reset accumulator
				next_state = s10;
				
				read_address_inputs_select = 2;
				input_counter_select = 0;
				input_size_select = 0;
				input_number_select = 0;
				record_inputs_select = 0;
				input_control_select = 0;
				read_address_weights_select = 2;
				weight_counter_select = 3; 
				weight_counter_group_select = 3;
				weight_addresses_select = 2;
				weight_size_select = 0;
				record_weights_select = 0;
				weight_control_select = 0;
				mult_input_select = 0;
			end
			default: begin
				next_state = s0;
				read_address_inputs_select = 2'bxx;
				input_counter_select = 3'bxxx;
				input_size_select = 1'bx;
				input_number_select = 1'bx;
				record_inputs_select = 2'bxx;
				input_control_select = 3'bxxx;
				read_address_weights_select = 2'bxx;
				weight_counter_select = 3'bxxx;
				weight_counter_group_select = 2'bxx;
				weight_addresses_select = 3'bxxx;
				weight_size_select = 1'bx;
				record_weights_select = 2'bxx;
				weight_control_select = 3'bxxx;
				mult_input_select = 1'bx;
				accumulate_select = 2'bxx;
				write_select = 1'bx;
				write_address_select = 2'bxx;
				end
		endcase
	end
			
	//Data Path
	//Input SRAM read address register
	always @(posedge clock) begin
		casex(read_address_inputs_select)
			2'b00: read_address_inputs <= 12'b0;
			2'b01: read_address_inputs <= read_address_inputs + 12'b1;
			2'b1x: read_address_inputs <= read_address_inputs;
		endcase
	end	
	
	//Input counter register
	always @(posedge clock) begin
		casex(input_counter_select)
			3'b000: input_counter <= 16'b0;
			3'b001: input_counter <= read_data_inputs;
			3'b010: input_counter <= input_counter - 16'b1;
			3'b011: input_counter <= input_counter;
			3'b100: input_counter <= input_counter >> 1;
			3'b101: input_counter <= input_counter >> 2;
			3'b110: input_counter <= input_counter >> 3;
			default: input_counter <= input_counter;
		endcase
	end	
	
	//Input size register
	always @(posedge clock) begin
			if (input_size_select == 1'b0)
				input_size <= input_size;
			else 
				input_size <= read_data_inputs;
	end	
	
	//Input number register
	always @(posedge clock) begin
			if (input_number_select == 1'b0)
				input_number <= input_number;
			else 
				input_number <= read_data_inputs;
	end	
	
	//Input storing register
	always @(posedge clock) begin
		casex(record_inputs_select)
			2'b00:
				inputs[input_control] <= inputs[input_control];
			2'b01: begin
				inputs[input_control] <= read_data_inputs[7:0];
				inputs[input_control + 1] <= read_data_inputs[15:8];
				end
			2'b10: begin
				inputs[input_control] <=     {{4{read_data_inputs[3]}}, read_data_inputs[3:0]};
				inputs[input_control + 1] <= {{4{read_data_inputs[7]}}, read_data_inputs[7:4]};
				inputs[input_control + 2] <= {{4{read_data_inputs[11]}}, read_data_inputs[11:8]};
				inputs[input_control + 3] <= {{4{read_data_inputs[15]}}, read_data_inputs[15:12]};
				end
			2'b11: begin
				inputs[input_control] <=     {{6{read_data_inputs[1]}}, read_data_inputs[1:0]};
				inputs[input_control + 1] <= {{6{read_data_inputs[3]}}, read_data_inputs[3:2]};
				inputs[input_control + 2] <= {{6{read_data_inputs[5]}}, read_data_inputs[5:4]};
				inputs[input_control + 3] <= {{6{read_data_inputs[7]}}, read_data_inputs[7:6]};
				inputs[input_control + 4] <= {{6{read_data_inputs[9]}}, read_data_inputs[9:8]};
				inputs[input_control + 5] <= {{6{read_data_inputs[11]}}, read_data_inputs[11:10]};
				inputs[input_control + 6] <= {{6{read_data_inputs[13]}}, read_data_inputs[13:12]};
				inputs[input_control + 7] <= {{6{read_data_inputs[15]}}, read_data_inputs[15:14]};
				end
		endcase
	end	
	
	//Input storing control register
	always @(posedge clock) begin
		casex(input_control_select)
			3'b000: input_control <= 0;
			3'b001:	input_control <= input_control + 2;
			3'b010:	input_control <= input_control + 4;
			3'b011:	input_control <= input_control + 8;
			3'b100:	input_control <= input_control;
			default: input_control <= input_control;
		endcase
	end	
	
	//Weight SRAM read address register
	always @(posedge clock) begin
		casex(read_address_weights_select)
			2'b00: read_address_weights <= 12'b0;
			2'b01: read_address_weights <= read_address_weights + 12'b1;
			2'b1x: read_address_weights <= read_address_weights;
		endcase
	end	
	
	//Weight counter register
	always @(posedge clock) begin
		casex(weight_counter_select)
			3'b000: weight_counter <= 16'b0;
			3'b001: weight_counter <= read_data_weights;
			3'b010: weight_counter <= weight_counter - 16'b1;
			3'b011: weight_counter <= weight_counter;
			3'b100: weight_counter <= weight_counter >> 1;
			3'b101: weight_counter <= weight_counter >> 2;
			3'b110: weight_counter <= weight_counter >> 3;
			3'b111: weight_counter <= weight_addresses;
		endcase
	end	
	
	//Weight group counter register
	always @(posedge clock) begin
		casex(weight_counter_group_select)
			2'b00: weight_counter_group <= 16'b0;
			2'b01: weight_counter_group <= read_data_weights;
			2'b10: weight_counter_group <= weight_counter_group - 16'b1;
			2'b11: weight_counter_group <= weight_counter_group;
		endcase
	end	

	//Weight addresses to be accessed register
	always @(posedge clock) begin
		casex(weight_addresses_select)
			3'b000: weight_addresses <= 16'b0;
			3'b001: weight_addresses <= read_data_weights;
			3'b011: weight_addresses <= weight_addresses;
			3'b100: weight_addresses <= weight_addresses >> 1;
			3'b101: weight_addresses <= weight_addresses >> 2;
			3'b110: weight_addresses <= weight_addresses >> 3;
			default: weight_addresses <= weight_addresses;
		endcase
	end	
	
	//Weight size register
	always @(posedge clock) begin
			if (weight_size_select == 1'b0)
				weight_size <= weight_size;
			else 
				weight_size <= read_data_weights;
	end	
	
	//Weight storing register
	always @(posedge clock) begin
		casex(record_weights_select)
			2'b00:
				weights[weight_control] <= weights[weight_control];
			2'b01: begin
				weights[weight_control] <= read_data_weights[7:0];
				weights[weight_control + 1] <= read_data_weights[15:8];
				end
			2'b10: begin
				weights[weight_control] <=     {{4{read_data_weights[3]}}, read_data_weights[3:0]};
				weights[weight_control + 1] <= {{4{read_data_weights[7]}}, read_data_weights[7:4]};
				weights[weight_control + 2] <= {{4{read_data_weights[11]}}, read_data_weights[11:8]};
				weights[weight_control + 3] <= {{4{read_data_weights[15]}}, read_data_weights[15:12]};
				end
			2'b11: begin
				weights[weight_control] <=     {{6{read_data_weights[1]}}, read_data_weights[1:0]};
				weights[weight_control + 1] <= {{6{read_data_weights[3]}}, read_data_weights[3:2]};
				weights[weight_control + 2] <= {{6{read_data_weights[5]}}, read_data_weights[5:4]};
				weights[weight_control + 3] <= {{6{read_data_weights[7]}}, read_data_weights[7:6]};
				weights[weight_control + 4] <= {{6{read_data_weights[9]}}, read_data_weights[9:8]};
				weights[weight_control + 5] <= {{6{read_data_weights[11]}}, read_data_weights[11:10]};
				weights[weight_control + 6] <= {{6{read_data_weights[13]}}, read_data_weights[13:12]};
				weights[weight_control + 7] <= {{6{read_data_weights[15]}}, read_data_weights[15:14]};
				end
		endcase
	end	
	
	//Weight storing control register
	always @(posedge clock) begin
		casex(weight_control_select)
			3'b000: weight_control <= 0;
			3'b001: weight_control <= weight_control + 2;
			3'b010: weight_control <= weight_control + 4;
			3'b011: weight_control <= weight_control + 8;
			3'b1xx:	weight_control <= weight_control;
		endcase
	end	
	
	//Input multiplication controller register
	always @(posedge clock) begin
			if (mult_input_select == 1'b0)
				mult_input <= 0;
			else 
				mult_input <= mult_input + 1;
	end	
	
	//Accumulator register
	always @(posedge clock) begin
		casex(accumulate_select)
			2'b00: accumulator <= 0;
			2'b01: accumulator <= accumulator + inputs[mult_input]*weights[mult_input];
			2'b1x: accumulator <= accumulator;	
		endcase
	end	
	
	//Write enable and data register
	always @(posedge clock) begin
		casex(write_select)
			1'b0: begin
				write_data <= write_data;
				write_enable <= 0;
				end
			1'b1: begin
				write_data <= accumulator;
				write_enable <= 1;
			end
		endcase
	end	
	
	//Write address register
	always @(posedge clock) begin
		casex(write_address_select)
			2'b00: write_address <= 12'b0;
			2'b01: write_address <= write_address + 12'b1;
			2'b1x: write_address <= write_address;
		endcase
	end	

	assign busy = !(current_state == s0);

endmodule	//SK


