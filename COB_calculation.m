    function my_COB = COB_calculation(meal,meal_type,T_samp)
% 
% Takes a meal signal, containing the amount of carbs ingested over time, and calculates Carbohydrates On Board (COB) over time
%
% meal.values: amount of meals ingested [g/min]
% meal_type: {'fast','slow','custom'}
%

%% %%% If you want to have a look at the dynamics decomment this

%% Convolution of meal signal with
switch meal_type
    % Loaded data:
    % COB(:,1) fast absorption carbs [ (% on board) / (min since meal)]
    % COB(:,2) slow absorption carbs [ (% on board) / (min since meal)]
    % First column refers to quick absorption, second to slow absorption.
    % Bioavailability of carbs in a meal is equal to 90% of the total amount,
    % remaining 10% is absorved by the liver and does not appear in plasma.
    
    case 'fast'
        load('COB.mat')
        fast_meals_curve = COB(:,1);
        fast_meals_curve = fast_meals_curve(1:T_samp:end);
        my_absorption_curve = fast_meals_curve;
    case 'slow'
        load('COB.mat')
        slow_meals_curve = COB(:,2);
        slow_meals_curve = slow_meals_curve(1:T_samp:end);
        my_absorption_curve = slow_meals_curve;
end

my_COB=conv(meal,my_absorption_curve);
% my_COB=conv(meal*T_samp,my_absorption_curve);
my_COB=my_COB(1:length(meal));

% figure
% hold on
% plot([1:length(fast_meals_curve)]*5,fast_meals_curve)
% plot([1:length(slow_meals_curve)]*5,slow_meals_curve)
% plot([1:length(custom_meals_curve)]*5,custom_meals_curve)
% legend('fast','slow','custom')
% %%%%%%%%%%%%%%%%%%%%%%%%

end