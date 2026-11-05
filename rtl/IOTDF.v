`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;

reg busy_r, busy_w;
assign busy = busy_r;
reg valid_r, valid_w;
assign valid = valid_r;

reg [127:0] iot_out_r, iot_out_w;
assign iot_out = iot_out_r;

reg [127:0] input_data_w [0:1], input_data_r [0:1];
reg load_select_w, load_select_r;
reg [15:0] counter_w, counter_r;

reg [63:0] des_plain_text_w, des_plain_text_r;
reg [63:0] des_main_key_w, des_main_key_r;
reg [63:0] des_cipher_text;
reg des_mode_w, des_mode_r;

wire [127:0] sorted_data;

reg [10:0]crc8_input;
reg [1:0] en;
wire [2:0]crc_out;
wire [7:0] sort_in;
assign sort_in = (fn_sel == 3'b100) ? iot_in : 8'd0;


always @(*) begin
    counter_w = counter_r;
    load_select_w = load_select_r;
    des_plain_text_w = des_plain_text_r;
    des_main_key_w = des_main_key_r;
    des_mode_w = des_mode_r;
    busy_w = busy_r;
    valid_w = valid_r;
    iot_out_w = iot_out_r;
    input_data_w[0] = input_data_r[0];
    input_data_w[1] = input_data_r[1];
    crc8_input = 11'd0;
    en = 2'b00;
    case(fn_sel)
        3'b001: begin
            en[0] = 1'b1;
            // function 1: des encryption
            des_mode_w = 1'b0; // encryption mode
            iot_out_w = {des_main_key_r, des_cipher_text};
            if(in_en) begin
                counter_w = counter_r + 1;
                if(load_select_r)begin
                    input_data_w[0] = {iot_in, input_data_r[0][127:8]};
                    des_plain_text_w = input_data_r[1][63:0];
                    des_main_key_w = input_data_r[1][127:64];
                end else begin
                    input_data_w[1] = {iot_in, input_data_r[1][127:8]};
                    des_plain_text_w = input_data_r[0][63:0];
                    des_main_key_w = input_data_r[0][127:64];
                end
                if(counter_r[3:0] == 15) begin
                    load_select_w = ~load_select_r;
                end
            end
            if(counter_r > 16 && counter_r[3:0] == 0) begin
                valid_w = 1'b1;
            end else begin
                valid_w = 1'b0;
            end
        end
        3'b010: begin
            // function 2
            // function 1: des encryption
            en[0] = 1'b1;
            des_mode_w = 1'b1; // encryption mode
            iot_out_w = {des_main_key_r, des_cipher_text};
            if(in_en) begin
                counter_w = counter_r + 1;
                if(load_select_r)begin
                    input_data_w[0] = {iot_in, input_data_r[0][127:8]};
                    des_plain_text_w = input_data_r[1][63:0];
                    des_main_key_w = input_data_r[1][127:64];
                end else begin
                    input_data_w[1] = {iot_in, input_data_r[1][127:8]};
                    des_plain_text_w = input_data_r[0][63:0];
                    des_main_key_w = input_data_r[0][127:64];
                end
                if(counter_r[3:0] == 15) begin
                    load_select_w = ~load_select_r;
                end
            end
            if(counter_r > 16 && counter_r[3:0] == 0) begin
                valid_w = 1'b1;
            end else begin
                valid_w = 1'b0;
            end
        end
        3'b011: begin
            // function 3: crc checksum
            iot_out_w = crc_out;
            if(in_en) begin
                counter_w = counter_r + 1;
                if(load_select_r)begin
                    input_data_w[0] = {iot_in, input_data_r[0][127:8]};
                    crc8_input = input_data_r[1][127:117];
                    input_data_w[1] = {crc_out, input_data_r[1][116:0], 8'd0};
                end else begin
                    input_data_w[1] = {iot_in, input_data_r[1][127:8]};
                    crc8_input = input_data_r[0][127:117];
                    input_data_w[0] = {crc_out, input_data_r[0][116:0], 8'd0};
                end
                if(counter_r[3:0] == 15) begin
                    load_select_w = ~load_select_r;
                end
            end
            if(counter_r > 16 && counter_r[3:0] == 4'd15) begin
                valid_w = 1'b1;
            end else begin
                valid_w = 1'b0;
            end
        end
        default: begin
            // function 4: sorting
            en[1] = 1'b1;
            iot_out_w = sorted_data;
            if(in_en) begin
                counter_w = counter_r + 1;
            end
            if(counter_r[3:0] == 4'd15) begin
                valid_w = 1'b1;
            end else begin
                valid_w = 1'b0;
            end
        end
    endcase
end

des u_des(
    .clk(clk),
    .rst(rst),
    .en(en[0]),
    .plain_text(des_plain_text_r),
    .main_key(des_main_key_r),
    .mode(des_mode_r),
    .round(counter_r[3:0]),
    .cipher_text(des_cipher_text)
);

insertion_sort u_insertion_sort (
    .clk(clk),
    .rst(rst),
    .in_en(in_en),
    .en(en[1]),
    .round(counter_r[3:0]),
    .in(sort_in),
    .out(sorted_data)
);

crc8 u_crc8(
    .data_in(crc8_input),
    .crc_out(crc_out)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // reset logic
        des_plain_text_r <= 0;
        des_main_key_r <= 0;
        des_mode_r <= 0;
        counter_r <= 0;
        load_select_r <= 0;
        busy_r <= 0;
        valid_r <= 0;
        iot_out_r <= 0;
        input_data_r[0] <= 0;
        input_data_r[1] <= 0;
    end else begin
        // sequential logic
        if(in_en) begin
            des_plain_text_r <= des_plain_text_w;
            des_main_key_r <= des_main_key_w;
            des_mode_r <= des_mode_w;
            counter_r <= counter_w;
            load_select_r <= load_select_w;
            busy_r <= busy_w;
            valid_r <= valid_w;
            iot_out_r <= iot_out_w;
            input_data_r[0] <= input_data_w[0];
            input_data_r[1] <= input_data_w[1];
        end
    end
end

endmodule

module crc8(
    input [10:0] data_in,
    output [2:0] crc_out
);

    parameter polynomial = 4'b1101; // x^4 + x + 1

    reg [3:0] crc [0:7];

    assign crc_out = crc[7][2:0];

    always @(*) begin
        if(data_in[10]) begin
            crc[0] = {data_in[10:7] ^ polynomial, data_in[6]};
        end else begin
            crc[0] = {data_in[10:7], data_in[6]};
        end
        if(crc[0][3]) begin
                crc[1] = {crc[0] ^ polynomial, data_in[5]};
        end else begin
                crc[1] = {crc[0], data_in[5]};
        end
        if(crc[1][3]) begin
            crc[2] = {crc[1] ^ polynomial, data_in[4]};
        end else begin
            crc[2] = {crc[1], data_in[4]};
        end
        if(crc[2][3]) begin
            crc[3] = {crc[2] ^ polynomial, data_in[3]};
        end else begin
            crc[3] = {crc[2], data_in[3]};
        end
        if(crc[3][3]) begin
            crc[4] = {crc[3] ^ polynomial, data_in[2]};
        end else begin
            crc[4] = {crc[3], data_in[2]};
        end
        if(crc[4][3]) begin
            crc[5] = {crc[4] ^ polynomial, data_in[1]};
        end else begin
            crc[5] = {crc[4], data_in[1]};
        end
        if(crc[5][3]) begin
            crc[6] = {crc[5] ^ polynomial, data_in[0]};
        end else begin
            crc[6] = {crc[5], data_in[0]};
        end
        if(crc[6][3]) begin
            crc[7] = crc[6] ^ polynomial;
        end else begin
            crc[7] = crc[6];
        end
    end

endmodule

module sort2(
    input [7:0] in0,
    input [7:0] in1,
    output [7:0] min,
    output [7:0] max
);
    assign {min, max} = (in0 < in1) ? {in0, in1} : {in1, in0};
endmodule

module insertion_sort(
    input clk,
    input rst,
    input en,
    input in_en,
    input [3:0] round,
    input [7:0] in,
    output [127:0] out
);

    // registers to store current order
    reg [7:0] sorted_w [0:15], sorted_r [0:15];
    wire [7:0] sorted [0:15];
    wire [7:0] min_wire [0:16];

    assign min_wire[0] = in;

    assign out = {sorted[0], sorted[1], sorted[2], sorted[3],
                  sorted[4], sorted[5], sorted[6],  sorted[7],
                  sorted[8],  sorted[9],  sorted[10],  sorted[11],
                  sorted[12],  sorted[13],  sorted[14],  sorted[15]};

    //generate 16 sort2 modules for insertion sort
    genvar g;
    generate
        for(g = 0; g < 16; g = g + 1) begin : SORT2_GEN
            sort2 u_sort2 (
                .in0(min_wire[g]),
                .in1(sorted_r[g]),
                .min(min_wire[g+1]),
                .max(sorted[g])
            );
        end
    endgenerate

    //combinational circuit
    integer i;
    always @(*)begin
        if(in_en) begin
            for(i = 0; i < 16; i = i + 1) begin
                sorted_w[i] = sorted[i];
            end
            if(round == 4'd15) begin
                for(i = 0; i < 16; i = i + 1) begin
                    sorted_w[i] = 0;
                end
            end
        end else begin
            for(i = 0; i < 16; i = i + 1) begin
                sorted_w[i] = sorted_r[i];
            end
        end
        
    end

    //initial value of sorter should be small => all 0s
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            for(i = 0; i < 16; i = i + 1) begin
                sorted_r[i] <= 0;
            end
        end else begin
            if(en) begin
                for(i = 0; i < 16; i = i + 1) begin
                    sorted_r[i] <= sorted_w[i];
                end
            end
        end
    end

endmodule

module des_initial_permutation (
    input  wire [63:0] in_ip,
    output wire [63:0] out_ip
);

    assign out_ip[63] = in_ip[6];
    assign out_ip[62] = in_ip[14];
    assign out_ip[61] = in_ip[22];
    assign out_ip[60] = in_ip[30];
    assign out_ip[59] = in_ip[38];
    assign out_ip[58] = in_ip[46];
    assign out_ip[57] = in_ip[54];
    assign out_ip[56] = in_ip[62];

    assign out_ip[55] = in_ip[4];
    assign out_ip[54] = in_ip[12];
    assign out_ip[53] = in_ip[20];
    assign out_ip[52] = in_ip[28];
    assign out_ip[51] = in_ip[36];
    assign out_ip[50] = in_ip[44];
    assign out_ip[49] = in_ip[52];
    assign out_ip[48] = in_ip[60];

    assign out_ip[47] = in_ip[2];
    assign out_ip[46] = in_ip[10];
    assign out_ip[45] = in_ip[18];
    assign out_ip[44] = in_ip[26];
    assign out_ip[43] = in_ip[34];
    assign out_ip[42] = in_ip[42];
    assign out_ip[41] = in_ip[50];
    assign out_ip[40] = in_ip[58];

    assign out_ip[39] = in_ip[0];
    assign out_ip[38] = in_ip[8];
    assign out_ip[37] = in_ip[16];
    assign out_ip[36] = in_ip[24];
    assign out_ip[35] = in_ip[32];
    assign out_ip[34] = in_ip[40];
    assign out_ip[33] = in_ip[48];
    assign out_ip[32] = in_ip[56];

    assign out_ip[31] = in_ip[7];
    assign out_ip[30] = in_ip[15];
    assign out_ip[29] = in_ip[23];
    assign out_ip[28] = in_ip[31];
    assign out_ip[27] = in_ip[39];
    assign out_ip[26] = in_ip[47];
    assign out_ip[25] = in_ip[55];
    assign out_ip[24] = in_ip[63];

    assign out_ip[23] = in_ip[5];
    assign out_ip[22] = in_ip[13];
    assign out_ip[21] = in_ip[21];
    assign out_ip[20] = in_ip[29];
    assign out_ip[19] = in_ip[37];
    assign out_ip[18] = in_ip[45];
    assign out_ip[17] = in_ip[53];
    assign out_ip[16] = in_ip[61];

    assign out_ip[15] = in_ip[3];
    assign out_ip[14] = in_ip[11];
    assign out_ip[13] = in_ip[19];
    assign out_ip[12] = in_ip[27];
    assign out_ip[11] = in_ip[35];
    assign out_ip[10] = in_ip[43];
    assign out_ip[9]  = in_ip[51];
    assign out_ip[8]  = in_ip[59];

    assign out_ip[7]  = in_ip[1];
    assign out_ip[6]  = in_ip[9];
    assign out_ip[5]  = in_ip[17];
    assign out_ip[4]  = in_ip[25];
    assign out_ip[3]  = in_ip[33];
    assign out_ip[2]  = in_ip[41];
    assign out_ip[1]  = in_ip[49];
    assign out_ip[0]  = in_ip[57];

endmodule

module des_final_permutation (
    input  wire [63:0] in_fp,
    output wire [63:0] out_fp
);

    assign out_fp[63] = in_fp[24];
    assign out_fp[62] = in_fp[56];
    assign out_fp[61] = in_fp[16];
    assign out_fp[60] = in_fp[48];
    assign out_fp[59] = in_fp[8];
    assign out_fp[58] = in_fp[40];
    assign out_fp[57] = in_fp[0];
    assign out_fp[56] = in_fp[32];

    assign out_fp[55] = in_fp[25];
    assign out_fp[54] = in_fp[57];
    assign out_fp[53] = in_fp[17];
    assign out_fp[52] = in_fp[49];
    assign out_fp[51] = in_fp[9];
    assign out_fp[50] = in_fp[41];
    assign out_fp[49] = in_fp[1];
    assign out_fp[48] = in_fp[33];

    assign out_fp[47] = in_fp[26];
    assign out_fp[46] = in_fp[58];
    assign out_fp[45] = in_fp[18];
    assign out_fp[44] = in_fp[50];
    assign out_fp[43] = in_fp[10];
    assign out_fp[42] = in_fp[42];
    assign out_fp[41] = in_fp[2];
    assign out_fp[40] = in_fp[34];

    assign out_fp[39] = in_fp[27];
    assign out_fp[38] = in_fp[59];
    assign out_fp[37] = in_fp[19];
    assign out_fp[36] = in_fp[51];
    assign out_fp[35] = in_fp[11];
    assign out_fp[34] = in_fp[43];
    assign out_fp[33] = in_fp[3];
    assign out_fp[32] = in_fp[35];

    assign out_fp[31] = in_fp[28];
    assign out_fp[30] = in_fp[60];
    assign out_fp[29] = in_fp[20];
    assign out_fp[28] = in_fp[52];
    assign out_fp[27] = in_fp[12];
    assign out_fp[26] = in_fp[44];
    assign out_fp[25] = in_fp[4];
    assign out_fp[24] = in_fp[36];

    assign out_fp[23] = in_fp[29];
    assign out_fp[22] = in_fp[61];
    assign out_fp[21] = in_fp[21];
    assign out_fp[20] = in_fp[53];
    assign out_fp[19] = in_fp[13];
    assign out_fp[18] = in_fp[45];
    assign out_fp[17] = in_fp[5];
    assign out_fp[16] = in_fp[37];

    assign out_fp[15] = in_fp[30];
    assign out_fp[14] = in_fp[62];
    assign out_fp[13] = in_fp[22];
    assign out_fp[12] = in_fp[54];
    assign out_fp[11] = in_fp[14];
    assign out_fp[10] = in_fp[46];
    assign out_fp[9]  = in_fp[6];
    assign out_fp[8]  = in_fp[38];

    assign out_fp[7]  = in_fp[31];
    assign out_fp[6]  = in_fp[63];
    assign out_fp[5]  = in_fp[23];
    assign out_fp[4]  = in_fp[55];
    assign out_fp[3]  = in_fp[15];
    assign out_fp[2]  = in_fp[47];
    assign out_fp[1]  = in_fp[7];
    assign out_fp[0]  = in_fp[39];

endmodule

module des_pc1 (
    input  [63:0] key_in,
    output [55:0] key_out
);

    // Row 1 of PC-1
    assign key_out[55] = key_in[7];   // 57
    assign key_out[54] = key_in[15];  // 49
    assign key_out[53] = key_in[23];  // 41
    assign key_out[52] = key_in[31];  // 33
    assign key_out[51] = key_in[39];  // 25
    assign key_out[50] = key_in[47];  // 17
    assign key_out[49] = key_in[55];  //  9

    // Row 2 of PC-1
    assign key_out[48] = key_in[63];  //  1
    assign key_out[47] = key_in[6];   // 58
    assign key_out[46] = key_in[14];  // 50
    assign key_out[45] = key_in[22];  // 42
    assign key_out[44] = key_in[30];  // 34
    assign key_out[43] = key_in[38];  // 26
    assign key_out[42] = key_in[46];  // 18

    // Row 3 of PC-1
    assign key_out[41] = key_in[54];  // 10
    assign key_out[40] = key_in[62];  //  2
    assign key_out[39] = key_in[5];   // 59
    assign key_out[38] = key_in[13];  // 51
    assign key_out[37] = key_in[21];  // 43
    assign key_out[36] = key_in[29];  // 35
    assign key_out[35] = key_in[37];  // 27

    // Row 4 of PC-1
    assign key_out[34] = key_in[45];  // 19
    assign key_out[33] = key_in[53];  // 11
    assign key_out[32] = key_in[61];  //  3
    assign key_out[31] = key_in[4];   // 60
    assign key_out[30] = key_in[12];  // 52
    assign key_out[29] = key_in[20];  // 44
    assign key_out[28] = key_in[28];  // 36

    // Row 5 of PC-1
    assign key_out[27] = key_in[1];   // 63
    assign key_out[26] = key_in[9];   // 55
    assign key_out[25] = key_in[17];  // 47
    assign key_out[24] = key_in[25];  // 39
    assign key_out[23] = key_in[33];  // 31
    assign key_out[22] = key_in[41];  // 23
    assign key_out[21] = key_in[49];  // 15

    // Row 6 of PC-1
    assign key_out[20] = key_in[57];  //  7
    assign key_out[19] = key_in[2];   // 62
    assign key_out[18] = key_in[10];  // 54
    assign key_out[17] = key_in[18];  // 46
    assign key_out[16] = key_in[26];  // 38
    assign key_out[15] = key_in[34];  // 30
    assign key_out[14] = key_in[42];  // 22

    // Row 7 of PC-1
    assign key_out[13] = key_in[50];  // 14
    assign key_out[12] = key_in[58];  //  6
    assign key_out[11] = key_in[3];   // 61
    assign key_out[10] = key_in[11];  // 53
    assign key_out[9]  = key_in[19];  // 45
    assign key_out[8]  = key_in[27];  // 37
    assign key_out[7]  = key_in[35];  // 29

    // Row 8 of PC-1
    assign key_out[6]  = key_in[43];  // 21
    assign key_out[5]  = key_in[51];  // 13
    assign key_out[4]  = key_in[59];  //  5
    assign key_out[3]  = key_in[36];  // 28
    assign key_out[2]  = key_in[44];  // 20
    assign key_out[1]  = key_in[52];  // 12
    assign key_out[0]  = key_in[60];  //  4

endmodule

module des_pc2 (
    input  [55:0] key_in,
    output [47:0] subkey_out
);

    // Row 1
    assign subkey_out[47] = key_in[42]; // pos 14
    assign subkey_out[46] = key_in[39]; // pos 17
    assign subkey_out[45] = key_in[45]; // pos 11
    assign subkey_out[44] = key_in[32]; // pos 24
    assign subkey_out[43] = key_in[55]; // pos 1
    assign subkey_out[42] = key_in[51]; // pos 5

    // Row 2
    assign subkey_out[41] = key_in[53]; // pos 3
    assign subkey_out[40] = key_in[28]; // pos 28
    assign subkey_out[39] = key_in[41]; // pos 15
    assign subkey_out[38] = key_in[50]; // pos 6
    assign subkey_out[37] = key_in[35]; // pos 21
    assign subkey_out[36] = key_in[46]; // pos 10

    // Row 3
    assign subkey_out[35] = key_in[33]; // pos 23
    assign subkey_out[34] = key_in[37]; // pos 19
    assign subkey_out[33] = key_in[44]; // pos 12
    assign subkey_out[32] = key_in[52]; // pos 4
    assign subkey_out[31] = key_in[30]; // pos 26
    assign subkey_out[30] = key_in[48]; // pos 8

    // Row 4
    assign subkey_out[29] = key_in[40]; // pos 16
    assign subkey_out[28] = key_in[49]; // pos 7
    assign subkey_out[27] = key_in[29]; // pos 27
    assign subkey_out[26] = key_in[36]; // pos 20
    assign subkey_out[25] = key_in[43]; // pos 13
    assign subkey_out[24] = key_in[54]; // pos 2

    // Row 5
    assign subkey_out[23] = key_in[15]; // pos 41
    assign subkey_out[22] = key_in[4];  // pos 52
    assign subkey_out[21] = key_in[25]; // pos 31
    assign subkey_out[20] = key_in[19]; // pos 37
    assign subkey_out[19] = key_in[9];  // pos 47
    assign subkey_out[18] = key_in[1];  // pos 55

    // Row 6
    assign subkey_out[17] = key_in[26]; // pos 30
    assign subkey_out[16] = key_in[16]; // pos 40
    assign subkey_out[15] = key_in[5];  // pos 51
    assign subkey_out[14] = key_in[11]; // pos 45
    assign subkey_out[13] = key_in[23]; // pos 33
    assign subkey_out[12] = key_in[8];  // pos 48

    // Row 7
    assign subkey_out[11] = key_in[12]; // pos 44
    assign subkey_out[10] = key_in[7];  // pos 49
    assign subkey_out[9]  = key_in[17]; // pos 39
    assign subkey_out[8]  = key_in[0];  // pos 56
    assign subkey_out[7]  = key_in[22]; // pos 34
    assign subkey_out[6]  = key_in[3];  // pos 53

    // Row 8
    assign subkey_out[5]  = key_in[10]; // pos 46
    assign subkey_out[4]  = key_in[14]; // pos 42
    assign subkey_out[3]  = key_in[6];  // pos 50
    assign subkey_out[2]  = key_in[20]; // pos 36
    assign subkey_out[1]  = key_in[27]; // pos 29
    assign subkey_out[0]  = key_in[24]; // pos 32

endmodule

module sbox1(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd14;
                    4'd1:  out = 4'd4;
                    4'd2:  out = 4'd13;
                    4'd3:  out = 4'd1;
                    4'd4:  out = 4'd2;
                    4'd5:  out = 4'd15;
                    4'd6:  out = 4'd11;
                    4'd7:  out = 4'd8;
                    4'd8:  out = 4'd3;
                    4'd9:  out = 4'd10;
                    4'd10: out = 4'd6;
                    4'd11: out = 4'd12;
                    4'd12: out = 4'd5;
                    4'd13: out = 4'd9;
                    4'd14: out = 4'd0;
                    4'd15: out = 4'd7;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd0;
                    4'd1:  out = 4'd15;
                    4'd2:  out = 4'd7;
                    4'd3:  out = 4'd4;
                    4'd4:  out = 4'd14;
                    4'd5:  out = 4'd2;
                    4'd6:  out = 4'd13;
                    4'd7:  out = 4'd1;
                    4'd8:  out = 4'd10;
                    4'd9:  out = 4'd6;
                    4'd10: out = 4'd12;
                    4'd11: out = 4'd11;
                    4'd12: out = 4'd9;
                    4'd13: out = 4'd5;
                    4'd14: out = 4'd3;
                    4'd15: out = 4'd8;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd4;
                    4'd1:  out = 4'd1;
                    4'd2:  out = 4'd14;
                    4'd3:  out = 4'd8;
                    4'd4:  out = 4'd13;
                    4'd5:  out = 4'd6;
                    4'd6:  out = 4'd2;
                    4'd7:  out = 4'd11;
                    4'd8:  out = 4'd15;
                    4'd9:  out = 4'd12;
                    4'd10: out = 4'd9;
                    4'd11: out = 4'd7;
                    4'd12: out = 4'd3;
                    4'd13: out = 4'd10;
                    4'd14: out = 4'd5;
                    4'd15: out = 4'd0;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd15;
                    4'd1:  out = 4'd12;
                    4'd2:  out = 4'd8;
                    4'd3:  out = 4'd2;
                    4'd4:  out = 4'd4;
                    4'd5:  out = 4'd9;
                    4'd6:  out = 4'd1;
                    4'd7:  out = 4'd7;
                    4'd8:  out = 4'd5;
                    4'd9:  out = 4'd11;
                    4'd10: out = 4'd3;
                    4'd11: out = 4'd14;
                    4'd12: out = 4'd10;
                    4'd13: out = 4'd0;
                    4'd14: out = 4'd6;
                    4'd15: out = 4'd13;
                endcase
            end
        endcase
    end
endmodule

module sbox2(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd15;
                    4'd1:  out = 4'd1;
                    4'd2:  out = 4'd8;
                    4'd3:  out = 4'd14;
                    4'd4:  out = 4'd6;
                    4'd5:  out = 4'd11;
                    4'd6:  out = 4'd3;
                    4'd7:  out = 4'd4;
                    4'd8:  out = 4'd9;
                    4'd9:  out = 4'd7;
                    4'd10: out = 4'd2;
                    4'd11: out = 4'd13;
                    4'd12: out = 4'd12;
                    4'd13: out = 4'd0;
                    4'd14: out = 4'd5;
                    4'd15: out = 4'd10;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd3;
                    4'd1:  out = 4'd13;
                    4'd2:  out = 4'd4;
                    4'd3:  out = 4'd7;
                    4'd4:  out = 4'd15;
                    4'd5:  out = 4'd2;
                    4'd6:  out = 4'd8;
                    4'd7:  out = 4'd14;
                    4'd8:  out = 4'd12;
                    4'd9:  out = 4'd0;
                    4'd10: out = 4'd1;
                    4'd11: out = 4'd10;
                    4'd12: out = 4'd6;
                    4'd13: out = 4'd9;
                    4'd14: out = 4'd11;
                    4'd15: out = 4'd5;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd0;
                    4'd1:  out = 4'd14;
                    4'd2:  out = 4'd7;
                    4'd3:  out = 4'd11;
                    4'd4:  out = 4'd10;
                    4'd5:  out = 4'd4;
                    4'd6:  out = 4'd13;
                    4'd7:  out = 4'd1;
                    4'd8:  out = 4'd5;
                    4'd9:  out = 4'd8;
                    4'd10: out = 4'd12;
                    4'd11: out = 4'd6;
                    4'd12: out = 4'd9;
                    4'd13: out = 4'd3;
                    4'd14: out = 4'd2;
                    4'd15: out = 4'd15;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd13;
                    4'd1:  out = 4'd8;
                    4'd2:  out = 4'd10;
                    4'd3:  out = 4'd1;
                    4'd4:  out = 4'd3;
                    4'd5:  out = 4'd15;
                    4'd6:  out = 4'd4;
                    4'd7:  out = 4'd2;
                    4'd8:  out = 4'd11;
                    4'd9:  out = 4'd6;
                    4'd10: out = 4'd7;
                    4'd11: out = 4'd12;
                    4'd12: out = 4'd0;
                    4'd13: out = 4'd5;
                    4'd14: out = 4'd14;
                    4'd15: out = 4'd9;
                endcase
            end
        endcase
    end
endmodule

module sbox3(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd10;
                    4'd1:  out = 4'd0;
                    4'd2:  out = 4'd9;
                    4'd3:  out = 4'd14;
                    4'd4:  out = 4'd6;
                    4'd5:  out = 4'd3;
                    4'd6:  out = 4'd15;
                    4'd7:  out = 4'd5;
                    4'd8:  out = 4'd1;
                    4'd9:  out = 4'd13;
                    4'd10: out = 4'd12;
                    4'd11: out = 4'd7;
                    4'd12: out = 4'd11;
                    4'd13: out = 4'd4;
                    4'd14: out = 4'd2;
                    4'd15: out = 4'd8;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd13;
                    4'd1:  out = 4'd7;
                    4'd2:  out = 4'd0;
                    4'd3:  out = 4'd9;
                    4'd4:  out = 4'd3;
                    4'd5:  out = 4'd4;
                    4'd6:  out = 4'd6;
                    4'd7:  out = 4'd10;
                    4'd8:  out = 4'd2;
                    4'd9:  out = 4'd8;
                    4'd10: out = 4'd5;
                    4'd11: out = 4'd14;
                    4'd12: out = 4'd12;
                    4'd13: out = 4'd11;
                    4'd14: out = 4'd15;
                    4'd15: out = 4'd1;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd13;
                    4'd1:  out = 4'd6;
                    4'd2:  out = 4'd4;
                    4'd3:  out = 4'd9;
                    4'd4:  out = 4'd8;
                    4'd5:  out = 4'd15;
                    4'd6:  out = 4'd3;
                    4'd7:  out = 4'd0;
                    4'd8:  out = 4'd11;
                    4'd9:  out = 4'd1;
                    4'd10: out = 4'd2;
                    4'd11: out = 4'd12;
                    4'd12: out = 4'd5;
                    4'd13: out = 4'd10;
                    4'd14: out = 4'd14;
                    4'd15: out = 4'd7;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd1;
                    4'd1:  out = 4'd10;
                    4'd2:  out = 4'd13;
                    4'd3:  out = 4'd0;
                    4'd4:  out = 4'd6;
                    4'd5:  out = 4'd9;
                    4'd6:  out = 4'd8;
                    4'd7:  out = 4'd7;
                    4'd8:  out = 4'd4;
                    4'd9:  out = 4'd15;
                    4'd10: out = 4'd14;
                    4'd11: out = 4'd3;
                    4'd12: out = 4'd11;
                    4'd13: out = 4'd5;
                    4'd14: out = 4'd2;
                    4'd15: out = 4'd12;
                endcase
            end
        endcase
    end
endmodule

module sbox4(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd7;
                    4'd1:  out = 4'd13;
                    4'd2:  out = 4'd14;
                    4'd3:  out = 4'd3;
                    4'd4:  out = 4'd0;
                    4'd5:  out = 4'd6;
                    4'd6:  out = 4'd9;
                    4'd7:  out = 4'd10;
                    4'd8:  out = 4'd1;
                    4'd9:  out = 4'd2;
                    4'd10: out = 4'd8;
                    4'd11: out = 4'd5;
                    4'd12: out = 4'd11;
                    4'd13: out = 4'd12;
                    4'd14: out = 4'd4;
                    4'd15: out = 4'd15;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd13;
                    4'd1:  out = 4'd8;
                    4'd2:  out = 4'd11;
                    4'd3:  out = 4'd5;
                    4'd4:  out = 4'd6;
                    4'd5:  out = 4'd15;
                    4'd6:  out = 4'd0;
                    4'd7:  out = 4'd3;
                    4'd8:  out = 4'd4;
                    4'd9:  out = 4'd7;
                    4'd10: out = 4'd2;
                    4'd11: out = 4'd12;
                    4'd12: out = 4'd1;
                    4'd13: out = 4'd10;
                    4'd14: out = 4'd14;
                    4'd15: out = 4'd9;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd10;
                    4'd1:  out = 4'd6;
                    4'd2:  out = 4'd9;
                    4'd3:  out = 4'd0;
                    4'd4:  out = 4'd12;
                    4'd5:  out = 4'd11;
                    4'd6:  out = 4'd7;
                    4'd7:  out = 4'd13;
                    4'd8:  out = 4'd15;
                    4'd9:  out = 4'd1;
                    4'd10: out = 4'd3;
                    4'd11: out = 4'd14;
                    4'd12: out = 4'd5;
                    4'd13: out = 4'd2;
                    4'd14: out = 4'd8;
                    4'd15: out = 4'd4;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd3;
                    4'd1:  out = 4'd15;
                    4'd2:  out = 4'd0;
                    4'd3:  out = 4'd6;
                    4'd4:  out = 4'd10;
                    4'd5:  out = 4'd1;
                    4'd6:  out = 4'd13;
                    4'd7:  out = 4'd8;
                    4'd8:  out = 4'd9;
                    4'd9:  out = 4'd4;
                    4'd10: out = 4'd5;
                    4'd11: out = 4'd11;
                    4'd12: out = 4'd12;
                    4'd13: out = 4'd7;
                    4'd14: out = 4'd2;
                    4'd15: out = 4'd14;
                endcase
            end
        endcase
    end
endmodule

module sbox5(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd2;
                    4'd1:  out = 4'd12;
                    4'd2:  out = 4'd4;
                    4'd3:  out = 4'd1;
                    4'd4:  out = 4'd7;
                    4'd5:  out = 4'd10;
                    4'd6:  out = 4'd11;
                    4'd7:  out = 4'd6;
                    4'd8:  out = 4'd8;
                    4'd9:  out = 4'd5;
                    4'd10: out = 4'd3;
                    4'd11: out = 4'd15;
                    4'd12: out = 4'd13;
                    4'd13: out = 4'd0;
                    4'd14: out = 4'd14;
                    4'd15: out = 4'd9;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd14;
                    4'd1:  out = 4'd11;
                    4'd2:  out = 4'd2;
                    4'd3:  out = 4'd12;
                    4'd4:  out = 4'd4;
                    4'd5:  out = 4'd7;
                    4'd6:  out = 4'd13;
                    4'd7:  out = 4'd1;
                    4'd8:  out = 4'd5;
                    4'd9:  out = 4'd0;
                    4'd10: out = 4'd15;
                    4'd11: out = 4'd10;
                    4'd12: out = 4'd3;
                    4'd13: out = 4'd9;
                    4'd14: out = 4'd8;
                    4'd15: out = 4'd6;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd4;
                    4'd1:  out = 4'd2;
                    4'd2:  out = 4'd1;
                    4'd3:  out = 4'd11;
                    4'd4:  out = 4'd10;
                    4'd5:  out = 4'd13;
                    4'd6:  out = 4'd7;
                    4'd7:  out = 4'd8;
                    4'd8:  out = 4'd15;
                    4'd9:  out = 4'd9;
                    4'd10: out = 4'd12;
                    4'd11: out = 4'd5;
                    4'd12: out = 4'd6;
                    4'd13: out = 4'd3;
                    4'd14: out = 4'd0;
                    4'd15: out = 4'd14;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd11;
                    4'd1:  out = 4'd8;
                    4'd2:  out = 4'd12;
                    4'd3:  out = 4'd7;
                    4'd4:  out = 4'd1;
                    4'd5:  out = 4'd14;
                    4'd6:  out = 4'd2;
                    4'd7:  out = 4'd13;
                    4'd8:  out = 4'd6;
                    4'd9:  out = 4'd15;
                    4'd10: out = 4'd0;
                    4'd11: out = 4'd9;
                    4'd12: out = 4'd10;
                    4'd13: out = 4'd4;
                    4'd14: out = 4'd5;
                    4'd15: out = 4'd3;
                endcase
            end
        endcase
    end
endmodule

module sbox6(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd12;
                    4'd1:  out = 4'd1;
                    4'd2:  out = 4'd10;
                    4'd3:  out = 4'd15;
                    4'd4:  out = 4'd9;
                    4'd5:  out = 4'd2;
                    4'd6:  out = 4'd6;
                    4'd7:  out = 4'd8;
                    4'd8:  out = 4'd0;
                    4'd9:  out = 4'd13;
                    4'd10: out = 4'd3;
                    4'd11: out = 4'd4;
                    4'd12: out = 4'd14;
                    4'd13: out = 4'd7;
                    4'd14: out = 4'd5;
                    4'd15: out = 4'd11;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd10;
                    4'd1:  out = 4'd15;
                    4'd2:  out = 4'd4;
                    4'd3:  out = 4'd2;
                    4'd4:  out = 4'd7;
                    4'd5:  out = 4'd12;
                    4'd6:  out = 4'd9;
                    4'd7:  out = 4'd5;
                    4'd8:  out = 4'd6;
                    4'd9:  out = 4'd1;
                    4'd10: out = 4'd13;
                    4'd11: out = 4'd14;
                    4'd12: out = 4'd0;
                    4'd13: out = 4'd11;
                    4'd14: out = 4'd3;
                    4'd15: out = 4'd8;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd9;
                    4'd1:  out = 4'd14;
                    4'd2:  out = 4'd15;
                    4'd3:  out = 4'd5;
                    4'd4:  out = 4'd2;
                    4'd5:  out = 4'd8;
                    4'd6:  out = 4'd12;
                    4'd7:  out = 4'd3;
                    4'd8:  out = 4'd7;
                    4'd9:  out = 4'd0;
                    4'd10: out = 4'd4;
                    4'd11: out = 4'd10;
                    4'd12: out = 4'd1;
                    4'd13: out = 4'd13;
                    4'd14: out = 4'd11;
                    4'd15: out = 4'd6;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd4;
                    4'd1:  out = 4'd3;
                    4'd2:  out = 4'd2;
                    4'd3:  out = 4'd12;
                    4'd4:  out = 4'd9;
                    4'd5:  out = 4'd5;
                    4'd6:  out = 4'd15;
                    4'd7:  out = 4'd10;
                    4'd8:  out = 4'd11;
                    4'd9:  out = 4'd14;
                    4'd10: out = 4'd1;
                    4'd11: out = 4'd7;
                    4'd12: out = 4'd6;
                    4'd13: out = 4'd0;
                    4'd14: out = 4'd8;
                    4'd15: out = 4'd13;
                endcase
            end
        endcase
    end
endmodule

module sbox7(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd4;
                    4'd1:  out = 4'd11;
                    4'd2:  out = 4'd2;
                    4'd3:  out = 4'd14;
                    4'd4:  out = 4'd15;
                    4'd5:  out = 4'd0;
                    4'd6:  out = 4'd8;
                    4'd7:  out = 4'd13;
                    4'd8:  out = 4'd3;
                    4'd9:  out = 4'd12;
                    4'd10: out = 4'd9;
                    4'd11: out = 4'd7;
                    4'd12: out = 4'd5;
                    4'd13: out = 4'd10;
                    4'd14: out = 4'd6;
                    4'd15: out = 4'd1;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd13;
                    4'd1:  out = 4'd0;
                    4'd2:  out = 4'd11;
                    4'd3:  out = 4'd7;
                    4'd4:  out = 4'd4;
                    4'd5:  out = 4'd9;
                    4'd6:  out = 4'd1;
                    4'd7:  out = 4'd10;
                    4'd8:  out = 4'd14;
                    4'd9:  out = 4'd3;
                    4'd10: out = 4'd5;
                    4'd11: out = 4'd12;
                    4'd12: out = 4'd2;
                    4'd13: out = 4'd15;
                    4'd14: out = 4'd8;
                    4'd15: out = 4'd6;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd1;
                    4'd1:  out = 4'd4;
                    4'd2:  out = 4'd11;
                    4'd3:  out = 4'd13;
                    4'd4:  out = 4'd12;
                    4'd5:  out = 4'd3;
                    4'd6:  out = 4'd7;
                    4'd7:  out = 4'd14;
                    4'd8:  out = 4'd10;
                    4'd9:  out = 4'd15;
                    4'd10: out = 4'd6;
                    4'd11: out = 4'd8;
                    4'd12: out = 4'd0;
                    4'd13: out = 4'd5;
                    4'd14: out = 4'd9;
                    4'd15: out = 4'd2;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd6;
                    4'd1:  out = 4'd11;
                    4'd2:  out = 4'd13;
                    4'd3:  out = 4'd8;
                    4'd4:  out = 4'd1;
                    4'd5:  out = 4'd4;
                    4'd6:  out = 4'd10;
                    4'd7:  out = 4'd7;
                    4'd8:  out = 4'd9;
                    4'd9:  out = 4'd5;
                    4'd10: out = 4'd0;
                    4'd11: out = 4'd15;
                    4'd12: out = 4'd14;
                    4'd13: out = 4'd2;
                    4'd14: out = 4'd3;
                    4'd15: out = 4'd12;
                endcase
            end
        endcase
    end
endmodule

module sbox8(
    input  [5:0] in,
    output reg [3:0] out
);
    wire [1:0] row = {in[5], in[0]};
    wire [3:0] col = in[4:1];

    always @* begin
        case (row)
            2'd0: begin
                case (col)
                    4'd0:  out = 4'd13;
                    4'd1:  out = 4'd2;
                    4'd2:  out = 4'd8;
                    4'd3:  out = 4'd4;
                    4'd4:  out = 4'd6;
                    4'd5:  out = 4'd15;
                    4'd6:  out = 4'd11;
                    4'd7:  out = 4'd1;
                    4'd8:  out = 4'd10;
                    4'd9:  out = 4'd9;
                    4'd10: out = 4'd3;
                    4'd11: out = 4'd14;
                    4'd12: out = 4'd5;
                    4'd13: out = 4'd0;
                    4'd14: out = 4'd12;
                    4'd15: out = 4'd7;
                endcase
            end
            2'd1: begin
                case (col)
                    4'd0:  out = 4'd1;
                    4'd1:  out = 4'd15;
                    4'd2:  out = 4'd13;
                    4'd3:  out = 4'd8;
                    4'd4:  out = 4'd10;
                    4'd5:  out = 4'd3;
                    4'd6:  out = 4'd7;
                    4'd7:  out = 4'd4;
                    4'd8:  out = 4'd12;
                    4'd9:  out = 4'd5;
                    4'd10: out = 4'd6;
                    4'd11: out = 4'd11;
                    4'd12: out = 4'd0;
                    4'd13: out = 4'd14;
                    4'd14: out = 4'd9;
                    4'd15: out = 4'd2;
                endcase
            end
            2'd2: begin
                case (col)
                    4'd0:  out = 4'd7;
                    4'd1:  out = 4'd11;
                    4'd2:  out = 4'd4;
                    4'd3:  out = 4'd1;
                    4'd4:  out = 4'd9;
                    4'd5:  out = 4'd12;
                    4'd6:  out = 4'd14;
                    4'd7:  out = 4'd2;
                    4'd8:  out = 4'd0;
                    4'd9:  out = 4'd6;
                    4'd10: out = 4'd10;
                    4'd11: out = 4'd13;
                    4'd12: out = 4'd15;
                    4'd13: out = 4'd3;
                    4'd14: out = 4'd5;
                    4'd15: out = 4'd8;
                endcase
            end
            2'd3: begin
                case (col)
                    4'd0:  out = 4'd2;
                    4'd1:  out = 4'd1;
                    4'd2:  out = 4'd14;
                    4'd3:  out = 4'd7;
                    4'd4:  out = 4'd4;
                    4'd5:  out = 4'd10;
                    4'd6:  out = 4'd8;
                    4'd7:  out = 4'd13;
                    4'd8:  out = 4'd15;
                    4'd9:  out = 4'd12;
                    4'd10: out = 4'd9;
                    4'd11: out = 4'd0;
                    4'd12: out = 4'd3;
                    4'd13: out = 4'd5;
                    4'd14: out = 4'd6;
                    4'd15: out = 4'd11;
                endcase
            end
        endcase
    end
endmodule

module des_expansion (
    input  wire [31:0] r_in,
    output wire [47:0] e_out
);

    assign e_out[47] = r_in[0];
    assign e_out[46] = r_in[31];
    assign e_out[45] = r_in[30];
    assign e_out[44] = r_in[29];
    assign e_out[43] = r_in[28];
    assign e_out[42] = r_in[27];
    assign e_out[41] = r_in[28];
    assign e_out[40] = r_in[27];
    assign e_out[39] = r_in[26];
    assign e_out[38] = r_in[25];
    assign e_out[37] = r_in[24];
    assign e_out[36] = r_in[23];
    assign e_out[35] = r_in[24];
    assign e_out[34] = r_in[23];
    assign e_out[33] = r_in[22];
    assign e_out[32] = r_in[21];
    assign e_out[31] = r_in[20];
    assign e_out[30] = r_in[19];
    assign e_out[29] = r_in[20];
    assign e_out[28] = r_in[19];
    assign e_out[27] = r_in[18];
    assign e_out[26] = r_in[17];
    assign e_out[25] = r_in[16];
    assign e_out[24] = r_in[15];
    assign e_out[23] = r_in[16];
    assign e_out[22] = r_in[15];
    assign e_out[21] = r_in[14];
    assign e_out[20] = r_in[13];
    assign e_out[19] = r_in[12];
    assign e_out[18] = r_in[11];
    assign e_out[17] = r_in[12];
    assign e_out[16] = r_in[11];
    assign e_out[15] = r_in[10];
    assign e_out[14] = r_in[9];
    assign e_out[13] = r_in[8];
    assign e_out[12] = r_in[7];
    assign e_out[11] = r_in[8];
    assign e_out[10] = r_in[7];
    assign e_out[9]  = r_in[6];
    assign e_out[8]  = r_in[5];
    assign e_out[7]  = r_in[4];
    assign e_out[6]  = r_in[3];
    assign e_out[5]  = r_in[4];
    assign e_out[4]  = r_in[3];
    assign e_out[3]  = r_in[2];
    assign e_out[2]  = r_in[1];
    assign e_out[1]  = r_in[0];
    assign e_out[0]  = r_in[31];

endmodule

module des_p_permutation (
    input  wire [31:0] in_f,
    output wire [31:0] p_out
);

    assign p_out[31] = in_f[16];
    assign p_out[30] = in_f[25];
    assign p_out[29] = in_f[12];
    assign p_out[28] = in_f[11];
    assign p_out[27] = in_f[3];
    assign p_out[26] = in_f[20];
    assign p_out[25] = in_f[4];
    assign p_out[24] = in_f[15];

    assign p_out[23] = in_f[31];
    assign p_out[22] = in_f[17];
    assign p_out[21] = in_f[9];
    assign p_out[20] = in_f[6];
    assign p_out[19] = in_f[27];
    assign p_out[18] = in_f[14];
    assign p_out[17] = in_f[1];
    assign p_out[16] = in_f[22];

    assign p_out[15] = in_f[30];
    assign p_out[14] = in_f[24];
    assign p_out[13] = in_f[8];
    assign p_out[12] = in_f[18];
    assign p_out[11] = in_f[0];
    assign p_out[10] = in_f[5];
    assign p_out[9]  = in_f[29];
    assign p_out[8]  = in_f[23];

    assign p_out[7]  = in_f[13];
    assign p_out[6]  = in_f[19];
    assign p_out[5]  = in_f[2];
    assign p_out[4]  = in_f[26];
    assign p_out[3]  = in_f[10];
    assign p_out[2]  = in_f[21];
    assign p_out[1]  = in_f[28];
    assign p_out[0]  = in_f[7];

endmodule

module des_feistel_function(
    input  [31:0] right_half,
    input  [47:0] round_key,
    output [31:0] out
);

    wire [47:0] expanded_right;
    // Implementation of the Feistel function goes here
    // This typically includes expansion, key mixing, substitution using S-boxes, and permutation
    des_expansion u_expansion(
        .r_in(right_half),
        .e_out(expanded_right) // 48 bits
    );

    wire [47:0] xor_with_key;
    assign xor_with_key = expanded_right ^ round_key;

    wire [31:0] sbox_output;

    sbox1 u_sbox1(
        .in(xor_with_key[47:42]), // 6 bits
        .out(sbox_output[31:28]) // 4 bits
    );

    sbox2 u_sbox2(
        .in(xor_with_key[41:36]),
        .out(sbox_output[27:24])
    );

    sbox3 u_sbox3(
        .in(xor_with_key[35:30]),
        .out(sbox_output[23:20])
    );

    sbox4 u_sbox4(
        .in(xor_with_key[29:24]),
        .out(sbox_output[19:16])
    );

    sbox5 u_sbox5(
        .in(xor_with_key[23:18]),
        .out(sbox_output[15:12])
    );

    sbox6 u_sbox6(
        .in(xor_with_key[17:12]),
        .out(sbox_output[11:8])
    );

    sbox7 u_sbox7(
        .in(xor_with_key[11:6]),
        .out(sbox_output[7:4])
    );

    sbox8 u_sbox8(
        .in(xor_with_key[5:0]),
        .out(sbox_output[3:0])
    );

    des_p_permutation u_p_permutation(
        .in_f(sbox_output),
        .p_out(out)
    );
endmodule

module des(
    input clk,
    input rst,
    input en,
    input [63:0] plain_text,
    input [63:0] main_key,
    input mode, // 0: encrypt, 1: decrypt
    input [3:0] round,
    output [63:0] cipher_text
);

    wire [63:0] init_permute;
    wire [55:0] cipher_key;
    reg [55:0] cipher_key_w, cipher_key_r;
    reg [27:0] left_key, right_key;
    wire [47:0] round_key;
    wire [31:0] function_out;
    reg [31:0] function_input;

    reg [63:0] cipher_text_w, cipher_text_r;

    wire [63:0]final_permutation_input;
    assign final_permutation_input = (round == 4'd0) ? cipher_text_w : 0;

    des_initial_permutation u_pi(
        .in_ip(plain_text),
        .out_ip(init_permute)
    );

    des_pc1 u_pc1(
        .key_in(main_key),
        .key_out(cipher_key)
    );

    // decide shifting order based on mode
    always @(*) begin
        cipher_key_w = cipher_key_r;
        cipher_text_w = cipher_text_r;
        if (round == 4'd1) begin
            function_input = init_permute[31:0];
            cipher_text_w = {init_permute[31:0], function_out^init_permute[63:32]};
        end else if (round == 4'd0) begin
            function_input = cipher_text_r[31:0];
            cipher_text_w = {function_out ^ cipher_text_r[63:32], cipher_text_r[31:0]};
        end else begin
            function_input = cipher_text_r[31:0];
            cipher_text_w = {cipher_text_r[31:0], function_out ^ cipher_text_r[63:32]};
        end

        case (mode)
            1'b0: begin
                // encryption shifting schedule
                // round 1,2 9,16: left shift by 1
                case (round)
                    4'd1: begin
                        // left shift by 1
                        right_key = {cipher_key[26:0], cipher_key[27]};
                        left_key = {cipher_key[54:28], cipher_key[55]};
                        cipher_key_w = {left_key, right_key};
                    end
                    4'd0, 4'd9, 4'd2: begin
                        // left shift by 1
                        right_key = {cipher_key_r[26:0], cipher_key_r[27]};
                        left_key = {cipher_key_r[54:28], cipher_key_r[55]};
                        cipher_key_w = {left_key, right_key};
                    end
                    default: begin
                        // left shift by 2
                        right_key = {cipher_key_r[25:0], cipher_key_r[27:26]};
                        left_key = {cipher_key_r[53:28], cipher_key_r[55:54]};
                        cipher_key_w = {left_key, right_key};
                    end
                endcase
            end
            1'b1: begin
                // decryption shifting schedule
                // round 17-1, 17-2, 17-9, 17-16: right shift by 1
                // => round 16,15,8,1: right shift by 1
                case (round)
                    4'd1: begin
                        cipher_key_w = cipher_key;
                    end
                    4'd2, 4'd9, 4'd0: begin
                        // right shift by 1
                        right_key = {cipher_key_r[0], cipher_key_r[27:1]};
                        left_key = {cipher_key_r[28], cipher_key_r[55:29]};
                        cipher_key_w = {left_key, right_key};
                    end
                    default: begin
                        // right shift by 2
                        right_key = {cipher_key_r[1:0], cipher_key_r[27:2]};
                        left_key = {cipher_key_r[29:28], cipher_key_r[55:30]};
                        cipher_key_w = {left_key, right_key};
                    end
                endcase
            end
        endcase
    end

    des_pc2 u_pc2(
        .key_in(cipher_key_w),
        .subkey_out(round_key)
    );

    des_feistel_function u_feistel(
        .right_half(function_input),
        .round_key(round_key),
        .out(function_out)
    );

    des_final_permutation u_final_permutation(
        .in_fp(final_permutation_input),
        .out_fp(cipher_text)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cipher_key_r <= 0;
            cipher_text_r <= 0;
        end else begin
            if (en) begin
                cipher_key_r <= cipher_key_w;
                cipher_text_r <= cipher_text_w;
            end
        end
    end
endmodule