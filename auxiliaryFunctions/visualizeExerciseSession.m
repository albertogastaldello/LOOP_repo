function visualizeExerciseSession()

    % load filtered exercise table
    exercise = load("exerciseTableWithWearableData.mat").exercise_valid;
    
    % choose a session and visualize
    
    i=randi(height(exercise));
    
    cgmPreExercise = exercise.cgmData{i,1}.cgmPreExercise;
    cgmExercise = exercise.cgmData{i,1}.cgmExercise;
    cgmPostExercise = exercise.cgmData{i,1}.cgmPostExercise;
    
    cgm = [cgmPreExercise; cgmExercise; cgmPostExercise];
    
    startExercise = exercise.DeviceDtTm(i);
    endExercise = startExercise + minutes(exercise.DurationValue(i));
    
    mealData = exercise.mealData{i,1};
    
    figure()
    yyaxis left
    plot(cgm.Time, cgm.Glucose)
    hold on
    xline(startExercise, 'r--', 'LineWidth', 1.5)
    xline(endExercise, 'r--', 'LineWidth', 1.5)
    ylabel('Glucose (mg/dl)')
    
    yyaxis right
    stem(mealData.DeviceDtTm, mealData.CarbsNet)
    ylabel('Carbs (g)')
    
    xlabel('Time')
    
    title(sprintf('%s | Duration: %d minutes | Age: %d', ...
        exercise.CleanActivityName{i}, ...
        exercise.DurationValue(i), ...
        exercise.age(i)))

end