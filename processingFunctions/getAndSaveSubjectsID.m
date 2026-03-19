function getAndSaveSubjectsID(base_path, codePath)

    % get subjects ID

    [cgm_subjectsID_numeric, cgm_subjectsID]     = getSubjectsID(base_path, "cgm");
    [basal_subjectsID_numeric, basal_subjectsID] = getSubjectsID(base_path, "basal");
    [bolus_subjectsID_numeric, bolus_subjectsID] = getSubjectsID(base_path, "bolus");

    % save

    saveFolder = fullfile(codePath, 'subjectsID');
    if ~exist(saveFolder, 'dir')
        mkdir(saveFolder);
    end

    save(fullfile(saveFolder,"cgm_subjectsID.mat"), "cgm_subjectsID");
    save(fullfile(saveFolder,"cgm_subjectsID_numeric.mat"), "cgm_subjectsID_numeric");

    save(fullfile(saveFolder,"bolus_subjectsID.mat"), "bolus_subjectsID");
    save(fullfile(saveFolder,"bolus_subjectsID_numeric.mat"), "bolus_subjectsID_numeric");

    save(fullfile(saveFolder,"basal_subjectsID.mat"), "basal_subjectsID");
    save(fullfile(saveFolder,"basal_subjectsID_numeric.mat"), "basal_subjectsID_numeric");
 

end


% subfunction

function [subjectsID_numeric, subjectsID] = getSubjectsID(base_path, data_type)

    folders = dir(fullfile(base_path, "data_type=" + data_type));

    folders = folders([folders.isdir]);
    folders = folders(~ismember({folders.name}, {'.', '..'}));
    folder_names = {folders.name};
    
    n_subj = size(folder_names, 2);
    
    subjectsID_numeric = zeros(1, n_subj);
    
    for i = 1:n_subj
        curr_folder_name = folder_names{1,i};
        curr_subjectID = curr_folder_name(12:end);
        curr_subjectID_numeric = str2double(curr_subjectID);
        subjectsID_numeric(1, i) = curr_subjectID_numeric;
    end
    
    subjectsID_numeric = sort(subjectsID_numeric);
    subjectsID = string(subjectsID_numeric);

end