function exerciseWithWearableData()

    % Load filtered exercise table
    exercise = load("exerciseTable_filtered.mat").exerciseTable_clean;
    
    base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31';
    subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
    
    % Columns of meals data to keep
    mealColumsToKeep = ["PtID", "RecID", "DeviceDtTm", "UTCDtTm", ...
                        "CarbsNet", "CarbUnits", "TmZnOffset"];
    
    subjectsID = unique(exercise.PtID);
    
    % Preallocate exercise_valid table
    exercise_valid = exercise([],:);           % empty table with same columns
    exercise_valid.AOB = zeros(0,1);
    exercise_valid.TotalCWL = zeros(0,1);
    exercise_valid.CWLPerDay = zeros(0,1);
    exercise_valid.ACWR = zeros(0,1);
    exercise_valid.insulinData = {};           % cell for insulin struct
    exercise_valid.cgmData     = {};           % cell for CGM struct
    exercise_valid.reportedMealData = {};           % cell for meal table
    exercise_valid.finalMealData = {};
    exercise_valid.COB = zeros(0,1);
    exercise_valid.COBnorm = zeros(0,1);

    hoursPreExercise = 2;
    hoursPostExercise = 6;

    
    % COB curve
    load('COB.mat');
    
    counter = 0;

    tau = 600; % AOB decay constant, 600 minutes (10 hours)
    
    fewCgmData_counter = 0;
    shortSessions_counter = 0;

    % Loop over subjects
    for i = 1:length(subjectsID)
        
        % UNCOMMENT IF YOU WANT JUST TO VISUALIZE SOME EXAMPLES OF FEW CGM
        % DATA TRACES WITHOUT RUNNING THE ENTIRE LOOP
        % 
        % if(fewCgmData_counter > 10)
        %     break
        % end

        disp(['Processing subject ' num2str(i) ' of ' num2str(length(subjectsID))]);
        
        curr_subjID = subjectsID(i);
        struct_patientField = ['patient_' num2str(curr_subjID)];
        curr_exercise = exercise(exercise.PtID == curr_subjID,:);
        
        % Load subject data once
        cgm_data   = readtable(fullfile(base_path, ['data_type=cgm/patient_id=' num2str(curr_subjID)], 'cgm.csv'));
        basal_data = readtable(fullfile(base_path, ['data_type=basal/patient_id=' num2str(curr_subjID)], 'basal.csv'));
        bolus_data = readtable(fullfile(base_path, ['data_type=bolus/patient_id=' num2str(curr_subjID)], 'bolus.csv'));

        % Force Babelbetes strings to UTC Datetime
        cgm_data.datetime = datetime(cgm_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        basal_data.datetime = datetime(basal_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        bolus_data.datetime = datetime(bolus_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        
        % -------- REMOVE CGM DUPLICATES --------
        
        [uniqueTimes,~,ic] = unique(cgm_data.datetime);
        cgm_values = accumarray(ic, cgm_data.cgm, [], @mean);
        
        cgm_data = table(uniqueTimes, cgm_values, ...
            'VariableNames', {'datetime','cgm'});
        
        cgm_data = sortrows(cgm_data,'datetime');
        
        % -------- SUBJECT DATA --------
        
        curr_wizard = subjectsStruct.(struct_patientField).wizard;
        curr_wizard = sortrows(curr_wizard,'UTCDtTm');
        
        curr_subjectMealData = subjectsStruct.(struct_patientField).food(:, mealColumsToKeep);
        curr_subjectMealData = sortrows(curr_subjectMealData, 'UTCDtTm');
        
        % -------- LOOP SESSIONS --------
        
        for j = 1:height(curr_exercise)
            
            curr_session = curr_exercise(j,:);

            startExercise = curr_session.UTCDtTm;
            exerciseDuration = curr_session.DurationValue;
            endExercise   = startExercise + minutes(exerciseDuration);
            
            preExercise   = startExercise - hours(hoursPreExercise);
            postExercise  = endExercise + hours(hoursPostExercise);

            % -------- ACUTE:CHRONIC WORKLOAD RATIO ---------
            
            [aob, total_cwl, cwl_per_day, acwr] = computeACWR(curr_session, curr_exercise, tau);
            curr_session.AOB = aob;
            curr_session.TotalCWL = total_cwl;
            curr_session.CWLPerDay = cwl_per_day;
            curr_session.ACWR = acwr;
            
            % -------- CGM WINDOWS --------
            
            idxExercise = cgm_data.datetime >= startExercise & ...
                cgm_data.datetime <= endExercise;
            idxPre = cgm_data.datetime >= preExercise & ...
                cgm_data.datetime <= startExercise;
            idxPost = cgm_data.datetime >= endExercise & ...
                cgm_data.datetime <= postExercise;


            maxSamples_preExercise  = floor((hoursPreExercise * 60) / 5) + 1;
            maxSamples_during       = floor(minutes(exerciseDuration) / 5) + 1;
            maxSamples_postExercise = floor((hoursPostExercise * 60) / 5) + 1;
            
            % Minimum number of points

            if sum(idxPre) < (0.85 * maxSamples_preExercise) || ...
               sum(idxExercise) < (0.85 * maxSamples_during) || ...
               sum(idxPost) < (0.7 * maxSamples_postExercise)
               
                % Reject the session due to insufficient CGM density
                fewCgmData_counter = fewCgmData_counter + 1;

                % UNCOMMENT TO VISUALIZE SOME EXAMPLES OF FEW CGM DATA
                % TRACES

                % if(fewCgmData_counter <= 10)
                %     figure()
                %     plot(cgm_data.datetime(idxPre), cgm_data.cgm(idxPre), 'r')
                %     hold on
                %     plot(cgm_data.datetime(idxExercise), cgm_data.cgm(idxExercise), 'g')
                %     hold on
                %     plot(cgm_data.datetime(idxPost), cgm_data.cgm(idxPost), 'b')
                % 
                %     nPre = sum(idxPre);
                %     nDuring = sum(idxExercise);
                %     nPost = sum(idxPost);
                % 
                %     title(['Samples Available: Pre ' num2str(nPre) ' / '...
                %        num2str(maxSamples_preExercise) ' | During: '...
                %        num2str(nDuring) '/ ' num2str(exerciseDuration/5)...
                %        ' | Post: ' num2str(nPost) '/ ' num2str(maxSamples_postExercise)]);
                % 
                % end
                continue

            end
            
            % -------- BUILD TIMETABLES --------
            
            cgmExercise_table = timetable( ...
                cgm_data.datetime(idxExercise), ...
                cgm_data.cgm(idxExercise), ...
                'VariableNames',{'Glucose'});
            
            cgmPreExercise_table = timetable( ...
                cgm_data.datetime(idxPre), ...
                cgm_data.cgm(idxPre), ...
                'VariableNames',{'Glucose'});
            
            cgmPostExercise_table = timetable( ...
                cgm_data.datetime(idxPost), ...
                cgm_data.cgm(idxPost), ...
                'VariableNames',{'Glucose'});
            
            % -------- INSULIN DATA --------
            
            [curr_CF, curr_CR, curr_tslb, curr_lb, ...
             curr_tslBasal, curr_lBasal, curr_IOB] = ...
                getInsulinInfo(startExercise, curr_wizard, bolus_data, basal_data);
            curr_IOB_normalized = curr_IOB * curr_CF;
            
            tmpInsulin = struct( ...
                'InsSensitivity',curr_CF, ...
                'InsCarbRatio',curr_CR, ...
                'TimeSinceLastBolus',curr_tslb, ...
                'LastBolus',curr_lb, ...
                'TimeSinceLastBasal',curr_tslBasal, ...
                'LastBasal',curr_lBasal, ...
                'IOB',curr_IOB, ...
                'IOBnorm', curr_IOB_normalized);
            
            % -------- MEAL DATA --------
            
            preMeal  = startExercise - hours(hoursPreExercise);
            postMeal = endExercise + hours(hoursPostExercise);
            
            idxMeal = curr_subjectMealData.UTCDtTm >= preMeal & ...
                curr_subjectMealData.UTCDtTm <= postMeal;
            sessionMealData = curr_subjectMealData(idxMeal,:);

            % meals alignment and detection
            cgmTotal = vertcat(cgmPreExercise_table, cgmExercise_table, cgmPostExercise_table);
            curr_finalMeals = alignAndDetectMeals(cgmTotal, sessionMealData, curr_CF, curr_CR, curr_session.weight);
            mealTimes = curr_finalMeals.UTCDtTm;
            mealCHO = curr_finalMeals.CarbsNet;


            % mealTimes = sessionMealData.UTCDtTm;
            % mealCHO = sessionMealData.CarbsNet;
    
            timeDiff = minutes(startExercise - mealTimes);
            cobMeals = timeDiff >= 0 & timeDiff <= 360;
    
            dt = timeDiff(cobMeals);
            CHO = mealCHO(cobMeals);
    
            f = COB(:,1); % fast
            % f = COB(:,2); %slow
            t_curve = 0:359;
    
            total_cob = sum(CHO .* interp1(t_curve, f, dt, 'linear', 0));
            weight = subjectsStruct.(struct_patientField).surveys.weight_kg(1);
            cob_norm = total_cob / weight; 
            
            % -------- APPEND SESSION --------
            
            counter = counter + 1;
            
            curr_session.insulinData = {tmpInsulin};
            
            curr_session.cgmData = {struct( ...
                'cgmPreExercise',cgmPreExercise_table, ...
                'cgmExercise',cgmExercise_table, ...
                'cgmPostExercise',cgmPostExercise_table)};
            
            curr_session.reportedMealData = {sessionMealData};
            curr_session.finalMealData = {curr_finalMeals};
    
            curr_session.COB = total_cob;
            curr_session.COBnorm = cob_norm;
            
            exercise_valid(counter,:) = curr_session;
            
        end


    end
    
    % Optional: trim unused preallocated rows
    exercise_valid = exercise_valid(1:counter,:);

    % disp removed sessions counters
    disp(['short sessions: ' num2str(shortSessions_counter)])
    disp(['few cgm data sessions: ' num2str(fewCgmData_counter)])
    
    % save
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTableWithWearableData.mat"), "exercise_valid");

end

% compute ACWR function

function [aob, total_cwl, cwl_per_day, acwr] = computeACWR(curr_session, curr_exercise, tau)
    
    % compute the load of current session as MET*duration
    % NB: NOT MET - 1 BECAUSE HEALTHKIT PROVIDES ACTIVE ENERGY VALUE, SO
    % THE 'SITTING' ENERGY CONSUMPTION (I.E. THE MINUS 1 IN MET VALUE) IS
    % ALREADY SUBSTRACTED
    curr_session_load = curr_session.MET * curr_session.DurationValue;

    % look for sessions included in 48 hours prior current session start
    % for computing AOB
    curr_sessionStart = curr_session.UTCDtTm;

    aob_timeWindow = curr_sessionStart - hours(48);
    aob_sessions = curr_exercise(curr_exercise.UTCDtTm < curr_sessionStart ...
        & curr_exercise.UTCDtTm >= aob_timeWindow, :);
    aob = 0;
    if ~isempty(aob_sessions)
        for j=1:height(aob_sessions)
            curr_load = aob_sessions.MET(j) * aob_sessions.DurationValue(j);
            curr_timeDiff = minutes(curr_sessionStart - ...
                (aob_sessions.UTCDtTm(j) + minutes(aob_sessions.DurationValue(j))));
            if curr_timeDiff > 0
                aob = aob + (curr_load * exp(-(curr_timeDiff)/tau));
            end
        end
    end

    % look for sessions included in 7 days prior current session start for
    % computing CWL

    cwl_timeWindow = curr_sessionStart - hours(168);
    cwl_sessions = curr_exercise(curr_exercise.UTCDtTm < curr_sessionStart ...
        & curr_exercise.UTCDtTm >= cwl_timeWindow, :);
    cwl = 0;
    if ~isempty(cwl_sessions)
        for j=1:height(cwl_sessions)
            curr_cwl = cwl_sessions.MET(j) * cwl_sessions.DurationValue(j);
            cwl = cwl + curr_cwl;
        end
    end
        
    cwl_per_day = cwl/7; % average across 7 days
    total_cwl = cwl; 

    % compute ACWR
    if cwl == 0
        acwr = Inf;
    else
        acwr = (curr_session_load + aob)/cwl;
    end

end

% getInsulinInfo function

function [CF, CR, tslb, lb, tslBasal, lBasal, IOB] = getInsulinInfo(startExercise, wizard, bolus_data, basal_data)
    CF=NaN; CR=NaN; tslb=NaN; lb=NaN; tslBasal=NaN; lBasal=NaN; IOB=NaN;
    
    basal_data(isnan(basal_data.basal_rate),:)=[];
    bolus_data(isnan(bolus_data.bolus),:)=[];
    
    maxTolerance = minutes(30);
    
    % Wizard CF and CR

    % CLOSEST IN TIME TO START EXERCISE, BEFORE OR AFTER
    
    if ~isempty(wizard)

        timeDiff = abs(wizard.UTCDtTm - startExercise);
        [~, sortedIdx] = sort(timeDiff);
    
        for k = 1:length(sortedIdx)
            idx = sortedIdx(k);

            if isnan(CF) && ~isnan(wizard.InsulinSensitivity(idx))
                CF = wizard.InsulinSensitivity(idx);
            end

            if isnan(CR) && ~isnan(wizard.InsulinCarbRatio(idx))
                CR = wizard.InsulinCarbRatio(idx);
            end

            if ~isnan(CF) && ~isnan(CR)
                break
            end
        end
    end

    % ONLY BEFORE START OF EXERCISE
    % idx = find(wizard.datenum <= datenum(startExercise), 1, 'last');
    % if ~isempty(idx)
    %     CF = wizard.InsulinSensitivity(idx);
    %     CR = wizard.InsulinCarbRatio(idx);
    %     if startExercise - wizard.DeviceDtTm(idx) <= maxTolerance
    %         IOB = wizard.InsulinOnBoard(idx);
    %     end
    % end

    % Estimate IOB if not available

    if isnan(IOB)
        ts = 5; 
        time_edges = (startExercise - hours(6)) : minutes(ts) : startExercise;
        num_bins = length(time_edges) - 1;
        insulin_inputs = zeros(num_bins, 1);
        
        % --- A. PROCESS BOLUSES ---
        idx_bolus = bolus_data.datetime >= time_edges(1) & bolus_data.datetime < time_edges(end);
        recent_boluses = bolus_data(idx_bolus, :);
        for b = 1:height(recent_boluses)
            bin_idx = find(time_edges <= recent_boluses.datetime(b), 1, 'last');
            if bin_idx > num_bins; bin_idx = num_bins; end
            insulin_inputs(bin_idx) = insulin_inputs(bin_idx) + recent_boluses.bolus(b);
        end

        % --- B. PROCESS NET BASAL (The Median Proxy Method) ---
        % Find the underlying scheduled basal rate using the median of the last 48 hours
        idx_48h = basal_data.datetime >= (startExercise - hours(48)) & basal_data.datetime <= startExercise;
        if any(idx_48h)
            % Use median to filter out temporary spikes and suspensions
            baseline_rate = median(basal_data.basal_rate(idx_48h), 'omitnan');
        else
            baseline_rate = 0; % Fallback
        end

        idx_basal = basal_data.datetime >= (time_edges(1) - hours(1)) & basal_data.datetime < time_edges(end);
        recent_basals = basal_data(idx_basal, :);

        for b = 1:height(recent_basals)
            start_time = recent_basals.datetime(b);
            
            % Safely determine duration if BabelBetes dropped it
            if ismember('duration', recent_basals.Properties.VariableNames)
                % Assuming BabelBetes duration is in minutes
                end_time = start_time + minutes(recent_basals.duration(b));
            else
                % Dynamic calculation: duration is until the next basal change
                if b < height(recent_basals)
                    end_time = recent_basals.datetime(b+1);
                else
                    end_time = startExercise; % Cap at exercise start
                end
            end
            
            % Net Basal Deviation
            rate = recent_basals.basal_rate(b);
            net_rate_hr = rate - baseline_rate; 
            
            % Convert U/hr to Units per 5-minute bin
            net_units_per_bin = net_rate_hr * (ts / 60);
            
            for bin = 1:num_bins
                bin_center = time_edges(bin) + minutes(ts/2);
                if bin_center >= start_time && bin_center <= end_time
                    insulin_inputs(bin) = insulin_inputs(bin) + net_units_per_bin;
                end
            end
        end

        k1 = 0.0173; 
        k2 = 0.0116; 
        k3 = 6.73;
        
        t = 0:359; % Minutes 0 to 359
        
        % Calculate the 360-minute curve (Vectorized)
        term1 = -k3 / (k2 * (k1 - k2)) .* (exp(-k2 .* t ./ 0.75) - 1);
        term2 =  k3 / (k1 * (k1 - k2)) .* (exp(-k1 .* t ./ 0.75) - 1);
        iob_6h_curve = 1 - 0.75 .* (term1 + term2) ./ 2.4947e4;
        
        % Subsample every ts=5 minutes 
        % (Python's [ts::ts] maps to MATLAB indices starting at t=5, which is index 6)
        iob_6h_curve_sub = iob_6h_curve((ts+1):ts:end); 
        
        % Convolve the bolus input array with the decay curve
        iob_conv = conv(insulin_inputs, iob_6h_curve_sub);
        
        % The IOB at exactly T_start is the value at the end of the bolus array
        IOB = iob_conv(num_bins);

    end

    
    % Last bolus info
    idx_bolus = find(bolus_data.datetime <= startExercise, 1, 'last');
    if ~isempty(idx_bolus)
        tslb = minutes(startExercise - bolus_data.datetime(idx_bolus));
        lb   = bolus_data.bolus(idx_bolus);
    end
    
    % Last basal info
    idx_basal = find(basal_data.datetime <= startExercise, 1, 'last');
    if ~isempty(idx_basal)
        tslBasal = minutes(startExercise - basal_data.datetime(idx_basal));
        lBasal   = basal_data.basal_rate(idx_basal);
    end
end