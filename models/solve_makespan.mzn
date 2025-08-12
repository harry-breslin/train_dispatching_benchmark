%------------------------------------------------------------------------------%
% Minimisation problem of the makespan, i.e., the latest end time of a train.
%------------------------------------------------------------------------------%

include "train-sched.mzn";

solve
    :: search
    :: restart
    minimize v_makespan;

