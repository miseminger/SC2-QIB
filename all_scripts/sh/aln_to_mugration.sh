#Given a starting alignment and a metadata table containing the records, reduce the alignment to the ${num} most diverse sequences and make a treetime mugration model from that.

results=/home/ubuntu/20220228  #store outputs here
aln=allseqs_30.aln #starting alignment file
metadata=fritest2.tsv #metadata file containing names and dates
num=25 #how many sequences do you want?
new=allseqs_25 #name for new, reduced files
treetime_dir=timetree-7 #treetime results dir

mkdir -d ${results}

sed -i 's/_/\//g' ${results}/${aln}
rapidnj ${results}/${aln} -i fa -t d -n -c 8 -o t -x ${results}/${aln}.tre
iqtree -k ${num} ${results}/${aln}.tre
grep -A ${num} "The optimal PD set has ${num} taxa:" ${results}/${aln}.tre.pda | sed '1d'  | sed 's/^.//;s/.$//;s/_/\//;s/_/\//' | sort | uniq > ${results}/${new}.txt

grep -w -A 1 -f ${results}/${new}.txt ${results}/${aln} --no-group-separator > ${results}/${new}.aln
iqtree -s ${results}/${new}.aln

grep ">" ${results}/${new}.aln | sed 's/>//g' > ${results}/${new}_leaftips.txt
python /home/ubuntu/scripts/get_treetime_dates.py --metadata_tsv ${metadata} --leaftips ${results}/${new}_leaftips.txt --out ${results}/${new}_treetime_dates.tsv
sed -i 's/\//_/g' ${results}/${new}.aln

treetime --relax 1.0 0 --clock-rate 0.008 --tree ${results}/${new}.aln.treefile --dates ${results}/${new}_treetime_dates.tsv --outdir ${results}/${treetime_dir} --aln ${results}/${new}.aln

treetime mugration --confidence --tree ${results}/${treetime_dir}/timetree.nexus --states ${results}/${new}_treetime_dates.tsv --attribute 'region' --outdir ${results}/${treetime_dir}-mugration
