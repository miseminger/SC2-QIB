#!/usr/bin/env nextflow

/*
This pipeline is built to create maximum likelihood trees out of SARS-CoV-2 samples, with the option to enrich with nearest neighbours.  A date range must always be specified, but beyond this there are several ways of subsetting:

--take a random sample of up to max_samples_per_month seqs per month
--reduce your query samples to the diverseQueries most diverse: to skip this, set diverseQueries=false
--reduce your nearest neighbours samples to the diverseNeighbours most diverse: to skip this, set diverseNeighbours=false
--specify a four-letter sequencing site code (England-based only) to limit your samples to (only when not using nns)

To include nearest neighbours, specify params.nns as a uvaia output file with adm2 removed for anonymity.  If not using nns, params.nns must be set to "NO_FILE".
*/

params.cog_fasta = "/home/ubuntu/ongaeshi-mnt/civet/cog_global_*.fasta.xz"
params.cog_meta = "/home/ubuntu/ongaeshi-mnt/civet/cog_global_*public.csv.xz"
params.wuhan_hu_1 = "/home/ubuntu/Wuhan-Wu-1-linear.fasta"
params.start_date = "2021-12-01"
params.end_date = "2021-12-15"
params.diverseQueries = 5  // integer or false
params.nns = "NO_FILE" // "/home/ubuntu/03.nn_geodate_min_noadm2.csv.xz"
params.diverseNeighbours = false
params.centre = "ALDP"  // integer or false
params.max_samples_per_month = 20

cog_fasta = file(params.cog_fasta)
cog_meta = file(params.cog_meta)
wuhan_hu_1 = file(params.wuhan_hu_1)
nn_file = file(params.nns)


process chooseSamples {
    input:
    file cog_meta
    file nn_file

    output:
    tuple file("query_samples.txt"), file("nn_samples.txt") optional true into fasta_ch

    script
    if !params.nns
        """
        python3 /home/ubuntu/scripts/get_query_seqs_by_date_and_center.py --cog_meta_file $cog_meta --start_date $params.start_date --end_date $params.end_date --out "query_samples.txt" --sequencing_centre $params.centre --max_samples_per_month $params.max_samples_per_month
        """
        
    else
        """
        python3 /home/ubuntu/scripts/get_seqs_by_date_max.py --nn_file $nn_file --start_date $params.start_date --end_date $params.end_date --max_samples_per_month $params.max_samples_per_month
        """
}


process getFastaRecords {
    input:
    file "*" from fasta_ch
    file cog_fasta
    file wuhan_hu_1
        
    output:
    tuple file("query_samples_ref.aln"), file("nn_samples_ref.aln") optional true into mask_ch
    file "query_samples.aln"
    file "nn_samples.aln" optional true
    
    script
    if !params.nns
        """
        xzgrep -w -A 1 -f query_samples.txt $cog_fasta --no-group-separator > query_samples.aln
        cat $wuhan_hu_1 query_samples.aln > query_samples_ref.aln
        """
        
    else
        """
        xzgrep -w -A 1 -f query_samples.txt $cog_fasta --no-group-separator > query_samples.aln
        cat $wuhan_hu_1 query_samples.aln > query_samples_ref.aln
        
        xzgrep -w -A 1 -f nn_samples.txt $cog_fasta --no-group-separator > nn_samples.aln
        cat $wuhan_hu_1 nn_samples.aln > nn_samples_ref.aln
        """
}


process maskProblematicSites {
    input:
    file("query_samples_ref.aln") from mask_ch
    
    output:
    file("query_samples_ref_masked.aln") into wu_ch
        
    """
    python3 /home/ubuntu/ProblematicSites_SARS-CoV2/src/mask_alignment_using_vcf.py -v /home/ubuntu/ProblematicSites_SARS-CoV2/problematic_sites_sarsCov2.vcf -i query_samples_ref.aln -o query_samples_ref_masked.aln -r "Wuhan-Hu-1"
    """
}


process removeWuhanHu1 {
    input:
    file("query_samples_ref_masked.aln") from wu_ch
    
    output:
    file("query_samples_masked.aln") into query_aln_ch
        
    """
    sed '/Wuhan-Hu-1/,+1d' query_samples_ref_masked.aln > query_samples_masked.aln
    """
}


