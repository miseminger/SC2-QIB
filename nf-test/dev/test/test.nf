#!/usr/bin/env nextflow

params.nns = "pdfs.txt"

nns = file(params.nns)
params.diverseQueries = false
mode = 1

process removeWuhanHu1 {
    input:
    file nns

    output:
    file("nns_sub.txt") into mask_ch

    """
    head -4 $nns > nns_sub.txt
    """
}

// reduceQueries_ch is empty if diverseQueries=false
// fastTree_ch is empty for now

(reduceQueries_ch, fastTree_ch) = ( !params.diverseQueries
                 ? [Channel.empty(), mask_ch]
                 : [mask_ch, Channel.empty()] )


process reduceQueries {
    input:
    file("nns_sub.txt") from reduceQueries_ch
        
    output:
    file "cats.txt" into optional_ch

    shell:
    '''
    tac nns_sub.txt > cats.txt
    '''
}


fastTree_ch.mix(optional_ch).into { build_ch; pango_ch }      


process buildFastTree {

    input:
    file '*' from build_ch
    
    output:
    file "mice.txt"
    
    """
    cat * | head -$mode > mice.txt
    """
}

process runPangolin {
    input:
    file '*aln' from pango_ch
    file nns
    
    output:
    file "fin.txt"
    
    shell:
    template('sed.txt')    
}


