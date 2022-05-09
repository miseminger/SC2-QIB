#!/usr/bin/env nextflow

params.cog_fasta = "/home/ubuntu/ongaeshi-mnt/civet/cog_global_*.fasta.xz"
params.cog_meta = "/home/ubuntu/ongaeshi-mnt/civet/cog_global_*public.csv.xz"
params.wuhan_hu_1 = "/home/ubuntu/Wuhan-Wu-1-linear.fasta"
params.nns = "/home/ubuntu/03.nn_geodate_min_noadm2.csv.xz"
params.start_date = "2021-12-01"
params.end_date = "2022-02-28"
params.N = 4
params.K = 100
params.max_samples_per_month = 30

cog_fasta = file(params.cog_fasta)
cog_meta = file(params.cog_meta)
wuhan_hu_1 = file(params.wuhan_hu_1)
nns = file(params.nns)


process chooseSamples {
    input:
    file nns

    output:
    file "nn_file_subset.csv.xz" into join_nn_meta_ch
    tuple file("query_samples.txt"), file("neighbour_samples.txt") into fasta_ch

    """
    python3 /home/ubuntu/scripts/get_query_seqs_by_date_max.py --nn_file $nns --start_date $params.start_date --end_date $params.end_date --query_names "query_samples.txt" --ref_names "neighbour_samples.txt" --nn_file_subset "nn_file_subset.csv.xz" --N $params.N
    """
}


process getFastaRecords {
    input:
    tuple file("query_samples.txt"), file("neighbour_samples.txt") from fasta_ch
    file cog_fasta
    file wuhan_hu_1
        
    output:
    tuple file("query_samples_ref.aln"), file("neighbour_samples_ref.aln") into mask_ch
    file "query_samples.aln"
    file "neighbour_samples.aln"
    
    """
    xzgrep -w -A 1 -f query_samples.txt $cog_fasta --no-group-separator > query_samples.aln
    cat $wuhan_hu_1 query_samples.aln > query_samples_ref.aln

    xzgrep -w -A 1 -f neighbour_samples.txt $cog_fasta --no-group-separator > neighbour_samples.aln
    cat $wuhan_hu_1 neighbour_samples.aln > neighbour_samples_ref.aln
    """
}


process maskProblematicSites {
    input:
    tuple file("query_samples_ref.aln"), file("neighbour_samples_ref.aln") from mask_ch
    
    output:
    tuple file("query_samples_ref_masked.aln"), file("neighbour_samples_ref_masked.aln") into wu_ch
        
    """
    python3 /home/ubuntu/ProblematicSites_SARS-CoV2/src/mask_alignment_using_vcf.py -v /home/ubuntu/ProblematicSites_SARS-CoV2/problematic_sites_sarsCov2.vcf -i query_samples_ref.aln -o query_samples_ref_masked.aln -r "Wuhan-Hu-1"
    
    python3 /home/ubuntu/ProblematicSites_SARS-CoV2/src/mask_alignment_using_vcf.py -v /home/ubuntu/ProblematicSites_SARS-CoV2/problematic_sites_sarsCov2.vcf -i neighbour_samples_ref.aln -o neighbour_samples_ref_masked.aln -r "Wuhan-Hu-1"
    """
}


process removeWuhanHu1 {
    input:
    tuple file("query_samples_ref_masked.aln"), file("neighbour_samples_ref_masked.aln") from wu_ch
    
    output:
    file("neighbour_samples_masked.aln") into choose_K_ch
    file("query_samples_masked.aln") into full_tree_q_ch
        
    """
    sed '/Wuhan-Hu-1/,+1d' query_samples_ref_masked.aln > query_samples_masked.aln
    sed '/Wuhan-Hu-1/,+1d' neighbour_samples_ref_masked.aln > neighbour_samples_masked.aln
    """
}


process reduceRefs {
    input:
    file("neighbour_samples_masked.aln") from choose_K_ch
    
    output:
    file("neighbour_samples_masked.aln.tre")
    file("reduced_refs.txt")
    file("neighbour_samples_masked.aln.tre.pda")
    file("reduced_refs.aln") into(nn_tree_ch, full_tree_nn_ch)
    
    shell:
    template('choose_nns.txt')

}


process buildReducedRefsTree {
    input:
    file("reduced_refs.aln") from nn_tree_ch
    
    output:
    file("reduced_refs.aln.treefile") into full_tree_backbone_ch
    
    """
    iqtree -s reduced_refs.aln
    """
}


process buildAllSamplesTree {
    input:
    file("reduced_refs.aln.treefile") from full_tree_backbone_ch
    file("query_samples_masked.aln") from full_tree_q_ch
    file("reduced_refs.aln") from full_tree_nn_ch
    
    output:
    file("allseqs.aln.treefile") into treetime_tree_ch
    file("allseqs.aln") into (treetime_aln_ch, pango_ch, cog_select_ch)
    
    """
    cat query_samples_masked.aln reduced_refs.aln > allseqs.aln
    iqtree -s allseqs.aln -m HKY+G -g reduced_refs.aln.treefile -t PARS
    """
}


process runPangolin {
    input:
    file("allseqs.aln") from pango_ch
    
    output:
    file("lineage_report.csv") into lineages_ch
    
    """
    pangolin allseqs.aln
    """
}


process getCOGUKMetadata {
    input:
    file("allseqs.aln") from cog_select_ch
    file cog_meta
    
    output:
    file("leaftips.txt")
    file("leaftips_cog_metadata.csv") into cog_subset_ch
    
    """
    grep ">" allseqs.aln | sed 's/>//g' > leaftips.txt
    xzcat $cog_meta | head -1 > leaftips_cog_metadata.csv
    xzgrep -f leaftips.txt $cog_meta --no-group-separator >> leaftips_cog_metadata.csv
    """
}


process joinAllMetadata {
    input:
    file "leaftips_cog_metadata.csv.xz" from cog_subset_ch
    file "nn_file_subset.csv.xz" from join_nn_meta_ch
    file "lineage_report.csv" from lineages_ch
    
    output:
    file "all_metadata.csv" into (treetime_ch, treetime_mugration_ch)
    
    """
    python3  /home/ubuntu/scripts/join_nn_and_coguk_metadata.py --nn_file_subset nn_file_subset.csv.xz --cog_metadata_file leaftips_cog_metadata.csv.xz --lineage_report lineage_report.csv --merged_file all_metadata.csv
    """
}


process treeTime {
    input:
    file "all_metadata.csv" from treetime_ch
    file "allseqs.aln.treefile" from treetime_tree_ch
    file "allseqs.aln" from treetime_aln_ch
    
    output:
    file "timetree/*" into first_timetree_ch
    
    """
    treetime --aln allseqs.aln --tree allseqs.aln.treefile --dates all_metadata.csv --name-column sequence_name --date-column sample_date --relax 1.0 0 --clock-rate 0.008 --outdir timetree
    """
}


process treeTimeMugration {
    input:
    file "all_metadata.csv" from treetime_mugration_ch
    file "timetree/timetree.nexus" from first_timetree_ch
    
    output:
    file "timetree-mugration/*"
    
    """
    treetime mugration --tree timetree/timetree.nexus --states all_metadata.csv --attribute 'NUTS1' --outdir timetree-mugration
    """
}


