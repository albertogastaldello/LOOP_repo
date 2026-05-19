clc
clear all
close all

%% add paths

addpath("auxiliaryFunctions/");
addpath("tables/");

%% create and visualize heatmap for few cgm data filtering

heatmapFewCgmData();

%% datasetOverview.m: load subjects of interests 
% (all subjects, common_subjects or commonWizard_subjects) 
% and get an overview of demographics and other general information

datasetOverview();

%% exerciseCharacterization.m: load exerciseTableForBN.mat and evaluates 
% the distribution of activity per activity type, per subject and combined.
% Also, it evaluates and visualizes the distribution of some parameters 
% (glucose RoC, METs, duration,...) among the different type of activities.

exerciseCharacterization();

%% groupSimilarExercise.m: to group activities based on name 
% or some metrics(to be developed)

groupSimilarExercise();

%% insulinDataAnalysis.m: evaluate and visualize IOB availability across 
% exercise sessions for exerciseTableForBN.mat.
% load dataTablesStructure_withDateTime and bolus + basal data and 
% evaluates and visualizes insulin-carb correlation and 
% insulin table data with wizard data

insulinDataAnalysis();

%% visualizeData.m: choose a subject and plot CGM with meals, exercise, and
% bolus + basal

visualizeData();

%%  visualizeExerciseSession.m to visualize one random exercise session
% from the "exerciseTableWithWearableData.mat" structure. In particular,
% visualize CGM data around the session, with start time and end time,
% reported meals, and other info in the figure title

visualizeExerciseSession();