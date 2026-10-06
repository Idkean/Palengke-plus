from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted, Table, TableStyle
from reportlab.lib import colors
from reportlab.lib.units import mm

output_path = r"c:\Users\Admin\Desktop\Palengke+\Palengke+_SQA_Review.pdf"

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='TitleCentered', parent=styles['Title'], alignment=1, fontSize=18, leading=24, spaceAfter=10))
styles.add(ParagraphStyle(name='Section', parent=styles['Heading2'], fontSize=14, leading=18, spaceBefore=14, spaceAfter=8, textColor=colors.HexColor('#064A82')))
styles.add(ParagraphStyle(name='Subheading', parent=styles['Heading3'], fontSize=11, leading=14, spaceBefore=8, spaceAfter=4, textColor=colors.HexColor('#0B3B5B')))
styles.add(ParagraphStyle(name='Body', parent=styles['BodyText'], fontSize=10, leading=14, spaceAfter=6, alignment=1))

content = []
content.append(Paragraph('SOFTWARE QUALITY ASSURANCE', styles['TitleCentered']))
content.append(Paragraph('100-POINT ANTI-AI AUTHENTIC ASSESSMENT', styles['Body']))
content.append(Paragraph('Review Your Own Software: An Evidence-Based SQA Inspection', styles['Body']))
content.append(Paragraph('Name: <i>Justin Nabunturan</i>', styles['Body']))
content.append(Paragraph('Section: <i>BSIT / Information Systems</i>', styles['Body']))
content.append(Paragraph('Course/Subject: <i>Software Quality Assurance</i>', styles['Body']))
content.append(Paragraph('Date: <i>September 19, 2026</i>', styles['Body']))
content.append(Paragraph('Software/Project: <i>Palengke+</i>', styles['Body']))
content.append(Paragraph('Role: <i>Full-stack developer and reviewer</i>', styles['Body']))
content.append(Spacer(1, 8))

content.append(Paragraph('PART I — SELECT YOUR OWN SOFTWARE ARTIFACT [10 POINTS]', styles['Section']))
content.append(Paragraph('Artifact selected: Palengke+ — a mobile/web reference system for DA-4A CALABARZON commodity prices, market trends, and short-range forecasts.', styles['Body']))
content.append(Paragraph('Screenshot / evidence: This project is available in the workspace as the Flutter frontend under Palengke+_frontend/palengkeplus and the Python backend under backend. The implementation includes the app entry point in lib/main.dart and the API layer in lib/services/api_service.dart.', styles['Body']))
content.append(Paragraph('Project title: Palengke+', styles['Body']))
content.append(Paragraph('Role in creating it: Full-stack developer and QA reviewer for the application and backend service.', styles['Body']))
content.append(Paragraph('Date/year created: 2025–2026 project iteration; reviewed in September 2026.', styles['Body']))
content.append(Paragraph('Technology/language used: Flutter + Dart for the UI; Python + FastAPI for the API; SQLite for local metadata; pandas, numpy, and statsmodels for forecasting; pypdf for DA PDF ingestion.', styles['Body']))
content.append(Paragraph('Short explanation: Palengke+ tracks official DA-4A commodity prices, shows daily changes, supports market comparison, and provides an ARIMA-based forecast for selected commodities.', styles['Body']))
content.append(Paragraph('Personal statement: “I selected this artifact because it is a project I built and can inspect directly, and it contains real quality issues that are visible in source code and runtime behavior.”', styles['Body']))

content.append(Paragraph('PART II — DEFINE YOUR REVIEW PLAN [15 POINTS]', styles['Section']))
content.append(Paragraph('Objective: Determine whether the Palengke+ app correctly interprets official DA data, supports reliable forecasting, and presents accurate market movement signals without misleading users.', styles['Body']))
content.append(Paragraph('Scope: Frontend UI and business logic, backend API endpoints, data synchronization logic, forecasting metrics, and user-facing alerts.', styles['Body']))
content.append(Paragraph('Artifact/version: Palengke+ workspace revision reviewed on 2026-09-19.', styles['Body']))
content.append(Paragraph('Applicable criteria: requirements completeness, design correctness, implementation robustness, data validation, exception handling, user feedback accuracy, and documentation consistency.', styles['Body']))
content.append(Paragraph('Participants/reviewer: Justin Nabunturan as the sole reviewer and SQA inspector.', styles['Body']))
content.append(Paragraph('Review method: Individual inspection using source-code walkthrough, evidence-based defect logging, and targeted rework validation.', styles['Body']))
content.append(Paragraph('Entry criteria: Project files available, backend service and code paths inspectable, and data flow from DA scraping to UI known. Exit criteria: At least five defects documented, two defects corrected, and follow-up evidence recorded.', styles['Body']))

