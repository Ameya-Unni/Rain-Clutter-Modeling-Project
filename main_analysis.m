%% ANALYSIS_ARS_DETECTIONS: Generate Scatter Plots of Radar Detections
%% Project for Research by Ameya Unni (ameaya.unni@tu-ilmenau.de)

% This script loads ARS radar measurement data, calculates Cartesian
% coordinates for detected points, and plots them as a scatter map where
% color represents the Radar Cross Section (RCS) intensity. 
clc;
clear;
close all;
clear functions; 

%% Helper function to extract info (distance, rain_rate, rep) from filename
function [distance, rain_rate, rep_num] = extract_full_info_from_filename(filename)
    distance = NaN;
    rain_rate = NaN;
    rep_num = NaN;
    % Try 'dump_data_XXm_rain_YY_Z.mat' format
    tokens_rain = regexp(filename, 'dump_data_(\d+)m_rain_(\d+)_(\d+)\.mat', 'tokens', 'once');
    if ~isempty(tokens_rain)
        distance = str2double(tokens_rain{1});
        rain_rate = str2double(tokens_rain{2});
        rep_num = str2double(tokens_rain{3});
        return;
    end
    % Try 'dump_data_XXm_YY_Z.mat' format (for 30m_98_1 example)
    tokens_norain = regexp(filename, 'dump_data_(\d+)m_(\d+)_(\d+)\.mat', 'tokens', 'once');
    if ~isempty(tokens_norain)
        distance = str2double(tokens_norain{1});
        rain_rate = str2double(tokens_norain{2});
        rep_num = str2double(tokens_norain{3});
        return;
    end
    
    warning('Could not extract full info from filename: %s', filename);
end

%% --- User Configuration: Specify your measurement file ---
fprintf('--- Select a measurement file ---\n');
prompt_file = {'TR Distance (e.g., 30):','Rain Rate (e.g., 16, 32, 98):','File Repetition Number (e.g., 1, 2, 3, 4):'};
dlgtitle_file = 'Select Measurement File';
dims_file = [1 50];
definput_file = {'30', '16', '1'}; % Default values
answer_file = inputdlg(prompt_file, dlgtitle_file, dims_file, definput_file);
if isempty(answer_file)
    disp('File selection cancelled');
    return;
end
try
    selected_tr_dist = str2double(answer_file{1});
    selected_rain_rate = str2double(answer_file{2});
    selected_rep_num = str2double(answer_file{3}); 
    if isnan(selected_tr_dist) || isnan(selected_rain_rate) || isnan(selected_rep_num)
        error('Invalid input');
    end
    % Construct filename based on selected parameters
    root_folder = 'NIED_Data'; % Base folder where your .mat files are located
    if selected_tr_dist == 30 && selected_rain_rate == 98
        filename = fullfile(root_folder, sprintf('dump_data_%dm_%d_%d.mat', selected_tr_dist, selected_rain_rate, selected_rep_num));
    else
        filename = fullfile(root_folder, sprintf('dump_data_%dm_rain_%d_%d.mat', selected_tr_dist, selected_rain_rate, selected_rep_num));
    end
catch ME
    error('Error parsing file selection inputs: %s\n%s', ME.message, 'Please ensure inputs are valid numbers.');
end
% Check if the constructed file exists before proceeding
if ~isfile(filename)
    error('File not found: %s\nPlease update the selected parameters to point to a valid .mat file in your ''NIED_Data'' folder.', filename);
end
fprintf('Loading file: %s\n', filename);
loaded_data = load(filename);
measdata = loaded_data.measdata; 
% --- Setup Configuration ---
setup = "NIED"; 
% --- Dynamic Filename Parsing for Plot Titles ---
[~, name_only, ~] = fileparts(filename);
[tr_dist_val, rain_rate_val, rep_num_val] = extract_full_info_from_filename(filename);
% Construct figtitle and figtitle_plot for display
if ~isnan(tr_dist_val) && ~isnan(rain_rate_val) && ~isnan(rep_num_val)
    figtitle = sprintf('NIED Data: TR %dm Rain %d Rep %d (Azimuth Shift: %.1f deg)', tr_dist_val, rain_rate_val, rep_num_val, 3.5); % Hardcoded 3.5 deg in title
    figtitle_plot = sprintf('Radar Detections: TR %dm Rain %d Rep %d', tr_dist_val, rain_rate_val, rep_num_val);
    figtitle_parts = {'', sprintf('TR %dm', tr_dist_val), sprintf('Rain %d', rain_rate_val), sprintf('Rep %d', rep_num_val)};
else
    figtitle = name_only;
    figtitle_plot = name_only;
    figtitle_parts = {'', '', '', ''}; 
    warning('Could not extract detailed info for title. Using generic titles.');
end
% Azimuth shift
azishift_deg = 3.5; 
 
%% --- Radar Parameters (consistent with extractHighProbDetections) ---
hPBWphi   = deg2rad(53.19);  
hPBWtheta = deg2rad(22.23);   
rangeRes  = 0.416;            
% Define broad extraction limits to capture all potentially relevant data
Xlim_extraction = [-20, 20]; 
Ylim_extraction = [0, 70];   
%% --- Process Near Scan Data (applying high probability detection logic per snapshot) ---
num_snapshots_near = size(measdata.ars430_HH.NearScan.UTCtime_ms, 1);
% Determine the maximum number of detections in any single snapshot to preallocate
max_detections_per_snapshot = 0;
if isfield(measdata.ars430_HH.NearScan, 'Range_m')
    max_detections_per_snapshot = size(measdata.ars430_HH.NearScan.Range_m, 2);
