#!/bin/bash
pactl load-module module-pipe-source source_name=relm file=/home/asztrikx/Desktop/relm format=s16le rate=16000 channels=1 
pactl set-default-source relm
# re: Read input at native frame rate.
# i: input
# f:
# ar: sampling freq
# ac: channels
ffmpeg -stream_loop -1 -re -i pavarotti_original.wav -f s16le -ar 16000 -ac 1 - > /home/asztrikx/Desktop/relm