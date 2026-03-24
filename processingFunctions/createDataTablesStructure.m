function createDataTablesStructure(code_path, base_path)
    % create data tables structure for all subjects
    
    common_subjectsID = load("common_subjectsID_numeric.mat").common_subjectsID_numeric;
    n_common_subjects = length(common_subjectsID);
    
    base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31/DataTablesCommonSubjects';
    
    data_tables_all = struct();
    
    % Only suppress the harmless variable naming warning
    warn_id = 'MATLAB:table:ModifiedAndSavedVarnames';
    warning('off', warn_id);
    
    for i=1:n_common_subjects
    
        curr_subjID = common_subjectsID(i);
        subj_folder = fullfile(base_path, "patient_id=" + num2str(curr_subjID));
    
        csv_files = dir(fullfile(subj_folder, '*.csv'));
    
        subj_data = struct();
    
        for j = 1:length(csv_files)
            file_name = csv_files(j).name;
            [~, field_name, ~] = fileparts(file_name);
            
            % Generate import options specifically for this file
            opts = detectImportOptions(fullfile(subj_folder, file_name));
            
            % Force all 'datetime' guessing to just be 'string' or 'char'
            % This prevents MATLAB from guessing American vs European dates
            varTypes = opts.VariableTypes;
            dateCols = strcmp(varTypes, 'datetime');
            opts.VariableTypes(dateCols) = {'string'};
            
            % Read the table using the safe options
            tbl = readtable(fullfile(subj_folder, file_name), opts);
            subj_data.(field_name) = tbl;
        end
    
        data_tables_all.("patient_" + num2str(curr_subjID)) = subj_data;
    end
    
    % Restore the warning
    warning('on', warn_id);
    
    % save data tables structure
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "dataTablesStructure.mat"), "data_tables_all");
end