else
    error('NearScan.Range_m is missing from the loaded data. Cannot proceed.');
end
% Preallocate matrices to store processed data, initialized with NaNs
near_x = NaN(num_snapshots_near, max_detections_per_snapshot);
near_y = NaN(num_snapshots_near, max_detections_per_snapshot);
near_z = 0.6 .* ones(num_snapshots_near, max_detections_per_snapshot); 
near_rcs_linear = NaN(num_snapshots_near, max_detections_per_snapshot); 
% Store UTC times, initially as NaT (Not a Time)
near_utc_time_raw = datetime.empty(num_snapshots_near, 0);
fprintf('Processing raw Near Scan data snapshot by snapshot to apply high-probability logic...\n');
for t_idx = 1:num_snapshots_near
    % Ensure required fields exist before creating the scan struct
    if ~isfield(measdata.ars430_HH.NearScan, 'prob0') || ...
       ~isfield(measdata.ars430_HH.NearScan, 'prob1') || ...
       ~isfield(measdata.ars430_HH.NearScan, 'Azimuth0_rad') || ...
       ~isfield(measdata.ars430_HH.NearScan, 'Azimuth1_rad') || ...
       ~isfield(measdata.ars430_HH.NearScan, 'RCS0') || ...
       ~isfield(measdata.ars430_HH.NearScan, 'Range_m')
        warning('Missing one or more required fields (prob0, prob1, Azimuth0_rad, Azimuth1_rad, RCS0, Range_m) in NearScan data at snapshot %d. Skipping this snapshot.', t_idx);
        continue; 
    end
    % Create a temporary struct for the current snapshot's raw data, as expected by extractHighProbDetections
    current_scan_snap.prob0 = measdata.ars430_HH.NearScan.prob0(t_idx, :);
    current_scan_snap.prob1 = measdata.ars430_HH.NearScan.prob1(t_idx, :);
    current_scan_snap.RCS0 = measdata.ars430_HH.NearScan.RCS0(t_idx, :);
    if isfield(measdata.ars430_HH.NearScan, 'RCS1')
        current_scan_snap.RCS1 = measdata.ars430_HH.NearScan.RCS1(t_idx, :);
    else
        current_scan_snap.RCS1 = current_scan_snap.RCS0; 
    end
    current_scan_snap.Azimuth0_rad = measdata.ars430_HH.NearScan.Azimuth0_rad(t_idx, :);
    current_scan_snap.Azimuth1_rad = measdata.ars430_HH.NearScan.Azimuth1_rad(t_idx, :);
    current_scan_snap.Range_m = measdata.ars430_HH.NearScan.Range_m(t_idx, :);
    
    % Call extractHighProbDetections (external function)
    [x_coor_snap, y_coor_snap, eta_linear_snap, ~] = extractHighProbDetections(...
        current_scan_snap, hPBWphi, hPBWtheta, rangeRes, Xlim_extraction, Ylim_extraction, azishift_deg); 
    
    % The outputs x_coor_snap, y_coor_snap, eta_linear_snap are already filtered.
    num_valid_in_snap = length(x_coor_snap); 
    if num_valid_in_snap > 0
        % Store the valid points into the preallocated matrices.
        cols_to_copy = min(num_valid_in_snap, max_detections_per_snapshot);
        near_x(t_idx, 1:cols_to_copy) = x_coor_snap(1:cols_to_copy);
        near_y(t_idx, 1:cols_to_copy) = y_coor_snap(1:cols_to_copy);
        near_rcs_linear(t_idx, 1:cols_to_copy) = eta_linear_snap(1:cols_to_copy);
    end
    
    % Store UTC time
    near_utc_time_raw(t_idx) = datetime(measdata.ars430_HH.NearScan.UTCtime_ms(t_idx,1), "ConvertFrom", "epochtime", "TicksPerSecond", 1e3, "Format", "dd-MMM-uuuu HH:mm:ss.SSS");
end
%% --- Robustly align and filter snapshots for plot3_detections and other plots ---
min_num_rows = num_snapshots_near; 
% Initialize mask for overall valid snapshots (rows)
valid_snapshot_mask_overall = true(min_num_rows, 1);
for idx_snap_check = 1:min_num_rows
    if isnat(near_utc_time_raw(idx_snap_check))
        valid_snapshot_mask_overall(idx_snap_check) = false;
        continue;
    end
    
    if all(isnan(near_x(idx_snap_check,:)))
        valid_snapshot_mask_overall(idx_snap_check) = false;
    end
end
% Apply the overall valid snapshot mask to all primary data arrays
filtered_near_x = near_x(valid_snapshot_mask_overall, :);
filtered_near_y = near_y(valid_snapshot_mask_overall, :);
filtered_near_rcs_linear = near_rcs_linear(valid_snapshot_mask_overall, :); 
filtered_near_z = near_z(valid_snapshot_mask_overall, :); 
filtered_near_utc_time = near_utc_time_raw(valid_snapshot_mask_overall);
filtered_near_utc_ms_for_3D = measdata.ars430_HH.NearScan.UTCtime_ms(valid_snapshot_mask_overall); 
if isempty(filtered_near_x)
    warning('No valid Near Scan data left after initial processing and filtering. Skipping animated scatter plot.');
    vid_near_handle = []; 
