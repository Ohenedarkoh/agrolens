
import sys
import pandas as pd



def profile_csv(file_path, file_name, date_column=None):

    # Read the first 50,000 rows of the CSV file
    df = pd.read_csv(file_path, nrows=50000)

    print(f"\n{'=' * 50}")
    print(f"Profiling: {file_name}")
    print(f"{'=' * 50}")

    # 1. Display basic information about the dataset
    print(f"\nRows: {len(df)}")
    print(f"Columns: {len(df.columns)}")
    print(f"\nColumn names: {list(df.columns)}")
    print(f"\nData types:\n{df.dtypes}")

    # 2. Count missing values in each column
    print(f"\nMissing values:\n{df.isnull().sum()}")

    # 3. Check the number of unique values in each column
    for column in df.columns:
        values = df[column].dropna().unique()

        print(f"\n{column}: {len(values)} unique values")

        # Display all values if there are 20 or fewer
        if len(values) <= 20:
            print(values)
        else:
            # Otherwise, display only the first five values
            print(f"Sample values: {values[:5]}")

    # 4. Check whether the price column contains invalid numbers
    price_column = None

    for column in df.columns:
        if column.lower() == "price":
            price_column = column
            break

    if price_column is not None:

        # Convert prices to numeric; invalid values become NaN
        prices = pd.to_numeric(df[price_column], errors="coerce")

        # Count and display invalid price values
        invalid_prices = prices.isna().sum()
        print(f"\nInvalid prices: {invalid_prices}")

        if invalid_prices > 0:
            bad_values = df.loc[prices.isna(), price_column].head(5)
            print(f"Examples: {bad_values.tolist()}")

    # 5. Check the date range if a date column was provided
    if date_column and date_column in df.columns:

        # Convert values to dates; unparseable values become NaT
        dates = pd.to_datetime(df[date_column], errors="coerce")

        print(f"\nDate range: {dates.min()} to {dates.max()}")
        print(f"Invalid dates: {dates.isna().sum()}")

    # 6. Count completely duplicated rows
    print(f"\nExact duplicate rows: {df.duplicated().sum()}")


# Run the profiling function when the script is executed directly
if __name__ == "__main__":

    # Check that the required command-line arguments were provided
    if len(sys.argv) < 3:
        print("Usage: python profile_csv.py <path> <name> [date_col]")
        sys.exit(1)

    # Retrieve the file path, dataset name, and optional date column
    file_path = sys.argv[1]
    file_name = sys.argv[2]
    date_column = sys.argv[3] if len(sys.argv) > 3 else None

    # Start profiling the CSV file
    profile_csv(file_path, file_name, date_column)
