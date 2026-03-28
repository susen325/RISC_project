`timescale 1ns / 1ps

module m_tb:

        $display("Simulation Finished. Results saved to output.txt and wb_stage_results.vcd.");

        // Close all opened files and cleanly terminate the simulation
        // TODO-2
        $fclose(in_file);
        $fclose(out_file);
        $finish;

    end

endmodule
