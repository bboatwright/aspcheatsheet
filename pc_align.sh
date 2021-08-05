declare -a tiflist=('*-DEM-adj.tif')

c=1
for tifstring in $tiflist
do
tifname=${tifstring%-DEM-adj.tif}
~/StereoPipeline-2.6.2-2019-06-17-x86_64-Linux/bin/pc_align --max-displacement 1000 --save-transformed-source-points mola128_stereoclip.tif "$tifname"-DEM-adj.tif -o "$tifname"
~/StereoPipeline-2.6.2-2019-06-17-x86_64-Linux/bin/point2dem --tr 25 "$tifname"-trans_source.tif
c=$(($c+1))
done


