
import pandas as pd
from sqlalchemy import create_engine, text, URL
from getpass import getpass
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

logger = logging.getLogger(__name__)

# Database connection settings
username = "root"
password = getpass("Enter your MySQL password: ")

host = "127.0.0.1"
port = 3306
database = "healthcare_project"

# Create the connection engine
connection_url = URL.create(
    drivername="mysql+pymysql",
    username=username,
    password=password,
    host=host,
    port=port,
    database=database
)

engine = create_engine(connection_url)


def load_accepted_claims(accepted_df, engine):
    """Load accepted claims while skipping existing claim IDs."""

    inserted_count = 0
    skipped_count = 0

    with engine.begin() as connection:
        for _, row in accepted_df.iterrows():

            existing_claim = connection.execute(
                text("""
                    SELECT 1
                    FROM target_claims
                    WHERE claim_id = :claim_id
                    LIMIT 1
                """),
                {"claim_id": row["claim_id"]}
            ).first()

            if existing_claim:
                logger.info(
                    "Skipped existing claim: %s",
                    row["claim_id"]
                )
                skipped_count += 1
                continue

            connection.execute(
                text("""
                    INSERT INTO target_claims
                        (claim_id, patient_id, amount, status)
                    VALUES
                        (:claim_id, :patient_id, :amount, :status)
                """),
                {
                    "claim_id": row["claim_id"],
                    "patient_id": row["patient_id"],
                    "amount": row["amount"],
                    "status": row["status"]
                }
            )

            inserted_count += 1

            logger.info(
                "Loaded claim: %s",
                row["claim_id"]
            )

    logger.info(
        "Load summary: %d inserted, %d skipped",
        inserted_count,
        skipped_count
    )

    return inserted_count, skipped_count


try:
    logger.info("Healthcare Claims ETL started")

    # Test the database connection
    with engine.connect() as connection:
        result = connection.execute(text("SELECT DATABASE()"))
        print("Connected to database:", result.scalar())

    # Extract raw claims
    query = """
        SELECT claim_id, patient_id, amount, status
        FROM raw_claims_staging
        ORDER BY claim_id
    """

    df = pd.read_sql(query, engine)

    logger.info("Extracted %d raw rows", len(df))

    print("\nRaw staging data:")
    print(df)

    print("\nRaw record count:", len(df))
    print("Raw total amount:", df["amount"].sum())

    # Identify duplicate claim IDs
    duplicate_mask = df["claim_id"].duplicated(keep=False)

    # Identify invalid amounts
    invalid_amount_mask = (
        df["amount"].isna() | (df["amount"] <= 0)
    )

    # Identify invalid statuses
    valid_statuses = ["Approved", "Pending", "Rejected"]

    invalid_status_mask = (
        df["status"].isna()
        | (df["status"].str.strip() == "")
        | (~df["status"].str.strip().isin(valid_statuses))
    )

    # Accept unique claims with valid amounts and statuses
    accepted_df = df[
        ~duplicate_mask
        & ~invalid_amount_mask
        & ~invalid_status_mask
    ].copy()

    # Load accepted claims into MySQL
    inserted_count, skipped_count = load_accepted_claims(
        accepted_df, engine
    )

        # Verify the target table after loading
    with engine.connect() as connection:
        target_result = connection.execute(
            text("""
                SELECT
                    COUNT(*) AS total_records,
                    COALESCE(SUM(amount), 0) AS total_amount
                FROM target_claims
            """)
        ).mappings().one()

    target_records = target_result["total_records"]
    target_amount = float(target_result["total_amount"])

    print("\n--- Target Verification ---")
    print("Target records:", target_records)
    print("Target amount:", target_amount)

    expected_records = 8
    expected_amount = 29500.00

    if (
        target_records == expected_records
        and abs(target_amount - expected_amount) < 0.01
    ):
        print("Target verification: PASS")
        logger.info("Target verification passed")
    else:
        print("Target verification: FAIL")
        logger.error(
            "Target verification failed: records=%d, amount=%.2f",
            target_records,
            target_amount
        )

    # Reject duplicates, invalid amounts, or invalid statuses
    rejected_df = df[
        duplicate_mask
        | invalid_amount_mask
        | invalid_status_mask
    ].copy()

    logger.info(
        "Classification complete: %d accepted, %d rejected",
        len(accepted_df),
        len(rejected_df)
    )

    print("\nAccepted records:")
    print(accepted_df)

    print("\nRejected records:")
    print(rejected_df)

    # Export rejected records
    rejected_df.to_csv("claim_exceptions.csv", index=False)

    logger.info(
        "Saved %d rejected rows to claim_exceptions.csv",
        len(rejected_df)
    )

    # ETL summary
    print("\n--- ETL Summary ---")
    print("Raw rows:", len(df))
    print("Accepted rows:", len(accepted_df))
    print("Rejected rows:", len(rejected_df))
    print("Accepted amount:", accepted_df["amount"].sum())
    print("Inserted rows:", inserted_count)
    print("Skipped existing rows:", skipped_count)

    # Test status validation with a temporary copy
    test_df = df.copy()
    test_df.loc[test_df.index[0], "status"] = "Unknown"

    test_invalid_status = (
        test_df["status"].isna()
        | (test_df["status"].str.strip() == "")
        | (~test_df["status"].str.strip().isin(valid_statuses))
    )

    print("\n--- Status Validation Test ---")
    print(
        "Invalid status rows detected:",
        test_invalid_status.sum()
    )

    # Reconcile raw, accepted, and rejected rows
    print("\n--- Final Reconciliation ---")

    total_rows = len(df)
    accepted_rows = len(accepted_df)
    rejected_rows = len(rejected_df)

    print("Raw rows:", total_rows)
    print("Accepted + rejected:", accepted_rows + rejected_rows)

    if total_rows == accepted_rows + rejected_rows:
        print("Row reconciliation: PASS")
    else:
        print("Row reconciliation: FAIL")

    # Verify classification integrity
    print("\n--- Classification Integrity ---")

    accepted_indexes = set(accepted_df.index)
    rejected_indexes = set(rejected_df.index)

    overlap = accepted_indexes & rejected_indexes
    accounted_for = accepted_indexes | rejected_indexes

    print("Rows in both groups:", len(overlap))
    print("Rows accounted for:", len(accounted_for))

    if len(overlap) == 0 and len(accounted_for) == len(df):
        print("Classification integrity: PASS")
    else:
        print("Classification integrity: FAIL")

    logger.info("Healthcare Claims ETL completed successfully")

except Exception:
    logger.exception("Healthcare Claims ETL failed")
    raise

finally:
    engine.dispose()
