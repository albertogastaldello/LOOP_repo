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
    
        % -------------- post exercise (outcome) layer --------------
        
        %disp(i);
        glucoseStart = curr_session.cgmData{1,1}.cgmExercise.Glucose(1);
        glucoseEnd = curr_session.cgmData{1,1}.cgmExercise.Glucose(end);
        
        % exercise glucose excursion
        exerciseGlucoseExcursion = glucoseEnd - glucoseStart;
    
        % exercise glucose rate of change
        exerciseGlucoseRoc = exerciseGlucoseExcursion / ...
            minutes(curr_session.cgmData{1,1}.cgmExercise.Time(end) - ...
            curr_session.cgmData{1,1}.cgmExercise.Time(1));

        cgmPostExercise = curr_session.cgmData{1,1}.cgmPostExercise;
        
        sessionDuration = curr_session.DurationValue;
        endSession = startSession + minutes(sessionDuration);

        postSession_6hours = endSession + hours(6);
        idx6HoursPostSession = find(cgmPostExercise.Time >= postSession_6hours, 1, 'first');

        if isempty(idx6HoursPostSession)
            idx6HoursPostSession = size(cgmPostExercise,1);
        end

        glucose6HoursPostExercise = cgmPostExercise.Glucose(1:idx6HoursPostSession);
    
        % minimum glucose value reached in the post exercise (6h after end)
        minGlucosePostExercise = min(glucose6HoursPostExercise);
    
        % time in range in the post exercise (6h after end)
        idx_TIR = find(glucose6HoursPostExercise >= 70 & glucose6HoursPostExercise <= 180);
        postExerciseTIR = (length(idx_TIR)/height(glucose6HoursPostExercise))*100;
    
        % glucose CV in the post exercise (6h after end)
        postExerciseGlucoseCV = (std(glucose6HoursPostExercise) / mean(glucose6HoursPostExercise)) * 100;
    
        % add metrics
        curr_session.exerciseGlucoseExcursion = exerciseGlucoseExcursion;
        curr_session.exerciseGlucoseRoc = exerciseGlucoseRoc;
        curr_session.minGlucosePostExercise = minGlucosePostExercise;
        curr_session.postExerciseTIR = postExerciseTIR;
        curr_session.postExerciseGlucoseCV = postExerciseGlucoseCV;
        
        % update the current row of exercise table
        exerciseTableForBN = [exerciseTableForBN; curr_session];
            
    end
    
    % save
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTableForBN.mat"), "exerciseTableForBN");

end