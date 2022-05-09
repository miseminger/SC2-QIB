#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Join COG-UK metadata with metadata from the nearest neighbours file')
    parser.add_argument('--nn_file_subset', type=str, default=None,
                        help='Filename for subset of nn file (.csv.xz)')
    parser.add_argument('--cog_metadata_file', type=str, default=None,
                        help='Filename for subset of COG-UK metadata file (.csv)')
    parser.add_argument('--lineage_report', type=str, default=None,
                        help='Filename for Pango lineage report')  
    parser.add_argument('--merged_file', type=str, default=None,
                        help='Path for merged output file (.csv or .csv.xz)')                        
    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    nn_file_subset = args.nn_file_subset 
    cog_metadata_file = args.cog_metadata_file
    merged_file = args.merged_file
    lineage_report = args.lineage_report

    nn_df = pd.read_csv(nn_file_subset, header=0)

    # create query_df of query info
    query_df = nn_df.loc[:, ['query sequence', 'query date']]
    query_df['NUTS1'] = "East_Of_England"
    query_df['nn_type'] = 'query'
    query_df = query_df.rename(columns={'query sequence':'sequence_name', 'query date':'nnfile_date'})
    query_df = query_df.drop_duplicates() 
    #create ref_df of ref info
    ref_df = nn_df.loc[:, ['reference sequence', 'reference date', 'reference NUTS1']]
    ref_df = ref_df.rename(columns={'reference sequence':'sequence_name', 'reference date':'nnfile_date', 'reference NUTS1':'NUTS1'})
    ref_df['nn_type'] = 'reference'
    ref_df = ref_df.drop_duplicates() 

    # stack ref_df and query_df, and keep only unique rows
    stack_df = pd.concat([query_df, ref_df])
    stack_df = stack_df.drop_duplicates()     

    # merge with cog_uk_data
    cog_df = pd.read_csv(cog_metadata_file, header=0)

    merged_df = cog_df.merge(stack_df, how='left', on='sequence_name')

    # delete existing civet lineage column
    merged_df = merged_df.drop(columns=['lineage'])
    
    # merge with pango lineage report
    pango_df = pd.read_csv(lineage_report, header=0)
    pango_df = pango_df.rename(columns={'taxon':'sequence_name'})

    save_df = merged_df.merge(pango_df, how='left', on='sequence_name')
    
    # add 'sequencing_centre' column
    save_df['sequencing_centre'] = save_df['sequence_name'].str.split('/').str[1].str.split('-').str[0]
    
    # change name format to match the names in .treefile
    save_df['sequence_name'] = save_df['sequence_name'].str.replace('/', '_') 

    # save merged df as .csv
    save_df.to_csv(merged_file, sep=',', header=True, index=False, compression='infer')
