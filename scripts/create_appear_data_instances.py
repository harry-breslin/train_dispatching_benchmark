"""
Script to generate the data and instance files for appear trains using origin train data in the cp2025 dataset.
Goal is hardcoded for now.
Should be run in the root directory, e.g. `python scripts/create_appear_data_instances.py`.
"""

import os
import subprocess
import glob
import csv

goal = "sat"
data_dir = "appear-cp2025"
input_folder = "data/cp2025"
output_folder = f"data/{data_dir}"
generator_model = "scripts/appear-instance-generator.mzn"
instances_csv = f"data/instances_{goal}_{data_dir}.csv"

os.makedirs(output_folder, exist_ok=True)


def has_origin_train(dzn_path):
    with open(dzn_path, "r") as f:
        return any("t_type" in line and "origin" in line for line in f)


# generate new dzn files
new_instances = []
for dzn_file in glob.glob(os.path.join(input_folder, "*.dzn")):
    if not has_origin_train(dzn_file):
        continue

    out_file = os.path.join(output_folder, f"appear-{os.path.basename(dzn_file)}")
    result = subprocess.run(
        ["minizinc", "--solver", "cp-sat", generator_model, dzn_file], capture_output=True, text=True
    )

    output_lines = result.stdout.rstrip("\n").split("\n")
    truncated_output = (
        "\n".join(output_lines[:-2]) + "\n"
    )  # remove trailing newline and line with ----------, and add newline
    with open(out_file, "w") as f:
        f.write(truncated_output)

    new_instances.append(os.path.basename(out_file))

# create instances csv
with open(instances_csv, "w", newline="") as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=["problem", "model", "data_file"])
    writer.writeheader()

    for instance in new_instances:
        row = {
            "problem": data_dir,
            "model": f"../models/solve_{goal}.mzn:../models/pddl-print.mzn",
            "data_file": f"{data_dir}/{instance}",
        }
        writer.writerow(row)