else
    fprintf('Plotting animated scatter for %d valid snapshots.\n', size(filtered_near_x, 1));
    %% --- Interactive Y-Axis (Down-Range) Segment Input for Area of Observation (AoO) ---
    prompt_aoo = {'Enter Y-range for Area of Observation (e.g., [1, 50]):'}; 
    dlgtitle_aoo = 'Define Area of Observation (AoO) Y-Range';
    dims_aoo = [1 50];
    definput_aoo = {sprintf('[10, 20]', selected_tr_dist)}; 
    answer_aoo = inputdlg(prompt_aoo, dlgtitle_aoo, dims_aoo, definput_aoo);
    if isempty(answer_aoo)
        disp('File selection cancelled. Exiting script.');
        return;
    end
    try
        current_Ylim_aoo = str2num(answer_aoo{1}); %#ok<ST2NM>
        if isempty(current_Ylim_aoo) || numel(current_Ylim_aoo) ~= 2 || current_Ylim_aoo(2) <= current_Ylim_aoo(1)
            error('Invalid input format. Please enter a 1x2 matrix like [start, end] where end > start.');
        end
        % Ensure AoO minimum range is at least 1m, explicitly
        if current_Ylim_aoo(1) < 1.0
            fprintf('INFO: Adjusting entered AoO minimum down-range from %.1f m to 1.0 m.\n', current_Ylim_aoo(1));
            current_Ylim_aoo(1) = 1.0;
        end
    catch ME
        error('Error parsing Area of Observation Y-range: %s\n%s', ME.message, 'Please ensure input is a valid MATLAB matrix (e.g., [1, 50]).');
    end
    fprintf('Using Area of Observation (AoO) Y-range for bounding box and analysis: [%.1f, %.1f] m\n', current_Ylim_aoo(1), current_Ylim_aoo(2));
    % --------------------------------------------------------------------------------------
    %% --- Generate Animated Top-View Scatter Plot of Detections (Near Scan) ---
    video_enable_scatter = 1; % Set to 1 to enable video saving for this plot
    if exist('plot3_detections', 'file') == 2
        [fig_near_scatter, ax_near_scatter, vid_near_handle] = plot3_detections(...
            figtitle,...             
            figtitle_plot,...        
            filtered_near_x, filtered_near_y,...  
            filtered_near_rcs_linear,...       
            filtered_near_utc_time,...         
            current_Ylim_aoo,...     
            selected_tr_dist,...     
            video_enable_scatter);   
    else
        fprintf('Skipping plot3_detections: Function not found.\n');
        vid_near_handle = []; 
    end
end
%% Bounding box and filtering
figtitle_parts_bb = figtitle_parts;
bb = []; 
near_x_for_bb_filter = near_x; 
near_y_for_bb_filter = near_y;
near_rcs_for_bb_filter = near_rcs_linear; 
fprintf('DEBUG: Before calling set_boundingbox.\n'); 
if exist('set_boundingbox', 'file') == 2
    bb_defined_flag = true;
    try
        % Pass current_Ylim_aoo and selected_tr_dist to set_boundingbox
        bb = set_boundingbox(figtitle_parts_bb, size(near_x, 1), current_Ylim_aoo, selected_tr_dist); 
    catch ME
        warning(ME.identifier, 'Error calling set_boundingbox: %s. Bounding box filtering will be skipped.', ME.message);
        bb_defined_flag = false;
        bb = []; 
    end
else
    fprintf('Skipping set_boundingbox: Function not found. Bounding box filtering will not be applied.\n');
    bb_defined_flag = false;
