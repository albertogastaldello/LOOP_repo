function exerciseWithWearableData()

    % Load filtered exercise table
    exercise = load("exerciseTable_filtered.mat").exerciseTable_clean;
    % exercise(exercise.DurationValue < 15, :) = [];
    
    base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';
    subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
    
    % Columns of meals data to keep
    mealColumsToKeep = ["PtID", "RecID", "DeviceDtTm", "UTCDtTm", ...
                        "CarbsNet", "CarbUnits", "TmZnOffset"];
    
    subjectsID = unique(exercise.PtID);
    
    % Preallocate exercise_valid table
    exercise_valid = exercise([],:);           % empty table with same columns
    exercise_valid.AOB = zeros(0,1);
    exercise_valid.CWL = zeros(0,1);
    exercise_valid.ACWR = zeros(0,1);
    exercise_valid.insulinData = {};           % cell for insulin struct
    exercise_valid.cgmData     = {};           % cell for CGM struct
    exercise_valid.mealData    = {};           % cell for meal table
    exercise_valid.COB = zeros(0,1);

    
    % COB curve
    load('COB.mat');
    
    counter = 0;

    tau = 600; % AOB decay constant, 600 minutes (10 hours)
    
    % Loop over subjects
    for i = 1:length(subjectsID)
        disp(['Processing subject ' num2str(i) ' of ' num2str(length(subjectsID))]);
        
        curr_subjID = subjectsID(i);
        struct_patientField = ['patient_' num2str(curr_subjID)];
        curr_exercise = exercise(exercise.PtID == curr_subjID,:);
        
        % Load subject data once
        cgm_data   = readtable(fullfile(base_path, ['data_type=cgm/patient_id=' num2str(curr_subjID)], 'cgm.csv'));
        basal_data = readtable(fullfile(base_path, ['data_type=basal/patient_id=' num2str(curr_subjID)], 'basal.csv'));
        bolus_data = readtable(fullfile(base_path, ['data_type=bolus/patient_id=' num2str(curr_subjID)], 'bolus.csv'));
        
        % -------- REMOVE CGM DUPLICATES --------
        
        [uniqueTimes,~,ic] = unique(cgm_data.datetime);
        cgm_values = accumarray(ic, cgm_data.cgm, [], @mean);
        
        cgm_data = table(uniqueTimes, cgm_values, ...
            'VariableNames', {'datetime','cgm'});
        
        cgm_data = sortrows(cgm_data,'datetime');
        
        % Convert timestamps
        cgm_data.datenum   = datenum(cgm_data.datetime);
        basal_data.datenum = datenum(basal_data.datetime_aligned);
        bolus_data.datenum = datenum(bolus_data.datetime_aligned);
        
        % -------- SUBJECT DATA --------
        
        curr_wizard = subjectsStruct.(struct_patientField).wizard;
        curr_wizard = sortrows(curr_wizard,'DeviceDtTm');
        curr_wizard.datenum = datenum(curr_wizard.DeviceDtTm);
        
        curr_subjectMealData = subjectsStruct.(struct_patientField).food(:, mealColumsToKeep);
        curr_subjectMealData.datenum = datenum(curr_subjectMealData.DeviceDtTm);
        
        % -------- LOOP SESSIONS --------
        
        for j = 1:height(curr_exercise)
            
            curr_session = curr_exercise(j,:);
            
            startExercise = curr_session.DeviceDtTm;
            endExercise   = startExercise + minutes(curr_session.DurationValue);
            
            preExercise   = startExercise - hours(2);
            postExercise  = endExercise + hours(6);

            % -------- ACUTE:CHRONIC WORKLOAD RATIO ---------
            
            [aob, cwl, acwr] = computeACWR(curr_session, curr_exercise, tau);
            curr_session.AOB = aob;
            curr_session.CWL = cwl;
            curr_session.ACWR = acwr;
            
            % -------- CGM WINDOWS --------
            
            idxExercise = cgm_data.datenum >= datenum(startExercise) & ...
                          cgm_data.datenum <= datenum(endExercise);
            
            idxPre = cgm_data.datenum >= datenum(preExercise) & ...
                     cgm_data.datenum <= datenum(startExercise);
            
            idxPost = cgm_data.datenum >= datenum(endExercise) & ...
                      cgm_data.datenum <= datenum(postExercise);
            
            % Minimum number of points
            if height(cgm_data(idxPre,:)) < 0.85*24 || ...
               height(cgm_data(idxExercise,:)) < 3 || ...
               height(cgm_data(idxPost,:)) < 0.85*72
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
                getInsulinInfo(curr_session, curr_wizard, bolus_data, basal_data);
            
            tmpInsulin = struct( ...
                'InsSensitivity',curr_CF, ...
                'InsCarbRatio',curr_CR, ...
                'TimeSinceLastBolus',curr_tslb, ...
                'LastBolus',curr_lb, ...
                'TimeSinceLastBasal',curr_tslBasal, ...
                'LastBasal',curr_lBasal, ...
                'IOB',curr_IOB);
            
            % -------- MEAL DATA --------
            
            preMeal  = startExercise - hours(6);
            postMeal = endExercise + hours(6);
            
            idxMeal = curr_subjectMealData.datenum >= datenum(preMeal) & ...
                      curr_subjectMealData.datenum <= datenum(postMeal);
            
            sessionMealData = curr_subjectMealData(idxMeal,:);
    
            mealTimes = sessionMealData.DeviceDtTm;
            mealCHO = sessionMealData.CarbsNet;
    
            timeDiff = minutes(startExercise - mealTimes);
            cobMeals = timeDiff >= 0 & timeDiff <= 360;
    
            dt = timeDiff(cobMeals);
            CHO = mealCHO(cobMeals);
    
            f = COB(:,1); % fast
            % f = COB(:,2); %slow
            t_curve = 0:359;
    
            total_cob = sum(CHO .* interp1(t_curve, f, dt, 'linear', 0));
            
            % -------- APPEND SESSION --------
            
            counter = counter + 1;
            
            curr_session.insulinData = {tmpInsulin};
            
            curr_session.cgmData = {struct( ...
                'cgmPreExercise',cgmPreExercise_table, ...
                'cgmExercise',cgmExercise_table, ...
                'cgmPostExercise',cgmPostExercise_table)};
            
            curr_session.mealData = {sessionMealData};
    
            curr_session.COB = total_cob;
            
            exercise_valid(counter,:) = curr_session;
            
        end
    end
    
    % Optional: trim unused preallocated rows
    exercise_valid = exercise_valid(1:counter,:);
    
    % save
    tables_path = '/Users/albertogastaldello/Desktop/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTableWithWearableData.mat"), "exercise_valid");