(reduceQueries_ch, fastTree_ch) = ( !params.diverseQueries
                 ? [Channel.empty(), query_aln_ch]
                 : [query_aln_ch, Channel.empty()] )
                 
                 
(reduceNeighbours_ch, fastTreeNN_ch) = ( !params.diverseNeighbours
                 ? [Channel.empty(), nn_aln_ch]
                 : [nn_aln_ch, Channel.empty()] )
            

process reduceQueries {
    input:
    file("query_samples_masked.aln") from reduceQueries_ch
    
    output:
    file("query_samples_masked.aln.tre")
    file("reduced_queries.txt")
    file("query_samples_masked.aln.tre.pda")
    file("reduced_queries.aln") into optional_ch
    
    shell:
    template('reduce_queries.txt')
}


process reduceNeighbours {
    input:
    file("nn_samples_masked.aln") from reduceNeighbours_ch
    
    output:
    file("nn_samples_masked.aln.tre")
    file("reduced_nns.txt")
    file("nn_samples_masked.aln.tre.pda")
    file("reduced_nns.aln") into optional_nn_ch
    
    shell:
    template('reduce_neighbours.txt')
}


fastTree_ch.mix(optional_ch).into rmdup_q_ch
fastTreeNN_ch.mix(optional_nn_ch).into rmdup_nn_ch


process removeDuplicates {
    input:
    file queries from rmdup_q_ch
    file nn_aln from rmdup_nn_ch
    file nn_file
    
    output:
    file("allseqs.aln") into { rapidnj_tree_ch; pango_ch; cog_select_ch }
 
    script:
    def filter = nn_file.name != 'NO_FILE' ? "--filter $nn_aln" : ''   
    """
    cat queries $filter | seqkit rmdup -s > allseqs.aln
    """
}


process buildFastTree {
    input:
    file 'allseqs.aln' from rapidnj_tree_ch

    output:
    file("fast.aln.tre") into slow_tree_start_ch
    file("reformatted.aln") into slow_tree_aln

    shell:
    template('rapidnj_tree.txt')
}



process refineTree {
    input:
    file("reformatted.aln") from slow_tree_aln
    file("fast.aln.tre") from slow_tree_start_ch
    
    output:
    file("seqs.aln.treefile")
    
    shell:
    template('refine_tree.txt')
}


process runPangolin {
    input:
    file 'allseqs.aln' from pango_ch
    
    output:
    file("lineage_report.csv") into lineages_ch
    
    """
    pangolin allseqs.aln --outfile lineage_report.csv
    """
}


process getCOGUKMetadata {
    input:
    file 'allseqs.aln' from cog_select_ch
    file cog_meta
    
    output:
    file("leaftips.txt")
    file("leaftips_cog_metadata.csv.xz") into cog_subset_ch
    
    """
    grep ">" allseqs.aln | sed 's/>//g' > leaftips.txt
    xzcat $cog_meta | head -1 > leaftips_cog_metadata.csv
    xzgrep -f leaftips.txt $cog_meta --no-group-separator >> leaftips_cog_metadata.csv
    xz leaftips_cog_metadata.csv > leaftips_cog_metadata.csv.xz
    """
}


process joinMetadata {
    input:
    file "leaftips_cog_metadata.csv.xz" from cog_subset_ch
    file "lineage_report.csv" from lineages_ch
    file nn_file
    
    output:
    file "all_metadata.csv"
    
    script:
    if !params.nns
        """
        python3  /home/ubuntu/scripts/join_pango_and_coguk_metadata.py --cog_metadata_file leaftips_cog_metadata.csv.xz --lineage_report lineage_report.csv --merged_file all_metadata.csv
        """
        
    else
        """
        python3  /home/ubuntu/scripts/join_nn_and_coguk_metadata.py --nn_file_subset nn_file_subset.csv.xz --cog_metadata_file leaftips_cog_metadata.csv.xz --lineage_report lineage_report.csv --merged_file all_metadata.csv
        """
}
