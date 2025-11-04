"""
Script to generate the data and instance files for reverse trains using existing train data in the cp2025 dataset.
Goal is hardcoded for now.
Should be run in the root directory, e.g. `python scripts/create_reverse_data_instances.py`.
"""

import os
import subprocess
import glob
import csv

goal = "sat"
data_dir = "reverse-cp2025"
input_folder = "data/cp2025"
output_folder = f"data/{data_dir}"
generator_script = "scripts/reverse-instance-generator.py"
instances_csv = f"data/instances_{goal}_{data_dir}.csv"

os.makedirs(output_folder, exist_ok=True)


# generate new dzn files
new_instances = []
for dzn_file in glob.glob(os.path.join(input_folder, "*.dzn")):
    out_file = os.path.join(output_folder, f"reverse-{os.path.basename(dzn_file)}")
    result = subprocess.run(["python", generator_script, dzn_file, out_file], capture_output=True, text=True)

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
