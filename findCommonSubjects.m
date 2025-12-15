clc
clear all
close all

%% find subjects ID in common with all data and save them

roster = readtable("Data Tables/PtRoster.txt");

rosterSubjID = roster.PtID;
cgmSubjID = load("cgm_subjectsID_numeric.mat").cgm_subjectsID_numeric;
basalSubjID = load("basal_subjectsID_numeric.mat").basal_subjectsID_numeric;
bolusSubjID = load("bolus_subjectsID_numeric.mat").bolus_subjectsID_numeric;

common_subjectsID_numeric = intersect(intersect(intersect(rosterSubjID, cgmSubjID), basalSubjID), bolusSubjID);
common_subjectsID = string(common_subjectsID_numeric);

save("common_subjectsID_numeric.mat", "common_subjectsID_numeric");
save("common_subjectsID.mat", "common_subjectsID");

