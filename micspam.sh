function rewire() {
	pw-link "Music Player Daemon:output_FL" "$1:playback_FL"
	pw-link "Music Player Daemon:output_FR" "$1:playback_FR"
}

SINK=micspam-sink
MIC=micspam-mic
CMD=$0

function usage() {
	printf "\
\033[1;32mUsage:\033[0m $CMD [ -s sink ] [ -m mic ]\n\
\n\
\033[1;32mOptions:\033[0m\n\
\t\033[1m-s sink\033[0m\tsets the name of the sink\n\
\t\033[1m-m mic\033[0m\tsets the name of the virtual microphone\n\
\n\
$CMD creates the sink and the virtual microphone if needed.  If you cannot \
unload them afterward (possibly due to invalid permissions), try restarting \
your audio daemon.  On systemd with pipewire, the command to run should be:\n\
\n\
\t\033[1msystemctl --user restart pipewire\033[0m\n\
\n\
$CMD resets the default microphone and exits upon receiving \
\033[0;31mSIGINT\033[0m.\n"
}

# Argument parsing

while [ $# -gt 0 ]; do
	case $1 in
	-s|--sink)
		shift
		SINK=$1
		shift
		;;
	-m|--mic)
		shift
		MIC=$1
		shift
		;;
	-h|--help)
		usage
		exit 1
		;;
	esac
done

# Setup

S2M=0

if [ ! "$(pw-link -o | grep "^$SINK:monitor_F[LR]$")" ]; then
	pactl load-module module-null-sink \
		media.class=Audio/Sink \
		"sink_name=$SINK" \
		channel_map=stereo
	S2M=1
fi

if [ ! "$(pw-link -o | grep "^$MIC:input_F[LR]$")" ]; then
	pactl load-module module-null-sink \
		media.class=Audio/Source/Virtual \
		"sink_name=$MIC" \
		channel_map=front-left,front-right
	S2M=1
fi

if [ $S2M -eq 1 ]; then
	pw-link "$SINK:monitor_FL" "$MIC:input_FL"
	pw-link "$SINK:monitor_FR" "$MIC:input_FR"
fi

DEFMIC=$(pactl get-default-source)
printf "\033[1;32mDefault microphone:\033[0m $DEFMIC\n"
printf "\033[1;32mVirtual microphone:\033[0m $MIC\n"
printf "\033[1;32mSink:\033[0m $SINK\n"

pactl set-default-source "$MIC"

# Main loop

function main_loop() {
	while true; do
		rewire "$SINK" 2> /dev/null
		sleep 1
	done
}

main_loop &
PID=$!
printf "\033[1;33mMain loop PID:\033[0m $PID\n"

function handler() {
	kill $PID
	wait $PID
	printf "\033[1;33mMain loop ($PID)\033[0m terminated with status $?\n"
}

trap handler INT
wait
trap - INT

pactl set-default-source "$DEFMIC"
