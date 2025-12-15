`timescale 1ns / 1ps

module uart_bmpg(
	input wire		upg_clk_i,			// 10MHz
	input wire		upg_rst_i,			// High active
	// blkram signals
	output wire		upg_clk_o,
	output reg		upg_wen_o,
	output reg [14:0]	upg_adr_o,
	output reg [31:0]	upg_dat_o,
	output reg		upg_done_o,
	// UART Pinouts
	input wire		upg_rx_i,
	output reg		upg_tx_o
);

	// ========================================
	// 10MHz / 128000 bps
	localparam BAUD_CNT = 10'd78;
	
	// ״̬
	localparam IDLE = 3'd0;        //  START BIT
	localparam START = 3'd1;       // ֤ START BIT
	localparam DATA = 3'd2;        
	localparam STOP = 3'd3;        // ֤ STOP BIT
	localparam PROCESS = 3'd4;    
	localparam DONE = 3'd5;        
	
	// ==================== ڲĴ ====================
	reg [2:0] state;               // ǰ״̬
	reg [2:0] next_state;          // һ״̬
	
	reg [10:0] baud_cnt;           // ʼ
	reg [3:0] bit_cnt;             // ؼ0-7 ʾ 8 λ
	reg [31:0] shift_reg;          // λĴյݣ
	
	reg [7:0] byte_cnt;            // ֽڼ0-7 ʾ 8 ֽڣ
	reg [31:0] addr_buf;           // ַ壨4 ֽڣ
	reg [31:0] data_buf;           // ݻ壨4 ֽڣ
	
	reg rx_sync;                   // RX ֹ̬ͬ
	reg rx_d1, rx_d2, rx_d3;       // RX ӳ٣ͬͱؼ⣩
	
	// ==================== ֵ ====================
	assign upg_clk_o = upg_clk_i;  // ʱֱͨ
	
	// ==================== RX ͬCDC - Clock Domain Crossing ====================
	always @(posedge upg_clk_i) begin
		if (upg_rst_i == 1'b1) begin
			rx_d1 <= 1'b1;
			rx_d2 <= 1'b1;
			rx_d3 <= 1'b1;
			rx_sync <= 1'b1;
		end
		else begin
			rx_d1 <= upg_rx_i;
			rx_d2 <= rx_d1;
			rx_d3 <= rx_d2;
			rx_sync <= rx_d3;
		end
	end
	
	// ==================== ״̬ʱ߼ ====================
	always @(posedge upg_clk_i) begin
		if (upg_rst_i == 1'b1) begin
			// === λмĴ ===
			state <= IDLE;
			baud_cnt <= 11'd0;
			bit_cnt <= 4'd0;
			shift_reg <= 32'd0;
			byte_cnt <= 8'd0;
			addr_buf <= 32'd0;
			data_buf <= 32'd0;
			
			upg_wen_o <= 1'b0;
			upg_done_o <= 1'b0;
			upg_adr_o <= 15'd0;
			upg_dat_o <= 32'd0;
			upg_tx_o <= 1'b1;
		end
		else begin
			state <= next_state;
			
			// ״̬߼ always @(*) 
		end
	end
	
	// ==================== ״̬߼ ====================
	always @(*) begin
		next_state = state;
		
		case (state)
			// ===== IDLE: ȴ START BIT =====
			IDLE: begin
				upg_wen_o = 1'b0;
				upg_done_o = 1'b0;
				upg_tx_o = 1'b1;
				
				//  RX ½أSTART BIT
				if (rx_sync == 1'b0) begin
					next_state = START;
				end
			end
			
			// ===== START: ֤ START BIT =====
			START: begin
				// ʼ
				if (baud_cnt == BAUD_CNT - 1) begin
					//  START BIT м
					if (rx_sync == 1'b0) begin
						// START BIT ȷ
						next_state = DATA;
					end
					else begin
						// ٵ START BITص IDLE
						next_state = IDLE;
					end
				end
			end
			
			// ===== DATA:  8 λ =====
			DATA: begin
				// ʼ
				if (baud_cnt == BAUD_CNT - 1) begin
					// λ
					if (bit_cnt == 4'd7) begin
						//  8 λ
						next_state = STOP;
					end
				end
			end
			
			// ===== STOP: ֤ STOP BIT =====
			STOP: begin
				// ʼ
				if (baud_cnt == BAUD_CNT - 1) begin
					if (rx_sync == 1'b1) begin
						// STOP BIT ȷ
						next_state = PROCESS;
					end
					else begin
						// STOP BIT 󣬻ص IDLE
						next_state = IDLE;
					end
				end
			end
			
			// ===== PROCESS: յ =====
			PROCESS: begin
				if (byte_cnt == 8'd7) begin
					//  8 ֽڣ4 ֽڵַ + 4 ֽݣ
					next_state = DONE;
				end
				else begin
					// ȴһֽ
					next_state = IDLE;
				end
			end
			
			// ===== DONE: ɣ RAM дź =====
			DONE: begin
				upg_wen_o = 1'b1;      //  RAM д
				upg_done_o = 1'b1;
				upg_adr_o = addr_buf[14:0];
				upg_dat_o = data_buf;
				
				next_state = IDLE;     //  IDLE ȴһ֡
			end
			
			default: begin
				next_state = IDLE;
			end
		endcase
	end
	
	// ==================== ʼ߼ ====================
	always @(posedge upg_clk_i) begin
		if (upg_rst_i == 1'b1) begin
			baud_cnt <= 11'd0;
		end
		else begin
			case (state)
				START, DATA, STOP: begin
					// Щ״̬¼
					if (baud_cnt == BAUD_CNT - 1) begin
						baud_cnt <= 11'd0;
					end
					else begin
						baud_cnt <= baud_cnt + 11'd1;
					end
				end
				
				default: begin
					// ״̬
					baud_cnt <= 11'd0;
				end
			endcase
		end
	end
	
	// ==================== ؼ߼ ====================
	always @(posedge upg_clk_i) begin
		if (upg_rst_i == 1'b1) begin
			bit_cnt <= 4'd0;
		end
		else if (state == DATA && baud_cnt == BAUD_CNT - 1) begin
			if (bit_cnt == 4'd7) begin
				bit_cnt <= 4'd0;       // λؼ
			end
			else begin
				bit_cnt <= bit_cnt + 4'd1;
			end
		end
		else if (state == IDLE || state == START) begin
			bit_cnt <= 4'd0;
		end
	end
	
	// ==================== ݽ߼ ====================
	always @(posedge upg_clk_i) begin
		if (upg_rst_i == 1'b1) begin
			shift_reg <= 32'd0;
		end
		else if (state == DATA && baud_cnt == BAUD_CNT - 1) begin
			// λмLSB Ƚ
			shift_reg[bit_cnt] <= rx_sync;
		end
	end
	
	// ==================== ֽڼݻ߼ ====================
	always @(posedge upg_clk_i) begin
		if (upg_rst_i == 1'b1) begin
			byte_cnt <= 8'd0;
			addr_buf <= 32'd0;
			data_buf <= 32'd0;
		end
		else if (state == STOP && baud_cnt == BAUD_CNT - 1 && rx_sync == 1'b1) begin
			// STOP BIT ȷյֽ
			byte_cnt <= byte_cnt + 8'd1;
			
			if (byte_cnt < 8'd4) begin
				
				addr_buf <= {shift_reg[7:0], addr_buf[31:8]};
			end
			else begin
				
				data_buf <= {shift_reg[7:0], data_buf[31:8]};
			end
		end
		else if (state == IDLE && next_state == IDLE && byte_cnt == 8'd8) begin
			
			byte_cnt <= 8'd0;
		end
	end

endmodule
