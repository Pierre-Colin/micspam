# Copyright 2024 Pierre Colin
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
function rewire() {
	pw-link "Music Player Daemon:output_FL" "$1:playback_FL"
	pw-link "Music Player Daemon:output_FR" "$1:playback_FR"
}

SINK=micspam
CMD=$0

function usage() {
	printf "\
\033[1;32mUsage:\033[0m $CMD [ -s sink ]\n\
\n\
\033[1;32mOptions:\033[0m\n\
\t\033[1m-s sink\033[0m\tsets the name of the sink\n\
\n\
$CMD creates a duplex sink if needed.  If you cannot unload it afterward \
(possibly due to invalid permissions), try restarting your audio daemon.  On \
systemd with pipewire, the command to run should be:\n\
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
	-h|--help)
		usage
		exit 1
		;;
	*)
		printf "Unknown option: \033[1m$1\033[0m\n"
		exit 1
		;;
	esac
done

# Setup

SINKNO=
if [ ! "$(pw-link -o | grep "^$SINK:")" ]; then
	SINKNO=$(pactl load-module module-null-sink \
		media.class=Audio/Duplex \
		sink_name="$SINK")
fi

DEFMIC=$(pactl get-default-source)
printf "\033[1;32mDefault microphone:\033[0m $DEFMIC\n"
printf "\033[1;32mSink:\033[0m $SINK"
if [ $SINKNO ]; then
	printf " (created as $SINKNO)"
fi
echo

pactl set-default-source "$SINK"

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

# Cleanup

pactl set-default-source "$DEFMIC"

if [ $SINKNO ]; then
	pactl unload-module $SINKNO
	if [ $? -gt 0 ]; then
		printf "\033[1;31mCould not unload $SINK ($SINKNO)\033[0m\n"
	fi
fi
