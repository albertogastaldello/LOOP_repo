clc
clear all
close all

%% add paths

addpath("processingFunctions/");
addpath("subjectsID/");
addpath("tables/");
addpath("/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31/");

base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31';
code_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo';

%% 1. getAndSaveSubjectsID.m to save the subjects ID of cgm, bolus and basal files.
 
disp('getAndSaveSubjectsID');

getAndSaveSubjectsID(base_path, code_path);

%% 2. findCommonSubjects.m to find the subjects present simultaneously 
% in roster data table, bolus, basal and cgm files. These subjects' ID 
% are saved in common_subjectsID_numeric.mat and 
% common_subjectsID_numeric.mat

disp('findCommonSubjects');

findCommonSubjects(code_path, base_path);

%% 3. adjustAndSaveDataTables.m file to load interesting data tables, 
% extract and save each subject time zone offset in 
% subjectsTimeZoneOffset.mat data, find subjects who dropped and save 
% their IDs in droppedSubjectsID.mat, change date format where needed, 
% then save for each subject the corresponding rows of each data table in 
% LOOP_data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects

disp('adjustAndSaveDataTables');

adjustAndSaveDataTables(code_path, base_path);

%% DISMISSED IT SINCE DON'T NEEDED FOR IOB ESTIMATION

% 4. alignBolusAndBasal.m to align basal and bolus datetime with the
% cgm datetime. Tables are override and can be found in 
% LOOP_data/Loop study public dataset 2023-01-31/data_type={basal/bolus/cgm}

% disp('alignBolusAndBasal');
% 
% alignBolusAndBasal(base_path);

%% 5. createDataTablesStructure.m file to create and save a unique 
% structure (dataTablesStructure.mat) that contains the data tables 
% information divided by subjects

disp('createDataTablesStructure');

createDataTablesStructure(code_path, base_path);

%% 6. addDateTime.m file to loop on each subject and apply the time zone 
% offset present in roster data to the column 'UTCDtTm' of BGM, food and 
% exercise tables. The obtained datetimes are placed in the 'DeviceDtTm' 
% column if NaN or NaT are present. Also, these three tables are sorted in 
% chronological order based on the updated 'DeviceDtTm' column. 
% The structure is saved as dataTablesStructure_withDateTime.mat.

disp('addDateTime');

addDateTime();

%% 7. createExerciseTable.m to first intersect common_subjectsID.mat with
% subjects that have wizard data. The ID of the intersected subjects are
% saved in commonWizard_subjectsID.mat. Then it creates a table for each 
% exercise session with all information.
% The table is saved as exerciseTable.mat

disp('createExerciseTable');

createExerciseTable(code_path, base_path);

%% 8. filterExerciseSessions.m to filter the exercise table removing 
% duplicates, sessions completely contained in others, sessions that 
% overlap and sessions that last less than 10 minutes. 
% Compute also the average number of sessions per week for each subject.
% The filtered exercise table is saved as exerciseTable_filtered.mat

disp('filterExerciseSessions');

stats = filterExerciseSessions();

%% 9. exerciseWithWearableData.m to load exerciseTable_filtered.mat, 
% remove exercise sessions that have few cgm 
% data, and add wearable data around each exercise session (cgm, insulin, meals).
% For meals data, before computing COB reported meals are aligned and
% possible unannounced meals are detected.
% At this step ACWR, IOB, and COB are computed and added to the table.
% The table is saved as exerciseTableWithWearableData.mat

disp('exerciseWithWearableData');

exerciseWithWearableData();

%% 10. exerciseForBN.m to load exerciseTableWithWearableData.mat, and 
% compute various  metrics useful for the developing of Bayesian Network. 
% The table is saved as exerciseTableForBN.mat

disp('exerciseForBN');

exerciseForBN();

%% 11. convert exerciseTableForBN.mat in a table usable in python

disp('exerciseForBN for Python');

exerciseForBN_python();

