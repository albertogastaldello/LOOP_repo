clc
clear all
close all

%% load subjects structure

data_tables_all = load('dataTablesStructure.mat').data_tables_all;

%% loop on subjects

n_subj = numel(fieldnames(data_tables_all));
subjectsID = fieldnames(data_tables_all);

for i=1:n_subj

    curr_subjStruct = data_tables_all.(subjectsID{i,1});

    % get current subject's time zone offset
    curr_timeZoneOffset = curr_subjStruct.roster.PtTimezoneOffset;

    % apply time zone offset where needed
    if(~isempty(curr_subjStruct.BGM))
        BGM_missing_indices = find(ismissing(curr_subjStruct.BGM.DeviceDtTm));
    
        if(~isempty(BGM_missing_indices))
            curr_subjStruct.BGM.DeviceDtTm(BGM_missing_indices) = curr_subjStruct.BGM.UTCDtTm(BGM_missing_indices) + hours(curr_timeZoneOffset);
        end
    end

    if(~isempty(curr_subjStruct.exercise))
        exercise_missing_indices = find(ismissing(curr_subjStruct.exercise.DeviceDtTm));
        curr_subjStruct.exercise.DeviceDtTm = datetime(curr_subjStruct.exercise.DeviceDtTm, 'ConvertFrom','datenum');

        if(~isempty(exercise_missing_indices))
            curr_subjStruct.exercise.DeviceDtTm(exercise_missing_indices) = curr_subjStruct.exercise.UTCDtTm(exercise_missing_indices) + hours(curr_timeZoneOffset);
        end
    end

    if(~isempty(curr_subjStruct.food))

        food_missing_indices = find(ismissing(curr_subjStruct.food.DeviceDtTm));
        curr_subjStruct.food.DeviceDtTm = datetime(curr_subjStruct.food.DeviceDtTm, 'ConvertFrom','datenum');

        if(~isempty(food_missing_indices))
            curr_subjStruct.food.DeviceDtTm(food_missing_indices) = curr_subjStruct.food.UTCDtTm(food_missing_indices) + hours(curr_timeZoneOffset);
        end
    end

    % sort tables in chronological order
    curr_subjStruct.BGM = sortrows(curr_subjStruct.BGM, 'DeviceDtTm');
    curr_subjStruct.exercise = sortrows(curr_subjStruct.exercise, 'DeviceDtTm');
    curr_subjStruct.food = sortrows(curr_subjStruct.food, 'DeviceDtTm');
    
    % update subject structure
    data_tables_all.(subjectsID{i,1}) = curr_subjStruct;

end

%% save updated subjects structure

save("dataTablesStructure_withDateTime.mat", "data_tables_all");

