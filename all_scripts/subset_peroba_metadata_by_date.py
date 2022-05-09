#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Extracts a subset of the peroba metadata by date range, and saves the metadata and sample names separately.')
    parser.add_argument('--start_date', type=str, default=None,
                        help='Earliest sample date to select, of the form: 2021-07-01')
    parser.add_argument('--end_date', type=str, default=None,
    		        help='Latest sample date to select, of the form: 2021-07-31')
    parser.add_argument('--metadata_tsv', type=str, default=None,
                        help='Metadata tsv from Peroba')
    parser.add_argument('--output_metadata', type=str, default=None,
                        help='Filename for metadata slice (.tsv)')
    parser.add_argument('--output_names', type=str, default=None,
                        help='Filename for record names (.txt)')

    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    start_date = args.start_date 
    end_date = args.end_date
    metadata_tsv = args.metadata_tsv
    output_metadata = args.output_metadata
    output_names = args.output_names

    #slice dataframe
    df = pd.read_csv(metadata_tsv, parse_dates=['date'], sep='\t', header=0)
    date_subset = df.loc[df['date'].between(start_date, end_date, inclusive='both')]

    #save relevant metadata as .tsv
    date_subset.to_csv(f"{output_metadata}", sep='\t', header=True, index=False)
    print(f"Metadata subset saved as {output_metadata}")

    #save record names (format: "England/NORW-XXXXXXX/YYYY" to include as a .txt
    date_subset['strain'].to_csv(f"{output_names}", sep='\t', header=False, index=False)
    print(f"Record names saved as {output_names}")
