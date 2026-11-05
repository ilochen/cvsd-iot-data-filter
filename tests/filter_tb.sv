`timescale 1ns/1ps
module filter_tb;
    logic clk=0,rst=0,in_en=0;
    logic [7:0] iot_in=0;
    logic [2:0] fn_sel;
    wire busy,valid;
    wire [127:0] iot_out;
    IOTDF dut(.*);
    always #6 clk = ~clk;
    logic [127:0] patterns[64],answers[64];
    integer fn, suite, sent=0, received=0;
    initial begin
        if (!$value$plusargs("fn=%d",fn) || !$value$plusargs("suite=%d",suite)) $fatal;
        fn_sel=fn;
        $readmemh($sformatf("tests/pattern%0d_data/pattern%0d.dat",suite,suite),patterns);
        $readmemh($sformatf("tests/pattern%0d_data/f%0d.dat",suite,fn),answers);
        @(negedge clk); rst=1;
        @(negedge clk); rst=0;
        while(received < 64) begin
            @(negedge clk);
            in_en=!busy;
            if (in_en) begin
                iot_in = sent<1024 ? patterns[sent/16][(sent%16)*8+:8] : 0;
                sent++;
            end
        end
    end
    always @(posedge clk) if(valid) begin
        if(iot_out !== answers[received]) $fatal(1,"word %0d got %h expected %h",received,iot_out,answers[received]);
        received++;
        if(received==64) begin $display("PASS mode=%0d suite=%0d",fn,suite); $finish; end
    end
    initial #30000 $fatal(1,"Timed out after %0d outputs",received);
endmodule
