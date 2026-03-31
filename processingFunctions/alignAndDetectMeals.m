function final_meals = alignAndDetectMeals(cgm_data, reported_meals, CF, CR, patient_weight)
    
    % --- SAFE DATA PARSING ---
    if istimetable(cgm_data)
        times = cgm_data.Time;
        if ismember('Glucose', cgm_data.Properties.VariableNames)
            g = cgm_data.Glucose;
        else
            g = cgm_data.cgm;
        end
    else
        times = cgm_data.datetime;
        g = cgm_data.cgm;
    end
    
    n_samples = length(g);
    
    if n_samples < 20
        final_meals = reported_meals;
        return;
    end
    
    % --- SETUP CONSTANTS ---
    if isnan(CF) || isnan(CR) || CF <= 0
        conversion_ratio = 0.28; % 500/1800 rule
    else
        conversion_ratio = CR / CF;
    end
    
    if nargin < 5 || isnan(patient_weight)
        patient_weight = 70; 
    end
    ms_fallback = 0.7 * patient_weight; 

    % =====================================================================
    % 1. PRE-PROCESSING: MEAL AGGREGATION (Gastric Emptying Rule)
    % =====================================================================
    if height(reported_meals) > 1
        reported_meals = sortrows(reported_meals, 'UTCDtTm');
        agg_meals = reported_meals(1, :);
        
        for k = 2:height(reported_meals)
            curr_meal = reported_meals(k, :);
            prev_idx = height(agg_meals);
            prev_meal = agg_meals(prev_idx, :);
            
            % If meals are logged within 30 mins, aggregate them into one!
            if minutes(abs(curr_meal.UTCDtTm - prev_meal.UTCDtTm)) <= 30
                agg_meals.CarbsNet(prev_idx) = agg_meals.CarbsNet(prev_idx) + curr_meal.CarbsNet;
            else
                agg_meals = [agg_meals; curr_meal]; %#ok<AGROW>
            end
        end
        reported_meals = agg_meals;
    end

    % --- STEP 2-4: CALCULATE MU ---
    if exist('sgolayfilt', 'file')
        g_smooth = sgolayfilt(g, 3, 13);
        g_prime = gradient(g_smooth) / 5; 
        g_prime = max(0, g_prime); 
        
        g_prime_smooth = sgolayfilt(g_prime, 3, 13);
        g_2prime = gradient(g_prime_smooth) / 5;
        g_2prime = max(0, g_2prime); 
    else
        g_prime = max(0, gradient(movmean(g, 3)) / 5);
        g_2prime = max(0, gradient(movmean(g_prime, 3)) / 5);
    end
    mu = g_prime .* g_2prime; 

    % =====================================================================
    % 5-8: BIDIRECTIONAL ALIGNMENT (Pre-bolus Handling)
    % =====================================================================
    aligned_meals = reported_meals;
    I1max = 12; % +/- 60 mins search area bounds (Bidirectional!)
    I2min = 12;
    
    for i = 1:height(aligned_meals)
        meal_time = aligned_meals.UTCDtTm(i);
        [min_time_diff, Im_i] = min(abs(times - meal_time));
        
        if min_time_diff <= minutes(30)
            idx_start_S1 = max(1, Im_i - I1max);
            idx_end_S1 = min(n_samples, Im_i + I1max);
            S1_range = idx_start_S1:idx_end_S1;
            
            [~, local_peak_idx] = max(mu(S1_range));
            I_mu_i = S1_range(local_peak_idx); 
            
            idx_start_S2 = max(1, I_mu_i - I2min);
            S2_range = idx_start_S2:I_mu_i;
            
            if length(S2_range) > 1
                mu_diff_S2 = diff(mu(S2_range));
                mu_diff_S2(mu_diff_S2 <= 0) = Inf; 
                [~, local_base_idx] = min(mu_diff_S2);
                I_base_i = S2_range(local_base_idx); 
                
                % Update meal time to the physiological base
                aligned_meals.UTCDtTm(i) = times(I_base_i);
            end
        end
    end

    % =====================================================================
    % 9-10: IDENTIFY POTENTIAL UNANNOUNCED PEAKS
    % =====================================================================
    Pm = 0.0075; 
    Pp = 0.0025; 
    separation_samples = 6; 
    
    if exist('findpeaks', 'file')
        [Ph, Id] = findpeaks(mu, 'MinPeakHeight', Pm, ...
                             'MinPeakProminence', Pp, ...
                             'MinPeakDistance', separation_samples);
    else
        Id = find(mu > Pm);
        Ph = mu(Id);
    end

    % =====================================================================
    % 11-23: CLASSIFY UNANNOUNCED MEALS (With 60-min Lockout)
    % =====================================================================
    unannounced_meals = table('Size', [0 2], 'VariableTypes', {'datetime', 'double'}, ...
                              'VariableNames', {'UTCDtTm', 'CarbsNet'});
    hypo_treat_indices = [];
    meal_indices = [];
    
    for i = 1:length(Id)
        Id_i = Id(i);
        
        idx_start_S3 = max(1, Id_i - I2min);
        S3_range = idx_start_S3:Id_i;
        
        if length(S3_range) > 1
            mu_diff_S3 = diff(mu(S3_range));
            mu_diff_S3(mu_diff_S3 <= 0) = Inf;
            [~, local_base_idx] = min(mu_diff_S3);
            Id_base = S3_range(local_base_idx);
        else
            Id_base = Id_i;
        end
        
        peak_time = times(Id_base);
        
        % --- THE REFRACTORY LOCKOUT PERIOD ---
        % Is this peak occurring within 60 minutes AFTER a reported meal?
        % If so, it's just a secondary gastric emptying spike (fat/protein). Ignore it.
        is_locked_out = false;
        if ~isempty(aligned_meals)
            for j = 1:height(aligned_meals)
                time_since_meal = minutes(peak_time - aligned_meals.UTCDtTm(j));
                if time_since_meal > 0 && time_since_meal <= 60
                    is_locked_out = true;
                    break;
                end
            end
        end
        
        if is_locked_out
            continue; % Skip processing this peak entirely
        end
        
        % Proceed with Hypo / Meal Classification
        idx_end_60m = min(n_samples, Id_base + 12);
        delta_g = max(g(Id_base:idx_end_60m)) - g(Id_base); 
        base_g = g(Id_base);
        
        if base_g <= 90 && Ph(i) >= 0.01
            % Hypo-rescue
            if isempty(hypo_treat_indices) || (Id_base - hypo_treat_indices(end)) > 3
                hypo_treat_indices(end+1) = Id_base; %#ok<AGROW>
                unannounced_meals = [unannounced_meals; {peak_time, 20}]; %#ok<AGROW>
            end
        elseif delta_g >= 40
            % Unannounced Meal
            if isempty(meal_indices) || (Id_base - meal_indices(end)) > 9
                meal_indices(end+1) = Id_base; %#ok<AGROW>
                est_carbs = delta_g * conversion_ratio;
                if est_carbs < 10 || est_carbs > 200
                    est_carbs = ms_fallback; 
                end
                unannounced_meals = [unannounced_meals; {peak_time, est_carbs}]; %#ok<AGROW>
            end
        end
    end

    % =====================================================================
    % MERGE AND FINAL SORT
    % =====================================================================
    % =====================================================================
    % MERGE AND FINAL SORT (POST-ALIGNMENT DEDUPLICATION)
    % =====================================================================
    % 1. Tag the meals so we know which ones to protect
    aligned_meals = aligned_meals(:, {'UTCDtTm', 'CarbsNet'});
    aligned_meals.IsReported = true(height(aligned_meals), 1);
    
    if height(unannounced_meals) > 0
        unannounced_meals.IsReported = false(height(unannounced_meals), 1);
    else
        unannounced_meals.IsReported = logical([]);
    end
    
    % 2. Combine and sort chronologically
    final_meals_raw = sortrows([aligned_meals; unannounced_meals], 'UTCDtTm');
    
    % 3. The Smart Merge Loop
    if height(final_meals_raw) > 1
        merged_meals = final_meals_raw(1, :);
        
        for k = 2:height(final_meals_raw)
            curr_meal = final_meals_raw(k, :);
            prev_idx = height(merged_meals);
            prev_meal = merged_meals(prev_idx, :);
            
            % If meals were dragged to the same (or adjacent) CGM timestamp (within 15 mins)
            if minutes(abs(curr_meal.UTCDtTm - prev_meal.UTCDtTm)) <= 15
                
                % SCENARIO A: Two reported meals dragged to the same peak
                if curr_meal.IsReported && prev_meal.IsReported
                    merged_meals.CarbsNet(prev_idx) = merged_meals.CarbsNet(prev_idx) + curr_meal.CarbsNet;
                
                % SCENARIO B: A reported meal and an unannounced phantom collide
                elseif curr_meal.IsReported && ~prev_meal.IsReported
                    merged_meals(prev_idx, :) = curr_meal; % Real meal overwrites phantom
                elseif ~curr_meal.IsReported && prev_meal.IsReported
                    continue; % Ignore the phantom, keep the real meal
                
                % SCENARIO C: Two unannounced meals right next to each other
                elseif ~curr_meal.IsReported && ~prev_meal.IsReported
                    % Keep the one with the larger estimated carbs
                    merged_meals.CarbsNet(prev_idx) = max(merged_meals.CarbsNet(prev_idx), curr_meal.CarbsNet);
                end
            else
                % No collision, append normally
                merged_meals = [merged_meals; curr_meal]; %#ok<AGROW>
            end
        end
        % Drop the tracking column before returning
        final_meals = merged_meals(:, {'UTCDtTm', 'CarbsNet'});
    else
        final_meals = final_meals_raw(:, {'UTCDtTm', 'CarbsNet'});
    end
end