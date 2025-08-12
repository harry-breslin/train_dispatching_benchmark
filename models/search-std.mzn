% The standard search assigning variables in this order start, route, and dwell

search =
    seq_search([
        int_search(v_start, smallest, indomain_min),
        int_search(v_route, smallest, indomain_min),
        % NOTE that indomain_random is not supported by Chuffed
        %int_search(v_route, smallest, indomain_random),
        int_search(v_dwell, smallest, indomain_min)
    ]);

