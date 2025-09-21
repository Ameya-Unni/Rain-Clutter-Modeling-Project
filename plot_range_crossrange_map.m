function plot_range_crossrange_map(...
    x_coords, y_coords, eta_linear_data, ...
    aoo_Ylim_for_box, nominal_tr_distance, file_info_struct, ...
    aoo_Xlim_for_box, hPBWphi) % hPBWphi is horizontal beamwidth in radians
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT_RANGE_CROSSRANGE_MAP
%   Generates a static 2D scatter plot of aggregated radar detections
%   showing Down-range (X-axis) vs. Cross-range (Y-axis).
%   Points are colored by their LINEAR reflectivity (eta, in m^-1).
%   This version displays ALL valid data points *within the radar's
%   horizontal beam spread (cone shape)* AND within the specified
%   plot limits for cross-range. It highlights the Area of Observation (AoO)
%   with a red dashed bounding box.
%   Marker size and color scaling are refined for better visualization,
%   especially to make the Triple Reflector (TR) more distinct by
%   adjusting the color axis limits (clim) to a more appropriate range.
%
% Inputs:
%   x_coords            : 1D array of Cross-range (X) coordinates (m) for detections.
%                         Expected to contain all points.
%   y_coords            : 1D array of Down-range (Y) coordinates (m) for detections.
%                         Expected to contain all points.
%   eta_linear_data     : 1D array of LINEAR eta values (m^-1) for color mapping.
%                         Expected to contain all points.
%   aoo_Ylim_for_box    : 1x2 array [ymin, ymax] defining the Y-range (Down-range)
%                         for the Area of Observation box.
%   nominal_tr_distance : Scalar, the nominal distance of the Triple Reflector.
%   file_info_struct    : Struct containing file information (tr_dist, rain_rate, rep_num).
%   aoo_Xlim_for_box    : 1x2 array [xmin, xmax] defining the X-range (Cross-range)
%                         for the Area of Observation box.
%   hPBWphi             : Horizontal Power Beam Width in radians (for cone filtering).
%
% Outputs:
%   None. Generates a figure directly.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('DEBUG: Entering plot_range_crossrange_map function (Strict Cross-Range Limits for Plot).\n');

    % Create a new figure for the Range-Crossrange Map
    fig_handle = figure('Name', sprintf('Range-Crossrange Map: TR@%dm, R=%dmm/h, Repetition %d', ...
                                        file_info_struct.tr_dist, file_info_struct.rain_rate, file_info_struct.rep_num), ...
                        'NumberTitle', 'off', 'Position', [100 100 900 700]);
    ax_handle = axes(fig_handle);
    hold(ax_handle, 'on');
    grid(ax_handle, 'on');

    % --- Define Plot Axis Limits (Full Data Range for display) ---
    % Down-Range on X-axis, Cross-Range on Y-axis
    % X-axis limit: 0 to TR position + 5m (or a fixed broader max for visual consistency)
    plot_Xlim_full_downrange = [0, max(nominal_tr_distance, 70)]; % Extend to 70m if TR is less
    
    % Y-axis limit: 
    plot_Ylim_full_crossrange = [-20, 20]; 
    
    xlim(ax_handle, plot_Xlim_full_downrange);
    ylim(ax_handle, plot_Ylim_full_crossrange);

    % --- Apply Main Beam (Cone) Filtering based on hPBWphi AND plot limits ---
    % Calculate the maximum cross-range extent at each down-range (y_coord)
    % based on the horizontal beamwidth (hPBWphi).
    % The half-angle of the beam is hPBWphi / 2.
    % max_cross_range = tan(half_beam_angle) * down_range
    
    % Ensure y_coords are positive for tan calculation (down-range must be >= 0).
    y_coords_for_filter = max(y_coords, 0.1); 
    
    max_cross_range_at_each_y = tan(hPBWphi / 2) * y_coords_for_filter;
    
    % Filter conditions now include the strict plot_Ylim_full_crossrange
    beam_filter_indices = ...
        (y_coords >= plot_Xlim_full_downrange(1) & y_coords <= plot_Xlim_full_downrange(2)) & ...
        (x_coords >= plot_Ylim_full_crossrange(1) & x_coords <= plot_Ylim_full_crossrange(2)) & ... % NEW: Filter by strict Y-axis plot limits
        (abs(x_coords) <= max_cross_range_at_each_y); % Keep existing beam-width filtering
    
    filtered_x_coords = x_coords(beam_filter_indices);
    filtered_y_coords = y_coords(beam_filter_indices);
    filtered_eta_linear_data = eta_linear_data(beam_filter_indices);

    % --- Plot all aggregated data (now filtered by main beam cone) ---
    if ~isempty(filtered_x_coords)
        % Swapped filtered_x_coords (Cross-Range) and filtered_y_coords (Down-Range) for plotting (y_coords on X, x_coords on Y)
        scatter_obj = scatter(ax_handle, filtered_y_coords, filtered_x_coords, 10, filtered_eta_linear_data, 'filled', 'DisplayName', 'Radar Detections', ...
                              'MarkerFaceAlpha', 0.4); 
    else
        % Plot an empty scatter if no valid data after filtering
        scatter_obj = scatter(ax_handle, NaN, NaN, 10, NaN, 'filled', 'DisplayName', 'No Valid Detections', ...
                              'MarkerFaceAlpha', 0.4); 
    end

    % --- Add Red Dashed Bounding Box for Area of Observation (AoO) ---
    % This box uses the specific AoO limits passed.
    % Swapped coordinates for the bounding box to match the new axis orientation
    red_box_x_plot = [aoo_Ylim_for_box(1), aoo_Ylim_for_box(2), aoo_Ylim_for_box(2), aoo_Ylim_for_box(1), aoo_Ylim_for_box(1)];
    red_box_y_plot = [aoo_Xlim_for_box(1), aoo_Xlim_for_box(1), aoo_Xlim_for_box(2), aoo_Xlim_for_box(2), aoo_Xlim_for_box(1)];
    plot(ax_handle, red_box_x_plot, red_box_y_plot, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Area of Observation (AoO)');

    % --- Removed Black Dashed Line for Nominal TR Distance ---
    % if ~isnan(nominal_tr_distance)
    %     % Nominal TR distance is in Down-Range, which is now the X-axis
    %     plot(ax_handle, [nominal_tr_distance nominal_tr_distance], ylim(ax_handle), ... % Plotting as a vertical line
    %          'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('Nominal TR at %dm', nominal_tr_distance));
    % end

    % --- Colorbar Setup (using linear eta values) ---
    colormap(ax_handle, 'jet');
    colorbar_handle = colorbar(ax_handle);
    colorbar_handle.Label.String = '$\eta$ (m$^{-1}$)'; % Label for linear eta
    colorbar_handle.Label.Interpreter = 'latex';

    % --- MANUALLY SET CLIM FOR TR VISIBILITY ---
    % Based on your reference plot's appearance and the current colorbar scale,
    % a range like [0, 300] or [0, 500] might make the TR (if its value is in that range)
    % appear orange/yellow, while keeping lower rain values blue.
    % YOU MAY NEED TO ADJUST THE UPPER LIMIT (e.g., 300) based on your actual TR's reflectivity value
    % and the range of values you want to highlight.
    clim(ax_handle, [0, 300]); 
    fprintf('INFO: clim manually set to [0, 300] to enhance TR visibility. Adjust as needed.\n');


    % --- Labels and Title ---
    title_str = sprintf('Range-Crossrange Map: TR@%dm, R=%dmm/h, Repetition %d', ...
                        file_info_struct.tr_dist, file_info_struct.rain_rate, file_info_struct.rep_num);
    title(ax_handle, title_str, 'Interpreter', 'latex');
    xlabel(ax_handle, 'Down-Range (m)', 'Interpreter', 'latex'); % Swapped label
    ylabel(ax_handle, 'Cross-Range (m)', 'Interpreter', 'latex'); % Swapped label

    % --- IMPORTANT: Removed 'axis equal' to allow independent scaling of axes ---
    % This ensures the explicit 'ylim' for cross-range is strictly enforced.
    % If 'axis equal' were present, it might try to expand the Y-axis to match X-axis units
    % if the X-axis range is much larger, overriding the desired Y-axis limit.
    % axis equal; % REMOVED

    % Adjust view and legend
    view(ax_handle, 2); % Ensure 2D view
    legend(ax_handle, 'Location', 'best'); % Place legend after all elements are plotted

    drawnow; % Force rendering
    
    % Save plot as SVG (optional)
    output_folder = fullfile('output_plots', 'Range_Crossrange_Maps');
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end
    svg_filename = fullfile(output_folder, sprintf('Range_Crossrange_Map_TR%dm_Rain%d_Rep%d.svg', ...
                                    file_info_struct.tr_dist, file_info_struct.rain_rate, file_info_struct.rep_num));
    try
        saveas(fig_handle, svg_filename);
        fprintf('Range-Crossrange Map saved as SVG: %s\n', svg_filename);
    catch ME
        warning('MATLAB:saveas:SaveFailed', 'Failed to save Range-Crossrange Map as SVG: %s', ME.message); 
    end

    hold(ax_handle, 'off');
    fprintf('DEBUG: Exiting plot_range_crossrange_map function.\n');
end



%%
%{
function plot_range_crossrange_map(...
    x_coords, y_coords, eta_linear_data, ...
    aoo_Ylim_for_box, nominal_tr_distance, file_info_struct, ...
    aoo_Xlim_for_box, plot_Ylim_full_range) % plot_Ylim_full_range is now a dummy
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT_RANGE_CROSSRANGE_MAP
%   Generates a static 2D scatter plot of aggregated radar detections
%   showing Down-range (X-axis) vs. Cross-range (Y-axis).
%   Points are colored by their LINEAR reflectivity (eta, in m^-1).
%   This version displays ALL valid data points within a "main beam" filter
%   and highlights the Area of Observation (AoO) with a red dashed bounding box.
%   Marker size and color scaling are refined for better visualization.
%
% Inputs:
%   x_coords            : 1D array of Cross-range (X) coordinates (m) for detections.
%                         Expected to contain all points, not just AoO-filtered.
%   y_coords            : 1D array of Down-range (Y) coordinates (m) for detections.
%                         Expected to contain all points, not just AoO-filtered.
%   eta_linear_data     : 1D array of LINEAR eta values (m^-1) for color mapping.
%                         Expected to contain all points, not just AoO-filtered.
%   aoo_Ylim_for_box    : 1x2 array [ymin, ymax] defining the Y-range (Down-range)
%                         for the Area of Observation box.
%   nominal_tr_distance : Scalar, the nominal distance of the Triple Reflector.
%   file_info_struct    : Struct containing file information (tr_dist, rain_rate, rep_num).
%   aoo_Xlim_for_box    : 1x2 array [xmin, xmax] defining the X-range (Cross-range)
%                         for the Area of Observation box.
%   plot_Ylim_full_range : Placeholder, now calculated internally based on TR distance.
%
% Outputs:
%   None. Generates a figure directly.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('DEBUG: Entering plot_range_crossrange_map function (Refined Plot Limits).\n');

    % Create a new figure for the Range-Crossrange Map
    fig_handle = figure('Name', sprintf('Range-Crossrange Map: TR@%dm, R=%dmm/h, Repetition %d', ...
                                        file_info_struct.tr_dist, file_info_struct.rain_rate, file_info_struct.rep_num), ...
                        'NumberTitle', 'off', 'Position', [100 100 900 700]);
    ax_handle = axes(fig_handle);
    hold(ax_handle, 'on');
    grid(ax_handle, 'on');

    % --- Define Plot Axis Limits (Full Data Range for display) ---
    % Down-Range on X-axis, Cross-Range on Y-axis
    % X-axis limit: 0 to TR position + 5m
    plot_Xlim_full_downrange = [0, nominal_tr_distance + 5];
    % Y-axis limit: -3 to 3m for Cross-Range
    plot_Ylim_full_crossrange = [-3, 3];
    
    xlim(ax_handle, plot_Xlim_full_downrange);
    ylim(ax_handle, plot_Ylim_full_crossrange);

    % --- Apply Main Beam Filtering ---
    % Define a broader "main beam" region for filtering data before plotting.
    % This removes points clearly outside the radar's primary field of view.
    main_beam_cross_range_lim = [-10, 10]; % Example: a wider but still focused cross-range limit
    
    % Filter all input data (x_coords, y_coords, eta_linear_data)
    % based on the main beam cross-range and the overall down-range limits.
    main_beam_filter_indices = ...
        (y_coords >= plot_Xlim_full_downrange(1) & y_coords <= plot_Xlim_full_downrange(2)) & ... % Filter by plot's down-range limits
        (x_coords >= main_beam_cross_range_lim(1) & x_coords <= main_beam_cross_range_lim(2));   % Filter by main beam cross-range
    
    filtered_x_coords = x_coords(main_beam_filter_indices);
    filtered_y_coords = y_coords(main_beam_filter_indices);
    filtered_eta_linear_data = eta_linear_data(main_beam_filter_indices);

    % --- Plot all aggregated data (now filtered by main beam) ---
    if ~isempty(filtered_x_coords)
        % Swapped filtered_x_coords and filtered_y_coords for plotting (y_coords on X, x_coords on Y)
        scatter_obj = scatter(ax_handle, filtered_y_coords, filtered_x_coords, 15, filtered_eta_linear_data, 'filled', 'DisplayName', 'Radar Detections'); % Increased marker size to 15
    else
        % Plot an empty scatter if no valid data after filtering
        scatter_obj = scatter(ax_handle, NaN, NaN, 15, NaN, 'filled', 'DisplayName', 'No Valid Detections');
    end

    % --- Add Red Dashed Bounding Box for Area of Observation (AoO) ---
    % This box uses the specific AoO limits passed, but the plot limits are wider.
    % Swapped coordinates for the bounding box to match the new axis orientation
    red_box_x_plot = [aoo_Ylim_for_box(1), aoo_Ylim_for_box(2), aoo_Ylim_for_box(2), aoo_Ylim_for_box(1), aoo_Ylim_for_box(1)];
    red_box_y_plot = [aoo_Xlim_for_box(1), aoo_Xlim_for_box(1), aoo_Xlim_for_box(2), aoo_Xlim_for_box(2), aoo_Xlim_for_box(1)];
    plot(ax_handle, red_box_x_plot, red_box_y_plot, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Area of Observation (AoO)');

    % --- Add Black Dashed Line for Nominal TR Distance ---
    if ~isnan(nominal_tr_distance)
        % Nominal TR distance is in Down-Range, which is now the X-axis
        plot(ax_handle, [nominal_tr_distance nominal_tr_distance], ylim(ax_handle), ... % Plotting as a vertical line
             'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', sprintf('Nominal TR at %dm', nominal_tr_distance));
    end

    % --- Colorbar Setup (using linear eta values) ---
    colormap(ax_handle, 'jet');
    colorbar_handle = colorbar(ax_handle);
    colorbar_handle.Label.String = '$\eta$ (m$^{-1}$)'; % Label for linear eta
    colorbar_handle.Label.Interpreter = 'latex';

    % Dynamically set clim based on the *filtered* eta data range
    if ~isempty(filtered_eta_linear_data)
        % Use 1st and 95th percentiles to avoid extreme outliers skewing the color scale
        min_eta_val = prctile(filtered_eta_linear_data, 1);
        max_eta_val = prctile(filtered_eta_linear_data, 95); % Use 95th percentile for max

        % Ensure a minimum positive value for min_eta_val to avoid log(0) issues or all blue
        min_eta_val = max(min_eta_val, 1e-7); % Set a floor if very small
        
        % Ensure max_eta_val is greater than min_eta_val for a valid range
        if max_eta_val <= min_eta_val + eps(max_eta_val) % Add machine epsilon for comparison
            % If the range is too narrow (e.g., almost constant data), provide a default visible range
            if max_eta_val == 0
                clim(ax_handle, [0, 1e-6]); % For all zeros
            else
                clim(ax_handle, [min_eta_val * 0.9, min_eta_val * 1.1 + eps]); % Small buffer around constant
            end
        else
            clim(ax_handle, [min_eta_val, max_eta_val]); 
        end
    else
        clim(ax_handle, [0, 1e-4]); % Default if no data
    end

    % --- Labels and Title ---
    title_str = sprintf('Range-Crossrange Map: TR@%dm, R=%dmm/h, Repetition %d', ...
                        file_info_struct.tr_dist, file_info_struct.rain_rate, file_info_struct.rep_num);
    title(ax_handle, title_str, 'Interpreter', 'latex');
    xlabel(ax_handle, 'Down-Range (m)', 'Interpreter', 'latex'); % Swapped label
    ylabel(ax_handle, 'Cross-Range (m)', 'Interpreter', 'latex'); % Swapped label

    % Adjust view and legend
    view(ax_handle, 2); % Ensure 2D view
    axis equal; % Maintain aspect ratio within the set limits
    legend(ax_handle, 'Location', 'best'); % Place legend after all elements are plotted

    drawnow; % Force rendering
    
    % Save plot as SVG (optional)
    output_folder = fullfile('output_plots', 'Range_Crossrange_Maps');
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end
    svg_filename = fullfile(output_folder, sprintf('Range_Crossrange_Map_TR%dm_Rain%d_Rep%d.svg', ...
                                    file_info_struct.tr_dist, file_info_struct.rain_rate, file_info_struct.rep_num));
    try
        saveas(fig_handle, svg_filename);
        fprintf('Range-Crossrange Map saved as SVG: %s\n', svg_filename);
    catch ME
        warning('MATLAB:saveas:SaveFailed', 'Failed to save Range-Crossrange Map as SVG: %s', ME.message); 
    end

    hold(ax_handle, 'off');
    fprintf('DEBUG: Exiting plot_range_crossrange_map function.\n');
end
%}