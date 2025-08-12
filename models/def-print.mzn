%------------------------------------------------------------------------------%
% Default output for the solutions
%------------------------------------------------------------------------------%


output [
    "v_makespan = \(v_makespan);\n",
    "v_start = \(v_start);\n",
    "v_route = \(v_route);\n",
    "v_dwell = \(v_dwell);\n",
    "b_vstart = \(b_vstart);\n",
    "b_vend = \([b_vstart[b] ~+ b_vdur[b] | b in B]);\n",
    "r_has_stop = \(r_has_stop);\n",
];

