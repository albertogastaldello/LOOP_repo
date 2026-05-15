function stats = filterExerciseSessions()

    % ================= LOAD DATA =================
    exerciseTable = load("exerciseTable.mat").exercise_table;
    subjIDs       = unique(exerciseTable.PtID);
    
    % ================= LOG INIZIALI =================
    nullDurationLog = table();
    duplicateLog  = table();
    containedLog  = table();
    overlapLog    = table();
    shortDurationLog = table();
    
    pairCounterDup      = 0;
    pairCounterContained = 0;
    pairCounterOverlap   = 0;

    totalRemovedNullDuration = 0;
    totalRemovedDup = 0;
    totalRemovedContained = 0;
    totalRemovedOverlap = 0;
    totalRemovedShortDuration = 0;

    initialCount = height(exerciseTable);
    
    exerciseTable_clean = table();
    
    % ================= LOOP SU TUTTI I SOGGETTI =================
    for i = 1:length(subjIDs)
    
        curr_subjID   = subjIDs(i);
        curr_sessions = exerciseTable(exerciseTable.PtID == curr_subjID, :);
    
        % Ordina temporalmente
        curr_sessions = sortrows(curr_sessions, "UTCDtTm");

        startCount = height(curr_sessions);

        % ===== STEP 1: REMOVE DURATION = 0 =====
        [curr_sessions_removedNullDuration, nullDurationLog] = removeNullDuration(curr_sessions, nullDurationLog);
        totalRemovedNullDuration = totalRemovedNullDuration + (startCount - height(curr_sessions_removedNullDuration));

        % ===== STEP 2: REMOVE DUPLICATES =====
        countBefore2 = height(curr_sessions_removedNullDuration);
        [curr_sessions_removedDuplicates, pairCounterDup, duplicateLog] = ...
            removeDuplicates(curr_sessions_removedNullDuration, pairCounterDup, duplicateLog);
        totalRemovedDup = totalRemovedDup + (countBefore2 - height(curr_sessions_removedDuplicates));
    
        % ===== STEP 3: REMOVE CONTAINED SESSIONS =====
        countBefore3 = height(curr_sessions_removedDuplicates);
        [curr_sessions_removedContained, pairCounterContained, containedLog] = ...
            removeContainedSessions(curr_sessions_removedDuplicates, pairCounterContained, containedLog);
        totalRemovedContained = totalRemovedContained + (countBefore3 - height(curr_sessions_removedContained));
    
        % ===== STEP 4: HANDLE PARTIAL OVERLAP =====
        countBefore4 = height(curr_sessions_removedContained);
        [curr_sessions_removedOverlap, pairCounterOverlap, overlapLog] = ...
            handlePartialOverlap(curr_sessions_removedContained, pairCounterOverlap, overlapLog);
        totalRemovedOverlap = totalRemovedOverlap + (countBefore4 - height(curr_sessions_removedOverlap));

        % ===== STEP 5: REMOVE SESSIONS WITH DURATION LESS THAN 5 MINUTES
        countBefore5 = height(curr_sessions_removedOverlap);
        [curr_sessions_removedShortDuration, shortDurationLog] = ...
            removeShortDuration(curr_sessions_removedOverlap, shortDurationLog);
        totalRemovedShortDuration = totalRemovedShortDuration + (countBefore5 - height(curr_sessions_removedShortDuration));
        
        % add average number of sessions per week for each subject
        if ~ isempty(curr_sessions_removedShortDuration)
            if height(curr_sessions_removedShortDuration) == 1
                curr_sessions_removedShortDuration.avgSessionsPerWeek = NaN;
            else
                firstExerciseDay = curr_sessions_removedShortDuration.UTCDtTm(1);
                lastExerciseDay = curr_sessions_removedShortDuration.UTCDtTm(end);
                exerciseWeeks = (days(lastExerciseDay - firstExerciseDay))/7;
                avgSessionsPerWeek = height(curr_sessions_removedShortDuration)/exerciseWeeks;
                curr_sessions_removedShortDuration.avgSessionsPerWeek = ...
                repmat(avgSessionsPerWeek, height(curr_sessions_removedShortDuration), 1);
            end

            % ===== STEP 6: ACCUMULA TABELLA PULITA =====
            exerciseTable_clean = [exerciseTable_clean; curr_sessions_removedShortDuration];

        end

    end

    stats.InitialSessions = initialCount;
    stats.CleanedSessions = height(exerciseTable_clean);
    stats.TotalRemoved    = initialCount - height(exerciseTable_clean);

    stats.ByFilter.NullDuration = totalRemovedNullDuration;
    stats.ByFilter.Duplicates = totalRemovedDup;
    stats.ByFilter.Contained  = totalRemovedContained;
    stats.ByFilter.Overlap    = totalRemovedOverlap;
    stats.ByFilter.ShortDuration = totalRemovedShortDuration;
    
    % save filtered exercise table
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTable_filtered.mat"), "exerciseTable_clean");

end
    
% ================= FUNZIONI DI FILTRAGGIO =================

% REMOVE NULL DURATION SESSIONS
function [curr_sessions, nullDurationLog] = removeNullDuration(curr_sessions, nullDurationLog)
    nullDurationIndices = find(curr_sessions.DurationValue == 0);
    if ~isempty(nullDurationIndices)
        nullDurationLog = [nullDurationLog; curr_sessions(nullDurationIndices,:)];
        curr_sessions(nullDurationIndices,:) = [];
    end