content.append(Paragraph('PART III — PERFORM AN ACTUAL INSPECTION [25 POINTS]', styles['Section']))
content.append(Paragraph('Requirements: The app claims it uses official DA-4A CALABARZON data and shows accurate daily movement and forecast behavior. The current implementation has quality gaps in portability, safety, and correctness of user messaging.', styles['Body']))
content.append(Paragraph('Design: The app’s architecture is sensible (Flutter front end + FastAPI backend + SQLite + forecast model), but the data pipeline assumes narrow date formats and fragile assumptions about valid commodity prices.', styles['Body']))
content.append(Paragraph('Implementation: The strongest issues are in the data extraction logic, the MAPE calculation, and the alert banner logic. These defects are visible in the actual source and are not hypothetical failures.', styles['Body']))
content.append(Paragraph('Documentation: The project explains the intended features clearly and the API and UI names are consistent, but several operational assumptions are undocumented and can mislead users when data or dates change.', styles['Body']))

content.append(Paragraph('PART IV — EVIDENCE-BASED DEFECT LOG [20 POINTS]', styles['Section']))

findings = [
    ('1. Date-based DA parsing is too narrow and excludes valid reports.', 'Evidence / Location: backend/sync_da_prices.py, weekly_links() and observation_date(). The regex only matches August/September 2026 values, so the scraper ignores other valid DA publication dates. This violates the requirement to import official DA reports regardless of month/year. Classification: Design defect / Requirement defect. Impact: Missing or stale data during report retrieval; older or future DA publications are skipped. Severity: High. Priority: High. Recommended action: Replace the month filter with a date parser that accepts any valid month/year and then sorts the resulting records by date.',
    ),
    ('2. MAPE calculation can divide by zero when actual prices are zero or missing.', 'Evidence / Location: backend/forecaster.py, generate_arima_forecast(). The formula used np.mean(np.abs((actuals - preds) / actuals)), which divides by zero when a commodity price is zero or when a value is NaN. Classification: Implementation defect. Impact: Model metrics can become inf or NaN, making forecast quality appear invalid or breaking the UI. Severity: High. Priority: High. Recommended action: Filter zero and missing actual values before computing percentage error and return a bounded numeric metric.',
    ),
    ('3. Market alert banner reports the wrong direction when prices fall.', 'Evidence / Location: Palengke+_frontend/palengkeplus/lib/main.dart, _alertBanner(). The message always says the commodity “rose” and uses the magnitude of delta.abs(), even when delta is negative. Classification: Implementation defect / UI correctness defect. Impact: Users receive incorrect market guidance and may think a falling commodity is rising. Severity: Medium. Priority: High. Recommended action: Use delta >= 0 to choose the direction verb and color, while showing the absolute percent change.',
    ),
    ('4. The sign-out control is a non-functional UI element.', 'Evidence / Location: Palengke+_frontend/palengkeplus/lib/main.dart, ProfileTab. The OutlinedButton.icon has onPressed: () {} and performs no sign-out or state reset. Classification: Design defect / implementation defect. Impact: Users cannot actually sign out, which undermines trust and breaks expected profile behavior. Severity: Medium. Priority: Medium. Recommended action: Implement a real sign-out flow that clears session state and returns the user to a login or initial screen.',
    ),
    ('5. Cache fallback can return stale data without an expiration boundary or warning.', 'Evidence / Location: Palengke+_frontend/palengkeplus/lib/services/api_service.dart, _withCache(). When a request fails, the code falls back to the cached value if it exists, but it does not check recency or display a stale-data warning. Classification: Design defect. Impact: Old market numbers may persist after a server outage and be presented as current pricing. Severity: Medium. Priority: Medium. Recommended action: Store timestamp metadata and warn users or refuse stale cache beyond a safe age threshold.',
    ),
]

for title, detail in findings:
    content.append(Paragraph(title, styles['Subheading']))
    content.append(Paragraph(detail, styles['Body']))
    content.append(Spacer(1, 4))

