#! /bin/bash
## Convert MP4 from phone to HLS playlist for streaming
## Rule of thumb: maxrate = w*h*fps*0.1

## Encoding options for multi-bitrate: [<res>]=<kbps>
declare -A bitrate
bitrate=( [full]=0 [720]=4000 [486]=2000 [360]=300 )

ffmpeg=/usr/bin/ffmpeg

## Build part of ffmpeg cmdline
single_res() {
  local res=$1 rate=$2 ts=$3 
  local buf=$((rate*2))

  if [[ "$res" = "full" ]]; then
    echo -n " -c:v copy"
  else
    echo -n " -c:v libx264"
    echo -n " -preset slower"
    echo -n " -crf 25"
    echo -n " -vf scale=-1:$res"
    echo -n " -maxrate ${rate}k"
    echo -n " -bufsize ${buf}k"
    echo -n " -force_key_frames 'expr:gte(t,n_forced*2)'"
  fi

  echo -n " -hls_time 2"
  echo -n " -bsf:v h264_mp4toannexb"
  echo -n " -hls_playlist_type vod"
  echo -n " -hls_flags single_file"
  echo -n " -hls_segment_filename $ts"
  echo -n " -c:a copy"
}

## Build complete ffmpeg cmdline
ffmpeg_cmd() {
  local src=$1 dst=$2
  echo -n "nice $ffmpeg -i $src"

  for res in ${!bitrate[@]}; do
    single_res $res ${bitrate[$res]} "${dst}/${res}.ts"
    echo -n " ${dst}/${res}.m3u8" 
  done
}

## Main
for src in $@; do
  srcfile=$(basename $src)
  base=${srcfile%.*}

  srcdir=$(dirname $src)
  hlsdir="${srcdir}/.hls/${base}"
  master="${srcdir}/${base}.m3u8"

  ## Find original bitrate
  eval $(/usr/bin/ffprobe -show_format $src 2>&- | grep bit_rate)
  bitrate[full]=$((bit_rate/1024))

  ## Create master playlist
  mkdir -p $hlsdir
  echo "#EXTM3U" > $master
  for res in $(printf '%s\n' ${!bitrate[@]} | sort); do		# should use sort -n
    br=${bitrate[$res]} bw=$((br*1024))
    echo "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=${bw}" >> $master
    echo ".hls/${base}/$res.m3u8" >> $master
  done

  ## Create ffmpeg cmdline and run it
  cmd=$(ffmpeg_cmd $src $hlsdir)
  echo $cmd
  eval $cmd
done
