function SimParams = Get_Config()
    % Global Configuration Parameters

    SimParams.PNRG_Seed1 = 1731;  % random seed for Node deployment
    SimParams.PNRG_Seed2 = 1731;  % random seed for other random processes
    SimParams.BEB_ENABLE = 1;

    %------------------------------------------
    % PARAMETERS & VARIABLES
    %------------------------------------------
    SimParams.N_slot = 1000000;
    SimParams.N_alarmSTA = 50;
    SimParams.N_bkSTA = 10;
    SimParams.N_STA = SimParams.N_alarmSTA + SimParams.N_bkSTA;
    SimParams.N_AP = 1;
    SimParams.N_Node = SimParams.N_AP + SimParams.N_STA;

    % RAW Config
    SimParams.Opt_N_RAW = 8;
    SimParams.Opt_Slot_Duration_Count = 255;
    SimParams.RAW_Mode = 3;

    SimParams.Traffic_Surge_Mode = 3;
    SimParams.On_Save_TX_Log = 2;
    SimParams.On_Log_Tx_Fail_Ratio = 1;
    SimParams.Interval_Log_Tx_Fail_Ratio = 1000;

    % Antenna Config
    SimParams.Ant_Height_AP = 30.0;
    SimParams.Ant_Height_STA = 1.5;

    SimParams.TX_Power_AP = 0; % (dBm)
    SimParams.TX_Power_STA_Battery_Limit = 0; % (dBm)
    SimParams.TX_Power_STA_Battery_NonLimit = SimParams.TX_Power_AP;
    SimParams.CSTh = -82.0; % (dBm)

    SimParams.Mode_Net_Congestion_Measure = 1;
    SimParams.Net_Congestion_Measure_Interval = 1000;

    SimParams.Mode_Dynamic_Sim_Time = 0;
    SimParams.Crit_Remaied_Slot = 500000;
    SimParams.N_Extending_Slot = 500000;

    % Rates and MAC Params
    SimParams.R_data = 0.3*10^6*ones(1,SimParams.N_Node);
    SimParams.CW_min = 16*ones(1,SimParams.N_Node);
    SimParams.CW_max = 1024*ones(1,SimParams.N_Node);
    SimParams.Retry_Limit = 7*ones(1,SimParams.N_Node);

    SimParams.L_data = 100*ones(1,SimParams.N_Node);
    SimParams.L_data(1:SimParams.N_AP) = 0;

    SimParams.T_slot = 52*10^-6;
    SimParams.L_macH = 18;
    SimParams.T_phyH = 560*10^-6 + 32/SimParams.R_data(1);
    SimParams.T_sifs = 160*10^-6;
    SimParams.L_ack  = 14;
    SimParams.R_ack  = 0.3*10^6;
    SimParams.T_ack  = SimParams.T_phyH + SimParams.L_ack*8/SimParams.R_ack;
    SimParams.T_ack_Timeout = SimParams.T_sifs + SimParams.T_ack + 0;

    T_difs = SimParams.T_sifs + 2*SimParams.T_slot;
    SimParams.AIFSN = ceil(T_difs/SimParams.T_slot)*ones(1,SimParams.N_Node);
    SimParams.SIFSN = ceil(SimParams.T_sifs/SimParams.T_slot);
    SimParams.T_ackN = ceil(SimParams.T_ack/SimParams.T_slot);

    % Pre-calculate data transmission times (approximate or initial)
    % Note: Actual T_data depends on frame length which varies

    % Background Traffic Params
    if SimParams.N_bkSTA > 0
        SimParams.Range_Frame_Length_bk = [100 100];
        SimParams.Range_Frame_Interval_bk = [19240 19240];
        SimParams.Prob_Frame_Generation_bk = 1.0;
    end

    % Traffic Surge Params
    SimParams.Allowed_MAX_Next_Traffic_Event = 1000;

    if SimParams.Traffic_Surge_Mode == 1
        SimParams.Range_Frame_Length_al = [100 100];
        SimParams.Range_Frame_Interval_al = [100 100];
        SimParams.Prob_Frame_Generation_al = 1.0;
        SimParams.Traffic_Gen_Mode = 1;
        SimParams.Noise_Arrival_Time = [10 50];
        SimParams.Opt_Start = 0;
        SimParams.Opt_End = SimParams.N_slot;

    elseif SimParams.Traffic_Surge_Mode == 2
        var_alpha = 1.7013;
        var_beta = 8.1347;
        SimParams.Opt_Start = 10000;
        SimParams.Opt_End = 150000;
        SimParams.Period = SimParams.Opt_End - SimParams.Opt_Start + 1;

        SimParams.Tab_Traffic_Model = Build_Traffic_Surge_Model(var_alpha, var_beta, SimParams.Period, SimParams.N_alarmSTA, SimParams.Opt_Start);
        SimParams.Tab_Traffic_Model(1,:) = SimParams.Tab_Traffic_Model(1,:) + SimParams.Opt_Start;

        SimParams.Range_Frame_Length_al = [100 100];

    elseif SimParams.Traffic_Surge_Mode == 3
        var_alpha = 2.029;
        var_beta = 2.4513;
        SimParams.Opt_Start = 10;
        SimParams.Opt_End = 50000 + SimParams.Opt_Start;
        SimParams.Period = SimParams.Opt_End - SimParams.Opt_Start + 1;

        SimParams.Tab_Traffic_Model = Build_Traffic_Surge_Model(var_alpha, var_beta, SimParams.Period, SimParams.N_alarmSTA, SimParams.Opt_Start);
        SimParams.Tab_Traffic_Model(1,:) = SimParams.Tab_Traffic_Model(1,:) + SimParams.Opt_Start;

        SimParams.Range_Frame_Length_al = [100 100];
        SimParams.Range_Frame_Interval_al = [1924 1924];
        SimParams.Prob_Frame_Generation_al = 1.0;
    end

    SimParams.On_Measure_Traffic_Temporal_Evolution = 1;
    SimParams.Opt_Measure_Interval = 2000;

    % RAW Settings
    SimParams.On_RAW = 1;
    if SimParams.On_RAW
        SimParams.On_CSB = 0;
        SimParams.On_BSR = 0;
        if SimParams.On_BSR
            SimParams.L_BSR = 560*10^-6;
            SimParams.L_BSR_in_Slot = ceil(SimParams.L_BSR/SimParams.T_slot);
        end

        C = SimParams.Opt_Slot_Duration_Count;
        SimParams.T_RAW_Slot = 500*10^-6 + C*120*10^-6;
        SimParams.N_RAW = SimParams.Opt_N_RAW;
        SimParams.T_RAW_Slot_in_Slot = ceil(SimParams.T_RAW_Slot/SimParams.T_slot);
        SimParams.Beacon_Interval = SimParams.T_RAW_Slot_in_Slot * SimParams.N_RAW;
    end

    % RAW Mode Specifics
    if SimParams.RAW_Mode == 1 || SimParams.RAW_Mode == 2
        SimParams.Opt_Interval = 10;
        SimParams.Opt_Threshold = SimParams.N_RAW * SimParams.Opt_Interval;
        SimParams.Opt_decisionFactor = 8;
        SimParams.Opt_Max = SimParams.Opt_Threshold * SimParams.Opt_decisionFactor;
    end

    if SimParams.RAW_Mode == 2
       SimParams.Opt_Range_Interval = [1 10];
       SimParams.Opt_Range_decisionFactor = [1 10];
       SimParams.Opt_Inc_Interval = 1;
       SimParams.Opt_Dec_Interval = 1;
       SimParams.Opt_Inc_decisionFactor = 1;
       SimParams.Opt_Dec_decisionFactor = 1;
    end

    if SimParams.RAW_Mode == 3
        SimParams.TX_Th = 0.5;
        SimParams.Enable_TxWeight = 1;
        SimParams.Init_TxWeight = 1.0;
        SimParams.Max_TxWeight = 2.0;
        SimParams.Min_TxWeight = 0.01;
        SimParams.Dec_TxWeight = 0.3;
        SimParams.Inc_TxWeight = 0.3;

        SimParams.On_Log_TxWeight = 1;
        SimParams.Target_Node_Log_TxWeight = [2 5 10];
        SimParams.Measure_Interval_Log_TxWeight = SimParams.Net_Congestion_Measure_Interval;

        if SimParams.On_Save_TX_Log == 2
            filename = sprintf('TX_LOG_TEST.mat');
        else
            filename = sprintf('TX_LOG_Nal_%d_Nbk_%d_Nraw_%d_SDC_%d.mat', ...
            SimParams.N_alarmSTA, SimParams.N_bkSTA, SimParams.Opt_N_RAW, SimParams.Opt_Slot_Duration_Count);
        end
        loaded_data = load(filename);
        SimParams.TX_LOG = loaded_data.Unnamed_Tab;

        SimParams.Bin_CH_Usage = 0.1000;
        SimParams.Bin_N_ACK = 5;
        SimParams.Norm_TX_LOG = [ SimParams.TX_LOG(:,1)/max(SimParams.TX_LOG(:,1)) SimParams.TX_LOG(:,2)/max(SimParams.TX_LOG(:,2)) ];
    end

    if SimParams.RAW_Mode == 4
        SimParams.N_offset = 0;
    end

    % Index Helpers
    SimParams.idx_AP = SimParams.N_AP;
    SimParams.idx_STA_Type0 = SimParams.N_AP+1 : SimParams.N_AP+SimParams.N_bkSTA;
    SimParams.idx_STA_Type1 = SimParams.N_AP+SimParams.N_bkSTA+1 : SimParams.N_Node;
    SimParams.idx_STA = SimParams.N_AP+1 : SimParams.N_Node;
end
