clc;
close all;
tic

%% Define folder and filenames
root   = "";              
folder = "NIED_Data";     

%% Get only the CSV files
listing = dir( fullfile(folder, '*.csv') );   

for k = 1:numel(listing)
    csvname = listing(k).name;
    fullname = fullfile(root, folder, csvname);
    fprintf("Processing %s …\n", csvname);

    ars_HH = conti2mat(fullname);
    measdata = struct("ars430_HH", ars_HH);

    % Save individually
    [~, base, ~] = fileparts(csvname);
    save(fullfile(folder, base + ".mat"), "measdata", '-v7.3');

 end

toc
