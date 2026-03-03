clc
clear all
close all

%% load exercise table

exercise = load("exerciseTable.mat").exercise;

%% one feature vs one outcome

%feature = "EnergyValue";
%feature = "MET";
feature = "MET_min";
%feature = "DurationValue";

outcome = "RoCDuringActivity";
%outcome = "SevereHypoglycemiaEvent";
%outcome = "ExcursionDuringActivity";


figure()
scatter(exercise.(feature), exercise.(outcome))
xlabel(feature)
ylabel(outcome)
title([outcome ' vs ' feature])

