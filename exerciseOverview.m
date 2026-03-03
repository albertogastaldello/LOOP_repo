clc
clear all
close all

%% load subjects structure

allSubjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
commonWizard_subjectsID = load("commonWizard_subjectsID.mat").commonWizard_subjectsID;

fieldsCommonWizard = "patient_" + commonWizard_subjectsID;
all_fields = string(fieldnames(allSubjectsStruct));
fields_valid = intersect(all_fields, fieldsCommonWizard);
subjectsStruct = rmfield(allSubjectsStruct, setdiff(all_fields, fields_valid));
subjectsInfo = struct();

subjects = fieldnames(subjectsStruct);
n_subjects = size(subjects,1);

%% exercise characteristics distribution

n_exercises = zeros(1, n_subjects);
exercises_duration = [];
exercises_time = [];
exercises_kcal = [];

j=0;

for i = 1:n_subjects
    curr_exercise_table = subjectsStruct.(subjects{i,1}).exercise;
    
    if(~isempty(curr_exercise_table))
        curr_exercise_table.DurationValue = curr_exercise_table.DurationValue./60;
        j=j+1;
        n_exercises(1,i) = size(curr_exercise_table,1);
        exercises_duration = [exercises_duration; curr_exercise_table.DurationValue];
        exercises_time = [exercises_time; timeofday(curr_exercise_table.DeviceDtTm)];
        exercises_kcal = [exercises_kcal; curr_exercise_table.EnergyValue];

    end
end

figure()
histogram(n_exercises)
title('Distribution of number of exercise among subjects')

figure()
subplot(3,1,1)
histogram(exercises_time, j)
title('Distribution of exercise time')
subplot(3,1,2)
histogram(exercises_duration, j)
title('Distribution of exercise duration (in minutes)')
subplot(3,1,3)
histogram(exercises_kcal, j)
title('Distribution of exercise energy (in kcal)')



figure()
boxplot(n_exercises)
title('Distribution of number of exercise among subjects')

figure()
subplot(3,1,1)
boxplot(hours(exercises_time))
title('Distribution of exercise time')
subplot(3,1,2)
boxplot(exercises_duration)
title('Distribution of exercise duration (in minutes)')
subplot(3,1,3)
boxplot(exercises_kcal)
title('Distribution of exercise energy (in kcal)')

%% study duration among subjects

common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';

n_subjects = length(common_subjectsID_numeric);

durations = zeros(1, n_subjects);

for i=1:n_subjects
    
    subjID = common_subjectsID(i);
    
    cgm_path = strcat(base_path, '/data_type=cgm/patient_id=', subjID, '/cgm.csv');
    cgm_data = readtable(cgm_path);
    
    basal_path = strcat(base_path, '/data_type=basal/patient_id=', subjID, '/basal.csv');
    basal_data = readtable(basal_path);
    
    bolus_path = strcat(base_path, '/data_type=bolus/patient_id=', subjID, '/bolus.csv');
    bolus_data = readtable(bolus_path);


    first_cgm_date = cgm_data.datetime(1);
    last_cgm_date = cgm_data.datetime(end);

    first_basal_date = basal_data.datetime(1);
    last_basal_date = basal_data.datetime(end);

    first_bolus_date = bolus_data.datetime(1);
    last_bolus_date = bolus_data.datetime(end);

    first_common_date = max([first_cgm_date, first_basal_date, first_bolus_date], [], 'omitmissing');
    last_common_date  = min([last_cgm_date,  last_basal_date,  last_bolus_date],  [], 'omitmissing');

    curr_duration = days(last_common_date - first_common_date);

    durations(1,i) = floor(curr_duration);

end

figure()
histogram(durations, 30)
title('Data duration distribution')
xlabel('days')

%% count occurrence of each activity

exercise = load("exerciseTable.mat").exercise_table;

common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;

exercise = exercise(ismember(exercise.PtID, common_subjectsID_numeric), :);

exercise = exercise(exercise.DurationValue > 0,:);
exercise.EnergyPerMinute = exercise.EnergyValue ./ exercise.DurationValue;

raw_activities = exercise.ExerciseName;

clean_activities = cell(size(raw_activities));
for i = 1:length(raw_activities)
    str = raw_activities{i};
    pos = strfind(str, ' - ');
    if ~isempty(pos)
        clean_activities{i} = strtrim(str(1:pos-1));
    else
        clean_activities{i} = str;
    end
end

exercise.CleanActivityName = clean_activities;

[uniqueActivities, ~, idx] = unique(exercise.CleanActivityName);
counts = accumarray(idx, 1);
activityCountTable = table(uniqueActivities, counts, ...
    'VariableNames', {'Activity', 'Count'});

activityCountTable = activityCountTable(~ismissing(activityCountTable.Activity),:);

