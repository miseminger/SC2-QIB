#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Get sample names of query sequences and of their top N nns according to a date range.')
    parser.add_argument('--start_date', type=str, default=None,
                        help='Earliest sample date to select, of the form: 2021-07-01')
    parser.add_argument('--end_date', type=str, default=None,
    		        help='Latest sample date to select, of the form: 2021-07-31')
    parser.add_argument('--nn_file', type=str, default=None,
                        help='Anonymized nearest neighbours file')
    parser.add_argument('--query_names', type=str, default=None,
                        help='Filename for query sample names (.txt)')
    parser.add_argument('--ref_names', type=str, default=None,
                        help='Filename for ref sample names (.txt)')
    parser.add_argument('--nn_file_subset', type=str, default=None,
                        help='Filename for subset of nn file (.csv)')
    parser.add_argument('--N', type=int, default=None,
                        help='Maximum number of neighbours to choose for each query sequence')

    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    start_date = args.start_date 
    end_date = args.end_date
    nn_file = args.nn_file
    query_names = args.query_names
    ref_names = args.ref_names
    nn_file_subset = args.nn_file_subset
    N = args.N

    #slice dataframe by query sequence date
    df = pd.read_csv(nn_file, parse_dates=['query date'], sep=',', header=0)
    date_subset = df.loc[df['query date'].between(start_date, end_date, inclusive='both')]

    #select at most n random samples per month without replacement, if the parameter is set
    if max_samples_per_month.isdigit():
    	max_samples_per_month = int(max_samples_per_month)
    	grouper = df.groupby(pd.Grouper(freq='1M'))
    	sampled_grouper = grouper.apply(lambda x: x.sample(min(max_samples_per_month,len(x)), random_state=1)).reset_index(drop=True)
 	
    	
    #keep just the first N neighbours for each query sequence
    date_N_subset = date_subset.groupby('query sequence').head(N)
    
    #save subset of nn file as .csv.xz
    date_N_subset.to_csv(f"{nn_file_subset}", sep=',', header=True, index=False, compression='infer')
    print(f"Metadata subset saved as {nn_file_subset}")

    #get unique names of N refs that are not also in the query names
    queries = set(date_N_subset['query sequence'])
    references = set(date_N_subset['reference sequence'])
    unique_references = pd.DataFrame(list(references.difference(queries)))
    
    #save unique query record names as a .txt
    date_N_subset['query sequence'].drop_duplicates().to_csv(f"{query_names}", sep=',', header=False, index=False)
    print(f"Query record names saved as {query_names}")
    
    #save unique ref record names, not also found in the query names, as a .txt
    unique_references.to_csv(f"{ref_names}", sep=',', header=False, index=False)
    print(f"{N} nearest neighbour record names for each query sequence saved as {ref_names}")

