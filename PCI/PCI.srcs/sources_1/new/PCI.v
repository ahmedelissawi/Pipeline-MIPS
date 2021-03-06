`timescale 1ns / 1ps

module device(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N, GNT_N, FORCED_REQ_N, FORCED_ADDRESS, FORCED_CBE_N, Forced_DataTfNo, MIN_ADDRESS, Forced_Frame, Forced_IRDY , Forced_TRDY);

parameter BusFree = 1'b1 , BusBusy = 1'b0;
parameter TransactionStart = 3'b000, GrantGiven = 3'b001, FrameAsserted = 3'b010;
parameter EndOfTurnaround = 3'b011 , DataPhase = 3'b100, Ending_Transaction = 3'b101,Finish = 3'b110;

input FORCED_REQ_N;
input [3:0] Forced_DataTfNo;
input [31:0] MIN_ADDRESS;
input [31:0] FORCED_ADDRESS;
input [3:0] FORCED_CBE_N;
input Forced_Frame, Forced_IRDY, Forced_TRDY;

input CLK, RST_N, GNT_N;

inout [31:0] AD;	
inout [3:0] CBE_N;
inout FRAME_N, IRDY_N, TRDY_N, DEVSEL_N;

output REQ_N;

reg [31:0] ADreg; 
reg [3:0] CBE_Nreg; 
reg [3:0] Counter;
reg [2:0] Status;
reg FRAME_Nreg, IRDY_Nreg, TRDY_Nreg, DEVSEL_Nreg;
reg MasterFlag, SlaveFlag, ReadFlag, WriteFlag;
reg BusStatus;

reg [31:0] memory [0:9];


assign REQ_N    = FORCED_REQ_N;
assign AD       = ADreg;	       
assign CBE_N    = CBE_Nreg;
assign FRAME_N  = FRAME_Nreg;	
assign IRDY_N   = IRDY_Nreg;
assign TRDY_N   = TRDY_Nreg;	    
assign DEVSEL_N = DEVSEL_Nreg;

always @ (DEVSEL_N)
begin
	if(DEVSEL_N == 0)
	begin
		BusStatus <= BusBusy;
	end
	if(DEVSEL_N == 1)
	begin
		BusStatus <= BusFree;
	end
end

always @ (negedge CLK)
begin
	if (RST_N)
	begin
		if(MasterFlag)
		begin
			case (Status)
			GrantGiven:
			begin
				FRAME_Nreg <= 1'b0;
				ADreg      <= FORCED_ADDRESS;
				CBE_Nreg   <= FORCED_CBE_N;
				Status     <= FrameAsserted;
			end
			FrameAsserted: 
			begin 
				IRDY_Nreg <= Forced_IRDY;
				if (CBE_N == 4'b0110)       //Read Operation
				begin
					ReadFlag  <= 1'b1;
					WriteFlag <= 1'b0;
					ADreg     <= {(32){1'bz}};
					CBE_Nreg  <= 4'b0000;
					Status    <= EndOfTurnaround;
				end
				else if (CBE_N == 4'b0111) // Write Operation
				begin
					ReadFlag  <= 1'b0;
					WriteFlag <= 1'b1;
					ADreg     <= memory [Counter];
					CBE_Nreg  <= FORCED_CBE_N;
					if(Counter == (Forced_DataTfNo - 1))
					begin
						FRAME_Nreg <= 1'b1;
					end
					Status <= DataPhase;
				end
			end
			EndOfTurnaround:
			begin 
				Status <= DataPhase;
				if(!DEVSEL_N)
				begin
					if (!TRDY_N)
					begin
						if((Counter == (Forced_DataTfNo - 1)) || (Counter == 8))
						begin
							FRAME_Nreg <= 1'b1;
						end
					end
				end
				else
				begin
					MasterFlag <= 1'b0;
					FRAME_Nreg <= 1'b1;
					IRDY_Nreg  <= 1'b1;
					Counter    <= 4'b0000;
					Status     <= Finish;
				end
			end
			DataPhase:
			begin
				IRDY_Nreg <= Forced_IRDY;
				if (WriteFlag)
				begin
					if(!DEVSEL_N)
					begin
						if (!IRDY_N)
						begin
							ADreg <= memory [Counter];
							CBE_Nreg <= FORCED_CBE_N;
							if((Counter == (Forced_DataTfNo - 1)) || (Counter == 8))
							begin
								FRAME_Nreg <= 1'b1;
							end
						end
					end
					else
					begin
						MasterFlag <= 1'b0;
						FRAME_Nreg <= 1'b1;
						IRDY_Nreg  <= 1'b1;
						Counter    <= 4'b0000;
						Status     <= Finish;
					end
				end
				else if (ReadFlag)
				begin
					if(!DEVSEL_N)
					begin
						if (!TRDY_N)
						begin
							if((Counter == (Forced_DataTfNo - 1)) || (Counter == 8))
							begin
								FRAME_Nreg <= 1'b1;
							end
							else if((Counter == (Forced_DataTfNo)) || (Counter == 9))
							begin
								IRDY_Nreg  <= 1'b1;
								CBE_Nreg  <= 4'bzzzz;
								Status <= Finish;
							end
						end
					end
					else
					begin
						MasterFlag <= 1'b0;
						FRAME_Nreg <= 1'b1;
						IRDY_Nreg  <= 1'b1;
						Counter    <= 4'b0000;
						Status     <= Finish;
					end
				end
			end
			Ending_Transaction:
			begin 
				IRDY_Nreg  <= 1'b1;
				ADreg     <= {(32){1'bz}};
				CBE_Nreg  <= 4'bzzzz;
				Status   <= Finish;
			end
			Finish:
			begin
				FRAME_Nreg <= 1'bz;
				IRDY_Nreg  <= 1'bz;
				ADreg     <= {(32){1'bz}};
				CBE_Nreg  <= 4'bzzzz;
				Counter    <= 4'b0000;
				MasterFlag <= 1'b0; 
		        SlaveFlag <= 1'b0; 
				Status     <= TransactionStart;
			end
			endcase
		end
		else if(SlaveFlag)
		begin
			case (Status)
			GrantGiven:
			begin
				DEVSEL_Nreg <= 1'b0;
				TRDY_Nreg <= Forced_TRDY; 
				if (CBE_N == 4'b0110)       //Read Operation by master
				begin
					ReadFlag  <= 1'b1;
					WriteFlag <= 1'b0;
				end
				else if (CBE_N == 4'b0111) // Write Operation by master
				begin
					ReadFlag  <= 1'b0;
					WriteFlag <= 1'b1;
				end
				Status <= DataPhase;
			end
			DataPhase:
			begin
				TRDY_Nreg <= Forced_TRDY;
				if (ReadFlag)
				begin
					if (!TRDY_N)
					begin
						ADreg <= memory[Counter];
					end
				end
			end
			Ending_Transaction:
			begin 
				DEVSEL_Nreg <= 1;
				TRDY_Nreg <= 1;
				ADreg <= {(32){1'bz}};
				Status <= Finish;
			end
			Finish:
			begin
				DEVSEL_Nreg <= 1'bz;
				TRDY_Nreg <= 1'bz;
				ADreg     <= {(32){1'bz}};
				MasterFlag <= 1'b0; 
				SlaveFlag <= 1'b0; 
				Counter    <= 4'b0000;
				Status     <= TransactionStart;
			end
			endcase
		end
	end
end

always @ (posedge CLK)
begin
    if (RST_N)
	begin
		if((!GNT_N && !REQ_N && BusStatus && !SlaveFlag) || MasterFlag ) //Then Device is Master
		begin 
			MasterFlag <= 1'b1;
			case (Status)
			TransactionStart:
			begin
				if(!Forced_Frame)
				begin
					Status <= GrantGiven;
				end
			end
			DataPhase:
			begin
				if (ReadFlag)
				begin
					if(!DEVSEL_N)
					begin
						if (!TRDY_N && !IRDY_N)
						begin
							memory[Counter] <= AD;
							Counter <= Counter + 1;
						end
					end
				end
				if (WriteFlag)
				begin
					if(!DEVSEL_N)
					begin
						if (!TRDY_N && !IRDY_N)
						begin
							Counter <= Counter + 1;
							if((Counter == (Forced_DataTfNo - 1)) || (Counter == 8))
							begin
								Status <= Ending_Transaction;
							end
						end
					end
				end
			end
			endcase
		end
		else if (BusStatus || SlaveFlag)  	//Device is Slave
		begin
			if(((AD >= MIN_ADDRESS) && (AD < (MIN_ADDRESS + 10))) || SlaveFlag)
			begin
				case (Status)
				TransactionStart:
				begin
					SlaveFlag <= 1'b1;
					Status <= GrantGiven;
					Counter <= (AD - MIN_ADDRESS);
				end
				DataPhase:
				begin
					if (WriteFlag)
					begin
						if (!TRDY_N && !IRDY_N)
						begin
							if(CBE_N [0] == 0)
								memory[Counter][7:0]  <= AD [7:0];
							if(CBE_N [1] == 0)
								memory[Counter][15:8] <= AD [15:8];
							if(CBE_N [2] == 0)
								memory[Counter][23:16] <= AD [23:16];
							if(CBE_N [3] == 0)
							    memory[Counter][31:24] <=	AD [31:24];
							Counter <= Counter + 1;
							if(FRAME_N)
							begin
								Status <= Ending_Transaction;
							end
						end
					end
					else if (ReadFlag)
					begin
						if(!IRDY_N && !TRDY_N)
						begin
							Counter <= Counter + 1;
							if(FRAME_N)
								begin
									Status <= Ending_Transaction;
								end
							end
						end
					end
				endcase
			end		
		end
	end
end

always @ (negedge RST_N)
begin 
	ADreg <= {(32){1'bz}};
	CBE_Nreg <= 4'bzzzz;
	FRAME_Nreg <= 1'bz;
	IRDY_Nreg <= 1'bz; 
	TRDY_Nreg <= 1'bz; 
	DEVSEL_Nreg <= 1'bz;
	MasterFlag <= 1'b0; 
	SlaveFlag <= 1'b0; 
	Counter <= 4'b0000;
	BusStatus <= BusFree;
	Status <= TransactionStart; 
	memory[0] <= {MIN_ADDRESS [15:0],{16'h0001}};
	memory[1] <= {MIN_ADDRESS [15:0],{16'h0002}};
	memory[2] <= {MIN_ADDRESS [15:0],{16'h0003}};
	memory[3] <= {MIN_ADDRESS [15:0],{16'h0004}};
	memory[4] <= {MIN_ADDRESS [15:0],{16'h0005}};
	memory[5] <= {MIN_ADDRESS [15:0],{16'h0006}};
	memory[6] <= {MIN_ADDRESS [15:0],{16'h0007}};
	memory[7] <= {MIN_ADDRESS [15:0],{16'h0008}};
	memory[8] <= {MIN_ADDRESS [15:0],{16'h0009}};
	memory[9] <= {MIN_ADDRESS [15:0],{16'h000A}}; 
end	
endmodule

module arbiter_priority(GNT_N, REQ_N, FRAME_N, RST_N, mode);
inout [7:0] GNT_N;
input [7:0] REQ_N;
input FRAME_N,RST_N;
input [1:0] mode;
reg EN, BusStatus;
reg [7:0] GNT_Nreg;

assign GNT_N = GNT_Nreg;

always @(FRAME_N, REQ_N, RST_N)
begin
	if (mode == 2'b00)
	begin
		if(~RST_N)
		begin
			GNT_Nreg <= 8'b1111_1111;
			BusStatus <= 1'b1;
			EN <= 1'b1;
		end
		else if(FRAME_N == 1'b0)
		begin
			EN <= 1'b1;
		end
		else if((FRAME_N && EN) || (BusStatus))
		begin
			casez(REQ_N)
				8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; EN <= 1'b0;BusStatus <= 1'b0; end
				8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; EN <= 1'b0;BusStatus <= 1'b0; end
				8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; EN <= 1'b0;BusStatus <= 1'b0; end
				8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; EN <= 1'b0;BusStatus <= 1'b0; end
				8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; EN <= 1'b0;BusStatus <= 1'b0; end
				8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; EN <= 1'b0;BusStatus <= 1'b0; end
				8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; EN <= 1'b0;BusStatus <= 1'b0; end
				8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; EN <= 1'b0;BusStatus <= 1'b0; end
				default:begin GNT_Nreg <= 8'b1111_1111; EN <= 1'b1;BusStatus <= 1'b1; end
			endcase
		end
	end
	else
	begin
		GNT_Nreg <= 8'bzzzz_zzzz;
	end
end
endmodule

module arbiter_RobinRound(GNT_N, REQ_N, FRAME_N, RST_N, mode);
inout [7:0] GNT_N;
input [7:0] REQ_N;
input FRAME_N,RST_N;
input [1:0] mode;

reg EN, BusStatus;
reg [2:0] counter;
reg [7:0] GNT_Nreg;

assign GNT_N = GNT_Nreg;

always @(FRAME_N, REQ_N, RST_N)
begin
if (mode == 2'b01)
begin
	if(~RST_N)
	begin
		GNT_Nreg <= 8'b1111_1111;
		BusStatus <= 1'b1;
		counter <= 3'b000;
	end
	else if(FRAME_N == 1'b0)
	begin
		EN <= 1'b1;
	end
	else if((FRAME_N && EN) || (BusStatus))
	begin
		case(counter)
		3'b000:
		begin
		casez(REQ_N)
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b000; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase
		end
		3'b001:
		begin
		casez(REQ_N)
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b001; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase
		end
		3'b010:
		begin
		casez(REQ_N)
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b010; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase
		end
		3'b011:
		begin
		casez(REQ_N)
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b011; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase                
		end
		3'b100:
		begin
		casez(REQ_N)
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b100; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase                
		end
		3'b101:
		begin
		casez(REQ_N)
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b101; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase                
		end
		3'b110:
		begin
		casez(REQ_N)
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b110; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase               
		end
		3'b111:
		begin
		casez(REQ_N)
			8'b0zzz_zzzz:begin GNT_Nreg <= 8'b0111_1111; counter <= 3'b000; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zzz0:begin GNT_Nreg <= 8'b1111_1110; counter <= 3'b001; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_zz0z:begin GNT_Nreg <= 8'b1111_1101; counter <= 3'b010; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_z0zz:begin GNT_Nreg <= 8'b1111_1011; counter <= 3'b011; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzzz_0zzz:begin GNT_Nreg <= 8'b1111_0111; counter <= 3'b100; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzzz0_zzzz:begin GNT_Nreg <= 8'b1110_1111; counter <= 3'b101; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bzz0z_zzzz:begin GNT_Nreg <= 8'b1101_1111; counter <= 3'b110; EN <= 1'b0;BusStatus <= 1'b0; end
			8'bz0zz_zzzz:begin GNT_Nreg <= 8'b1011_1111; counter <= 3'b111; EN <= 1'b0;BusStatus <= 1'b0; end
			default: begin GNT_Nreg <= 8'b1111_1111; counter <= 3'b111; EN <= 1'b1;BusStatus <= 1'b1; end
		endcase                
	   end
	endcase
	end
end
else
begin
	GNT_Nreg <= 8'bzzzz_zzzz;
end
end
endmodule 

module arbiter_FCFS(GNT , REQ , FRAME_Neg ,CLK, RST_Neg,ON_OFF);

output [7:0] GNT ;
wire [7:0] TH0,TH1,TH2,TH3,TH4,TH5,TH6,TH7,memory_out;
input [7:0] REQ;
input FRAME_Neg,RST_Neg,CLK;
input[1:0] ON_OFF;

REQ_THREADER RT1(CLK,REQ,TH0,TH1,TH2,TH3,TH4,TH5,TH6,TH7);
memory m1(TH0,TH1,TH2,TH3,TH4,TH5,TH6,TH7,memory_out,CLK,FRAME_Neg,RST_Neg,ON_OFF);
assign GNT = memory_out;

endmodule

// thread the input depending on the zeros, all 1=> all1 and arragne them with piorty
module REQ_THREADER(CLK, REQ, THREADING_REQ0, THREADING_REQ1, THREADING_REQ2, THREADING_REQ3, THREADING_REQ4, THREADING_REQ5, THREADING_REQ6, THREADING_REQ7);
//request output only 1 time
input CLK;
input [7:0]REQ;
output reg [7:0]THREADING_REQ0;
output reg [7:0]THREADING_REQ1;
output reg [7:0]THREADING_REQ2;
output reg [7:0]THREADING_REQ3;
output reg [7:0]THREADING_REQ4;
output reg [7:0]THREADING_REQ5;
output reg [7:0]THREADING_REQ6;
output reg [7:0]THREADING_REQ7;
reg [7:0]THREADING_REQ[0:7]; // memory
reg [3:0] free_location;
//if 0 get out 
//if all 1 output = 1111_1111

always@(*)
begin
	free_location = 0;
	if(REQ[0] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1111_1110;  
		free_location = free_location + 1;
	end
	if(REQ[1] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1111_1101;  
		free_location = free_location + 1;
	end
	if(REQ[2] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1111_1011;
		free_location = free_location + 1;
	end
	if(REQ[3] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1111_0111;
		free_location = free_location + 1;
	end
	if(REQ[4] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1110_1111;
		free_location = free_location + 1;
	end
	if(REQ[5] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1101_1111;
		free_location = free_location + 1;
	end
	if(REQ[6] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b1011_1111;
		free_location = free_location + 1;
	end
	if(REQ[7] == 1'b0)
	begin
		THREADING_REQ[free_location] = 8'b0111_1111;
		free_location = free_location+1;
	end
	
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
		free_location = free_location + 1;
	end
	if(free_location < 8)
	begin
		THREADING_REQ[free_location] = 8'b1111_1111;
	end

	THREADING_REQ0<=THREADING_REQ[0];
	THREADING_REQ1<=THREADING_REQ[1];
	THREADING_REQ2<=THREADING_REQ[2];
	THREADING_REQ3<=THREADING_REQ[3];
	THREADING_REQ4<=THREADING_REQ[4];
	THREADING_REQ5<=THREADING_REQ[5];
	THREADING_REQ6<=THREADING_REQ[6];
	THREADING_REQ7<=THREADING_REQ[7];

end
endmodule

module memory(IN0,IN1,IN2,IN3,IN4,IN5,IN6,IN7,OUT1,CLK,FRAME,RESET,ON_OFF);

input [7:0] IN0,IN1,IN2,IN3,IN4,IN5,IN6,IN7;
output reg [7:0] OUT1;
input [1:0]ON_OFF;
input CLK,FRAME,RESET;
reg [7:0]MEGA_MIND[0:7];
//flag1 equals ex
reg first_time,ENABLE_TO_GNT;
reg [2:0]free_location;

always@(posedge FRAME)
begin
	if(ON_OFF == 3)
		ENABLE_TO_GNT <= 1;
end
 
always@(negedge RESET)
begin
	if(ON_OFF == 3)
	begin
		OUT1 <= 9'b1111_1111;
		first_time <= 0;
	end
end

always@(posedge CLK)
begin
	if(ON_OFF==3)
	begin
		if(~RESET)
		begin
			OUT1 <= 8'b1111_1111;
			ENABLE_TO_GNT = 1;
			first_time = 0;
		end
		else
		begin
			if(first_time==1)
			begin
				casez(MEGA_MIND[7])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[7] = 8'b1111_1111;
					free_location = free_location - 1;
				end
				endcase

				casez(MEGA_MIND[6])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[6] = MEGA_MIND[7];
					MEGA_MIND[7] = 8'b1111_1111;
					free_location = free_location - 1;
				end
				endcase

				casez(MEGA_MIND[5])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[5] = MEGA_MIND[6];
					MEGA_MIND[6] = MEGA_MIND[7];
					MEGA_MIND[7] = 8'b1111_1111;
					free_location = free_location - 1;
				end
				endcase

				casez(MEGA_MIND[4])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[4] = MEGA_MIND[5];
					MEGA_MIND[5] = MEGA_MIND[6];
					MEGA_MIND[6] = MEGA_MIND[7];
					MEGA_MIND[7] = 8'b1111_1111;
					free_location = free_location-1;
				end
				endcase

				casez(MEGA_MIND[3])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[3] = MEGA_MIND[4];
					MEGA_MIND[4] = MEGA_MIND[5];
					MEGA_MIND[5] = MEGA_MIND[6];
					MEGA_MIND[6] = MEGA_MIND[7];
					MEGA_MIND[7] = 8'b1111_1111;
					free_location = free_location-1;
				end
				endcase

				casez(MEGA_MIND[2])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[2]=MEGA_MIND[3];
					MEGA_MIND[3]=MEGA_MIND[4];
					MEGA_MIND[4]=MEGA_MIND[5];
					MEGA_MIND[5]=MEGA_MIND[6];
					MEGA_MIND[6]=MEGA_MIND[7];
					MEGA_MIND[7]=8'b1111_1111;
					free_location=free_location-1;
				end
				endcase

				casez(MEGA_MIND[1])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[1]=MEGA_MIND[2];
					MEGA_MIND[2]=MEGA_MIND[3];
					MEGA_MIND[3]=MEGA_MIND[4];
					MEGA_MIND[4]=MEGA_MIND[5];
					MEGA_MIND[5]=MEGA_MIND[6];
					MEGA_MIND[6]=MEGA_MIND[7];
					MEGA_MIND[7]=8'b1111_1111;
					free_location=free_location-1;
				end
				endcase

				casez(MEGA_MIND[0])
				IN0:;
				IN1:;
				IN2:;
				IN3:;
				IN4:;
				IN5:;
				IN6:;
				IN7:;
				default:
				begin
					MEGA_MIND[0]=MEGA_MIND[1];
					MEGA_MIND[1]=MEGA_MIND[2];
					MEGA_MIND[2]=MEGA_MIND[3];
					MEGA_MIND[3]=MEGA_MIND[4];
					MEGA_MIND[4]=MEGA_MIND[5];
					MEGA_MIND[5]=MEGA_MIND[6];
					MEGA_MIND[6]=MEGA_MIND[7];
					MEGA_MIND[7]=8'b1111_1111;
					free_location=free_location-1;
				end
				endcase

//CHECK MEMORY INSIDE THE NEW DATA  AND REMOVE THE UNFOUND REQUESTS
//===================================================================\\


				casez(IN0)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					MEGA_MIND[free_location]=IN0;
					free_location=free_location+1;
				end
				endcase

				casez(IN1)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					MEGA_MIND[free_location]=IN1;
					free_location=free_location+1;
				end
				endcase

				casez(IN2)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					MEGA_MIND[free_location]=IN2;
					free_location=free_location+1;
				end
				endcase

				casez(IN3)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					MEGA_MIND[free_location]=IN3;
					free_location=free_location+1;
				end
				endcase

				casez(IN4)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin 
					MEGA_MIND[free_location]=IN4;
					free_location=free_location+1;
				end
				endcase

				casez(IN5)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					MEGA_MIND[free_location]=IN5;
					free_location=free_location+1;
				end
				endcase

				casez(IN6)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					MEGA_MIND[free_location]=IN6;
					free_location=free_location+1;
				end
				endcase

				casez(IN7)
				MEGA_MIND[0]: ;
				MEGA_MIND[1]: ;
				MEGA_MIND[2]: ;
				MEGA_MIND[3]: ;
				MEGA_MIND[4]: ;
				MEGA_MIND[5]: ;
				MEGA_MIND[6]: ;
				MEGA_MIND[7]: ;
				default:begin
					if(free_location>7)
					MEGA_MIND[free_location]=IN7;  
					free_location=free_location+1;
				end
				endcase
			end
			else
			begin
				first_time=1;
				free_location=0;
				MEGA_MIND[0]=IN0;
				free_location=free_location+1;
				MEGA_MIND[1]=IN1;
				free_location=free_location+1;  
				MEGA_MIND[2]=IN2;
				free_location=free_location+1;
				MEGA_MIND[3]=IN3;
				free_location=free_location+1;
				MEGA_MIND[4]=IN4;
				free_location=free_location+1;
				MEGA_MIND[5]=IN5;
				free_location=free_location+1;
				MEGA_MIND[6]=IN6;
				free_location=free_location+1;
				MEGA_MIND[7]=IN7;
				//reset the free location
				if(IN0==8'b1111_1111)
					free_location=0;
				else if(IN1==8'b1111_1111)
					free_location=1;
				else if(IN2==8'b1111_1111)
					free_location=2;
				else if(IN3==8'b1111_1111)
					free_location=3;
				else if(IN4==8'b1111_1111)
					free_location=4;
				else if(IN5==8'b1111_1111)
					free_location=5;
				else if(IN6==8'b1111_1111)
					free_location=6;
				else if(IN7==8'b1111_1111) 
					free_location=7;  
			end
		end
	end
end

always@(negedge CLK)
begin
	if(ON_OFF == 3)
	begin
		if(ENABLE_TO_GNT && RESET)
		begin
			if(MEGA_MIND[0] === 8'bxxxx_xxxx)
			begin
				OUT1 = 8'b1111_1111;
			end
			else
			begin
				OUT1 <= MEGA_MIND[0];
				MEGA_MIND[0] <=  MEGA_MIND[1];
				MEGA_MIND[1] <=  MEGA_MIND[2];
				MEGA_MIND[2] <=  MEGA_MIND[3];
				MEGA_MIND[3] <=  MEGA_MIND[4];
				MEGA_MIND[4] <=  MEGA_MIND[5];
				MEGA_MIND[5] <=  MEGA_MIND[6];
				MEGA_MIND[6] <=  MEGA_MIND[7];
				MEGA_MIND[7] <=  8'b1111_1111;
				if(OUT1 != 8'b1111_1111)
				begin
					free_location <= free_location - 1;  
					ENABLE_TO_GNT <= 0;
				end
			end
		end
	end
	else
	begin
		OUT1 <= 8'bzzzz_zzzz;
		first_time <= 0;
	end
end

endmodule


module PCI(CLK, RST_N, FORCED_REQ_N, mode, Forced_Frame,Forced_IRDY, Forced_TRDY,
           FORCED_ADDRESS_A, FORCED_ADDRESS_B, FORCED_ADDRESS_C, FORCED_ADDRESS_D, FORCED_ADDRESS_E, FORCED_ADDRESS_F, FORCED_ADDRESS_G, FORCED_ADDRESS_H,
		   FORCED_CBE_N_A, FORCED_CBE_N_B, FORCED_CBE_N_C, FORCED_CBE_N_D, FORCED_CBE_N_E, FORCED_CBE_N_F, FORCED_CBE_N_G, FORCED_CBE_N_H,
		   Forced_DataTfNo_A, Forced_DataTfNo_B, Forced_DataTfNo_C, Forced_DataTfNo_D, Forced_DataTfNo_E, Forced_DataTfNo_F, Forced_DataTfNo_G, Forced_DataTfNo_H);

input CLK,RST_N,Forced_Frame,Forced_IRDY, Forced_TRDY;
input [1:0] mode;
wire FRAME_N, IRDY_N, TRDY_N, DEVSEL_N;
wire [31:0] AD;
wire [3:0] CBE_N;

input [3:0] Forced_DataTfNo_A;
input [3:0] Forced_DataTfNo_B;
input [3:0] Forced_DataTfNo_C;
input [3:0] Forced_DataTfNo_D;
input [3:0] Forced_DataTfNo_E;
input [3:0] Forced_DataTfNo_F;
input [3:0] Forced_DataTfNo_G;
input [3:0] Forced_DataTfNo_H;

input [31:0] FORCED_ADDRESS_A;
input [31:0] FORCED_ADDRESS_B;
input [31:0] FORCED_ADDRESS_C;
input [31:0] FORCED_ADDRESS_D;
input [31:0] FORCED_ADDRESS_E;
input [31:0] FORCED_ADDRESS_F;
input [31:0] FORCED_ADDRESS_G;
input [31:0] FORCED_ADDRESS_H;

input [3:0] FORCED_CBE_N_A;
input [3:0] FORCED_CBE_N_B;
input [3:0] FORCED_CBE_N_C;
input [3:0] FORCED_CBE_N_D;
input [3:0] FORCED_CBE_N_E;
input [3:0] FORCED_CBE_N_F;
input [3:0] FORCED_CBE_N_G;
input [3:0] FORCED_CBE_N_H;

input [7:0] FORCED_REQ_N;

wire [7:0] REQ_N;
wire [7:0] GNT_N;


device A(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[0], GNT_N[0], FORCED_REQ_N[0], FORCED_ADDRESS_A, FORCED_CBE_N_A, Forced_DataTfNo_A, 32'h0000_0000, Forced_Frame, Forced_IRDY, Forced_TRDY);
device B(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[1], GNT_N[1], FORCED_REQ_N[1], FORCED_ADDRESS_B, FORCED_CBE_N_B, Forced_DataTfNo_B, 32'h0000_000A, Forced_Frame, Forced_IRDY, Forced_TRDY);
device C(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[2], GNT_N[2], FORCED_REQ_N[2], FORCED_ADDRESS_C, FORCED_CBE_N_C, Forced_DataTfNo_C, 32'h0000_0014, Forced_Frame, Forced_IRDY, Forced_TRDY);
device D(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[3], GNT_N[3], FORCED_REQ_N[3], FORCED_ADDRESS_D, FORCED_CBE_N_D, Forced_DataTfNo_D, 32'h0000_001E, Forced_Frame, Forced_IRDY, Forced_TRDY);
device E(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[4], GNT_N[4], FORCED_REQ_N[4], FORCED_ADDRESS_E, FORCED_CBE_N_E, Forced_DataTfNo_E, 32'h0000_0028, Forced_Frame, Forced_IRDY, Forced_TRDY);
device F(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[5], GNT_N[5], FORCED_REQ_N[5], FORCED_ADDRESS_F, FORCED_CBE_N_F, Forced_DataTfNo_F, 32'h0000_0032, Forced_Frame, Forced_IRDY, Forced_TRDY);
device G(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[6], GNT_N[6], FORCED_REQ_N[6], FORCED_ADDRESS_G, FORCED_CBE_N_G, Forced_DataTfNo_G, 32'h0000_003C, Forced_Frame, Forced_IRDY, Forced_TRDY);
device H(CLK, RST_N, AD, CBE_N, FRAME_N, IRDY_N, TRDY_N, DEVSEL_N, REQ_N[7], GNT_N[7], FORCED_REQ_N[7], FORCED_ADDRESS_H, FORCED_CBE_N_H, Forced_DataTfNo_H, 32'h0000_0046, Forced_Frame, Forced_IRDY, Forced_TRDY);

arbiter_priority PriorityArbiter(GNT_N, REQ_N, FRAME_N, RST_N, mode);
arbiter_RobinRound RobinRoundArbiter(GNT_N, REQ_N, FRAME_N, RST_N, mode);
arbiter_FCFS FCFSArbiter(GNT_N, REQ_N, FRAME_N, CLK, RST_N, mode);

endmodule



module PCI_tb();

reg [7:0] FORCED_REQ_N;

reg [3:0] Forced_DataTfNo_A;
reg [3:0] Forced_DataTfNo_B;
reg [3:0] Forced_DataTfNo_C;
reg [3:0] Forced_DataTfNo_D;
reg [3:0] Forced_DataTfNo_E;
reg [3:0] Forced_DataTfNo_F;
reg [3:0] Forced_DataTfNo_G;
reg [3:0] Forced_DataTfNo_H;

reg [31:0] FORCED_ADDRESS_A;
reg [31:0] FORCED_ADDRESS_B;
reg [31:0] FORCED_ADDRESS_C;
reg [31:0] FORCED_ADDRESS_D;
reg [31:0] FORCED_ADDRESS_E;
reg [31:0] FORCED_ADDRESS_F;
reg [31:0] FORCED_ADDRESS_G;
reg [31:0] FORCED_ADDRESS_H;

reg [3:0] FORCED_CBE_N_A;
reg [3:0] FORCED_CBE_N_B;
reg [3:0] FORCED_CBE_N_C;
reg [3:0] FORCED_CBE_N_D;
reg [3:0] FORCED_CBE_N_E;
reg [3:0] FORCED_CBE_N_F;
reg [3:0] FORCED_CBE_N_G;
reg [3:0] FORCED_CBE_N_H;


reg CLK, RST_N, Forced_Frame, Forced_IRDY, Forced_TRDY;
reg [1:0] mode;

/*
Device_A --> 32'h0000_0000 : 32'h0000_0009
Device_B --> 32'h0000_000A : 32'h0000_0013
Device_C --> 32'h0000_0014 : 32'h0000_001D
Device_D --> 32'h0000_001E : 32'h0000_0027
Device_E --> 32'h0000_0028 : 32'h0000_0031
Device_F --> 32'h0000_0032 : 32'h0000_003B
Device_G --> 32'h0000_003C : 32'h0000_0045
Device_H --> 32'h0000_0046 : 32'h0000_004F
*/

initial
begin

// ____ TA ____
CLK <= 1'b0;
RST_N <= 1'b0;
mode <= 2'b00;
Forced_Frame <= 1'b0;
Forced_IRDY <= 1'b0;
Forced_TRDY <= 1'b0;
#10
RST_N  <= 1;
FORCED_REQ_N <= 8'b1111_1110;
FORCED_ADDRESS_A <= 32'h0000_000A;
FORCED_CBE_N_A <= 4'b0111;
Forced_DataTfNo_A <= 3;
#10
FORCED_CBE_N_A <= 4'b0000;
#20
FORCED_REQ_N <= 8'b1111_1101;
FORCED_ADDRESS_B <= 32'h0000_0005;
FORCED_CBE_N_B <= 4'b0111;
Forced_DataTfNo_B <= 2;
#40
FORCED_CBE_N_B <= 4'b0000;
#10
FORCED_REQ_N <= 8'b1111_1010;
FORCED_ADDRESS_A <= 32'h0000_0014;
FORCED_ADDRESS_C <= 32'h0000_0003;
FORCED_CBE_N_A <= 4'b0111;
FORCED_CBE_N_C <= 4'b0111;
Forced_DataTfNo_A <= 2;
Forced_DataTfNo_C <= 1;
#40
FORCED_CBE_N_A <= 4'b0000;
#10
FORCED_REQ_N <= 8'b1111_1011;
#40
FORCED_CBE_N_C <= 4'b0000;
#20
FORCED_CBE_N_C <= 4'b0111;
FORCED_ADDRESS_C <= 32'h0000_000E;
#20
FORCED_CBE_N_C <= 4'b000;
#30


// ____ PriorityArbiter ____
RST_N <= 0;
mode <= 2'b00;
#25
RST_N  <= 1;

FORCED_REQ_N <= 8'b1111_1010;
FORCED_ADDRESS_A <= 32'h0000_000A;
FORCED_ADDRESS_C <= 32'h0000_000F;
FORCED_CBE_N_A <= 4'b0111;
FORCED_CBE_N_C <= 4'b0110;
Forced_DataTfNo_A <= 5;
Forced_DataTfNo_C <= 3;
#20
FORCED_CBE_N_A <= 4'b0000;
#50
FORCED_ADDRESS_A <= 32'h0000_0028;
FORCED_CBE_N_A <= 4'b0111;
#30
FORCED_CBE_N_A <= 4'b0000;
#30
FORCED_REQ_N <= 8'b1111_1011;
#40
FORCED_CBE_N_C <= 4'b0000;
#30
FORCED_ADDRESS_C <= 32'h0000_0021;
FORCED_CBE_N_C <= 4'b0111;
#40
FORCED_CBE_N_C <= 4'b0000;
#20
FORCED_REQ_N <= 8'b1111_0101;
FORCED_ADDRESS_B <= 32'h0000_001E;
FORCED_ADDRESS_D <= 32'h0000_0046;
FORCED_CBE_N_B <= 4'b0111;
FORCED_CBE_N_D <= 4'b0110;
Forced_DataTfNo_B <= 4;
Forced_DataTfNo_D <= 1;
#30
FORCED_CBE_N_B <= 4'b0000;
#50
FORCED_ADDRESS_B <= 32'h0000_0023;
FORCED_CBE_N_B <= 4'b0111;
#20
FORCED_CBE_N_B <= 4'b0000;
#50
FORCED_ADDRESS_B <= 32'h0000_0046;
FORCED_CBE_N_B <= 4'b0111;
#20
FORCED_CBE_N_B <= 4'b0000;
#50
FORCED_ADDRESS_B <= 32'h0000_0048;
FORCED_CBE_N_B <= 4'b0111;
#20
FORCED_CBE_N_B <= 4'b0000;
#30
FORCED_REQ_N <= 8'b1111_0111;
#40
FORCED_REQ_N <= 8'b0111_1111;
FORCED_ADDRESS_H <= 32'h0000_0014;
FORCED_CBE_N_H <= 4'b0110;
Forced_DataTfNo_H <= 8;
Forced_Frame <= 1'b1;
#80
Forced_Frame <= 1'b0;
#40
Forced_IRDY <= 1'b1;
#20
Forced_IRDY <= 1'b0;
#40
Forced_TRDY <= 1'b1;
#20
Forced_TRDY <= 1'b0;
#60



// ____ RobinRoundArbiter ____
RST_N <= 0;
mode <= 2'b01;
#15
RST_N  <= 1;

FORCED_REQ_N <= 8'b1111_1010;
FORCED_ADDRESS_A <= 32'h0000_000A;
FORCED_ADDRESS_C <= 32'h0000_000F;
FORCED_CBE_N_A <= 4'b0111;
FORCED_CBE_N_C <= 4'b0110;
Forced_DataTfNo_A <= 5;
Forced_DataTfNo_C <= 3;
#20
FORCED_CBE_N_A <= 4'b0000;
#60
FORCED_CBE_N_C <= 4'b0000;
#30
FORCED_ADDRESS_A <= 32'h0000_0028;
FORCED_CBE_N_A <= 4'b0111;
#30
FORCED_CBE_N_A <= 4'b0000;
#30
FORCED_ADDRESS_C <= 32'h0000_0021;
FORCED_CBE_N_C <= 4'b0111;
#40
FORCED_CBE_N_C <= 4'b0000;
#50

// ____ FCFSArbiter ____ 
RST_N <= 0;
mode <= 2'b11;
#10
RST_N  <= 1;

FORCED_REQ_N <= 8'b1101_1110;
FORCED_ADDRESS_A <= 32'h0000_000A;
FORCED_ADDRESS_C <= 32'h0000_000F;
FORCED_ADDRESS_F <= 32'h0000_003C;
FORCED_CBE_N_A <= 4'b0111;
FORCED_CBE_N_C <= 4'b0110;
FORCED_CBE_N_F <= 4'b0110;
Forced_DataTfNo_A <= 5;
Forced_DataTfNo_C <= 3;
Forced_DataTfNo_F <= 3;
#40
FORCED_REQ_N <= 8'b1101_1010;
FORCED_CBE_N_A <= 4'b0000;
#30
FORCED_ADDRESS_A <= 32'h0000_0028;
FORCED_CBE_N_A <= 4'b0111;
#35
FORCED_CBE_N_A <= 4'b0000;
#25
FORCED_REQ_N <= 8'b1101_1011;
#200
FORCED_ADDRESS_F <= 32'h0000_0028;
FORCED_CBE_N_F <= 4'b0111;
#35
FORCED_CBE_N_F <= 4'b0000;
#25
FORCED_REQ_N <= 8'b1101_1011;
#80
#80
RST_N <= 0;

end

always
begin
#5 CLK = ~CLK;
end

PCI pci(CLK, RST_N, FORCED_REQ_N, mode,Forced_Frame,Forced_IRDY, Forced_TRDY,
        FORCED_ADDRESS_A, FORCED_ADDRESS_B, FORCED_ADDRESS_C, FORCED_ADDRESS_D, FORCED_ADDRESS_E, FORCED_ADDRESS_F, FORCED_ADDRESS_G, FORCED_ADDRESS_H,
		FORCED_CBE_N_A, FORCED_CBE_N_B, FORCED_CBE_N_C, FORCED_CBE_N_D, FORCED_CBE_N_E, FORCED_CBE_N_F, FORCED_CBE_N_G, FORCED_CBE_N_H,
		Forced_DataTfNo_A, Forced_DataTfNo_B, Forced_DataTfNo_C, Forced_DataTfNo_D, Forced_DataTfNo_E, Forced_DataTfNo_F, Forced_DataTfNo_G, Forced_DataTfNo_H);

endmodule