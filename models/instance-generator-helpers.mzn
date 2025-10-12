%------------------------------------------------------------------------------%
% Helper Predicates and Functions
% 
% Identical to helpers.mzn except for the removal of post_redundant_cumu
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

