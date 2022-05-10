declare -a tiflist=('*-DEM-adj.tif')

c=1
for tifstring in $tiflist
do
tifname=${tifstring%-DEM-adj.tif}
pc_align --max-displacement 1000 --save-transformed-source-points <tile>.tif "$tifname"-DEM-adj.tif -o "$tifname"
point2dem --tr 20 "$tifname"-trans_source.tif
c=$(($c+1))
done

dem_mosaic -l mosaic_order.lis -o ctx_mosaic
dem_mosaic --priority-blending-length 20 ctx_mosaic-tile-0.tif <tile>.tif -o ctx_mosaic_global
