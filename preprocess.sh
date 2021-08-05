declare -a imglist=('*.IMG')

c=1
for imgstring in $imglist
do
imgname=${imgstring%.IMG}
mroctx2isis from= "$imgname".IMG to= "$imgname".cub
spiceinit from= "$imgname".cub
ctxcal from= "$imgname".cub to= "$imgname".cal.cub
imgnameout[$c]=$imgname
c=$(($c+1))
done

imgnameout1=${imgnameout[1]}
imgnameout2=${imgnameout[2]}

cam2map4stereo.py "$imgnameout1".cal.cub "$imgnameout2".cal.cub
