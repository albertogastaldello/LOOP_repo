clc
clear all
close all

%% load tables

addpath("tables/");

exercise_table = load("exerciseTable.mat").exercise_table;
exercise_tableFiltered = load("exerciseTable_filtered.mat").exerciseTable_clean;
exerciseTableForBN = load("exerciseTableForBN.mat").exerciseTableForBN;

%% choose a random subject

subjectsID = unique(exercise_table.PtID);
Nsubjects = length(subjectsID);
i = randi(Nsubjects);

curr_subjID = subjectsID(i);

exercise_table_subject = exercise_table(exercise_table.PtID == curr_subjID,:);
exercise_tableFiltered_subject = exercise_tableFiltered(exercise_tableFiltered.PtID ...
    == curr_subjID, :);

% exercise_tableForBN_subject = exerciseTableForBN(exerciseTableForBN.PtID ...
%     == curr_subjID, :);

exerciseStarts = exercise_table_subject.DeviceDtTm;
exerciseEnds = exerciseStarts + minutes(exercise_table_subject.DurationValue);

exercise_filtered_starts = exercise_tableFiltered_subject.DeviceDtTm;
exercise_filtered_ends = exercise_filtered_starts + minutes(exercise_tableFiltered_subject.DurationValue);

figure()
stem(exercise_table_subject.DeviceDtTm, ones(1, height(exercise_table_subject)), 'k')
hold on
% stem(exercise_tableForBN_subject.DeviceDtTm, 2 * ones(1, height(exercise_tableForBN_subject)), 'r')
stem(exercise_tableFiltered_subject.DeviceDtTm, 2 * ones(1, height(exercise_tableFiltered_subject)), 'r')