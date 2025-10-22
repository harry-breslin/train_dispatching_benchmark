%------------------------------------------------------------------------------%
% Train Scheduling in One Station
%
% TODO Description
%------------------------------------------------------------------------------%
% Assumptions
%
% 1. Travel and dwell (stopping) times can be different between routes for
%   the same train.
% 2. A route describes one path through the station including termination on a
%   platform.
% 3. A train can only stop once during an iter
% 4. A train can halt at the end of an itinerary at a platform.
% 5. Appearing trains cannot have a dwell time of zero.
%
%------------------------------------------------------------------------------%
% Libraries includes

include "assert-tests.mzn";
include "helpers.mzn";
include "alternative.mzn";
include "disjunctive_opt.mzn";
include "cumulative.mzn";

%------------------------------------------------------------------------------%
% Parameters

% Network-related parameters
% Edge types
%   border  - edges that are located at the entrance or exit of the station,
%             i.e., the first and last edge that a train passes when the
%             train fully traverse the station. In other words, the edges
%             are the connecting points to the external railway network
%             (excluding railway yards).
%   platform - edges that are located at a platform of the station
%   inter   - all remaining edges
enum ETypes = {border, inter, platform};

% - Edges (rail segments, e.g., "aa" and "ac")
int: nb_edges;                  % Number of egdes
set of int: E = 1..nb_edges;    % Set of edges
array [E] of string: e_name;    % Name of edge, e.g., "aa"
array [E] of ETypes: e_type;    % Type of edge (needed for redundant constraints)
array [E] of set of int: e_cols;% Column numbers, to which the edge belongs to. 
                                % NOTE that it might be useful for redundant
                                % constraints.

% - Columns (derived parameter from the edges)
int: nb_columns = card(C);      % Number of columns
set of int: C = {               % Set of columns
    c | e in E, c in e_cols[e]};
array [C] of set of E: c_edges =% Set of edges that belongs to a column
    [ {e | e in E where c in e_cols[e]} | c in C ];
array [C] of ETypes: c_type = [get_column_type(c) | c in C];
array [C] of int: c_width = [   % The number of edges in the column
    card(c_edges[c]) | c in C];

% - Nodes (vertices between rail segments)
%   (They might be only needed for references, but not for solving)
%int: nb_nodes;                  % Number of nodes
%set of int: N = 1..nb_nodes;    % Set of nodes
%array [N] of string: n_name;    % Name of node, e.g., "F01" or "" for no name

% Train types
%   dest    - train terminating at the station and blocking their platform for
%             the remaining planning horizon
%   vanish  - train terminating at the station, but vanish when they end their
%             stop, i.e., releasing their platform
%   appear  - train starting at the station, but their platform is empty before
%             that
%   origin  - train starting at the station
%   pass    - train going through the station with or without a stop
%   reverse - train going through the station with or without a stop, but
%             leaving in the same direction as arrival
enum TTypes = {dest, origin, pass, vanish, appear, reverse};

% Train-related parameters
int: nb_trains;                 % Number of trains
set of int: T = 1..nb_trains;   % Set of train ids
array [T] of string: t_name;    % Name of trains
array [T] of set of R: t_routes;% Set of possible routes through the station
array [T] of int: t_est;          % Earliest start time for any route
%array [T] of H: t_lct;          % Latest completion time for any route
                                % NOTE that is not a problem description parameter
%array [T] of H: t_dur_max;      % * Maximal duration in the station
                                % NOTE that is not a problem description parameter
array [T] of TTypes: t_type;    % The type of the train
array [T] of E: t_edge_start = [
    b_edge[r_block_start[min(t_routes[t])]]
| t in T];

% Routes (a route is unique to one train)
int: nb_routes;                 % Number of routes
set of int: R = 1..nb_routes;   % Set of route ids
array [R] of string: r_name;    % Name of the route
array [R] of string: r_it_1;    % Name of first itinerary
array [R] of string: r_it_2;    % Name of second itinerary
array [R] of string: r_platform_name;   % Platform name
array [R] of int: r_dwell_min;  % Minimal dwell (stop) time in station 
                                % NOTE that if the dwell times are independent of
                                % the routes (platforms) then these times should be
                                % a characteristics of trains.
%array [R] of int: r_dwell_max;  % Maximal dwell time in station (0 if no dwell time/no stop)
                                % NOTE that there is no maximal dwell time in
                                % the problem description
                                % NOTE 
array [R] of int: r_dur_min;    % Duration of route without dwell time
array [R] of int: r_overlap;    % Overlapping time between two itineraries
                                % NOTE that this time is already accounted for in 'b_dur'
