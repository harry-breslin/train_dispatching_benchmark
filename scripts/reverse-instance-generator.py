import re
import sys
from pathlib import Path


def parse_parameter(text, name):
    m = re.search(rf"{name}\s*=\s*(\[[^\]]*\]|[^;]+?)\s*;", text, re.M | re.S)
    if not m:
        return None
    val = m.group(1)
    val = val.replace("false", "False").replace("true", "True")
    val = val.replace("border", "'border'").replace("platform", "'platform'").replace("inter", "'inter'")
    val = (
        val.replace("pass", "'pass'")
        .replace("appear", "'appear'")
        .replace("origin", "'origin'")
        .replace("vanish", "'vanish'")
        .replace("dest", "'dest'")
        .replace("reverse", "'reverse'")
    )
    return eval(val)


def write_parameter(f, name, val):
    out = f"{name} = {val};\n"
    out = out.replace("False", "false").replace("True", "true")
    out = out.replace("'border'", "border").replace("'platform'", "platform").replace("'inter'", "inter")
    out = (
        out.replace("'pass'", "pass")
        .replace("'appear'", "appear")
        .replace("'origin'", "origin")
        .replace("'vanish'", "vanish")
        .replace("'dest'", "dest")
        .replace("'reverse'", "reverse")
    )
    out = out.replace("'", '"')
    f.write(out)


def read_dzn(path):
    s = path.read_text()
    data = {}
    for key in [
        "nb_edges",
        "e_name",
        "e_type",
        "e_cols",
        "nb_trains",
        "t_name",
        "t_routes",
        "t_est",
        "t_type",
        "nb_routes",
        "r_name",
        "r_it_1",
        "r_it_2",
        "r_platform_name",
        "r_dwell_min",
        "r_dur_min",
        "r_overlap",
        "r_block_start",
        "r_block_end",
        "r_train",
        "nb_blocks",
        "b_edge",
        "b_dur",
        "b_start_offset",
        "b_stop",
        "b_route",
    ]:
        data[key] = parse_parameter(s, key)
    return data


def dump_dzn(path, data):
    with open(path, "w") as f:
        for name, val in data.items():
            write_parameter(f, name, val)


def split_route_at_platform(data, r):
    """Return (first_it_blocks, second_it_blocks) for route r (0-based index).
    Each is a tuple of lists: (edges, durs, offs, stops).
    first_it includes platform blocks up to and including the platform segment(s).
    second_it starts immediately after the platform (may be empty).
    """
    r_start = data["r_block_start"][r] - 1
    r_end = data["r_block_end"][r] - 1
    edges = data["b_edge"][r_start : r_end + 1]
    durs = data["b_dur"][r_start : r_end + 1]
    offs = data["b_start_offset"][r_start : r_end + 1]
    stops = data["b_stop"][r_start : r_end + 1]

    # find last platform block index within this route
    last_platform_idx = None
    for i, edge in enumerate(edges):
        # edge is 1-based index into e_type
        if data["e_type"][edge - 1] == "platform":
            last_platform_idx = i
    if last_platform_idx is None:
        # no platform found: treat whole route as first itinerary, second empty
        return (edges, durs, offs, stops), ([], [], [], [])
    # split
    first_edges = edges[: last_platform_idx + 1]
    first_durs = durs[: last_platform_idx + 1]
    first_offs = offs[: last_platform_idx + 1]
    first_stops = stops[: last_platform_idx + 1]

    second_edges = edges[last_platform_idx + 1 :]
    second_durs = durs[last_platform_idx + 1 :]
    second_offs = offs[last_platform_idx + 1 :]
    second_stops = stops[last_platform_idx + 1 :]

    return (first_edges, first_durs, first_offs, first_stops), (second_edges, second_durs, second_offs, second_stops)


def get_itineraries_data(data, r_in, r_out):
    """Extract blocks for:
    - the first itinerary from route r_in (up to platform)
    - the second itinerary from route r_out (after platform)
    Return concatenated blocks (edges, durs, offs, stops).
    r_in / r_out are 0-based route indices.
    """
    first_it, _ = split_route_at_platform(data, r_in)
    _, second_it = split_route_at_platform(data, r_out)

    # concatenate: first itinerary blocks (including platform), then second itinerary blocks (after platform)
    new_edges = first_it[0] + second_it[0]
    new_dur = first_it[1] + second_it[1]
    new_off = first_it[2] + second_it[2]
    new_stop = first_it[3] + second_it[3]
    return new_edges, new_dur, new_off, new_stop