end
fprintf('DEBUG: After calling set_boundingbox. bb is empty: %d\n', isempty(bb)); 
if bb_defined_flag && exist('filter_boundingbox', 'file') == 2 && ~isempty(near_x)
    [near_x_bb_full, near_y_bb_full, near_rcs_bb_full] = filter_boundingbox(...
        near_x_for_bb_filter, near_y_for_bb_filter, near_rcs_for_bb_filter, ...
        bb, ...
        []); 
    
    near_x_bb_plot_candidate = near_x_bb_full(valid_snapshot_mask_overall, :);
    near_y_bb_plot_candidate = near_y_bb_full(valid_snapshot_mask_overall, :);
    near_rcs_bb_plot_candidate = near_rcs_bb_full(valid_snapshot_mask_overall, :); 
    filtered_bb_for_plot_candidate = bb(valid_snapshot_mask_overall, :); 
    filtered_near_utc_time_plot_candidate = filtered_near_utc_time; 
    % Exclude zeros in RCS - applied to near_rcs_bb_plot_candidate only
    near_rcs_bb_plot_candidate(near_rcs_bb_plot_candidate==0) = NaN; 
    final_plot_mask = true(size(near_x_bb_plot_candidate, 1), 1);
    for idx_snap = 1:size(near_x_bb_plot_candidate, 1)
        if all(isnan(near_x_bb_plot_candidate(idx_snap,:))) || all(isinf(near_x_bb_plot_candidate(idx_snap,:)))
            final_plot_mask(idx_snap) = false;
        end
    end
    near_x_bb = near_x_bb_plot_candidate(final_plot_mask, :);
    near_y_bb = near_y_bb_plot_candidate(final_plot_mask, :);
    
    near_rcs_bb_linear = near_rcs_bb_plot_candidate(final_plot_mask, :); 
    filtered_bb_for_plot = filtered_bb_for_plot_candidate(final_plot_mask, :);
    
    filtered_near_utc_time_final = filtered_near_utc_time_plot_candidate(final_plot_mask);
    filtered_near_utc_time_final = filtered_near_utc_time_final(:); 
    
    filtered_near_utc_ms_for_3D_masked_final = measdata.ars430_HH.NearScan.UTCtime_ms(valid_snapshot_mask_overall); 
    filtered_near_utc_ms_for_3D_masked_final = filtered_near_utc_ms_for_3D_masked_final(:); 
    fprintf('DEBUG: Size of near_x_bb : %dx%d\n', size(near_x_bb, 1), size(near_x_bb, 2));
    fprintf('DEBUG: Size of near_y_bb : %dx%d\n', size(near_y_bb, 1), size(near_y_bb, 2));
    fprintf('DEBUG: Size of near_rcs_bb_linear : %dx%d\n', size(near_rcs_bb_linear, 1), size(near_rcs_bb_linear, 2)); 
    fprintf('DEBUG: Size of filtered_near_utc_time_final: %dx%d\n', size(filtered_near_utc_time_final, 1), size(filtered_near_utc_time_final, 2));
    fprintf('DEBUG: Size of filtered_bb_for_plot : %dx%d\n', size(filtered_bb_for_plot, 1), size(filtered_bb_for_plot, 2));
    %% Plot animated topview with detections in time-variant boundingbox (Near Scan)
    video_enable_bb = 1; 
    fprintf('DEBUG: Before calling plot3_detections_boundingbox. bb is empty: %d, plot3_detections_boundingbox exists: %d\n', isempty(filtered_bb_for_plot), exist('plot3_detections_boundingbox', 'file') == 2); 
    if exist('plot3_detections_boundingbox', 'file') == 2 && ~isempty(filtered_bb_for_plot) && ~isempty(near_x_bb) 
        fprintf('DEBUG: Calling plot3_detelections_boundingbox with current_Ylim_aoo for BB definition.\n'); 
        [fig_near_bb, ax_near_bb, vid_near_bb_handle] = plot3_detections_boundingbox(...
            figtitle,...                 
            figtitle_plot,...            
            near_x_bb, ...               
            near_y_bb, ...               
            near_rcs_bb_linear, ...      
            [], ...                      
            filtered_near_utc_time_final, ... 
            filtered_bb_for_plot, ...    
            current_Ylim_aoo, ...        
            selected_tr_dist, ...        
            video_enable_bb);            
        if video_enable_bb == 1 && isa(vid_near_bb_handle, 'VideoWriter')
            close(vid_near_bb_handle);
            fprintf('Near Scan bounding box video saved.\n');
        end
    else
        fprintf('Skipping plot3_detections_boundingbox: Function not found, filtered bounding box data is empty, or filtered near_x_bb is empty.\n');
    end
else
    fprintf('Skipping filter_boundingbox or plot3_detections_boundingbox: Function not found, bounding box not defined, or no valid data to process.\n');
    near_x_bb = []; near_y_bb = []; near_rcs_bb_linear = []; 
end
%% Plot PDF of detections in boundingbox (Near Scan)
start_bin = 1; 
stop_bin = size(near_rcs_bb_linear,1); 
% Prepare data for PDF. Flatten and clean.

data_for_pdf_raw = near_rcs_bb_linear(start_bin:stop_bin,:);
data_for_pdf_flat = data_for_pdf_raw(:); 
data_for_pdf_clean = data_for_pdf_flat(~isnan(data_for_pdf_flat) & ~isinf(data_for_pdf_flat));
% --- Apply IQR Filtering to the data used for PDF ---
% Only apply if there's enough data for quantiles (at least 2 points)
if numel(data_for_pdf_clean) >= 2
    q1_pdf = quantile(data_for_pdf_clean, 0.25);
    q3_pdf = quantile(data_for_pdf_clean, 0.75);
    iqr_value_pdf = q3_pdf - q1_pdf; 
    lower_bound_pdf = q1_pdf - 1.5 * iqr_value_pdf;
    upper_bound_pdf = q3_pdf + 1.5 * iqr_value_pdf;
    
    data_for_pdf_filtered_iqr = data_for_pdf_clean(...
        data_for_pdf_clean >= lower_bound_pdf & ...
        data_for_pdf_clean <= upper_bound_pdf);
    fprintf('INFO: Applied IQR filtering to PDF data. Original points: %d, Filtered points: %d\n', numel(data_for_pdf_clean), numel(data_for_pdf_filtered_iqr));
else
    data_for_pdf_filtered_iqr = data_for_pdf_clean;
    fprintf('INFO: Not enough data points (%d) for effective IQR filtering for PDF. Skipping IQR.\n', numel(data_for_pdf_clean));
end
% Pass this filtered data to plot_pdf and plot_3Dpdf.

save_as_svg = 0;
% Define universal eta range and number of bins for PDF plotting
universal_eta_range = [0, 7e-3]; % From 0 to 7e-3 m^-1
num_bins = 500;

%bin_width = 0.0001;
% Initialize RMSE variables to NaN
gamma_rmse = NaN;
single_loggamma_rmse_optimized = NaN;
single_loggamma_rmse_unoptimized = NaN;
Perc_Improvement_Gamma_to_OptLG = NaN;
Perc_Improvement_UnOptLG_to_OptLG = NaN;

