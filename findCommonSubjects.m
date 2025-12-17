clc
clear all
close all

%% find subjects ID in common with all data and save them

roster = readtable("Data Tables/PtRoster.txt");
surveys = readtable("Data Tables/Surveys.txt");
sampleResults = readtable("Data Tables/SampleResults.txt");

rosterSubjID = roster.PtID;
rosterCompleted = roster(strcmp(roster.PtStatus, 'Completed'),:);
rosterCompletedSubjID = rosterCompleted.PtID;

surveysID = unique(surveys.SubjectID);
cgmSubjID = load("cgm_subjectsID_numeric.mat").cgm_subjectsID_numeric;
basalSubjID = load("basal_subjectsID_numeric.mat").basal_subjectsID_numeric;
bolusSubjID = load("bolus_subjectsID_numeric.mat").bolus_subjectsID_numeric;
sampleResultsSubjID = unique(sampleResults.PtID);

common_subjectsID_numeric = intersect(intersect(intersect(intersect(rosterCompletedSubjID, cgmSubjID), basalSubjID), sampleResultsSubjID), surveysID);
common_subjectsID = string(common_subjectsID_numeric);

save("common_subjectsID_numeric.mat", "common_subjectsID_numeric");
save("common_subjectsID.mat", "common_subjectsID");