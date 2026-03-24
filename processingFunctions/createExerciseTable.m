function createExerciseTable(code_path, base_path)

    % load subjects structure (already has processed datetimes)
    subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
    % subjectsID = fieldnames(subjectsStruct);

    % load common subjects and intersect with subjects that have wizard data
    wizard = readtable(fullfile(base_path, 'Data Tables', 'LOOPDeviceWizard.txt'));
    wizardSubjID = unique(wizard.PtID);

    common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
    common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
    
    commonWizard_subjectsID_numeric = intersect(common_subjectsID_numeric, wizardSubjID);
    commonWizard_subjectsID = string(commonWizard_subjectsID_numeric);
    
    % save common subjects with wizard data
    saveFolder = fullfile(code_path, 'subjectsID');
    save(fullfile(saveFolder, "commonWizard_subjectsID.mat"), "commonWizard_subjectsID");
    save(fullfile(saveFolder, "commonWizard_subjectsID_numeric.mat"), "commonWizard_subjectsID_numeric");
    
    colsToRemove = ["RecID", "ParentLOOPDeviceUploadsID", "ReportedIntensity",...
        "OriginName", "OriginVers", "OriginType", "OriginDeviceFirmwrVer",...
        "OriginDeviceHardwrVer", "OriginDeviceManufact", "OriginDeviceModel", ...
        "OriginOperatingSystVer", "OriginProductType"];
    
    exercise_table = table();

    subjectsID = commonWizard_subjectsID_numeric;
    
    % Iterate for each subject in your cleaned struct
    for i=1:length(subjectsID)
    
        curr_subjID = subjectsID(i);
        struct_patientField = ['patient_' num2str(curr_subjID)];
        
        % Skip if the subject doesn't have an exercise table
        if ~isfield(subjectsStruct.(struct_patientField), 'exercise') || ...
           isempty(subjectsStruct.(struct_patientField).exercise)
            continue;
        end
        
        curr_exercise = subjectsStruct.(struct_patientField).exercise;
        
        % remove not valid activities
        curr_exercise.ExerciseName = string(curr_exercise.ExerciseName);
        curr_exercise(ismissing(curr_exercise.ExerciseName), :) = [];
    
        if ~isempty(curr_exercise)
             
            % remove useless columns (suppress warning if some columns are already missing)
            colsToDrop = intersect(colsToRemove, curr_exercise.Properties.VariableNames);
            curr_exercise(:, colsToDrop) = [];
            
            % add a column with clean activiy names (String array approach is faster)
            raw_activities = curr_exercise.ExerciseName;
            clean_activities = strings(size(raw_activities));
            for k = 1:length(raw_activities)
                str = raw_activities(k);
                pos = strfind(str, ' - ');
                if ~isempty(pos)
                    clean_activities(k) = strtrim(extractBefore(str, pos));
                else
                    clean_activities(k) = str;
                end
            end
            curr_exercise.CleanActivityName = clean_activities;
        
            n_exercises = height(curr_exercise);
            
            % Transform all duration to minutes 
            curr_exercise.DurationUnits = string(curr_exercise.DurationUnits);
            mask_seconds = curr_exercise.DurationUnits == "seconds";
            curr_exercise.DurationUnits(mask_seconds) = "minutes";
            curr_exercise.DurationValue(mask_seconds) = curr_exercise.DurationValue(mask_seconds) ./ 60;
    
            curr_exercise.DistanceUnits = string(curr_exercise.DistanceUnits);
    
            % Compute Base Energy and Active METs
            curr_exercise.EnergyPerMinute = curr_exercise.EnergyValue ./ curr_exercise.DurationValue;
            curr_weight = subjectsStruct.(struct_patientField).surveys.weight_kg(1);
            
            % (Assuming EnergyValue is Active Calories based on HealthKit)
            curr_exercise.MET = curr_exercise.EnergyValue ./ (curr_weight * (curr_exercise.DurationValue ./ 60));
            curr_exercise.MET_min = curr_exercise.MET .* curr_exercise.DurationValue;
        
            % --- DEMOGRAPHICS & LABS ---
            curr_exercise.age = repmat(subjectsStruct.(struct_patientField).surveys.ageAtBaseline(1), n_exercises, 1);
            curr_exercise.gender = repmat(subjectsStruct.(struct_patientField).surveys.gender(1), n_exercises, 1); 
            curr_exercise.height = repmat(subjectsStruct.(struct_patientField).surveys.height_cm(1), n_exercises, 1);
            curr_exercise.weight = repmat(curr_weight, n_exercises, 1);
            
            % HbA1c Safety Net: Try Lab Data first, fallback to Survey Data
            if isfield(subjectsStruct.(struct_patientField), 'sampleResults') && ...
               height(subjectsStruct.(struct_patientField).sampleResults) > 0
                hba1c_val = subjectsStruct.(struct_patientField).sampleResults.Value(1);
            else
                % Fallback to self-reported survey data
                hba1c_val = subjectsStruct.(struct_patientField).surveys.hba1c_level(1);
            end
            curr_exercise.HbA1c = repmat(hba1c_val, n_exercises, 1);
        
            % FIX: Sort by UTC to prevent causality violations
            curr_exercise = sortrows(curr_exercise, 'UTCDtTm');
            
            % Append to main table
            exercise_table = [exercise_table; curr_exercise];
        end
    end
    
    % save
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTable.mat"), "exercise_table");
    disp('Exercise Table successfully generated!');
end