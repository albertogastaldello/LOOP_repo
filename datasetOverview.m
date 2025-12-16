clc
clear all
close all

%% load useful data tables and select only common subjects

common_subjectsID_numeric = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;

roster = readtable("Data Tables/PtRoster.txt");
roster = roster(ismember(roster.PtID, common_subjectsID_numeric),:);

surveys = readtable("Data Tables/Surveys.txt");
surveys = surveys(ismember(surveys.SubjectID, common_subjectsID_numeric),:);

subjSurveys = unique(surveys.SubjectID);