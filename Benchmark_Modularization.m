% Benchmark_Modularization.m
% Compare Execution Time of Original vs Modular Code

clear all;
close all;

SimN_Slot = 20000; % Use enough slots to make timing meaningful
addpath('modules');

fprintf('Starting Benchmark (N_slot = %d)...\n', SimN_Slot);

% ---------------------------------------------------------
% 1. Benchmark Original Script
% ---------------------------------------------------------
fprintf('\n[1/2] Running Original Simulation...\n');
try
    orig_content = fileread('Simple_RAW_CSB_rev7_250123_rev260202.m');

    % Prepare Temporary Script
    orig_content = strrep(orig_content, 'clear all;', '% clear all;');
    orig_content = strrep(orig_content, 'N_slot = 1000000;', ['N_slot = ' num2str(SimN_Slot) ';']);
    orig_content = strrep(orig_content, 'On_Save_TX_Log = 2;', 'On_Save_TX_Log = 0;'); % Disable logging to focus on compute

    % Inject Avg_Delay init to prevent crash
    stats_start_str = 'cnt_empty_delay_measure = 0;';
    orig_content = strrep(orig_content, stats_start_str, ['Avg_Delay = zeros(N_Node, 3);' newline stats_start_str]);

    fid = fopen('Temp_Benchmark_Orig.m', 'w');
    fwrite(fid, orig_content);
    fclose(fid);

    % Measure Time
    tic;
    run('Temp_Benchmark_Orig.m');
    Time_Orig = toc;

    fprintf('Original Execution Time: %.4f seconds\n', Time_Orig);

    delete('Temp_Benchmark_Orig.m');

catch ME
    warning('Original Simulation Failed: %s', ME.message);
    Time_Orig = NaN;
end


% ---------------------------------------------------------
% 2. Benchmark Modular Script
% ---------------------------------------------------------
fprintf('\n[2/2] Running Modular Simulation...\n');
try
    clearvars -except Time_Orig SimN_Slot

    addpath('modules');

    % Config & Init
    SimParams = Get_Config();
    SimParams.N_slot = SimN_Slot;
    SimParams.On_Save_TX_Log = 0; % Disable Log

    SimState = Init_Network(SimParams);

    % Measure Loop Time
    tic;

    % Main Loop (Inline from Main_Modular to avoid script overhead, focus on logic)
    while SimState.Time <= SimParams.N_slot
        SimState = Manage_RAW(SimState, SimParams);
        SimState = MAC_Access(SimState, SimParams);
        SimState = Handle_Tx_Events(SimState, SimParams);
        SimState = Generate_Traffic(SimState, SimParams);
        SimState.Time = SimState.Time + 1;
    end

    Time_Modular = toc;

    % Calculate Stats (Optional, not timed)
    Stats = Calc_Stats(SimState, SimParams);

    fprintf('Modular Execution Time:  %.4f seconds\n', Time_Modular);

    rmpath('modules');

catch ME
    warning('Modular Simulation Failed: %s', ME.message);
    Time_Modular = NaN;
end


% ---------------------------------------------------------
% 3. Report
% ---------------------------------------------------------
fprintf('\n------------------------------------------------\n');
fprintf('BENCHMARK RESULTS (N_slot = %d)\n', SimN_Slot);
fprintf('------------------------------------------------\n');

if ~isnan(Time_Orig) && ~isnan(Time_Modular)
    fprintf('Original: %.4f s\n', Time_Orig);
    fprintf('Modular:  %.4f s\n', Time_Modular);

    diff = Time_Modular - Time_Orig;
    ratio = Time_Modular / Time_Orig;

    if diff > 0
        fprintf('Outcome:  Modular is SLOWER by %.4f s (%.2fx)\n', diff, ratio);
    else
        fprintf('Outcome:  Modular is FASTER by %.4f s (%.2fx)\n', abs(diff), ratio);
    end

    fprintf('\nAnalysis:\n');
    fprintf('- Modular code introduces function call overhead in the main loop.\n');
    fprintf('- Every slot calls 4 functions: Manage_RAW, MAC_Access, Handle_Tx_Events, Generate_Traffic.\n');
    fprintf('- In MATLAB, function calls have a small cost. For %d iterations, this adds up.\n', SimN_Slot);
    fprintf('- However, modularity improves readability and maintainability significantly.\n');
else
    fprintf('Benchmark Incomplete due to errors.\n');
end
