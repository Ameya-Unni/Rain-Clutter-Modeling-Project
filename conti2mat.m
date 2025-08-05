function [ars_HH] = conti2mat(filename)
%CONTI2MAT converts csv-files from ARS-measurements into mat-struct
%   (c) Andreas Schwind, FG HMT, TU Ilmenau, <andreas.schwind@tu-ilmenau.de>


    %% Input csv-file
    arsdata_table = importfile_ARS_table(filename, [1, Inf]);
   
    %%
    % find locations of "Status" to identify Status informations
    [~,tmp] = ismember(arsdata_table, "Status");
    [idx_row_status,~] = find(tmp==1);
    
    % find locations of "NEAR" to identify NEAR detections
    [~,tmp] = ismember(arsdata_table, "NEAR");
    [idx_row_near,~] = find(tmp==1);
    % find locations of "FAR" to identify FAR detections
    [~,tmp] = ismember(arsdata_table, "FAR");
    [idx_row_far,~] = find(tmp==1);
    
    % count maximum number of detections (near and far) for array size
    max_num_detect_near = min(max(double(arsdata_table(idx_row_near,6))), 3.0868e+05);% SG: max(double(arsdata_table(idx_row_near,6)));
    max_num_detect_far  = max(double(arsdata_table(idx_row_far,6)));
    
    %%
    % divide string table into status/near/far arrays
    ars_status_head = arsdata_table(1,:);
    
    ars_status      = string(nan(size(idx_row_status,1),32));
  

    ars_detect_near = string(nan(size(idx_row_status,1),max_num_detect_near,24));
    ars_detect_far  = string(nan(size(idx_row_status,1),max_num_detect_far, 24));
   
    
    for k = 1:size(idx_row_status,1)
        disp("Snapshot: "+string(k)+" / "+string(size(idx_row_status,1)));
        % ars_status
        ars_status(k,:) = arsdata_table(idx_row_status(k),:);
    
        % ars_detect_near
        [~,tmp1] = ismember(arsdata_table(:,1), string(k));
        [~,tmp2] = ismember(arsdata_table(:,3), "NEAR");
        [tmp,~]  = find(tmp1+tmp2 == 2);
        ars_detect_near(k,1:length(tmp),:) = arsdata_table(tmp,1:24);
        disp("Assigning detection data at index: " + k);

    
        % ars_detect_far
        [~,tmp1] = ismember(arsdata_table(:,1), string(k));
        [~,tmp2] = ismember(arsdata_table(:,3), "FAR");
        [tmp,~]  = find(tmp1+tmp2 == 2);
        ars_detect_far(k,1:length(tmp),:) = arsdata_table(tmp,1:24);
    end
    
    %% Organize all data in struct
    
    % Split ars_detect_near/far into single variables
    % NEAR
    near_detections_utc             = double(ars_detect_near(:,:,4));
    near_num_detections             = double(ars_detect_near(:,:,6));
    near_range                      = double(ars_detect_near(:,:,7));
    near_rel_rad_velocity           = double(ars_detect_near(:,:,8));
    near_azimuth_0                  = double(ars_detect_near(:,:,9));
    near_azimuth_1                  = double(ars_detect_near(:,:,10));
    near_elevation                  = double(ars_detect_near(:,:,11));
    near_rcs_0                      = double(ars_detect_near(:,:,12));
    near_rcs_1                      = double(ars_detect_near(:,:,13));
    near_prob_0                     = double(ars_detect_near(:,:,14));
    near_prob_1                     = double(ars_detect_near(:,:,15));
    near_range_variance             = double(ars_detect_near(:,:,16));
    near_rel_rad_velocity_variance  = double(ars_detect_near(:,:,17));
    near_azimuth_0_variance         = double(ars_detect_near(:,:,18));
    near_azimuth_1_variance         = double(ars_detect_near(:,:,19));
    near_elevation_variance         = double(ars_detect_near(:,:,20));
    near_pdh0                       = double(ars_detect_near(:,:,21));
    near_snr                        = double(ars_detect_near(:,:,22));
    near_intpowerlog                = double(ars_detect_near(:,:,24));
    % FAR
    far_detections_utc              = double(ars_detect_far(:,:,4));
    far_num_detections              = double(ars_detect_far(:,:,6));
    far_range                       = double(ars_detect_far(:,:,7));
    far_rel_rad_velocity            = double(ars_detect_far(:,:,8));
    far_azimuth_0                   = double(ars_detect_far(:,:,9));
    far_azimuth_1                   = double(ars_detect_far(:,:,10));
    far_elevation                   = double(ars_detect_far(:,:,11));
    far_rcs_0                       = double(ars_detect_far(:,:,12));
    far_rcs_1                       = double(ars_detect_far(:,:,13));
    far_prob_0                      = double(ars_detect_far(:,:,14));
    far_prob_1                      = double(ars_detect_far(:,:,15));
    far_range_variance              = double(ars_detect_far(:,:,16));
    far_rel_rad_velocity_variance   = double(ars_detect_far(:,:,17));
    far_azimuth_0_variance          = double(ars_detect_far(:,:,18));
    far_azimuth_1_variance          = double(ars_detect_far(:,:,19));
    far_elevation_variance          = double(ars_detect_far(:,:,20));
    far_pdh0                        = double(ars_detect_far(:,:,21));
    far_snr                         = double(ars_detect_far(:,:,22));
    far_intpowerlog                 = double(ars_detect_far(:,:,24));
    
    % build structs of near- and farscan
    nearscan = struct( ...
        "UTCtime_ms",                   near_detections_utc,...
        "Num_detections",               near_num_detections,...
        "Range_m",                      near_range,...
        "Range_variance",               near_range_variance,...
        "Rel_radial_velocity_m_s",      near_rel_rad_velocity,...
        "Rel_radial_velocity_variance", near_rel_rad_velocity_variance,...
        "Azimuth0_rad",                 near_azimuth_0,...
        "Azimuth0_variance",            near_azimuth_0_variance,...
        "Azimuth1_rad",                 near_azimuth_1,...
        "Azimuth1_variance",            near_azimuth_1_variance,...
        "Elevation_rad",                near_elevation,...
        "Elevation_variance",           near_elevation_variance,...
        "RCS0",                         near_rcs_0,...
        "RCS1",                         near_rcs_1,...
        "prob0",                        near_prob_0,...
        "prob1",                        near_prob_1,...
        "pdh0",                         near_pdh0,...
        "SNR",                          near_snr,...
        "IntPowerLog",                  near_intpowerlog);
    
    farscan = struct( ...
        "UTCtime_ms",                   far_detections_utc,...
        "Num_detections",               far_num_detections,...
        "Range_m",                      far_range,...
        "Range_variance",               far_range_variance,...
        "Rel_radial_velocity_m_s",      far_rel_rad_velocity,...
        "Rel_radial_velocity_variance", far_rel_rad_velocity_variance,...
        "Azimuth0_rad",                 far_azimuth_0,...
        "Azimuth0_variance",            far_azimuth_0_variance,...
        "Azimuth1_rad",                 far_azimuth_1,...
        "Azimuth1_variance",            far_azimuth_1_variance,...
        "Elevation_rad",                far_elevation,...
        "Elevation_variance",           far_elevation_variance,...
        "RCS0",                         far_rcs_0,...
        "RCS1",                         far_rcs_1,...
        "prob0",                        far_prob_0,...
        "prob1",                        far_prob_1,...
        "pdh0",                         far_pdh0,...
        "SNR",                          far_snr,...
        "IntPowerLog",                  far_intpowerlog);

    %% build struct
    ars_HH = struct(...
        "InfoStatus",       ars_status_head,...
        "Status",           ars_status,...
        "NearScan",         nearscan,...
        "FarScan",          farscan);
%% Push to base workspace
%assignin('base', 'ars_detect_near', ars_detect_near);
%assignin('base', 'ars_detect_far', ars_detect_far);

end