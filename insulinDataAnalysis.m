clc
close all
clear all

%% load data structures

allSubjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
commonWizard_subjectsID = load("commonWizard_subjectsID.mat").commonWizard_subjectsID;

subj_idx = 5; % choose an index
%subjID = common_subjectsID(subj_idx);
subjID = commonWizard_subjectsID(subj_idx);

fieldsCommonWizard = "patient_" + commonWizard_subjectsID;
all_fields = string(fieldnames(allSubjectsStruct));
fields_valid = intersect(all_fields, fieldsCommonWizard);
subjectsStruct = rmfield(allSubjectsStruct, setdiff(all_fields, fields_valid));

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';
basal_path = strcat(base_path, '/data_type=basal/patient_id=', subjID, '/basal.csv');
basal_data = readtable(basal_path);

bolus_path = strcat(base_path, '/data_type=bolus/patient_id=', subjID, '/bolus.csv');
bolus_data = readtable(bolus_path);

%% choose a subject and evaluate insulin-carb correlation

fieldName = fieldsCommonWizard(subj_idx,1);
struct = subjectsStruct.(fieldName);

figure()
ax1 = subplot(2,1,1);
stem(bolus_data.datetime_aligned, bolus_data.bolus, 'k')
hold on
plot(basal_data.datetime_aligned, basal_data.basal_rate, 'r')
legend('Bolus', 'Basal')

ax2 = subplot(2,1,2);
stem(struct.food.DeviceDtTm, struct.food.CarbsNet)
title('Carbs (g)')
linkaxes([ax1 ax2], 'x')


figure()
ax1 = subplot(2,1,1);
stem(bolus_data.datetime_aligned, bolus_data.bolus, 'k')
% hold on
% plot(basal_data.datetime_aligned, basal_data.basal_rate, 'r')
% legend('Bolus', 'Basal')
title('Bolus')

ax2 = subplot(2,1,2);
stem(struct.wizard.DeviceDtTm, struct.wizard.RecommendedNet)
title('Recommended Net')

linkaxes([ax1 ax2], 'x')
