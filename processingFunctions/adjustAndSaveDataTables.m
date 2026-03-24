function adjustAndSaveDataTables(code_path, base_path)

    % open Data Tables
    
    adverseEvents  = readtable(fullfile(base_path, 'Data Tables', 'adverseEvents.txt'));
    deviceIssues   = readtable(fullfile(base_path, 'Data Tables', 'deviceIssues.txt'));
    gluIndices     = readtable(fullfile(base_path, 'Data Tables', 'gluIndices.txt'));
    BGM            = readtable(fullfile(base_path, 'Data Tables', 'LOOPDeviceBGM.txt'));
    exercise       = readtable(fullfile(base_path, 'Data Tables', 'LOOPDeviceExercise.txt'));
    food           = readtable(fullfile(base_path, 'Data Tables', 'LOOPDeviceFood.txt'));
    deviceIssueRpt = readtable(fullfile(base_path, 'Data Tables', 'LOOPDeviceIssueRpt.txt'));
    wizard         = readtable(fullfile(base_path, 'Data Tables', 'LOOPDeviceWizard.txt'));
    finalStatus    = readtable(fullfile(base_path, 'Data Tables', 'LOOPPtFinalStatus.txt'));
    roster         = readtable(fullfile(base_path, 'Data Tables', 'PtRoster.txt'));
    sampleResults  = readtable(fullfile(base_path, 'Data Tables', 'SampleResults.txt'));
    surveys        = readtable(fullfile(base_path, 'Data Tables', 'Surveys.txt'));
    
    % extract and save time zone offset of each subject
    
    timeZoneOffset = roster(:, {'PtID', 'PtTimezoneOffset'});
    timeZoneOffset = sortrows(timeZoneOffset, 'PtID');
    save("subjectsTimeZoneOffset.mat", "timeZoneOffset");
    
    % 'dropped' subjects
    
    dropped_subjectsID = roster(strcmp(roster.PtStatus, 'Dropped'),1);
    saveFolder = fullfile(code_path, 'subjectsID');
    save(fullfile(saveFolder,"droppedSubjectsID.mat"), "dropped_subjectsID");
    
    
    % adjust data where needed
    
    % Change date format of eventDt field of adverseEvents
    adverseEvents.eventDt = datetime(adverseEvents.eventDt, 'InputFormat', 'ddMMMyyyy');
    deviceIssues.date = datetime(deviceIssues.date, 'InputFormat', 'ddMMMyyyy');
    
    % Add column for height in cm and weight in kg 
    surveys.height_cm = (surveys.height_feet.*12 + surveys.height_inches)*2.54;
    surveys.weight_kg = surveys.weight.*0.453592;
    
    
    % for each subject, select its data and save them in a dedicated folder
    
    common_subjectsID = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
    n_common_subjects = length(common_subjectsID);
    
    base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects';
    
    dataTables = {
        "adverseEvents",   "subjectID";
        "deviceIssues",    "subjectID";
        "gluIndices",      "SubjectID";
        "BGM",             "PtID";
        "exercise",        "PtID";
        "food",            "PtID";
        "deviceIssueRpt",  "PtID";
        "wizard",          "PtID";
        "finalStatus",     "PtID";
        "roster",          "PtID";
        "sampleResults",   "PtID";
        "surveys",         "SubjectID"
    };
    
    for i=1:n_common_subjects
    
        curr_subjID = common_subjectsID(i);
    
        % create the folder if it does not exist
        output_folder = fullfile(base_path, "patient_id=" + num2str(curr_subjID));
        
        if ~exist(output_folder, 'dir')
            mkdir(output_folder);
        end
    
        % Loop over each data table
    
        for j = 1:size(dataTables,1)
            
            data_name = dataTables{j,1};
            id_field  = dataTables{j,2};
    
            data_table = eval(data_name);
    
            % Filter rows for the subject
            rows = data_table.(id_field) == curr_subjID;
            curr_table = data_table(rows,:);
    
            % Build output filename
            filename = fullfile(output_folder, data_name + ".csv");
    
            % Save
            writetable(curr_table, filename)
        end
    
    end

end
