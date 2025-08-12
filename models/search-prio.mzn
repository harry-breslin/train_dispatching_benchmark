% NOTE that the priority_search is only supported by Chuffed

include "chuffed.mzn";

search =
    priority_search(
        v_start,
        [ int_search([v_start[t], v_route[t], v_dwell[t]], input_order, indomain_min)
        | t in T],
        smallest,
        indomain_min
    );

