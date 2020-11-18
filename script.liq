%include "http.liq"

set("init.allow_root", true)
set("protocol.aws.endpoint", "{{ S3_ENDPOINT }}")
set("harbor.bind_addrs", ["0.0.0.0"])


# Input Icecast stream

live = input.harbor("live",
  port={{ ICECAST_PORT }},
  password="{{ ICECAST_PASSWORD }}",
  replay_metadata=true,
  icy=true,
)


# Metadata server

live = http_serve_metadata(live, "/live.json", {{ HTTP_PORT }});


# Output formats

aac_lofi = %ffmpeg(format="mpegts", codec="aac", channels=2, ar=44100)
aac_midfi = %ffmpeg(format="mpegts", codec="aac", channels=2, ar=44100, b="96k")
aac_hifi = %ffmpeg(format="mpegts", codec="aac", channels=2, ar=44100, b="192k")

streams_info = [
  ("aac_lofi", (40000, "mp4a.40.29", "ts")),
  ("aac_midfi", (110000, "mp4a.40.2", "ts")),
  ("aac_hifi", (220000, "mp4a.40.2", "ts")),
]
                
streams = [
  ("aac_lofi", aac_lofi), 
  ("aac_midfi", aac_midfi), 
  ("aac_hifi", aac_hifi),
]

def segment_name(~position,~extname,stream_name) =
  timestamp = int_of_float(gettimeofday())
  duration = 2
  "#{stream_name}_#{duration}_#{timestamp}_#{position}.#{extname}"
end


# Output HLS stream

output.harbor.hls(
  playlist="live.m3u8",
  port={{ HTTP_PORT }},
  path="/",
  streams,
  streams_info=streams_info,
  segments=5,
  segment_duration=2.0,
  segment_name=segment_name,
  segments_overhead=5,
  persist=true,
  persist_at="/var/liquidsoap/hls.config",
  fallible=true,
  live,
)