if exist('plot_pdf', 'file') == 2 && ~isempty(data_for_pdf_filtered_iqr) 
    start_bin = max(1, start_bin);
    stop_bin = min(size(near_rcs_bb_linear, 1), stop_bin);
    
    if (stop_bin - start_bin + 1) > 0
 
        % Create the binning_option struct as expected by plot_pdf
        binning_option_for_pdf = struct('type', 'num_bins', 'value', num_bins, 'plot_kde', true);

        % Capture the bin centers, total_num_data_points, and bin_width from plot_pdf
        [fig_near_pdf, ax_near_pdf, data_for_pdf_filtered_iqr_output, ~, eta_bin_centers_for_fitting, total_num_data_points, bin_width] = plot_pdf(... 
            figtitle, figtitle_plot, figtitle_parts, ... 
            data_for_pdf_filtered_iqr, ... % Pass IQR-filtered LINEAR RCS data
            save_as_svg, ...
            universal_eta_range, ...
            binning_option_for_pdf); % Pass the binning_option struct

        %% --- Call fit_distributions_to_pdf to overlay Gamma and Single Log-Gamma fits ---
        if exist('fit_distributions_to_pdf', 'file') == 2 && ~isempty(data_for_pdf_filtered_iqr)
            fprintf('Calling fit_distributions_to_pdf to overlay fitted Gamma and Single Log-Gamma.\n');
            % Pass total_num_data_points_from_plot_pdf and bin_width_from_plot_pdf
            [gamma_rmse, single_loggamma_rmse_optimized, single_loggamma_rmse_unoptimized, a_fit_single_lg, b_fit_single_lg, loc_fit_single_lg] = ...
                fit_distributions_to_pdf(ax_near_pdf, data_for_pdf_filtered_iqr, ...
                                     eta_bin_centers_for_fitting, total_num_data_points, bin_width);
            fprintf('Gamma and Single Log-Gamma fitting complete.\n');
        else
            fprintf('Skipping Gamma and Single Log-Gamma fitting: Function not found or no valid data for fitting.\n');
        end

        
        %% --- Calculate and display statistics from the PDF data ---
        fprintf('\n--- Calculating Statistics for PDF of Detections (Linear Eta in m^-1) ---\n');
        
        % Statistics are calculated on the IQR-filtered data
        if ~isempty(data_for_pdf_filtered_iqr)
            num_points = numel(data_for_pdf_filtered_iqr);
            mean_val = mean(data_for_pdf_filtered_iqr);
            median_val = median(data_for_pdf_filtered_iqr);
            std_dev = std(data_for_pdf_filtered_iqr);
            skew_val = skewness(data_for_pdf_filtered_iqr);
            kurt_val = kurtosis(data_for_pdf_filtered_iqr);
            
            fprintf('  TR Distance: %d m\n', selected_tr_dist);
            fprintf('  Rain Rate: %d mm/hr\n', selected_rain_rate);
            fprintf('  Repetition Number: %d\n', selected_rep_num);
            fprintf('  Y-Range AoO: [%.1f, %.1f] m\n', current_Ylim_aoo(1), current_Ylim_aoo(2));
            fprintf('  Data Range (Snapshots): %d to %d\n', start_bin, stop_bin);
            fprintf('  Number of valid points (N): %d\n', num_points);
            fprintf('  Mean (linear eta): %.4e m^-1\n', mean_val); 
            fprintf('  Median (linear eta): %.4e m^-1\n', median_val);
            fprintf('  Standard Deviation (linear eta): %.4e m^-1\n', std_dev);
            fprintf('  Skewness: %.4f\n', skew_val);
            fprintf('  Kurtosis: %.4f\n', kurt_val);
        else
            fprintf('  No valid data available after filtering for statistics from PDF plot.\n');
        end
        fprintf('-----------------------------------------------------\n');
    else
        fprintf('Skipping plot_pdf: Invalid start/stop bins for filtered data.\n');
    end
else
    fprintf('Skipping plot_pdf: Function not found or no valid filtered data for 2D PDF.\n');
end

%% Calculate percentage improvements
Perc_Improvement_Gamma_to_OptLG = NaN;
if ~isnan(gamma_rmse) && gamma_rmse ~= 0
    Perc_Improvement_Gamma_to_OptLG = ((gamma_rmse - single_loggamma_rmse_optimized) / gamma_rmse) * 100;
end

Perc_Improvement_UnOptLG_to_OptLG = NaN;
if ~isnan(single_loggamma_rmse_unoptimized) && single_loggamma_rmse_unoptimized ~= 0
    Perc_Improvement_UnOptLG_to_OptLG = ((single_loggamma_rmse_unoptimized - single_loggamma_rmse_optimized) / single_loggamma_rmse_unoptimized) * 100;
end

