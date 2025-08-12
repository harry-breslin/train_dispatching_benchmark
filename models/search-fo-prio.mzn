% The fixed-order priority search tries to mimick the priority search but 
% with a fixed order of trains in ascending order of their earliest start
% time 't_est'.

array [T] of T: t_o = arg_sort(t_est);

search = int_search(
    [ [v_start[t_o[i]], v_route[t_o[i]], v_dwell[t_o[i]]][j]
    | i in T, j in 1..3 ],
    input_order, indomain_min);

