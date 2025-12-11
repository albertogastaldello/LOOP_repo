clc
clear all
close all

%% get subjects ID

folders = dir('data_type=cgm');
folders = folders([folders.isdir]);   
folders = folders(~ismember({folders.name}, {'.', '..'}));
folder_names = {folders.name};

n_subj = size(folder_names, 2);

subjectsID_numeric = zeros(1, n_subj);

for i = 1:n_subj
    curr_folder_name = folder_names{1,i};
    curr_subjectID = curr_folder_name(12:end);
    curr_subjectID_numeric = str2double(curr_subjectID);
    subjectsID_numeric(1, i) = curr_subjectID_numeric;
end

subjectsID_numeric = sort(subjectsID_numeric);
subjectsID = string(subjectsID_numeric);

%% save

save("SubjectsID.mat", "subjectsID");
save("SubjectsIDNumeric.mat", "subjectsID_numeric");