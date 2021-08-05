declare -a tiflist=('*-DEM-adj.tif')

c=1
for tifstring in $tiflist
do
tifname=${tifstring%-DEM-adj.tif}
pc_align --max-displacement 1000 --save-transformed-source-points mola128_stereoclip.tif "$tifname"-DEM-adj.tif -o "$tifname"
# mola128_stereoclip.tif is what I named my MOLA tile, but you can name it whatever you like
point2dem --tr 20 "$tifname"-trans_source.tif
c=$(($c+1))
done
