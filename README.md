# Healthcare Claims ETL Pipeline

## Overview
A Python and MySQL ETL project that extracts synthetic healthcare claims, validates data quality, identifies duplicate claims and invalid amounts, loads accepted claims, and reports exceptions.

## Technologies
- Python
- Pandas
- MySQL
- SQLAlchemy
- PyMySQL
- Logging

## ETL Workflow
1. Extract claims from MySQL staging data.
2. Identify duplicate claim IDs.
3. Validate claim amounts.
4. Separate accepted and rejected records.
5. Load accepted claims into the target table while skipping existing IDs.
6. Export rejected records to a CSV report.
7. Verify target totals and reconcile row counts.

## Sample Run Results
- Raw rows processed: 11
- Accepted rows: 4
- Rejected rows: 7
- Accepted amount: 15000
- Target records verified: 8
- Target amount verified: 29500
- Row reconciliation: PASS
- Classification integrity: PASS

These results reflect one run against the local synthetic project database.

## Setup
1. Install Python and MySQL.
2. Create the required database and tables using the SQL scripts provided in this repository.
3. Install dependencies:

   `pip install -r requirements.txt`

4. Run the pipeline:

   `python etl_pipeline.py`

The script prompts for the MySQL password at runtime.

## Data Privacy
This project is intended for synthetic demonstration data. Do not commit real patient information, passwords, or database credentials.

## Future Improvements
- Automated tests
- More comprehensive validation rules
- Automated exception loading into MySQL
- Claims analytics and visualizations
