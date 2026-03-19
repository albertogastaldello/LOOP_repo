function datasetOverview()

    % load subjects structure and save dataset overview information
    
    allSubjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
    commonWizard_subjectsID = load("commonWizard_subjectsID.mat").commonWizard_subjectsID;
    
    fieldsCommonWizard = "patient_" + commonWizard_subjectsID;
    all_fields = string(fieldnames(allSubjectsStruct));
    fields_valid = intersect(all_fields, fieldsCommonWizard);
    subjectsStruct = rmfield(allSubjectsStruct, setdiff(all_fields, fields_valid));
    
    subjectsInfo = struct();
    
    subjects = fieldnames(subjectsStruct);
    n_subjects = size(subjects,1);
    
    info_fields = ["ageAtBaseline", "gender", "height_cm", "weight_kg"];
    
    for j=1:length(info_fields)
        subjectsInfo.(info_fields(j)) = getSurveyInfo(subjectsStruct, n_subjects, subjects, info_fields(j));
    end
    
    subjectsInfo.bmi = subjectsInfo.weight_kg ./ ((subjectsInfo.height_cm/100).^2);
    
    hba1c_vector = zeros(1,n_subjects);
    for i=1:n_subjects
        if(~isempty(subjectsStruct.(subjects{i,1}).sampleResults))
            curr_hba1c = subjectsStruct.(subjects{i,1}).sampleResults.Value(1);
            hba1c_vector(1,i) = curr_hba1c;
        else
            hba1c_vector(1,i) = NaN;
        end
    end
    
    
    % visualize overview information
    hba1c_vector = hba1c_vector(~isnan(hba1c_vector));
    nbins = 30;
    
    figure()
    histogram(subjectsInfo.ageAtBaseline, nbins)
    title("Age at baseline")
    
    figure()
    histogram(subjectsInfo.bmi, nbins)
    title("BMI")
    
    figure()
    histogram(hba1c_vector, nbins)
    title("HbA1c")
    
    
    for j=1:length(info_fields)
        mirroredHistogram(subjectsInfo.(info_fields(j)), info_fields(j)) 
    end
    
    hba1c_vector = hba1c_vector(~isnan(hba1c_vector));
    mirroredHistogram(hba1c_vector,'HbA1c');
    
    mirroredHistogram(subjectsInfo.bmi, 'bmi');
    
    figure()
    x = subjectsInfo.weight_kg;
    y = subjectsInfo.height_cm;
    z = subjectsInfo.ageAtBaseline;
    
    scatter(x, y, 50, z, 'filled');
    grid on;
    colormap('parula');
    colorbar;
    
    xlabel('Weight (kg)')
    ylabel('Height (cm)')
    title('Height vs Weight with gradient based on age')

end

% function for mirrored histogram
function mirroredHistogram(vector, name)

    vector = vector(:);
    vector = vector(~isnan(vector));

    [counts, values] = groupcounts(vector);
    binCenters = values;

    figure
    hold on
    barh(binCenters,  counts, 'FaceColor',[0 0.7 0], ...
         'EdgeColor','k', 'FaceAlpha',0.5)
    barh(binCenters, -counts, 'FaceColor',[0 0.7 0], ...
         'EdgeColor','k', 'FaceAlpha',0.5)

    xlabel('Counts')
    ylabel(name)
    title([name, ' distribution'])
    grid on
    hold off
end


% function to get subjects'vector of a chosen field of surveys table

function info_vector = getSurveyInfo(subjectsStruct, n_subjects, subjects, info_field)
    
    info_vector = zeros(1,n_subjects);

    for i=1:n_subjects
        curr_survey_table = subjectsStruct.(subjects{i,1}).surveys;
        info_vector(1,i) = curr_survey_table.(info_field)(1);
    end

end

