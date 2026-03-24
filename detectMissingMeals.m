function inferred_meals = detectMissingMeals(cgm_data, reported_meals, bolus_data, CF, CR)
   
    % Initialize empty table
    inferred_meals = table('Size', [0 2], 'VariableTypes', {'datetime', 'double'}, ...
                           'VariableNames', {'UTCDtTm', 'CarbsNet'});
                       
    if height(cgm_data) < 15
        return;
    end
    
    % --- 1. CARB RATIO CONSTANTS ---
    if ~isnan(CR) && ~isnan(CF) && CF > 0
        conversion_ratio = CR / CF;
        current_CR = CR;
    else
        conversion_ratio = 0.28; % The 500/1800 clinical constant
        current_CR = 12;         % Fallback: 1 Unit covers 12g
    end

    % --- 2. ORPHAN BOLUS DETECTION ---
    % Find manual boluses (> 0.5U) that the patient took, but forgot to log the food for
    if ~isempty(bolus_data)
        for b = 1:height(bolus_data)
            b_time = bolus_data.datetime(b);
            b_amt = bolus_data.bolus(b);
            
            if b_amt >= 0.5 % Ignore tiny correction micro-boluses
                % Is there a reported meal within 60 mins of this bolus?
                if isempty(reported_meals) || ~any(abs(minutes(reported_meals.UTCDtTm - b_time)) <= 60)
                    % It's an orphan bolus! Reverse engineer the carbs.
                    est_carbs = b_amt * current_CR;
                    est_carbs = max(10, min(est_carbs, 150)); % bounds
                    
                    inferred_meals = [inferred_meals; {b_time, est_carbs}]; %#ok<AGROW>
                end
            end
        end
    end

    % --- 3. CGM SAVITZKY-GOLAY MU DETECTION ---
    % Use Savitzky-Golay filtering (polynomial order 3, frame 13)
    % Fallback to movmean if Signal Processing Toolbox is missing
    cgm_vals = cgm_data.Glucose;% --- 3. CGM SAVITZKY-GOLAY MU DETECTION ---
    
    if exist('sgolayfilt', 'file')
        % Smooth the CGM data first
        smoothed_cgm = sgolayfilt(cgm_vals, 3, 13);
        
        % Calculate 1st derivative (speed) and convert to mg/dL/min
        g_prime = gradient(smoothed_cgm) / 5; 
        g_prime = max(0, g_prime); % Clip negative values to zero
        
        % Smooth the speed, then calculate 2nd derivative (acceleration)
        smoothed_g_prime = sgolayfilt(g_prime, 3, 13);
        g_2prime = gradient(smoothed_g_prime) / 5;
        g_2prime = max(0, g_2prime); % Clip negative values to zero
    else
        % Fallback if Signal Processing Toolbox is missing
        smoothed_cgm = movmean(cgm_vals, 3);
        g_prime = max(0, gradient(smoothed_cgm) / 5);
        smoothed_g_prime = movmean(g_prime, 3);
        g_2prime = max(0, gradient(smoothed_g_prime) / 5);
    end
    
    mu = g_prime .* g_2prime;
    
    % Find peaks in the mu signal (The physiological onset of a meal)
    threshold = 0.005; % Tuning parameter for mu peak height
    
    for i = 2:(length(mu)-1)
        % Very basic peak finder (higher than neighbors and threshold)
        if mu(i) > threshold && mu(i) > mu(i-1) && mu(i) > mu(i+1)
            meal_start_idx = i;
            
            % Walk forward to find the peak of the actual glucose excursion
            peak_idx = meal_start_idx;
            while peak_idx < length(cgm_vals) && cgm_vals(peak_idx+1) >= cgm_vals(peak_idx)
                peak_idx = peak_idx + 1;
            end
            
            delta_G = cgm_vals(peak_idx) - cgm_vals(meal_start_idx);
            base_G = cgm_vals(meal_start_idx);
            
            % If it's a massive rise (e.g., > 35 mg/dL)
            if delta_G > 35
                if base_G < 85
                    % HYPO RESCUE: Patient was low, ate fast carbs. Hardcode 20g.
                    est_carbs = 20;
                else
                    % STANDARD MEAL: Reverse engineer using CF/CR
                    est_carbs = delta_G * conversion_ratio;
                    est_carbs = max(10, min(est_carbs, 150));
                end
                
                m_time = cgm_data.datetime(meal_start_idx);
                
                % Check if this CGM meal overlaps with a reported meal OR an orphan bolus we just found
                is_duplicate = false;
                if ~isempty(reported_meals) && any(abs(minutes(reported_meals.UTCDtTm - m_time)) <= 60)
                    is_duplicate = true;
                end
                if ~isempty(inferred_meals) && any(abs(minutes(inferred_meals.UTCDtTm - m_time)) <= 60)
                    is_duplicate = true;
                end
                
                if ~is_duplicate
                    inferred_meals = [inferred_meals; {m_time, est_carbs}]; %#ok<AGROW>
                end
            end
        end
    end
end