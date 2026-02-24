function Stats = Calc_Stats(SimState, SimParams)

    N_Node = SimParams.N_Node;
    N_STA = SimParams.N_STA;
    T_slot = SimParams.T_slot;
    idx_STA = SimParams.idx_STA;

    % Access Stats
    Stats.n_access = SimState.n_access;

    % Plot Cumulative Triggered STAs
    figure;
    hold on;
    plot(SimState.Measure_Cummulated_N_Triggerd_STAs(:,1), SimState.Measure_Cummulated_N_Triggerd_STAs(:,2),'.');
    title('Cumulative Triggered STAs');
    hold off;

    Diff_Measure_Cummulated_N_Triggerd_STAs = SimState.Measure_Cummulated_N_Triggerd_STAs(2:length(SimState.Measure_Cummulated_N_Triggerd_STAs(:,2)),2) ...
                                            - SimState.Measure_Cummulated_N_Triggerd_STAs(1:length(SimState.Measure_Cummulated_N_Triggerd_STAs(:,2))-1,2);
    figure;
    hold on;
    plot(SimState.Measure_Cummulated_N_Triggerd_STAs(2:length(SimState.Measure_Cummulated_N_Triggerd_STAs(:,2)),1), Diff_Measure_Cummulated_N_Triggerd_STAs);
    title('Differential Triggered STAs');
    hold off;

    % Delay Stats
    Avg_Delay = zeros(N_Node, 3);
    Avg_AccessDelay = zeros(N_Node, 3);
    cnt_empty_delay_measure = 0;

    for j = 1:N_Node
        if (isempty(SimState.Delay(j).delay))
            cnt_empty_delay_measure = cnt_empty_delay_measure + 1;
        else
            L_Delay_Data = length(SimState.Delay(j).delay(:,1));
            if L_Delay_Data == 1
                SimState.Delay(j).delay(1,4) =  SimState.Delay(j).delay(1,3);
            else
                SimState.Delay(j).delay(:,4) = SimState.Delay(j).delay(:,2)-[0;SimState.Delay(j).delay(1:L_Delay_Data-1,2)];
                SimState.Delay(j).delay(1,4) =  SimState.Delay(j).delay(1,3);
            end
            Avg_Delay(j, :) = [nanmean(SimState.Delay(j).delay(:,3))*T_slot nanmin(SimState.Delay(j).delay(:,3))*T_slot nanmax(SimState.Delay(j).delay(:,3))*T_slot];
            Avg_AccessDelay(j,:) = [nanmean(SimState.Delay(j).delay(:,4))*T_slot nanmin(SimState.Delay(j).delay(:,4))*T_slot nanmax(SimState.Delay(j).delay(:,4))*T_slot];
        end
    end

    Stats.cnt_empty_delay_measure = cnt_empty_delay_measure;
    Stats.Avg_Delay = Avg_Delay;

    % Throughput & Fairness
    if SimParams.Opt_Start == 0 && SimParams.Opt_End == SimParams.N_slot
        Temp_Solve_Time = SimParams.N_slot;
    else
        Idx_Solved_Time = find(SimState.Traffic_Temporal_Evolution(find(SimState.Traffic_Temporal_Evolution(:,1) > SimParams.Opt_End),6)==0,1);
        Temp_Solve_Time = SimState.Traffic_Temporal_Evolution(find(SimState.Traffic_Temporal_Evolution(:,1) > SimParams.Opt_End),1);
        if ~isempty(Idx_Solved_Time)
             Temp_Solve_Time = Temp_Solve_Time(Idx_Solved_Time);
        else
             Temp_Solve_Time = SimParams.Opt_End; % Fallback
        end
    end
    % Force overwrite as in original
    Temp_Solve_Time = SimParams.Opt_End;

    per_user_th = (SimState.L_success * 8) / ((SimParams.N_slot)*T_slot) / 10^6;  % Mb/s
    total_th = sum(SimState.L_success * 8) / ((SimParams.N_slot)*T_slot) / 10^6;
    normalized_th = total_th/(SimParams.R_data(1)*10^-6);
    fairness_index = total_th^2 / (N_STA * sum(per_user_th.*per_user_th));

    Stats.total_th = total_th;
    Stats.normalized_th = normalized_th;
    Stats.fairness_index = fairness_index;

    % Collision & Loss
    avg_collision_ratio = [nanmean(SimState.n_collision(idx_STA)./SimState.n_access(idx_STA)) nanmean(SimState.n_collision2(idx_STA)./SimState.n_access(idx_STA))];
    avg_n_access = mean(SimState.n_access(idx_STA));
    avg_success_ratio = [nanmean(SimState.n_success(idx_STA)./SimState.n_access(idx_STA)) nanmean(SimState.n_success2(idx_STA)./SimState.n_access(idx_STA))];

    loss_ratio = SimState.n_loss(idx_STA)./SimState.n_enq(idx_STA);
    avg_loss_ratio = nanmean(loss_ratio);
    avg_loss = mean(SimState.n_loss(idx_STA));

    Stats.avg_collision_ratio = avg_collision_ratio;
    Stats.avg_n_access = avg_n_access;
    Stats.avg_success_ratio = avg_success_ratio;
    Stats.avg_loss_ratio = avg_loss_ratio;

    % Result Set
    Stats.RESULT_SET2 = [total_th normalized_th avg_n_access avg_success_ratio avg_collision_ratio avg_loss_ratio avg_loss mean(Avg_Delay)];

    % Print
    disp('Statistics:');
    disp(Stats.RESULT_SET2);

    if(SimParams.RAW_Mode == 3)
        disp('Count No Log:');
        disp(sum(SimState.Cnt_NoLog));
        disp(mean(SimState.Cnt_NoLog(2:N_Node)));
    end

    if SimParams.On_Save_TX_Log
         % Unpack variables required by Anal_Congestion_Log script
         Net_Congestion_Measure = SimState.Net_Congestion_Measure;
         On_Save_TX_Log = SimParams.On_Save_TX_Log;
         N_alarmSTA = SimParams.N_alarmSTA;
         N_bkSTA = SimParams.N_bkSTA;
         if isfield(SimParams, 'N_RAW')
            N_RAW = SimParams.N_RAW;
         else
            N_RAW = SimParams.Opt_N_RAW;
         end
         C = SimParams.Opt_Slot_Duration_Count;

         Anal_Congestion_Log;
    end

end
