function [gamma_rmse, single_loggamma_rmse_optimized, single_loggamma_rmse_unoptimized, a_fit_single_lg, b_fit_single_lg, loc_fit_single_lg] = fit_distributions_to_pdf(ax_handle, data_to_fit, eta_bin_centers_input, total_num_data_points, bin_width)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fits Gamma and single Log-Gamma distributions to the observed
% reflectivity (eta) histogram counts (occurrences) and overlays the
% fitted curves on the provided axes. It also calculates and returns the
% RMSE for each fit. This version incorporates multi-start optimization
% for the Single Log-Gamma distribution to improve the robustness of the fit.
% Fitted curves are scaled to match the 'count' normalization of the histogram.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('DEBUG: Entering fit_distributions_to_pdf function (Gamma and Single Log-Gamma for Occurrences).\n');
    hold(ax_handle, 'on'); 
    % Initialize
    gamma_rmse = NaN;
    single_loggamma_rmse_optimized = NaN;
    single_loggamma_rmse_unoptimized = NaN;
    a_fit_single_lg = NaN;
    b_fit_single_lg = NaN;
    loc_fit_single_lg = NaN;
    FONT_SIZE_LEGEND = 16;

    if isempty(data_to_fit) || numel(data_to_fit) < 2
        fprintf('WARNING: Not enough data points (need at least 2) for distribution fitting. Skipping fitting process.\n');
        hold(ax_handle, 'off'); 
        return;
    end

    % check data_to_fit is a column vector and contains only finite
    data_to_fit = data_to_fit(:);
    data_to_fit = data_to_fit(~isnan(data_to_fit) & ~isinf(data_to_fit) & isreal(data_to_fit));
    
    if isempty(data_to_fit) || numel(data_to_fit) < 2
        fprintf('WARNING: Data became empty or insufficient after cleaning for distribution fitting. Skipping fitting process.\n');
        hold(ax_handle, 'off');
        return;
    end

    % Get the histogram counts (occurrences)
    h_hist = findobj(ax_handle, 'Type', 'histogram');
    if isempty(h_hist)
        warning('Could not find histogram object on the axes. Cannot calculate RMSE for fits.');
        y_hist_counts = []; 
        hist_bin_centers = [];
    else
        % Use the bin edges from the existing histogram to get corresponding counts
        hist_bin_edges = h_hist.BinEdges;
        
        [counts_occ, ~] = histcounts(data_to_fit, hist_bin_edges); 
        y_hist_counts = counts_occ; 
      
        hist_bin_centers = (hist_bin_edges(1:end-1) + hist_bin_edges(2:end)) / 2;
    end

    % Generate a denser set of x-values for smoother fitted curves
    x_limits = xlim(ax_handle);
    x_fit_values_positive = linspace(max(x_limits(1), 1e-12), x_limits(2), 500); 
    x_fit_values_positive = x_fit_values_positive(x_fit_values_positive > 0); 

    % --- Scaling factor for converting PDF to approximate counts (occurrences) ---
   
    scaling_factor = total_num_data_points * bin_width;
    if scaling_factor == 0
        warning('Scaling factor is zero. Fitted curves will not be scaled correctly.');
    end

    %% --- Gamma Distribution Fit ---
    fprintf('INFO: Fitting Gamma distribution...\n');
    try
        % Fit Gamma distribution using Maximum Likelihood Estimation
        pd_gamma = fitdist(data_to_fit, 'Gamma');
        
        % Generate y-values for the fitted Gamma PDF
        x_fit_gamma = linspace(max(x_limits(1), 1e-12), x_limits(2), 500);
        x_fit_gamma(x_fit_gamma <= 0) = 1e-12; 
        y_fit_gamma_pdf = gampdf(x_fit_gamma, pd_gamma.a, pd_gamma.b);
        
        % Scale the Gamma PDF to approximate counts for plotting
        y_fit_gamma_scaled = y_fit_gamma_pdf * scaling_factor;
        plot(ax_handle, x_fit_gamma, y_fit_gamma_scaled, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5, 'DisplayName', 'Gamma Fit'); 
        
        if ~isempty(y_hist_counts)
            % RMSE calculation
            gamma_rmse = calculate_rmse_helper(y_hist_counts, @(x) gampdf(x, pd_gamma.a, pd_gamma.b), hist_bin_centers, scaling_factor);
            fprintf('DEBUG: Gamma fit successful. A: %.4f, B: %.4f, RMSE: %.4e\n', pd_gamma.a, pd_gamma.b, gamma_rmse);
        else
            fprintf('DEBUG: Gamma fit successful. A: %.4f, B: %.4f. Could not calculate RMSE (no histogram counts found).\n', pd_gamma.a, pd_gamma.b);
        end
    catch ME
        warning('MATLAB:fitdist:GammaFitFailed', 'Failed to fit Gamma distribution: %s. Skipping Gamma fit.', ME.message);
        gamma_rmse = NaN;
    end

    %% --- Single Log-Gamma Distribution Fit (with Multi-Start lsqcurvefit) ---
    fprintf('INFO: Fitting Single Log-Gamma distribution...\n');
    min_data_val = min(data_to_fit);
    range_data = max(data_to_fit) - min_data_val;
    if range_data == 0, range_data = 1; end 
    
    lb_single_lg = [1e-6, 1e-6, min(min_data_val - (range_data * 10), min_data_val - 1e3)]; 

    min_loc_offset = max(1e-8, bin_width * 0.001); 
    ub_single_lg_loc = min_data_val - min_loc_offset;

    
    ub_single_lg_loc = min(ub_single_lg_loc, min_data_val - 1e-15);

    ub_single_lg = [inf, inf, ub_single_lg_loc];

    
    xdata_for_fit = hist_bin_centers(:); 
    ydata_for_fit = y_hist_counts(:); 
    
    model_fun_single_lg = @(params, x) loggamma_pdf(x, params(1), params(2), params(3)) * scaling_factor;
    num_random_starts = 200; 
    best_rmse_single_lg_current = inf;
    best_fitted_params_single_lg = [];
    
    % Store the RMSE of the very first initial guess
    initial_single_loggamma_rmse_unoptimized_val = NaN; 

    % Options for lsqcurvefit during multi-start (suppress iteration display)
    options_lsq_multistart = optimoptions('lsqcurvefit', 'Display', 'off', ... 
                                          'MaxFunctionEvaluations', 20000, 'MaxIterations', 10000, ...
                                          'FunctionTolerance', 1e-8, 'StepTolerance', 1e-9); 

    fprintf('DEBUG: Starting multi-start lsqcurvefit for Single Log-Gamma Model with %d random starts...\n', num_random_starts);
    for i = 1:num_random_starts
        % Generate randomized initial parameters within reasonable bounds
        random_a_guess = 1e-6 + (100 - 1e-6) * rand(); 
        random_b_guess = 1e-6 + (20 - 1e-6) * rand(); 
        % Generate random_loc_guess uniformly between its lower and upper bounds
        random_loc_guess = lb_single_lg(3) + (ub_single_lg(3) - lb_single_lg(3)) * rand();

        initial_params_single_lg_current = [random_a_guess, random_b_guess, random_loc_guess];
        
        % Calculate RMSE for the first initial guess (unoptimized) for output
        if i == 1 && ~isempty(y_hist_counts)
            % Ensure the function call matches the expected input for calculate_rmse_helper
            initial_single_loggamma_rmse_unoptimized_val = calculate_rmse_helper(y_hist_counts, @(x) loggamma_pdf(x, initial_params_single_lg_current(1), initial_params_single_lg_current(2), initial_params_single_lg_current(3)), hist_bin_centers, scaling_factor);
            fprintf('DEBUG: Initial Single Log-Gamma RMSE (first guess): %.4e\n', initial_single_loggamma_rmse_unoptimized_val);
            
        end

        try
            [current_fitted_params_single_lg, current_resnorm, ~, ~, ~] = lsqcurvefit(model_fun_single_lg, initial_params_single_lg_current, xdata_for_fit, ydata_for_fit, lb_single_lg, ub_single_lg, options_lsq_multistart);
            current_rmse_single_lg = sqrt(current_resnorm / numel(ydata_for_fit));
            
            % Check if fitted parameters are valid and RMSE is better
            
            if current_fitted_params_single_lg(1) > 0 && current_fitted_params_single_lg(2) > 0 && ...
               current_fitted_params_single_lg(3) < min_data_val && ... % Ensure loc is strictly less than min_data_val
               isfinite(current_rmse_single_lg) && current_rmse_single_lg < best_rmse_single_lg_current
                
                best_rmse_single_lg_current = current_rmse_single_lg;
                best_fitted_params_single_lg = current_fitted_params_single_lg;
                fprintf('    New best RMSE for Single Log-Gamma found: %.4e\n', best_rmse_single_lg_current);
            end
        catch ME
            fprintf('    Warning: lsqcurvefit failed for this Single Log-Gamma start (%s). Skipping.\n', ME.message);
        end
    end

    if isempty(best_fitted_params_single_lg)
        fprintf('ERROR: Multi-start optimization failed to find any valid fit for Single Log-Gamma after %d runs. Skipping plot and RMSE calculation.\n', num_random_starts);
    else
        a_fit_single_lg = best_fitted_params_single_lg(1);
        b_fit_single_lg = best_fitted_params_single_lg(2);
        loc_fit_single_lg = best_fitted_params_single_lg(3);
        
        % Calculate PDF values for the fitted Single Log-Gamma distribution
        y_fit_single_loggamma_pdf = loggamma_pdf(x_fit_values_positive, a_fit_single_lg, b_fit_single_lg, loc_fit_single_lg);
        
        % Scale the Log-Gamma PDF to approximate counts for plotting
        y_fit_single_loggamma_scaled = y_fit_single_loggamma_pdf * scaling_factor;
        y_fit_single_loggamma_scaled(~isfinite(y_fit_single_loggamma_scaled)) = 0; 
        
        plot(ax_handle, x_fit_values_positive, y_fit_single_loggamma_scaled, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'DisplayName', 'Single Log-Gamma Fit (Optimized)'); % Orange color

        single_loggamma_rmse_optimized = best_rmse_single_lg_current;
        fprintf('DEBUG: Single Log-Gamma fit successful (Optimized). A: %.4f, B: %.4f, Loc: %.4e, RMSE: %.4e\n', a_fit_single_lg, b_fit_single_lg, loc_fit_single_lg, single_loggamma_rmse_optimized);
    end
    
    % Assign the stored initial RMSE value to the output variable
    single_loggamma_rmse_unoptimized = initial_single_loggamma_rmse_unoptimized_val;

  
    %% --- Update Legend ---
    all_plot_handles = findobj(ax_handle, '-property', 'DisplayName');
    valid_legend_handles = [];
    final_legend_strings = {};
    for i = 1:length(all_plot_handles)
        dn = get(all_plot_handles(i), 'DisplayName');
        if ~isempty(dn) && ~strcmp(dn, 'data_for_pdf_filtered_iqr') 
            valid_legend_handles(end+1) = all_plot_handles(i); %#ok<AGROW>
            final_legend_strings{end+1} = dn; %#ok<AGROW>
        end
    end
    
    if ~isempty(valid_legend_handles)
        legend(ax_handle, valid_legend_handles, final_legend_strings, 'Location', 'best', 'Interpreter', 'latex', 'FontSize', FONT_SIZE_LEGEND);
    end

    fprintf('\n--- RMSE Results for Fitted Distributions ---\n');
    fprintf('Gamma RMSE: %.4e\n', gamma_rmse);
    fprintf('Single Log-Gamma RMSE (Optimized): %.4e\n', single_loggamma_rmse_optimized);
    fprintf('Single Log-Gamma RMSE (Initial Guess): %.4e\n', single_loggamma_rmse_unoptimized);
    fprintf('----------------------------------------------\n');

    hold(ax_handle, 'off'); 
    fprintf('DEBUG: Exiting fit_distributions_to_pdf function.\n');

    %% --- Local Helper Functions ---
    % --- Helper function for Log-Gamma PDF ---
    
    function p = loggamma_pdf(x, a, b, loc)
        
        if a <= 0 || b <= 0 
            p = zeros(size(x)); 
            return;
        end
        valid_x_indices = (x > loc);
        p = zeros(size(x)); 
        if any(valid_x_indices)
            x_val = x(valid_x_indices);
            
            % Calculate the transformed variable for the Gamma PDF
            fixed_small_offset = 1e-10; % A small, fixed positive value
            transformed_val = (x_val - loc) ./ b;
            transformed_val(transformed_val <= fixed_small_offset) = fixed_small_offset; 
            
            % Calculate Gamma PDF for the transformed variable with scale 1
            gamma_pdf_val = gampdf(transformed_val, a, 1); 
            
            % Apply the change of variable factor (1/b)
            p(valid_x_indices) = gamma_pdf_val ./ (abs(b) + eps); 
            
            % Handle cases where results might be Inf/NaN
            p(~isfinite(p)) = 0; 
        end
    end 

    % --- Helper function for RMSE calculation ---
    function rmse = calculate_rmse_helper(y_true_counts, y_pred_pdf_func, x_values_for_pred, scaling_factor_for_rmse)
        
        % Calculate predicted PDF values at the histogram bin centers
        y_pred_pdf = y_pred_pdf_func(x_values_for_pred);
        
        % Scale the predicted PDF values to counts
        y_pred_counts = y_pred_pdf * scaling_factor_for_rmse;
        
        % Ensure y_true_counts and y_pred_counts are column vectors and of the same length
        y_true_counts = y_true_counts(:);
        y_pred_counts = y_pred_counts(:);
        
        if numel(y_true_counts) ~= numel(y_pred_counts)
            warning('RMSE calculation: True and predicted data lengths do not match. Skipping RMSE for this fit.');
            rmse = NaN;
            return;
        end
        
        % Handle NaN/Inf in predicted counts
        if any(~isfinite(y_pred_counts))
            rmse = Inf; 
            return;
        end

        residuals = y_true_counts - y_pred_counts;
        rmse = sqrt(mean(residuals.^2));
    end 
end 
