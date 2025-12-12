clc
clear all
close all

%% open Data Tables

adverseEvents = readtable("Data Tables/adverseEvents.txt");
deviceIssues = readtable("Data Tables/deviceIssues.txt");
gluIndices = readtable("Data Tables/gluIndices.txt");
BGM = readtable("Data Tables/LOOPDeviceBGM.txt");
exercise = readtable("Data Tables/LOOPDeviceExercise.txt");
food = readtable("Data Tables/LOOPDeviceFood.txt");
deviceIssueRpt = readtable("Data Tables/LOOPDeviceIssueRpt.txt");
wizard = readtable("Data Tables/LOOPDeviceWizard.txt");
finalStatus = readtable("Data Tables/LOOPPtFinalStatus.txt");
roster = readtable("Data Tables/PtRoster.txt");
sampleResults = readtable("Data Tables/SampleResults.txt");
surveys = readtable("Data Tables/Surveys.txt");

%% extract and save time zone offset of each subject

timeZoneOffset = roster(:, {'PtID', 'PtTimezoneOffset'});
timeZoneOffset = sortrows(timeZoneOffset, 'PtID');
save("subjectsTimeZoneOffset.mat", "timeZoneOffset");

%% 'dropped' subjects

dropped_subjectsID = roster(strcmp(roster.PtStatus, 'Dropped'),1);
save("droppedSubjectsID.mat", "dropped_subjectsID");


%% adjust data where needed

% Change date format of eventDt field of adverseEvents
adverseEvents.eventDt = datetime(adverseEvents.eventDt, 'InputFormat', 'ddMMMyyyy');
deviceIssues.date = datetime(deviceIssues.date, 'InputFormat', 'ddMMMyyyy');


%% for each subject, select its data and save them in a dedicated folder

common_subjectsID = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
n_common_subjects = length(common_subjectsID);

base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects';

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
