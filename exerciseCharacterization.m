clc; clear; close all;

%% ================= LOAD & PREPROCESS =================

% Load and extract the table
data = load("exerciseTable.mat");
exercise = data.exercise_table;

% Clean missing names and calculate Energy Per Minute
exercise = exercise(~ismissing(exercise.CleanActivityName), :);
exercise.EnergyPerMinute = exercise.EnergyValue ./ exercise.DurationValue;

%% ================= SUMMARY STATISTICS =================
% We use custom function handles and then rename them immediately 
% to avoid the "fun1/fun2" ambiguity.
stats = groupsummary(exercise, "CleanActivityName", ...
    {@nanmean, @nanmedian, @nanstd, @(x)prctile(x,25), @(x)prctile(x,75)}, ...
    ["EnergyPerMinute", "MET", "MET_min", "RoCDuringActivity", "DurationValue"]);

% Get activity counts separately and join them to the main stats table
counts = groupsummary(exercise, "CleanActivityName");
stats = join(stats, counts(:, ["CleanActivityName", "GroupCount"]));

% Define translation keys
oldPrefixes = {'fun1_', 'fun2_', 'fun3_', 'fun4_', 'fun5_'};
newPrefixes = {'mean_', 'med_', 'sd_', 'q1_', 'q3_'};

oldMetrics  = {'EnergyPerMinute', 'RoCDuringActivity', 'DurationValue'};
newMetrics  = {'EPM', 'Roc', 'Dur'};

% Apply the translations to the entire VariableNames array
tempNames = stats.Properties.VariableNames(1, 3:end);
tempNames = replace(tempNames, oldPrefixes, newPrefixes);
tempNames = replace(tempNames, oldMetrics, newMetrics);

% 3. Assign back to the table
stats.Properties.VariableNames(1, 3:end) = tempNames;

%% ================= BOXPLOTS =================
sortedBoxplot(stats.med_EPM, 'EnergyPerMinute', stats, exercise)
sortedBoxplot(stats.med_MET, 'MET', stats, exercise)
sortedBoxplot(stats.med_Roc, 'RoCDuringActivity', stats, exercise)

%% ================= SCATTER PLOTS =================
% Simple Scatter
activityMetricScatter(stats.med_Dur, 'Duration', stats.med_EPM, 'EnergyPerMinute', stats)

% Mean + SD Scatter
activityMeanSDScatter(stats.mean_Dur, stats.sd_Dur, 'Duration', ...
                      stats.mean_EPM, stats.sd_EPM, 'EnergyPerMinute', stats)

% Median + IQR Scatter
activityMedianIQRScatter(stats.med_Dur, stats.q1_Dur, stats.q3_Dur, 'Duration', ...
                         stats.med_EPM, stats.q1_EPM, stats.q3_EPM, 'EnergyPerMinute', ...
                         stats)

% MET vs Glucose RoC
activityMedianIQRScatter(stats.med_MET, stats.q1_MET, stats.q3_MET, 'MET', ...
                         stats.med_Roc, stats.q1_Roc, stats.q3_Roc, 'Glucose RoC', ...
                         stats)

%% ================= FUNCTIONS =========================

function sortedBoxplot(medians, metric, statsTable, exercise)
    [~, idx] = sort(medians, 'ascend');
    sortedNames = statsTable.CleanActivityName(idx);
    
    figure('Color', 'w', 'Name', metric);
    set(gcf, 'Position', [100 100 850 950]);
    
    boxplot(exercise.(metric), exercise.CleanActivityName, ...
        'Orientation', 'horizontal', ...
        'GroupOrder', sortedNames, ...
        'Symbol', 'r.', 'OutlierSize', 4);
    
    xlabel(metric, 'FontWeight', 'bold');
    ylabel('Activity Type', 'FontWeight', 'bold');
    title(['Distribution of ', metric]);
    grid on;
    set(gca, 'TickLabelInterpreter', 'none');
end

% ------------------------------------------------------------

function activityMetricScatter(x, xName, y, yName, statsTable)
    names = statsTable.CleanActivityName;
    n = numel(names);
    
    figure('Color', 'w', 'Name', [xName ' vs ' yName]);
    set(gcf, 'Position', [100 100 850 650]);
    hold on; grid on;
    
    colors = lines(n);
    for i = 1:n
        scatter(x(i), y(i), 90, colors(i,:), 'filled', 'DisplayName', char(names(i)));
    end
    
    xlabel(xName, 'FontWeight', 'bold');
    ylabel(yName, 'FontWeight', 'bold');
    legend('Location', 'eastoutside', 'FontSize', 8);
end

% ------------------------------------------------------------

function activityMeanSDScatter(xm, xsd, xName, ym, ysd, yName, statsTable)
    names = statsTable.CleanActivityName;
    n = numel(names);
    
    figure('Color', 'w', 'Name', [xName ' vs ' yName ' (Mean ± SD)']);
    set(gcf, 'Position', [100 100 850 650]);
    hold on; grid on;
    
    colors = lines(n);
    for i = 1:n
        % Error bars (manual)
        plot([xm(i)-xsd(i) xm(i)+xsd(i)], [ym(i) ym(i)], 'Color', colors(i,:), 'LineWidth', 1);
        plot([xm(i) xm(i)], [ym(i)-ysd(i) ym(i)+ysd(i)], 'Color', colors(i,:), 'LineWidth', 1);
        scatter(xm(i), ym(i), 80, colors(i,:), 'filled');
    end
    
    xlabel(xName, 'FontWeight', 'bold');
    ylabel(yName, 'FontWeight', 'bold');
    legend(cellstr(names), 'Location', 'eastoutside', 'FontSize', 8);
end

% ------------------------------------------------------------

function activityMedianIQRScatter(xm, q1x, q3x, xName, ym, q1y, q3y, yName, statsTable)
    names = statsTable.CleanActivityName;
    n = numel(names);
    
    figure('Color', 'w', 'Name', [xName ' vs ' yName ' (Median + IQR)']);
    set(gcf, 'Position', [100 100 850 650]);
    hold on; grid on;
    
    colors = lines(n);
    for i = 1:n
        % IQR X range
        plot([q1x(i) q3x(i)], [ym(i) ym(i)], 'Color', colors(i,:), 'LineWidth', 1.5);
        % IQR Y range
        plot([xm(i) xm(i)], [q1y(i) q3y(i)], 'Color', colors(i,:), 'LineWidth', 1.5);
        scatter(xm(i), ym(i), 80, colors(i,:), 'filled');
    end
    
    xlabel(xName, 'FontWeight', 'bold');
    ylabel(yName, 'FontWeight', 'bold');
    legend(cellstr(names), 'Location', 'eastoutside', 'FontSize', 8);
end