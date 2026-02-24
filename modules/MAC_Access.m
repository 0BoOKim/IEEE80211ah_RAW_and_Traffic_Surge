function MAC_Access(SimState, SimParams)

    i = SimState.Time;

    % Identify Assigned STAs in current RAW Slot
    if SimParams.On_RAW
        Idx_Enabled_RAW = find(SimState.Tab_RAW(:,3) == 1);

        if length(Idx_Enabled_RAW) > 1
            error('only one RAW slot can be enabled!');
        end

        Assigned_STA = [];
        if ~isempty(Idx_Enabled_RAW)
             if Idx_Enabled_RAW <= size(SimState.List_Assigned_STA, 1)
                Assigned_STA = SimState.List_Assigned_STA(Idx_Enabled_RAW,:);
                Assigned_STA(Assigned_STA == 0) = [];
            end
        end

        N_user_in_RAW_Slot = length(Assigned_STA);

        % ---------------------------------------------
        % 1. Decrement AIFS and Backoff
        % ---------------------------------------------
        % Decrement AIFS
        for j=1:N_user_in_RAW_Slot
            u = Assigned_STA(j);
            if (SimState.Node.aifs(u) > 0 && ...
                    SimState.Node.TX_Buffer(u).Length > 0 && ...
                    SimState.n_txnode(u) == 0 && ...
                    SimState.tx_status(u,1) == -1 && ...
                    SimState.Node.ACK_Timer(u,1) == -1)

                SimState.Node.aifs(u) = SimState.Node.aifs(u) - 1;
            end
        end

        % Decrement Backoff
        for j=1:N_user_in_RAW_Slot
            u = Assigned_STA(j);
            if (SimState.Node.aifs(u) == 0 && ...
                    SimState.Node.TX_Buffer(u).Length > 0 && ...
                    SimState.n_txnode(u) == 0 && ...
                    SimState.tx_status(u,1) == -1 && ...
                    SimState.Node.ACK_Timer(u,1) == -1)

                SimState.Node.bc(u) = SimState.Node.bc(u) -1;
            end
        end

        % ---------------------------------------------
        % 2. Attempt Transmission (Data)
        % ---------------------------------------------
        for j=1:N_user_in_RAW_Slot
            u = Assigned_STA(j);
            if (SimState.Node.bc(u) == 0 && SimState.n_txnode(u) == 0 && SimState.tx_status(u,1) == -1)

                T_data = 8*SimState.Node.TX_Buffer(u).MPDU(1,2)/SimParams.R_data(u);
                T_txslot = ceil(T_data/SimParams.T_slot);

                SimState.Node.aifs(u) = SimState.Node.Init_aifs(u);

                if SimParams.On_CSB == 0

                    % Check if fits in RAW slot
                    if  T_txslot  < SimState.Tab_RAW(Idx_Enabled_RAW, 2) - i

                        SimState.n_access(u) = SimState.n_access(u) + 1;

                        if  SimParams.Mode_Net_Congestion_Measure
                              SimState.Net_Congestion_Measure(u).N_Acc(size(SimState.Net_Congestion_Measure(u).N_Acc, 1), 2) ...
                                    = SimState.Net_Congestion_Measure(u).N_Acc(size(SimState.Net_Congestion_Measure(u).N_Acc, 1), 2) + 1;
                        end

                        if length(find(SimState.tx_status(u,:) == -1)) ~= 5
                            error('unexpected tx_status!');
                        else
                            SimState.tx_status(u,:) = [i i+T_txslot-1 1 0 0];
                        end

                    else
                        % Transmission not allowed (not enough time in RAW slot)
                        % Logic implies we do nothing, just wait?
                        % Original code: sets T_data=0, T_txslot=0. Effectively no-op.
                    end
                end

                % Note: Logic to reset BC/AIFS was commented out in original code?
                % No, "bc(Assigned_STA(j)) = ceil(rand*CW(Assigned_STA(j)))" was commented out.
                % It is done at End of Transmission.
            end
        end
    end

    % ---------------------------------------------
    % 3. Attempt Transmission (ACK by AP)
    % ---------------------------------------------
    for j=1:SimParams.N_AP
        u = SimParams.idx_AP(j);

        if SimState.Node.TX_Buffer(u).ACK_Length > 0 && SimState.tx_status(u, 1) == -1
            if ~isempty(SimState.Node.TX_Buffer(u).ACK(1))

                % Check if ACK Transmission Time Reached
                if SimState.Node.TX_Buffer(u).ACK(1,5) + SimParams.SIFSN <= i

                   % Check Channel Idle
                   if SimState.n_txnode(u) == 0

                      % Transmit ACK
                      SimState.tx_state(i:(i+SimParams.T_ackN-1), u) = 1; % STATE_TX = 1

                      SimState.tx_status(u, :) = [i i+SimParams.T_ackN-1 SimState.Node.TX_Buffer(u).ACK(1,3) 0 1];

                      % Deque ACK
                      SimState.Node.TX_Buffer(u) = Deque_ACK(SimState.Node.TX_Buffer(u));

                      SimState.n_access(u) = SimState.n_access(u) + 1;
                   end
                end
            end
        end
    end

    % ---------------------------------------------
    % 4. Propagate Transmission Effects (Start of TX)
    % ---------------------------------------------
    % Original code loops N_Node checking tx_status(j,1) == i

    STATE_CS = 2;
    STATE_TX = 1;

    for j=1:SimParams.N_Node
        if SimState.tx_status(j,1) == i  % Begin of Transmission

                [Idx_IntfSTA, Idx_IntfAP] = Get_InteferedSTAs(SimState.MAP_RSS, j, SimParams.CSTh, SimParams.N_AP);
                Idx_IntfNode = unique([Idx_IntfSTA; Idx_IntfAP]);

                % Update self tx_state
                SimState.tx_state(i:SimState.tx_status(j,2), j) = STATE_TX;

                if ~isempty(Idx_IntfNode)
                    % Update neighbors tx_state (Accumulate CS)
                    SimState.tx_state(i:SimState.tx_status(j,2),Idx_IntfNode) = SimState.tx_state(i:SimState.tx_status(j,2),Idx_IntfNode) + STATE_CS;

                    SimState.Node.aifs(Idx_IntfNode) = SimState.Node.Init_aifs(Idx_IntfNode);
                    SimState.n_txnode(Idx_IntfNode) = SimState.n_txnode(Idx_IntfNode) + 1;
                end

                % Count Interferences (Collision Marking)
                % Check other ongoing transmissions
                for temp_idx = 1:SimParams.N_Node
                    if temp_idx == j
                        continue;
                    end
                    % If temp_idx is transmitting and its target is in Idx_IntfNode (meaning it hears j's transmission)
                    % Wait, logic is:
                    % if tx_status(temp_idx,1) ~= -1 (active tx)
                    % and ismember(tx_status(temp_idx,3), Idx_IntfNode) (temp_idx's receiver is hearing j)
                    % then temp_idx's transmission is interfered?

                    if SimState.tx_status(temp_idx,1) ~= -1 && ismember(SimState.tx_status(temp_idx,3), Idx_IntfNode)
                       SimState.tx_status(temp_idx,4) = SimState.tx_status(temp_idx,4) + 1;
                    end
                end
        end
    end

end
