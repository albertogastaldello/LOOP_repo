"""Meal detector base class."""

# built-in imports
import abc
import logging
from typing import Any, Dict, Optional, Union

# pip imports
import numpy as np
import pandas as pd
import toml
import tqdm

# get logger based on custom config
logger = logging.getLogger(__name__)


class MealDetector(abc.ABC):
    """Meal detector abstract base class, implementing structure for meal detection algorithms."""

    DEFAULT_PARAMETERS: Dict[str, Any] = {}
    params: Dict[str, Any]
    sampling_interval_minutes: int
    data: pd.DataFrame

    def __init__(self, params: Optional[Union[str, Dict[str, Any]]] = None) -> None:
        """Initialize the meal detector.

        Parameters
        ----------
        params : Optional[Union[str, Dict[str, Any]]]
            Parameters used by the meal detection (either a dictionary or a path to a toml-file). Default None leads
            to using DEFAULT_PARAMETERS instead.
        """
        self.params = self.DEFAULT_PARAMETERS
        if params is not None:
            if isinstance(params, str):
                self.params = self.params | toml.load(params)
            else:
                self.params = self.params | params
            logger.info(f"Meal detector set up with the following parameters: {self.params}")

    @abc.abstractmethod
    def _detect_meals_for_a_single_subject(self) -> None:
        """Detect meal for a single subject.

        This method should use single subject data in self.data (containing columns CGM and CARB_AMOUNT) for meal
        detection.

        For mealtime adjustment, the following columns should be added:
         - ADJUSTED_MEALTIME for mealtime adjusted based on the CGM signal, and
         - CARB_AMOUNT_ADJUSTED for carbohydrate amount at the adjusted mealtime.

        For unannounced meal detection, column CARBS_UNANNOUNCED should be added to denote the meal size at an inferred
        mealtime.
        """

    def get_parameters(self) -> Dict[str, Any]:
        """Get meal detector parameters."""
        return self.params

    def detect_meals(self, input_data: pd.DataFrame) -> pd.DataFrame:
        """Detect meals based on the CGM signal and reported meals in the input data.

        This methods serves as a wrapper for method _detect_meals_for_a_single_subject.

        Parameters
        ----------
        input_data : pd.DataFrame
            The input data, containing columns PATIENT_ID, BUCKET_START, CGM and CARB_AMOUNT.

        Returns
        -------
        pd.DataFrame
            The input data, augmented with the meal detection results from _detect_meals_for_a_single_subject.
        """
        result = pd.DataFrame()
        for _, input_data_patient in tqdm.tqdm(input_data.groupby("PATIENT_ID"), "Meal detection for each PATIENT_ID"):
            assert (input_data_patient.index.to_series().diff().dropna() == 1).all(), "Step index required."
            time_delta = input_data_patient.BUCKET_START.diff()
            assert time_delta.nunique() == 1, "Time grid should be evenly spaced."
            self.sampling_interval_minutes = int(time_delta.dropna().iat[0] / np.timedelta64(1, "m"))
            self.data = input_data_patient.copy()
            self._detect_meals_for_a_single_subject()
            result = result.append(self.data)
        return result
