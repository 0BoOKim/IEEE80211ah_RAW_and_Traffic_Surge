function Manage_RAW(SimState, SimParams)

    i = SimState.Time;

    if SimParams.On_RAW

        if i == SimState.Next_BTT+1  % at the begin of RAW slot

           T_RAW_Slot_in_Slot = SimParams.T_RAW_Slot_in_Slot;
           N_RAW = SimParams.N_RAW;

           % configure the RAW slot
           Tab_RAW = [i+1 i+T_RAW_Slot_in_Slot 0];

           if N_RAW > 1
               for idx_RAW = 2:N_RAW
                    Tab_RAW(idx_RAW, 1) = Tab_RAW(idx_RAW-1, 2) + 1;
                    Tab_RAW(idx_RAW, 2) = Tab_RAW(idx_RAW, 1)+T_RAW_Slot_in_Slot;
                    Tab_RAW(idx_RAW, 3)  = 0;
               end
           end

           idx_STA = SimParams.idx_STA;
           N_STA = SimParams.N_STA;
           Node = SimState.Node;

           if SimParams.RAW_Mode == 0
              % Allocate STAs based on uniform random distribution
              All_User = [];
              for j = 1:length(idx_STA)
                if 1 % Node.TX_Buffer(idx_STA(j)).Length > 0
                   All_User = [All_User;  idx_STA(j)];
                end
              end

               SimState.List_Assigned_STA = [];

               % N_Assigned_STA calculation was in init, but here we do it dynamically or fixed
               % In original code: N_Assigned_STA = ceil(N_STA/N_RAW);
               N_Assigned_STA = ceil(N_STA/N_RAW);

               for idx_RAW = 1:N_RAW
                   for idx = 1:N_Assigned_STA
                       if isempty(All_User)
                          break;
                       end
                       Temp_Assigned_STA = All_User(ceil(rand*length(All_User)));
                       SimState.List_Assigned_STA(idx_RAW, idx) = Temp_Assigned_STA;
                       All_User(All_User == Temp_Assigned_STA) = [];
                   end
               end

           elseif SimParams.RAW_Mode == 3

               SimState.List_Assigned_STA = zeros(N_RAW, N_STA);

               for j = 1:N_STA
                   if( Node.TX_Buffer(idx_STA(j)).Length > 0 )

                       % Net Congestion Logic
                       if ~isempty(SimState.Net_Congestion_Measure(idx_STA(j)).CH_Util)

                           current_idx = size(SimState.Net_Congestion_Measure(idx_STA(j)).CH_Util, 1);
                           Temp_Bin_CH_Usage =  ceil(SimState.Net_Congestion_Measure(idx_STA(j)).CH_Util(current_idx,2)/SimParams.Bin_CH_Usage)*SimParams.Bin_CH_Usage;
                           Temp_Bin_ACK = ceil(SimState.Net_Congestion_Measure(idx_STA(j)).N_ACK(current_idx,2)/SimParams.Bin_N_ACK)*SimParams.Bin_N_ACK;

                           Temp_Idx_TX_LOG = find(SimParams.TX_LOG(:,1) == Temp_Bin_CH_Usage & SimParams.TX_LOG(:,2) == Temp_Bin_ACK);

                           if isempty(Temp_Idx_TX_LOG)
                               % disp('There is no corresponding data in TX_LOG!');
                               SimState.Cnt_NoLog(idx_STA(j)) = SimState.Cnt_NoLog(idx_STA(j)) + 1;

                               EuclDist = sqrt( (SimParams.Norm_TX_LOG(:,1) - Temp_Bin_CH_Usage/max(SimParams.TX_LOG(:,1))).^2 + (SimParams.Norm_TX_LOG(:,2) - Temp_Bin_ACK/max(SimParams.TX_LOG(:,2))).^2);
                               [minEuclDist, Temp_Idx_TX_LOG] = min(EuclDist);
                           end

                           TX_Prob = SimParams.TX_LOG(Temp_Idx_TX_LOG,11);

                           if SimParams.Enable_TxWeight
                              [PrevTxProb, PrevTxWeight] = Get_PrevTxConfig(idx_STA(j), SimState.Prev_TxConfig);
                              TxWeight = 0; % Init

                              if PrevTxProb == -1 || PrevTxWeight == -1
                                 TxWeight = SimParams.Init_TxWeight;
                              else
                                 [R_Suc] = Calc_SucRatio(idx_STA(j), SimState.Net_Congestion_Measure);
                                 TxWeight = PrevTxWeight;

                                 if R_Suc <= PrevTxProb
                                    TxWeight = TxWeight - SimParams.Dec_TxWeight;
                                    if TxWeight < SimParams.Min_TxWeight
                                       TxWeight = SimParams.Min_TxWeight;
                                    end
                                 elseif R_Suc > PrevTxProb
                                    TxWeight = TxWeight + SimParams.Inc_TxWeight;
                                    if TxWeight > SimParams.Max_TxWeight
                                       TxWeight = SimParams.Max_TxWeight;
                                    end
                                 elseif isnan(R_Suc)
                                    TxWeight = PrevTxWeight;
                                 else
                                     error('unexpected case of variable R_suc!');
                                 end
                              end

                              TX_Prob = TxWeight*TX_Prob;
                              [SimState.Prev_TxConfig] = Set_PrevTxConfig(idx_STA(j), SimState.Prev_TxConfig, TX_Prob, TxWeight);

                              if SimParams.On_Log_TxWeight
                                  NodeID_Log_TxWeight = find(SimParams.Target_Node_Log_TxWeight == idx_STA(j));
                                  if i >= SimState.Next_Measure_Interval_Log_TxWeight && ~isempty(NodeID_Log_TxWeight)
                                     idx_row = SimState.Ptr_EachNodeLog(NodeID_Log_TxWeight);
                                     idx_col = NodeID_Log_TxWeight*3-2;
                                     SimState.Ptr_EachNodeLog(NodeID_Log_TxWeight) = SimState.Ptr_EachNodeLog(NodeID_Log_TxWeight) + 1;

                                     SimState.Log_TxWeight(idx_row, idx_col:idx_col+2) = [i TxWeight TX_Prob];
                                     % Note: We update Next_Measure_Interval_Log_TxWeight only once per interval, but this loop runs per node.
                                     % Logic in original code seems to update it repeatedly? No, it's global variable in loop.
                                     % We should update it outside the loop or check condition carefully.
                                     % For now, I'll update it at the end of function or outside.
                                     % Actually, original code updates it INSIDE the loop. This means it might be incremented multiple times if multiple target nodes are processed?
                                     % Check original code:
                                     % Next_Measure_Interval_Log_TxWeight = Next_Measure_Interval_Log_TxWeight + Measure_Interval_Log_TxWeight;
                                     % This looks like a bug in original code if multiple target nodes exist.
                                     % But let's replicate logic or fix it.
                                     % If I replicate:
                                     % Wait, "if i >= Next..." matches. If updated once, next node won't match. So it's fine.
                                     SimState.Next_Measure_Interval_Log_TxWeight = SimState.Next_Measure_Interval_Log_TxWeight + SimParams.Measure_Interval_Log_TxWeight;
                                  end
                              end
                           end

                           if TX_Prob >= rand
                              SimState.List_Assigned_STA(ceil(N_RAW*rand), j) = idx_STA(j);
                           end
                       else
                            error('There is no TX_Log!');
                       end
                   end
               end

           elseif SimParams.RAW_Mode == 4
              % Legacy RAW
              All_User = [];
              for j = 1:length(idx_STA)
                if Node.TX_Buffer(idx_STA(j)).Length > 0
                   All_User = [All_User;  idx_STA(j)];
                end
              end

              SimState.List_Assigned_STA = zeros(N_RAW, N_STA);

              for idx = 1:length(All_User)
                   Temp_Assigned_RAW_Slot = mod((All_User(idx) + SimParams.N_offset), N_RAW)+1;
                   SimState.List_Assigned_STA(Temp_Assigned_RAW_Slot, idx) = All_User(idx);
              end
           end

           SimState.Tab_RAW = Tab_RAW;
           % update Next Beacon Transmission Time
           SimState.Next_BTT = SimState.Next_BTT + SimParams.Beacon_Interval + (N_RAW-1) + 1;
        end

        % Check RAW Slot Boundaries (CSB Logic)
        % Update Tab_RAW(:,3) status
        if SimParams.On_CSB == 0
            for idx_RAW = 1:SimParams.N_RAW
                if SimState.Tab_RAW(idx_RAW, 1) == i
                    if SimState.Tab_RAW(idx_RAW, 3) ~= 0
                         error('Unexpected RAW STATE!');
                    end
                    SimState.Tab_RAW(idx_RAW, 3) = 1;
                end

                 if SimState.Tab_RAW(idx_RAW, 2) == i
                     if SimState.Tab_RAW(idx_RAW, 3) ~= 1
                         error('Unexpected RAW STATE!');
                     end
                     SimState.Tab_RAW(idx_RAW, 3) = 0;

                     Temp_Channel_State = sum(SimState.tx_state(SimState.Tab_RAW(idx_RAW, 1):SimState.Tab_RAW(idx_RAW, 2), SimParams.idx_AP(1))');
                     idx_last_CH_access_time = find(Temp_Channel_State ~= 0, 1, 'last');

                     if isempty(idx_last_CH_access_time)
                         SimState.List_Remained_Slot = [SimState.List_Remained_Slot; length(Temp_Channel_State)-1 idx_RAW];
                     else
                         SimState.List_Remained_Slot = [SimState.List_Remained_Slot; length(Temp_Channel_State) - find(Temp_Channel_State ~= 0, 1, 'last')-1 idx_RAW];
                     end
                 end
            end
        end
        % CSB=1 logic omitted as it says "not used longer" in original code (but logic was there).
    end
end
