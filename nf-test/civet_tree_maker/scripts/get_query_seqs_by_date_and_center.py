#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Get sample names according to a date range and sequencing centre.')
    parser.add_argument('--start_date', type=str, default=None,
                        help='Earliest sample date to select, of the form: 2021-07-01 (optional)')
    parser.add_argument('--end_date', type=str, default=None,
    		        help='Latest sample date to select, of the form: 2021-07-31 (optional)')
    parser.add_argument('--max_samples_per_month', type=str, default=None,
    		        help='Maximum number of random samples to take for each month (int) (optional)')
    parser.add_argument('--sequencing_centre', type=str, default=None,
    		        help='Four-letter code for sequencing centre, eg. NORW')    		        
    parser.add_argument('--cog_meta_file', type=str, default=None,
                        help='COG-UK metadata file')
    parser.add_argument('--out', type=str, default=None,
                        help='Filename for sample names (.txt)')

    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    if args.start_date and args.end_date:
    	start_date = args.start_date 
    	end_date = args.end_date
    cog_meta_file = args.cog_meta_file
    savefile = args.out
    if args.sequencing_centre:
    	sequencing_centre = args.sequencing_centre.upper()
    max_samples_per_month = args.max_samples_per_month

    #slice dataframe by query sequence date and sequencing centre
    df = pd.read_csv(cog_meta_file, parse_dates=['sample_date'], sep=',', header=0, usecols=['sample_date', 'sequence_name'])
    if args.start_date and args.end_date:
    	df = df.loc[df['sample_date'].between(start_date, end_date, inclusive='both')]
    if args.sequencing_centre:
    	df = df.loc[df['sequence_name'].str.startswith(f"England/{sequencing_centre}")]
    df.set_index('sample_date', inplace=True)
    #select at most n random samples per month without replacement, if the parameter is set
    if max_samples_per_month.isdigit():
    	max_samples_per_month = int(max_samples_per_month)
    	grouper = df.groupby(pd.Grouper(freq='1M'))
    	sampled_grouper = grouper.apply(lambda x: x.sample(min(max_samples_per_month,len(x)), random_state=1)).reset_index(drop=True)
    	save_subset = sampled_grouper.drop_duplicates(subset=['sequence_name'])

    else:
    	save_subset = df.drop_duplicates(subset=['sequence_name'])

    #save unique sample record names as a .txt
    save_subset['sequence_name'].to_csv(str(savefile), sep=',', header=False, index=False)
    print(f"Sequence record names saved as {savefile}")
    
