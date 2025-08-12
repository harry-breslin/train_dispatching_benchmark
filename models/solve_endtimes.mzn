%------------------------------------------------------------------------------%
% Minimisation problem of the sum of end times
%------------------------------------------------------------------------------%

include "train-sched.mzn";

solve
    :: search
    :: restart
    minimize sum(v_end);

