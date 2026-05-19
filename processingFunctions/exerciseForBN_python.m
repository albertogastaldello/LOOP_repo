function exerciseForBN_python()

    exerciseTable = load("exerciseTableForBN.mat").exerciseTableForBN;

    exerciseTableForBN_python = exerciseTable;

    colsToRemove = ["insulinData", "cgmData", "reportedMealData", "finalMealData"];
    exerciseTableForBN_python = removevars(exerciseTableForBN_python, colsToRemove);

    N = height(exerciseTableForBN_python);

    insSensitivity = zeros(N, 1);
    insCarbRatio = zeros(N, 1);

    timeSinceLastBolusStartEx = zeros(N, 1);
    lastBolusStartEx = zeros(N, 1);
    timeSinceLastBasalStartEx =  zeros(N, 1);
    lastBasalStartEx = zeros(N, 1);
    IOBStartEx = zeros(N, 1);
    IOBnormStartEx = zeros(N,1);

    timeSinceLastBolusEndEx = zeros(N, 1);
    lastBolusEndEx = zeros(N, 1);
    timeSinceLastBasalEndEx =  zeros(N, 1);
    lastBasalEndEx = zeros(N, 1);
    IOBnormEndEx = zeros(N,1);

    insulinDuringEx = zeros(N,1);

    for i = 1:N

        curr_insulinData = exerciseTable.insulinData{i,1};

        insSensitivity(i,1) = curr_insulinData.InsSensitivity;
        insCarbRatio(i,1) = curr_insulinData.InsCarbRatio;

        timeSinceLastBolusStartEx(i,1) = curr_insulinData.TimeSinceLastBolusStartEx;
        lastBolusStartEx(i,1) = curr_insulinData.LastBolusStartEx;
        timeSinceLastBasalStartEx(i,1) = curr_insulinData.TimeSinceLastBasalStartEx;
        lastBasalStartEx(i,1) = curr_insulinData.LastBasalStartEx;
        IOBStartEx(i,1) = curr_insulinData.IOBStartEx;
        IOBnormStartEx(i,1) = curr_insulinData.IOBnormStartEx;

        timeSinceLastBolusEndEx(i,1) = curr_insulinData.TimeSinceLastBolusEndEx;
        lastBolusEndEx(i,1) = curr_insulinData.LastBolusEndEx;
        timeSinceLastBasalEndEx(i,1) = curr_insulinData.TimeSinceLastBasalEndEx;
        lastBasalEndEx(i,1) = curr_insulinData.LastBasalEndEx;
        IOBnormEndEx(i,1) = curr_insulinData.IOBnormEndEx;
        
        if istable(curr_insulinData.insulinDuringEx)
            insulinDuringEx(i,1) = table2array(curr_insulinData.insulinDuringEx);
        else
            insulinDuringEx(i,1) = curr_insulinData.insulinDuringEx;
        end

    end

    exerciseTableForBN_python.InsSensitivity = insSensitivity;
    exerciseTableForBN_python.InsCarbRatio = insCarbRatio;

    exerciseTableForBN_python.IOBStartEx = IOBStartEx;
    exerciseTableForBN_python.IOBnormStartEx = IOBnormStartEx;
    exerciseTableForBN_python.TimeSinceLastBolusStartEx = timeSinceLastBolusStartEx;
    exerciseTableForBN_python.LastBolusStartEx = lastBolusStartEx;
    exerciseTableForBN_python.TimeSinceLastBasalStartEx = timeSinceLastBasalStartEx;
    exerciseTableForBN_python.LastBasalStartEx = lastBasalStartEx;

    exerciseTableForBN_python.IOBnormEndEx = IOBnormEndEx;
    exerciseTableForBN_python.TimeSinceLastBolusEndEx = timeSinceLastBolusEndEx;
    exerciseTableForBN_python.LastBolusEndEx = lastBolusEndEx;
    exerciseTableForBN_python.TimeSinceLastBasalEndEx = timeSinceLastBasalEndEx;
    exerciseTableForBN_python.LastBasalEndEx = lastBasalEndEx;

    exerciseTableForBN_python.InsulinDuringEx = insulinDuringEx;

    % save
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    parquetwrite(fullfile(tables_path,"exerciseTableForBN_python.parquet"), exerciseTableForBN_python);

end