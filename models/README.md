# Organisations

The MiniZinc models are divided in multiple files, which are grouped in `Model`, `Goal`, `Search`, and `Print` as follows.
- `Model`: base model files
    - `train-sched.mzn`: Base train model
    - `assert-tests.mzn`: Assertion test for checking assumption about the instance data file.
    - `helpers.mzn`: Useful functions for keeping the base train scheduling model tidy.
- `Goal`: optimisation and satisfaction solution goals
    - `solve_sat.mzn`: Finding first solution
    - `solve_makespan.mzn`: Minimising the makespan (latest end time of a train)
    - `solve_endtimes.mzn`: Minimising the sum of end times of the trains
- `Search`: search strategies' implementations
    - `search-std.mzn`: Standard search (all start times -> all routes -> all dwell times)
    - `search-fo-prio.mzn`: Fixed-order search (all train triplets (start time, route, dwell time) in a fixed train order)
    - `search-prio`: Same as fixed-order search, but train order is dynamic and depends on the smallest value in the train's start-time domain
- `Print`: solution output format
    - `def-print.mzn`: Printing main variables in MiniZinc format.
    - `pddl-print.mzn`: Printing the solution in PDDL+-like format. Note that a post-process is required for converting it to PDDL+ format.
    - `pretty-print.mzn`: Printing the solution in a nice readable format for (bash) terminals.

In addition, the model has following options.
- `col_opt`: Redundant constraints over columns
    - `0` (default): For no column.
    - `1`: For all columns.
    - `2`: For border and platform columns.
    - `3`: For platform columns.
    - `4`: For border columns.
- `restart_opt`: Restart options for the search strategies.
    - `0` (default): No restart.
    - `1`: Geometric restart with base `100` and factor `1.5`.

To solve an instance with the model, one need to execute as follow.

```
minizinc [-D "col_opt=<int>;restart_opt=<int>;" <Goal>.mzn [<Search>.mzn] [<Print>.mzn] <instance>.dzn
```

