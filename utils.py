import pyagrum as gum
import pyagrum.lib.notebook as gnb
import pandas as pd
import itertools
import numpy as np
import matplotlib.pyplot as plt


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


def discretize_data(df, cv_strategy, bmi_strategy, hba1c_strategy, glucose_strategy, cols_to_remove):

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
            df_discrete[col] = pd.qcut(df_discrete[col], q=3, labels=["Low Variance", "Medium Variance", "High Variance"], duplicates='drop')
        elif cv_strategy == "clinical":
            df_discrete[col] = pd.cut(df_discrete[col], bins=[0, 36, np.inf], labels=["Stable", "Unstable"])

    # 2. BMI
    if 'BMI' in df_discrete.columns:
        if bmi_strategy == "clinical":
            df_discrete["BMI"] = pd.cut(df_discrete["BMI"], bins=[0, 18.5, 24.9, 29.9, np.inf], labels=["Underweight", "Normal", "Overweight", "Obese"])
        elif bmi_strategy == "statistical":
            df_discrete["BMI"] = pd.qcut(df_discrete["BMI"], q=3, labels=["Lower BMI", "Medium BMI", "Higher BMI"], duplicates='drop')

    # 3. HbA1c
    if 'HbA1c' in df_discrete.columns:
        if hba1c_strategy == "clinical":
            df_discrete["HbA1c"] = pd.cut(df_discrete["HbA1c"], bins=[0, 5.7, 6.4, 7, np.inf], labels=["Normal", "Prediabetes", "Diabetes - Control", "Diabetes - Poor Control"])
        elif hba1c_strategy == "statistical":
            df_discrete["HbA1c"] = pd.qcut(df_discrete["HbA1c"], q=3, labels=["Lower HbA1c", "Medium HbA1c", "Higher HbA1c"], duplicates='drop')

    # 4. Start Exercise Glucose Level
    if 'startExerciseGlucoseLevel' in df_discrete.columns:
        if glucose_strategy == "clinical":
            df_discrete["startExerciseGlucoseLevel"] = pd.cut(df_discrete["startExerciseGlucoseLevel"], bins=[0, 70, 180, 250, np.inf], labels=["Hypo Risk", "Target", "Elevated", "Very High"])
        elif glucose_strategy == "statistical":
            df_discrete["startExerciseGlucoseLevel"] = pd.qcut(df_discrete["startExerciseGlucoseLevel"], q=3, labels=["Lower Glucose", "Target/Medium", "Higher Glucose"], duplicates='drop')


    # -------------------------------------------------------------
    # FIXED FEATURES (Always discretized the same way, based on clinical thresholds or natural breaks)
    # -------------------------------------------------------------
    startRoc_edges = [-np.inf, -2, -1, 1, 2, np.inf]
    startRoc_labels = ["Rapidly Falling", "Falling", "Stable", "Rising", "Rapidly Rising"]

    if 'age' in df_discrete.columns: df_discrete["age"] = pd.qcut(df_discrete["age"], q=3, labels=["Younger", "Middle", "Older"], duplicates='drop')
    if 'gender' in df_discrete.columns: df_discrete["gender"] = df_discrete["gender"].map({1.0: "male", 2.0: "female"})
    if 'height' in df_discrete.columns: df_discrete["height"] = pd.qcut(df_discrete["height"], q=3, labels=["Shorter", "Average", "Taller"], duplicates='drop')
    if 'weight' in df_discrete.columns: df_discrete["weight"] = pd.qcut(df_discrete["weight"], q=3, labels=["Lighter", "Average", "Heavier"], duplicates='drop')
    if 'InsSensitivity' in df_discrete.columns: df_discrete["InsSensitivity"] = pd.qcut(df_discrete["InsSensitivity"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'InsCarbRatio' in df_discrete.columns: df_discrete["InsCarbRatio"] = pd.qcut(df_discrete["InsCarbRatio"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'preExerciseRoc' in df_discrete.columns: df_discrete["preExerciseRoc"] = pd.cut(df_discrete["preExerciseRoc"], bins=startRoc_edges, labels=startRoc_labels)
    if 'IOB' in df_discrete.columns: df_discrete["IOB"] = pd.cut(df_discrete["IOB"], bins=[-np.inf, -0.2, 0.2, 2, np.inf], labels=["Negative", "Baseline", "Moderate", "High"])
    if 'COB' in df_discrete.columns: df_discrete["COB"] = pd.qcut(df_discrete["COB"], q=4, labels=["Low", "Moderate", "High", "Very High"], duplicates='drop')
    if 'IOBnorm' in df_discrete.columns: df_discrete["IOBnorm"] = pd.qcut(df_discrete["IOBnorm"], q=3, labels=["Low Impact", "Medium Impact", "High Impact"], duplicates='drop')
    if 'COBnorm' in df_discrete.columns: df_discrete["COBnorm"] = pd.qcut(df_discrete["COBnorm"], q=3, labels=["Low Carb Load", "Medium Carb Load", "High Carb Load"], duplicates='drop')
    if 'AOB' in df_discrete.columns: df_discrete["AOB"] = pd.qcut(df_discrete["AOB"], q=3, labels=["Low AOB", "Medium AOB", "High AOB"], duplicates='drop')
    if 'TotalCWL' in df_discrete.columns: df_discrete["TotalCWL"] = pd.qcut(df_discrete["TotalCWL"], q=3, labels=["Low CWL", "Medium CWL", "High CWL"], duplicates='drop')
    if 'ACWR' in df_discrete.columns: df_discrete["ACWR"] = pd.qcut(df_discrete["ACWR"], q=4, labels=["Sedentary", "Lightly Active", "Active", "Highly Active"], duplicates='drop')
    if 'MET' in df_discrete.columns: df_discrete["MET"] = pd.cut(df_discrete["MET"], bins=[0, 3, 6, np.inf], labels=["Light", "Moderate", "Vigorous"])
    if 'DurationValue' in df_discrete.columns: df_discrete["DurationValue"] = pd.cut(df_discrete["DurationValue"], bins=[0, 30, 60, np.inf], labels=["Short", "Medium", "Long"])
    if 'MET_min' in df_discrete.columns: df_discrete["MET_min"] = pd.qcut(df_discrete["MET_min"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    if 'EnergyPerMinute' in df_discrete.columns: df_discrete["EnergyPerMinute"] = pd.qcut(df_discrete["EnergyPerMinute"], q=3, labels=["Low", "Medium", "High"], duplicates='drop')
    
    if 'exerciseGlucoseExcursion' in df_discrete.columns: df_discrete["exerciseGlucoseExcursion"] = pd.cut(df_discrete["exerciseGlucoseExcursion"], bins=[-np.inf, -40, -10, 10, np.inf], labels=["Severe Drop", "Moderate Drop", "Stable", "Rise"])
    if 'exerciseGlucoseRoc' in df_discrete.columns: df_discrete["exerciseGlucoseRoc"] = pd.cut(df_discrete["exerciseGlucoseRoc"], bins=startRoc_edges, labels=startRoc_labels)
    if 'minGlucosePostExercise' in df_discrete.columns: df_discrete["minGlucosePostExercise"] = pd.cut(df_discrete["minGlucosePostExercise"], bins=[-np.inf, 54, 70, 180, np.inf], labels=["Severe Hypo", "Hypo Risk", "Target", "Elevated"])
    if 'postExerciseTIR' in df_discrete.columns: df_discrete["postExerciseTIR"] = pd.cut(df_discrete["postExerciseTIR"], bins=[-np.inf, 50, 70, np.inf], labels=["Poor", "Borderline", "Target"])

    print("Discretization complete.")
    return df_discrete


# ==========================================
# DISTRIBUTION PLOT
# =========================================

def plot_single_feature_distribution(df, feature_name, title_prefix=""):
    """
    Plots a horizontal bar chart for a single specified feature.
    Assigns a distinct, colorblind-safe color to each discretized level (category).
    """
    if feature_name not in df.columns:
        print(f"Error: Feature '{feature_name}' not found in the dataset.")
        return


    # Calculate percentages
    counts = df[feature_name].value_counts(normalize=True) * 100
    try:
        # Sort by the underlying categorical/logical order if Pandas knows it
        counts = counts.sort_index()
    except TypeError:
        pass 

    y_pos = range(len(counts))
    
    # Expanded Okabe-Ito Colorblind-Safe Palette 
    # (Blue, Amber, Vermillion, Green, Light Blue, Yellow, Pink, Grey)
    color_palette = ['#0072B2', '#E69F00', '#D55E00', '#009E73', '#56B4E9', '#F0E442', '#CC79A7', '#999999']
    
    # Ensure the plot height dynamically scales with the number of bins
    fig, ax = plt.subplots(figsize=(10, max(3, len(counts) * 0.8)))
    
    # Map colors to bars (loops back to the start if there are more than 8 bins)
    colors = [color_palette[i % len(color_palette)] for i in range(len(counts))]

    bars = ax.barh(y_pos, counts.values, align='center', color=colors)

    # Add exact percentage text at the end of each bar
    for j, bar in enumerate(bars):
        val = counts.values[j]
        # Offset the text slightly past the end of the bar
        ax.text(val + 1.5, bar.get_y() + bar.get_height()/2, f'{val:.1f}%', 
                va='center', ha='left', fontsize=11, fontweight='bold')

    # Format Axes
    ax.set_yticks(y_pos)
    ax.set_yticklabels(counts.index.astype(str), fontsize=12)
    
    # Dynamically set X-axis limit to leave room for the percentage text
    ax.set_xlim(0, max(counts.values) * 1.15) 
    
    # Titles and Labels
    title = f"Distribution of {feature_name}"
    if title_prefix:
        title += f" {title_prefix}"
        
    ax.set_title(title, fontweight='bold', fontsize=15, pad=15)
    ax.set_xlabel("Percentage (%)", fontsize=12)

    # Despine for a clean, academic look
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    plt.tight_layout()
    plt.show()


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

    # 1. BMI: Group extremes to ensure statistical power
    if 'BMI' in clean_df.columns:
        clean_df['BMI'] = clean_df['BMI'].replace(
            {'Underweight': 'Normal/Underweight', 
             'Normal': 'Normal/Underweight',
             'Obese': 'Overweight/Obese', 
             'Overweight': 'Overweight/Obese'}
        )

    # 2. Rate of Change (Both Pre and During): Merge 'Rapidly' into standard directions
    for col in ['preExerciseRoc', 'exerciseGlucoseRoc']:
        if col in clean_df.columns:
            clean_df[col] = clean_df[col].replace(
                {'Rapidly Rising': 'Rising', 'Rapidly Falling': 'Falling'}
            )

    # 3. startExerciseGlucoseLevel: Merge the 4.1% 'Very High' into 'Elevated'
    if 'startExerciseGlucoseLevel' in clean_df.columns:
        clean_df['startExerciseGlucoseLevel'] = clean_df['startExerciseGlucoseLevel'].replace(
            {'Very High': 'Elevated'}
        )
        
    # 4. minGlucosePostExercise: Merge the 1.4% 'Elevated' into 'Target' (since it's a post-exercise recovery context)
    if 'minGlucosePostExercise' in clean_df.columns:
        clean_df['minGlucosePostExercise'] = clean_df['minGlucosePostExercise'].replace(
            {'Elevated': 'Target'}
        )

    print("✅ Bin collapsing complete! Dataset is mathematically safe.")
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

    # Rule 2: Root Nodes (Demographics)
    for node in tiers['static']:
        if node not in ['age', 'gender'] and node in learner.names():
            if 'age' in learner.names(): learner.addForbiddenArc(node, 'age')
            if 'gender' in learner.names(): learner.addForbiddenArc(node, 'gender')
        learner.addForbiddenArc('gender', 'age')  
        learner.addForbiddenArc('age', 'gender')  

    # Rule 3: Pre-Exercise internal chronology
    historical_pre = [n for n in tiers['pre'] if n != 'startExerciseGlucoseLevel']
    if 'startExerciseGlucoseLevel' in learner.names():
        for hist_feat in historical_pre:
            if hist_feat in learner.names():
                learner.addForbiddenArc('startExerciseGlucoseLevel', hist_feat)

    for var1, var2 in itertools.combinations(historical_pre, 2):
        if var1 in learner.names() and var2 in learner.names():
            learner.addForbiddenArc(var1, var2)
            learner.addForbiddenArc(var2, var1)

    # Rule 4: Exercise internal (Simultaneous)
    exercise_layer = [n for n in tiers['exercise']]
    for var1, var2 in itertools.combinations(exercise_layer, 2):
        if var1 in learner.names() and var2 in learner.names():
            learner.addForbiddenArc(var1, var2)
            learner.addForbiddenArc(var2, var1)

    # Rule 5: Outcome Chronology (During vs Post)
    for post_metric in tiers['outcome_post']:
        for during_metric in tiers['outcome_during']:
            if post_metric in learner.names() and during_metric in learner.names():
                learner.addForbiddenArc(post_metric, during_metric)
                
    for var1, var2 in itertools.combinations(tiers['outcome_during'], 2):
        if var1 in learner.names() and var2 in learner.names():
            learner.addForbiddenArc(var1, var2)
            learner.addForbiddenArc(var2, var1)
            
    for var1, var2 in itertools.combinations(tiers['outcome_post'], 2):
        if var1 in learner.names() and var2 in learner.names():
            learner.addForbiddenArc(var1, var2)
            learner.addForbiddenArc(var2, var1)

    return learner

# ==========================================
# NETWORK VISUALIZATION
# ==========================================
def visualize_network(bn, tiers):
    """Renders the Bayesian Network using a colorblind-safe Okabe-Ito palette."""
    dot_lines = [
        "digraph ExpertCausalModel {", 
        '  rankdir="TB";', 
        '  node [style="filled", shape="ellipse", fontname="Helvetica", margin="0.1"];'
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