end

% compute ACWR function

function [aob, cwl, acwr] = computeACWR(curr_session, curr_exercise, tau)
    
    % compute the load of current session as (MET - 1)*duration
    curr_session_load = (curr_session.MET - 1) * curr_session.DurationValue;

    % look for sessions included in 48 hours prior current session start
    % for computing AOB
    curr_sessionStart = curr_session.DeviceDtTm;
    aob_timeWindow = curr_sessionStart - hours(48);
    aob_sessions = curr_exercise(curr_exercise.DeviceDtTm < curr_sessionStart ...
        & curr_exercise.DeviceDtTm >= aob_timeWindow, :);
    aob = 0;
    if ~isempty(aob_sessions)
        for j=1:height(aob_sessions)
            curr_load = (aob_sessions.MET(j) - 1) * aob_sessions.DurationValue(j);
            curr_timeDiff = minutes(curr_sessionStart - aob_sessions.DeviceDtTm(j));
            curr_aob = curr_load * exp(-(curr_timeDiff)/tau);
            aob = aob + curr_aob;
        end
    end

    % look for sessions included in 7 days prior current session start for
    % computing CWL

    cwl_timeWindow = curr_sessionStart - hours(168);
    cwl_sessions = curr_exercise(curr_exercise.DeviceDtTm < curr_sessionStart ...
        & curr_exercise.DeviceDtTm >= cwl_timeWindow, :);
    cwl = 0;
    if ~isempty(cwl_sessions)
        for j=1:height(cwl_sessions)
            curr_cwl = (cwl_sessions.MET(j) - 1) * cwl_sessions.DurationValue(j);
            cwl = cwl + curr_cwl;
        end
    end

    cwl = cwl/7; % average across 7 days

    % compute ACWR
    if cwl == 0
        acwr = Inf;
    else
        acwr = (curr_session_load + aob)/cwl;
    end

end

% getInsulinInfo function

function [CF, CR, tslb, lb, tslBasal, lBasal, IOB] = getInsulinInfo(session, wizard, bolus_data, basal_data)
    CF=NaN; CR=NaN; tslb=NaN; lb=NaN; tslBasal=NaN; lBasal=NaN; IOB=NaN;
    maxTolerance = minutes(30);
    startExercise = session.DeviceDtTm;
    
    % Wizard CF and CR

    % CLOSEST IN TIME TO START EXERCISE, BEFORE OR AFTER
  
    timeDiff = abs(wizard.DeviceDtTm - startExercise);
    validIdx = timeDiff <= maxTolerance;
    
    if any(validIdx)
        [~, minIdxRel] = min(timeDiff(validIdx));
        
        validIndices = find(validIdx);
        idx = validIndices(minIdxRel);
        
        CF = wizard.InsulinSensitivity(idx);
        CR = wizard.InsulinCarbRatio(idx);
        IOB = wizard.InsulinOnBoard(idx);
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
    
    % Last bolus info
    idx_bolus = find(bolus_data.datenum <= datenum(startExercise), 1, 'last');
    if ~isempty(idx_bolus)
        tslb = minutes(startExercise - bolus_data.datetime_aligned(idx_bolus));
        lb   = bolus_data.bolus(idx_bolus);
    end
    
    % Last basal info
    idx_basal = find(basal_data.datenum <= datenum(startExercise), 1, 'last');
    if ~isempty(idx_basal)
        tslBasal = minutes(startExercise - basal_data.datetime_aligned(idx_basal));
        lBasal   = basal_data.basal_rate(idx_basal);
    end
end