function createExerciseTable(codePath)

    % load common subjects and intersect with subjects that have wizard data
    
    wizard = readtable("Data Tables/LOOPDeviceWizard.txt");
    wizardSubjID = unique(wizard.PtID);
    
    common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
    common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
    
    commonWizard_subjectsID_numeric = intersect(common_subjectsID_numeric, wizardSubjID);
    commonWizard_subjectsID = string(commonWizard_subjectsID_numeric);
    
    % save common subjects with wizard data
    
    saveFolder = fullfile(codePath, 'subjectsID');
    save(fullfile(saveFolder, "commonWizard_subjectsID.mat"), "commonWizard_subjectsID");
    save(fullfile(saveFolder, "commonWizard_subjectsID_numeric.mat"), "commonWizard_subjectsID_numeric");
    
    % load exercise data and add METs and METs/min columns
    
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
    exercise.EnergyPerMinute = zeros(size(exercise,1), 1);
    exercise.MET = zeros(size(exercise,1), 1);
    % exercise.METLevel = zeros(size(exercise,1), 1);
    exercise.MET_min = zeros(size(exercise,1), 1);
    exercise.age = zeros(size(exercise,1), 1);
    exercise.gender = zeros(size(exercise,1), 1);
    exercise.height = zeros(size(exercise,1), 1);
    exercise.weight = zeros(size(exercise,1), 1);
    exercise.HbA1c = zeros(size(exercise,1), 1);
    
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
            
            % Transform all duration in minutes 
            curr_exercise.DurationUnits = string(curr_exercise.DurationUnits);
            mask_seconds = curr_exercise.DurationUnits == "seconds";
            curr_exercise.DurationUnits(mask_seconds) = "minutes";
            curr_exercise.DurationValue(mask_seconds) = curr_exercise.DurationValue(mask_seconds)./ 60;
    
            curr_exercise.DistanceUnits = string(curr_exercise.DistanceUnits);
    
            curr_exercise.EnergyPerMinute = curr_exercise.EnergyValue ./ curr_exercise.DurationValue;
            
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
        
    
            curr_exercise = sortrows(curr_exercise, 'DeviceDtTm');
            exercise_table = [exercise_table; curr_exercise];
    
        end
    
    end

    % save
    tables_path = '/Users/albertogastaldello/Desktop/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTable.mat"), "exercise_table");

end