#!/usr/bin/env nextflow

/*
This pipeline is built to create trees out of SARS-CoV-2 sequences from the CIVET database.
A date range must always be specified, but beyond this there are several ways of choosing samples:

--subset your data to a random sample of up to max_samples_per_month seqs per month
--reduce your query samples to the diverseQueries most diverse: to skip this, set diverseQueries=false
--specify a four-letter sequencing site code (England-based only) to limit your samples to

*/

params.cog_fasta = "/home/ubuntu/ongaeshi-mnt/cog_global_*.fasta.xz"
params.cog_meta = "/home/ubuntu/ongaeshi-mnt/cog_global_*public.csv.xz"
params.wuhan_hu_1 = "/home/ubuntu/Wuhan-Wu-1-linear.fasta"
params.start_date = "2021-12-01"
params.end_date = "2021-12-15"
params.diverseQueries = false  // integer or false
params.centre = "NORW"
params.max_samples_per_month = false
cog_fasta = file(params.cog_fasta)
cog_meta = file(params.cog_meta)
wuhan_hu_1 = file(params.wuhan_hu_1)


process chooseSamples {
    input:
    file cog_meta

    output:
    file("query_samples.txt") into fasta_ch

    """
    python3 scripts/get_query_seqs_by_date_and_center.py --cog_meta_file $cog_meta --start_date $params.start_date --end_date $params.end_date --out "query_samples.txt" --sequencing_centre $params.centre --max_samples_per_month $params.max_samples_per_month
    """
}


process getFastaRecords {
    input:
    file("query_samples.txt") from fasta_ch
    file cog_fasta
    file wuhan_hu_1
        
    output:
    file("query_samples_ref.aln") into mask_ch
    file "query_samples.aln"
    
    """
    xzgrep -w -A 1 -f query_samples.txt $cog_fasta --no-group-separator > query_samples.aln
    cat $wuhan_hu_1 query_samples.aln > query_samples_ref.aln
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
                 

process reduceQueries {
    conda 'bioconda::iqtree=1.6.12'
    conda 'bioconda::rapidnj=2.3.2'
    
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


fastTree_ch.mix(optional_ch).into { rapidnj_tree_ch; pango_ch; cog_select_ch }


process buildFastTree {
    conda 'bioconda::rapidnj=2.3.2'
    
    input:
    file '*aln' from rapidnj_tree_ch

    output:
    file("fast.aln.tre") into slow_tree_start_ch
    file("reformatted.aln") into slow_tree_aln

    shell:
    template('rapidnj_tree.txt')
}



process refineTree {
    conda 'bioconda::iqtree=1.6.12'
    
    input:
    file("reformatted.aln") from slow_tree_aln
    file("fast.aln.tre") from slow_tree_start_ch
    
    output:
    file("reformatted.aln.treefile")
    
    shell:
    template('refine_tree.txt')
}


process runPangolin {
    input:
    file '*aln' from pango_ch
    
    output:
    file("lineage_report.csv") into lineages_ch
    
    """
    pangolin *aln --outfile lineage_report.csv
    """
}


process getCOGUKMetadata {
    input:
    file '*aln' from cog_select_ch
    file cog_meta
    
    output:
    file("leaftips.txt")
    file("leaftips_cog_metadata.csv") into cog_subset_ch
    
    """
    grep ">" *aln | sed 's/>//g' > leaftips.txt
    xzcat $cog_meta | head -1 > leaftips_cog_metadata.csv
    xzgrep -f leaftips.txt $cog_meta --no-group-separator >> leaftips_cog_metadata.csv
    """
}


process joinMetadata {
    input:
    file "leaftips_cog_metadata.csv" from cog_subset_ch
    file "lineage_report.csv" from lineages_ch
    
    output:
    file "all_metadata.csv"
    
    """
    python3  scripts/join_pango_and_coguk_metadata.py --cog_metadata_file leaftips_cog_metadata.csv --lineage_report lineage_report.csv --merged_file all_metadata.csv
    """
}
