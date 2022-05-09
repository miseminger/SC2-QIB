#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Create dates + regions file for treetime input')
    parser.add_argument('--metadata_tsv', type=str, default=None,
                        help='Peroba metadata file containing sequences of interest')
    parser.add_argument('--leaftips', type=str, default=None,
                        help='Path to .txt file of leaf tip names')
    parser.add_argument('--out', type=str, default=None,
                        help='Path for output .tsv file')

    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()
    metadata_tsv = args.metadata_tsv
    leaftips = args.leaftips
    out = args.out

    #read in dataframe
    df = pd.read_csv(metadata_tsv, header=0, sep='\t', dtype='str')
    df = df.rename(columns={'strain':'name'}) #header required by treetime

    #create columns for country and region to use in mugration models
    df['country'] = df['name'].str.split('/').str[0]
    df['region'] = df['name'].str.split('/').str[1]
    df['region'] = df['region'].str.split('-').str[0]
    
    #include only the names that match the names in the alignment
    leaf_df = pd.read_csv(leaftips, header=None)
    leaf_df = leaf_df.rename(columns={0:'name'})

    #add dates to leaf_df, and format the names like in the tree
    save_df = leaf_df.merge(df, how='left')
    save_df['name'] = save_df['name'].str.replace('/', '_')

    save_df.to_csv(out, sep='\t', index=False)


