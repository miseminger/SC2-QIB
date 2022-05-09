#!/usr/bin/env python3

import pandas as pd
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description='Replace "/" with "_" in sequence_name column.')   		        
    parser.add_argument('--cog_meta_file', type=str, default=None,
                        help='COG-UK metadata file')
    parser.add_argument('--out', type=str, default=None,
                        help='Output filename (.csv)')

    return parser.parse_args()


if __name__ == '__main__':

    args = parse_args()

    cog_meta_file = args.cog_meta_file
    savefile = args.out

    df = pd.read_csv(cog_meta_file, sep=',', header=0)
    df['sequence_name'] = df['sequence_name'].str.replace('/', '_')
    df.to_csv(str(savefile), sep="\t", header=True, index=False)
    

