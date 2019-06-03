rm -rf mode_2
mkdir -p mode_2
cd mode_2

ffmpeg  -i ../BadApple.avi -r 30 -s 128x96  a_%04d.bmp

for i in $(seq -w 1 6571)
do
    echo $i
    convert -type bilevel a_$i.bmp tmp.mono
    cat tmp.mono >> tmp
done
../reverse <tmp >MOVIE
rm tmp
