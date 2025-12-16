clc
clear all
close all

%% select a subject and load the data

common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;

subj_idx = 126; % choose an index

subjID = common_subjectsID(subj_idx);

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';

cgm_path = strcat(base_path, '/data_type=cgm/patient_id=', subjID, '/cgm.csv');
cgm_data = readtable(cgm_path);

basal_path = strcat(base_path, '/data_type=basal/patient_id=', subjID, '/basal.csv');
basal_data = readtable(basal_path);

bolus_path = strcat(base_path, '/data_type=bolus/patient_id=', subjID, '/bolus.csv');
bolus_data = readtable(bolus_path);

dataTablesStructure = load("dataTablesStructure_withDateTime.mat").data_tables_all;
subjStruct_ID = strcat('patient_', subjID);
subjStruct = dataTablesStructure.(subjStruct_ID);

%% plot data

figure()
ax1 = subplot(3,1,1);
hold on
yyaxis left
plot(cgm_data.datetime, cgm_data.cgm)
ylabel('Glucose (mg/dl)')
yyaxis right
stem(subjStruct.food.DeviceDtTm, subjStruct.food.CarbsNet)
ylabel('Net Carbohydrates (g)')
hold off
xlabel('Time');
title('CGM and meals')

ax2 = subplot(3,1,2);
hold on;

y_spacing = 1;   % spazio verticale tra attività se vuoi separarle
n_exercises = height(subjStruct.exercise);



for i = 1:n_exercises
    x_start = subjStruct.exercise.DeviceDtTm(i);
    x_end   = x_start + seconds(subjStruct.exercise.DurationValue(i));  
    y_pos = 0;          % puoi mettere i valori verticali base a 0
    height = subjStruct.exercise.EnergyValue(i);

    % Crea rettangolo
    X = [x_start x_end x_end x_start];
    Y = [y_pos y_pos y_pos+height y_pos+height];

    patch(X, Y, [0.2 0.6 0.8], 'EdgeColor','k')
end

xlabel('Time');
ylabel('Energy Expenditure (kcal)');
title('Exercise');

grid on;

ax3 = subplot(3,1,3);
hold on
stem(bolus_data.datetime, bolus_data.bolus, 'r');
plot(basal_data.datetime, basal_data.basal_rate, 'b');
title('Bolus and basal insulin')
xlabel('Time');

if(n_exercises>0)
    linkaxes([ax1, ax2, ax3], 'x')
else
    linkaxes([ax1, ax3], 'x')
end

