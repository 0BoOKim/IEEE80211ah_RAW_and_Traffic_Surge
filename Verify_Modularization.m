% Verify_Modularization.m
% Verification Script for Modularized Code

clear all;
close all;

% Define common settings
SimN_Slot = 2000; % Short simulation for test
addpath('modules'); % Ensure helper functions are available

% Run Original Script
fprintf('Running Original Simulation...\n');
try
    % Override N_slot in original script by wrapping it in a function?
    % Or simply run it and capture the workspace.
    % To modify N_slot without editing original file, we can:
    % 1. Create a wrapper function that sets N_slot and calls the script?
    %    Since it's a script, variables are in workspace.
    %    But script starts with `clear all`, which wipes overrides.
    %    We'll have to rely on editing or a slightly modified copy for verification.
    %    Or assume the user modifies N_slot manually as instructed.
    %    Wait, `Simple_RAW_CSB...m` has `clear all;` at line 6.
    %    This makes automated testing tricky without modification.

    % Let's create a temporary copy of the original script without `clear all`
    % and with `N_slot = 2000`.
    orig_content = fileread('Simple_RAW_CSB_rev7_250123_rev260202.m');
    orig_content = strrep(orig_content, 'clear all;', '% clear all;');
    orig_content = strrep(orig_content, 'N_slot = 1000000;', ['N_slot = ' num2str(SimN_Slot) ';']);

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
    % We need to modify Get_Config to use N_slot = 2000.
    % Or we can pass N_slot as argument if we modify Main_Modular.
    % Since we can't easily modify Get_Config dynamically (it's a function),
    % we'll use a modified Main_Modular approach or modify SimParams after Get_Config.

    clearvars -except Result1 SimN_Slot

    addpath('modules');
    SimParams = Get_Config();
    SimParams.N_slot = SimN_Slot; % Override

    % Re-Init using modified params
    SimState = Init_Network(SimParams);

    % Run Main Loop (Copy of Main_Modular logic but inline or modify Main_Modular to accept Params)
    % It's cleaner to modify Main_Modular to check for existing SimParams?
    % No, let's just run the loop logic here using the modules.

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
