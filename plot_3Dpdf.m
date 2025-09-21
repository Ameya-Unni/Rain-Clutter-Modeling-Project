function [fig_handle, ax_handle] = plot_3Dpdf(...
    figtitle_base, plot_title_part, figtitle_parts, ...
    rcs_data_bb, utc_ms_timestamps, binedges_dummy, width, save_as_svg)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT_3DPDF
%   Generates a 3D Probability Density Function (PDF) waterfall plot
%   showing the evolution of the reflectivity (eta, linear scale) PDF over time.
%   Each slice along the time axis represents the PDF of eta values for
%   a specific time window. The plot uses a 'mesh' type for the waterfall effect.
%
% Inputs:
%   figtitle_base       : Base title for figures (string).
%   plot_title_part     : Specific plot title part (string).
%   figtitle_parts      : Cell array of title components (for side label).
%   rcs_data_bb         : NxM matrix of LINEAR eta values (m^-1) for each snapshot.
%                         (Expected to be bounding-box filtered, potentially with NaNs).
%   utc_ms_timestamps   : N-element array of UTC timestamps in milliseconds for each snapshot.
%   binedges_dummy      : Placeholder (not used, internal binning now).
%   width               : Width of the sliding window (number of snapshots) for time aggregation.
%   save_as_svg         : Flag (0 or 1) to save plot as SVG.
%
% Outputs:
%   fig_handle          : Handle to the created figure.
%   ax_handle           : Handle to the axes within the figure.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('DEBUG: Entering plot_3Dpdf function (Waterfall Plot for Linear Eta).\n');

    num_snapshots = size(rcs_data_bb, 1);
    
    if num_snapshots == 0
        warning('No data to plot for 3D PDF. Skipping plot.');
        fig_handle = [];
        ax_handle = [];
        return;
    end
    
    % Ensure rcs_data_bb is cleaned of NaNs for determining global min/max for binning
    all_rcs_values_flat = rcs_data_bb(:);
    all_rcs_values_clean = all_rcs_values_flat(~isnan(all_rcs_values_flat) & ~isinf(all_rcs_values_flat) & isreal(all_rcs_values_flat));

    if isempty(all_rcs_values_clean)
        warning('No valid reflectivity data after cleaning for 3D PDF. Plot will be empty.');
        fig_handle = [];
        ax_handle = [];
        return;
    end

    % --- Define X-axis (eta) bin edges based on overall data distribution ---
    num_eta_bins = 100; % Define a reasonable number of bins for the eta axis
    
    % Determine percentile-based min/max for robust binning
    min_eta_val = prctile(all_rcs_values_clean, 1); % 1st percentile
    max_eta_val = prctile(all_rcs_values_clean, 99); % 99th percentile
    
    % Ensure min_eta_val is non-negative and max_eta_val is sufficiently larger
    min_eta_val = max(0, min_eta_val); 
    % Added a more aggressive max for eta_val to stretch the X-axis for better visibility
    % The reference plot has a very wide distribution on its X-axis.
    % You might need to tune this `1e-2` (0.01) based on your specific data's max eta.
    if (max_eta_val - min_eta_val) < 1e-7 || max_eta_val < 1e-3 % Ensure a minimum span or a reasonable upper bound
        max_eta_val = max(max_eta_val, 1e-2); % Use 0.01 as a more visible upper limit if auto-detected max is too small
        if min_eta_val == 0 && max_eta_val == 1e-2 % Prevent case where range is [0, 0.01] and all data is at 0
             max_eta_val = 1e-1; % Even wider default for very low values
        end
    end

    eta_bin_edges = linspace(min_eta_val, max_eta_val, num_eta_bins + 1);
    eta_bin_centers = (eta_bin_edges(1:end-1) + eta_bin_edges(2:end)) / 2;

    % --- Prepare Z-data (PDF values) matrix over time ---
    pdf_matrix = zeros(num_snapshots, num_eta_bins);

    for t_idx = 1:num_snapshots
        current_snapshot_data = rcs_data_bb(t_idx, :);
        current_snapshot_data_clean = current_snapshot_data(~isnan(current_snapshot_data) & ~isinf(current_snapshot_data));
        
        if isempty(current_snapshot_data_clean)
            pdf_matrix(t_idx, :) = zeros(1, num_eta_bins); % Fill with zeros for empty slices
        else
            % Calculate PDF for current snapshot
            [counts, ~] = histcounts(current_snapshot_data_clean, eta_bin_edges, 'Normalization', 'pdf');
            pdf_matrix(t_idx, :) = counts;
        end
    end
    
    % Filter out rows where all PDF values are zero (i.e., no detections) for a cleaner plot
    non_zero_pdf_rows = any(pdf_matrix ~= 0, 2);
    pdf_matrix_filtered = pdf_matrix(non_zero_pdf_rows, :);
    utc_ms_timestamps_filtered = utc_ms_timestamps(non_zero_pdf_rows);

    if isempty(pdf_matrix_filtered)
        warning('No non-zero PDF data left after cleaning for 3D PDF. Skipping plot.');
        fig_handle = [];
        ax_handle = [];
        return;
    end

    % Convert UTC milliseconds to datetime objects for display
    actual_utc_times_for_plot = datetime(utc_ms_timestamps_filtered, 'ConvertFrom', 'epochtime', 'TicksPerSecond', 1e3, 'Format', 'HH:mm:ss');
    
    % Create a numeric time index for plotting along Y-axis, or use a relative time (seconds)
    time_points_seconds = (utc_ms_timestamps_filtered - utc_ms_timestamps_filtered(1)) / 1000; % Time in seconds from start

    % Create figure
    fig_handle = figure('Name', sprintf('3D PDF of Detections: %s', figtitle_base), ...
                        'NumberTitle', 'off', 'Position', [100 100 1200 800]);
    ax_handle = axes(fig_handle);
    hold(ax_handle, 'on');
    grid(ax_handle, 'on');

    % --- Create the waterfall/mesh plot ---
    % X: eta_bin_centers (reflectivity)
    % Y: time_points_seconds (time)
    % Z: pdf_matrix_filtered (PDF values)
    
    % Generate mesh grid for X and Y axes
    [X_mesh, Y_mesh] = meshgrid(eta_bin_centers, time_points_seconds);
    
    % Plot using mesh for the waterfall effect
    % Using 'FaceColor', 'interp' for smoother color transitions within faces
    % 'EdgeColor', [0.7 0.7 0.7] for subtle grid lines
    % 'FaceAlpha', 0.8 for slight transparency
    mesh_obj = mesh(ax_handle, X_mesh, Y_mesh, pdf_matrix_filtered, pdf_matrix_filtered); % Color by Z-value
    set(mesh_obj, 'FaceColor', 'interp', 'EdgeColor', [0.7 0.7 0.7], 'FaceAlpha', 0.8); 
    
    colormap(ax_handle, 'jet'); % Use jet colormap for vibrant colors

    % --- Set view, labels, and title ---
    view(ax_handle, 3); % 3D view
    
    title_str = sprintf('3D PDF of Detections: %s', plot_title_part);
    title(ax_handle, title_str, 'Interpreter', 'latex');
    
    xlabel(ax_handle, '$\eta$ (m$^{-1}$)', 'Interpreter', 'latex');
    ylabel(ax_handle, 'Measurement Time (s)', 'Interpreter', 'latex'); % Label for time in seconds
    zlabel(ax_handle, 'PDF p($\eta$)', 'Interpreter', 'latex');

    % Set X-axis tick format to scientific notation
    ax_handle.XAxis.TickLabelFormat = '%.1e'; % Example: 1.0e-04

    % Custom Y-axis (time) ticks for better readability
    if ~isempty(actual_utc_times_for_plot)
        num_major_ticks = min(5, length(actual_utc_times_for_plot)); % Up to 5 major ticks
        if num_major_ticks > 1
            tick_indices = round(linspace(1, length(actual_utc_times_for_plot), num_major_ticks));
            ax_handle.YTick = time_points_seconds(tick_indices);
            ax_handle.YTickLabel = datestr(actual_utc_times_for_plot(tick_indices), 'HH:MM:SS');
        end
    end
    
    % --- Set Z-axis limits based on PDF values, with an adjusted upper bound for better color distribution ---
    % Dynamically set caxis based on actual PDF value range
    min_pdf_value_for_caxis = 0; % PDF values are non-negative
    
    % Calculate max PDF value for caxis based on a higher percentile to avoid outliers crushing the color scale
    % Using 99th percentile of *non-zero* PDF values to capture relevant range.
    pdf_values_for_caxis = pdf_matrix_filtered(pdf_matrix_filtered > 0);
    if ~isempty(pdf_values_for_caxis)
        max_pdf_value_for_caxis = prctile(pdf_values_for_caxis, 99); 
        % Add a small buffer to the upper caxis limit
        max_pdf_value_for_caxis = max_pdf_value_for_caxis * 1.1;
    else
        max_pdf_value_for_caxis = 0.1; % Default if no non-zero PDF values
    end

    if max_pdf_value_for_caxis > 0
        caxis(ax_handle, [min_pdf_value_for_caxis, max_pdf_value_for_caxis]);
    else
        caxis(ax_handle, [0, 0.1]); % Fallback for very flat or empty PDFs
    end

    % Set Z-axis limits based on PDF values
    % Also use a percentile for Z-axis max if the absolute max is an extreme outlier
    z_axis_max_val = max(pdf_matrix_filtered(:));
    if z_axis_max_val > 0
        zlim(ax_handle, [0, z_axis_max_val * 1.1]); % Add a small buffer for Z-axis
    else
        zlim(ax_handle, [0, 0.1]); % Default for very flat PDFs
    end

    % Colorbar
    colorbar_handle = colorbar(ax_handle);
    colorbar_handle.Label.String = 'PDF Value'; % Colorbar indicates PDF value
    colorbar_handle.Label.Interpreter = 'latex';
    
    % Add side label (if needed, using figtitle_parts)
    if ~isempty(figtitle_parts{1}) && length(figtitle_parts) > 1
        text_z_pos = 0.5; % Mid-point of Z-axis
        % Position the text in data coordinates (X, Y, Z) for 3D plot
        % For optimal placement, consider positioning based on relative axes.
        % Placing it near the corner of the plot volume.
        text(ax_handle, ax_handle.XLim(2), min(time_points_seconds), max_pdf_height * text_z_pos, ...
             sprintf('Radar Detections: %s %s %s', figtitle_parts{2}, figtitle_parts{3}, figtitle_parts{4}), ...
             'Units', 'data', 'Rotation', -90, ... 
             'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ... % Adjusted alignment
             'Interpreter', 'latex', 'FontSize', 10);
    end

    drawnow;

    % Save plot as SVG (optional)
    if save_as_svg == 1
        output_folder = fullfile('output_plots', '3D_PDF_Plots');
        if ~exist(output_folder, 'dir')
            mkdir(output_folder);
        end
        svg_filename = fullfile(output_folder, sprintf('%s_3D_PDF_Waterfall.svg', figtitle_base));
        try
            saveas(fig_handle, svg_filename);
            fprintf('3D PDF Waterfall plot saved as SVG: %s\n', svg_filename);
        catch ME
            warning('MATLAB:saveas:SaveFailed', 'Failed to save 3D PDF plot as SVG: %s', ME.message); 
        end
    end
    
    hold(ax_handle, 'off');
    fprintf('DEBUG: Exiting plot_3Dpdf function.\n');
