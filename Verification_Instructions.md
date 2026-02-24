# Verification Instructions

To verify that the modularized code (`Main_Modular.m`) produces identical results to the original script (`Simple_RAW_CSB_rev7_250123_rev260202.m`), follow these steps:

1. **Comparison Strategy:**
   - Both scripts calculate a final statistics vector `RESULT_SET2` containing throughput, collision ratio, etc.
   - We will run both scripts with a small number of slots (e.g., `N_slot = 2000`) to save time.
   - We will compare the resulting `RESULT_SET2` values. They should be identical (difference < 1e-10).

2. **Run Verification Script:**
   - Open MATLAB and ensure you are in the project root directory.
   - Run the script `Verify_Modularization.m`.
   - The script will automatically:
     1. Run the original simulation (with `N_slot=2000`).
     2. Run the modular simulation (with `N_slot=2000`).
     3. Compare the outputs and display "PASS" or "FAIL".

3. **Manual Check:**
   - You can also manually inspect the `TX_LOG_...mat` files generated if `On_Save_TX_Log` is enabled, to ensure data logging is consistent.
