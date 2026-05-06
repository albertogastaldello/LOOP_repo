function exerciseForBN_python()

    exerciseTable = load("exerciseTableForBN.mat").exerciseTableForBN;

    exerciseTableForBN_python = exerciseTable;

    colsToRemove = ["insulinData", "cgmData", "reportedMealData", "finalMealData"];
    exerciseTableForBN_python = removevars(exerciseTableForBN_python, colsToRemove);

    N = height(exerciseTableForBN_python);

    insSensitivity = zeros(N, 1);
    insCarbRatio = zeros(N, 1);
    timeSinceLastBolus = zeros(N, 1);
    lastBolus = zeros(N, 1);
    timeSinceLastBasal =  zeros(N, 1);
    lastBasal = zeros(N, 1);
    IOB = zeros(N, 1);
    IOBnorm = zeros(N,1);

    for i = 1:N

        curr_insulinData = exerciseTable.insulinData{i,1};
        insSensitivity(i,1) = curr_insulinData.InsSensitivity;
        insCarbRatio(i,1) = curr_insulinData.InsCarbRatio;
        timeSinceLastBolus(i,1) = curr_insulinData.TimeSinceLastBolus;
        lastBolus(i,1) = curr_insulinData.LastBolus;
        timeSinceLastBasal(i,1) = curr_insulinData.TimeSinceLastBasal;
        lastBasal(i,1) = curr_insulinData.LastBasal;
        IOB(i,1) = curr_insulinData.IOB;
        IOBnorm(i,1) = curr_insulinData.IOBnorm;

    end

    exerciseTableForBN_python.InsSensitivity = insSensitivity;
    exerciseTableForBN_python.InsCarbRatio = insCarbRatio;
    exerciseTableForBN_python.IOB = IOB;
    exerciseTableForBN_python.IOBnorm = IOBnorm;
    exerciseTableForBN_python.TimeSinceLastBolus = timeSinceLastBolus;
    exerciseTableForBN_python.LastBolus = lastBolus;
    exerciseTableForBN_python.TimeSinceLastBasal = timeSinceLastBasal;
    exerciseTableForBN_python.LastBasal = lastBasal;

    % save
    tables_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_repo/tables/';
    parquetwrite(fullfile(tables_path,"exerciseTableForBN_python.parquet"), exerciseTableForBN_python);

end