end

%%
%{
function [fig9,ax9] = plot_3Dpdf(...
    figtitle, figtitle_plot, figtitle_parts,...
    near_rcs_bb,...
    near_utc_ms,...
    binedges, width,...
    save_as_svg)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % PLOT_3DPDF
    %   This function generates a 3D time-variant Probability Density Function (PDF)
    %   plot for Near Scan radar detections within a bounding box. It aggregates
    %   RCS data over defined time windows to create smoother and more
    %   representative PDF slices.
    %
    % Inputs:
    %   figtitle          : Main title for the figure windows (string).
    %   figtitle_plot     : Specific plot title part for display on the figure itself (string).
    %   figtitle_parts    : Cell array with parts of the figure title (e.g., {'', 'TR 30m', 'Rain 98', 'Rep 1'}).
    %   near_rcs_bb       : Filtered Near Scan RCS data (in dBsm, matrix: time_steps x detections_per_snapshot).
    %   near_utc_ms       : UTC timestamps (in ms) for Near Scan data.
    %   binedges          : Edges for histogram bins (e.g., -50:0.5:30 dBsm).
    %   width             : The number of time snapshots to aggregate for each PDF slice.
    %   save_as_svg       : Flag (0 or 1) to enable/disable saving figure as SVG.
    %
    % Outputs:
    %   fig9              : Figure handle for the 3D PDF plot.
    %   ax9               : Axes handle for the 3D PDF plot.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Check if near_rcs_bb is empty or has insufficient data for the given width.
    num_total_snapshots = size(near_rcs_bb,1);
    
    % Calculate how many full windows can be formed
    num_windows = floor(num_total_snapshots / width);

    if isempty(near_rcs_bb) || num_total_snapshots < width
        warning('Near scan data is empty or has insufficient time snapshots (%d) for 3D PDF plot with the specified window width (%d). Skipping Near Scan 3D PDF plot.', num_total_snapshots, width);
        fig9 = [];
        ax9 = [];
        return; % Exit function early if no valid data
    end

    % Pre-allocate N_near for efficiency
    N_near = nan(num_windows, size(binedges,2)-1);
    Y_coords_near = nan(num_windows, 1);
    
    % --- Loop through each defined time window for Near Scan. ---
    for window_idx = 1:num_windows
        start_idx = (window_idx - 1) * width + 1;
        end_idx = start_idx + width - 1;
        
        % Aggregate all valid (non-NaN, non-Inf) RCS values within the current window
        current_window_rcs = near_rcs_bb(start_idx:end_idx, :);
        current_window_rcs = current_window_rcs(:); % Flatten to a column vector
        current_window_rcs = current_window_rcs(~isnan(current_window_rcs) & isfinite(current_window_rcs)); % Remove NaN/Inf
        
        if ~isempty(current_window_rcs)
            % Calculate histogram for the aggregated data in this window
            N_near(window_idx,:) = histcounts(current_window_rcs, binedges, "Normalization", "pdf");
            % Use the timestamp of the start of the window (or midpoint, or end)
            Y_coords_near(window_idx) = (near_utc_ms(start_idx,1) - near_utc_ms(1,1)) ./ 1000; % Convert to seconds
        else
            N_near(window_idx,:) = zeros(1, size(binedges,2)-1); % Row of zeros if no data in window
            Y_coords_near(window_idx) = (near_utc_ms(start_idx,1) - near_utc_ms(1,1)) ./ 1000;
        end
    end

    % Remove any rows that are still NaN if num_windows was smaller than pre-allocated.
    N_near = N_near(~any(isnan(N_near), 2), :);
    Y_coords_near = Y_coords_near(~isnan(Y_coords_near));

    if isempty(N_near)
        warning('No valid PDF windows could be formed for Near Scan after data aggregation. Skipping plot.');
        fig9 = [];
        ax9 = [];
        return;
    end
    
    % Handle single-row N_near case for waterfall plot to avoid error.
    % Waterfall requires at least 2 rows for the surface.
    if size(N_near, 1) == 1
        N_near = [N_near; N_near]; % Duplicate the single row
        if isscalar(Y_coords_near)
             Y_coords_near = [Y_coords_near; Y_coords_near + 1e-6]; % Add a tiny offset for time
        else
            Y_coords_near = [Y_coords_near(1); Y_coords_near(1) + 1e-6]; % Duplicate first time and add offset
        end
    end

    [X,Y] = meshgrid(binedges(1,1:end-1), Y_coords_near);
    
    fig9 = figure(9);
    fig9.Name = strcat("NearScan/ 3D-PDF of detections: ",figtitle_plot);
    fig9.Position = [500 300 1600 900]; % Adjusted size for 3D plot
    
    h_waterfall = waterfall(X,Y,N_near);
    
    colormap('parula'); % Use 'parula' or 'jet' for better color distinction
    shading flat;       % Use 'flat' shading for clear bin boundaries
    set(h_waterfall, 'FaceAlpha', 0.4); % MODIFIED: Made surfaces more transparent for better flow
    set(h_waterfall, 'EdgeColor', 'flat'); % Color edges based on data

    ax9 = gca; % Get current axes handle
    
    ax9.XLim = [binedges(1,1) binedges(1,end-1)];
    ax9.YLim = [min(Y_coords_near), max(Y_coords_near)]; % Set Y-limits based on actual data
    
    ax9.XLabel.String = "RCS $\sigma$ (dBsm)"; % LaTeX interpreter for labels
    ax9.YLabel.String = "Measurement time t (s)";
    ax9.ZLabel.String = "PDF p($\sigma$)";
    
    % Construct title from figtitle_parts
    title_str = '';
    if length(figtitle_parts) >= 4
        title_str = sprintf('3D-PDF of detections: %s @ distance: %s, %s', ...
                            figtitle_parts{2}, figtitle_parts{3}, figtitle_parts{4});
    else
        title_str = strcat("3D-PDF of detections: ", figtitle_plot);
    end
    ax9.Title.String = title_str;
    ax9.Title.Interpreter = 'latex'; % Set title interpreter to LaTeX
    
    ax9.View = [20 45]; % MODIFIED: Adjusted view angle for better waterfall effect
    
    % Adjust Y-axis label position and rotation for better visibility
    ax9.YLabel.Position = [ax9.XLim(2) * 0.9, (ax9.YLim(1) + ax9.YLim(2))/2, ax9.ZLim(2) * 0.5]; % Dynamically position
    ax9.YLabel.Rotation = 60; % Rotate for better readability in 3D

    % Dynamically set Z-axis limits for the PDF values based on actual data
    if ~isempty(N_near)
        max_pdf_val_3D = max(N_near(:));
        if max_pdf_val_3D > 0
            ax9.ZLim = [0, max_pdf_val_3D * 1.1]; % Set ZLim with a 10% buffer
        else
            ax9.ZLim = [0, 0.01]; % Default if no density
        end
    else
        ax9.ZLim = [0, 0.01]; % Default if no data
    end
    ax9.FontName = "Arial";
    ax9.FontSize = 12;
    grid on;
    
    cb = colorbar(ax9); % Get colorbar handle
    cb.Label.String = 'PDF p($\sigma$)'; % Set colorbar label
    cb.Label.Interpreter = 'latex'; % Set colorbar label interpreter
    ax9.CLim = ax9.ZLim; % Ensure color limits match Z-axis limits for PDF

    % --- Optional: Save figure as SVG ---
    if save_as_svg == 1
        % Derive a clean filename from the figure's name.
        save_filename_base = strrep(figtitle, ':', '');
        save_filename_base = strrep(save_filename_base, '/', '_');
        save_filename_base = strrep(save_filename_base, ' ', '_');
        save_filename_base = strrep(save_filename_base, '.', '');

        save_filename_near_svg = strcat(save_filename_base, '_Near_3Dpdf.svg');
        fig9.Renderer = "painters"; % For high-quality vector graphics
        saveas(fig9, save_filename_near_svg, "svg");
        fprintf('Saved NearScan 3D PDF plot as: %s\n', save_filename_near_svg);
    end
   
end
%}



