function SimState = Init_Network(SimParams)

    rng(SimParams.PNRG_Seed1);

    N_AP = SimParams.N_AP;
    N_Node = SimParams.N_Node;
    N_bkSTA = SimParams.N_bkSTA;

    % Initialize Nodes
    Node.Pos = zeros(N_Node, 2);
    Node.Type = zeros(1, N_Node);
    Node.ACK_Timer = zeros(N_Node, 2);

    TX_Radius_AP = Get_MaxDist(1, SimParams.Ant_Height_AP, SimParams.Ant_Height_STA, SimParams.TX_Power_AP, SimParams.CSTh);
    TX_Radius_STA = Get_MaxDist(2, SimParams.Ant_Height_STA, SimParams.Ant_Height_AP, SimParams.TX_Power_STA_Battery_Limit, SimParams.CSTh);

    % AP Setup
    Node.Pos(1,:) = [TX_Radius_AP, TX_Radius_AP];
    Node.Type(1)  =  -1;
    Node.ACK_Timer(1,:) = [-1 -1];

    % Background STAs
    for i= N_AP+1:N_AP+N_bkSTA
        Node.Type(i) = 0;
        rand_radian = rand*2*pi;
        rand_radius = rand*TX_Radius_AP;
        Node.Pos(i,:) = [rand_radius*cos(rand_radian)+TX_Radius_AP rand_radius*sin(rand_radian)+TX_Radius_AP];
        Node.ACK_Timer(i,:) =[-1 -1];
    end

    % Alarm STAs
    for i=N_AP+N_bkSTA+1:N_Node
        Node.Type(i) = 1;
        rand_radian = rand*2*pi;
        rand_radius = rand*TX_Radius_STA;
        Node.Pos(i,:) = [rand_radius*cos(rand_radian)+TX_Radius_AP rand_radius*sin(rand_radian)+TX_Radius_AP];
        Node.ACK_Timer(i,:) = [-1 -1];
    end

    % Initialize Buffer and Traffic State
    SimState.Next_Frame_Length_bk = zeros(1, N_Node);
    SimState.Next_Frame_Interval_bk = zeros(1, N_Node);
    SimState.Next_Frame_Length_al = zeros(1, N_Node);
    SimState.Next_Frame_Interval_al = zeros(1, N_Node);

    for i = 1:N_Node
        Node.TX_Buffer(i).Length = 0;
        Node.TX_Buffer(i).ACK_Length = 0;
        Node.TX_Buffer(i).ACK = [ ];
        Node.TX_Buffer(i).MPDU= [ ];

        if Node.Type(i) == 0  % BK STA
            SimState.Next_Frame_Length_bk(i) = ceil( (SimParams.Range_Frame_Length_bk(2)-SimParams.Range_Frame_Length_bk(1))*rand + SimParams.Range_Frame_Length_bk(1) );
            SimState.Next_Frame_Interval_bk(i) = ceil( (SimParams.Range_Frame_Interval_bk(2)-SimParams.Range_Frame_Interval_bk(1))*rand + SimParams.Range_Frame_Interval_bk(1) );

        elseif Node.Type(i) == 1  % Alarm STA
            if SimParams.Traffic_Surge_Mode == 1
                if SimParams.Traffic_Gen_Mode == 0
                    SimState.Next_Frame_Length_al(i) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                    SimState.Next_Frame_Interval_al(i) = ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                end
            elseif SimParams.Traffic_Surge_Mode == 2 || SimParams.Traffic_Surge_Mode == 3
                Node.TX_Buffer(i).Triggered = 0;
                if SimParams.Traffic_Surge_Mode == 3
                    SimState.Next_Frame_Length_al(i) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                    SimState.Next_Frame_Interval_al(i) = ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                end
            end
        end
        SimState.Delay(i).delay = [];
    end

    if SimParams.Traffic_Surge_Mode == 1 && SimParams.Traffic_Gen_Mode == 1
         SimState.Next_Frame_Length_al = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
         SimState.Next_Frame_Interval_al = ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
    end

    % Network Maps
    idx_AP = SimParams.idx_AP;
    idx_STA = SimParams.idx_STA;
    [SimState.MAP_LoS, SimState.MAP_RSS] = Build_NetworkInfoMaps(Node.Pos(idx_AP,:), Node.Pos(idx_STA,:), Node.Type, ...
        SimParams.Ant_Height_AP, SimParams.Ant_Height_STA, SimParams.Ant_Height_STA, ...
        SimParams.TX_Power_AP, SimParams.TX_Power_STA_Battery_Limit, SimParams.TX_Power_STA_Battery_NonLimit);

    % Initial Backoff & AIFS
    rng(SimParams.PNRG_Seed2);

    Node.CW = SimParams.CW_min;
    Node.bc = ceil(rand(1,N_Node).*Node.CW);
    Node.Init_aifs = SimParams.AIFSN;
    Node.aifs = Node.Init_aifs;
    Node.N_retry = zeros(1, N_Node);
    Node.Retry_Limit = SimParams.Retry_Limit;
    Node.CW_max = SimParams.CW_max;
    Node.CW_min = SimParams.CW_min;

    SimState.Node = Node;

    % Channel State
    SimState.tx_state = zeros(SimParams.N_slot, N_Node); % This might be large memory allocation
    SimState.tx_status = zeros(N_Node, 5) -1;
    SimState.n_txnode = zeros(1, N_Node);

    % Statistics
    SimState.n_access = zeros(1,N_Node);
    SimState.n_collision = zeros(1,N_Node);
    SimState.n_collision2 = zeros(1,N_Node);
    SimState.n_success = zeros(1,N_Node);
    SimState.n_success2 = zeros(1,N_Node);
    SimState.L_success = zeros(1,N_Node);
    SimState.n_loss = zeros(1,N_Node);
    SimState.n_enq = zeros(1,N_Node);

    % RAW State
    if SimParams.On_RAW
        SimState.Next_BTT = 1;
        SimState.Tab_RAW = [0 0 0];
        SimState.List_Assigned_STA = [];
        SimState.List_Remained_Slot = [];
        SimState.STATE_Prev_Remained_Slot = 0;
    end

    % Logs & Metrics
    if SimParams.Mode_Net_Congestion_Measure
        for i = 1:N_Node
            SimState.Net_Congestion_Measure(i).CH_Util = [0 0];
            SimState.Net_Congestion_Measure(i).N_ACK = [0 0];
            SimState.Net_Congestion_Measure(i).N_Acc = [0 0];
            SimState.Net_Congestion_Measure(i).N_Fail = [0 0];
            SimState.Net_Congestion_Measure(i).N_Suc = [0 0];
            SimState.Net_Congestion_Measure(i).N_MPDU = [0 0];
            SimState.Net_Congestion_Measure(i).L_QTime = [0 0];
        end
        SimState.Init_Net_Congestion_Measure_Time = 0;
        SimState.Next_Net_Congestion_Measure_Time = SimParams.Net_Congestion_Measure_Interval;
    end

    if SimParams.On_Measure_Traffic_Temporal_Evolution
       SimState.Next_Measure_Time = SimParams.Opt_Measure_Interval;
       SimState.Traffic_Temporal_Evolution = [0 0 0 0 0 0 0 0 0];
    end

    % Adaptive Mode
    if SimParams.RAW_Mode == 3
        SimState.Prev_TxConfig = -1*ones(N_Node, 2);
        SimState.Cnt_NoLog = zeros(N_Node,1);

        if SimParams.On_Log_TxWeight
            SimState.Log_TxWeight = zeros(1, 3*length(SimParams.Target_Node_Log_TxWeight));
            SimState.Ptr_EachNodeLog = ones(1,length(SimParams.Target_Node_Log_TxWeight));
            SimState.Next_Measure_Interval_Log_TxWeight = SimParams.Measure_Interval_Log_TxWeight;
        end
    end

    % Traffic Surge State
    SimState.Last_Time = 1;
    SimState.Measure_Cummulated_N_Triggerd_STAs = [0 0];
    SimState.L_Measure_Cummulated_N_Triggerd_STAs = 1;
    SimState.Prev_Traffic_Event = 0;

    % Global ID
    SimState.GID = 0;

    % Simulation Start Time
    SimState.Time = 1;
    if SimParams.On_RAW
        SimState.Time = 2;
    end

end
