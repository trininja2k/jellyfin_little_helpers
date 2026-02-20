Small scripts, that helps around prond problems with video files and Jellyfin.

1. mkv2mp4 - Initial for WebOS TV and directplay, I hate transcoding, to many problems. WebOS has problems with HEVC x265 in mkv containers, so this script simply uses ffmpeg to remux everything into mp4.
Textbased subs get transfered with mov_text, PGS/VobSub get extracted. everything else gets discarded. No files will be deleted. Just put it in the directory, "chmod" it and run it, double check if everything worked.

More to come.
