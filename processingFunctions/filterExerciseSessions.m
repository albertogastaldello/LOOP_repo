function filterExerciseSessions()

    % ================= LOAD DATA =================
    exerciseTable = load("exerciseTable.mat").exercise_table;
    subjIDs       = unique(exerciseTable.PtID);
    
    % ================= LOG INIZIALI =================
    duplicateLog  = table();
    containedLog  = table();
    overlapLog    = table();
    tooCloseLog = table();
    pairCounterDup      = 0;
    pairCounterContained = 0;
    pairCounterOverlap   = 0;
    pairCounterTooClose = 0;
    
    exerciseTable_clean = table();
    
    % ================= LOOP SU TUTTI I SOGGETTI =================
    for i = 1:length(subjIDs)
    
        curr_subjID   = subjIDs(i);
        curr_sessions = exerciseTable(exerciseTable.PtID == curr_subjID, :);
    
        % Ordina temporalmente
        curr_sessions = sortrows(curr_sessions, "DeviceDtTm");
    
        % ===== STEP 1: REMOVE DUPLICATES =====
        [curr_sessions_removedDuplicates, pairCounterDup, duplicateLog] = ...
            removeDuplicates(curr_sessions, pairCounterDup, duplicateLog);
    
        % ===== STEP 2: REMOVE CONTAINED SESSIONS =====
        [curr_sessions_removedContained, pairCounterContained, containedLog] = ...
            removeContainedSessions(curr_sessions_removedDuplicates, pairCounterContained, containedLog);
    
        % ===== STEP 3: HANDLE PARTIAL OVERLAP =====
        [curr_sessions_removedOverlap, pairCounterOverlap, overlapLog] = ...
            handlePartialOverlap(curr_sessions_removedContained, pairCounterOverlap, overlapLog);
        % 
        % ===== STEP 4: REMOVE SESSIONS WITH PREVIOUS SESSION CLOSER THAN 6
        % HOURS
        % [curr_sessions_removedCloseSessions, pairCounterTooClose, tooCloseLog] = ...
        %     removeTooCloseSessions(curr_sessions_removedOverlap, pairCounterTooClose, tooCloseLog);
    
        % ===== STEP 5: ACCUMULA TABELLA PULITA =====
        exerciseTable_clean = [exerciseTable_clean; curr_sessions_removedOverlap];
        %exerciseTable_clean = [exerciseTable_clean; curr_sessions_removedCloseSessions];
    
    end
    
    % save filtered exercise table
    tables_path = '/Users/albertogastaldello/Desktop/LOOP_repo/tables/';
    save(fullfile(tables_path, "exerciseTable_filtered.mat"), "exerciseTable_clean");

end
    
% ================= FUNZIONI DI FILTRAGGIO =================

% REMOVE DUPLICATE SESSIONS
function [curr_sessions, pairCounterDup, duplicateLog] = removeDuplicates(curr_sessions, pairCounterDup, duplicateLog)
    startTimes = curr_sessions.DeviceDtTm;
    activity   = curr_sessions.CleanActivityName;

    if height(curr_sessions) > 1
        deltaT       = minutes(diff(startTimes));
        sameActivity = strcmp(activity(1:end-1), activity(2:end));
        isDuplicate  = sameActivity & deltaT < 5;

        dupIdx       = find(isDuplicate);
        rowsToRemove = [];

        for k = dupIdx'
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
    startTimes = curr_sessions.DeviceDtTm;
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
    startTimes = curr_sessions.DeviceDtTm;
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


% REMOVE SESSIONS THAT START WITHIN 6 HOURS AFTER THE END OF THE PREVIOUS
% SESSION
function [curr_sessions, pairCounterTooClose, tooCloseLog] = removeTooCloseSessions(curr_sessions, pairCounterTooClose, tooCloseLog)
    startTimes = curr_sessions.DeviceDtTm;
    validDuration = ~isnan(curr_sessions.DurationValue);
    endTimes = startTimes;
    endTimes(validDuration) = startTimes(validDuration) + minutes(curr_sessions.DurationValue(validDuration));

    rowsToRemove = [];

    if height(curr_sessions) > 1
        for k = 1:height(curr_sessions)-1
            % se la sessione successiva inizia entro 6 ore dalla fine della precedente
            if startTimes(k+1) <= endTimes(k) + hours(6)
                pairCounterTooClose = pairCounterTooClose + 1;

                % salva log
                tooClosePair = curr_sessions([k k+1], :);
                tooClosePair.TooClosePairID = repmat(pairCounterTooClose, 2, 1);
                tooClosePair.TooCloseOrder  = ["First"; "Second"];
                tooClosePair.FirstEndTime   = [endTimes(k); endTimes(k+1)];
                tooCloseLog = [tooCloseLog; tooClosePair];

                % marca la seconda sessione da rimuovere
                rowsToRemove(end+1) = k+1;
            end
        end

        % rimuovi le sessioni troppo vicine
        curr_sessions(unique(rowsToRemove), :) = [];
    end
end

