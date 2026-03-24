function addDateTime()
    % load subjects structure
    data_tables_all = load('dataTablesStructure.mat').data_tables_all;
    
    % loop on subjects
    n_subj = numel(fieldnames(data_tables_all));
    subjectsID = fieldnames(data_tables_all);
    
    % Tables we need to process
    tables_to_process = {'BGM', 'exercise', 'food', 'wizard'};
    
    for i=1:n_subj
        curr_subjStruct = data_tables_all.(subjectsID{i,1});
        
        % get current subject's time zone offset
        % (Assuming roster only has 1 row per subject here)
        curr_timeZoneOffset = curr_subjStruct.roster.PtTimezoneOffset(1); 
        
        for t = 1:length(tables_to_process)
            t_name = tables_to_process{t};
            
            if isfield(curr_subjStruct, t_name) && ~isempty(curr_subjStruct.(t_name))
                curr_table = curr_subjStruct.(t_name);
                
                % 1. Convert UTCDtTm from string to datetime
                if isstring(curr_table.UTCDtTm) || iscellstr(curr_table.UTCDtTm)
                    % Let MATLAB auto-detect the standard format (yyyy-MM-dd HH:mm:ss)
                    curr_table.UTCDtTm = datetime(curr_table.UTCDtTm);
                end
                
                % 2. Convert DeviceDtTm from string to datetime (handling missing values)
                if isstring(curr_table.DeviceDtTm) || iscellstr(curr_table.DeviceDtTm)
                    % Find missing strings ("" or <missing>)
                    missing_mask = ismissing(curr_table.DeviceDtTm);
                    
                    % Convert to datetime (missing ones become NaT)
                    curr_table.DeviceDtTm = datetime(curr_table.DeviceDtTm);
                    
                    % 3. Apply the Babelbetes UTC + Offset rule to the missing rows
                    if any(missing_mask)
                        curr_table.DeviceDtTm(missing_mask) = ...
                            curr_table.UTCDtTm(missing_mask) + hours(curr_timeZoneOffset);
                    end
                end
                
                % 4. Sort chronologically by UTC (Safeguard against DST paradoxes)
                curr_table = sortrows(curr_table, 'UTCDtTm');
                
                % Save updated table back to struct
                curr_subjStruct.(t_name) = curr_table;
            end
        end
        
        % 5. remove possible duplicates in exercise table and remove not valid entries
        if isfield(curr_subjStruct, 'exercise') && ~isempty(curr_subjStruct.exercise)
            % Unique based on UTCDtTm to ensure strict chronological uniqueness
            [~, unique_exercise_indices] = unique(curr_subjStruct.exercise.UTCDtTm, 'stable');
            curr_subjStruct.exercise = curr_subjStruct.exercise(unique_exercise_indices, :);
    
            % Remove empty ExerciseName rows
            valid_mask = ~ismissing(curr_subjStruct.exercise.ExerciseName) & ...
                         strlength(strtrim(curr_subjStruct.exercise.ExerciseName)) > 0;
            curr_subjStruct.exercise = curr_subjStruct.exercise(valid_mask, :);
        end
        
        % update subject structure
        data_tables_all.(subjectsID{i,1}) = curr_subjStruct;
    end
    
    % save updated subjects structure
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "dataTablesStructure_withDateTime.mat"), "data_tables_all");
    disp('DateTime conversion and chronological sorting complete!');
end