array [R] of B: r_block_start;  % First block id in the route
array [R] of B: r_block_end;    % Last block id in the route
array [R] of T: r_train;        % The train id the route belongs to
array [R] of bool: r_has_stop = [ 
    exists(b in r_block_start[r]..r_block_end[r])(b_stop[b])
| r in R];

% Blocks (a block is unique to one routes and corresponds to one edge)
int: nb_blocks;
set of int: B = 1..nb_blocks;
array [B] of E: b_edge;         % The corresponding edge
array [B] of 0..time_dur: b_dur;% The duration the needs to be reserved excluding dwell time
array [B] of -time_dur..time_dur: b_start_offset;
                                % The start time offset for reserving the block with
                                % regards to the end time of the previous block, i.e.,
                                % start[b] = end[b - 1] + b_start_offset[b].
                                % If the block is the first in the route then the
                                % offset is set to 0.
array [B] of bool: b_stop;      % Whether the block contains the dwell time of the
                                % stop
array [B] of R: b_route;        % The route id the block belongs to
array [B] of T: b_train =       % The train id the block belongs to
    [r_train[b_route[b]] | b in B];

% Planning horizon
int: time_start = min(t_est);   % Start time of the planning horizon derived by the 
                                % earliest start time of all trains
int: time_end = compute_upper_bound(T);
int: time_dur = time_end - time_start;
set of int: H = time_start..time_end;
set of int: D = 0..time_dur;

%------------------------------------------------------------------------------%
% Variables
%------------------------------------------------------------------------------%

% Decision variables
array [T] of var H: v_start;    % Start time of the train
array [T] of var R: v_route;    % Route of the train
array [T] of var D: v_dwell;    % Dwell time of the train

% Derived duration and end variable
array [T] of var D: v_dur = [ r_dur_min[v_route[t]] + v_dwell[t] | t in T ];
array [T] of var H: v_end = [ v_start[t] + v_dur[t] | t in T ];

% Variables related to blocks
array [B] of var opt H: b_vstart;
array [B] of var D: b_vdur = [
    b_dur[b] + if b_stop[b] then 
    v_dwell[b_train[b]] else 0 endif 
| b in B];
%arary [B] of var opt H: b_vend = [b_vstart[b] + b_vdur[b] | b in B];

% Variables related to the columns/routes

% Makespan
% var H: v_makespan = max(v_end);
var H: v_makespan ::output = max(v_end);
int: v_end_sum ::output_only ::output = sum(fix(v_end));

%------------------------------------------------------------------------------%
% Constraints
%------------------------------------------------------------------------------%

    % Domain restricting constraints
constraint forall(t in T)(
    % Earliest start/entry time at station
    t_est[t] <= v_start[t]
    % Latest completion/exit time at/from station
%/\  v_end[t] <= t_lct[t]
    % Minimal route number
/\  min(t_routes[t]) <= v_route[t]
    % Maximal route number
/\  v_route[t] <= max(t_routes[t])
    % Minimal dwell times
/\  min([r_dwell_min[r] | r in t_routes[t]]) <= v_dwell[t]
    % Maximal dwell times
/\  if t_type[t] = vanish then
        % Vanish trains disappear after they end their stop. Thus, w.l.o.g. we
        % can restrict their dwell time to the minimal one for the selected
        % route.
        v_dwell[t] <= max([r_dwell_min[r] | r in t_routes[t]])
    elseif t_type[t] = origin then
        v_dwell[t] = 0
    else
        v_dwell[t] <= time_end
    endif
);

%% Option 1
%constraint forall(t in T)(
%    alternative(v_start[t], v_dur[t],
%        [ b_vstart[r_block_start[r]] | r in t_routes[t] ],
%        [ r_dur_min[r] + v_dwell[t] | r in t_routes[t] ]
%    )
%);

% Option 2
constraint forall(t in T, r in t_routes[t])(
    v_route[t] == r -> v_start[t] = b_vstart[r_block_start[r]]
);

constraint forall(t in T, r in t_routes[t])(
    v_route[t] == r -> (
        r_dwell_min[r] <= v_dwell[t]
    /\  if not(r_has_stop[r]) then
            v_dwell[t] = 0
        else
            true
        endif
    )
);

% Formulation one
% The constraint enforces the presence/occurrence of the first block start time variable
% for the chosen route
constraint forall(t in T, r in t_routes[t])(
    v_route[t] == r <-> occurs(b_vstart[r_block_start[r]])
);

