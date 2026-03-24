clc
clear all
close all

%%

addpath("tables/");

base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31';
exercise = load("exerciseTableForBN.mat").exerciseTableForBN;

i=1;
curr_cgmPreExercise = exercise.cgmData{i,1}.cgmPreExercise;
curr_mealData = exercise.mealData{i,1};

curr_subjID = exercise.PtID(i);

basal_data = readtable(fullfile(base_path, ['data_type=basal/patient_id=' num2str(curr_subjID)], 'basal.csv'));
bolus_data = readtable(fullfile(base_path, ['data_type=bolus/patient_id=' num2str(curr_subjID)], 'bolus.csv'));

exerciseStart = exercise.UTCDtTm(i);
preExerciseMealWindow = exerciseStart - hours(6);

idxBolusForMeals = bolus_data.datetime >= preExerciseMealWindow & ...
    bolus_data.datetime <= exerciseStart;

curr_bolusData = bolus_data(idxBolusForMeals, :);

curr_CF = exercise.insulinData{i,1}.InsSensitivity;
curr_CR = exercise.insulinData{i,1}.InsCarbRatio;


%%
inferred_meals = detectMissingMeals(curr_cgmPreExercise, curr_mealData, ...
    curr_bolusData, curr_CF, curr_CR);
