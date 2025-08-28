function [fig1, ax1, vid_out] = plot3_detections(...
    figtitle, ...
    figtitle_plot, ...
    x_coords, y_coords, ... % No z_coords for 2D plotting
    eta_linear_data, ...             % LINEAR eta data for color
    utc_timestamps, ...        % Timestamps
    aoo_Ylim, ...              % Y-limits for the blue AoO box
    nominal_tr_distance, ...  % Nominal TR distance for black dashed line
    video_enable)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT3_DETECTIONS
%   This function generates animated scatter plots of radar detections.
%   Points are colored by their LINEAR reflectivity (eta, in m^-1).
%   It explicitly includes a blue rectangular "Area of Observation" box
%   and a black dashed line for the nominal Triple Reflector (TR) distance.
%   The plot is now strictly 2D (Cross-Range vs. Down-Range), with no height.
%   Color axis dynamically adjusts to the actual range of linear eta data.
%   It can optionally save the animation as an MPEG-4 video.
%
% Inputs:
%   figtitle          : Main title for the figure windows (string).
%   figtitle_plot     : Specific plot title part for display on the figure itself (string).
%   x_coords, y_coords : Cartesian coordinates (x=cross-range, y=down-range) for detections.
%   eta_linear_data   : LINEAR eta values (m^-1) for detections (used for color).
%   utc_timestamps    : UTC timestamps (datetime array/vector).
%   aoo_Ylim          : 1x2 array [ymin, ymax] for the blue Area of Observation box range.
%   nominal_tr_distance : Scalar, the nominal distance of the Triple Reflector (for dashed line).
%   video_enable      : Flag (0 or 1) to enable/disable video saving.
%
% Outputs:
%   fig1            : Figure handle.
%   ax1             : Axes handle.
%   vid_out         : (Optional) VideoWriter object if video_enable is true, else empty.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('DEBUG: Entering plot3_detections function (Final 2D Plotting and Improved Color Scaling with AoO in Filename).\n');
    
    vid_out = []; % Initialize as empty for cases where video_enable is false
    num_snapshots = size(x_coords, 1);

    if num_snapshots == 0
        warning('No data to plot for plot3_detections. Skipping plot.');
        fig1 = [];
        ax1 = [];
        return;
    end

    % --- VideoWriter Initialization ---
    if video_enable == 1
        % Dynamically generate video filename from figtitle_plot, ensuring valid characters
        clean_plot_title = strrep(figtitle_plot, ':', ''); % Remove colons
        clean_plot_title = strrep(clean_plot_title, ' ', '_'); % Replace spaces with underscores
        clean_plot_title = strrep(clean_plot_title, '.', ''); % Remove dots (e.g., from numbers or file extensions)
        clean_plot_title = strrep(clean_plot_title, '/', '_'); % Replace slashes if any

        % Incorporate aoo_Ylim into the filename for uniqueness
        aoo_ylim_str = sprintf('AoO_Y%d-%d', round(aoo_Ylim(1)), round(aoo_Ylim(2)));
        video_filename = strcat(clean_plot_title, '_', aoo_ylim_str, '_detections.mp4'); 
        
        % No need for fullfile, filepath, or mkdir as it's the current directory
        try
            vid_out = VideoWriter(char(video_filename), "MPEG-4"); % Assign to output variable
            vid_out.Quality = 100;
            vid_out.FrameRate = 10; % IMPORTANT: Set the frame rate explicitly
            open(vid_out);
            fprintf('Video writer opened for scatter plot: %s\n', video_filename);
        catch ME
            warning(ME.identifier, 'Failed to initialize VideoWriter for scatter plot: %s. Video saving will be disabled.', ME.message);
            vid_out = []; % Ensure it's empty if creation fails
        end
    end
    
    % --- Initial Plotting ---
    fig1 = figure(); % Create a new figure
    fig1.Renderer = 'opengl'; % Set the figure renderer explicitly to OpenGL
    set(fig1, 'PaperPositionMode', 'auto'); % Ensure captured frame matches display aspect ratio
    
    fig1.Position = [100 100 900 700]; % Set figure position and size
    fig1.Name = strcat("Radar Detections: ", figtitle_plot); % Update figure name
    
    ax1 = gca; % Get current axes handle
    hold(ax1, 'on'); % Hold on to add background elements

    % --- Define plot's X-axis limits (Cross-Range) to show full range ---
    plot_Xlim_full_crossrange = [-20, 20]; % The overall display range for X-axis
    
    % Add black dashed line for nominal TR distance
    if ~isnan(nominal_tr_distance)
        plot(ax1, plot_Xlim_full_crossrange, [nominal_tr_distance nominal_tr_distance], ... % Plotting in 2D
             'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance));
    end

    % --- Add the blue "Area of Observation" (AoO) box ---
    % Robustly validate aoo_Ylim
    if ~isnumeric(aoo_Ylim) || numel(aoo_Ylim) ~= 2 || ~all(isfinite(aoo_Ylim)) || aoo_Ylim(2) <= aoo_Ylim(1)
        warning('Invalid aoo_Ylim provided to plot3_detections. Defaulting to [1, 30].'); 
        aoo_Ylim_validated = [1, 30]; 
    else
        aoo_Ylim_validated = aoo_Ylim;
    end
    
    blue_box_crossrange_lim = [-2.5, 2.5]; % Fixed cross-range for the blue box
    
    blue_box_x_plot = [blue_box_crossrange_lim(1), blue_box_crossrange_lim(2), blue_box_crossrange_lim(2), blue_box_crossrange_lim(1), blue_box_crossrange_lim(1)];
    blue_box_y_plot = [aoo_Ylim_validated(1), aoo_Ylim_validated(1), aoo_Ylim_validated(2), aoo_Ylim_validated(2), aoo_Ylim_validated(1)];
    
    % Plotting the AoO box as a 2D line
    rainarea_handle = plot(ax1, blue_box_x_plot, blue_box_y_plot, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Area of Observation');
    
    % Create the initial scatter plot.
    idx = 1; % Start with the first time slice
    if ~isempty(x_coords) && size(x_coords,1) >= idx
        % Filter initial data for NaNs and Infs for plotting
        valid_initial_idx = ~isnan(x_coords(idx,:)) & ~isinf(x_coords(idx,:)) & ...
                            ~isnan(y_coords(idx,:)) & ~isinf(y_coords(idx,:)) & ...
                            ~isnan(eta_linear_data(idx,:)) & ~isinf(eta_linear_data(idx,:));
        
        % Plotting in 2D using 'scatter'
        s_handle = scatter(ax1, x_coords(idx,valid_initial_idx), y_coords(idx,valid_initial_idx), ...
                            20, eta_linear_data(idx,valid_initial_idx), "filled"); % Use eta_linear_data for color
    else
        % Create an empty scatter plot if no data, to get a handle
        s_handle = scatter(ax1, NaN, NaN, 20, NaN, "filled"); 
        warning('Initial Near Scan data is empty. Plot will be empty.');
    end
    grid on;
    axis equal; % Maintain aspect ratio

    ax1.XLabel.String = "Cross-Range (m)";
    ax1.YLabel.String = "Down-Range (m)";
    % Removed ZLabel as this is now a 2D plot
    
    ax1.XLim = plot_Xlim_full_crossrange; % Set X-axis limits for cross range
    ax1.YLim = [0 70]; % Set Y-axis limits for range (general display range)
    % Removed ZLim as this is now a 2D plot
    
    % --- Dynamic caxis for LINEAR eta based on percentiles ---
    % Calculate overall min/max of linear eta data to set appropriate color limits
    all_eta_linear_values = eta_linear_data(:); % Flatten all snapshots
    all_eta_linear_values_cleaned = all_eta_linear_values(~isnan(all_eta_linear_values) & ~isinf(all_eta_linear_values));

    if ~isempty(all_eta_linear_values_cleaned) && numel(all_eta_linear_values_cleaned) >= 2
        % Use 1st and 99th percentiles for more robust color scaling
        min_eta = prctile(all_eta_linear_values_cleaned, 1);
        max_eta = prctile(all_eta_linear_values_cleaned, 99);

        % Ensure min and max are not identical or too close (add small buffer if so)
        if min_eta == max_eta 
            if max_eta == 0 % If all values are exactly zero
                 clim(ax1, [0, 1e-6]); % Use a small positive range for visualization
            else % If all values are a non-zero constant
                clim(ax1, [min_eta * 0.9, max_eta * 1.1]); % Add a small buffer around the constant value
            end
        else
            clim(ax1, [min_eta, max_eta]); % Set based on actual 1st/99th percentile
        end
    else
        clim(ax1, [0, 1e-4]); % Default if no valid data or not enough data for percentiles
    end

    colormap(ax1, 'jet');
    cb1 = colorbar(ax1);
    cb1.Label.String = '$\eta$ (m$^{-1}$))'; % Updated label for linear eta
    cb1.Label.Interpreter = 'latex'; % Ensure LaTeX interpreter for eta label
    
    title_handle = title(ax1, sprintf('Radar Detections (UTC): %s', string(utc_timestamps(idx))), 'Interpreter', 'latex'); % Initial title
    
    % Create legend handles. Update to include TR line.
    legend_handles = [s_handle, rainarea_handle];
    legend_strings = {'Radar Detections', 'Area of Observation'};
    
    h_lines = findobj(ax1, 'Type', 'Line');
    tr_line_handle = findobj(h_lines, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance));
    if ~isempty(tr_line_handle)
        legend_handles = [legend_handles, tr_line_handle];
        legend_strings = [legend_strings, sprintf('TR at %dm', nominal_tr_distance)];
    end
    legend(ax1, legend_handles, legend_strings, 'Location', 'best');

    % Adjust text position for the wider X-limits
    text(ax1, plot_Xlim_full_crossrange(2) - 0.5, ax1.YLim(1) + 10, figtitle_plot, ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom'); 
    drawnow; % Force MATLAB to render the initial plot

    % --- Animation Loop (for all snapshots) ---
    for idx = 2:num_snapshots % Loop through all remaining snapshots
        fprintf('Plotting Radar Detections Snapshot: %d/%d\n', idx, num_snapshots);
        
        % Filter data for current snapshot before updating scatter plot
        current_x_snap = x_coords(idx,:);
        current_y_snap = y_coords(idx,:);
        current_eta_snap = eta_linear_data(idx,:); % Use eta_linear_data here

        valid_snap_idx = ~isnan(current_x_snap) & ~isinf(current_x_snap) & ...
                         ~isnan(current_y_snap) & ~isinf(current_y_snap) & ...
                         ~isnan(current_eta_snap) & ~isinf(current_eta_snap);

        % Update scatter plot data (2D)
        set(s_handle, 'XData', current_x_snap(valid_snap_idx), ...
                      'YData', current_y_snap(valid_snap_idx), ...
                      'CData', current_eta_snap(valid_snap_idx)); % Removed ZData
        
        % Update title with current timestamp
        set(title_handle, 'String', sprintf('Radar Detections (UTC): %s', string(utc_timestamps(idx))));
        
        drawnow; % Ensure plot is rendered before capturing frame
        
        % Capture frame for video 
        if video_enable == 1 && isa(vid_out, 'VideoWriter')
            % Set figure properties for accurate frame capture
            set(fig1, 'Renderer', 'opengl'); % Ensure OpenGL renderer
            set(fig1, 'PaperPositionMode', 'auto'); % Ensure captured frame matches display aspect ratio
            set(fig1, 'InvertHardcopy', 'off'); % Do not invert colors
            set(fig1, 'Color', 'w'); % Set background color to white
            
            % Use print to capture a high-resolution frame to a temporary PNG file
            temp_img_filename = 'temp_detections_frame.png'; 
            figure(fig1); % Make sure the target figure is active
            print(fig1, temp_img_filename, '-dpng', '-r150'); % -r150 sets 150 DPI resolution
            
            % Read the image file back
            img_data = imread(temp_img_filename);
            
            % Convert the image data to a frame struct for VideoWriter
            frame = im2frame(img_data);
            
            % Write the frame to the video
            writeVideo(vid_out, frame);
            
            % Delete the temporary image file
            delete(temp_img_filename);
        end
        pause(0.1); % Pause for animation effect
    end

    % Close VideoWriter after animation loop completes
    if video_enable == 1 && isa(vid_out, 'VideoWriter') && vid_out.IsOpen
        close(vid_out);
        fprintf('Scatter plot video saved.\n');
    end
    hold(ax1, 'off'); % Release hold on the axes
    fprintf('DEBUG: Exiting plot3_detections function.\n');
end


%%

%{
function [fig1, ax1, vid_out] = plot3_detections(...
    figtitle, ...
    figtitle_plot, ...
    near_x, near_y, near_z, ... % Data for plotting
    near_rcs, ...             % RCS data for color
    near_utc_time, ...        % Timestamps
    blue_box_Ylim, ...        % Y-limits for the blue AoO box
    nominal_tr_distance, ...  % Nominal TR distance for black dashed line
    video_enable)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT3_DETECTIONS
%   This function generates animated scatter plots of radar detections for
%   NearScan data only, in a standard Cartesian view (Crossrange vs. Range).
%   Points are colored by their Radar Cross Section (RCS) intensity.
%   It includes a blue rectangular "Area of Observation" box 
%   The plot's X-axis (Crossrange) is wide to show all detections, 
%   while the blue box specifically highlights -2.5m to 2.5m.
%   It can optionally save the animation as an MPEG-4 video.
%
% Inputs:
%   figtitle          : Main title for the figure windows (string).
%   figtitle_plot     : Specific plot title part for display on the figure itself (string).
%   near_x, near_y, near_z : Cartesian coordinates (x=crossrange, y=range, z=height) for detections.
%   near_rcs          : RCS values for detections (used for color).
%   setup             : String indicating the measurement environment ("CARISSMA" or "OUTDOOR").
%   near_utc_time     : UTC timestamps (datetime array/vector).
%   blue_box_Ylim     : 1x2 array [ymin, ymax] for the blue Area of Observation box range.
%   nominal_tr_distance : Scalar, the nominal distance of the Triple Reflector (for dashed line).
%   video_enable      : Flag (0 or 1) to enable/disable video saving.
%
% Outputs:
%   fig1            : Figure handle.
%   ax1             : Axes handle.
%   vid_out         : (Optional) VideoWriter object if video_enable is true, else empty.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    vid_out = []; % Initialize as empty for cases where video_enable is false

    % --- VideoWriter Initialization ---
    if video_enable == 1
        % Dynamically generate video filename from figtitle parts
        base_name = strrep(figtitle, ':', ''); % Remove colons
        base_name = strrep(base_name, ' ', '_'); % Replace spaces with underscores
        base_name = strrep(base_name, '.', ''); % Remove dots
        video_filename = strcat(base_name, '_detections.mp4'); % Specific name for this plot
        
        try
            vid_out = VideoWriter(char(video_filename), "MPEG-4"); % Assign to output variable
            vid_out.Quality = 100;
            vid_out.FrameRate = 10; % IMPORTANT: Set the frame rate explicitly
            open(vid_out);
            fprintf('Video writer opened for scatter plot: %s\n', video_filename);
        catch ME
            warning(ME.identifier, 'Failed to initialize VideoWriter for scatter plot: %s. Video saving will be disabled.', ME.message);
            vid_out = []; % Ensure it's empty if creation fails
        end
    end
    
    % --- Initial Plotting ---
    fig1 = figure(); % Create a new figure
    fig1.Renderer = 'opengl'; % Set the figure renderer explicitly to OpenGL
    set(fig1, 'PaperPositionMode', 'auto'); % Ensure captured frame matches display aspect ratio
    
    fig1.Position = [100 100 900 700]; % Set figure position and size
    fig1.Name = strcat("Radar Detections: ", figtitle_plot); % Update figure name
    
    ax1 = gca; % Get current axes handle
    hold(ax1, 'on'); % Hold on to add background elements

    % --- Define plot's X-axis limits (Crossrange) to show full range ---
    plot_Xlim_full_crossrange = [-20, 20]; % The overall display range for X-axis

    % --- Define the cross-range for the blue "Area of Observation" box ---
    blue_box_crossrange_lim = [-2.5, 2.5]; % Fixed cross-range for the blue box

    % The blue box representing Area of Observation (AoO)
    blue_box_x_plot = [blue_box_crossrange_lim(1), blue_box_crossrange_lim(2), blue_box_crossrange_lim(2), blue_box_crossrange_lim(1), blue_box_crossrange_lim(1)]; % Use fixed X-limits for the box
    blue_box_y_plot = [blue_box_Ylim(1), blue_box_Ylim(1), blue_box_Ylim(2), blue_box_Ylim(2), blue_box_Ylim(1)]; % Use provided Y-limits
    rainarea_handle = plot(ax1, blue_box_x_plot, blue_box_y_plot, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Area of Observation');

    % Add black dashed line for nominal TR distance (spans full plot X-range)
    if ~isnan(nominal_tr_distance)
        line([plot_Xlim_full_crossrange(1) plot_Xlim_full_crossrange(2)], [nominal_tr_distance nominal_tr_distance], ...
             'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance));
    end

    % Create the initial scatter plot.
    idx = 1; % Start with the first time slice
    if ~isempty(near_x) && size(near_x,1) >= idx
        s_handle = scatter3(ax1, near_x(idx,:), near_y(idx,:), near_z(idx,:), 20, near_rcs(idx,:), "filled");
    else
        % Create an empty scatter plot if no data, to get a handle
        s_handle = scatter3(ax1, NaN, NaN, NaN, 20, NaN, "filled"); 
        warning('Initial Near Scan data is empty. Plot will be empty.');
    end
    grid on;
    
    ax1.XLabel.String = "cross range (m)";
    ax1.YLabel.String = "range (m)";
    ax1.ZLabel.String = "Height (m)"; % Keep ZLabel for completeness, but viewed in 2D
    
    ax1.XLim = plot_Xlim_full_crossrange; % Set X-axis limits for cross range to wider value
    ax1.YLim = [0 70]; % Set Y-axis limits for range (general display range)
    
    ax1.CLim = [-30 50]; % Set color limits for RCS (in dBsm)
    
    view([0 90]); % Look from directly above (X-Y plane)
    cb1 = colorbar;
    cb1.Label.String = "RCS (dBsm)";
    
    title_handle = title(ax1, sprintf('Radar Detections (UTC): %s', string(near_utc_time(idx))), 'Interpreter', 'latex'); % Initial title
    
    % Create legend handles. Update to include TR line.
    legend_handles = [s_handle, rainarea_handle];
    legend_strings = {'Radar Detections', 'Area of Observation'};

    % Add TR line to legend if it was plotted
    h_lines = findobj(ax1, 'Type', 'Line');
    tr_line_handle = findobj(h_lines, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance));
    if ~isempty(tr_line_handle)
        legend_handles = [legend_handles, tr_line_handle];
        legend_strings = [legend_strings, sprintf('TR at %dm', nominal_tr_distance)];
    end

    % Add legend, ensure it's created correctly
    legend(ax1, legend_handles, legend_strings, 'Location', 'best');

    % Adjust text position for the wider X-limits
    text(ax1, plot_Xlim_full_crossrange(2) - 0.5, ax1.YLim(1) + 10, 0, figtitle_plot, ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom'); 
    drawnow; % Force MATLAB to render the initial plot

    % --- Animation Loop (for all snapshots) ---
    for idx = 2:size(near_x,1) % Loop through all remaining snapshots
        fprintf('Plotting Radar Detections Snapshot: %d/%d\n', idx, size(near_x,1));

        % Update scatter plot data
        set(s_handle, 'XData', near_x(idx,:), 'YData', near_y(idx,:), 'ZData', near_z(idx,:), 'CData', near_rcs(idx,:));
        
        % Update title with current timestamp
        set(title_handle, 'String', sprintf('Radar Detections (UTC): %s', string(near_utc_time(idx))));
        
        drawnow; % Ensure plot is rendered before capturing frame
        
        % Capture frame for video 
        if video_enable == 1 && isa(vid_out, 'VideoWriter')
            % Set figure properties for accurate frame capture
            set(fig1, 'Renderer', 'opengl'); % Ensure OpenGL renderer
            set(fig1, 'PaperPositionMode', 'auto'); % Ensure captured frame matches display aspect ratio
            set(fig1, 'InvertHardcopy', 'off'); % Do not invert colors
            set(fig1, 'Color', 'w'); % Set background color to white
            
            % Use print to capture a high-resolution frame to a temporary PNG file
            temp_img_filename = 'temp_detections_frame.png'; % Unique temp filename
            figure(fig1); % Make sure the target figure is active
            print(fig1, temp_img_filename, '-dpng', '-r150'); % -r150 sets 150 DPI resolution
            
            % Read the image file back
            img_data = imread(temp_img_filename);
            
            % Convert the image data to a frame struct for VideoWriter
            frame = im2frame(img_data);
            
            % Write the frame to the video
            writeVideo(vid_out, frame);
            
            % Delete the temporary image file
            delete(temp_img_filename);
        end

        pause(0.1); % Pause for animation effect
    end

    % Close VideoWriter after animation loop completes
    if video_enable == 1 && isa(vid_out, 'VideoWriter') && vid_out.IsOpen
        close(vid_out);
        fprintf('Scatter plot video saved.\n');
    end

    hold(ax1, 'off'); % Release hold on the axes
end
%}