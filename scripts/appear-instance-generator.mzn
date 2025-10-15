%------------------------------------------------------------------------------%
% Instance generator for appear trains using origin trains
%
% Each origin train in the input is replaced by an appear train, and the dwell
% time is set to 1 if it was 0.
%------------------------------------------------------------------------------%
% Libraries included

include "instance-generator-helpers.mzn";

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
% Output

array[T] of TTypes: t_type_new = [ if t_type[t] = origin then appear else t_type[t] endif | t in T ];
array[R] of int: r_dwell_min_new = [ if t_type_new[r_train[r]] = appear /\ r_dwell_min[r] = 0 % appear trains cannot have 0 dwell time
    then 1 else r_dwell_min[r] endif | r in R ];

output [
  "nb_edges = \(nb_edges);\n",
  "e_name = \(e_name);\n",
  "e_type = \(e_type);\n",
  "e_cols = ", show_sets(e_cols), ";\n",
  "nb_trains = \(nb_trains);\n",
  "t_name = \(t_name);\n",
  "t_routes = ", show_sets(t_routes), ";\n",
  "t_est = \(t_est);\n",
  "t_type = \(t_type_new);\n",
  "nb_routes = \(nb_routes);\n",
  "r_name = \(r_name);\n",
  "r_it_1 = \(r_it_1);\n",
  "r_it_2 = \(r_it_2);\n",
  "r_platform_name = \(r_platform_name);\n",
  "r_dwell_min = \(r_dwell_min_new);\n",
  "r_dur_min = \(r_dur_min);\n",
  "r_overlap = \(r_overlap);\n",
  "r_block_start = \(r_block_start);\n",
  "r_block_end = \(r_block_end);\n",
  "r_train = \(r_train);\n",
  "nb_blocks = \(nb_blocks);\n",
  "b_edge = \(b_edge);\n",
  "b_dur = \(b_dur);\n",
  "b_start_offset = \(b_start_offset);\n",
  "b_stop = \(b_stop);\n",
  "b_route = \(b_route);\n",
];