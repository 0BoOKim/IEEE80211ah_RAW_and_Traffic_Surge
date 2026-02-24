% Main_Modular.m
% Modularized version of Simple_RAW_CSB simulation

clear all;
close all;
addpath('modules');

% 1. Configuration
SimParams = Get_Config();

% 2. Initialization
SimState = Init_Network(SimParams);

disp('Starting Simulation...');
tic;

% 3. Main Loop
while SimState.Time <= SimParams.N_slot

    % Manage RAW Slot Boundaries and Assignments
    Manage_RAW(SimState, SimParams);

    % Handle MAC Access (Backoff, Start Transmission)
    MAC_Access(SimState, SimParams);

    % Handle Transmission Events (End of TX, ACKs, Timers)
    Handle_Tx_Events(SimState, SimParams);

    % Generate Traffic
    Generate_Traffic(SimState, SimParams);

    % Advance Time
    SimState.Time = SimState.Time + 1;

    if mod(SimState.Time, 100000) == 0
        fprintf('Progress: %d / %d slots\n', SimState.Time, SimParams.N_slot);
    end
end

toc;

% 4. Statistics and Reporting
Stats = Calc_Stats(SimState, SimParams);

rmpath('modules');
