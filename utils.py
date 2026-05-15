import pyagrum as gum
import pyagrum.lib.notebook as gnb
import pandas as pd
import itertools
import numpy as np
import matplotlib.pyplot as plt
import plotly.express as px
import ipywidgets as widgets
from IPython.display import display, clear_output
import os
from pathlib import Path



# ==========================================
# MAP EXERCISE MODALITY
# =========================================

import pandas as pd

def map_exercise_modality(df, activity_col_name="CleanActivityName"):
    """
    Maps raw string exercise names into physiological modalities 
    to capture differing counter-regulatory hormone responses.
    """
    
    modality_mapping = {
        # 1. AEROBIC: Continuous oxidative phosphorylation. 
        # Clinical Expectation: Rapid, linear drop in circulating blood glucose.
        'Walking': 'Aerobic', 
        'Cycling': 'Aerobic', 
        'Running': 'Aerobic',
        'Elliptical': 'Aerobic', 
        'Stairs': 'Aerobic', 
        'Swimming': 'Aerobic',
        'Hiking': 'Aerobic', 
        'StairClimbing': 'Aerobic', 
        'Rowing': 'Aerobic',
        'PaddleSports': 'Aerobic', 
        'Step Training': 'Aerobic',

        # 2. ANAEROBIC / RESISTANCE: High mechanical load, glycogen-driven.
        # Clinical Expectation: Counter-regulatory hormone release, potential glucose spike.
        'Traditional Strength Training': 'Anaerobic',
        'Functional Strength Training': 'Anaerobic',
        'Core Training': 'Anaerobic', 
        'Pilates': 'Anaerobic', 
        'Barre': 'Anaerobic',

        # 3. MIXED MODALITY: Alternating high/low heart rate (Sports & Intervals).
        # Clinical Expectation: Highly variable, often stabilizes glucose during, but drops later.
        'High Intensity Interval Training': 'Mixed', 
        'Cross Training': 'Mixed',
        'Kick Boxing': 'Mixed', 
        'Mixed Cardio': 'Mixed', 
        'Mixed Metabolic Cardio Training': 'Mixed',
        'Dance': 'Mixed', 
        'Hockey': 'Mixed', 
        'Soccer': 'Mixed',
        'Football': 'Mixed', 
        'Volleyball': 'Mixed', 
        'Racquetball': 'Mixed', 
        'Climbing': 'Mixed',
        'Downhill Skiing': 'Mixed', 
        'Snow Sports': 'Mixed', 
        'Snowboarding': 'Mixed',
        'Play': 'Mixed', 
        'Golf': 'Mixed',

        # 4. OTHER / FLEXIBILITY: Low metabolic impact, unclassified.
        # Clinical Expectation: Neutral to mild aerobic drop.
        'Yoga': 'Other', 
        'Mind And Body': 'Other',
        'Preparation And Recovery': 'Other', 
        'Other Activity': 'Other'
    }

    # Create the new categorical feature
    df_mapped = df.copy()
    df_mapped['ExerciseModality'] = df_mapped[activity_col_name].map(modality_mapping)
    
    # Fill any weird missing or unmapped values just to be safe
    df_mapped['ExerciseModality'] = df_mapped['ExerciseModality'].fillna('Other')
    
    return df_mapped


# ==========================================
# DATA DISCRETIZATION
# ==========================================


