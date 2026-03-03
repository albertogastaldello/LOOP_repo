clc
clear all
close all

%% load filtered exercise table

exercise = load("exerciseTable_filtered.mat").exerciseTable_clean;

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';

subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;

% Initialize columns for METs and subject characteristics

exercise.InsCarbRatio = zeros(size(exercise,1), 1);
exercise.InsSensitivity = zeros(size(exercise,1), 1);
exercise.TimeSinceLastBolus = zeros(size(exercise,1), 1);
exercise.LastBolus = zeros(size(exercise,1), 1);
exercise.TimeSinceLastBasal = zeros(size(exercise,1), 1);
exercise.LastBasal = zeros(size(exercise,1), 1);
exercise.IOBs = zeros(size(exercise,1), 1);

% Choose the outcomes and initialize them
outcomeNames = ["ExcursionDuringActivity", "RoCDuringActivity", "HypoglycemiaEvent", ...
    "SevereHypoglycemiaEvent", "NocturnalTIR", "NocturnalHypoglycemiaEvent"];

for j=1:length(outcomeNames)
    exercise.(outcomeNames(j)) = zeros(size(exercise,1),1);
end

exercise_table = table();

subjectsID = unique(exercise.PtID);

% Iterate for each subject
for i=1:length(subjectsID)

    curr_subjID = subjectsID(i);
    struct_patientField = ['patient_' num2str(curr_subjID)];
    curr_exercise = exercise(exercise.PtID == curr_subjID,:);
    
    cgm_path = strcat(base_path, '/data_type=cgm/patient_id=', num2str(curr_subjID), '/cgm.csv');
    cgm_data = readtable(cgm_path);

    basal_path = strcat(base_path, '/data_type=basal/patient_id=', num2str(curr_subjID), '/basal.csv');
    basal_data = readtable(basal_path);

    bolus_path = strcat(base_path, '/data_type=bolus/patient_id=', num2str(curr_subjID), '/bolus.csv');
    bolus_data = readtable(bolus_path);
    
    % Add the correspondent insulin sensitivity (CF) and insulin carb ratio (CR)
    % for each exercise session of the current subject

    % curr_wizard = wizard(wizard.PtID == curr_subjID,:);
    curr_wizard = subjectsStruct.(struct_patientField).wizard;
    % get and add insulin information
    [curr_CF, curr_CR, curr_tslb, curr_lb, curr_tslBasal, curr_lBasal, curr_IOB] = getInsulinInfo(curr_exercise, curr_wizard, bolus_data, basal_data);

    curr_exercise.InsSensitivity = curr_CF;
    curr_exercise.InsCarbRatio = curr_CR;
    curr_exercise.TimeSinceLastBolus = curr_tslb;
    curr_exercise.LastBolus = curr_lb;
    curr_exercise.TimeSinceLastBasal = curr_tslBasal;
    curr_exercise.LastBasal = curr_lBasal;
    curr_exercise.IOB = curr_IOB;

    curr_outcomes = getOutcomes(curr_exercise, cgm_data, outcomeNames);
    for k = 1:numel(outcomeNames)
        curr_exercise.(outcomeNames(k)) = curr_outcomes(:, k);
    end

    % exercise(exercise.PtID == curr_subjID,:) = curr_exercise;
    curr_exercise = sortrows(curr_exercise, 'DeviceDtTm');
    exercise_table = [exercise_table; curr_exercise];

end



%% function to get the corresponding CF and CR values for one subject's activity sessions

function [CF_vector, CR_vector, tslb_vector, lb_vector, tslBasal_vector, lBasal_vector, IOB_vector] = getInsulinInfo(exercise, wizard, bolus_data, basal_data)

    CF_vector = NaN(height(exercise),1);
    CR_vector = NaN(height(exercise),1);

    tslb_vector = NaN(height(exercise),1);
    lb_vector = NaN(height(exercise),1);
    tslBasal_vector = NaN(height(exercise),1);
    lBasal_vector = NaN(height(exercise),1);

    IOB_vector = NaN(height(exercise),1);

    wizard = sortrows(wizard, 'DeviceDtTm');

    maxTolerance = minutes(30);

    for i = 1:height(exercise)
        startExercise = exercise.DeviceDtTm(i);
        idx = find(wizard.DeviceDtTm <= startExercise, 1, 'last');

        if ~isempty(idx)
            CF_vector(i) = wizard.InsulinSensitivity(idx);
            CR_vector(i) = wizard.InsulinCarbRatio(idx);

            timeDiff = startExercise - wizard.DeviceDtTm(idx);
            if timeDiff <= maxTolerance
                IOB_vector(i) = wizard.InsulinOnBoard(idx);
            end
        end

        boluses_before = bolus_data.datetime_aligned(bolus_data.datetime_aligned <= startExercise);
        idx_bolus = find(bolus_data.datetime_aligned <= startExercise, 1, 'last');
        if ~isempty(boluses_before)
            tslb_vector(i) = minutes(startExercise - max(boluses_before));
            lb_vector(i) = bolus_data.bolus(idx_bolus);
        end

        basal_before = basal_data.datetime_aligned(basal_data.datetime_aligned <= startExercise);
        idx_basal = find(basal_data.datetime_aligned <= startExercise, 1, 'last');
        if ~isempty(basal_before)
            tslBasal_vector(i) = minutes(startExercise - max(basal_before));
            lBasal_vector(i) = basal_data.basal_rate(idx_basal);
        end

    end
end

%% function to compute CGM based outcomes for one subject's activity sessions

function outcomes = getOutcomes(exercise, cgm, outcomeNames)
    
    nOutcomes = length(outcomeNames);

    outcomes = NaN(height(exercise), nOutcomes);

    [t_unique, idx] = unique(cgm.datetime, 'last');
    cgm_clean = cgm(idx, :);


    for i = 1:height(exercise)
        
        startExercise = exercise.DeviceDtTm(i);
        endExercise = exercise.DeviceDtTm(i) + minutes(exercise.DurationValue(i));

        glucoseStartExercise = interp1(datenum(cgm_clean.datetime), cgm_clean.cgm, datenum(startExercise), 'linear');
        glucoseEndExercise = interp1(datenum(cgm_clean.datetime), cgm_clean.cgm, datenum(endExercise), 'linear');

        idxExercise = cgm_clean.datetime >= startExercise & cgm_clean.datetime <= endExercise;
        cgmExercise.datetime = cgm_clean.datetime(idxExercise);
        cgmExercise.cgm = cgm_clean.cgm(idxExercise);

        for j=1:nOutcomes
    
            curr_outcome = outcomeNames(j);
    
            switch curr_outcome
                case "ExcursionDuringActivity"
                    outcomes(i, j) = glucoseEndExercise - glucoseStartExercise;
                
                case "RoCDuringActivity"
                    outcomes(i, j) = (glucoseEndExercise - glucoseStartExercise) / exercise.DurationValue(i);
                
                case "HypoglycemiaEvent"
                    outcomes(i, j) = any(cgmExercise.cgm < 70);
                
                case "SevereHypoglycemiaEvent"
                    outcomes(i, j) = any(cgmExercise.cgm < 54);

            end
        end

    end

end

%%
save("exerciseTableForBN.mat", "exercise_table");