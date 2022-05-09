#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Return all four-letter sequencing site codes that exist in the COG-UK metadata file.')   		        
    parser.add_argument('--cog_meta_file', type=str, default=None,
                        help='COG-UK metadata file')
    parser.add_argument('--cutoff', type=int, default=None,
                        help='Ignore all sequencing sites that have <cutoff samples in the metadata file')

    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    cog_meta_file = args.cog_meta_file
    cutoff = args.cutoff
    
    df = pd.read_csv(cog_meta_file, parse_dates=['sample_date'], usecols=['sequence_name', 'sample_date'])
    df['country'] = df['sequence_name'].str.split('/').str[0]
    
    #keep only centres from England
    mask = (df['country'] == 'England')
    df = df.loc[mask]
    
    #take the first four chars of each sequencing site code
    df['sequencing_centre'] = df['sequence_name'].str.split('/').str[1].str.split('-').str[0]
    df['sequencing_centre'] = df['sequencing_centre'].str.slice(stop=4)
    
    #ignore all the sequencing site names that contain a number: these are typos
    alpha_mask = df['sequencing_centre'].str.isalpha() 
    df['sequencing_centre'] = df['sequencing_centre'].loc[alpha_mask]
    
    #discard all the sites that have <cutoff samples, if --cutoff was specified
    if args.cutoff:
        counts = df.groupby(['sequencing_centre'])['sequence_name'].count().reset_index()
        sites_to_keep = counts['sequencing_centre'].loc[counts['sequence_name'].astype(int) >= cutoff]
        sites_to_keep = sites_to_keep.tolist()    

    else:
    	sites_to_keep = pd.unique(df['sequencing_centre'])
    	
    print(sites_to_keep)

    
