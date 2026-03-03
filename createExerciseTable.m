clc
clear all
close all

%% load common subjects and intersect with subjects that have wizard data

wizard = readtable("Data Tables/LOOPDeviceWizard.txt");
wizardSubjID = unique(wizard.PtID);

common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;

commonWizard_subjectsID_numeric = intersect(common_subjectsID_numeric, wizardSubjID);
commonWizard_subjectsID = string(commonWizard_subjectsID_numeric);

%% save common subjects with wizard data
% 
% save("commonWizard_subjectsID.mat", "commonWizard_subjectsID");
% save("commonWizard_subjectsID_numeric.mat", "commonWizard_subjectsID_numeric");

%% load exercise data and add METs and METs/min columns

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';

exercise = readtable("Data Tables/LOOPDeviceExercise.txt");
subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;

exercise = exercise(ismember(exercise.PtID, commonWizard_subjectsID_numeric), :);

colsToRemove = ["RecID", "ParentLOOPDeviceUploadsID", "ReportedIntensity",...
    "OriginName", "OriginVers", "OriginType", "OriginDeviceFirmwrVer",...
    "OriginDeviceHardwrVer", "OriginDeviceManufact", "OriginDeviceModel", ...
    "OriginOperatingSystVer", "OriginProductType"];
exercise(:, colsToRemove) = [];

exercise.DeviceDtTm = NaT(height(exercise),1);
exercise.DurationUnits = string(exercise.DurationUnits);

% Change name of activities to group them

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


% Initialize columns for METs and subject characteristics
exercise.MET = zeros(size(exercise,1), 1);
% exercise.METLevel = zeros(size(exercise,1), 1);
exercise.MET_min = zeros(size(exercise,1), 1);
exercise.age = zeros(size(exercise,1), 1);
exercise.gender = zeros(size(exercise,1), 1);
exercise.height = zeros(size(exercise,1), 1);
exercise.weight = zeros(size(exercise,1), 1);
exercise.HbA1c = zeros(size(exercise,1), 1);
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

% Iterate for each subject
for i=1:length(commonWizard_subjectsID_numeric)

    curr_subjID = commonWizard_subjectsID_numeric(i);
    struct_patientField = ['patient_' num2str(curr_subjID)];
    curr_exercise = subjectsStruct.(struct_patientField).exercise;
    
    % remove not valid activities
    curr_exercise.ExerciseName = string(curr_exercise.ExerciseName);
    curr_exercise(ismissing(curr_exercise.ExerciseName), :) = [];

    if(~isempty(curr_exercise))
    
        cgm_path = strcat(base_path, '/data_type=cgm/patient_id=', num2str(curr_subjID), '/cgm.csv');
        cgm_data = readtable(cgm_path);

        basal_path = strcat(base_path, '/data_type=basal/patient_id=', num2str(curr_subjID), '/basal.csv');
        basal_data = readtable(basal_path);
    
        bolus_path = strcat(base_path, '/data_type=bolus/patient_id=', num2str(curr_subjID), '/bolus.csv');
        bolus_data = readtable(bolus_path);
        
        % load current exercise structure and process it
    
        
        % remove useless columns
        curr_exercise(:, colsToRemove) = [];
        % add a column with clean activiy names
        raw_activities = curr_exercise.ExerciseName;
        clean_activities = cell(size(raw_activities));
        for k = 1:length(raw_activities)
            str = raw_activities{k};
            pos = strfind(str, ' - ');
            if ~isempty(pos)
                clean_activities{k} = strtrim(str(1:pos-1));
            else
                clean_activities{k} = str;
            end
        end
        curr_exercise.CleanActivityName = clean_activities;
    
        n_exercises = height(curr_exercise);
    
        % Use the TimeZoneOffset present in roster data
        % curr_exercise.DeviceDtTm = curr_exercise.UTCDtTm + hours(subjectsStruct.(struct_patientField).roster.PtTimezoneOffset(1));
        
        % Transform all duration in minutes 
        curr_exercise.DurationUnits = string(curr_exercise.DurationUnits);
        mask_seconds = curr_exercise.DurationUnits == "seconds";
        curr_exercise.DurationUnits(mask_seconds) = "minutes";
        curr_exercise.DurationValue(mask_seconds) = curr_exercise.DurationValue(mask_seconds)./ 60;

        curr_exercise.DistanceUnits = string(curr_exercise.DistanceUnits);
        
        % Compute and add METs and MEts_min
        curr_weight = subjectsStruct.(struct_patientField).surveys.weight_kg(1);
        curr_exercise.MET = curr_exercise.EnergyValue ./ (curr_weight * (curr_exercise.DurationValue ./ 60));
        % if(curr_exercise.MET < 3)
        %     curr_exercise.METLevel = 0;
        % else
        %     if(curr_exercise.MET < 6)
        %         curr_exercise.METLevel = 1;
        %     else
        %         curr_exercise.METLevel = 2;
        %     end
        % end
        curr_exercise.MET_min = curr_exercise.MET .* curr_exercise.DurationValue;
    
    
        % Add fixed subject characteristics
        curr_exercise.age = repmat(subjectsStruct.(struct_patientField).surveys.ageAtBaseline(1), n_exercises, 1);
        curr_exercise.gender = repmat(subjectsStruct.(struct_patientField).surveys.gender(1), n_exercises, 1); 
        curr_exercise.height = repmat(subjectsStruct.(struct_patientField).surveys.height_cm(1), n_exercises, 1);
        curr_exercise.weight = repmat(curr_weight, n_exercises, 1);
        curr_exercise.HbA1c = repmat(subjectsStruct.(struct_patientField).sampleResults.Value(1), n_exercises, 1);
    
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

end

%%

n_activities = size(activityCountTable,1);
activitiesNameForStruct = regexprep(activityCountTable.Activity, '\s+', '');

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


%% save

save("exerciseTable.mat", "exercise_table");