% Formulation two
% The constraint enforces the presence/occurrence of the first block start time variable
% for the chosen route
% NOTE that this contraint might not be equivalent to the above one!
%constraint forall(t in T)(
%    occurs(b_vstart[r_block_start[v_route[t]]])
%);

% Linking the presence of the individual block start time variables together
constraint forall(r in R, b in (r_block_start[r]+1)..r_block_end[r])(
    occurs(b_vstart[b]) = occurs(b_vstart[b - 1])
);

% Linking blocks in a route:
% Here we handle the situation stops at the platform, the start time
% of next block depends on the operation of the previous block.
constraint forall(t in T, r in t_routes[t], b in (r_block_start[r]+1)..r_block_end[r])(
    let {
        int: b0 = b - 1;
    } in (
        % Differentiating the cases
        % NOTE that we have to use the weaker arithmetic versions prefixed by'~';
        % otherwise it is a model inconsistency. For example, "<> + 3 = 3" 
        % whereas "<> ~+ 3 = <>" where "<>" is an absent optional variable.
        if b_stop[b0] = false then
            % No stop at b0
            %b_vstart[b] = b_vend[b0] ~+ b_start_offset[b]
            b_vstart[b] = b_vstart[b0] ~+ b_dur[b0] ~+ b_start_offset[b]
        elseif b_stop[b] = false then
            % Stop at b0 and no stop at b
            %b_vstart[b] = b_vend[b0] ~+ b_start_offset[b]
            b_vstart[b] = b_vstart[b0] ~+ b_dur[b0] ~+ v_dwell[t] ~+ b_start_offset[b]
        else
            % Stop at b0 and b
            b_vstart[b] = b_vstart[b0] ~+ b_dur[b0] ~+ b_start_offset[b]
        endif
    )
);

% Train order constraints on the entry of the station
set of E: Entries = { t_edge_start[t] | t in T where t_type[t] != origin };
constraint forall(e in Entries)(
    let {
        set of T: Tes = {t | t in T where t_edge_start[t] = e};
        array [int] of T: te_id = [t | t in Tes];
        array [int] of int: te_est = [t_est[t] | t in Tes];
        array [int] of T: te_sort = arg_sort(te_est);
    } in (
        forall(i in index_set(te_sort) where i < max(index_set(te_sort)))(
            v_start[te_id[te_sort[i]]] <= v_start[te_id[te_sort[i+1]]]
        )
    )
);


% Disjunctive for segments
% train types (for those that begin in the station and those that end in the
% station)
constraint forall(e in E)(
    let {
        set of B: B_e = {b | b in B where b_edge[b] = e}
    } in (
        if card(B_e) > 0 then
            disjunctive(
                % Start variables
                [   if b_stop[b] /\ t_type[b_train[b]] == origin then
                        % Train begins its journey at the platform. Thus, the edge
                        % must be blocked since the beginning of the time horizon
                        occurs(b_vstart[b]) ~* time_start
                    else
                        % Edge must be blocked at the start time of the block
                        b_vstart[b]
                    endif
                | b in B_e],
                % Duration variables
                [   if b_stop[b] /\ t_type[b_train[b]] == origin then
                        % Train begins its journey at the platform. Thus, the
                        % platform is not available for another train before
                        % the train departs from the platform.
                        b_vdur[b] + (b_vstart[b] - time_start)
                    elseif b_stop[b] /\ t_type[b_train[b]] == dest then
                        % Train ends its journey at the platform. Therefore, the
                        % platform is not available for any other train during
                        % the remaining planning horizon.
                        b_vdur[b] + time_end
                    else
                        % Edge must be blocked for its entire duration incl.
                        % block duration and dwell time
                        b_vdur[b]
                    endif
                | b in B_e]
            )
        else
            true
        endif
    )
);

%------------------------------------------------------------------------------%
% Redundant disjunctive and cumulative constraints

% Column options:
%   0 - No redundant constraints
%   1 - Redundant constraints for all columns
%   2 - Redundant constraints for columns of type 'border' and 'platform'
%   3 - Redundant constraints for columns of type 'platform'
%   4 - Redundant constraints for columns of type 'border'
opt int: col_opt;
int: col_option = col_opt default 0;

