%------------------------------------------------------------------------------%
% Helper Predicates and Functions
%------------------------------------------------------------------------------%
% Computing a lower bound on the latest completion time of tasks on a machine

function int: compute_upper_bound(set of T: Trains) =
    let {
        int: max_est_origin = 
            max({0} union {t_est[t] | t in Trains where t_type[t] = origin});
        int: max_est_pass =
            max({0} union {t_est[t] | t in Trains where t_type[t] = pass \/ t_type[t] = vanish});
        array[int] of int: est = [
            if t_type[t] = origin then
                t_est[t]
            elseif t_type[t] = pass \/ t_type[t] = vanish then
                max(max_est_origin + 1, t_est[t])
            else
                max([max_est_origin + 2, max_est_pass + 1, t_est[t]])
            endif
            | t in Trains];
        array[int] of int: dur = [
            max([r_dur_min[r] + r_dwell_min[r] | r in t_routes[t]])
            | t in Trains];
    } in (
        lct_disjunctive(est, dur)
    );

function int: lct_disjunctive(array [int] of int: s, array [int] of int: d) = 
    let {
        % Retrieve ordered indices sorted in non-decreasing order of "s"
        array [int] of int: p = arg_sort(s);
        % Get maximal index number (Note that MiniZinc arrays are 1-indexed!)
        int: p_max = max(index_set(p));
    } in (
        % Computing the latest completion time
        lct_disjunctive_aux(s, d, p, 1, p_max)
    );

function int: lct_disjunctive_aux(array [int] of int: s, array [int] of int: d,
    array [int] of int: p, int: p_min, int: p_max) = 
    if p_min = p_max then
        s[p[p_max]] + d[p[p_max]]
    else
        let {
            % Compute the latest completion time for all earlier tasks before
            % task p[p_max]. That completion time is the earliest start time
            % for task p[p_max] unless the start time s[p_max] is greater.
            int: est = lct_disjunctive_aux(s, d, p, p_min, p_max - 1);
        } in (
            max(est, s[p[p_max]]) + d[p[p_max]]
        )
    endif;
        
%------------------------------------------------------------------------------%
% Computing the type of a column

function ETypes: get_column_type(C: c) =
    let {
        set of ETypes: CTypes = {e_type[e] | e in c_edges[c]};
    } in (
        if platform in CTypes then
            platform
        elseif border in CTypes then
            border
        else
            inter
        endif
    );


%------------------------------------------------------------------------------%
% Redundant constraints for border egdes

predicate post_redundant_cumu(C: c) = (
    let {
        % Set of all blocks in the column 'c'
        set of B: CB = {b | b in B where b_edge[b] in c_edges[c]};
        % Set of all trains passing the column 'c'
        set of T: CT = {b_train[b] | b in CB};
    } in if card(CT) > c_width[c] then
        let {
            % Index set
            set of int: CI = 1..card(CT);
            array [CI] of CT: ct_train = [t | t in CT];
            % Set of all blocks for each train
            array [CI] of set of B: ct_blocks =
                [ {b | b in CB where b_train[b] = ct_train[i]} | i in CI];
            % Has stop
            array [CI] of bool: ct_stop =
                [ exists(b in ct_blocks[i])(b_stop[b]) | i in CI ];
            % The start time variables for the master tasks
            array [CI] of var H: ct_vstart;
            % The duration variables for the master tasks
            array [CI] of var D: ct_vdur;
        } in (
            true
            % Linking the master task variables
        /\  forall(i in CI)(
                % Linking the start variable of the train to the master start time
                if r_block_start[ b_route[ min(ct_blocks[i]) ] ]
                                                == min(ct_blocks[i])
                   /\ (c_type[c] == border \/ c_type[c] == platform)
                then
                    ct_vstart[i] = v_start[ ct_train[i] ]
                endif
                % Linking the end variable of the train to the master start time and duration
            /\  if r_block_end[ b_route[ min(ct_blocks[i]) ] ]
                                                == min(ct_blocks[i])
                   /\ c_type[c] == border
                then
                    ct_vstart[i] + ct_vdur[i] = v_end[ ct_train[i] ]
                endif
                % Linking the master task variables to the block variables
            /\  alternative(ct_vstart[i], ct_vdur[i],
                    [ b_vstart[b] | b in ct_blocks[i] ],
                    [ b_vdur[b]   | b in ct_blocks[i] ]
                )
                % Imposing a minimum duration on the master duration variable (this might
                % be redundant to the alternative constraint)
            /\  min([
                    b_dur[b]
                    + if b_stop[b] then r_dwell_min[b_route[b]] else 0 endif
                | b in ct_blocks[i]
                ])
                <= ct_vdur[i]
            )
                % Set cumulative constraint for the column
            /\  cumulative(
                    [   if ct_stop[i] /\ t_type[ct_train[i]] == origin then
                            time_start
                        else
                            ct_vstart[i]
                        endif
                    | i in CI],
                    [   if ct_stop[i] /\ t_type[ct_train[i]] == origin then
                            ct_vdur[i] + (ct_vstart[i] - time_start)
                        elseif ct_stop[i] /\ t_type[ct_train[i]] == dest then
                            ct_vdur[i] + time_end
                        else
                            ct_vdur[i]
                        endif
                    | i in CI],
                    [1            | i in CI],
                    c_width[c]
                )
        )
    endif
);

%------------------------------------------------------------------------------%

