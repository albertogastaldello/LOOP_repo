
# STEPS TO PERFORM TO MANIPOLATE DATA AND CREATE USEFUL STRUCTURES FOR 
# FURTHER ANALYSIS


# 1. processed LOOP data (basal, bolus and cgm) using Babelbetes code. 
# Obtained patient-level output files in .parquet format. 
# Used a simple code to transform them into .csv files. 
# All necessary files are present in LOOP_data folder.

# 2. getAndSaveSubjectsID.m file to save the subjects ID of 
# cgm, bolus and basal files.

# 3. findCommonSubjects.m file to find the subjects present simultaneously 
# in roster data table, bolus, basal and cgm files. 
# These subjects' ID are saved in common_subjectsID_numeric.mat and 
# common_subjectsID_numeric.mat

# 4. adjustAndSaveDataTables.m file to load interesting data tables, 
# extract and save each subject time zone offset in 
# subjectsTimeZoneOffset.mat data, find subjects who dropped and save their 
# IDs in droppedSubjectsID.mat, change date format where needed, then save 
# for each subject the corresponding rows of each data table in 
# LOOP_data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects

# 5. alignBolusAndBasal.m to align basal and bolus datetime with the
# cgm datetime. Tables are override and can be found in 
# LOOP_data/Loop study public dataset 2023-01-31/data_type={basal/bolus/cgm}

# 6. createDataTablesStructure.m file to create and save a unique structure
# (dataTablesStructure.mat) that contains the data tables information 
# divided by subjects

# 7. addDateTime.m file to loop on each subject and apply the time zone 
# offset present in roster data to the column 'UTCDtTm' of BGM, food and 
# exercise tables. The obtained datetimes are placed in the 'DeviceDtTm' 
# column if NaN or NaT are present. Also, these three tables are sorted in 
# chronological order based on the updated 'DeviceDtTm' column. 
# The structure is saved as dataTablesStructure_withDateTime.mat.

# 8. createExerciseTable.m to first intersect common_subjectsID.mat with
# subjects that have wizard data. The ID of the intersected subjects are
# saved in commonWizard_subjectsID.mat. Then it creates a table for each 
# exercise session with all information.
# The table is saved as exerciseTable.mat


# 9. filterExerciseSessions.m to filter the exercise table removing 
# duplicates, sessions completely contained in others, 
# sessions that overlap, and sessions too close in time. The filtered
# exercise table is saved as exerciseTable_filtered.mat


# 10. exerciseWithWearableData.m to load exerciseTable_filtered.mat, 
# remove exercise sessions that last less than 5 minutes and that have few 
# cgm data, and add wearable data around each exercise session (cgm, insulin, meals). 
# The table is saved as exerciseTableWithWearableData.mat


# 11. exerciseForBN.m to load exerciseTableWithWearableData.mat, and compute various  
# metrics useful for the developing of Bayesian Network. 
# The table is saved as exerciseTableForBN.mat

# 12. exerciseForBN_python.m to convert exerciseTableForBN.mat in a table 
# that can be used in Python. The file is saved as exerciseTableForBN_python.parquet


# -------------------------------------------------------------------
# AUXILIARY SCRIPTS TO PERFORM ANALYSIS OR GENERAL OVERVIEW

# heatmapFewCgmData.m: load exerciseTable_filtered.mat and saves in a matrix
# (cgmThresholdGridSearch.mat) the number of sessions that remain after
# filtering for few cgm data with different thresholds. Then, it visualizes
# the matrix with a heatmap


# datasetOverview.m: load subjects of interests (all subjects, 
# common_subjects or commonWizard_subjects) and get an overview of 
# demographics and other general information


# exerciseCharacterization.m: load exerciseTableForBN.mat and evaluates the 
# distribution of activity per activity type, per subject and combined.
# Also, it evaluates and visualizes the distribution of some parameters 
# (glucose RoC, METs, duration, ...) among the different type of activities 


# groupSimilarExercise.m: to group activities based on name or some metrics
# (to be developed)


# insulinDataAnalysis.m: evaluate and visualize IOB availability across 
# exercise sessions for exerciseTableForBN.mat.
# load dataTablesStructure_withDateTime and bolus + 
# basal data and evaluates and visualizes insulin-carb correlation and 
# insulin table data with wizard data


# visualizeData.m: choose a subject and plot CGM with meals, exercise, and
# bolus + basal


# visualizeExerciseSession.m to visualize one random exercise session
# from the "exerciseTableWithWearableData.mat" structure. In particular,
# visualize CGM data around the session, with start time and end time,
# reported meals, and other info in the figure title 