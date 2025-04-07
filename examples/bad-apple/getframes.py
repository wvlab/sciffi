from pathlib import Path
from yt_dlp import YoutubeDL
from ffmpeg import FFmpeg

url = "https://youtu.be/FtutLA63Cp8"
video = "video.mp4"
output = Path("frames")
output.mkdir(exist_ok=True)
template = "frame%06d.png"
framerate = 30

opts = {
    "format": "bestvideo[ext=mp4]",
    "outtmpl": video,
}

with YoutubeDL(opts) as ydl:
    ydl.download([url])

ffmpeg = (
    FFmpeg()
    .input(video)
    .output(output / template, r=framerate, v="error")
    .execute()
)
