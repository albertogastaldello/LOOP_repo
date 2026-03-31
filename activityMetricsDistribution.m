clc
clear all
close all

%% 

addpath("tables/");

exerciseTableForBN = load("exerciseTableForBN.mat").exerciseTableForBN;

%%

figure()
subplot(3,1,1)
histogram(exerciseTableForBN.AOB);
title('AOB distirbution')
subplot(3,1,2)
histogram(exerciseTableForBN.CWL);
title('CWL distribution')
subplot(3,1,3)
histogram(exerciseTableForBN.ACWR);
title('ACWR distribution')

figure()
histogram(exerciseTableForBN.MET)

figure()
histogram(exerciseTableForBN.ACWR)

%%
%Export to CSV
writetable(exerciseTableForBN(:, {'AOB', 'CWL', 'ACWR'}), 'workload_data.csv');