def append_route_and_blocks(
    data,
    new_r_name,
    new_it1,
    new_it2,
    new_platform,
    new_dwell_min,
    new_dur_min,
    new_overlap,
    edges=None,
    durs=None,
    offs=None,
    stops=None,
):
    """
    Append blocks and a new route to `data`. If new_train is None a new train
    is created (nb_trains incremented) and the new route is assigned to it.
    The new train's t_routes is set to only allow this new route.
    """
    data["nb_trains"] += 1
    new_train = data["nb_trains"]  # e.g. 3 trains after adding -> new train name is T3
    data["t_name"].append(f"T{new_train}")
    data["t_routes"].append(set())  # will be replaced with the new route id below
    # copy an existing earliest start if available, otherwise 0
    data["t_est"].append(min(data["t_est"]) if len(data["t_est"]) > 0 else 0)
    data["t_type"].append("reverse")

    base_nb_blocks = data["nb_blocks"]
    start_block = base_nb_blocks + 1
    for i, e in enumerate(edges):
        data["b_edge"].append(e)
        data["b_dur"].append(durs[i])
        # first block of the appended route gets offset 0, others keep provided offs
        data["b_start_offset"].append(0 if i == 0 else offs[i])
        data["b_stop"].append(stops[i])
        data["b_route"].append(data["nb_routes"] + 1)
    end_block = base_nb_blocks + len(edges)
    data["nb_blocks"] += len(edges)

    new_route_id = data["nb_routes"] + 1
    data["nb_routes"] += 1
    data["r_name"].append(new_r_name)
    data["r_it_1"].append(new_it1)
    data["r_it_2"].append(new_it2)
    data["r_platform_name"].append(new_platform)
    data["r_dwell_min"].append(new_dwell_min)
    data["r_dur_min"].append(new_dur_min)
    data["r_overlap"].append(new_overlap)
    data["r_block_start"].append(start_block)
    data["r_block_end"].append(end_block)
    data["r_train"].append(new_train)

    data["t_routes"][new_train - 1] = {new_route_id}  # force new train to use only this new route


def main(src, dst):
    data = read_dzn(Path(src))

    # Build lists of itineraries per platform:
    # for every route r, if r_it_1 != "" register as a 'first' itinerary,
    # if r_it_2 != "" register as a 'second' itinerary.
    platform_itins = {}
    for idx, plat in enumerate(data["r_platform_name"]):
        platform_itins.setdefault(plat, {"first": [], "second": []})
        if data["r_it_1"][idx]:
            platform_itins[plat]["first"].append((idx, data["r_it_1"][idx]))
        if data["r_it_2"][idx]:
            platform_itins[plat]["second"].append((idx, data["r_it_2"][idx]))

    nb_initial_trains = data["nb_trains"]
    train_limit = min(50, nb_initial_trains * 1.2)  # allow up to 20% more trains (capped at 50)

    # For each platform, attempt to pair first-itineraries with matching second-itineraries.
    # Matching rule: itinerary names are permutations of each other (e.g., "IE1" <-> "I1E").
    for plat, groups in platform_itins.items():
        firsts = groups["first"]
        seconds = groups["second"]
        if not firsts or not seconds:
            continue
        # index second itineraries by sorted name to match when they contain same direction + platform
        seconds_by_key = {}
        for r_idx, name in seconds:
            key = "".join(sorted(name))
            seconds_by_key.setdefault(key, []).append((r_idx, name))

        for r_in, name_in in firsts:
            key = "".join(sorted(name_in))
            matches = seconds_by_key.get(key, [])
            if not matches:
                continue
            r_out, name_out = matches[0]

            edges, durs, offs, stops = get_itineraries_data(data, r_in, r_out)

            it1 = name_in
            it2 = name_out or data["r_it_1"][r_out]
            new_name = f"{it1}-{it2}"

            copy_from = (
                r_out  # arbitrarily take r_dwell_min, r_dur_min, r_overlap from original route of second itinerary
            )
            append_route_and_blocks(
                data,
                new_name,
                it1,
                it2,
                plat,
                data["r_dwell_min"][copy_from],
                data["r_dur_min"][copy_from],
                data["r_overlap"][copy_from],
                edges=edges,
                durs=durs,
                offs=offs,
                stops=stops,
            )

            # limit the total number of trains to avoid excessively large instances/skewed distribution of instance size
            if data["nb_trains"] >= train_limit:
                break
        if data["nb_trains"] >= train_limit:
            break

    dump_dzn(dst, data)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
