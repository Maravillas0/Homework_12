`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 05.10.2026 16:08:24
// Design Name:
// Module Name: frame_data
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


module frame_data #(
    parameter DATA_WIDTH      = 8 ,
    parameter DATA_WIDTH_FIFO = 32
) (
    input  wire                           s_axis_aclk   ,
    input  wire                           s_axis_aresetn,
    input  wire     [     DATA_WIDTH-1:0] data          ,
    input  wire                           data_valid    ,
    output wire                           data_ready    ,
    output      reg [DATA_WIDTH_FIFO-1:0] m_axis_tdata  ,
    output wire                           m_axis_tvalid ,
    input  wire                           m_axis_tready ,
    output wire                           m_axis_tlast  ,
    input  wire                           start
);

    reg [DATA_WIDTH_FIFO-1:0] temp_data                     ;
    reg [                1:0] cnt                           ;
    reg [               13:0] count                         ;
    reg                       state                         ;
    localparam                LOAD      = 1'b0, WRITE = 1'b1;




    assign data_ready    = start && (state == LOAD);
    assign m_axis_tvalid = (state == WRITE);
    assign m_axis_tlast = m_axis_tvalid && (count == 14'd15999);

    always @(posedge s_axis_aclk or negedge s_axis_aresetn) begin

        if (!s_axis_aresetn) begin
            temp_data    <= {DATA_WIDTH_FIFO{1'b0}};
            m_axis_tdata <= {DATA_WIDTH_FIFO{1'b0}};
            state        <= LOAD;
            cnt          <= 2'b00;
            count <= 14'd0;
        end else begin

            case (state)

                LOAD : begin if (data_valid && data_ready) begin

                        if (cnt == 2'd3) begin
                            m_axis_tdata <= {temp_data[DATA_WIDTH_FIFO-DATA_WIDTH-1:0], data};
                            cnt          <= 2'b00;
                            state        <= WRITE;
                        end
                        else begin
                            temp_data <= {temp_data[DATA_WIDTH_FIFO-DATA_WIDTH-1:0], data};
                            cnt       <= cnt + 1'b1;
                        end

                    end
                end

                WRITE : begin
                    if (m_axis_tready) begin
                        if (count == 14'd15999)
                            count <= 14'd0;
                        else
                            count <= count + 1'b1;

                        state <= LOAD;
                    end
                end
                default : begin temp_data <= {DATA_WIDTH_FIFO{1'b0}};
                    m_axis_tdata <= {DATA_WIDTH_FIFO{1'b0}};
                end
            endcase
        end
    end


endmodule