constraint
    if col_option = 1 then
        let {
            % 't_col_len' is the highest number of columns that a route goes through for each train
            array [T] of int: t_col_len = [
                max([r_block_end[r] - r_block_start[r] | r in t_routes[t]]) + 1
                | t in T];
            % The start index of a column route
            array [T] of int: t_col_start = [
                sum([t_col_len[t1] | t1 in 1..t-1]) + 1 | t in T];
            % The end index of a column route
            array [T] of int: t_col_end = [
                t_col_start[t] + t_col_len[t] - 1 | t in T];
            % The reference route of a column route
            array [T] of R: t_col_ref = [
                min([r | r in t_routes[t]
                    where r_block_end[r] - r_block_start[r] + 1 = t_col_len[t]])
                | t in T];
            % The number of columns over all column routes
            int: nb_col_routes = max(t_col_end);
            set of int: CR = 1..nb_col_routes;
            % The column of the column route
            array [CR] of C: cr_col = [
                min(e_cols[b_edge[ cr - t_col_start[t] + r_block_start[t_col_ref[t]] ]])
                | t in T, cr in t_col_start[t]..t_col_end[t]];
            % All blocks from the routes that belong to the same column
            array [CR] of set of B: cr_blocks = [
                { b | r in t_routes[t], b in r_block_start[r]..r_block_end[r]
                    where cr_col[cr] in e_cols[b_edge[b]]
                    }
                | t in T, cr in t_col_start[t]..t_col_end[t]];
            % Trains
            array [CR] of T: cr_train =
                [ t | t in T, cr in t_col_start[t]..t_col_end[t] ];
            % Stops
            array [CR] of bool: cr_stop =
                [ exists(b in cr_blocks[cr])(b_stop[b]) | cr in CR ];
            % The start time of the column routes
            array [CR] of var H: cr_vstart;
            % The duration of the column routes
            array [CR] of var D: cr_vdur;
            % The number of trains using the column
            array [C] of int: c_nb_trains = [
                card({cr | cr in CR where cr_col[cr] = c}) | c in C];
        } in
            true
            % Linking constraints
        /\  forall(t in T, cr in t_col_start[t]..t_col_end[t])(
                % Linking the start variable of the column route to the train
                if cr = t_col_start[t] then
                    cr_vstart[cr] = v_start[t]
                endif
                % Linking the end variable of the column route to the train
            /\  if cr = t_col_end[t] then
                    cr_vstart[cr] + cr_vdur[cr] = v_end[t]
                endif
                % Linking the start and duration variables of the column routes 
                % to their corresponding block variables 
            /\  alternative(cr_vstart[cr], cr_vdur[cr],
                    [ b_vstart[b] | b in cr_blocks[cr] ],
                    [ b_vdur[b]   | b in cr_blocks[cr] ]
                )
                % Imposing a minimum duration on the duration variable of the
                % column routes (might be redundant to the alternative 
                % constraint)
            /\  min([
                    b_dur[b] 
                    + if b_stop[b] then r_dwell_min[b_route[b]] else 0 endif
                | b in cr_blocks[cr]])
                <= cr_vdur[cr]
        )
        /\  forall(c in C where c_nb_trains[c] > c_width[c])(
                let {
                    set of CR: CR_col = {cr | cr in CR where cr_col[cr] = c};
                } in (
                    cumulative(
                        [   if cr_stop[cr] /\ t_type[cr_train[cr]] == origin then
                                time_start
                            else
                                cr_vstart[cr]
                            endif
                        | cr in CR_col],
                        [   if cr_stop[cr] /\ t_type[cr_train[cr]] == origin then
                                cr_vdur[cr] + (cr_vstart[cr] - time_start)
                            elseif cr_stop[cr] /\ t_type[cr_train[cr]] == dest then
                                cr_vdur[cr] + time_end
                            else
                                cr_vdur[cr]
                            endif
                        | cr in CR_col],
                        [1 | cr in CR_col],
                        c_width[c]
                    )
                )
        )
    elseif col_option == 2 then
        forall(c in C where c_type[c] == border \/ c_type[c] == platform)(
            post_redundant_cumu(c)
        )
    elseif col_option == 3 then
        forall(c in C where c_type[c] == platform)(
            post_redundant_cumu(c)
        )
    elseif col_option == 4 then
        forall(c in C where c_type[c] == border)(
            post_redundant_cumu(c)
        )
    else
        true
    endif;

%------------------------------------------------------------------------------%
% Search annotations and other related options

ann: search;    % Search annotations are defined in separated files.

opt int: restart_opt;
int: restart_option = restart_opt default 0;

ann: restart =
    if restart_option = 1 then
        restart_geometric(1.5, 100)
    endif;

%------------------------------------------------------------------------------%
% Ouput

% NOTE that a specific output format needs to be added to the MiniZinc command,
% e.g., $ minizinc <main-model>.mzn <output-format>.mzn <instance>.dzn

