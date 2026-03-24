function findCommonSubjects(code_path, base_path)

    % find subjects ID in common with all data and save them
    
    roster = readtable(fullfile(base_path, 'Data Tables', 'PtRoster.txt'));
    surveys = readtable(fullfile(base_path, 'Data Tables', 'Surveys.txt'));
    sampleResults = readtable(fullfile(base_path, 'Data Tables', 'SampleResults.txt'));
    
    rosterSubjID = roster.PtID;
    rosterCompleted = roster(strcmp(roster.PtStatus, 'Completed'),:);
    rosterCompletedSubjID = rosterCompleted.PtID;
    
    surveysID = unique(surveys.SubjectID);
    sampleResultsSubjID = unique(sampleResults.PtID);

    cgmSubjID = load("cgm_subjectsID_numeric.mat").cgm_subjectsID_numeric;
    basalSubjID = load("basal_subjectsID_numeric.mat").basal_subjectsID_numeric;
    bolusSubjID = load("bolus_subjectsID_numeric.mat").bolus_subjectsID_numeric;
    
    common_subjectsID_numeric = intersect(intersect(intersect(intersect(rosterCompletedSubjID, cgmSubjID), basalSubjID), sampleResultsSubjID), surveysID);
    common_subjectsID = string(common_subjectsID_numeric);

    saveFolder = fullfile(code_path, 'subjectsID');
    
    save(fullfile(saveFolder,"common_subjectsID_numeric.mat"), "common_subjectsID_numeric");
    save(fullfile(saveFolder,"common_subjectsID.mat"), "common_subjectsID");

end