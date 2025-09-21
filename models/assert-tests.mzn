%------------------------------------------------------------------------------%
% This model file contains different assertion (consistency) tests.
%------------------------------------------------------------------------------%

% The route ids for trains are consecutive numbers.
constraint forall(t in T)(
    let {
        set of R: Cont = min(t_routes[t])..max(t_routes[t]);
    } in (
        assert(t_routes[t] = Cont, "The set of routes (\(t_routes[t])) for the train \(t) is not an integer continuous one!\n")
    )
);

% All routes for a train start at the same block
constraint forall(t in T)(
    let {
        set of E: Es = { b_edge[r_block_start[r]] | r in t_routes[t] }
    } in (
        assert(card(Es) = 1, "The routes for the train \(t) do not start with the same edge \(Es)!\n")
    )
);

% Appearing trains cannot have a dwell time of zero
constraint forall(t in T where t_type[t] = appear) (
    let {
        set of int: Ds = { r_dwell_min[r] | r in t_routes[t] }
    } in (
        assert(forall(d in Ds)(d > 0), "Appearing train \(t) has a dwell time of zero!\n")
    )
);
