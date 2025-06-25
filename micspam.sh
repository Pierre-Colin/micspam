# Copyright 2024, 2025 Pierre Colin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function usage() {
	printf "\
\033[1;32mUsage:\033[0m $0 [ -s sink ]\n\
\n\
\033[1;32mOptions:\033[0m\n\
\t\033[1m-s sink\033[0m\tsets the name of the sink\n\
\n\
$0 creates a duplex sink if needed.  If you cannot unload it afterward \
(possibly due to invalid permissions), try restarting your audio daemon.  On \
systemd with pipewire, the command to run should be:\n\
\n\
\t\033[1msystemctl --user restart pipewire\033[0m\n\
\n\
$0 resets the default microphone and exits upon receiving \
\033[0;31mSIGINT\033[0m.\n" >&2
	exit 1
}

# Argument parsing

SINK=micspam
while getopts hs: name; do
	case $name in
	h | \?)	usage $0;;
	s)	SINK=$OPTARG;;
	esac
done

ERROR=$?
[ $ERROR -gt 1 ] && exit $ERROR

# Setup

SINKNO=
if [ ! "$(pw-link -o | grep "^$SINK:")" ]; then
	SINKNO=$(pactl load-module module-null-sink \
		media.class=Audio/Duplex \
		sink_name="$SINK" 2> /dev/null)
	if [ $? -gt 0 ]; then
		printf "\033[1;31mCould not create sink %s\033[0m\n" $SINK >&2
		exit 1
	fi
fi

function cleanup_sink() {
	if [ $SINKNO ]; then
		FMT="\033[1;31mCould not unload sink %s (%s)\033[0m\n"
		pactl unload-module $SINKNO 2> /dev/null
		[ $? -gt 0 ] && printf "$FMT" "$SINK" "$SINKNO" >&2
	fi
}

DEFMIC=$(pactl get-default-source)
printf "\033[1;32mDefault microphone:\033[0m $DEFMIC\n"
printf "\033[1;32mSink:\033[0m $SINK"
if [ $SINKNO ]; then
	printf " (created as $SINKNO)"
fi
echo

pactl set-default-source "$SINK"
if [ $? -gt 0 ]; then
	printf "\033[1;31mCould not set default mic to %s\033[0m\n" $SINK >&2
	cleanup_sink
	exit 1
fi

# Main loop

function rewire() {
	pw-link "Music Player Daemon:output_FL" "$1:playback_FL"
	pw-link "Music Player Daemon:output_FR" "$1:playback_FR"
}

function main_loop() {
	while true; do
		rewire "$SINK" 2> /dev/null
		sleep 1
	done
}

main_loop &
PID=$!
printf "\033[1;33mMain loop PID:\033[0m $PID\n"

TRAPS=$(trap -p)

function cleanup() {
	F_EXIT="\033[1;33mMain loop (%s)\033[0m exited with signal %s\n"
	F_WAITF="\033[1;31mCould not wait for main loop (%s) exiting\033[0m\n"
	trap - EXIT INT QUIT TERM
	eval "$TRAPS"
	kill $PID
	if [ $? -eq 0 ]; then
		wait $PID
		ERROR=$?
		if [ $ERROR -ge 128 ]; then
			printf "$F_EXIT" $PID "$(kill -l $ERROR)"
		else
			printf "$F_WAITF" $PID >&2
		fi
	else
		printf "\033[1;31mCould not kill main loop ($PID)\033[0m\n" >&2
	fi

	pactl set-default-source "$DEFMIC" 2> /dev/null
	if [ $? -gt 0 ]; then
		printf "\033[1;31mCould not reset mic to $DEFMIC\033[0m\n" >&2
	fi

	cleanup_sink
}

trap cleanup EXIT INT QUIT TERM
wait
