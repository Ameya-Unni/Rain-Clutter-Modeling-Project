function [fig_handle, ax_handle, y_hist_counts, eta_bin_edges, eta_bin_centers, total_num_data_points, actual_bin_width_used] = plot_pdf(...
    figtitle_base, plot_title_part, figtitle_parts, ...
    data_for_pdf, ... % This is the filtered eta data (linear)
    save_as_svg, ...
    universal_eta_range, ... % [min_eta, max_eta] for axis limits
    binning_option)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOT_PDF
%   Generates a 2D histogram using a fixed number of bins or a fixed
%   bin width. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Initialize outputs to NaN in case of early exit
    y_hist_counts = NaN;
    eta_bin_edges = NaN;
    eta_bin_centers = NaN;
    actual_bin_width_used = NaN;
    
    % --- Configuration for Presentation-Ready Plots ---
    % Increased font sizes for better visibility
    FONT_SIZE_TITLE = 20;
    FONT_SIZE_LABELS = 18;
    FONT_SIZE_TICKS = 16;
    
    % Filter out NaN values from the input data
    data_to_bin = data_for_pdf(~isnan(data_for_pdf));
    total_num_data_points = length(data_to_bin);
    
    % Handle case where there is no valid data
    if isempty(data_to_bin)
        warning('No valid data available for PDF plot. Skipping plot.');
        fig_handle = figure('Name', figtitle_base, 'NumberTitle', 'off');
        ax_handle = gca;
        text(0.5, 0.5, 'No valid data for plot', 'HorizontalAlignment', 'center', 'Units', 'normalized', 'FontSize', FONT_SIZE_LABELS);
        return;
    end
    
    % Create a new figure and get the axes handle
    fig_handle = figure('Name', figtitle_base, 'NumberTitle', 'off');
    ax_handle = gca;
    
    % Use the histogram function with different binning options
    h = []; 
    switch binning_option.type
        case 'num_bins'
            % Option 1: Fixed Number of Bins
            num_bins_requested = binning_option.value;
            final_num_bins = max(1, min([num_bins_requested, floor(total_num_data_points / 2)]));
            
            h = histogram(ax_handle, data_to_bin, final_num_bins, 'Normalization', 'count');
            actual_bin_width_used = h.BinWidth;
            fprintf('DEBUG: Using fixed number of bins: %d\n', final_num_bins);
            
        case 'fixed_width'
            % Option 2: Fixed Bin Width
            bin_width = binning_option.value;
            if bin_width <= 0
                error('bin_width must be a positive number for fixed_width binning.');
            end
            
            data_range = max(data_to_bin) - min(data_to_bin);
            estimated_num_bins = data_range / bin_width;
            if estimated_num_bins < 10 && estimated_num_bins > 0
                warning('The chosen fixed bin width is too large, resulting in too few bins. Falling back to 50 bins.');
                h = histogram(ax_handle, data_to_bin, 500, 'Normalization', 'count');
                actual_bin_width_used = h.BinWidth;
                fprintf('DEBUG: Bin width too large. Falling back to 50 bins. Actual bin width used: %f\n', actual_bin_width_used);
            else
                h = histogram(ax_handle, data_to_bin, 'BinWidth', bin_width, 'Normalization', 'count');
                actual_bin_width_used = h.BinWidth;
                fprintf('DEBUG: Using fixed bin width: %f. Number of bins: %d\n', bin_width, h.NumBins);
            end
        
        otherwise
            error('Invalid binning option for PDF. Supported types are "num_bins" and "fixed_width".');
    end
    
    % Extract bin data from the created histogram
    y_hist_counts = h.BinCounts;
    eta_bin_edges = h.BinEdges;
    eta_bin_centers = (eta_bin_edges(1:end-1) + eta_bin_edges(2:end)) / 2;
    
    % Set plot properties and display name for the original histogram data
    h.FaceColor = [0.1 0.5 0.9]; % Changed from [0.8 0.8 0.8] to blue
    h.EdgeColor = 'k';
    h.DisplayName = 'Histogram Data'; 
    
    %{
    % --- Optional: Plot Kernel Density Estimation (KDE) ---
    if isfield(binning_option, 'plot_kde') && binning_option.plot_kde
        hold(ax_handle, 'on');
        try
            % Use ksdensity to estimate the PDF, normalizing to a count
            [f_kde, xi_kde] = ksdensity(data_to_bin, 'Bandwidth', 'normal-approx', 'BoundaryCorrection', 'reflection');
            
            % Scale the KDE to match the count normalization of the histogram
            area_histogram = sum(h.Values) * h.BinWidth;
            f_kde_scaled = f_kde * area_histogram;
            
            % Ensure xi_kde values are within the plot's x-limits and positive
            x_limits = ax_handle.XLim;
            valid_kde_idx = xi_kde >= max(x_limits(1), 1e-12) & xi_kde <= x_limits(2);
            
            if sum(valid_kde_idx) > 1
                plot(ax_handle, xi_kde(valid_kde_idx), f_kde_scaled(valid_kde_idx), ...
                    'Color', [0.4940 0.1840 0.5560], 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'KDE');
                fprintf('DEBUG: KDE plot successful.\n');
            else
                fprintf('WARNING: KDE output is empty after filtering or too sparse. Skipping KDE plot.\n');
            end
        catch ME
            fprintf('WARNING: Failed to plot Kernel Density Estimation (KDE): %s\n', ME.message);
        end
        hold(ax_handle, 'off');
    end
    %}
    
    % Set axis limits and labels with explicit interpreters
    ax_handle.XLim = [universal_eta_range(1), universal_eta_range(2)];
    ax_handle.XLabel.String = "RCS $\sigma$ (dBsm)";
    ax_handle.XLabel.Interpreter = 'latex';
    ax_handle.XLabel.FontSize = FONT_SIZE_LABELS;
    
    ax_handle.YLabel.String = "Count";
    ax_handle.YLabel.Interpreter = 'none';
    ax_handle.YLabel.FontSize = FONT_SIZE_LABELS;
    
    % Add the title and side labels with explicit interpreters
    ax_handle.Title.String = plot_title_part;
    ax_handle.Title.Interpreter = 'none';
    ax_handle.Title.FontSize = FONT_SIZE_TITLE;
    
    ax_handle.FontName = "Arial";
    ax_handle.FontSize = FONT_SIZE_TICKS;
    
    % The figtitle_parts input is a cell array; concatenate it into a single string
    side_label_string = strjoin(figtitle_parts, ' ');
    text(1.1, 0.5, side_label_string, 'Units', 'normalized', 'HorizontalAlignment', 'center', 'Rotation', 90, 'Interpreter', 'none', 'FontSize', FONT_SIZE_LABELS);
    
    % Save the figure if requested
    if save_as_svg
        % The save logic from your original code snippet
        % save_filename_near = ...
        % ... etc.
    end
    
    hold(ax_handle, 'off');
end
