function exerciseForBN()

    % load exercise table with wearable data
    
    exercise = load("exerciseTableWithWearableData.mat").exercise_valid;
    
    exerciseTableForBN = table();
    
    
    % Loop over sessions
    
    for i = 1:height(exercise)
        
        curr_session = exercise(i,:);
    
        % -------------- demographics layer --------------
    
        curr_session.BMI = curr_session.weight / ((curr_session.height/100)^2);
        
        % FITNESS LEVEL (?)
    
        % INSULIN SENSITIVITY INDICES (?)
    
        % -------------- pre exercise layer --------------
        
        startSession = curr_session.DeviceDtTm;
        preSession_30Min = startSession - minutes(30);
        
        % glucose RoC in the 30 minutes prior to exercise session
        cgmPreExercise = curr_session.cgmData{1,1}.cgmPreExercise;
        idx30MinPreSession = find(cgmPreExercise.Time >= preSession_30Min, 1, 'first');
        if isempty(idx30MinPreSession)
            preExerciseRoc = NaN;
        else
            preExerciseRoc = (cgmPreExercise.Glucose(end) - cgmPreExercise.Glucose(idx30MinPreSession))...
                /(minutes(cgmPreExercise.Time(end) - cgmPreExercise.Time(idx30MinPreSession)));
        end
    
        % IOB --> CAPIRE SE VA STIMATA DATO CHE RARAMENTE E' PRESENTE
        
        % COB --> GUARDARE LETTERATURA E CODICE INVIATO DA ANDREA PER CAPIRE
        % COME STIMARLI
    
        % pre Exercise Glucose level
        startExerciseGlucoseLevel = cgmPreExercise.Glucose(end);
    
        % preExercise glucose CV
        preExerciseGlucoseCV = (std(cgmPreExercise.Glucose)/mean(cgmPreExercise.Glucose)) * 100;
        
        % add to curr_session
        curr_session.preExerciseRoc = preExerciseRoc;
        curr_session.startExerciseGlucoseLevel = startExerciseGlucoseLevel;
        curr_session.preExerciseGlucoseCV = preExerciseGlucoseCV;
    
        % -------------- exercise characteristic layer --------------
    
        % we have already intensity, duration, METs
    
        % TIME OF DAY PUO' ESSERE UTILE MA DA CAPIRE SE I TIMESTAMP CHE ABBIAMO
        % SONO RELIABLE
    
        % -------------- post exercise (outcome) layer --------------
        
        glucoseStart = curr_session.cgmData{1,1}.cgmExercise.Glucose(1);
        glucoseEnd = curr_session.cgmData{1,1}.cgmExercise.Glucose(end);
        
        % exercise glucose excursion
        exerciseGlucoseExcursion = glucoseEnd - glucoseStart;
    
        % exercise glucose rate of change
        exerciseGlucoseRoc = exerciseGlucoseExcursion / ...
            minutes(curr_session.cgmData{1,1}.cgmExercise.Time(end) - ...
            curr_session.cgmData{1,1}.cgmExercise.Time(1));
    
        % minimum glucose value reached in the post exercise (6h after end)
        cgmPostExercise = curr_session.cgmData{1,1}.cgmPostExercise;
        minGlucosePostExercise = min(cgmPostExercise.Glucose(end));
    
        % time in range in the post exercise (6h after end)
        idx_TIR = find(cgmPostExercise.Glucose >= 70 & cgmPostExercise.Glucose <= 180);
        postExerciseTIR = (length(idx_TIR)/height(cgmPostExercise))*100;
    
        % glucose CV in the post exercise (6h after end)
        postExerciseGlucoseCV = (std(cgmPostExercise.Glucose) / mean(cgmPostExercise.Glucose)) * 100;
    
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
    tables_path = '/Users/albertogastaldello/Desktop/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTableForBN.mat"), "exerciseTableForBN");

end