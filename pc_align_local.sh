# housekeeping
rm *txt *csv *trans_source* *tile*

## Calculate vertical offsets between CTX and MOLA
declare -a tiflist=('*-DEM-adj.tif')

for tifstring in $tiflist
do
tifname=${tifstring%-DEM-adj.tif}

pc_align --max-displacement 1000 <tile>.tif "$tifname"-DEM-adj.tif -o "$tifname"-initial
mv -T "$tifname"-initial-log-pc_align*txt "$tifname"-initial-log-pc_align.txt
down=$(cat "$tifname"-initial-log-pc_align.txt | awk -F'[,)]' 'FNR == 85 {print $5}')
initial_d="0 0 $down"
echo $initial_d

# manually adjust vertical offset
pc_align --max-displacement 1000 --initial-ned-translation "$initial_d" --num-iterations 0 --save-transformed-source-points <tile>.tif "$tifname"-DEM-adj.tif -o "$tifname"
point2dem --tr 20 "$tifname"-trans_source.tif
done

## Mosaic vertically adjusted CTX and align MOLA horizontally

dem_mosaic -l mosaic_order.lis -o ctx_mosaic

pc_align --max-displacement 1000 ctx_mosaic-tile-0.tif <tile>.tif -o mola-initial
mv -T <tile>-initial-log-pc_align*txt <tile>-initial-log-pc_align.txt
north=$(cat <tile>-initial-log-pc_align.txt | awk -F'[(,]' 'FNR == 85 {print $4}')
east=$(cat <tile>-initial-log-pc_align.txt | awk -F'[(,]' 'FNR == 85 {print $5}')
initial_ne="$north $east 0"
echo $initial_ne

# perform similar manual alignment for MOLA horizontal offset
pc_align --max-displacement 1000 --initial-ned-translation "$initial_ne" --num-iterations 0 --save-transformed-source-points ctx_mosaic-tile-0.tif <tile>.tif -o <tile>
point2dem <tile>-trans_source.tif

## Final mosaic
dem_mosaic --priority-blending-length 20 ctx_mosaic-tile-0.tif <tile>-trans_source-DEM.tif -o ctx_mosaic_local
