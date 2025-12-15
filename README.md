# 1. processed LOOP data (basal, bolus and cgm) using Babelbetes code. Obtained patient-level output files in .parquet format. Used a simple code to transform them into .csv files. All necessary files are present in LOOP_data folder.

# 2. getAndSaveSubjectsID.m file to save the subjects ID of cgm, bolus and basal files.

# 3. findCommonSubjects.m file to find the subjects present simultaneously in roster data table, bolus, basal and cgm files. These subjects' ID are saved in common_subjectsID_numeric.mat and common_subjectsID_numeric.mat

# 4. adjustAndSaveDataTables.m file to load interesting data tables, extract and save each subject time zone offset in subjectsTimeZoneOffset.mat data, find subjects who dropped and save their IDs in droppedSubjectsID.mat, change date format where needed, then save for each subject the corresponding rows of each data table in LOOP_data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects

# 5. createDataTablesStructure.m file to create and save a unique structure (dataTablesStructure.mat) that contains the data tables information divided by subjects

# 6. addDateTime.m file to loop on each subject and apply the time zone offset present in roster data to the column 'UTCDtTm' of BGM, food and exercise tables. The obtained datetimes are placed in the 'DeviceDtTm' column if NaN or NaT are present. Also, these three tables are sorted in chronological order based on the updated 'DeviceDtTm' column.