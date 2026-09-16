//Custom accum tb - liam
`timescale 1ns / 1ps

module accum_tb();

    // Parameters
    parameter DATAW = 32;
    parameter ACCUMW = 32;

    // Signals
    logic clk;
    logic rst;
    logic signed [DATAW-1:0] data;
    logic ivalid;
    logic first;
    logic last;
    logic signed [ACCUMW-1:0] result;
    logic ovalid;

    // Instantiate the Device Under Test (DUT)
    accum #(
        .DATAW(DATAW),
        .ACCUMW(ACCUMW)
    ) dut (
        .clk(clk),
        .rst(rst),
        .data(data),
        .ivalid(ivalid),
        .first(first),
        .last(last),
        .result(result),
        .ovalid(ovalid)
    );

    // Clock generation (10ns period -> 100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Test Stimulus
    initial begin
        // 1. Initialize inputs and apply reset
        rst = 1;
        data = 0;
        ivalid = 0;
        first = 0;
        last = 0;

        // Hold reset for a few clock cycles, then release
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        @(negedge clk);

        $display("--- Starting accum Simulation ---");

        // ---------------------------------------------------------
        // Test Case 1: Standard Multi-Cycle Accumulation
        // Simulating 4 chunks of data arriving sequentially.
        // Data: 10, 20, -5, 15
        // Expected: 10 + 20 - 5 + 15 = 40
        // ---------------------------------------------------------
        $display("Time: %0t | Injecting Test 1 (Standard Accumulation)...", $time);
        ivalid = 1; first = 1; last = 0; data = 32'd10; @(negedge clk); // Cycle 1 (first)
        ivalid = 1; first = 0; last = 0; data = 32'd20; @(negedge clk); // Cycle 2
        ivalid = 1; first = 0; last = 0; data = -32'd5; @(negedge clk); // Cycle 3
        ivalid = 1; first = 0; last = 1; data = 32'd15; @(negedge clk); // Cycle 4 (last)
        ivalid = 0; first = 0; last = 0; // Deassert inputs
        
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 1 Result: %0d | Expected: 40", $time, result);
        if (result !== 32'd40) $error("Test 1 Failed!");
        @(negedge clk);

        // ---------------------------------------------------------
        // Test Case 2: Edge Case (1-Cycle Accumulation)
        // Testing the condition where first && last are high simultaneously.
        // Data: 99
        // Expected: 99
        // ---------------------------------------------------------
        $display("Time: %0t | Injecting Test 2 (1-Cycle Accumulation)...", $time);
        ivalid = 1; first = 1; last = 1; data = 32'd99; @(negedge clk);
        ivalid = 0; first = 0; last = 0; 
        
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 2 Result: %0d | Expected: 99", $time, result);
        if (result !== 32'd99) $error("Test 2 Failed!");
        @(negedge clk);

        // ---------------------------------------------------------
        // Test Case 3: Back-to-Back Accumulations
        // Ensuring the pipeline doesn't bleed data between separate 
        // accumulations when there are zero idle cycles between them.
        // Acc A: 50 + 50 = 100
        // Acc B: -10 + (-10) = -20
        // ---------------------------------------------------------
        $display("Time: %0t | Injecting Test 3 (Back-to-Back)...", $time);
        
        // Drive Accumulation A
        ivalid = 1; first = 1; last = 0; data = 32'd50; @(negedge clk);
        ivalid = 1; first = 0; last = 1; data = 32'd50; @(negedge clk);
        
        // Drive Accumulation B, part 1
        ivalid = 1; first = 1; last = 0; data = -32'd10; 
        
        // EXACTLY HERE (at the negedge immediately following Acc A's 'last' cycle)
        // ovalid is currently HIGH. Check it before we advance time!
        $display("Time: %0t | Test 3a Result: %0d | Expected: 100", $time, result);
        if (result !== 32'd100) $error("Test 3a Failed! Result incorrect.");
        if (ovalid !== 1'b1) $error("Test 3a Failed! ovalid not high.");
        
        // Now advance time to clock in Accumulation B, part 1
        @(negedge clk);

        // Drive Accumulation B, part 2
        ivalid = 1; first = 0; last = 1; data = -32'd10; @(negedge clk);
        ivalid = 0; first = 0; last = 0;

        // Wait for B's result to finish computing
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 3b Result: %0d | Expected: -20", $time, result);
        if (result !== -32'd20) $error("Test 3b Failed!");
        @(negedge clk);

        // ---------------------------------------------------------
        // Test Case 4: Dirty Data & Invalid Signal Toggling
        // Ensuring the accumulator pauses its sum when ivalid is low,
        // ignoring garbage data and control signals.
        // Valid Data: 100 + 200 + 300 = 600
        // ---------------------------------------------------------
        $display("Time: %0t | Injecting Test 4 (Dirty Valid Toggling)...", $time);
        
        // Valid 'first' chunk
        ivalid = 1; first = 1; last = 0; data = 32'd100; @(negedge clk);
        
        // INVALID chunk (Garbage data, fake 'last' flag)
        ivalid = 0; first = 0; last = 1; data = 32'd9999; @(negedge clk);
        
        // Valid middle chunk
        ivalid = 1; first = 0; last = 0; data = 32'd200; @(negedge clk);
        
        // INVALID chunk (Garbage data)
        ivalid = 0; first = 0; last = 0; data = -32'd5000; @(negedge clk);
        
        // Valid 'last' chunk
        ivalid = 1; first = 0; last = 1; data = 32'd300; @(negedge clk);
        ivalid = 0; first = 0; last = 0;

        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 4 Result: %0d | Expected: 600", $time, result);
        if (result !== 32'd600) $error("Test 4 Failed!");
        
        // Ensure ovalid drops back to 0 correctly after 1 cycle
        @(posedge clk);
        @(negedge clk);
        if (ovalid !== 1'b0) $error("Test 4 Failed! ovalid got stuck high.");

        // Finish simulation
        #20;
        $display("--- Simulation Complete ---");
        $finish;
    end

endmodule
