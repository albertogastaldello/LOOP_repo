clc
clear all
close all

%%
addpath("tables/");
addpath("processingFunctions/");
base_path = '/Users/albertogastaldello/Desktop/PAxT1D_BN/LOOP_Data/Loop study public dataset 2023-01-31';
save_path = '/Users/albertogastaldello/Desktop/TESI_STELLA/LOOP_data';

dataTable = load("dataTablesStructure_withDateTime.mat").data_tables_all;

%%
subjIDs = fieldnames(dataTable);

cgmStruct = struct();
basalStruct = struct();
bolusStruct = struct();

for i=1:size(subjIDs,1)
    
    curr_subjID = subjIDs{i,1};
    curr_subjID_number = extractAfter(curr_subjID, '_');

    curr_Struct = dataTable.(curr_subjID);

    curr_timeZoneOffset = curr_Struct.roster.PtTimezoneOffset(1);

    cgm_data   = readtable(fullfile(base_path, ['data_type=cgm/patient_id=' num2str(curr_subjID_number)], 'cgm.csv'));
    basal_data = readtable(fullfile(base_path, ['data_type=basal/patient_id=' num2str(curr_subjID_number)], 'basal.csv'));
    bolus_data = readtable(fullfile(base_path, ['data_type=bolus/patient_id=' num2str(curr_subjID_number)], 'bolus.csv'));

    % remove datetime_aligned column from basal and bolus
    basal_data.datetime_aligned = [];
    bolus_data.datetime_aligned = [];

    % Force strings to UTC Datetime
    cgm_data.datetime = datetime(cgm_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    basal_data.datetime = datetime(basal_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    bolus_data.datetime = datetime(bolus_data.datetime, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');

    % Change column name
    cgm_data.Properties.VariableNames{'datetime'} = 'UTCDtTm';
    basal_data.Properties.VariableNames{'datetime'} = 'UTCDtTm';
    bolus_data.Properties.VariableNames{'datetime'} = 'UTCDtTm';

   
    % -------- REMOVE CGM DUPLICATES --------
    
    [uniqueTimes,~,ic] = unique(cgm_data.UTCDtTm);
    cgm_values = accumarray(ic, cgm_data.cgm, [], @mean);
    
    cgm_data = table(uniqueTimes, cgm_values, ...
        'VariableNames', {'UTCDtTm','cgm'});
    
    cgm_data = sortrows(cgm_data,'UTCDtTm');


    % -------- ALIGN BOLUS AND BASAL TO CGM (ADD DATE TIME ALIGNED COLUMN
    % TO THEM) ----------

    refTimes = cgm_data.UTCDtTm;
    minRef = min(refTimes);
    maxRef = max(refTimes);
    refNum   = datenum(refTimes);

    mask_bolus = (bolus_data.UTCDtTm >= minRef) & (bolus_data.UTCDtTm <= maxRef);
    bolusNum = datenum(bolus_data.UTCDtTm(mask_bolus));
    idx_bolus = knnsearch(refNum, bolusNum);
    bolus_data.UTCDtTm_aligned = bolus_data.UTCDtTm;
    bolus_data.UTCDtTm_aligned(mask_bolus) = refTimes(idx_bolus);

    mask_basal = (basal_data.UTCDtTm >= minRef) & (basal_data.UTCDtTm <= maxRef);
    basalNum = datenum(basal_data.UTCDtTm(mask_basal));
    idx_basal = knnsearch(refNum, basalNum);
    
    basal_data.UTCDtTm_aligned = basal_data.UTCDtTm;
    basal_data.UTCDtTm_aligned(mask_basal) = refTimes(idx_basal);


    % --------- APPLY TIME ZONE OFFSET ------
    cgm_data.DeviceDtTm = cgm_data.UTCDtTm + hours(curr_timeZoneOffset);
    bolus_data.DeviceDtTm = bolus_data.UTCDtTm + hours(curr_timeZoneOffset);
    basal_data.DeviceDtTm = basal_data.UTCDtTm + hours(curr_timeZoneOffset);
    bolus_data.DeviceDtTm_aligned = bolus_data.UTCDtTm_aligned + hours(curr_timeZoneOffset);
    basal_data.DeviceDtTm_aligned = basal_data.UTCDtTm_aligned + hours(curr_timeZoneOffset);

    % ---------- ADD CGM, BASAL AND BOLUS TO DATA TABLE STRUCTURE -----

    cgmStruct.(curr_subjID) = cgm_data;
    basalStruct.(curr_subjID) = basal_data;
    bolusStruct.(curr_subjID) = bolus_data;

end

%% save the data structure

save(fullfile(save_path, "dataStruct.mat"), "dataTable");
save(fullfile(save_path, "cgmStruct.mat"), "cgmStruct");
save(fullfile(save_path, "bolusStruct.mat"), "bolusStruct");
save(fullfile(save_path, "basalStruct.mat"), "basalStruct");