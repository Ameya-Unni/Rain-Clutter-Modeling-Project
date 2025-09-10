function [fig_handle, ax_handle, vid_writer] = plot3_detections_boundingbox(...
    figtitle_base, plot_title_part, ...
    x_coords_bb, y_coords_bb, ... 
    eta_linear_data_bb, ...      
    setup_dummy, utc_timestamps_bb, bounding_box_coords, ... 
    aoo_Ylim, nominal_tr_distance, enable_video_saving) 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT3_DETECTIONS_BOUNDINGBOX
%   Animated 2D scatter plot of radar detections within a bounding box.
%   Now adapted to handle LINEAR eta only, with no Z-coordinate.
%   The bounding box (green box) is explicitly set to the Area of Observation
%   (AoO) limits defined by aoo_Ylim and a fixed cross-range of [-2.5, 2.5].
%   Data points are filtered to only appear within this defined AoO.
%   The Area of Observation's minimum range (Y-axis) is forced to be
%   at least 1 meter.
%
% Inputs:
%   figtitle_base           : Base title for figures (string)
%   plot_title_part         : Specific plot title part (string)
%   x_coords_bb, y_coords_bb : NxM arrays of x,y-coordinates for detections. (No Z-coordinate)
%   eta_linear_data_bb      : NxM array of LINEAR eta values for color mapping.
%   setup_dummy             : Placeholder (not used, kept for signature match)
%   utc_timestamps_bb       : N-element datetime array of timestamps for animation.
%   bounding_box_coords     : Nx4 array of [min_x, max_x, min_y, max_y] for each snapshot's BB.
%                             (NOTE: This input is now ignored for the BB definition within this function,
%                             as the AoO (aoo_Ylim) is directly used instead for consistency.)
%   aoo_Ylim                : 1x2 array [ymin, ymax] defining the Y-range
%                             (Range) for the Area of Observation box. This is explicitly used for the BB.
%   nominal_tr_distance     : Scalar, the nominal distance of the Triple Reflector (for dashed line).
%   enable_video_saving     : 0 or 1 to enable/disable video saving.
%
% Outputs:
%   fig_handle          : Handle to the created figure.
%   ax_handle           : Handle to the axes within the figure.
%   vid_writer          : VideoWriter object if video saving is enabled, else empty.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    fprintf('DEBUG: Entering plot3_detections_boundingbox function (Refined Visuals for Strict Linear Eta Plots).\n');

    num_snapshots = size(x_coords_bb, 1);
    vid_writer = []; % Initialize as empty

    if num_snapshots == 0
        warning('No data to plot for plot3_detections_boundingbox. Skipping plot.');
        fig_handle = [];
        ax_handle = [];
        return;
    end

    fig_handle = figure('Name', figtitle_base, 'NumberTitle', 'off', 'Position', [100 100 1000 700]);
    ax_handle = axes(fig_handle);
    hold(ax_handle, 'on');
    grid(ax_handle, 'on');
    % Removed axis equal, we want to control aspect ratio with explicit XLim/YLim

    % --- Validate aoo_Ylim: Ensure it's a 1x2 numeric array ---
    if ~isnumeric(aoo_Ylim) || numel(aoo_Ylim) ~= 2 || ~all(isfinite(aoo_Ylim)) || aoo_Ylim(2) <= aoo_Ylim(1)
        warning('Invalid aoo_Ylim provided to plot3_detections_boundingbox. Defaulting to [1, 30].'); 
        aoo_Ylim_validated = [1, 30]; 
    else
        aoo_Ylim_validated = aoo_Ylim;
    end 

    % --- Define the Bounding Box based on AoO for filtering and drawing ---
    % Use fixed AoO cross-range limits, and the provided aoo_Ylim for down-range.
    aoo_cross_range_min = -2.5; % Common AoO cross-range minimum
    aoo_cross_range_max = 2.5;  % Common AoO cross-range maximum
    
    aoo_down_range_min = aoo_Ylim_validated(1);
    aoo_down_range_max = aoo_Ylim_validated(2);

    % Force AoO minimum range to be at least 1m
    if aoo_down_range_min < 1.0
        fprintf('INFO: Adjusting AoO minimum down-range from %.1f m to 1.0 m.\n', aoo_down_range_min);
        aoo_down_range_min = 1.0;
    end

    % --- Set general plot X-axis limits (Cross-Range) to cover the full data range ---
    % Explicitly setting X and Y limits to match desired output image.
    plot_xlim = [-20, 20]; % To match reference image Cross-range
    plot_ylim = [0, 70];   % To match reference image Range
    
    xlim(ax_handle, plot_xlim);
    ylim(ax_handle, plot_ylim);

    % --- Color mapping for STRICTLY LINEAR eta ---
    % Determine dynamic color limits for the linear data directly
    all_eta_linear_values = eta_linear_data_bb(:); 
    all_eta_linear_values_cleaned = all_eta_linear_values(~isnan(all_eta_linear_values) & ~isinf(all_eta_linear_values));

    if ~isempty(all_eta_linear_values_cleaned)
        min_eta_val = min(all_eta_linear_values_cleaned);
        max_eta_val = max(all_eta_linear_values_cleaned);

        if min_eta_val == max_eta_val % All values are the same
            if max_eta_val == 0 
                 caxis_limits = [0, 1e-6]; % Provide a small positive range for visualization
            else 
                caxis_limits = [min_eta_val * 0.9, max_eta_val * 1.1]; % Add a small buffer for constant data
            end
        else
            % Use actual min/max of linear eta for caxis
            caxis_limits = [min_eta_val, max_eta_val]; 
        end
    else
        caxis_limits = [0, 1e-4]; % Default if no valid data (adjust as per typical linear eta range)
    end
    
    clim(ax_handle, caxis_limits); % Apply the dynamically set linear limits

    colormap(ax_handle, 'jet');
    colorbar_handle = colorbar(ax_handle);
    colorbar_handle.Label.String = '$\eta$ (m$^{-1}$)'; % Label as linear eta (m^-1)
    colorbar_handle.Label.Interpreter = 'latex';
    
    title(ax_handle, plot_title_part, 'Interpreter', 'latex');
    xlabel(ax_handle, 'Cross-Range (m)', 'Interpreter', 'latex');
    ylabel(ax_handle, 'Down-Range (m)', 'Interpreter', 'latex');
    view(ax_handle, 2); % Set to 2D view

    % --- Add the Triple Reflector (TR) dashed line ---
    if ~isnan(nominal_tr_distance)
        plot(ax_handle, plot_xlim, [nominal_tr_distance nominal_tr_distance], ... % Plotting in 2D
             'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance)); % Dynamic TR label
    end

    % Initialize scatter plot and bounding box patch objects
    scatter_obj = scatter(ax_handle, NaN, NaN, [], NaN, 'filled'); % Changed to scatter (2D)
    
    % Define the STATIC green AoO box using the explicitly defined AoO limits
    aoo_box_x_corners = [aoo_cross_range_min, aoo_cross_range_max, aoo_cross_range_max, aoo_cross_range_min, aoo_cross_range_min];
    aoo_box_y_corners = [aoo_down_range_min, aoo_down_range_min, aoo_down_range_max, aoo_down_range_max, aoo_down_range_min];
    
    bb_patch_obj = patch(ax_handle, 'XData', aoo_box_x_corners, 'YData', aoo_box_y_corners, ...
                         'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 1.5, 'FaceAlpha', 0.1, ... 
                         'DisplayName', 'Bounding Box'); 
    
    % Initialize video writer
    if enable_video_saving == 1
        video_filename = fullfile('output_plots', 'BoundingBox_Plots', ... 
                                  sprintf('%s_AnimatedBoundingBox.mp4', figtitle_base));
        [filepath,name,ext] = fileparts(video_filename); 
        if ~exist(filepath, 'dir')
            mkdir(filepath);
        end
        vid_writer = VideoWriter(video_filename, 'MPEG-4');
        vid_writer.FrameRate = 10; 
        open(vid_writer);
    end

    for t_idx = 1:num_snapshots
        current_x_raw = x_coords_bb(t_idx, :);
        current_y_raw = y_coords_bb(t_idx, :);
        current_eta_linear_raw = eta_linear_data_bb(t_idx, :); 
        
        % --- Filter data points to be strictly within the defined AoO bounding box ---
        valid_idx = ~isnan(current_x_raw) & ~isinf(current_x_raw) & ...
                    ~isnan(current_y_raw) & ~isinf(current_y_raw) & ...
                    ~isnan(current_eta_linear_raw) & ~isinf(current_eta_linear_raw) & ...
                    (current_x_raw >= aoo_cross_range_min) & (current_x_raw <= aoo_cross_range_max) & ...
                    (current_y_raw >= aoo_down_range_min) & (current_y_raw <= aoo_down_range_max);
        
        % Data that will actually be plotted for this snapshot
        current_x_filtered = current_x_raw(valid_idx);
        current_y_filtered = current_y_raw(valid_idx);
        current_eta_linear_filtered = eta_linear_data_bb(t_idx, valid_idx); % Use linear data directly for color
        
        % Update scatter plot data (2D)
        set(scatter_obj, ...
            'XData', current_x_filtered, ...
            'YData', current_y_filtered, ...
            'CData', current_eta_linear_filtered); 

        % Update timestamp in title or text box
        if ~isnat(utc_timestamps_bb(t_idx))
            subtitle(ax_handle, sprintf('Time: %s', datestr(utc_timestamps_bb(t_idx), 'HH:MM:SS.FFF')), 'Interpreter', 'none');
        end

        drawnow limitrate;

        if enable_video_saving == 1 && ~isempty(vid_writer)
            frame = getframe(fig_handle);
            writeVideo(vid_writer, frame);
        end
    end

    if enable_video_saving == 1 && isa(vid_writer, 'VideoWriter')
        close(vid_writer);
        fprintf('Video saved: %s\n', video_filename);
    end
    hold(ax_handle, 'off');
    fprintf('DEBUG: Exiting plot3_detections_boundingbox function.\n');

%%
%{
function [fig3, ax3, vid_out] = plot3_detections_boundingbox(... % Reverted function name and vid_out output
    figtitle, ...
    figtitle_plot, ...
    near_x, near_y, near_z, ... % Data for plotting
    near_rcs, ...             % RCS data for color
    ~, ... % Replaced 'setup' with '~' as per request
    near_utc_time, ...        % Timestamps
    bb,...                    % The dynamically defined bounding box coordinates
    ~, ...        % Placeholder for Y-limits for the blue AoO box (now '~')
    nominal_tr_distance, ...  % Nominal TR distance for black dashed line (re-added as named input)
    video_enable)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT3_DETECTIONS_BOUNDINGBOX
%   This function generates animated scatter plots of radar detections within
%   a time-variant bounding box for NearScan data only.
%   The X-axis represents Crossrange (m), Y-axis represents Range (m).
%   Points are colored by their Radar Cross Section (RCS) intensity.
%   It includes a visual representation of the red dotted bounding box and a
%   black dashed line for the nominal TR distance. The blue "Area of Observation"
%   box is now hidden as its dimensions are identical to the red bounding box.
%   It can optionally save the animation as an MPEG-4 video.
%
% Inputs:
%   figtitle          : Main title for the figure windows (string).
%   figtitle_plot     : Specific plot title part for display on the figure itself (string).
%   near_x, near_y, near_z : Cartesian coordinates for detections.
%   near_rcs          : RCS values for detections (used for color).
%   ~                 : Placeholder for an unused input (previously 'setup').
%   near_utc_time     : UTC timestamps (datetime array/vector).
%   bb                : Bounding box coordinates (complex array, Nx4, from set_boundingbox.m).
%   ~                 : Placeholder for an unused input (previously 'blue_box_Ylim').
%   nominal_tr_distance : Scalar, the nominal distance of the Triple Reflector (for dashed line).
%   video_enable      : Flag (0 or 1) to enable/disable video saving.
%
% Outputs:
%   fig3            : Figure handle.
%   ax3             : Axes handle.
%   vid_out         : (Optional) VideoWriter object if video_enable is true, else empty.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('DEBUG: Entering plot3_detections_boundingbox function.\n'); % DEBUG PRINT
    vid_out = []; % Initialize as empty for cases where video_enable is false
    
    % --- VideoWriter Initialization ---
    if video_enable == 1
        video_filename_parts = split(figtitle," ");
        base_name = strrep(figtitle, ':', ''); % Remove colons
        base_name = strrep(base_name, ' ', '_'); % Replace spaces with underscores
        base_name = strrep(base_name, '.', ''); % Remove dots
        video_filename = strcat(base_name, '_bb.mp4'); % Specific name for BB plot
        
        try
            vid_out = VideoWriter(char(video_filename), "MPEG-4");
            vid_out.Quality = 100;
            vid_out.FrameRate = 10; % Set frame rate
            open(vid_out);
            fprintf('Video writer opened for bounding box plot: %s\n', video_filename);
        catch ME
            warning(ME.identifier, 'Failed to initialize VideoWriter for bounding box plot: %s. Video saving will be disabled.', ME.message);
            vid_out = [];
        end
    end
    
    idx = 1; % Start with the first snapshot for initial plotting

    % --- Initial Plotting for Bounding Box Plot ---
    fprintf('DEBUG: Attempting to create figure 3.\n'); % DEBUG PRINT
    fig3 = figure(3); % Use figure(3)
    fprintf('DEBUG: Figure 3 created/activated.\n'); % DEBUG PRINT
    fig3.Name = strcat("Detections with Bounding Box: ",figtitle_plot);
    fig3.Position = [500 500 900 700]; % Adjusted size for better visibility
    fig3.Renderer = 'opengl'; % Set renderer for consistent video output
    set(fig3, 'PaperPositionMode', 'auto'); % Ensure captured frame matches display aspect ratio
    ax3 = gca; % Get current axes handle
    hold(ax3, 'on'); % Hold on to add background elements

    % --- Background Setup (Removed specific conditions as per request) ---
    % The grey background patches for "OUTDOOR" and "CARISSMA" are no longer drawn.
    % The 'setup' input is effectively unused for drawing background structures in this function.
    disp("No specific setup background defined. Plotting without environmental context.");
    % Placeholder for 'Area of Observation' in legend, as blue box is hidden.
    rainarea_handle = plot(ax3, NaN, NaN, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Area of Observation');
    
    % --- Define plot's X-axis limits (Crossrange) to show full range ---
    plot_Xlim_full_crossrange = [-20, 20]; % The overall display range for X-axis
    
    % Add black dashed line for nominal TR distance (spans full plot X-range)
    if ~isnan(nominal_tr_distance)
        line([plot_Xlim_full_crossrange(1) plot_Xlim_full_crossrange(2)], [nominal_tr_distance nominal_tr_distance], ...
             'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance));
    end
    
    % --- Initial Bounding Box Plot (Red Dotted) ---
    if ~isempty(bb) && size(bb,1) >= idx
        bb_v_initial = [real(bb(idx,1)) imag(bb(idx,1)); real(bb(idx,2)) imag(bb(idx,2)); real(bb(idx,3)) imag(bb(idx,3)); real(bb(idx,4)) imag(bb(idx,4))];
        bb_f_initial = [1 2 3 4]; % Faces for a quadrilateral
        % MODIFIED: Changed FaceAlpha from 0.0 to 0.1 to make the red box visible
        bb_handle = patch(ax3, "Faces",bb_f_initial,"Vertices",bb_v_initial,"FaceColor","red","FaceAlpha",0.1,"EdgeColor","red","LineStyle", "--", 'DisplayName', 'Bounding Box');
    else
        bb_handle = plot(ax3, NaN, NaN, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Bounding Box'); % Create empty handle
        warning('Bounding box (bb) is empty or too short. Plotting an empty bounding box.');
    end
    
    % --- Initial Scatter Plot for Detections within Bounding Box ---
    if ~isempty(near_x) && size(near_x,1) >= idx
        s_handle = scatter3(ax3, near_x(idx,:), near_y(idx,:), near_z(idx,:), [], near_rcs(idx,:),"filled");
    else
        s_handle = scatter3(ax3, NaN, NaN, NaN, [], NaN,"filled"); % Create empty handle
        warning('Initial filtered data for scatter plot is empty. Plot will be empty.');
    end
    grid(ax3, 'on');
    ax3.XLim = plot_Xlim_full_crossrange; % Set X-axis limits for cross range to wider value
    ax3.YLim = [0,70];   % Range (general display range)
    ax3.CLim = [-30 50]; % RCS in dBsm
    ax3.XLabel.String = "cross range (m)";
    ax3.YLabel.String = "range (m)";
    ax3.ZLabel.String = "Height (m)"; % Keep ZLabel for completeness
    
    % Initial title with current timestamp
    title_handle = title(ax3, strcat("Detections with Bounding Box (UTC): ", string(near_utc_time(idx,1))));
    
    view(ax3, [0 90]); % Top-down view
    cb = colorbar(ax3);
    cb.Label.String = "RCS (dBsm)";
    % Ensure legend includes all relevant elements
    % Order: Bounding Box, Radar Detections, TR Line (Area of Observation removed)
    legend_handles = [bb_handle, s_handle]; % Removed rainarea_handle
    legend_strings = {'Bounding Box', 'Radar Detections'}; % Removed 'Area of Observation'
    % Add TR line to legend if it was plotted
    h_lines = findobj(ax3, 'Type', 'Line');
    tr_line_handle_in_plot = findobj(h_lines, 'DisplayName', sprintf('TR at %dm', nominal_tr_distance));
    if ~isempty(tr_line_handle_in_plot)
        legend_handles = [legend_handles, tr_line_handle_in_plot];
        legend_strings = [legend_strings, sprintf('TR at %dm', nominal_tr_distance)];
    end
    legend(ax3, legend_handles, legend_strings, 'Location', 'best');
    
    text(ax3, plot_Xlim_full_crossrange(2) - 0.5, ax3.YLim(1) + 10, 0, figtitle_plot, ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom'); % Adjusted X-position
    drawnow; % Force MATLAB to render the initial plot

    % --- Animation Loop ---
    fprintf('DEBUG: Starting animation loop for bounding box plot. Total snapshots: %d\n', size(near_x,1)); % DEBUG PRINT
    for current_idx = 2:size(near_x,1) % Loop from the second snapshot
        fprintf('Plotting Bounding Box Snapshot: %d/%d\n', current_idx, size(near_x,1));
        
        % Update bounding box vertices
        if size(bb,1) >= current_idx % Ensure bb has enough rows for this snapshot
            bb_curr_v = [real(bb(current_idx,1)) imag(bb(current_idx,1)); ...
                         real(bb(current_idx,2)) imag(bb(current_idx,2)); ...
                         real(bb(current_idx,3)) imag(bb(current_idx,3)); ...
                         real(bb(current_idx,4)) imag(bb(current_idx,4))];
            set(bb_handle, 'Vertices', bb_curr_v);
        end
        % Update scatter plot data
        set(s_handle, 'XData', near_x(current_idx,:), ...
                          'YData', near_y(current_idx,:), ...
                          'ZData', near_z(current_idx,:), ...
                          'CData', near_rcs(current_idx,:));
        
        % Update title with current timestamp
        set(title_handle, 'String', strcat("Detections with Bounding Box (UTC): ", string(near_utc_time(current_idx,1))));
        
        drawnow; % Ensure plot is rendered before capturing frame
        
        % Capture frame for video using robust print method
        if video_enable == 1 && isa(vid_out, 'VideoWriter')
            % Set figure properties for accurate frame capture
            set(fig3, 'Renderer', 'opengl'); % Ensure OpenGL is set
            set(fig3, 'PaperPositionMode', 'auto'); 
            set(fig3, 'InvertHardcopy', 'off'); % Do not invert colors
            set(fig3, 'Color', 'w'); % Set background color to white
            
            % --- Robust frame capture using print to temporary file ---
            temp_img_filename = 'temp_boundingbox_frame.png';
            
            % Print the figure to a temporary PNG file with a high resolution
            figure(fig3); % Ensure the correct figure is active
            print(fig3, temp_img_filename, '-dpng', '-r150'); % -r150 sets 150 DPI resolution
            
            % Read the image file back
            img_data = imread(temp_img_filename);
            
            % Convert the image data to a frame struct for VideoWriter
            frame = im2frame(img_data);
            
            % Write the frame to the video
            writeVideo(vid_out, frame);
            
            % Delete the temporary image file to avoid clutter
            delete(temp_img_filename);
            % --- End new robust frame capture ---
        end

        pause(0.1); % Pause for animation effect
    end

    % Close VideoWriter after animation loop completes
    if video_enable == 1 && isa(vid_out, 'VideoWriter') && vid_out.IsOpen
        close(vid_out);
        fprintf('Bounding box video saved.\n');
    end

    hold(ax3, 'off'); % Release hold on axes
    fprintf('DEBUG: Exiting plot3_detections_boundingbox function.\n'); % DEBUG PRINT
end
%}