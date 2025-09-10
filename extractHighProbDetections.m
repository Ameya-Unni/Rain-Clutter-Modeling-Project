function [x_coor, y_coor, eta, valid_mask] = extractHighProbDetections(scan, hPBWphi, hPBWtheta, rangeRes, Xlim, Ylim,azishift_val)
% Extracts coordinates and RCS density from radar scan struct
% Inputs:
%   - scan      : NearScan or FarScan struct from ars_HH (containing prob0, prob1, RCS0, RCS1, Azimuth0_rad, Azimuth1_rad, Range_m)
%   - hPBWphi   : Horizontal beamwidth in radians
%   - hPBWtheta : Vertical beamwidth in radians
%   - rangeRes  : Range resolution (in meters)
%   - Xlim      : [xmin xmax] range for X axis (cross-range)
%   - Ylim      : [ymin ymax] range for Y axis (down-range)
%   - azishift_val: Azimuth shift value in radians (default 0), applied to azimuth before Cartesian conversion.
%
% Outputs:
%   - x_coor, y_coor : Cartesian coordinates (meters) of valid detections.
%   - eta            : RCS per unit volume for valid detections.
%   - valid_mask     : Logical mask indicating which points from the *original* snapshot were valid and kept.
    
    % Extract fields from scan struct
    prob0 = scan.prob0;
    prob1 = scan.prob1;
    rcs0  = scan.RCS0;
    
    % Handle RCS1 potentially not existing; use RCS0 as fallback if missing
    if isfield(scan, 'RCS1')
        rcs1 = scan.RCS1;
    else
        rcs1 = rcs0; 
    end
    
    az0   = scan.Azimuth0_rad;
    az1   = scan.Azimuth1_rad;
    range = scan.Range_m;
    
    % Use higher probability hypothesis for azimuth and RCS
    use0 = prob0 > prob1; 
    azimuth = az0 .* use0 + az1 .* (~use0); 
    rcs     = rcs0 .* use0 + rcs1 .* (~use0); 
    

    % Convert to Cartesian coordinates
    
    x_coor_full = -1 .* range .* tan(azimuth + deg2rad(azishift_val));
    y_coor_full = range;
    

    % Calculate volume for each point
    % clipped range to avoid division by zero or very small numbers
    range_cl = max(range, 1e-3); 
    % Volume of resolution calculation
    volume_of_resolution = (range_cl.^2 * hPBWphi * hPBWtheta * rangeRes); 
    volume_of_resolution(volume_of_resolution < 1e-6) = 1e-6; 
    
    % Common RCS ranges are usually within [-50, +30] dBsm.
    rcs_clipped = min(max(rcs, -5000), 5000); 
    
    % Convert RCS from dBsm to linear scale and calculate eta (linear reflectivity)
    eta_linear_full = 10.^(rcs_clipped ./ 10) ./ volume_of_resolution;
    
    % Valid mask: within X/Y limits and not NaN or Inf for eta
    valid_mask_temp = ~isnan(eta_linear_full) & ~isinf(eta_linear_full) & ...
                 (x_coor_full >= Xlim(1)) & (x_coor_full <= Xlim(2)) & ...
                 (y_coor_full >= Ylim(1)) & (y_coor_full <= Ylim(2));
    
    % Filter all arrays by valid mask. Only return the valid points.
    x_coor = x_coor_full(valid_mask_temp);
    y_coor = y_coor_full(valid_mask_temp);
    eta = eta_linear_full(valid_mask_temp);
    valid_mask = valid_mask_temp; 
end