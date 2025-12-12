clc
clear all
close all

%% create data tables structure for all subjects

common_subjectsID = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
n_common_subjects = length(common_subjectsID);

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects';

data_tables_all = struct();

warnState = warning('off', 'all');

for i=1:n_common_subjects

    curr_subjID = common_subjectsID(i);
    subj_folder = fullfile(base_path, "patient_id=" + num2str(curr_subjID));

    csv_files = dir(fullfile(subj_folder, '*.csv'));

    subj_data = struct();

    for j = 1:length(csv_files)
        file_name = csv_files(j).name;
        % Nome campo senza estensione
        [~, field_name, ~] = fileparts(file_name);
        tbl = readtable(fullfile(subj_folder, file_name));
        subj_data.(field_name) = tbl;
    end

    data_tables_all.("patient_" + num2str(curr_subjID)) = subj_data;
end

warning(warnState);

%% save data tables structure

save("dataTablesStructure.mat", "data_tables_all");