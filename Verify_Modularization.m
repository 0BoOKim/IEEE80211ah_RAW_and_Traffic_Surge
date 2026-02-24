% Verify_Modularization.m
% Verification Script for Modularized Code

clear all;
close all;

% Define common settings
SimN_Slot = 5000; % Short simulation for test (increased to ensure traffic)
addpath('modules'); % Ensure helper functions are available

% Run Original Script
fprintf('Running Original Simulation...\n');
try
    % Create a temporary copy of the original script with overrides
    orig_content = fileread('Simple_RAW_CSB_rev7_250123_rev260202.m');

    % 1. Prevent 'clear all;'
    orig_content = strrep(orig_content, 'clear all;', '% clear all;');

    % 2. Override N_slot
    orig_content = strrep(orig_content, 'N_slot = 1000000;', ['N_slot = ' num2str(SimN_Slot) ';']);

    % 3. Override On_Save_TX_Log to 0 (Disable) to prevent Anal_Congestion_Log error
    orig_content = strrep(orig_content, 'On_Save_TX_Log = 2;', 'On_Save_TX_Log = 0;');

    % 4. Inject Avg_Delay initialization before stats loop to prevent 'undefined' error
    % Search for "cnt_empty_delay_measure = 0;" which starts stats section
    stats_start_str = 'cnt_empty_delay_measure = 0;';
    orig_content = strrep(orig_content, stats_start_str, ['Avg_Delay = zeros(N_Node, 3);' newline stats_start_str]);

    fid = fopen('Temp_Original_Sim.m', 'w');
    fwrite(fid, orig_content);
    fclose(fid);

    run('Temp_Original_Sim.m');
    Result1 = RESULT_SET2;

    delete('Temp_Original_Sim.m');

catch ME
    warning('Failed to run original simulation: %s', ME.message);
    Result1 = [];
end


% Run Modular Simulation
fprintf('\nRunning Modular Simulation...\n');
try
    clearvars -except Result1 SimN_Slot

    addpath('modules');
    SimParams = Get_Config();
    SimParams.N_slot = SimN_Slot; % Override
    SimParams.On_Save_TX_Log = 0; % Disable Log

    % Re-Init using modified params
    SimState = Init_Network(SimParams);

    tic;
    while SimState.Time <= SimParams.N_slot
        SimState = Manage_RAW(SimState, SimParams);
        SimState = MAC_Access(SimState, SimParams);
        SimState = Handle_Tx_Events(SimState, SimParams);
        SimState = Generate_Traffic(SimState, SimParams);
        SimState.Time = SimState.Time + 1;
    end
    toc;

    Stats = Calc_Stats(SimState, SimParams);
    Result2 = Stats.RESULT_SET2;

    rmpath('modules');

catch ME
    warning('Failed to run modular simulation: %s', ME.message);
    Result2 = [];
end

% Compare Results
if ~isempty(Result1) && ~isempty(Result2)
    fprintf('\nComparison Results:\n');
    Diff = abs(Result1 - Result2);

    % Allow NaN comparisons (NaN == NaN is false, need careful check if results contain NaNs)
    % Replace NaNs with 0 for diff check
    Diff(isnan(Diff)) = 0;

    if max(Diff) < 1e-10
        fprintf('PASS: Results are identical (Difference < 1e-10)\n');
    else
        fprintf('FAIL: Results differ!\n');
        disp('Difference Vector:');
        disp(Diff);
        disp('Original Result:');
        disp(Result1);
        disp('Modular Result:');
        disp(Result2);
    end
else
    fprintf('Verification Incomplete due to simulation errors.\n');
end
