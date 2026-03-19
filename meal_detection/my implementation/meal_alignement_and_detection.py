##############################################################################
# Implementation of the psedo-code of the meal detection algorithm reported in
# Appendix II of the paper 

# Input: Arrays of daily CGM values, g = (g1, . . . , gn), and
# reported meals, m = (m1, . . . ,mn), sampled every 5 min
# with n = 288.
# Output: Updated array of meals.
##############################################################################

from scipy.signal import find_peaks
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime
from scipy import signal
from matplotlib.dates import DateFormatter


# %% Read data

path = "data.csv";

data = pd.read_csv(path).copy()

timestamp = pd.to_datetime(data['timestamp'], infer_datetime_format=True)

unique_days = timestamp.dt.normalize().unique() # get unique days

# get data from dataframe
CGM	 = data['CGM'].to_numpy()
Carbohydrates = data['Carbohydrates'].to_numpy()	
Bolus = data['Bolus'].to_numpy()
Bolus_Correction = data['Bolus_Correction'].to_numpy()	
Bolus_Meal = data['Bolus_Meal'].to_numpy()


# %% Plot data

#%matplotlib qt
# %matplotlib inline
fig, axs1 = plt.subplots(2, sharex=True)
axs1[0].plot(timestamp, CGM, label="CGM")
idx = Carbohydrates > 0
axs1[0].bar(timestamp[idx], Carbohydrates[idx], width = 0.01, label="Carbs")
axs1[0].set_xlabel('Timestamp')
axs1[0].set_ylabel('CGM (mg/dL) / Carbs (g)')
axs1[0].legend()
hh_mm = DateFormatter('%H:%M')
axs1[0].xaxis.set_major_formatter(hh_mm)

idx = Bolus > 0
axs1[1].bar(timestamp[idx], Bolus[idx], width = 0.01, label="Bolus")
idx = Bolus_Meal > 0
axs1[1].bar(timestamp[idx], Bolus_Meal[idx], width = 0.01, label="Bolus_Meal")
idx = Bolus_Correction > 0
axs1[1].bar(timestamp[idx], Bolus_Correction[idx], width = 0.01, label="Bolus_Correction")
axs1[1].set_xlabel('Timestamp')
axs1[1].set_ylabel('Bolus (IU)')
axs1[1].legend()
axs1[1].xaxis.set_major_formatter(hh_mm)


# %% Algorithm

