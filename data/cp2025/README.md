# Dataset `cp2025` Information

This dataset `cp2025` was created and used in the paper.

Each file contains one instance and its filename has a specific format,
which reflects the size of the instance.
The format is as follows
```
tTTT-II.dzn
```
where `TTT` provides the number of trains with at least three digits
and `II` the instance number with at least two digits for instances
with the same number of trains.

In the paper, we distinguish trains with 1 to 19 trains and 20 to 50
trains. Thus, instances with a filename where `0 < TTT < 20` belonging to the first
set (e.g., `t003-02.dzn` and `t017-05.dzn`) and `19 < TTT < 51` belonging to the
second set (e.g., `t050-01.dzn`).