%% --- CSV Parameter Storage Logic ---
% Only proceed if fitting was successful and all necessary RMSE values are valid
if ~isnan(gamma_rmse) && ~isnan(single_loggamma_rmse_optimized) && ~isnan(single_loggamma_rmse_unoptimized) 

    output_folder_params = 'output_analysis';
    if ~exist(output_folder_params, 'dir')
        mkdir(output_folder_params);
    end

    % --- 1. Save RMSE Summary (Gamma and Single Log-Gamma) ---
    csv_filename_rmse_summary = fullfile(output_folder_params, 'RMSE_Summary.csv');

    % Updated headers for Gamma and Single Log-Gamma RMSEs and the new percentage improvement
    headers_rmse_summary = {'TR_Position_m', 'Rain_Rate_mm_hr', 'Repetition_Num', ...
                       'AoO_Ylim_min', 'AoO_Ylim_max', ...
                       'Gamma_RMSE','LogGamma_RMSE_Unoptimized' 'LogGamma_RMSE_Optimized' ... 
                       'Perc_Improvement_Gamma_to_OptLG','Perc_Improvement_UnOptLG_to_OptLG'}; 

    existing_data_table_rmse_summary = table();
    csv_file_info_rmse_summary = dir(csv_filename_rmse_summary);
    if isfile(csv_filename_rmse_summary) && ~isempty(csv_file_info_rmse_summary) && csv_file_info_rmse_summary.bytes > 0
        try
            opts_rmse = detectImportOptions(csv_filename_rmse_summary);
            % Ensure all numeric columns are read as doubles
            for i = 1:length(opts_rmse.VariableNames)
                if ismember(opts_rmse.VariableNames{i}, {'TR_Position_m', 'Rain_Rate_mm_hr', 'Repetition_Num', ...
                                                    'AoO_Ylim_min', 'AoO_Ylim_max', ...
                                                    'Gamma_RMSE','LogGamma_RMSE_Unoptimized', 'LogGamma_RMSE_Optimized' ...
                                                    'Perc_Improvement_Gamma_to_OptLG','Perc_Improvement_UnOptLG_to_OptLG'})
                    opts_rmse = setvaropts(opts_rmse, opts_rmse.VariableNames{i}, 'FillValue', NaN, 'TreatAsMissing', {'NA', ''}, 'Type', 'double');
                end
            end
            existing_data_table_rmse_summary = readtable(csv_filename_rmse_summary, opts_rmse);
            fprintf('Loaded %d existing entries from CSV: %s\n', size(existing_data_table_rmse_summary, 1), csv_filename_rmse_summary);

            % Add missing columns if headers have changed
            current_variable_names_rmse_summary = existing_data_table_rmse_summary.Properties.VariableNames;
            for h_idx = 1:numel(headers_rmse_summary)
                current_header = headers_rmse_summary{h_idx};
                if ~ismember(current_header, current_variable_names_rmse_summary)
                    existing_data_table_rmse_summary.(current_header) = NaN(size(existing_data_table_rmse_summary, 1), 1);
                    fprintf('  Added missing column "%s" to loaded RMSE summary table.\n', current_header);
                end
            end
            % Reorder columns to match new headers
            existing_data_table_rmse_summary = existing_data_table_rmse_summary(:, headers_rmse_summary);
        catch ME
            warning('Failed to read existing RMSE summary CSV file: %s. Creating a new empty table with headers. Error: %s', csv_filename_rmse_summary, ME.message);
            existing_data_table_rmse_summary = cell2table(cell(0, numel(headers_rmse_summary)), 'VariableNames', headers_rmse_summary);
        end
    else
        fprintf('Creating new RMSE summary CSV file: %s\n', csv_filename_rmse_summary);
        existing_data_table_rmse_summary = cell2table(cell(0, numel(headers_rmse_summary)), 'VariableNames', headers_rmse_summary);
    end

    current_row_data_rmse_summary = {selected_tr_dist, selected_rain_rate, selected_rep_num, ...
                                current_Ylim_aoo(1), current_Ylim_aoo(2), ...
                                gamma_rmse,single_loggamma_rmse_unoptimized,single_loggamma_rmse_optimized ...
                                Perc_Improvement_Gamma_to_OptLG,Perc_Improvement_UnOptLG_to_OptLG}; 
    current_table_row_rmse_summary = cell2table(current_row_data_rmse_summary, 'VariableNames', headers_rmse_summary);

    % Find existing scenario using the new identifying fields
    scenario_exists_idx_rmse_summary = find( ...
        existing_data_table_rmse_summary.TR_Position_m == selected_tr_dist & ...
        existing_data_table_rmse_summary.Rain_Rate_mm_hr == selected_rain_rate & ...
        existing_data_table_rmse_summary.Repetition_Num == selected_rep_num & ...
        existing_data_table_rmse_summary.AoO_Ylim_min == current_Ylim_aoo(1) & ...
        existing_data_table_rmse_summary.AoO_Ylim_max == current_Ylim_aoo(2), 1);

    if ~isempty(scenario_exists_idx_rmse_summary)
        fprintf('  Updating existing entry for this scenario in %s.\n', csv_filename_rmse_summary);
        existing_data_table_rmse_summary(scenario_exists_idx_rmse_summary, :) = current_table_row_rmse_summary;
    else
        fprintf('  Adding new entry for this scenario to %s.\n', csv_filename_rmse_summary);
        existing_data_table_rmse_summary = [existing_data_table_rmse_summary; current_table_row_rmse_summary]; 
    end

    writetable(existing_data_table_rmse_summary, csv_filename_rmse_summary, 'Delimiter', ',');
    fprintf('RMSE summary collected and saved/updated in %s\n', csv_filename_rmse_summary);

else
    fprintf('Skipping RMSE summary storage: Gamma or Single Log-Gamma RMSE values are invalid.\n');
end