day = 6
# for k in range(0,len(unique_days)-1,1):
for k in range(day,day+1,1):

    print(k)

    # logical indices corresponding to a day
    idx = (timestamp.to_numpy() >= unique_days[k]) & (timestamp.to_numpy()  < unique_days[k+1])
    
    # idx = timestamp.to_numpy() >= unique_days[0]
    
    # Capture the indices of reported meals (Step 1)
    Im = np.argwhere(Carbohydrates[idx] > 0)
    Im = Im[:,0]
    meals = Carbohydrates[idx][Im]  # meals carbohydrates list within a day
 
    # Estimate the element-wise first and second derivatives of g (gprime and g2prime) by means of a Savitzky-Golay filter of
    # polynomial order 3 and frame length 13 (Step 2)
    # Saturate gprime and g2prime at zero (Step 3)
    gprime =  np.clip(signal.savgol_filter(CGM[idx], window_length=13, polyorder=3, deriv=1, delta = 5),0, float('inf'))
    g2prime =  np.clip(signal.savgol_filter(gprime, window_length=13, polyorder=3, deriv=1, delta = 5),0, float('inf'))

    # Calculate element-wise product of gprime and g2prime (Step 4)
    mu = gprime*g2prime

    # plot results for a day
    #%matplotlib qt
    # %matplotlib inline
    fig, axs = plt.subplots(2, sharex=True)
    cgm_idx = CGM[idx]
    axs[0].plot(timestamp[idx], cgm_idx, label="CGM")
    # axs[1].plot(timestamp[idx], gprime)
    timestamp_idx = timestamp.to_numpy()[idx]
    axs[1].plot(timestamp_idx, mu)
    carb_idx = Carbohydrates[idx]
    carb_idx[np.isnan(carb_idx)] = 0
    axs[0].bar(timestamp_idx[Im], meals,width = 0.01, label="Meals")
    

    # Adjust the time of reported meals (Step 5)
    I1min = 12;  # low bound indices of the S1 search area
    I1max = 12;  # upper bound indices of the S1 search area
    I2min = 12;  # low bound indices of the S2 search area
    Imu = np.int16(np.zeros(len(Im))) # potential peak index in mu around Im[i]
    Imm = np.int16(np.zeros(len(Im))) # moved Im closer to the peak’s base
    mu_peaks = []
    idx_mu_peaks = []
    mu_base = [];
    idx_mu_base = []
    for i in range(0,len(Im),1):
        
        # Find a potential peak index in mu around Im[i] # (Step 6)
        #S1 = list(range(np.maximum(0, int(Im[i] - I1min)), int(np.minimum(288, Im[i] + I1max)))) # search area (Day by Day)
        S1 = list(range(np.maximum(0, int(Im[i] - I1min)), int(np.minimum(1e90, Im[i] + I1max)))) # search area (Whole Scenario)
        Imu[i] = int(mu[S1].argmax()) # peak index in mu around Im[i]
        
        idx_mu_peaks.append(S1[Imu[i]])
        mu_peaks.append(mu[S1[Imu[i]]])

        # axs[1].plot(timestamp_idx[S1[Imu[i]]], mu[S1[Imu[i]]],"o", color = 'red', label="Peaks Around Meal") # plot peaks

        # Move Imu[i] closer to the peak’s base (Step 7)
        S2 = list(range(int(np.maximum(0,S1[Imu[i]] - I2min)), int(S1[Imu[i]]))) # search area

        mu_diffS2 = np.ediff1d(mu[S2]); # differential of mu
        mu_diffS2[mu_diffS2<= 0] = np.inf;  # replace 0 by inf (this is a difference with respect to the original algo)
        Imm[i] = int(mu_diffS2.argmin()) # moved Im[i]

        idx_mu_base.append(S2[Imm[i]])
        mu_base.append(mu[S2[Imm[i]]]);
        
        # axs[1].plot(timestamp_idx[S2[Imm[i]]], mu[S2[Imm[i]]],"s", color = 'green', label="Peak Base") # plot base

    axs[0].bar(timestamp_idx[idx_mu_base], meals, width = 0.01, color = 'green', label="Shifted") # plot shifted meal
    axs[1].plot(timestamp_idx[idx_mu_peaks], mu_peaks,"o", color = 'red', label="Peaks Around Meal") # plot peaks
    axs[1].plot(timestamp_idx[idx_mu_base], mu_base,"s", color = 'green', label="Peak Base") # plot base

    # Identify potential unannounced meals at peak indices (step 9)
    Pm = 0.0075 # height (mg2/dL2/min3)
    Pp = 0.0025 #prominence (mg2/dL2/min3)
    # Pm = 0.075 # height (mg2/dL2/min3)  #(NEW VALUE)
    # Pp = 0.025 #prominence (mg2/dL2/min3) #(NEW VALUE)
    separation  = 30 #(min)
    Id, _ = find_peaks(mu, height=Pm, distance=separation, prominence=Pp)

    Ph = mu[Id] # peak heights (step 10)

    axs[1].plot(timestamp_idx[Id], Ph,"+", color = 'blue', label="Peaks") # plot peaks

    # Append detected unannounced meals/hypo-treatments (step 11)
    Idm = np.int16(np.zeros(len(Id))) 
    delta_g = np.int16(np.zeros(len(Id)))
    hypo_treat = [];   # hypo treatments
    idx_hypo_treat = []; # index hypo tratment
    detect_meals = []; # detected meals carbs
    idx_detect_meals = []; # index of detected meals
    for ii in range(0,len(Id),1):

        # Move Id[i] closer to the peak’s base (Step 12)
        S3 = list(range(np.maximum(0, int(Id[ii] - I2min)), int(Id[ii]))) # search area
        mu_diffS3 = np.ediff1d(mu[S3])
        mu_diffS3[mu_diffS3<= 0] = np.inf;  # replace 0 by inf (this is a difference with respect to the original algo)
        Idm[ii] = int(mu_diffS3.argmin())

        # Compute glucose deviations between peak’s base to 60 minutes ahead (Step 13)
        # delta_g[ii] = cgm_idx[S3[Idm[ii]]+12] - cgm_idx[S3[Idm[ii]]]

        delta_g[ii] = np.amax(cgm_idx[S3[Idm[ii]]:S3[Idm[ii]]+12]) - cgm_idx[S3[Idm[ii]]] # new

        # gt and Pht are glucose (90) and peak (0.01) thresholds, respectively
        gt = 90
        Pht = 0.01
        delta_gt = 40 # glucose deviation threshold (40)
        ms = 50 # average meal size obtained from historical records or 0.7g/kg if there are not.
        if cgm_idx[S3[Idm[ii]]] < gt and Ph[ii] >= Pht:
            # if Idm[i] is more than 3 samples apart from other detected hypo-treatments then
            # append 20 grams and Idm[i] to m and Im respectively (Step 16)
            if idx_hypo_treat == [] or (S3[int(Idm[ii])] - idx_hypo_treat[-1]) > 3: # empty or more than 3 samples apart from other detected hypo-treatments
                idx_hypo_treat.append(S3[int(Idm[ii])]) # append index 
                hypo_treat.append(20) # append 20 grams
                # axs[0].bar(timestamp_idx[S3[int(np.array(Idm[ii]))]], hypo_treat, width = 0.01, color = 'red', label="Rescue") # plot recue carbs
        elif delta_g[ii] > delta_gt: # if Id[i] is more than 9 samples apart from other meals (Step 18)
            if idx_detect_meals == [] or (S3[int(Idm[ii])] - idx_detect_meals[-1]) > 9:
                detect_meals.append(50); # detected meals carbs
                idx_detect_meals.append(S3[int(Idm[ii])]); # index of detected meals
                # axs[0].bar(timestamp_idx[S3[int(np.array(Idm[ii]))]], detect_meals, width = 0.01, color = 'orange', label="Detected") # plot detected meals

