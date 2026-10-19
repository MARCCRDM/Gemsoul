#!/bin/bash
# encode.sh <frames dir> <audio.wav> <out.mp4> [crf]: the shots in order, one sequence, H.264 + AAC.
set -e
FR=$1; AUD=$2; OUT=$3; CRF=${4:-19}
FF=$(python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())")
SEQ=$(mktemp -d)
n=0
for s in a1_rip a2_rip a3_steal b1_train b2_mine b3_defend c_roll d_end; do
  for f in $(ls $FR/$s/*.jpg | sort); do ln -s "$(readlink -f $f)" $SEQ/$(printf %05d $n).jpg; n=$((n+1)); done
done
echo "frames: $n"
$FF -v error -y -framerate 30 -i $SEQ/%05d.jpg -i $AUD -map 0:v -map 1:a -c:v libx264 -preset slow -crf $CRF -pix_fmt yuv420p \
  -profile:v high -level 4.1 -movflags +faststart -c:a aac -b:a 192k -shortest $OUT
rm -rf $SEQ
ls -la $OUT
