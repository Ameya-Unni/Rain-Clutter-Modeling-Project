% set_bounding_box.m
function bb_coords = set_boundingbox(~, num_snapshots, aoo_Ylim, ~)
    % SET_BOUNDING_BOX: Defines the coordinates for the time-variant bounding box.
    % This function calculates the four corner coordinates of a rectangular
    % bounding box for each time snapshot. The bounding box is fixed in
    % cross-range and uses the provided Area of Observation (AoO) Y-limits
    % for its range definition.
    
    fprintf('DEBUG: Entering set_bounding_box function.\n');
    
    % Define the fixed cross-range (X-axis) limits for the bounding box
    
    crossrange_lim = [-2.5, 2.5]; 
    
    % Extract range (Y-axis) limits from aoo_Ylim
    ymin = aoo_Ylim(1);
    ymax = aoo_Ylim(2);
    
    % Calculate the four corner coordinates for a single bounding box
    
    bl = crossrange_lim(1) + 1i*ymin; 
    br = crossrange_lim(2) + 1i*ymin; 
    tr = crossrange_lim(2) + 1i*ymax; 
    tl = crossrange_lim(1) + 1i*ymax; 
    
    % Create a single row of bounding box coordinates
    single_bb_row = [bl, br, tr, tl];
    
    
    bb_coords = repmat(single_bb_row, num_snapshots, 1);
    
    fprintf('DEBUG: Exiting set_bounding_box function. Bounding box size: %s\n', mat2str(size(bb_coords)));
end
