clc
clear all
close all

%% load cgm, basal and bolus data

common_subjectsID = load("common_subjectsID.mat").common_subjectsID;
base_path = '/Users/albertogastaldello/Desktop/LOOP_Data/Loop study public dataset 2023-01-31';

for i=1:length(common_subjectsID)

    subjID = common_subjectsID(i);

    cgm_path = strcat(base_path, '/data_type=cgm/patient_id=', subjID, '/cgm.csv');
    cgm_data = readtable(cgm_path);
    
    basal_path = strcat(base_path, '/data_type=basal/patient_id=', subjID, '/basal.csv');
    basal_data = readtable(basal_path);
    
    bolus_path = strcat(base_path, '/data_type=bolus/patient_id=', subjID, '/bolus.csv');
    bolus_data = readtable(bolus_path);

    refTimes = cgm_data.datetime;
    minRef = min(refTimes);
    maxRef = max(refTimes);
    refNum   = datenum(refTimes);

    mask_bolus = (bolus_data.datetime >= minRef) & (bolus_data.datetime <= maxRef);
    bolusNum = datenum(bolus_data.datetime(mask_bolus));
    idx_bolus = knnsearch(refNum, bolusNum);
    bolus_data.datetime_aligned = bolus_data.datetime;
    bolus_data.datetime_aligned(mask_bolus) = refTimes(idx_bolus);

    mask_basal = (basal_data.datetime >= minRef) & (basal_data.datetime <= maxRef);
    basalNum = datenum(basal_data.datetime(mask_basal));
    idx_basal = knnsearch(refNum, basalNum);
    
    basal_data.datetime_aligned = basal_data.datetime;
    basal_data.datetime_aligned(mask_basal) = refTimes(idx_basal);

    writetable(basal_data, basal_path);
    writetable(bolus_data, bolus_path);

end