function groupSimilarExercise()

% load exercise table

exercise = load("exerciseTable.mat").exercise_table;

% group similar activities

unique_activities = unique(exercise.CleanActivityName);

snowActivities = ["Downhill Skiing", "Snowboarding", "Snow Sports"];
stairsActivities = ["StairClimbing", "Stairs"];
cardioActivities = ["Mixed Metabolic Cardio Training", "Mixed Cardio"];
strengthActivities = ["Functional Strength Training", ...
    "Traditional Strength Training"];

end