end


% REMOVE DUPLICATE SESSIONS
function [curr_sessions, pairCounterDup, duplicateLog] = removeDuplicates(curr_sessions, pairCounterDup, duplicateLog)
    startTimes = curr_sessions.UTCDtTm;
    activity   = curr_sessions.CleanActivityName;

    rowsToRemove = [];
    if height(curr_sessions) > 1
        deltaT       = minutes(diff(startTimes));
        sameActivity = strcmp(activity(1:end-1), activity(2:end));
        isDuplicate  = sameActivity & deltaT < 5;
        dupIdx       = find(isDuplicate);
        
        for idx = 1:length(dupIdx)
            k = dupIdx(idx);
            pairCounterDup = pairCounterDup + 1;

            row1 = curr_sessions(k,:);
            row2 = curr_sessions(k+1,:);

            nMissing1 = sum(ismissing(row1), 2);
            nMissing2 = sum(ismissing(row2), 2);

            if nMissing1 > nMissing2
                keepIdx   = k+1;
                removeIdx = k;
            else
                keepIdx   = k;
                removeIdx = k+1;
            end

            % Log duplicati
            pairTable       = curr_sessions([k k+1], :);
            pairTable.PairID = repmat(pairCounterDup, 2, 1);

            status = strings(2,1);
            status([k k+1] == keepIdx)   = "Kept";
            status([k k+1] == removeIdx) = "Removed";

            pairTable.Status = status;
            duplicateLog = [duplicateLog; pairTable];

            rowsToRemove(end+1) = removeIdx;
        end

        % Rimuovi duplicati
        curr_sessions(rowsToRemove,:) = [];
    end
end


% REMOVE CONTAINED SESSIONS
function [curr_sessions, pairCounterContained, containedLog] = removeContainedSessions(curr_sessions, pairCounterContained, containedLog)
    startTimes = curr_sessions.UTCDtTm;
    validDuration = ~isnan(curr_sessions.DurationValue);
    endTimes = startTimes;
    endTimes(validDuration) = startTimes(validDuration) + minutes(curr_sessions.DurationValue(validDuration));

    rowsToRemove = [];
    if height(curr_sessions) > 1
        for k = 1:height(curr_sessions)-1
            for j = k+1:height(curr_sessions)
                % sessione j contained in k?
                if startTimes(j) >= startTimes(k) && endTimes(j) <= endTimes(k)
                    pairCounterContained = pairCounterContained + 1;
                    rowsToRemove(end+1) = j;

                    % log
                    logTable = curr_sessions([k j], :);
                    logTable.ContainedPairID = repmat(pairCounterContained, 2, 1);
                    logTable.ContainedDecision = ["Kept"; "Removed"];
                    containedLog = [containedLog; logTable];

                % oppure sessione k contained in j?
                elseif startTimes(k) >= startTimes(j) && endTimes(k) <= endTimes(j)
                    pairCounterContained = pairCounterContained + 1;
                    rowsToRemove(end+1) = k;

                    logTable = curr_sessions([j k], :);
                    logTable.ContainedPairID = repmat(pairCounterContained, 2, 1);
                    logTable.ContainedDecision = ["Kept"; "Removed"];
                    containedLog = [containedLog; logTable];
                end
            end
        end
        % rimuovi contained
        curr_sessions(unique(rowsToRemove), :) = [];
    end
end


% HANDLE PARTIAL OVERLAP (PER ORA TENGO SOLO LA PRIMA SESSIONE)
function [curr_sessions, pairCounterOverlap, overlapLog] = handlePartialOverlap(curr_sessions, pairCounterOverlap, overlapLog)
    startTimes = curr_sessions.UTCDtTm;
    validDuration = ~isnan(curr_sessions.DurationValue);
    endTimes = startTimes;
    endTimes(validDuration) = startTimes(validDuration) + minutes(curr_sessions.DurationValue(validDuration));

    rowsToRemove = [];

    if height(curr_sessions) > 1
        for k = 1:height(curr_sessions)-1
            % controlla se c'è sovrapposizione tra la sessione k e k+1
            if startTimes(k+1) <= endTimes(k)
                pairCounterOverlap = pairCounterOverlap + 1;

                % salva log
                overlapPair = curr_sessions([k k+1], :);
                overlapPair.OverlapPairID = repmat(pairCounterOverlap, 2, 1);
                overlapPair.OverlapOrder  = ["First"; "Second"];
                overlapPair.CalculatedEndTime = [endTimes(k); endTimes(k+1)];
                overlapLog = [overlapLog; overlapPair];

                % marca la seconda sessione da rimuovere
                rowsToRemove(end+1) = k+1;
            end
        end

        % rimuovi le sessioni duplicate o sovrapposte
        curr_sessions(unique(rowsToRemove), :) = [];
    end
end


% REMOVE SHORT DURATION SESSIONS
function [curr_sessions, shortDurationLog] = removeShortDuration(curr_sessions, shortDurationLog)
    shortDurationIndices = find(curr_sessions.DurationValue < 5);
    if ~isempty(shortDurationIndices)
        shortDurationLog = [shortDurationLog; curr_sessions(shortDurationIndices,:)];
        curr_sessions(shortDurationIndices,:) = [];
    end
end