% --- 2. Save Optimized Single Log-Gamma Parameters (detailed) ---
% Only proceed if fitting was successful and all necessary parameters are valid
if ~isnan(a_fit_single_lg) && ~isnan(b_fit_single_lg) && ~isnan(loc_fit_single_lg) && ~isnan(single_loggamma_rmse_optimized)
    csv_filename_optimized_params = fullfile(output_folder_params, 'Optimized_SingleLogGamma_Results.csv');
    headers_optimized_params = {'TR_Position_m', 'Rain_Rate_mm_hr', 'Repetition_Num', ...
                                'AoO_Ylim_min', 'AoO_Ylim_max', ...
                                'Optimized_Shape_a', 'Optimized_Scale_b', 'Optimized_Location_loc', ...
                                'Optimized_RMSE'};
    
    existing_data_table_optimized_params = table();
    csv_file_info_optimized_params = dir(csv_filename_optimized_params);
    if isfile(csv_filename_optimized_params) && ~isempty(csv_file_info_optimized_params) && csv_file_info_optimized_params.bytes > 0
        try
            opts_params = detectImportOptions(csv_filename_optimized_params);
            % Ensure all numeric columns are read as doubles
            for i = 1:length(opts_params.VariableNames)
                if ismember(opts_params.VariableNames{i}, {'TR_Position_m', 'Rain_Rate_mm_hr', 'Repetition_Num', ...
                                                        'AoO_Ylim_min', 'AoO_Ylim_max', ...
                                                        'Optimized_Shape_a', 'Optimized_Scale_b', 'Optimized_Location_loc', ...
                                                        'Optimized_RMSE'})
                    opts_params = setvaropts(opts_params, opts_params.VariableNames{i}, 'FillValue', NaN, 'TreatAsMissing', {'NA', ''}, 'Type', 'double');
                end
            end
            existing_data_table_optimized_params = readtable(csv_filename_optimized_params, opts_params);
            fprintf('Loaded %d existing entries from CSV: %s\n', size(existing_data_table_optimized_params, 1), csv_filename_optimized_params);

            % Add missing columns if headers have changed
            current_variable_names_params = existing_data_table_optimized_params.Properties.VariableNames;
            for h_idx = 1:numel(headers_optimized_params)
                current_header = headers_optimized_params{h_idx};
                if ~ismember(current_header, current_variable_names_params)
                    existing_data_table_optimized_params.(current_header) = NaN(size(existing_data_table_optimized_params, 1), 1);
                    fprintf('  Added missing column "%s" to loaded optimized parameters table.\n', current_header);
                end
            end
            % Reorder columns to match new headers
            existing_data_table_optimized_params = existing_data_table_optimized_params(:, headers_optimized_params);
        catch ME
            warning('Failed to read existing optimized parameters CSV file: %s. Creating a new empty table with headers. Error: %s', csv_filename_optimized_params, ME.message);
            existing_data_table_optimized_params = cell2table(cell(0, numel(headers_optimized_params)), 'VariableNames', headers_optimized_params);
        end
    else
        fprintf('Creating new optimized parameters CSV file: %s\n', csv_filename_optimized_params);
        existing_data_table_optimized_params = cell2table(cell(0, numel(headers_optimized_params)), 'VariableNames', headers_optimized_params);
    end

    current_row_data_optimized_params = {selected_tr_dist, selected_rain_rate, selected_rep_num, ...
                                         current_Ylim_aoo(1), current_Ylim_aoo(2), ...
                                         a_fit_single_lg, b_fit_single_lg, loc_fit_single_lg, ...
                                         single_loggamma_rmse_optimized};
    current_table_row_optimized_params = cell2table(current_row_data_optimized_params, 'VariableNames', headers_optimized_params);

    % Find existing scenario using the new identifying fields
    scenario_exists_idx_optimized_params = find( ...
        existing_data_table_optimized_params.TR_Position_m == selected_tr_dist & ...
        existing_data_table_optimized_params.Rain_Rate_mm_hr == selected_rain_rate & ...
        existing_data_table_optimized_params.Repetition_Num == selected_rep_num & ...
        existing_data_table_optimized_params.AoO_Ylim_min == current_Ylim_aoo(1) & ...
        existing_data_table_optimized_params.AoO_Ylim_max == current_Ylim_aoo(2), 1);

    if ~isempty(scenario_exists_idx_optimized_params)
        fprintf('  Updating existing entry for this scenario in %s.\n', csv_filename_optimized_params);
        existing_data_table_optimized_params(scenario_exists_idx_optimized_params, :) = current_table_row_optimized_params;
    else
        fprintf('  Adding new entry for this scenario to %s.\n', csv_filename_optimized_params);
        existing_data_table_optimized_params = [existing_data_table_optimized_params; current_table_row_optimized_params]; 
    end

    % --- Format numeric columns to strings before writing ---
    % Convert numeric columns to string format with desired precision
    existing_data_table_optimized_params.AoO_Ylim_min = arrayfun(@(x) sprintf('%.1f', x), existing_data_table_optimized_params.AoO_Ylim_min, 'UniformOutput', false);
    existing_data_table_optimized_params.AoO_Ylim_max = arrayfun(@(x) sprintf('%.1f', x), existing_data_table_optimized_params.AoO_Ylim_max, 'UniformOutput', false);
    existing_data_table_optimized_params.Optimized_Shape_a = arrayfun(@(x) sprintf('%.4e', x), existing_data_table_optimized_params.Optimized_Shape_a, 'UniformOutput', false);
    existing_data_table_optimized_params.Optimized_Scale_b = arrayfun(@(x) sprintf('%.4e', x), existing_data_table_optimized_params.Optimized_Scale_b, 'UniformOutput', false);
    existing_data_table_optimized_params.Optimized_Location_loc = arrayfun(@(x) sprintf('%.4e', x), existing_data_table_optimized_params.Optimized_Location_loc, 'UniformOutput', false);
    existing_data_table_optimized_params.Optimized_RMSE = arrayfun(@(x) sprintf('%.4e', x), existing_data_table_optimized_params.Optimized_RMSE, 'UniformOutput', false);

    writetable(existing_data_table_optimized_params, csv_filename_optimized_params, 'Delimiter', ',');
    fprintf('Optimized parameters collected and saved/updated in %s\n', csv_filename_optimized_params);