def discretize_data(df, cv_strategy, bmi_strategy, hba1c_strategy, glucose_strategy, roc_strategy, cols_to_remove):

    """
    Transforms continuous physiological data into discrete bins.
    Allows toggling between 'clinical' (literature thresholds) and 'statistical' (quantiles)
    for sensitive features.
    """
    print(f"Discretizing features | CV: {cv_strategy} | BMI: {bmi_strategy} | HbA1c: {hba1c_strategy} | Glucose: {glucose_strategy}")
    df_discrete = df.copy()
    
    existing_cols = [c for c in cols_to_remove if c in df_discrete.columns]
    if existing_cols:
        df_discrete.drop(columns=existing_cols, inplace=True)

    # -------------------------------------------------------------
    # THE TOGGLEABLE FEATURES (Parameters passed from Notebook)
    # -------------------------------------------------------------

    # 1. Glucose CV (Pre and Post)
    cv_cols = [col for col in ['preExerciseGlucoseCV', 'postExerciseGlucoseCV'] if col in df_discrete.columns]
    for col in cv_cols:
        if cv_strategy == "statistical":
            discrete_series_cv, thresholds = pd.qcut(df_discrete[col], q=3, 
                labels=["Low Variance", "Medium Variance", "High Variance"], duplicates='drop',retbins=True)
            df_discrete[col] = discrete_series_cv
            print(f"   - {col} thresholds: {thresholds}")
        elif cv_strategy == "clinical":
            df_discrete[col] = pd.cut(df_discrete[col], bins=[0, 36, np.inf], labels=["Stable", "Unstable"])

    # 2. BMI
    if 'BMI' in df_discrete.columns:
        if bmi_strategy == "clinical":
            df_discrete["BMI"] = pd.cut(df_discrete["BMI"], bins=[0, 18.5, 24.9, 29.9, np.inf], labels=["Underweight", "Healthyweight", "Overweight", "Obese"])
        elif bmi_strategy == "statistical":
            df_discrete["BMI"] = pd.qcut(df_discrete["BMI"], q=3, labels=["Lower BMI", "Medium BMI", "Higher BMI"], duplicates='drop')

    # 3. HbA1c
    if 'HbA1c' in df_discrete.columns:
        if hba1c_strategy == "clinical":
            df_discrete["HbA1c"] = pd.cut(df_discrete["HbA1c"], bins=[0, 5.7, 6.4,  np.inf], labels=["Normal", "Prediabetes", "Diabetes"])
        elif hba1c_strategy == "statistical":
            df_discrete["HbA1c"] = pd.qcut(df_discrete["HbA1c"], q=3, labels=["Lower HbA1c", "Medium HbA1c", "Higher HbA1c"], duplicates='drop')

    # 4. Start Exercise Glucose Level
    if 'startExerciseGlucoseLevel' in df_discrete.columns:
        if glucose_strategy == "clinical":
            df_discrete["startExerciseGlucoseLevel"] = pd.cut(df_discrete["startExerciseGlucoseLevel"], bins=[0, 70, 180, 250, np.inf], labels=["Hypo Risk", "Target", "Elevated", "Very High"])
        elif glucose_strategy == "statistical":
            df_discrete["startExerciseGlucoseLevel"] = pd.qcut(df_discrete["startExerciseGlucoseLevel"], q=3, labels=["Lower Glucose", "Target/Medium", "Higher Glucose"], duplicates='drop')

    # 5. Glucose Rate of Change

    if 'preExerciseRoc' in df_discrete.columns:
        if roc_strategy == "clinical":
            df_discrete["preExerciseRoc"] = pd.cut(df_discrete["preExerciseRoc"], bins=[-np.inf, -0.5, 0.5, np.inf], labels=["Falling", "Stable", "Rising"])
        elif roc_strategy == "statistical":
            df_discrete["preExerciseRoc"] = pd.qcut(df_discrete["preExerciseRoc"], q=3, labels=["Falling", "Stable", "Rising"], duplicates='drop')

    # -------------------------------------------------------------
    # FIXED FEATURES (Always discretized the same way, based on clinical thresholds or natural breaks)
    # -------------------------------------------------------------


    if 'age' in df_discrete.columns: df_discrete["age"] = pd.qcut(df_discrete["age"], q=3, labels=["Younger", "Middle", "Older"], duplicates='drop')
    if 'race' in df_discrete.columns: df_discrete["race"] = df_discrete["race"].map({1.0: "white", 2.0: "black", 3.0: "asian", 4.0: "pacific", 5.0: "american indian / alaskan native", 6.0: "no answer", 7.0: "more than one"})
    if 'gender' in df_discrete.columns: df_discrete["gender"] = df_discrete["gender"].map({1.0: "male", 2.0: "female"})
    if 'diabetesDuration' in df_discrete.columns: df_discrete["diabetesDuration"] = pd.qcut(df_discrete["diabetesDuration"], q=3, labels=["Short", "Medium", "Long"], duplicates='drop')
    if 'avgSessionsPerWeek' in df_discrete.columns: df_discrete["avgSessionsPerWeek"] = pd.qcut(df_discrete["avgSessionsPerWeek"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'height' in df_discrete.columns: df_discrete["height"] = pd.qcut(df_discrete["height"], q=3, labels=["Shorter", "Average", "Taller"], duplicates='drop')
    if 'weight' in df_discrete.columns: df_discrete["weight"] = pd.qcut(df_discrete["weight"], q=3, labels=["Lighter", "Average", "Heavier"], duplicates='drop')
    if 'InsSensitivity' in df_discrete.columns: df_discrete["InsSensitivity"] = pd.qcut(df_discrete["InsSensitivity"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'InsCarbRatio' in df_discrete.columns: df_discrete["InsCarbRatio"] = pd.qcut(df_discrete["InsCarbRatio"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'IOB' in df_discrete.columns: df_discrete["IOB"] = pd.cut(df_discrete["IOB"], bins=[-np.inf, -0.2, 0.2, 2, np.inf], labels=["Negative", "Baseline", "Moderate", "High"])
    if 'COB' in df_discrete.columns: df_discrete["COB"] = pd.qcut(df_discrete["COB"], q=4, labels=["Low", "Moderate", "High", "Very High"], duplicates='drop')
    if 'IOBnorm' in df_discrete.columns: df_discrete["IOBnorm"] = pd.qcut(df_discrete["IOBnorm"], q=3, labels=["Low Impact", "Medium Impact", "High Impact"], duplicates='drop')
    if 'COBnorm' in df_discrete.columns: 
        bins = pd.qcut(df_discrete["COBnorm"], q=3, duplicates='drop')
        df_discrete["COBnorm"] = bins.cat.rename_categories([f"Carb Load Bin {i+1}" for i in range(len(bins.cat.categories))]
    )
    
    if 'AOB' in df_discrete.columns: df_discrete["AOB"] = pd.qcut(df_discrete["AOB"], q=3, labels=["Low AOB", "Medium AOB", "High AOB"], duplicates='drop')
    if 'TotalCWL' in df_discrete.columns: df_discrete["TotalCWL"] = pd.qcut(df_discrete["TotalCWL"], q=3, labels=["Low CWL", "Medium CWL", "High CWL"], duplicates='drop')
    if 'ACWR' in df_discrete.columns: df_discrete["ACWR"] = pd.qcut(df_discrete["ACWR"], q=4, labels=["Sedentary", "Lightly Active", "Active", "Highly Active"], duplicates='drop')
    
    if 'MET' in df_discrete.columns: df_discrete["MET"] = pd.cut(df_discrete["MET"], bins=[0, 3, 6, np.inf], labels=["Light", "Moderate", "Vigorous"])
    if 'DurationValue' in df_discrete.columns: df_discrete["DurationValue"] = pd.cut(df_discrete["DurationValue"], bins=[0, 30, 60, np.inf], labels=["Short", "Medium", "Long"])
    if 'MET_min' in df_discrete.columns: df_discrete["MET_min"] = pd.qcut(df_discrete["MET_min"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'EnergyPerMinute' in df_discrete.columns: df_discrete["EnergyPerMinute"] = pd.qcut(df_discrete["EnergyPerMinute"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    
    if 'exerciseMaxExcursion' in df_discrete.columns: df_discrete["exerciseMaxExcursion"] = pd.qcut(df_discrete["exerciseMaxExcursion"], q=3, labels=["Small", "Medium", "Large"], duplicates='drop')
    if 'exerciseMaxSpikeRoc' in df_discrete.columns: df_discrete["exerciseMaxSpikeRoc"] = pd.cut(df_discrete["exerciseMaxSpikeRoc"], bins=[-np.inf, 1, 2, np.inf], labels=["Stable", "Moderate Rise", "Rapide Rise"])
    if 'exerciseMaxDropRoc' in df_discrete.columns: df_discrete["exerciseMaxDropRoc"] = pd.cut(df_discrete["exerciseMaxDropRoc"], bins=[-np.inf, -2, -1, np.inf], labels=["Rapid Drop", "Moderate Drop", "Stable"])
    if 'exerciseNadir' in df_discrete.columns: df_discrete["exerciseNadir"] = pd.cut(df_discrete["exerciseNadir"], bins=[-np.inf, 70, 180, np.inf], labels=["Hypo", "Target", "Hyper"])
    if 'exercisePeak' in df_discrete.columns: df_discrete["exercisePeak"] = pd.cut(df_discrete["exercisePeak"], bins=[-np.inf, 70, 180, np.inf], labels=["Hypo", "Target", "Hyper"])
    if 'exerciseTIR' in df_discrete.columns: df_discrete["exerciseTIR"] = pd.cut(df_discrete["exerciseTIR"], bins=[-np.inf, 50, 70, np.inf], labels=["Poor", "Borderline", "Target"])
    if 'exerciseTBR' in df_discrete.columns: df_discrete["exerciseTBR"] = pd.cut(df_discrete["exerciseTBR"], bins=[-np.inf, 0, 4, np.inf], labels=["Perfect", "Mild", "Risk"])
    if 'exerciseAUC70' in df_discrete.columns:
        # Find the median of ONLY the sessions where AUC > 0
        non_zero_auc = df_discrete[df_discrete['exerciseAUC70'] > 0]['exerciseAUC70']
        if not non_zero_auc.empty:
            auc_median = non_zero_auc.median()
            df_discrete['exerciseAUC70'] = pd.cut(
                df_discrete['exerciseAUC70'],
                bins=[-np.inf, 0.001, auc_median, np.inf],
                labels=['Zero', 'Mild Severity', 'High Severity']
            )
        else:
            df_discrete['exerciseAUC70'] = 'Zero'

    if 'maxGlucosePostExercise' in df_discrete.columns: df_discrete["maxGlucosePostExercise"] = pd.cut(df_discrete["maxGlucosePostExercise"], bins=[-np.inf, 70, 180, np.inf], labels=["Hypo", "Target", "Hyper"])
    if 'minGlucosePostExercise' in df_discrete.columns: df_discrete["minGlucosePostExercise"] = pd.cut(df_discrete["minGlucosePostExercise"], bins=[-np.inf, 70, 180, np.inf], labels=["Hypo", "Target", "Elevated"])
    if 'postExerciseTIR' in df_discrete.columns: df_discrete["postExerciseTIR"] = pd.cut(df_discrete["postExerciseTIR"], bins=[-np.inf, 50, 70, np.inf], labels=["Poor", "Borderline", "Target"])
    if 'postExerciseTimeToNadir' in df_discrete.columns: df_discrete["postExerciseTimeToNadir"] = pd.qcut(df_discrete["postExerciseTimeToNadir"], q=3, labels=["Early Drop", "Mid Drop", "Late Drop"])
    if 'postExerciseTBR' in df_discrete.columns: df_discrete["postExerciseTBR"] = pd.cut(df_discrete["postExerciseTBR"], bins=[-np.inf, 0, 4, np.inf], labels=["Perfect", "Mild", "Risk"])
    if 'postExerciseTAR' in df_discrete.columns: df_discrete["postExerciseTAR"] = pd.cut(df_discrete["postExerciseTAR"], bins=[-np.inf, 25, 50, np.inf], labels=["Target", "Elevated", "Risk"])
    if 'postExerciseHypoEvent' in df_discrete.columns: df_discrete["postExerciseHypoEvent"] = df_discrete["postExerciseHypoEvent"].map({0: "No", 1: "Yes"})
    if 'postExerciseAUC70' in df_discrete.columns:
        non_zero_auc = df_discrete[df_discrete['postExerciseAUC70'] > 0]['postExerciseAUC70']
        if not non_zero_auc.empty:
            auc_median = non_zero_auc.median()
            df_discrete['postExerciseAUC70'] = pd.cut(
                df_discrete['postExerciseAUC70'],
                bins=[-np.inf, 0.001, auc_median, np.inf],
                labels=['Zero', 'Mild Severity', 'High Severity']
            )
        else:
            df_discrete['postExerciseAUC70'] = 'Zero'


    print("Discretization complete.")
    return df_discrete


# ==========================================
# DISTRIBUTION PLOT
# =========================================

def plot_single_feature_distribution(df, feature_name, title_prefix="", show_png = False, save_png=True):
    """
    Plots an interactive horizontal bar chart for a single specified feature using Plotly.
    Includes the Okabe-Ito colorblind-safe palette and saves to PNG if requested.
    """

    base_dir = Path().resolve()
    save_dir = base_dir / "images" / "featuresDistribution"
    save_dir.mkdir(parents=True, exist_ok=True)

    if feature_name not in df.columns:
        print(f"Error: Feature '{feature_name}' not found in the dataset.")
        return

    # 1. Calculate percentages and sort
    counts = df[feature_name].value_counts(normalize=True) * 100
    try:
        counts = counts.sort_index()
    except TypeError:
        pass 
        
    # Convert to a temporary DataFrame specifically for Plotly
    plot_df = pd.DataFrame({
        'Category': counts.index.astype(str),
        'Percentage': counts.values
    })
    
    # 2. Expanded Okabe-Ito Colorblind-Safe Palette 
    color_palette = ['#0072B2', '#E69F00', '#D55E00', '#009E73', '#56B4E9', '#F0E442', '#CC79A7', '#999999']
    
    # Dynamically set height based on the number of bars
    dynamic_height = max(400, len(counts) * 45)
    
    # Title Setup
    title = f"Distribution of {feature_name}"
    if title_prefix:
        title += f" {title_prefix}"

    # 3. Build the Plotly Bar Chart
    fig = px.bar(
        plot_df, 
        x='Percentage', 
        y='Category', 
        orientation='h',
        text=plot_df['Percentage'].apply(lambda x: f'{x:.1f}%'), # Format text to 1 decimal
        color='Category',
        color_discrete_sequence=color_palette,
        height=dynamic_height
    )
    
    # 4. Styling and Layout Formatting
    fig.update_traces(
        textposition='outside', # Pushes the percentage text past the end of the bar
        textfont=dict(size=12, family="Arial Black"),
        showlegend=False        # Hide legend since the y-axis already labels the categories
    )
    
    fig.update_layout(
        title=dict(
            text=title, 
            font=dict(size=18, family="Arial"),
            y=0.95, x=0.5, xanchor='center', yanchor='top'
        ),
        xaxis_title="Percentage (%)",
        yaxis_title=None,
        plot_bgcolor='white', # Clean academic background
        xaxis=dict(
            range=[0, plot_df['Percentage'].max() * 1.20], # Room for the outside text
            showgrid=False,
            zeroline=False
        ),
        yaxis=dict(
            autorange="reversed", # Matches Matplotlib's top-to-bottom reading order
            tickfont=dict(size=14)
        ),
        margin=dict(l=20, r=40, t=70, b=20)
    )

    # 5. Display the interactive chart
    if show_png:
        fig.show()
    
    
    # 6. Save as High-Res PNG if requested
    if save_png:
        # Clean the feature name just in case it has weird characters
        safe_name = "".join([c for c in feature_name if c.isalnum() or c in ('_', '-')]).rstrip()
        if title_prefix == "- Clinical Thresholds":
            filename = f"{safe_name}_clinical.png"

        if title_prefix == "- Clinical Thresholds After Merge":
            filename = f"{safe_name}_clinical_merge.png"
        
        if title_prefix == "- Statistical Thresholds":
            filename = f"{safe_name}_statistical.png"

        if title_prefix == "- Statistical Thresholds After Merge":
            filename = f"{safe_name}_statistical_merge.png"
        
        full_path = save_dir / filename
        fig.write_image(full_path, scale=3)
        
    


# ==========================================
# COLLAPSE BINS
# ==========================================

def collapse_sparse_bins(df):
    """
    Collapses statistically sparse bins (< 5%) into their nearest clinical neighbors
    to prevent probability crashes and information sparsity in the Bayesian Network.
    """
    clean_df = df.copy()
    
    print("\n🔨 Collapsing sparse bins to optimize the Bayesian Network...")

    # BMI
    if 'BMI' in clean_df.columns:
        clean_df['BMI'] = clean_df['BMI'].replace(
            {'Underweight': 'Healthyweight/Underweight', 
             'Healthyweight': 'Healthyweight/Underweight',
             'Obese': 'Overweight/Obese', 
             'Overweight': 'Overweight/Obese'}
        )

    # startExerciseGlucoseLevel
    if 'startExerciseGlucoseLevel' in clean_df.columns:
        clean_df['startExerciseGlucoseLevel'] = clean_df['startExerciseGlucoseLevel'].replace(
            {'Very High': 'Elevated'}
        )
        
    # minGlucosePostExercise
    if 'minGlucosePostExercise' in clean_df.columns:
        clean_df['minGlucosePostExercise'] = clean_df['minGlucosePostExercise'].replace(
            {'Elevated': 'Not Hypo', 'Target': 'Not Hypo'}
        )

    # exerciseTIR
    if 'exerciseTIR' in clean_df.columns:
        clean_df['exerciseTIR'] = clean_df['exerciseTIR'].replace(
            {'Borderline': 'Poor'}
        )

    # exercise TBR
    if 'exerciseTBR' in clean_df.columns:
        clean_df['exerciseTBR'] = clean_df['exerciseTBR'].replace(
            {'Mild': 'Risk'}
        )

    # max Glucose Post Exercise
    if 'maxGlucosePostExercise' in clean_df.columns:
        clean_df['maxGlucosePostExercise'] = clean_df['maxGlucosePostExercise'].replace(
            {'Hypo': 'Target'}
        )

    # postExerciseTIR
    if 'postExerciseTIR' in clean_df.columns:
        clean_df['postExerciseTIR'] = clean_df['postExerciseTIR'].replace(
            {'Borderline': 'Poor'}
        )

    # postExercise TBR
    if 'postExerciseTBR' in clean_df.columns:
        clean_df['postExerciseTBR'] = clean_df['postExerciseTBR'].replace(
            {'Mild': 'Risk'}
        )

    # postExercise TAR
    if 'postExerciseTAR' in clean_df.columns:
        clean_df['postExerciseTAR'] = clean_df['postExerciseTAR'].replace(
            {'Elevated': 'Risk'}
        )

   
    return clean_df



# ==========================================
# DISCRETIZATION HEALTH CHECK
# ==========================================
def check_discretization(df, lower_bound=5.0, upper_bound=85.0):
    """Scans dataset for sparse or heavily skewed bins."""
    print("\n--- DISCRETIZATION HEALTH CHECK ---")
    for col in df.columns:
        print(f"📊 Feature: {col}")
        value_counts = df[col].value_counts(normalize=True) * 100
        
        for bin_name, pct in value_counts.items():
            if pct > upper_bound or pct < lower_bound:
                print(f"   ⚠️ {bin_name}: {pct:.1f}%")
            else:
                print(f"      {bin_name}: {pct:.1f}%")
        print("-" * 30)

# ==========================================
# EXPERT CONSTRAINTS (CAUSAL RULES)
# ==========================================
def apply_expert_constraints(learner, tiers):
    """Applies strict temporal and biological rules to the BN Learner."""
    time_tiers = [tiers['static'], tiers['pre'], tiers['exercise'], tiers['outcome_during'] + tiers['outcome_post']]
    
    # Rule 1: No backward time travel
    for i in range(len(time_tiers)):
        for j in range(i):
            for future_node in time_tiers[i]:
                for past_node in time_tiers[j]:
                    if future_node in learner.names() and past_node in learner.names():
                        learner.addForbiddenArc(future_node, past_node)


    # --------------------------------------------------------------
    # Rule 2: Static Layer Hierarchy
    absolute_roots = ['age', 'gender', 'diabetesDuration']
    clinical_params = ['HbA1c', 'InsSensitivity', 'InsCarbRatio']

    # Root nodes
    for node in tiers['static']:
        if node not in absolute_roots and node in learner.names():
            for root in absolute_roots:
                if root in learner.names():
                    learner.addForbiddenArc(node, root)

    # Root nodes cannot cause each other
    for i in range(len(absolute_roots)):
        for j in range(len(absolute_roots)):
            if i != j and absolute_roots[i] in learner.names() and absolute_roots[j] in learner.names():
                learner.addForbiddenArc(absolute_roots[i], absolute_roots[j])

    # Clinical parameters do not cause anthropometrics (BMI causes insulin resistance, not vice versa)
    for param in clinical_params:
        if param in learner.names() and 'BMI' in learner.names():
            learner.addForbiddenArc(param, 'BMI')

    # --------------------------------------------------------------
    # Rule 3: Pre-Exercise 
    drivers = ['IOBnorm', 'COBnorm', 'AOB', 'TotalCWL']
    dynamics = ['preExerciseRoc', 'preExerciseGlucoseCV']
    endpoint = 'startExerciseGlucoseLevel'

    # Glucose metrics (dynamics & endpoint) cannot cause the prior actions/drivers
    for var in dynamics + [endpoint]:
        if var in learner.names():
            for driver in drivers:
                if driver in learner.names():
                    learner.addForbiddenArc(var, driver)

    # The final starting glucose cannot cause the trajectory that led up to it
    if endpoint in learner.names():
        for dyn in dynamics:
            if dyn in learner.names():
                learner.addForbiddenArc(endpoint, dyn)

    # Drivers do not cause each other (e.g., taking insulin doesn't cause you to have eaten carbs)
    for driver1, driver2 in itertools.combinations(drivers, 2):
        if driver1 in learner.names() and driver2 in learner.names():
            learner.addForbiddenArc(driver1, driver2)
            learner.addForbiddenArc(driver2, driver1)

    # Dynamics do not cause each other (Variance doesn't cause Velocity)
    if 'preExerciseRoc' in learner.names() and 'preExerciseGlucoseCV' in learner.names():
        learner.addForbiddenArc('preExerciseRoc', 'preExerciseGlucoseCV')
        learner.addForbiddenArc('preExerciseGlucoseCV', 'preExerciseRoc')

    # --------------------------------------------------------------
    # Rule 4: Exercise layer
    modality = 'ExerciseModality'
    exercise_params = ['MET', 'DurationValue', 'MET_min']

   # Parameters (Time/Intensity) cannot cause the Modality 
    if modality in learner.names():
        for param in exercise_params:
            if param in learner.names():
                learner.addForbiddenArc(param, modality)

    # MET and Duration do not strictly cause each other (they are parallel restrictions of Modality)
    if 'MET' in learner.names() and 'DurationValue' in learner.names():
        learner.addForbiddenArc('MET', 'DurationValue')
        learner.addForbiddenArc('DurationValue', 'MET')


    # --------------------------------------------------------------
    # Rule 5: Outcome Chronology (During vs Post)
    # PART A: Inter-Layer Strict Time Travel Prevention (Post cannot cause During)
    # ---------------------------------------------------------
    for post_metric in tiers['outcome_post']:
        for during_metric in tiers['outcome_during']:
            if post_metric in learner.names() and during_metric in learner.names():
                learner.addForbiddenArc(post_metric, during_metric)

    # ---------------------------------------------------------
    # PART B: 'During Exercise' Internal Hierarchy
    # ---------------------------------------------------------
    during_dynamics = ['exerciseMaxSpikeRoc', 'exerciseMaxDropRoc']
    during_extremes = ['exercisePeak', 'exerciseNadir', 'exerciseMaxExcursion']
    during_aggregates = ['exerciseTIR', 'exerciseTBR', 'exerciseAUC70']

    # Aggregates cannot cause Extremes or Dynamics
    for agg in during_aggregates:
        if agg in learner.names():
            for ext in during_extremes:
                if ext in learner.names(): learner.addForbiddenArc(agg, ext)
            for dyn in during_dynamics:
                if dyn in learner.names(): learner.addForbiddenArc(agg, dyn)

    # Extremes cannot cause Dynamics
    for ext in during_extremes:
        if ext in learner.names():
            for dyn in during_dynamics:
                if dyn in learner.names(): learner.addForbiddenArc(ext, dyn)

    # Forbid tautologies within mathematical subgroups 
    # (e.g. TBR doesn't cause AUC, they happen simultaneously)
    for group in [during_dynamics, during_extremes, during_aggregates]:
        for var1, var2 in itertools.combinations(group, 2):
            if var1 in learner.names() and var2 in learner.names():
                learner.addForbiddenArc(var1, var2)
                learner.addForbiddenArc(var2, var1)

    # ---------------------------------------------------------
    # PART C: 'Post Exercise' Internal Hierarchy
    # ---------------------------------------------------------
    post_extremes = ['maxGlucosePostExercise', 'minGlucosePostExercise', 'postExerciseTimeToNadir']
    post_aggregates = ['postExerciseTIR', 'postExerciseTBR', 'postExerciseTAR', 'postExerciseAUC70', 'postExerciseGlucoseCV', 'postExerciseHypoEvent']

    # Aggregates/Variance cannot cause Extremes or Timing
    for agg in post_aggregates:
        if agg in learner.names():
            for ext in post_extremes:
                if ext in learner.names(): learner.addForbiddenArc(agg, ext)

    # Forbid tautologies within mathematical subgroups
    for group in [post_extremes, post_aggregates]:
        for var1, var2 in itertools.combinations(group, 2):
            if var1 in learner.names() and var2 in learner.names():
                learner.addForbiddenArc(var1, var2)
                learner.addForbiddenArc(var2, var1)

    return learner

# ==========================================
# NETWORK VISUALIZATION
# ==========================================
def visualize_network(bn, tiers):
    """Renders the Bayesian Network using a colorblind-safe Okabe-Ito palette."""

    gum.config['notebook', 'graph_format'] = 'png'

    dot_lines = [
        "digraph ExpertCausalModel {", 
        '  rankdir="TB";', 
        
        # FIX 1: Increase graph resolution (dpi) and physical spacing
        # nodesep = horizontal spacing, ranksep = vertical spacing
        '  graph [dpi=300, nodesep=0.6, ranksep=0.8];', 
        
        # FIX 2: Increase font size and the margin (padding) inside the ellipses
        '  node [style="filled", shape="box", style="filled,rounded", fontname="Helvetica", fontsize=14, margin="0.25,0.15"];'
    ]

    

    for node in bn.names():
        if node in tiers['static']:
            color, font = "#0072B2", "white"   # Deep Blue
        elif node in tiers['pre']:
            color, font = "#E69F00", "black"   # Amber
        elif node in tiers['exercise']:
            color, font = "#D55E00", "white"   # Vermillion
        elif node in tiers['outcome_during'] or node in tiers['outcome_post']:
            color, font = "#009E73", "white"   # Emerald Green
        else:
            color, font = "#D3D3D3", "black"   # Grey
            print(f"⚠️ Warning: '{node}' didn't match any tier list!")

        dot_lines.append(f'  "{node}" [fillcolor="{color}", fontcolor="{font}"];')

    for edge in bn.arcs():
        src = bn.variable(edge[0]).name()
        tgt = bn.variable(edge[1]).name()
        dot_lines.append(f'  "{src}" -> "{tgt}";')

    dot_lines.append("}")
    gnb.showDot("\n".join(dot_lines))


# ==========================================
# INFERENCE EXAMPLE
# =========================================

def interactive_inference_dashboard(bn, evidence_nodes, target_node):
    """
    Generates an interactive ipywidgets dashboard for a pyAgrum Bayesian Network.
    
    Parameters:
    bn (gum.BayesNet): Your trained Bayesian Network.
    evidence_nodes (list of str): The names of the features you want to act as inputs (dropdowns).
    target_node (str): The name of the outcome feature you want to visualize.
    """
    # 1. Initialize the Inference Engine
    ie = gum.LazyPropagation(bn)

    # 2. Extract Target States
    target_states = list(bn.variableFromName(target_node).labels())

    # 3. Dynamically Generate Dropdowns for Evidence Nodes
    dropdowns = {}
    for node in evidence_nodes:
        # Extract states for this specific node directly from the network
        states = list(bn.variableFromName(node).labels())
        
        # Create the widget
        dropdown = widgets.Dropdown(
            options=['Not Fixed'] + states,
            description=f'{node}:',
            style={'description_width': 'initial'}
        )
        dropdowns[node] = dropdown

    # 4. Create the Output Plot Area
    out_plot = widgets.Output()

    # 5. The Dynamic Update Function
    def update_dashboard(*args):
        with out_plot:
            clear_output(wait=True)
            ie.eraseAllEvidence()
            
            # Dynamically inject evidence from all generated dropdowns
            for node_name, dropdown_widget in dropdowns.items():
                if dropdown_widget.value != 'Not Fixed':
                    ie.addEvidence(node_name, dropdown_widget.value)
                    
            # Perform Inference
            ie.makeInference()
            posterior = ie.posterior(target_node)
            
            # Extract probabilities
            probs = [posterior[i] * 100 for i in range(len(target_states))]
            
            # Draw the Chart
            plt.figure(figsize=(8, 4))
            bars = plt.bar(target_states, probs, color='#2ca02c', edgecolor='black')
            plt.ylim(0, 100)
            plt.ylabel('Probability (%)', fontsize=12)
            plt.title(f'Predicted Outcome: {target_node}', fontsize=14, fontweight='bold')
            plt.grid(axis='y', linestyle='--', alpha=0.7)
            
            # Add percentage labels
            for bar in bars:
                yval = bar.get_height()
                plt.text(bar.get_x() + bar.get_width()/2, yval + 1.5, f'{yval:.1f}%', 
                         ha='center', va='bottom', fontweight='bold')
                
            # Clean layout
            plt.gca().spines['top'].set_visible(False)
            plt.gca().spines['right'].set_visible(False)
            plt.tight_layout()
            plt.show()

    # 6. Bind the Observers
    for dropdown_widget in dropdowns.values():
        dropdown_widget.observe(update_dashboard, names='value')

    # 7. Group the UI Elements dynamically
    # We use HBox for the dropdowns. If there are many, it might be better to wrap them, 
    # but HBox works great for 3-5 variables.
    dropdown_container = widgets.HBox(list(dropdowns.values()))
    
    ui = widgets.VBox([
        widgets.HTML(f"<h3>Dynamic Inference: Impact on <i>{target_node}</i></h3>"),
        dropdown_container,
        out_plot
    ])

    # 8. Display and initialize
    display(ui)
    update_dashboard()