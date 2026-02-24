function Generate_Traffic(SimState, SimParams)

    i = SimState.Time;

    %----------------------------------------
    % Background Traffic Generation
    %----------------------------------------
    if SimParams.N_bkSTA > 0
       idx_STA_Type0 = SimParams.idx_STA_Type0;
       for j = 1:SimParams.N_bkSTA

           idx = idx_STA_Type0(j);

           if SimState.Next_Frame_Interval_bk(idx) <= i

                if rand <= SimParams.Prob_Frame_Generation_bk

                    SimState.GID = SimState.GID + 1;
                    SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;

                    SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_bk(idx) i];
                    SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                end

                % reset configurations for a next arrival frame
                SimState.Next_Frame_Length_bk(idx) = ceil( (SimParams.Range_Frame_Length_bk(2)-SimParams.Range_Frame_Length_bk(1))*rand + SimParams.Range_Frame_Length_bk(1) );
                SimState.Next_Frame_Interval_bk(idx) = i + ceil( (SimParams.Range_Frame_Interval_bk(2)-SimParams.Range_Frame_Interval_bk(1))*rand + SimParams.Range_Frame_Interval_bk(1) );

           end
       end
    end

    %----------------------------------------
    % Alarm Traffic Generation
    %----------------------------------------
    if SimParams.Opt_Start < i && SimParams.Opt_End >= i
        SimState.Prev_Traffic_Event = i;
        idx_STA_Type1 = SimParams.idx_STA_Type1;

        if SimParams.Traffic_Surge_Mode == 1
            if SimParams.Traffic_Gen_Mode == 0
                for j = 1:SimParams.N_alarmSTA
                        idx = idx_STA_Type1(j);
                        if SimState.Next_Frame_Interval_al(idx) <= i
                            if rand <= SimParams.Prob_Frame_Generation_al
                                SimState.GID = SimState.GID + 1;
                                SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;
                                SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_al(idx) i];
                                SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                            end
                            SimState.Next_Frame_Length_al(idx) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                            SimState.Next_Frame_Interval_al(idx) = i + ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                        end
                end

            elseif SimParams.Traffic_Gen_Mode == 1
                if SimState.Next_Frame_Interval_al <= i && rand <= SimParams.Prob_Frame_Generation_al
                   for j = 1:SimParams.N_alarmSTA
                        idx = idx_STA_Type1(j);
                        SimState.GID = SimState.GID + 1;
                        SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;
                        SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_al i];
                        SimState.n_enq(idx) = SimState.n_enq(idx) + 1;

                        % Note: In original code, these next updates were inside loop.
                        SimState.Next_Frame_Length_al = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                        SimState.Next_Frame_Interval_al = i + ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                   end
                end
            end

        elseif SimParams.Traffic_Surge_Mode == 2 || SimParams.Traffic_Surge_Mode == 3

               N_buffered_STAs = floor(SimParams.Tab_Traffic_Model(2, i-SimParams.Opt_Start)) - floor(SimParams.Tab_Traffic_Model(2, SimState.Last_Time));

               if N_buffered_STAs > 0
                   SimState.Last_Time = i-SimParams.Opt_Start;
                   SimState.Measure_Cummulated_N_Triggerd_STAs = [SimState.Measure_Cummulated_N_Triggerd_STAs; i SimState.Measure_Cummulated_N_Triggerd_STAs(SimState.L_Measure_Cummulated_N_Triggerd_STAs,2)+N_buffered_STAs];
                   SimState.L_Measure_Cummulated_N_Triggerd_STAs = SimState.L_Measure_Cummulated_N_Triggerd_STAs +1;

                   Temp_cnt = 0;
                   for idx_N_buffered_STAs=1:SimParams.N_alarmSTA
                       idx = idx_STA_Type1(idx_N_buffered_STAs);

                       if SimState.Node.TX_Buffer(idx).Triggered == 0
                          SimState.Node.TX_Buffer(idx).Triggered = 1;

                          if SimParams.Traffic_Surge_Mode == 2
                              SimState.GID = SimState.GID + 1;
                              SimState.Next_Frame_Length_al(idx) = ceil( (SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                              SimState.Node.TX_Buffer(idx).Length = SimState.Node.TX_Buffer(idx).Length + 1;
                              SimState.Node.TX_Buffer(idx).MPDU = [SimState.Node.TX_Buffer(idx).MPDU; SimState.GID SimState.Next_Frame_Length_al(idx) i];
                              SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                          end

                          Temp_cnt = Temp_cnt + 1;
                          if Temp_cnt == N_buffered_STAs
                             break;
                          end
                       end
                   end

                   if SimParams.Traffic_Surge_Mode == 3
                      for j = 1:SimParams.N_alarmSTA
                        idx = idx_STA_Type1(j);
                        if SimState.Next_Frame_Interval_al(idx) <= i && SimState.Node.TX_Buffer(idx).Triggered == 1
                            if rand <= SimParams.Prob_Frame_Generation_al
                                [SimState.Node.TX_Buffer(idx) SimState.GID] = Enque_MPDU(SimState.Node.TX_Buffer(idx), SimState.GID, SimState.Next_Frame_Length_al(idx), i);
                                SimState.n_enq(idx) = SimState.n_enq(idx) + 1;
                            end
                            SimState.Next_Frame_Length_al(idx) = ceil( ( SimParams.Range_Frame_Length_al(2)-SimParams.Range_Frame_Length_al(1))*rand + SimParams.Range_Frame_Length_al(1) );
                            SimState.Next_Frame_Interval_al(idx) = i + ceil( (SimParams.Range_Frame_Interval_al(2)-SimParams.Range_Frame_Interval_al(1))*rand + SimParams.Range_Frame_Interval_al(1) );
                        end
                     end
                   end
               end
        end
    end
end
