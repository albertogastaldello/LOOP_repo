"""Meal detector proposed by Colmegna et al."""
# pylint: disable=too-few-public-methods # public methods inherited from parent class

# built-in imports
from typing import Union

# pip imports
import numpy as np
import pandas as pd
from scipy.signal import find_peaks, savgol_filter

# in-house imports
from meal_detector import MealDetector


class MealDetectorColmegna(MealDetector):
    """
    Implementation of meal detection algorithm proposed by Colmegna et al.

    Reference:
    Colmegna P, Bisio A, McFadden R, Wakeman C, Oliveri MC, Nass R, Breton M.
    Evaluation of a Web-Based Simulation Tool for Self-Management Support in Type 1 Diabetes: A Pilot Study.
    IEEE J Biomed Health Inform. 2022 Sep 23. DOI: 10.1109/JBHI.2022.3209090. Epub ahead of print. PMID: 36149995.

    The structure and parameter naming in the class is intended to follow the pseudo-code of the article (Appendix II).

    Parameter <max_relative_height> has been added to allow simple avoidance of cases where the base of mu's peak is
    inferred to be at the peak when there are two values close to each other. Now it is required that the inferred base
    of the peak is at most max_relative_height times as high as the peak.
    """

    DEFAULT_PARAMETERS = {
        "savgol_filter": {"window_length": 13, "polyorder": 3, "delta": 5},
        "peak_search": {"i1_min": 6, "i1_max": 6},
        "peak_base": {"i2_min": 5, "max_relative_height": 1.0},
        "peak_detection": {"height": 0.0075, "prominence": 0.0025, "distance": 6},
        "cgm_threshold": 90,
        "peak_threshold": 0.01,
        "cgm_increase_threshold": 40,
        "default_recovery_carbohydrates_grams": 20,
        "default_meal_size_grams": 49,  # article: 0.7g/kg if there are no logged meals. Computed for 70 kg of body mass
    }
    mu: pd.Series
    mu_increase: pd.Series

    # Comments in this class follow the steps of pseudo-code in Colmegna et al.

    def _calculate_mu(self) -> None:
        """Calculate mu, the product of the first and second derivates of the CGM, each clipped to positive values."""
        if self.data.CGM.shape[0] < self.params["savgol_filter"]["window_length"]:  # too few observations
            self.mu = pd.Series(0.0, index=self.data.index)  # pylint: disable=invalid-name  # no meals to be detected
        else:
            # 2. Estimate the element-wise first and second derivatives of CGM by means of a Savitzky-Golay filter
            cgm_d1 = savgol_filter(self.data.CGM, deriv=1, **self.params["savgol_filter"])
            cgm_d2 = savgol_filter(self.data.CGM, deriv=2, **self.params["savgol_filter"])
            # 3. Saturate the derivatives at zero
            # 4. Calculate mu as their product
            self.mu = pd.Series(  # pylint: disable=invalid-name
                cgm_d1.clip(min=0) * cgm_d2.clip(min=0), index=self.data.index
            )
        self.mu_increase = self.mu.shift(-1) - self.mu

    def _move_index_closer_to_peaks_base(self, start_idx: int, end_idx: int) -> int:
        """Move meal index close to the base of mu's peak within [start_idx, end_idx].

        Note: end_idx is not included in the search unlike in the article. This seems like an oversight in the article,
        as peak index will always have negative mu_increase, so it would be typically selected.

        Further, the article does not define which value to select when multiple minimum values are found. Here if mu is
        zero, we take the one closest to the peak where mu_increase is still 0. Additionally, if mu contains only
        missing values, end_idx is returned.

        Parameter max_relative_height is used as a requirement for maximum height of the base relative to the peak
        height (mu at <end_idx>).

        Parameters
        ----------
        start_idx : int
            The start index of the search area (included in the search).
        end_idx : int
            The end index of the search area (NOT included in the search).

        Returns
        -------
        int
            An index close to the peak's base.
        """
        start_idx = max(self.mu.index.min(), start_idx)
        # End index at most up to the 2nd last element, as mu_increase is not defined further
        end_idx = min(end_idx, self.mu.index.max())
        if self.mu_increase.loc[start_idx : (end_idx - 1)].isna().all():
            return end_idx

        relative_height = self.mu.loc[start_idx : (end_idx - 1)] / self.mu.loc[end_idx]
        search_index = relative_height.index[relative_height <= self.params["peak_base"]["max_relative_height"]]
        if len(search_index) == 0:  # If no samples from the search area match the criteria, return the furthest one
            return start_idx

        idx_base = self.mu_increase.loc[search_index].idxmin()
        if self.mu[idx_base] == 0 and self.mu_increase[idx_base] == 0:
            zeros = (self.mu.loc[search_index] == 0) & (self.mu_increase.loc[search_index] == 0)
            idx_base = zeros.index[zeros].max()
        return idx_base

    def _adjust_reported_mealtimes(self) -> None:
        """Adjust reported mealtimes, creating columns ADJUSTED_MEALTIME and CARB_AMOUNT_ADJUSTED in self.data."""
        self.data["ADJUSTED_MEALTIME"] = pd.NaT
        self.data["CARB_AMOUNT_ADJUSTED"] = 0.0

        for idx_meal, row in self.data.loc[self.data.CARB_AMOUNT > 0].iterrows():  # 5. Loop through the reported meals
            # 6. Find a potential peak index from the search area
            start_idx = max(self.mu.index.min(), idx_meal - self.params["peak_search"]["i1_min"])
            end_idx = min(idx_meal + self.params["peak_search"]["i1_max"], self.mu.index.max())
            if (self.mu.loc[start_idx:end_idx] == 0).all() or self.mu.loc[start_idx:end_idx].isna().any():
                idx_peak = idx_meal
            else:
                idx_peak = self.mu.loc[start_idx:end_idx].idxmax()

            # 7. Move peak index closer to the peak's base (by selecting the lowest upcoming increase)
            idx_meal_adj = self._move_index_closer_to_peaks_base(
                start_idx=idx_peak - self.params["peak_base"]["i2_min"], end_idx=idx_peak
            )

            self.data.loc[idx_meal, "ADJUSTED_MEALTIME"] = self.data.loc[idx_meal_adj, "BUCKET_START"]
            self.data.loc[idx_meal_adj, "CARB_AMOUNT_ADJUSTED"] += row.CARB_AMOUNT

    def _get_total_carbs_logged(self, index: int, distance: int) -> Union[int, float]:
        """Get total amount of carbs logged and detected within a specified distance of an index."""
        return (
            self.data.loc[(index - distance) : (index + distance), ["CARB_AMOUNT_ADJUSTED", "CARBS_UNANNOUNCED"]]
            .sum()
            .sum()
        )

    def _detect_unannounced_meals(self) -> None:
        """Detect unannounced meals, creating column CARBS_UNANNOUNCED in self.data."""
        if self.sampling_interval_minutes != 5:  # self.params["peak_detection"]["distance"] assumes 5-minute sampling
            raise NotImplementedError
        self.data["CARBS_UNANNOUNCED"] = np.nan
        # 9. Identify potential unannounced meals at peak indices
        idx_unannounced, _ = find_peaks(self.mu, **self.params["peak_detection"])

        # 10. Evaluate mu at potential peak indices to extract peak heights
        for idx_peak in self.mu.index[idx_unannounced]:  # 11. Loop through the peaks
            # 12. Move peak index closer to peak's base
            idx_adj = self._move_index_closer_to_peaks_base(
                start_idx=idx_peak - self.params["peak_base"]["i2_min"], end_idx=idx_peak
            )

            # 13. Compute glucose deviation between peak's base to 60 minutes ahead
            idx_adj_plus_hour = idx_adj + int(60 / self.sampling_interval_minutes)
            if idx_adj_plus_hour not in self.data.index or np.isnan(self.data.CGM[idx_adj_plus_hour]):
                continue
            gluc_dev = self.data.CGM[idx_adj_plus_hour] - self.data.CGM[idx_adj]

            # 14. CGM is below the threshold and mu is above the peak threshold -> detected recovery carbs
            if (
                self.data.CGM[idx_adj] <= self.params["cgm_threshold"]
                and self.mu[idx_peak] >= self.params["peak_threshold"]
            ):
                # 15. If peak is more than 3 samples apart from other detected hypo-treatments
                if self._get_total_carbs_logged(idx_adj, distance=3) == 0:
                    # 16. Append 20 grams to reported meals
                    self.data.loc[idx_adj, "CARBS_UNANNOUNCED"] = self.params["default_recovery_carbohydrates_grams"]
            elif gluc_dev >= self.params["cgm_increase_threshold"]:  # 18. Glucose increase is at or above the threshold
                # 19. Peak is more than 9 samples apart from other meals
                if self._get_total_carbs_logged(idx_adj, distance=9) == 0:
                    # 20. append average meal size from  historical data
                    meal_size = self.data.CARB_AMOUNT.loc[:idx_peak].replace({0: np.nan}).mean()
                    if np.isnan(meal_size):
                        meal_size = self.params["default_meal_size_grams"]
                    self.data.loc[idx_adj, "CARBS_UNANNOUNCED"] = meal_size

    def _detect_meals_for_a_single_subject(self) -> None:
        """Detect meals for a single subject, starting by adjusting reported mealtimes."""
        self._calculate_mu()
        self.data["MU"] = self.mu
        self._adjust_reported_mealtimes()
        self._detect_unannounced_meals()
