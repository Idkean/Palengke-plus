import math
import sqlite3
import unittest
from pathlib import Path
import sys
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pandas as pd

import forecaster
import sync_da_prices


class SqaFixRegressionTests(unittest.TestCase):
    def test_sync_reads_existing_dates_from_configured_database(self):
        connection = sqlite3.connect(":memory:")
        connection.execute("CREATE TABLE prices (date TEXT)")
        connection.execute("INSERT INTO prices (date) VALUES (?)", ("2026-09-29",))
        with patch.object(sync_da_prices, "DB_PATH", "configured-database.db"), patch.object(
            sync_da_prices, "init_db"
        ), patch.object(
            sync_da_prices,
            "weekly_links",
            return_value=[("https://example.test/report", "September 29, 2026")],
        ), patch.object(sync_da_prices.sqlite3, "connect", return_value=connection) as connect:
            result = sync_da_prices.sync()

        self.assertEqual(result, 0)
        connect.assert_called_once_with("configured-database.db")

    def test_weekly_links_accepts_any_month_and_year(self):
        html = '''
        <a href="https://drive.google.com/file/d/abc123/view?usp=sharing"><center>October 15, 2026</a>
        <a href="https://drive.google.com/file/d/xyz789/view?usp=sharing"><center>March 02, 2027</a>
        '''
        reports = sync_da_prices.extract_report_links(html)
        self.assertEqual(len(reports), 2)
        self.assertEqual(reports[0][1], 'March 02, 2027')
        self.assertEqual(reports[1][1], 'October 15, 2026')

    def test_safe_mape_avoids_divide_by_zero_and_nan(self):
        actuals = pd.Series([0.0, 1.0, 0.0, 2.0])
        preds = pd.Series([0.0, 1.0, 2.0, 2.0])
        mape = forecaster.safe_mape(actuals, preds)
        self.assertTrue(math.isfinite(mape))
        self.assertGreaterEqual(mape, 0.0)

    def test_short_history_uses_baseline_with_wide_intervals(self):
        series = pd.Series(
            [100.0, 110.0, 90.0, 105.0, 95.0],
            index=pd.date_range('2026-09-19', periods=5),
        )
        result = forecaster.generate_baseline_forecast(series, 'test', 2)
        self.assertEqual(result['model_order'], 'LAST_VALUE_BASELINE')
        self.assertEqual(result['quality']['status'], 'insufficient_history')
        self.assertEqual(result['forecast'][0]['predicted_price'], 95.0)
        self.assertLess(result['forecast'][0]['ci_lower'], 95.0)
        self.assertGreater(result['forecast'][0]['ci_upper'], 95.0)

    def test_baselines_share_a_holdout_window(self):
        series = pd.Series(
            [100.0, 102.0, 104.0, 106.0, 108.0, 110.0, 112.0, 114.0, 116.0, 118.0],
            index=pd.date_range('2026-09-14', periods=10),
        )
        results = forecaster.evaluate_baselines(series, 2)
        self.assertEqual(
            [result['model'] for result in results],
            ['LAST_VALUE_BASELINE', 'MOVING_AVERAGE_BASELINE'],
        )
        self.assertTrue(all(result['validation_points'] == 2 for result in results))

    def test_holdout_order_selection_uses_training_data_only(self):
        series = pd.Series(
            [100.0 + index for index in range(10)],
            index=pd.date_range('2026-09-14', periods=10),
        )
        predictions = series.iloc[-2:]
        with patch.object(forecaster, 'find_best_arima_order', return_value=(1, 1, 0)) as order_search:
            with patch.object(forecaster, 'ARIMA') as arima:
                arima.return_value.fit.return_value.forecast.return_value = predictions
                result = forecaster.evaluate_holdout(series, 2)

        selected_training = order_search.call_args.args[0]
        self.assertEqual(len(selected_training), 8)
        self.assertEqual(selected_training.index[-1], series.index[-3])
        self.assertEqual(result['order'], (1, 1, 0))
        self.assertEqual(result['validation_points'], 2)
        self.assertEqual(result['rmse'], 0.0)


if __name__ == '__main__':
    unittest.main()
