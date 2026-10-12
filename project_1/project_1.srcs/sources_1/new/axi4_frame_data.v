`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 02.10.2026 16:16:58
// Design Name:
// Module Name: axi4_frame_data
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module axi4_frame_data #(
    parameter DATA_WIDTH      = 8 ,
    parameter DATA_WIDTH_FIFO = 32
) (
    input  wire                       data_clk      ,
    input  wire                       m_axis_aclk   ,
    input  wire                       s_axis_aresetn,
    // module 8 to 32
    input  wire [     DATA_WIDTH-1:0] data          ,
    input  wire                       data_valid    ,
    output wire                       data_ready    ,
    input  wire                       start         ,
    // FIFO
    input  wire                       m_axis_tready ,
    output wire                       m_axis_tvalid ,
    output wire [DATA_WIDTH_FIFO-1:0] m_axis_tdata  ,
    output wire                       m_axis_tlast
);

    wire [DATA_WIDTH_FIFO-1:0] data_w;
    wire                       ready ;
    wire                       valid ;
    wire                       last  ;

    (* ASYNC_REG = "TRUE" *) reg sync_100;
    (* ASYNC_REG = "TRUE" *) reg sync_125;

    always @(posedge data_clk or negedge s_axis_aresetn) begin : proc_
        if(~s_axis_aresetn) begin
            sync_125 <= 0;
            sync_100 <= 0;
        end else begin
            sync_100 <= start;
            sync_125 <= sync_100;
        end
    end
    frame_data dut_data (
        .m_axis_tdata  (data_w        ),
        .m_axis_tready (ready         ),
        .m_axis_tvalid (valid         ),
        .data          (data          ),
        .data_valid    (data_valid    ),
        .start         (sync_125      ),
        .s_axis_aclk   (data_clk      ),
        .data_ready    (data_ready    ),
        .m_axis_tlast  (last          ),
        .s_axis_aresetn(s_axis_aresetn)
    );



    axis_data_fifo_0 axi_fifo (
        .s_axis_aresetn(s_axis_aresetn),   // input wire s_axis_aresetn
        .s_axis_aclk   (data_clk      ),   // input wire s_axis_aclk
        .s_axis_tvalid (valid         ),   // input wire s_axis_tvalid
        .s_axis_tready (ready         ),   // output wire s_axis_tready
        .s_axis_tdata  (data_w        ),   // input wire [31 : 0] s_axis_tdata
        .s_axis_tlast  (last          ),   // input wire s_axis_tlast
        .m_axis_aclk   (m_axis_aclk   ),   // input wire m_axis_aclk
        .m_axis_tvalid (m_axis_tvalid ),   // output wire m_axis_tvalid
        .m_axis_tready (m_axis_tready ),   // input wire m_axis_tready
        .m_axis_tdata  (m_axis_tdata  ),   // output wire [31 : 0] m_axis_tdata
        .m_axis_tlast  (m_axis_tlast  )    // output wire m_axis_tlast
    );



endmodule