%%
%{
function [fig_out, ax_out] = plot_3Dpdf(...
    figtitle, figtitle_plot, figtitle_parts, ...
    rcs_data, utc_ms_data, ...
    binedges, width, ...
    save_as_svg)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2D Colormap PDF
%   This function generates a 2D colormap plot (spectrogram-like) of the
%   Probability Density Function (PDF) of Radar Cross Section (RCS)
%   detections over time. It uses a sliding window to calculate PDFs for
%   different time segments and visualizes them as a colored image.
%
% Inputs:
%   figtitle          : Main title for the figure windows (string).
%   figtitle_plot     : Specific plot title part for display on the figure itself (string).
%   figtitle_parts    : Cell array with parts of the figure title (e.g., {'', 'TR 30m', 'Rain 16', 'Rep 1'}).
%   rcs_data          : RCS values (linear scale) for detections within the bounding box.
%                       Expected to be a NxM matrix where N is time snapshots, M is detections per snapshot.
%   utc_ms_data       : UTC timestamps (in ms) corresponding to each snapshot in rcs_data.
%                       Expected to be a column vector.
%   binedges          : Edges for the histogram bins (e.g., -50:0.5:30 for RCS in dBsm).
%   width             : Number of time snapshots to include in each sliding window for PDF calculation.
%   save_as_svg       : Flag (0 or 1) to enable/disable saving figure as SVG.
%
% Outputs:
%   fig_out           : Figure handle for the 2D colormap PDF plot.
%   ax_out            : Axes handle for the 2D colormap PDF plot.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    fprintf('DEBUG: Entering plot_3Dpdf function.\n');

    fig_out = figure(); % Create a new figure for the 2D colormap PDF
    fig_out.Name = strcat("3D-PDF of detections (2D Colormap): ", figtitle_plot); % Updated name
    fig_out.Position = [100 100 1000 700]; % Set a good size
    fig_out.Renderer = 'painters'; % Use 'painters' for vector graphics if saving as SVG

    ax_out = gca; % Get current axes
    hold(ax_out, 'on');

    num_snapshots = size(rcs_data, 1);
    num_bins = length(binedges) - 1;

    % Check if there's enough data for at least one full window
    if num_snapshots < width
        warning('Not enough data snapshots (%d) for the specified window width (%d). Skipping 2D colormap PDF plot.', num_snapshots, width);
        % Create an empty plot with a message
        text(ax_out, 0.5, 0.5, 'Not enough data for 2D Colormap PDF plot', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Units', 'normalized');
        ax_out.XLabel.String = "RCS \sigma (dBsm)";
        ax_out.YLabel.String = "Measurement time t (s)";
        ax_out.Title.String = strcat("2D Colormap PDF of detections: ", figtitle_parts{2}," @ distance: ",figtitle_parts{3},", ",figtitle_parts{4});
        hold(ax_out, 'off');
        return;
    end

    % Preallocate matrices to store PDF counts and corresponding time coordinates
    num_windows_to_plot = num_snapshots - width + 1;
    all_pdf_counts = zeros(num_windows_to_plot, num_bins);
    time_coords_for_plot = zeros(num_windows_to_plot, 1);
    
    % Ensure utc_ms_data is a column vector
    utc_ms_data = utc_ms_data(:);

    fprintf('DEBUG: Starting window processing for 2D colormap PDF plot. Total snapshots: %d\n', num_snapshots);

    window_counter = 0;
    for start_idx = 1:num_windows_to_plot
        end_idx = start_idx + width - 1;
        
        % Extract RCS data for the current window and flatten it
        current_window_rcs = rcs_data(start_idx:end_idx, :);
        current_window_rcs_flat = current_window_rcs(:);
        
        % Remove NaN and Inf values from the current window's data
        current_window_rcs_clean = current_window_rcs_flat(~isnan(current_window_rcs_flat) & isfinite(current_window_rcs_flat));

        if isempty(current_window_rcs_clean)
            % If no valid data in this window, store zeros for PDF
            counts = zeros(1, num_bins);
        else
            % Calculate histogram for the current window
            [counts, ~] = histcounts(current_window_rcs_clean, binedges, 'Normalization', 'pdf');
        end
        
        % Store the PDF counts
        window_counter = window_counter + 1;
        all_pdf_counts(window_counter, :) = counts;
        
        % Get the time coordinate for this window (using the center of the window)
        window_center_utc_ms = utc_ms_data(floor((start_idx + end_idx)/2));
        elapsed_time_s = (window_center_utc_ms - utc_ms_data(1)) ./ 1000; % Convert to seconds
        time_coords_for_plot(window_counter) = elapsed_time_s;
    end

    % Trim preallocated arrays if fewer windows were processed
    all_pdf_counts = all_pdf_counts(1:window_counter, :);
    time_coords_for_plot = time_coords_for_plot(1:window_counter);

    % Define X-coordinates (RCS bin centers) for the colormap plot
    X_bin_centers = binedges(1:end-1) + diff(binedges)/2; 
    
    % Define Y-coordinates (Time) for the colormap plot
    Y_time_points = time_coords_for_plot;

    % Create the 2D colormap plot using imagesc
    % X_bin_centers defines the x-axis, Y_time_points defines the y-axis
    % all_pdf_counts contains the values to be mapped to color.
    imagesc(ax_out, X_bin_centers, Y_time_points, all_pdf_counts);
    
    colormap(ax_out, 'jet'); % Use 'jet' colormap as seen in examples
    
    % --- FIXED: Create colorbar first, then set its label ---
    cb = colorbar(ax_out, 'Location', 'eastoutside');
    cb.Label.String = 'PDF p($\sigma$)'; % Set color bar label
    cb.Label.Interpreter = 'latex'; % Ensure LaTeX interpreter for the label
    % --- END FIX ---
    
    % Adjust the Y-axis direction to normal, as imagesc often inverts it
    set(ax_out, 'YDir', 'normal'); 

    % Set labels and title
    ax_out.XLabel.String = "RCS \sigma (dBsm)";
    ax_out.YLabel.String = "Measurement time t (s)";
    ax_out.Title.String = strcat("2D Colormap PDF of detections: ", figtitle_parts{2}," @ distance: ",figtitle_parts{3},", ",figtitle_parts{4}); % Updated title
    
    ax_out.FontName = "Arial";
    grid(ax_out, 'on');

    % Set X and Y axis limits based on data and bin edges
    ax_out.XLim = [min(binedges), max(binedges)];
    if ~isempty(Y_time_points)
        ax_out.YLim = [min(Y_time_points), max(Y_time_points)];
    end
    
    hold(ax_out, 'off');

    % Save figure as SVG if enabled
    if save_as_svg == 1
        save_filename = strrep(fig_out.Name, '3D-PDF of detections (2D Colormap): ', '');
        save_filename = strrep(save_filename, ':', '');
        save_filename = strrep(save_filename, '/', '_');
        save_filename = strrep(save_filename, ' ', '_');
        save_filename = strrep(save_filename, '.', '');
        save_filename = strcat(save_filename, '.svg');

        % Renderer is already set to 'painters' at the beginning of the function
        try
            saveas(fig_out, save_filename, "svg");
            fprintf('Saved 2D Colormap PDF plot as: %s\n', save_filename);
        catch ME
            warning('Failed to save SVG: %s', ME.message);
        end
    end

    fprintf('DEBUG: Exiting plot_3Dpdf function.\n');
end

%}




%{
function [fig9,ax9] = plot_3Dpdf(...
    figtitle, figtitle_plot, figtitle_parts,...
    near_rcs_bb,...
    near_utc_ms,...
    binedges, width,...
    save_as_svg)

    % NEAR
    N_near = nan(size(near_rcs_bb,1)-width, size(binedges,2)-1);
    for time_idx = 1:width:size(near_rcs_bb,1)-width
        N_near(time_idx,:) = histcounts(near_rcs_bb(time_idx:time_idx+width,:),binedges,"Normalization","pdf");
    end
    [X,Y] = meshgrid(binedges(1,1:end-1),(near_utc_ms(1:1:size(near_rcs_bb,1)-width)-near_utc_ms(1,1)) ./ 1000);
    fig9 = figure(9);
    fig9.Name = strcat("NearScan/ 3D-PDF of detections: ",figtitle_plot);
    fig9.Position = [500 300 1600 900];
    waterfall(X,Y,N_near);
    ax9 = gca;
    ax9.XLim = [binedges(1,1) binedges(1,end-1)];
    ax9.YLim = [0 (near_utc_ms(size(near_rcs_bb,1)-width,1)-near_utc_ms(1,1))/1000];
    ax9.XLabel.String = "RCS \sigma (dBsm)";
    ax9.YLabel.String = "Measurement time t (s)";
    ax9.ZLabel.String = "PDF p(\sigma)";
    ax9.Title.String = strcat("3D-PDF of detections: ", figtitle_parts(2)," @ distance: ",figtitle_parts(3),", ",figtitle_parts(4));
    ax9.View = [16 69];
    ax9.YLabel.Position = [35,(near_utc_ms(size(near_rcs_bb,1)-width,1)-near_utc_ms(1,1))/2000,0];
    ax9.YLabel.Rotation = 60;
    ax9.ZLim = [0 0.05];
    ax9.FontName = "Arial";
    ax9.FontSize = 12;
    text(0.98,-0.05,0,figtitle_plot,"Units","normalized","HorizontalAlignment","right");

    % save fig1
    filename = split(figtitle," ");
    filename_near = strcat(filename(1),"_",filename(2),"_",filename(3),"_near_3Dpdf.svg");

    if save_as_svg == 1
        fig9.Renderer = "painters";
        saveas(fig9,filename_near,"svg");
     
    end
   

end

%}

%%
%{
function [fig9,fig10, ax9,ax10] = plot_3Dpdf(...
    figtitle, figtitle_plot, figtitle_parts,...
    near_rcs_bb,far_rcs_bb,...
    near_utc_ms, far_utc_ms,...
    binedges, width,...
    save_as_svg)

    % Initialize Near Scan outputs to empty
    fig9 = [];
    ax9 = [];

    % Check if far_rcs_bb is empty or has insufficient data for the given width.
    num_available_snapshots_far = size(far_rcs_bb,1);
    if isempty(far_rcs_bb) || num_available_snapshots_far < width
        warning('Far scan data is empty or has insufficient time snapshots (%d) for 3D PDF plot with the specified window width (%d). Skipping Far Scan 3D PDF plot.', num_available_snapshots_far, width);
        fig10 = [];
        ax10 = [];
        return; % Exit function early if no valid data for Far Scan
    end

    % --- FAR Scan 3D PDF Plotting ---
    N_far_list = {};
    Y_coords_list_far = [];
    
    % Loop through each defined time window for Far Scan.
    for start_idx = 1 : width : (num_available_snapshots_far - width + 1)
        end_idx = start_idx + width - 1;
        
        current_window_rcs_far = far_rcs_bb(start_idx:end_idx, :);
        current_window_rcs_far = current_window_rcs_far(:); % Flatten to a column vector
        current_window_rcs_far = current_window_rcs_far(~isnan(current_window_rcs_far) & isfinite(current_window_rcs_far)); % Remove NaN/Inf

        if ~isempty(current_window_rcs_far)
            N_far_list{end+1} = histcounts(current_window_rcs_far, binedges, "Normalization", "pdf");
            Y_coords_list_far(end+1) = (far_utc_ms(start_idx,1) - far_utc_ms(1,1)) ./ 1000;
        else
            N_far_list{end+1} = zeros(1, size(binedges,2)-1); % Row of zeros if no data
            Y_coords_list_far(end+1) = (far_utc_ms(start_idx,1) - far_utc_ms(1,1)) ./ 1000;
        end
    end

    if isempty(N_far_list)
        warning('No valid PDF windows could be formed for Far Scan after data processing. Skipping plot.');
        fig10 = [];
        ax10 = [];
        return;
    end

    N_far = vertcat(N_far_list{:});
    Y_coords_far = Y_coords_list_far';

    % Handle single-row N_far case for waterfall plot
    if size(N_far, 1) == 1
        N_far = [N_far; N_far]; 
        if numel(Y_coords_far) == 1
             Y_coords_far = [Y_coords_far; Y_coords_far + 1e-6]; 
        else
            Y_coords_far = [Y_coords_far(1); Y_coords_far(1) + 1e-6];
        end
    end

    [X,Y] = meshgrid(binedges(1,1:end-1), Y_coords_far);
    
    fig10 = figure(10);
    fig10.Name = strcat("FarScan/ 3D-PDF of detections: ",figtitle_plot);
    fig10.Position = [500 300 1600 900];
    
    h_waterfall = waterfall(X,Y,N_far);
    
    colormap('parula'); 
    shading interp; 
    set(h_waterfall, 'FaceAlpha', 1); 
    set(h_waterfall, 'EdgeColor', 'flat'); 
    ax10 = gca; 
    
    ax10.XLim = [binedges(1,1) binedges(1,end-1)];
    ax10.YLim = [min(Y_coords_far), max(Y_coords_far)];
    
    ax10.XLabel.String = "RCS \sigma (dBsm)";
    ax10.YLabel.String = "Measurement time t (s)";
    ax10.ZLabel.String = "PDF p(\sigma)";
    
    title_str_far = '';
    if length(figtitle_parts) >= 4
        title_str_far = sprintf('3D-PDF of detections: %s @ distance: %s, %s', ...
                            figtitle_parts{2}, figtitle_parts{3}, figtitle_parts{4});
    else
        title_str_far = strcat("3D-PDF of detections: ", figtitle_plot);
    end
    ax10.Title.String = title_str_far;
    
    ax10.View = [40 25]; 
    ax10.YLabel.Rotation = 60;
    
    % MODIFIED: Dynamically set Z-axis limits for the PDF values based on actual data
    if ~isempty(N_far)
        max_pdf_val_3D_far = max(N_far(:));
        if max_pdf_val_3D_far > 0
            ax10.ZLim = [0, max_pdf_val_3D_far * 1.1]; % Set ZLim with a 10% buffer
        else
            ax10.ZLim = [0, 0.01]; % Default if no density
        end
    else
        ax10.ZLim = [0, 0.01]; % Default if no data
    end

    ax10.FontName = "Arial";
    ax10.FontSize = 12;
    grid on;
    
    cb_far = colorbar;
    cb_far.Label.String = 'PDF p(\sigma)';
    cb_far.Label.Interpreter = 'latex';
    ax10.CLim = ax10.ZLim;
    
    % --- Optional: Save figure as SVG ---
    if save_as_svg == 1 && ~isempty(fig10)
        filename_parts_for_save = split(figtitle," ");
        filename_far_svg  = strcat(filename_parts_for_save{1},"_",filename_parts_for_save{2},"_",filename_parts_for_save{3},"_far_3Dpdf.svg");

        fig10.Renderer = "painters";
        saveas(fig10,filename_far_svg,"svg");
        fprintf('Saved FarScan 3D PDF plot as: %s\n', filename_far_svg);
    end
   
end
%}

%%




%%
%{
function [fig1, ax1, vid_near_out] = plot3_detections(...
    figtitle, ...
    figtitle_plot, ...
    near_x, near_y, near_z, ...
    near_rcs, ...
    setup, ...
    near_utc_time, ...
    video_enable)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT3_DETECTIONS
%   This function generates animated scatter plots of radar detections for
%   NearScan data only, in a standard Cartesian view.
%   The X-axis represents Crossrange (m), Y-axis represents Range (m).
%   Points are colored by their Radar Cross Section (RCS) intensity.
%   It includes a rectangular box, mimicking the provided example image.
%   It can optionally open a VideoWriter object and return it for external
%   frame writing.
%
% Inputs:
%   figtitle        : Main title for the figure windows (string).
%   figtitle_plot   : Specific plot title part for display on the figure itself (string).
%   near_x, near_y, near_z : Cartesian coordinates (x=crossrange, y=range, z=height) for NearScan detections.
%   near_rcs        : RCS values for NearScan detections (used for color).
%   setup           : String indicating the measurement environment ("NIED" or "OUTDOOR").
%   near_utc_time   : UTC timestamp for NearScan (datetime object).
%   video_enable    : Flag (0 or 1) to enable/disable video saving.
%
% Outputs:
%   fig1            : Figure handle for NearScan plot.
%   ax1             : Axes handle for NearScan plot.
%   vid_near_out    : (Optional) VideoWriter object if video_enable is true, else empty.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    vid_near_out = []; % Initialize as empty for cases where video_enable is false

    % --- VideoWriter Initialization ---
    if video_enable == 1
        video_filename_parts = split(figtitle, " ");
        % Adjust filename to reflect standard Cartesian plot
        video_filename_near = strcat(video_filename_parts{1}, "_", video_filename_parts{2}, "_", video_filename_parts_parts{3}, "_near_detections");
        
        try
            vid_near_out = VideoWriter(char(video_filename_near), "MPEG-4"); % Assign to output variable
            vid_near_out.Quality = 100;
            vid_near_out.FrameRate = 10; % IMPORTANT: Set the frame rate explicitly
            open(vid_near_out);
        catch ME
            % Corrected: Pass MException properties using a format specifier
            warning(ME.identifier, 'Failed to initialize VideoWriter: %s. Video saving will be disabled.', ME.message);
            vid_near_out = []; % Ensure it's empty if creation fails
        end
    end
    
    % --- Initial Plotting for Near Scan ---
    fig1 = figure(1);
    % IMPORTANT CHANGE: Set the figure renderer explicitly to OpenGL
    fig1.Renderer = 'opengl';
    set(fig1, 'PaperPositionMode', 'auto'); % Ensure captured frame matches display aspect ratio
    
    % MODIFIED: Adjusted figure position to be less tall, matching the aspect ratio of the reference image.
    fig1.Position = [100 100 900 500]; % Set figure position and size (width 900, height 500)

    % Update figure name to reflect standard radar detections plot
    fig1.Name = strcat("NearScan/Radar Detections: ", figtitle_plot);
    

    % Create the scatter plot for NearScan.
    % IMPORTANT CHANGE: Plot near_x (Crossrange) on X-axis, near_y (Range) on Y-axis
    % Increased MarkerSize to 20 for clearer points as per new example image
    s_near = scatter3(near_x, near_y, near_z, 20, near_rcs, "filled");
    grid on;
    
    ax1 = gca;
    % IMPORTANT CHANGE: Set X and Y axis labels for standard Cartesian plot
    ax1.XLabel.String = "cross range (m)";
    ax1.YLabel.String = "range (m)";
    % MODIFIED: Removed ZLabel as it's a 2D top-down view and not explicitly needed for the visual style.
    % ax1.ZLabel.String = "Height (m)"; % Keep ZLabel for completeness, but viewed in 2D

    % MODIFIED: Set X and Y limits to match the reference image.
    % XLim now matches the new Xlim setting in plot_radar_detections.m ([-20, 20])
    ax1.XLim = [-20 20]; 
    ax1.YLim = [0 70]; % YLim remains [0, 70] as it was already suitable
    
    % Set color limits for RCS (in dBsm).
    % MODIFIED: Adjusted CLim to match the example image's colorbar range (approx -30 to 50 dBsm)
    ax1.CLim = [-30 50]; 
    
    view([0 90]); % Still look from directly above (X-Y plane)
    cb1 = colorbar;
    cb1.Label.String = "RCS (dBsm)";

    % Add main title for the plot (simplified as per new example image)
    title(ax1, sprintf('UTC: %s', string(near_utc_time)));
    hold on; % Hold on to add more elements

    % --- MODIFIED: Removed Gray Shaded Area as requested ---
    % The following code block has been removed as per the user's request
    % to not include the gray shaded part.
    % gray_x = [5, 20, 20, 5, 5];
    % gray_y = [0, 0, 70, 70, 0];
    % patch(ax1, gray_x, gray_y, [0.8 0.8 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'DisplayName', 'Shaded Area');

    % --- Add Blue Rectangular Box ---
    % Coordinates for the blue rectangle as seen in the example image
    % This box visually represents the 'reference bricks' area in the example image
    % Its X-limits [-2.5, 2.5] are narrower than the main plot's X-limits [-20, 20],
    % matching the visual in your reference image.
    blue_box_x = [-2.5, 2.5, 2.5, -2.5, -2.5];
    blue_box_y = [0, 0, 50, 50, 0];
    plot(ax1, blue_box_x, blue_box_y, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Blue Box Area');

    drawnow; % Force MATLAB to render the plot now before returning
    hold off; % Release hold on the axes

    % Closing the VideoWriter is now handled by the calling script (analysis_ars_detections.m)
    % if video_enable == 1
    %     close(vid_near_out);
    %     fprintf('Video saved: %s.mp4\n', video_filename_near);
    % end

end % End of function
%}