else
    fprintf('Skipping optimized parameters storage: Single Log-Gamma fit was not successful or parameters are invalid.\n');
end



%% 3D-Plot time-variant PDF of detections in boundingbox (Near Scan)
%{
start_bin_3D = 1; 
stop_bin_3D = size(near_rcs_bb_linear,1); 
width = 10; 
% For 3D PDF, we also pass the IQR-filtered data
data_for_3dpdf_filtered_iqr = data_for_pdf_filtered_iqr_final; % Reuse the same filtered data
% Note: The time axis in plot_3Dpdf still needs to correspond to the original snapshots.
% Need to ensure data_for_3dpdf_filtered_iqr correctly maps to utc_ms_timestamps.
% Currently, `data_for_3dpdf_filtered_iqr` is a flattened, filtered version.
% For 3D PDF, `rcs_data_bb` should be the full `near_rcs_bb_linear` and IQR filtering should be done *per window* in `plot_3Dpdf`
% to correctly correspond to the time slices.
% REVERTING this to pass `near_rcs_bb_linear` directly and let `plot_3Dpdf` handle its own IQR and binning.
save_as_svg = 0;
if exist('plot_3Dpdf', 'file') == 2 && ~isempty(near_rcs_bb_linear) 
    start_bin_3D = max(1, start_bin_3D);
    stop_bin_3D = min(size(near_rcs_bb_linear, 1), stop_bin_3D);
    if (stop_bin_3D - start_bin_3D + 1) >= width 
        filtered_near_utc_ms_for_3D_col = measdata.ars430_HH.NearScan.UTCtime_ms(valid_snapshot_mask_overall); % Start from raw ms
        filtered_near_utc_ms_for_3D_col = filtered_near_utc_ms_for_3D_col(:); % Ensure column vector
        [fig_near_3dpdf, ax_near_3dpdf] = plot_3Dpdf(... 
            figtitle, ... 
            figtitle_plot, ... 
            figtitle_parts, ... 
            near_rcs_bb_linear, ... % Pass original LINEAR RCS data; plot_3Dpdf will handle filtering
            filtered_near_utc_ms_for_3D_col,... 
            [], width, ... % Pass empty for binedges; plot_3Dpdf will calculate internally
            save_as_svg);
    else
        fprintf('Skipping plot_3Dpdf: Not enough valid filtered data or time snapshots (%d) for 3D PDF with width (%d). Skipping 3D PDF plot.\n', size(near_rcs_bb_linear,1), width);
    end
else
    fprintf('Skipping plot_3Dpdf: Function not found or no valid filtered data for 3D PDF.\n');
end

%% Plotting Range-Crossrange Map (Aggregated from ALL filtered data)
% Prepare file_info struct for plot_range_crossrange_map
file_info_struct = struct();
file_info_struct.tr_dist = tr_dist_val;
file_info_struct.rain_rate = rain_rate_val;
file_info_struct.rep_num = rep_num_val;

% Define AoO Cross-range limits for plotting the red box
aoo_cross_range_min = -2.5; % From set_boundingbox
aoo_cross_range_max = 2.5;  % From set_boundingbox

if exist('plot_range_crossrange_map', 'file') == 2
    fprintf('DEBUG: Calling plot_range_crossrange_map with full data.\n');
    
    % Pass the *broadly filtered* data (not the _bb filtered data)
    map_x_coor = filtered_near_x(:); 
    map_y_coor = filtered_near_y(:); 
    map_eta_linear = filtered_near_rcs_linear(:); 
    
    % Filter out NaNs from the flattened data before passing to the plot function
    valid_map_indices = ~isnan(map_x_coor) & ~isnan(map_y_coor) & ~isnan(map_eta_linear);
    
    map_x_coor = map_x_coor(valid_map_indices);
    map_y_coor = map_y_coor(valid_map_indices);
    map_eta_linear = map_eta_linear(valid_map_indices); % Use linear eta directly
    
    if ~isempty(map_x_coor) && ~isempty(map_y_coor) && ~isempty(map_eta_linear)
        plot_range_crossrange_map(...
            map_x_coor, ...         % Crossrange (x_coor)
            map_y_coor, ...         % Range (y_coor)
            map_eta_linear, ...     % RCS in linear scale
            current_Ylim_aoo, ...   % Pass current_Ylim_aoo for red box Y-limits
            selected_tr_dist, ...   
            file_info_struct, ...   
            [aoo_cross_range_min, aoo_cross_range_max], ... % Explicitly pass AoO X-limits for red box
            hPBWphi); % Pass the horizontal beamwidth for cone filtering
    else
        fprintf('No valid data available for Range-Crossrange Map. Skipping plot.\n');
    end
else
    fprintf('Skipping plot_range_crossrange_map: Function not found.\n');
end

fprintf('\nNear Scan analysis and plotting complete.\n');

%}


