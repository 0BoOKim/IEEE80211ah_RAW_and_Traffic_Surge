# Performance Analysis: Modular vs. Monolithic

This document analyzes the performance impact of modularizing the IEEE 802.11ah simulation code.

## 1. Methodology
- **Benchmark Script:** `Benchmark_Modularization.m`
- **Simulation Parameters:**
    - `N_slot`: 20,000 slots (to ensure measurable execution time)
    - `On_Save_TX_Log`: Disabled (to focus on computational overhead, not I/O)
    - Configuration: Identical for both runs.

## 2. Expected Results
In MATLAB, function calls introduce a small but non-zero overhead compared to inline code execution within a script. The modularized code introduces **4 function calls per time slot** (`Manage_RAW`, `MAC_Access`, `Handle_Tx_Events`, `Generate_Traffic`).

For `N_slot = 1,000,000` (standard run), this adds **4 million function calls**.

Therefore, it is expected that the **modular code will be slightly slower** than the original monolithic script. The slowdown is typically in the range of **1.1x to 1.5x**, depending on the complexity of the logic inside the functions versus the call overhead.

## 3. Deep Dive: Why it is slower? (State Structure Overhead)
The primary cause of the performance degradation is the handling of the simulation state structure (`SimState`).

- **Large State Object:** `SimState` contains the variable `tx_state`, which is a matrix of size `N_slot` × `N_Node` (1,000,000 × 61 ≈ 61 million elements). This single variable consumes significant memory (approx. **488 MB** if using double precision).
- **Copy-on-Write Behavior:** In MATLAB, structures are passed by value. When `SimState` is passed to a function like `Manage_RAW(SimState, ...)` and modified inside that function, MATLAB's "Copy-on-Write" mechanism may trigger a **deep copy** of the entire structure if the compiler cannot optimize it away.
- **Repeated Copying:** This potential copy happens **4 times per time slot**. Over 1,000,000 slots, this results in massive memory bandwidth usage and allocation overhead, far exceeding the cost of the arithmetic operations themselves.
- **Comparison:** In the original monolithic script, all variables resided in a single workspace scope, so no copying was necessary.

## 4. Trade-off Analysis
While the modular code may be slower, the benefits outweigh the performance cost:
- **Readability:** Logic is separated into clear, descriptive modules.
- **Maintainability:** Bugs can be isolated to specific modules (e.g., MAC logic vs. Traffic logic).
- **Reusability:** Functions like `Generate_Traffic` can be reused in other simulations or unit tested independently.
- **Testing:** Individual components can be verified with unit tests (as seen in `Verify_Modularization.m`).

## 5. Optimization Opportunities
If performance is critical, the following optimizations can be applied to the modular code:
- **Handle Classes:** Convert `SimState` to a MATLAB `handle` class (object-oriented). This enforces pass-by-reference semantics, eliminating the copy overhead.
- **Global Variables:** Store large read-only or shared state like `tx_state` in `global` or `persistent` variables (though this reduces modularity).
- **Vectorization:** Ensure operations inside modules are vectorized to minimize execution time per call.
- **MEX Functions:** Critical loops could be rewritten in C/C++ (MEX) if needed.

## 6. Conclusion
The modularization prioritizes code quality and correctness over raw execution speed. The slight performance regression is a standard trade-off in high-level languages like MATLAB when moving from scripts to functions, exacerbated here by the large state object.
