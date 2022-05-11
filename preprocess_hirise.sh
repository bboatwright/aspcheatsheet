declare -a imglist=('*_RED0_0.IMG')

c=1
for imgstring in $imglist
do
imgname=${imgstring%_RED0_0.IMG}
imgnameout[$c]=$imgname
c=$(($c+1))
done

imgnameout1=${imgnameout[1]}
imgnameout2=${imgnameout[2]}

hiedr2mosaic.py "$imgnameout1"*
hiedr2mosaic.py "$imgnameout2"*

cam2map4stereo.py "$imgnameout1"_RED.mos_hijitreged.norm.cub "$imgnameout2"_RED.mos_hijitreged.norm.cub
