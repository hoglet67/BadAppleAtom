rm -rf mode_4
mkdir -p mode_4
cd mode_4

ffmpeg  -i ../BadApple.avi -r 30 -s 256x192  a_%04d.bmp

for i in $(seq -w 1 6571)
do
    echo $i
    convert -type bilevel a_$i.bmp tmp.mono
    cat tmp.mono >> tmp
done
../reverse <tmp >MOVIE
rm tmp
