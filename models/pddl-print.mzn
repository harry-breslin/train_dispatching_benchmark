% Solution output in PDDL+ like form for solution validation
%------------------------------------------------------------------------------

% Constants
string: number_ext = ".00000";

% Helper function to get the first block that the train stops
function B union {0}: get_stop_block(R: r) = (
    if r_has_stop[r] then
        let {
            set of B: StopBs = 
                {b | b in r_block_start[r]..r_block_end[r] where b_stop[b]};
        } in 
            if card(StopBs) > 0 then
                min(StopBs)
            else
                0
            endif
    else
        0
    endif
);

% Helper function to get the last block in an itinerary
function B union {0}: get_last_it_block(R: r) = (
    let {
        set of B: LastItBs =
            {b-1 | b in r_block_start[r]+1..r_block_end[r] 
                where b_dur[b-1] + b_start_offset[b] != 0};
    } in
        if card(LastItBs) > 0 then
            min(LastItBs)
        else
            0
        endif
);

% Output scheduled train information
function string: get_scheduled_train_info(T: t) ::output_only;
function string: get_scheduled_train_info(T: t) = 
    let { R: r = fix(v_route[t]) } in
(
    if t_type[t] = origin then
        % Start of train
        show(v_start[t]) ++ number_ext ++ ": (" ++ t_name[t] ++ "_beginsVoy_"
        ++ r_platform_name[r] ++ "_" ++ r_it_1[r] ++ ")\n"
        % End of train
        ++ show(v_end[t]) ++ number_ext ++ ": (" ++ t_name[t] 
        ++ "_exitsStation_" ++ r_it_1[r] ++ ")\n"
    else
        % Start of train
        show(v_start[t]) ++ number_ext ++ ": (" ++ t_name[t] ++ "_entersStation_"
        ++ r_it_1[r] ++ ")\n"
        % Stop
        ++ if r_has_stop[r] /\ r_dwell_min[r] > 0 then
            let {
                B: b = get_stop_block(r);
                int: start = fix(v_start[t]) + b_dur[b] - r_overlap[r];
                int: end = start + fix(v_dwell[t]);
            } in
            % Begin stop
            show(start) ++ number_ext ++ ": (" ++ t_name[t] ++ "_beginStop_"
            ++ r_it_1[r] ++ "_" ++ r_platform_name[r] ++ ")\n"
            ++ if t_type[t] == pass then
                % Start of overlap
                show(end) ++ number_ext ++ ": (" ++ t_name[t] ++ "_overlaps_"
                ++ r_it_1[r] ++ "_" ++ r_it_2[r] ++ ")\n"
            else
                ""
            endif
            % End stop
            % NOTE that "endStop" is an event and therefore does not need to be
            % printed
            %++ show(end) ++ number_ext ++ ": (" ++ t_name[t] ++ "_endStop_"
            %++ r_it_1[r] ++ "_" ++ r_platform_name[r] ++ ")\n"
        elseif t_type[t] == pass then
            let {
                B: b = get_last_it_block(r);
                int: start = fix(v_start[t]) + b_dur[b] - r_overlap[r];
                int: end = start + fix(v_dwell[t]);
            } in
            % Start of overlap
            show(end) ++ number_ext ++ ": (" ++ t_name[t] ++ "_overlaps_"
            ++ r_it_1[r] ++ "_" ++ r_it_2[r] ++ ")\n"
        else
            ""
        endif
        % End
        ++ show(v_end[t]) ++ number_ext ++ ": (" ++ t_name[t] 
        ++ if t_type[t] = pass then
            "_exitsStation_" ++ r_it_2[r]
        else
            % "dest" and "vanish" trains
            "_trainEndsVoy_" ++ r_it_1[r] ++ "_" ++ r_platform_name[r]
        endif
        ++ ")\n"
    endif
);


%------------------------------------------------------------------------------
% Output item

output [
    get_scheduled_train_info(t)
| t in T]
++ [
    "\(fix(v_makespan))" ++ number_ext ++ ": @PlanEND\n"
]

