% It contains a readable solution output, which should make it easier for
% further processing.
%------------------------------------------------------------------------------%
% Options

bool: draw_gantt = false;

%------------------------------------------------------------------------------%

% Short cut for the set of blocks for each edge
array [E] of set of B: e_bs = [ {b | b in B where b_edge[b] = e} | e in E];

%------------------------------------------------------------------------------%
% Helper functions

% Output a textual Gantt chart for edges with present blocks
function string: my_show_textual_gantt(E: e, array [$$T] of var opt int: start, array [$$T] of var int: dur, array [$$T] of string: name) ::output_only;
function string: my_show_textual_gantt(E: e, array [$$T] of var opt int: start, array [$$T] of var int: dur, array [$$T] of string: name) = let {
    set of index_set(start): I = {i | i in index_set(start) where fix(occurs(start[i]))};
    array[int] of int: fix_start = [fix(deopt(start[i])) | i in I];
    array[int] of int: fix_dur = [fix(dur[i]) | i in I];
    array[int] of string: fix_name = [name[i] | i in I];
    array[int] of index_set(fix_start): sort = arg_sort(fix_start);
} in
    if card(I) > 0 then
        "###############################\n"
        ++ "Bit: \(e_name[e])\n"
        ++ "Bit Reserved Times (train, start, end):\n"
        ++ concat(i in index_set(sort))(
            "(\(fix_name[sort[i]]), \(fix_start[sort[i]]), \(fix_start[sort[i]] + fix_dur[sort[i]])), "
        )
        ++ "\n"
    endif;

% Output a visual Gantt chart for edges with present blocks
function string: my_show_gantt(E: e, array [$$T] of var opt int: start, array [$$T] of var int: dur, array [$$T] of string: name) ::output_only;
function string: my_show_gantt(E: e, array [$$T] of var opt int: start, array [$$T] of var int: dur, array [$$T] of string: name) = let {
    set of index_set(start): I = {i | i in index_set(start) where fix(occurs(start[i]))};
} in 
    if card(I) > 0 then
        "*******************************\n"
        ++ "Bit: \(e_name[e])\n"
        ++ show_gantt(
            [deopt(start[i]) | i in I],
            [dur[i] | i in I],
            [name[i] | i in I]
        )
        ++ "\n"
    endif;

%------------------------------------------------------------------------------%
% Output

output [
    "Makespan: \(v_makespan)\n"
]
% Trains
++ [
    if b == r_block_start[b_route[b]] then
        "===============================\n"
        ++ "Train: \(t_name[b_train[b]])\n"
        ++ "Type: \(t_type[b_train[b]])\n"
        ++ "Route: \(r_name[b_route[b]])\n"
        ++ "Platform: \(r_platform_name[b_route[b]])\n"
        ++ "Start: \(v_start[b_train[b]])\n"
        ++ "End: \(v_end[b_train[b]])\n"
        ++ "Dwell Time: \(v_dwell[b_train[b]])\n"
        ++ "Bit Reserved Times (bit, start, end):\n"
    endif
    ++
    "(\(e_name[b_edge[b]]), \(b_vstart[b]), \(b_vstart[b] ~+ b_vdur[b])), "
    ++
    if b == r_block_end[b_route[b]] then
        "\n"
    endif
| b in B where fix(occurs(b_vstart[b]))]
% Segment (Bit) View
++ [
    my_show_textual_gantt(e,
        [b_vstart[b] | b in e_bs[e]], [b_vdur[b] | b in e_bs[e]],
        [t_name[b_train[b]] | b in e_bs[e]]
    )
| e in E]
% Gantt Chart
++ if draw_gantt then 
    [
        my_show_gantt(e,
            [b_vstart[b] | b in e_bs[e]], [b_vdur[b] | b in e_bs[e]],
            [t_name[b_train[b]] | b in e_bs[e]]
        )
    | e in E]
endif

