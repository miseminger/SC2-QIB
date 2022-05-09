#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Join COG-UK metadata with the PANGO lineages file')
    parser.add_argument('--cog_metadata_file', type=str, default=None,
                        help='Filename for subset of COG-UK metadata file (.csv)')
    parser.add_argument('--lineage_report', type=str, default=None,
                        help='Filename for Pango lineage report')  
    parser.add_argument('--merged_file', type=str, default=None,
                        help='Path for merged output file (.csv or .csv.xz)')                        
    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    cog_metadata_file = args.cog_metadata_file
    merged_file = args.merged_file
    lineage_report = args.lineage_report 

    # load cog_uk_data
    cog_df = pd.read_csv(cog_metadata_file, header=0)

    # delete existing civet lineage column
    cog_df = cog_df.drop(columns=['lineage'])
    
    # merge with pango lineage report
    pango_df = pd.read_csv(lineage_report, header=0)
    pango_df = pango_df.rename(columns={'taxon':'sequence_name'})

    save_df = cog_df.merge(pango_df, how='left', on='sequence_name')
    
    # add 'sequencing_centre' column
    save_df['sequencing_centre'] = save_df['sequence_name'].str.split('/').str[1].str.split('-').str[0]
    
    # change name format to match the names in .treefile
    save_df['sequence_name'] = save_df['sequence_name'].str.replace('/', '_') 
    save_df['sequence_name'] = '_' + save_df['sequence_name'] + '_'
    # save merged df as .csv
    save_df.to_csv(merged_file, sep=',', header=True, index=False, compression='infer')
