classdef SimulationState < handle
    % SimulationState: A handle class to store dynamic simulation variables.
    % Using a handle class allows pass-by-reference semantics, preventing
    % expensive deep copies of large arrays (like tx_state) during function calls.

    properties
        % Node Information
        Node

        % Channel State (Large Matrix)
        tx_state
        tx_status
        n_txnode

        % Traffic State
        Next_Frame_Length_bk
        Next_Frame_Interval_bk
        Next_Frame_Length_al
        Next_Frame_Interval_al
        Delay
        GID

        % RAW Management
        Next_BTT
        Tab_RAW
        List_Assigned_STA
        List_Remained_Slot
        STATE_Prev_Remained_Slot

        % Maps
        MAP_LoS
        MAP_RSS

        % Statistics
        n_access
        n_collision
        n_collision2
        n_success
        n_success2
        L_success
        n_loss
        n_enq

        % Metrics & Logging
        Net_Congestion_Measure
        Init_Net_Congestion_Measure_Time
        Next_Net_Congestion_Measure_Time
        Traffic_Temporal_Evolution
        Next_Measure_Time

        % Adaptive Mode (Mode 3)
        Prev_TxConfig
        Cnt_NoLog
        Log_TxWeight
        Ptr_EachNodeLog
        Next_Measure_Interval_Log_TxWeight

        % Traffic Surge Control
        Last_Time
        Measure_Cummulated_N_Triggerd_STAs
        L_Measure_Cummulated_N_Triggerd_STAs
        Prev_Traffic_Event

        % Global Time
        Time
    end

    methods
        function obj = SimulationState()
            % Constructor (Optional: Initialize defaults if needed)
        end
    end
end