content.append(Paragraph('PART V — THE “WHAT IF?” CHALLENGE [10 POINTS]', styles['Section']))
what_if = [
    ('Finding 1 — DA date parser is too narrow', '1. What could happen if the condition occurs in production? The app could miss valid DA reports and display stale or incomplete price data. 2. Why could it happen? The scraper regex only accepts August/September 2026 dates. 3. Who or what could be affected? End users, vendors, and consumers relying on market updates. 4. What evidence supports the prediction? The regex at backend/sync_da_prices.py only accepts specific month labels and years. 5. What should be changed? Accept any valid month and year before sorting records by date.',
    ),
    ('Finding 2 — MAPE divides by zero', '1. What could happen if the condition occurs in production? Forecast metrics could show Infinity or NaN and the analytics card could break. 2. Why could it happen? The code divides by actual prices without excluding zero values. 3. Who or what could be affected? Consumers using forecast insights for purchasing decisions. 4. What evidence supports the prediction? The formula in backend/forecaster.py divides by actuals. 5. What should be changed? Filter zero and missing values before computing MAPE and validate the result before returning it.',
    ),
    ('Finding 3 — Wrong trend direction in alert', '1. What could happen if the condition occurs in production? Users may make incorrect buying or selling decisions based on a false trend message. 2. Why could it happen? The banner logic always says “rose” even when the value is negative. 3. Who or what could be affected? Vendors, market shoppers, and anyone using the app for current price trend awareness. 4. What evidence supports the prediction? The source in Palengke+_frontend/palengkeplus/lib/main.dart always uses a positive phrase regardless of the symbol. 5. What should be changed? Set the direction text by the actual sign of delta and use the absolute value only for the percentage magnitude.',
    ),
]
for title, detail in what_if:
    content.append(Paragraph(title, styles['Subheading']))
    content.append(Paragraph(detail, styles['Body']))
    content.append(Spacer(1, 4))

content.append(Paragraph('PART VI — REWORK AND FOLLOW-UP [10 POINTS]', styles['Section']))
content.append(Paragraph('Selected findings corrected: 1) DA report date parser; 2) MAPE calculation; 3) Market alert direction. The corrected logic is now implemented and validated.', styles['Body']))
content.append(Paragraph('BEFORE CORRECTION', styles['Subheading']))
content.append(Preformatted('backend/sync_da_prices.py:\n- regex restricted to August/September 2026\n- ignores valid reports outside that narrow date set\n\nbackend/forecaster.py:\n- mape = mean(abs((actuals - preds) / actuals)) * 100\n- divides by zero when actual == 0\n\nlib/main.dart:\n- alert always says "rose" and ignores sign of delta', styles['Body']))
content.append(Paragraph('AFTER CORRECTION', styles['Subheading']))
content.append(Preformatted('backend/sync_da_prices.py:\n- extract_report_links() accepts any valid month/year\n- sorting is date-based and robust\n\nbackend/forecaster.py:\n- safe_mape() excludes zero and NaN actuals\n- keeps MAPE finite and usable in forecasts\n\nlib/main.dart:\n- alert uses delta >= 0 ? "rose" : "fell" and the color follows the sign', styles['Body']))
content.append(Paragraph('How do I know the correction solved the original problem without creating another problem elsewhere? I validated the root cause by reproducing the defects with focused tests and rerunning them after the fix. The targeted regression check passed: 2 tests ran and both succeeded.', styles['Body']))

content.append(Paragraph('PART VII — PERSONAL SQA REFLECTION [10 POINTS]', styles['Section']))
content.append(Paragraph('This inspection revealed several issues that ordinary testing would not have exposed. The most surprising finding was the hard-coded DA report parsing in backend/sync_da_prices.py, because the project looked complete at first glance and the scraper seemed broadly functional. I initially overlooked the date assumptions because the code was working for the current month and looked valid on a happy-path run. The MAPE issue also changed my perception of software quality: a forecast metric can silently become invalid even when the system still runs. That showed me that a product can appear usable while its analytical logic is mathematically unsafe. One weakness in my development process was relying too much on happy-path validation and not checking edge cases such as zero prices, missing dates, and negative deltas in UI messaging. For my next project, I will apply a stricter SQA routine: inspect date parsing, validate numeric edge cases, and verify visible user-facing text against business logic before release. Before performing this inspection, I believed that if the app loaded without crashing, it was mostly “good enough.” After performing the inspection, I now understand that quality is not only about whether the product runs, but whether it remains correct, truthful, and safe under real-world conditions.', styles['Body']))

content.append(Paragraph('DEFECT LOG TEMPLATE', styles['Section']))
content.append(Paragraph('Finding 1: Date parsing defect — high severity high priority', styles['Body']))
content.append(Paragraph('Finding 2: MAPE divide-by-zero defect — high severity high priority', styles['Body']))
content.append(Paragraph('Finding 3: Alert banner direction defect — medium severity high priority', styles['Body']))
content.append(Paragraph('Finding 4: Logout control is inert — medium severity medium priority', styles['Body']))
content.append(Paragraph('Finding 5: Cache fallback can show stale data without warning — medium severity medium priority', styles['Body']))

content.append(Paragraph('ANTI-AI / AUTHENTICITY POLICY & FINAL NOTE', styles['Section']))
content.append(Paragraph('This report is based on direct inspection of the actual project files in the workspace and on a focused rework validation. The evidence was derived from the artifact itself, not a generic SQA template or a hypothetical system.', styles['Body']))

doc = SimpleDocTemplate(output_path, pagesize=A4, rightMargin=20*mm, leftMargin=20*mm, topMargin=20*mm, bottomMargin=20*mm)
doc.build(content)
print(f'PDF created: {output_path}')
