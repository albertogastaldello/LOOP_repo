function exerciseForBN()

    % load exercise table with wearable data
    
    exercise = load("exerciseTableWithWearableData.mat").exercise_valid;
    
    exerciseTableForBN = table();
    
    % Loop over sessions
    
    for i = 1:height(exercise)
    
        curr_session = exercise(i,:);
    
        % -------------- demographics layer --------------
    
        curr_session.BMI = curr_session.weight / ((curr_session.height/100)^2);
    
        % -------------- pre exercise layer --------------
        
        startSession = curr_session.UTCDtTm;
        preSession_30Min = startSession - minutes(30);
        preSession_120min = startSession - minutes(120);
        
        % glucose RoC in the 30 minutes prior to exercise session
        cgmPreExercise = curr_session.cgmData{1,1}.cgmPreExercise;
        idx30MinPreSession = find(cgmPreExercise.Time >= preSession_30Min, 1, 'first');
        if isempty(idx30MinPreSession)
            preExerciseRoc = NaN;
        else
            preExerciseRoc = (cgmPreExercise.Glucose(end) - cgmPreExercise.Glucose(idx30MinPreSession))...
                /(minutes(cgmPreExercise.Time(end) - cgmPreExercise.Time(idx30MinPreSession)));
        end
    
        % pre Exercise Glucose level
        startExerciseGlucoseLevel = cgmPreExercise.Glucose(end);
    
        % preExercise glucose CV
        idx120MinPreSession = find(cgmPreExercise.Time >= preSession_120min, 1, 'first');
        preExerciseGlucoseCV = (std(cgmPreExercise.Glucose(idx120MinPreSession:end))...
            /mean(cgmPreExercise.Glucose(idx120MinPreSession:end))) * 100;
        
        % add to curr_session
        curr_session.preExerciseRoc = preExerciseRoc;
        curr_session.startExerciseGlucoseLevel = startExerciseGlucoseLevel;
        curr_session.preExerciseGlucoseCV = preExerciseGlucoseCV;
    
        % -------------- exercise characteristic layer --------------
    
        % we have already intensity, duration, METs
    
        % -------------- during exercise (outcome) layer --------------
        
        %disp(i);

        ex_glucose = curr_session.cgmData{1,1}.cgmExercise.Glucose;
        ex_time = curr_session.cgmData{1,1}.cgmExercise.Time;
        dt_minutes = minutes(diff(ex_time));
        total_duration = minutes(ex_time(end) - ex_time(1));

        % glucose nadir and peak during exercise
        ex_nadir = min(ex_glucose);
        ex_peakGlucose = max(ex_glucose);

        % max excursion during exercise
        ex_maxExcursion = ex_peakGlucose - ex_nadir;

        % glucose max spike roc and max drop roc during exercise
        if length(ex_glucose) > 1
           
            instant_roc = diff(ex_glucose) ./ dt_minutes;

            maxSpikeRoc = max([instant_roc(:); 0]); 
            maxDropRoc  = min([instant_roc(:); 0]);
        else
            maxSpikeRoc = 0;
            maxDropRoc = 0;
        end
        
        % hypo event during exercise
        exerciseHypoEvent = double(any(ex_glucose < 70));

        % time to hypo event during exercise (NaN if no hypo event)
        if exerciseHypoEvent == 1
            idxHypoEvent = find(ex_glucose < 70, 1, 'first');
            timeHypoEvent = ex_time(idxHypoEvent);
            timeToExerciseHypoEvent = minutes(timeHypoEvent - startSession);
        else
            timeToExerciseHypoEvent = NaN;
        end

        % glucose TBR and TIR during exercise
        if total_duration > 0

            dt_full = [dt_minutes(:); median(dt_minutes(:))];

            calc_duration = sum(dt_full);

            % Logical arrays: Was the glucose below 70 at the start of this interval?
            idx_below_70 = ex_glucose < 70;
            idx_in_range = ex_glucose >= 70 & ex_glucose <= 180;
            
            % Sum the time (in minutes) spent in those states, divide by total time
            ex_TBR = (sum(dt_full(idx_below_70)) / calc_duration) * 100;
            ex_TIR = (sum(dt_full(idx_in_range)) / calc_duration) * 100;
        else
            ex_TBR = 0;
            ex_TIR = 0;
        end

        % glucose AUC below 70 mg/dl during exercise
        if length(ex_glucose) > 1
            time_numeric = minutes(ex_time(:) - ex_time(1));
            cgm_deficit = max(0, 70 - ex_glucose(:));
            ex_AUC70 = trapz(time_numeric, cgm_deficit);
        else
            ex_AUC70 = 0;
        end

        % -------------- post exercise (outcome) layer --------------

        cgmPostExercise = curr_session.cgmData{1,1}.cgmPostExercise;
        
        sessionDuration = curr_session.DurationValue;
        endSession = startSession + minutes(sessionDuration);
        postSession_6hours = endSession + hours(6);
        idx6HoursPostSession = find(cgmPostExercise.Time >= postSession_6hours, 1, 'first');
        
        if isempty(idx6HoursPostSession)
            idx6HoursPostSession = size(cgmPostExercise,1);
        end
        
        % Extract Post-Exercise Arrays safely
        post_time = cgmPostExercise.Time(1:idx6HoursPostSession);
        post_glucose = cgmPostExercise.Glucose(1:idx6HoursPostSession);
    
        % Max and Min glucose
        [minGlucosePostExercise, min_idx] = min(post_glucose); 
        maxGlucosePostExercise = max(post_glucose); 
        
        % Glucose CV
        postExerciseGlucoseCV = (std(post_glucose) / mean(post_glucose)) * 100;
        
        % Time-to-Event Metric 
        postExercise_timeToNadir = minutes(post_time(min_idx) - post_time(1));
        
        % Post Exercise Hypo Event
        postExerciseHypoEvent = double(any(post_glucose < 70));

        % Time to Post Exercise Hypo Event (NaN if no hypo event)
        if postExerciseHypoEvent == 1
            idxPostHypoEvent = find(post_glucose < 70, 1, 'first');
            timePostHypoEvent = post_time(idxPostHypoEvent);
            timeToPostExerciseHypoEvent = minutes(timePostHypoEvent - endSession);
        else
            timeToPostExerciseHypoEvent = NaN;
        end
    
        % Range Metrics (TIR, TBR, TAR)
        if length(post_time) > 1
            dt_post = minutes(diff(post_time));
            dt_full_post = [dt_post; median(dt_post)];
            total_post_time = sum(dt_full_post);
            
            idx_TIR = post_glucose(:) >= 70 & post_glucose(:) <= 180;
            idx_TBR = post_glucose(:) < 70;
            idx_TAR = post_glucose(:) > 180;
            
            postExerciseTIR = (sum(dt_full_post(idx_TIR)) / total_post_time) * 100;
            postExerciseTBR = (sum(dt_full_post(idx_TBR)) / total_post_time) * 100;
            postExerciseTAR = (sum(dt_full_post(idx_TAR)) / total_post_time) * 100;
            
            % Area Under the Curve (AUC < 70)
            time_numeric_post = minutes(post_time(:) - post_time(1));
            cgm_deficit_post = max(0, 70 - post_glucose(:));
            postExerciseAUC70 = trapz(time_numeric_post, cgm_deficit_post);
            
        else
            % Fallbacks if there isn't enough data
            postExerciseTIR = NaN; postExerciseTBR = NaN; postExerciseTAR = NaN;
            postExerciseAUC70 = NaN;
        end


        % ------------------ add metrics --------------------------
        curr_session.exerciseMaxExcursion = ex_maxExcursion;
        curr_session.exerciseMaxSpikeRoc = maxSpikeRoc;
        curr_session.exerciseMaxDropRoc = maxDropRoc;
        curr_session.exerciseNadir = ex_nadir;
        curr_session.exercisePeak = ex_peakGlucose;
        curr_session.exerciseTIR = ex_TIR;
        curr_session.exerciseTBR = ex_TBR;
        curr_session.exerciseAUC70 = ex_AUC70;
        curr_session.exerciseHypoEvent = exerciseHypoEvent;
        curr_session.timeToExerciseHypoEvent = timeToExerciseHypoEvent;
        
        curr_session.maxGlucosePostExercise = maxGlucosePostExercise;
        curr_session.minGlucosePostExercise = minGlucosePostExercise;
        curr_session.postExerciseTimeToNadir = postExercise_timeToNadir;
        curr_session.postExerciseTIR = postExerciseTIR;
        curr_session.postExerciseTBR = postExerciseTBR;
        curr_session.postExerciseTAR = postExerciseTAR;
        curr_session.postExerciseGlucoseCV = postExerciseGlucoseCV;
        curr_session.postExerciseAUC70 = postExerciseAUC70;
        curr_session.postExerciseHypoEvent = postExerciseHypoEvent;
        curr_session.timeToPostExerciseHypoEvent = timeToPostExerciseHypoEvent;
        
        % update the current row of exercise table
        exerciseTableForBN = [exerciseTableForBN; curr_session];
            
    end
    
    % save
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTableForBN.mat"), "exerciseTableForBN");

end