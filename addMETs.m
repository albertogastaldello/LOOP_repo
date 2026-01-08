clc
clear all
close all

%% load exercise data and add METs and METs/min columns

exercise = readtable("Data Tables/LOOPDeviceExercise.txt");

common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;

exercise = exercise(ismember(exercise.PtID, common_subjectsID_numeric), :);

exercise.MET = zeros(size(exercise,1), 1);
exercise.MET_min = zeros(size(exercise,1), 1);

for i=1:size(exercise,1)
    curr_patientID = exercise.PtID(i);
    struct_patientField = ['patient_' num2str(curr_patientID)];
    curr_weight = subjectsStruct.(struct_patientField).surveys.weight_kg(1);
    curr_MET = exercise.EnergyValue(i) / (curr_weight * (exercise.DurationValue(i) / 3600));
    exercise.MET(i) = curr_MET;

    curr_MET_min = curr_MET * (exercise.DurationValue(i)/60);
    exercise.MET_min(i) = curr_MET_min;
end

%% save

save("exerciseTable.mat", "exercise")