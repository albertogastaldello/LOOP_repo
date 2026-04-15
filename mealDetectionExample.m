clc
clear all
close all

%%

addpath("tables/");

base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31';
exercise = load("exerciseTableForBN.mat").exerciseTableForBN;

i = randi(size(exercise,1));

curr_cgmPreExercise = exercise.cgmData{i,1}.cgmPreExercise;
curr_cgmExercise = exercise.cgmData{i,1}.cgmExercise;
curr_cgmPostExercise = exercise.cgmData{i,1}.cgmPostExercise;
curr_cgmData = vertcat(curr_cgmPreExercise, curr_cgmExercise, curr_cgmPostExercise);

curr_reportedMeal = exercise.reportedMealData{i,1};
curr_finalMeal = exercise.finalMealData{i,1};

exerciseStart = exercise.UTCDtTm(i);
exerciseDuration = exercise.DurationValue(i);
exerciseEnd = exerciseStart + minutes(exerciseDuration);


%%

figure()
subplot(2,1,1);
yyaxis left
plot(curr_cgmData.Time, curr_cgmData.Glucose)
ylabel('Glucose concentration (mg/dl)')
hold on
yyaxis right
stem(curr_reportedMeal.UTCDtTm, curr_reportedMeal.CarbsNet, 'b')
ylabel('Carbohydrates (g)')
xlabel('Time')
xl1 = xline(exerciseStart, 'LineWidth', 2);
xl2 = xline(exerciseEnd, 'LineWidth', 2);
xl1.DisplayName = 'Exercise';
xl2.Annotation.LegendInformation.IconDisplayStyle = 'off';  


legend(xl1, {'Exercise'});

subplot(2,1,2);
yyaxis left
plot(curr_cgmData.Time, curr_cgmData.Glucose)
ylabel('Glucose concentration (mg/dl)')
hold on
yyaxis right
stem(curr_finalMeal.UTCDtTm, curr_finalMeal.CarbsNet, 'r')
ylabel('Carbohydrates (g)')
xlabel('Time')

xl1 = xline(exerciseStart, 'LineWidth', 2);
xl2 = xline(exerciseEnd, 'LineWidth', 2);
xl1.DisplayName = 'Exercise';
xl2.Annotation.LegendInformation.IconDisplayStyle = 'off';   

legend(xl1, {'Exercise'});

ax = findall(gcf,'type','axes');
linkaxes(ax,'xy')
