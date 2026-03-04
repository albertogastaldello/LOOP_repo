clc
clear all
close all

%% Load filtered exercise table
exercise = load("exerciseTable_filtered.mat").exerciseTable_clean;
exercise(exercise.DurationValue < 15, :) = [];

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';
subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;

% Columns of meals data to keep
mealColumsToKeep = ["PtID", "RecID", "DeviceDtTm", "UTCDtTm", ...
                    "CarbsNet", "CarbUnits", "TmZnOffset"];

subjectsID = unique(exercise.PtID);

% Preallocate exercise_valid table
exercise_valid = exercise([],:);           % empty table with same columns
exercise_valid.insulinData = {};           % cell for insulin struct
exercise_valid.cgmData     = {};           % cell for CGM struct
exercise_valid.mealData    = {};           % cell for meal table

counter = 0;

% Loop over subjects
for i = 1:length(subjectsID)
    disp(['Processing subject ' num2str(i) ' of ' num2str(length(subjectsID))]);
    
    curr_subjID = subjectsID(i);
    struct_patientField = ['patient_' num2str(curr_subjID)];
    curr_exercise = exercise(exercise.PtID == curr_subjID,:);
    
    % Load subject data once
    cgm_data   = readtable(fullfile(base_path, ['data_type=cgm/patient_id=' num2str(curr_subjID)], 'cgm.csv'));
    basal_data = readtable(fullfile(base_path, ['data_type=basal/patient_id=' num2str(curr_subjID)], 'basal.csv'));
    bolus_data = readtable(fullfile(base_path, ['data_type=bolus/patient_id=' num2str(curr_subjID)], 'bolus.csv'));
    
    % Convert timestamps to datenum for speed
    cgm_data.datenum   = datenum(cgm_data.datetime);
    basal_data.datenum = datenum(basal_data.datetime_aligned);
    bolus_data.datenum = datenum(bolus_data.datetime_aligned);
    
    curr_wizard = subjectsStruct.(struct_patientField).wizard;
    curr_wizard = sortrows(curr_wizard, 'DeviceDtTm');
    curr_wizard.datenum = datenum(curr_wizard.DeviceDtTm);
    
    curr_subjectMealData = subjectsStruct.(struct_patientField).food(:, mealColumsToKeep);
    curr_subjectMealData.datenum = datenum(curr_subjectMealData.DeviceDtTm);
    
    % Loop over sessions
    for j = 1:height(curr_exercise)
        curr_session = curr_exercise(j,:);
        
        startExercise = curr_session.DeviceDtTm;
        endExercise   = startExercise + minutes(curr_session.DurationValue);
        preExercise   = startExercise - hours(2);
        postExercise  = endExercise + hours(6);
        
        % -------- CGM Data --------
        [uniqueTimes, ~, ic] = unique(cgm_data.datetime);
        cgm_agg = accumarray(ic, cgm_data.cgm, [], @mean);
        
        idxExercise = cgm_data.datenum >= datenum(startExercise) & cgm_data.datenum <= datenum(endExercise);
        idxPre      = cgm_data.datenum >= datenum(preExercise) & cgm_data.datenum <= datenum(startExercise);
        idxPost     = cgm_data.datenum >= datenum(endExercise) & cgm_data.datenum <= datenum(postExercise);
        
        % Minimum number of points (optional)
        if height(cgm_data(idxPre,:)) < 0.85*24 || height(cgm_data(idxExercise,:)) < 3 || height(cgm_data(idxPost,:)) < 0.85*72
            continue
        end
        
        cgmExercise_table     = timetable(cgm_data.datetime(idxExercise), cgm_data.cgm(idxExercise), 'VariableNames', {'Glucose'});
        cgmPreExercise_table  = timetable(cgm_data.datetime(idxPre), cgm_data.cgm(idxPre), 'VariableNames', {'Glucose'});
        cgmPostExercise_table = timetable(cgm_data.datetime(idxPost), cgm_data.cgm(idxPost), 'VariableNames', {'Glucose'});
        
        % -------- Insulin Data --------
        [curr_CF, curr_CR, curr_tslb, curr_lb, curr_tslBasal, curr_lBasal, curr_IOB] = ...
            getInsulinInfo(curr_session, curr_wizard, bolus_data, basal_data);
        
        tmpInsulin = struct('InsSensitivity', curr_CF, ...
                            'InsCarbRatio', curr_CR, ...
                            'TimeSinceLastBolus', curr_tslb, ...
                            'LastBolus', curr_lb, ...
                            'TimeSinceLastBasal', curr_tslBasal, ...
                            'LastBasal', curr_lBasal, ...
                            'IOB', curr_IOB);
        
        % -------- Meal Data --------
        preMeal  = startExercise - hours(6);
        postMeal = endExercise + hours(6);
        idxMeal  = curr_subjectMealData.datenum >= datenum(preMeal) & curr_subjectMealData.datenum <= datenum(postMeal);
        sessionMealData = curr_subjectMealData(idxMeal,:);
        
        % -------- Append session --------
        counter = counter + 1;
        
        % Aggiungo le 3 colonne mancanti alla riga
        curr_session.insulinData = {tmpInsulin};
        curr_session.cgmData     = {struct('cgmPreExercise', cgmPreExercise_table, ...
                                           'cgmExercise', cgmExercise_table, ...
                                           'cgmPostExercise', cgmPostExercise_table)};
        curr_session.mealData    = {sessionMealData};
        
        % Ora le colonne combaciano perfettamente
        exercise_valid(counter,:) = curr_session;


        exercise_valid.cgmData{counter}     = struct('cgmPreExercise', cgmPreExercise_table, ...
                                                     'cgmExercise', cgmExercise_table, ...
                                                     'cgmPostExercise', cgmPostExercise_table);
        exercise_valid.insulinData{counter} = tmpInsulin;
        exercise_valid.mealData{counter}    = sessionMealData;
    end
end

% Optional: trim unused preallocated rows
exercise_valid = exercise_valid(1:counter,:);

%% save

save("exerciseTableWithWearableData.mat", "exercise_valid");


%% getInsulinInfo function

function [CF, CR, tslb, lb, tslBasal, lBasal, IOB] = getInsulinInfo(session, wizard, bolus_data, basal_data)
    CF=NaN; CR=NaN; tslb=NaN; lb=NaN; tslBasal=NaN; lBasal=NaN; IOB=NaN;
    maxTolerance = minutes(30);
    startExercise = session.DeviceDtTm;
    
    % Wizard CF and CR
    idx = find(wizard.datenum <= datenum(startExercise), 1, 'last');
    if ~isempty(idx)
        CF = wizard.InsulinSensitivity(idx);
        CR = wizard.InsulinCarbRatio(idx);
        if startExercise - wizard.DeviceDtTm(idx) <= maxTolerance
            IOB = wizard.InsulinOnBoard(idx);
        end
    end
    
    % Last bolus info
    idx_bolus = find(bolus_data.datenum <= datenum(startExercise), 1, 'last');
    if ~isempty(idx_bolus)
        tslb = minutes(startExercise - bolus_data.datetime_aligned(idx_bolus));
        lb   = bolus_data.bolus(idx_bolus);
    end
    
    % Last basal info
    idx_basal = find(basal_data.datenum <= datenum(startExercise), 1, 'last');
    if ~isempty(idx_basal)
        tslBasal = minutes(startExercise - basal_data.datetime_aligned(idx_basal));
        lBasal   = basal_data.basal_rate(idx_basal);
    end
end