function heatmapFewCgmData()

    preThrVec    = 0.60:0.05:0.95;
    duringThrVec = 0.60:0.05:0.95;
    postThrVec   = 0.50:0.05:0.90;

    % Load filtered exercise table
    exercise = load("exerciseTable_filtered.mat").exerciseTable_clean;

    nTotalSessions = height(exercise);

    percPre_all    = zeros(nTotalSessions,1);
    percDuring_all = zeros(nTotalSessions,1);
    percPost_all   = zeros(nTotalSessions,1);

    sessionCounter = 0;
    
    base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31';
    subjectsStruct = load("dataTablesStructure_withDateTime.mat").data_tables_all;
    
    % Columns of meals data to keep
    mealColumsToKeep = ["PtID", "RecID", "DeviceDtTm", "UTCDtTm", ...
                        "CarbsNet", "CarbUnits", "TmZnOffset"];
    
    subjectsID = unique(exercise.PtID);

    hoursPreExercise = 2;
    hoursPostExercise = 6;
    
    shortSessions_counter = 0;

    % Loop over subjects
    for i = 1:length(subjectsID)

        disp(['Processing subject ' num2str(i) ' of ' num2str(length(subjectsID))]);
        
        curr_subjID = subjectsID(i);
        struct_patientField = ['patient_' num2str(curr_subjID)];
        curr_exercise = exercise(exercise.PtID == curr_subjID,:);
        
        % Load subject data once
        cgm_data   = readtable(fullfile(base_path, ['data_type=cgm/patient_id=' num2str(curr_subjID)], 'cgm.csv'));

        % Force Babelbetes strings to UTC Datetime
        cgm_data.datetime = datetime(cgm_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
      
        
        % -------- REMOVE CGM DUPLICATES --------
        
        [uniqueTimes,~,ic] = unique(cgm_data.datetime);
        cgm_values = accumarray(ic, cgm_data.cgm, [], @mean);
        
        cgm_data = table(uniqueTimes, cgm_values, ...
            'VariableNames', {'datetime','cgm'});
        
        cgm_data = sortrows(cgm_data,'datetime');
        
        % -------- SUBJECT DATA --------

        maxSamples_preExercise  = floor((hoursPreExercise * 60) / 5) + 1;
        maxSamples_postExercise = floor((hoursPostExercise * 60) / 5) + 1;
        
        % -------- LOOP SESSIONS --------
        
        for j = 1:height(curr_exercise)
            
            curr_session = curr_exercise(j,:);

            startExercise = curr_session.UTCDtTm;
            exerciseDuration = curr_session.DurationValue;
            endExercise   = startExercise + minutes(exerciseDuration);
            
            preExercise   = startExercise - hours(hoursPreExercise);
            postExercise  = endExercise + hours(hoursPostExercise);
            
            % filter sessions shorter than 10 minutes
            if exerciseDuration < 10 
                shortSessions_counter = shortSessions_counter + 1;
                continue
            end
            
            
            % -------- CGM WINDOWS --------
            
            idxExercise = cgm_data.datetime >= startExercise & ...
                cgm_data.datetime <= endExercise;
            idxPre = cgm_data.datetime >= preExercise & ...
                cgm_data.datetime <= startExercise;
            idxPost = cgm_data.datetime >= endExercise & ...
                cgm_data.datetime <= postExercise;


            maxSamples_during = floor(exerciseDuration / 5) + 1;
            
            
            % Minimum number of points
            percPre    = sum(idxPre)      / max(maxSamples_preExercise,1);
            percDuring = sum(idxExercise) / max(maxSamples_during,1);
            percPost   = sum(idxPost)     / max(maxSamples_postExercise,1);
            
            % salva SEMPRE la sessione (non filtriamo più qui)
            sessionCounter = sessionCounter + 1;
            percPre_all(sessionCounter)    = percPre;
            percDuring_all(sessionCounter) = percDuring;
            percPost_all(sessionCounter)   = percPost;
            
        end


    end

    percPre_all    = percPre_all(1:sessionCounter);
    percDuring_all = percDuring_all(1:sessionCounter);
    percPost_all   = percPost_all(1:sessionCounter);
    
    nPre    = length(preThrVec);
    nDuring = length(duringThrVec);
    nPost   = length(postThrVec);

    validSessionsMatrix = zeros(nPre, nDuring, nPost);

    for i = 1:nPre
        for j = 1:nDuring
            for k = 1:nPost
            
                thrPre    = preThrVec(i);
                thrDuring = duringThrVec(j);
                thrPost   = postThrVec(k);
            
                validMask = percPre_all    >= thrPre & ...
                        percDuring_all >= thrDuring & ...
                        percPost_all   >= thrPost;
            
                validSessionsMatrix(i,j,k) = sum(validMask);
            
            end
        end
    end

    disp(['Total sessions analysed: ' num2str(sessionCounter)])
    disp(['Short sessions removed: ' num2str(shortSessions_counter)])

    save('cgmThresholdGridSearch.mat', ...
     'validSessionsMatrix', ...
     'preThrVec', 'duringThrVec', 'postThrVec');

    visualizeHeatmap(validSessionsMatrix, preThrVec, duringThrVec, postThrVec);
    
end

function visualizeHeatmap(validSessionsMatrix, preThrVec, duringThrVec, postThrVec)

    nDuring = length(duringThrVec);
    
    figure('Color','w')
    tiledlayout(ceil(nDuring/3),3,'TileSpacing','compact')
    
    for j = 1:nDuring
        
        nexttile
        
        % slice 2D fissando la soglia DURING
        heatSlice = squeeze(validSessionsMatrix(:,j,:));
        
        imagesc(postThrVec, preThrVec, heatSlice)
        set(gca,'YDir','normal')
        
        colormap(parula)
        colorbar
        
        title(['During ≥ ' num2str(duringThrVec(j),'%.2f')])
        xlabel('Post-exercise CGM coverage')
        ylabel('Pre-exercise CGM coverage')
        
        % mostra i numeri dentro la heatmap (super utile!)
        for r = 1:length(preThrVec)
            for c = 1:length(postThrVec)
                text(postThrVec(c), preThrVec(r), ...
                    num2str(heatSlice(r,c)), ...
                    'HorizontalAlignment','center', ...
                    'FontSize',8,'Color','k','FontWeight','bold')
            end
        end
        
    end
    
    sgtitle('Valid exercise sessions vs CGM coverage thresholds', ...
        'FontSize',16,'FontWeight','bold')

end