if idx_hypo_treat != []:
    axs[0].bar(timestamp_idx[idx_hypo_treat], hypo_treat, width = 0.01, color = 'red', label="Rescue") # plot recue carbs
if idx_detect_meals != []:
    axs[0].bar(timestamp_idx[idx_detect_meals], detect_meals, width = 0.01, color = 'orange', label="Detected") # plot detected meals

axs[0].set_xlabel('Timestamp')
axs[0].set_ylabel('CGM (mg/dL) / Carbs (g)')

axs[0].legend(loc='upper left')
axs[1].set_xlabel('Timestamp')
axs[1].set_ylabel('mu, peaks, and bases')
axs[1].legend()
axs[0].xaxis.set_major_formatter(hh_mm)
axs[1].xaxis.set_major_formatter(hh_mm)


plt.figure()
fig, ax1 = plt.subplots()
ax2 = ax1.twinx()
lns1 = ax1.plot(timestamp[idx], cgm_idx, label="CGM", color="blue")
bolus_idx = Bolus[idx]
bolus_idx[np.isnan(bolus_idx)] = 0
lns3 = ax2.plot(timestamp_idx, bolus_idx, label="Bolus Insulin", color="green",linewidth=0.5)
carb_idx = Carbohydrates[idx]
carb_idx[np.isnan(carb_idx)] = 0
lns2 = ax1.plot(timestamp_idx, carb_idx, label="Meal Carbs", color="orange",linewidth=4)
ax1.xaxis.set_major_formatter(hh_mm)
ax2.xaxis.set_major_formatter(hh_mm)
ax1.set_xlabel('Timestamp')
ax2.set_ylabel('Insulin Bolus (U)', color='black')
ax1.set_ylabel('Glucose Level (mg/dL) / Carbohydrate (g)', color='black')
# added these three lines
lns = lns1+lns3+lns2
labs = [l.get_label() for l in lns]
ax2.legend(lns, labs, loc=0)
plt.show()

ax1.grid(False)
ax2.grid(False)



