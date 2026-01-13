Dedicated to underscore_x personally and to the entire global public domain collectively.

---

# PokerVis chart plotter

Parses PokerNow session logs to chart net chips per player over hands.

## Environmental requirements

- CRuby v3.2.2
- Gnuplot v6.0.4

Any versions may work — these just have been tested.

## Usage

Pattern:
```shell
ruby <path_to_main.rb> <path_to_log_file>
```

Example:
```shell
ruby ~/git_clone_zoo/pokerviz/main.rb ./poker_now_log_pglaJpG5HaabwUprNa2rbacub.csv
```

## Output

Gnuplot's Qt preview window opens and two files are written in the working directory immediately, overwriting on filename collisions without confirmation:
- `./[ID].svg`. Losslessly scalable.
- `./[ID].jpg`. Compessed raster preview.

Where `[ID]` is taken from the input CSV log filename, such as `pglaJpG5HaabwUprNa2rbacub` from `poker_now_log_pglaJpG5HaabwUprNa2rbacub.cs`.

## Misc.

No inputs or other files are modified.

Clearly, not my cleanest work.

More caveats detailed at the top of `main.rb`.
