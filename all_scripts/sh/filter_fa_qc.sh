fastadir='/home/ubuntu/transfer/incoming/QIB_Sequencing/Covid-19_Seq/result.illumina.20210513/qc_climb_upload/210513_NB501819_0205_AHNTMGAFX2/' #directory containing fasta files
metacsv='/home/ubuntu/transfer/incoming/QIB_Sequencing/Covid-19_Seq/result.illumina.20210513/20210513_metrics.csv' #metadata csv
savefile='20210513.fa'

#make a directory to store the fasta files that passed qc, if the directory doesn't already exist
mkdir -p /home/ubuntu/fasta_temp

#read metadata csv line-by-line
count=0
while IFS=, read -r central_sample sample_name sequenced_bases reads mapped_reads coverage snps pct_N_bases pct_covered_bases longest_no_N_run full_mapped_reads probable_false_positive qc_pass hi_qc_pass; do
  #print sample names that passed hi_qc; for each sample that passes, find the corresponding fasta file and concatenate it to a new .fa file
  [[ "$hi_qc_pass" == "True" ]] && ((++count)) && echo "$sample_name" && find ${fastadir} -type f -regex "${fastadir}${sample_name}.*fa" -exec cat {} \; > /home/ubuntu/merged_fasta.fa
#the metadata csv filepath goes here:
done < ${metacsv}
#print the final number of samples to pass hi_qc
echo ">> ${count} samples passed hi_qc"

#remove empty records from the merged fasta file, and save as ${savefile}
awk 'BEGIN {RS = ">" ; FS = "\n" ; ORS = ""} $2 {print ">"$0}' /home/ubuntu/merged_fasta.fa > /home/ubuntu/fasta_temp/${savefile}
#remove intermediate file: /home/ubuntu/merged_fasta.fa
rm /home/ubuntu/merged_fasta.fa
