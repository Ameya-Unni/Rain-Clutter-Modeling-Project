function [near_x_filtered, near_y_filtered, near_rcs_filtered] = filter_boundingbox(...
          near_x_in, near_y_in, near_rcs_in, ...
          bb_coords, ~) 
    % FILTER_BOUNDINGBOX: Filters radar detection data based on a time-variant bounding box.
    % This function iterates through each time snapshot and retains only those
    % detection points (x, y) that fall within the current bounding box defined by bb_coords.
    % It is specifically designed for Near Scan data.
    %
    % Inputs:
    %   near_x_in, near_y_in, near_rcs_in : N x M matrices of Near Scan Cartesian coordinates (x, y) and RCS values.
    %                                       N is number of snapshots, M is number of detections per snapshot.
    %   bb_coords                         : N x 4 complex array containing bounding box coordinates for each snapshot.
    %   ~                                 : Placeholder for an unused input (previously figtitle_parts).
    %
    % Outputs:
    %   near_x_filtered, near_y_filtered, near_rcs_filtered : Filtered Near Scan data.
    %                                                           Points outside the BB are set to NaN.
    
    fprintf('DEBUG: Entering filter_boundingbox function.\n');
    
    num_snapshots = size(near_x_in, 1);
    
    % Initialize filtered outputs with NaNs (to preserve array size and indicate filtered-out points)
    near_x_filtered = NaN(size(near_x_in));
    near_y_filtered = NaN(size(near_y_in));
    near_rcs_filtered = NaN(size(near_rcs_in));
    
    for i = 1:num_snapshots
        % Get current snapshot's bounding box coordinates
        % The bb_coords array has 4 complex numbers per row, representing
        % [bottom-left, bottom-right, top-right, top-left] corners.
        current_bb = bb_coords(i,:);
        bb_x = [real(current_bb(1)), real(current_bb(2)), real(current_bb(3)), real(current_bb(4))];
        bb_y = [imag(current_bb(1)), imag(current_bb(2)), imag(current_bb(3)), imag(current_bb(4))];
        
        % Filter Near Scan data for the current snapshot
        current_near_x = near_x_in(i,:);
        current_near_y = near_y_in(i,:);
        current_near_rcs = near_rcs_in(i,:); % This input is directly used, no conversion here.
        
        % Use inpolygon to check which points are inside the bounding box
        in = inpolygon(current_near_x, current_near_y, bb_x, bb_y);
        
        % Store only the points that are inside the bounding box
        near_x_filtered(i, in) = current_near_x(in);
        near_y_filtered(i, in) = current_near_y(in);
        near_rcs_filtered(i, in) = current_near_rcs(in);
    end
    fprintf('DEBUG: Exiting filter_boundingbox function.\n');
end

%%
%{
function [near_x_filtered, near_y_filtered, near_rcs_filtered] = filter_boundingbox(...
          near_x_in, near_y_in, near_rcs_in, ...
          bb_coords, ~) 
    % FILTER_BOUNDINGBOX: Filters radar detection data based on a time-variant bounding box.
    % This function iterates through each time snapshot and retains only those
    % detection points (x, y) that fall within the current bounding box defined by bb_coords.
    % It is specifically designed for Near Scan data.
    %
    % Inputs:
    %   near_x_in, near_y_in, near_rcs_in : N x M matrices of Near Scan Cartesian coordinates (x, y) and RCS values.
    %                                       N is number of snapshots, M is number of detections per snapshot.
    %   bb_coords                         : N x 4 complex array containing bounding box coordinates for each snapshot.
    %   ~                                 : Placeholder for an unused input (previously figtitle_parts).
    %
    % Outputs:
    %   near_x_filtered, near_y_filtered, near_rcs_filtered : Filtered Near Scan data.
    %                                                           Points outside the BB are set to NaN.
    
    fprintf('DEBUG: Entering filter_boundingbox function.\n');
    
    num_snapshots = size(near_x_in, 1);
    
    % Initialize filtered outputs with NaNs (to preserve array size and indicate filtered-out points)
    near_x_filtered = NaN(size(near_x_in));
    near_y_filtered = NaN(size(near_y_in));
    near_rcs_filtered = NaN(size(near_rcs_in));
    
    for i = 1:num_snapshots
        % Get current snapshot's bounding box coordinates
        % The bb_coords array has 4 complex numbers per row, representing
        % [bottom-left, bottom-right, top-right, top-left] corners.
        current_bb = bb_coords(i,:);
        bb_x = [real(current_bb(1)), real(current_bb(2)), real(current_bb(3)), real(current_bb(4))];
        bb_y = [imag(current_bb(1)), imag(current_bb(2)), imag(current_bb(3)), imag(current_bb(4))];
        
        % Filter Near Scan data for the current snapshot
        current_near_x = near_x_in(i,:);
        current_near_y = near_y_in(i,:);
        current_near_rcs = near_rcs_in(i,:);
        
        % Use inpolygon to check which points are inside the bounding box
        in = inpolygon(current_near_x, current_near_y, bb_x, bb_y);
        
        % Store only the points that are inside the bounding box
        near_x_filtered(i, in) = current_near_x(in);
        near_y_filtered(i, in) = current_near_y(in);
        near_rcs_filtered(i, in) = current_near_rcs(in);
    end
    fprintf('DEBUG: Exiting filter_boundingbox function.\n');
end
%}