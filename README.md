Micspam utility
===============

This Bash script is a command-line utility for micspam purposes.  It was
developed for [Sven Co-op](https://svencoop.com/) but should work with any game
that uses the default microphone as set in PipeWire.

Usage
-----

The dependencies are:

* [MPD](https://www.musicpd.org/)
* [PipeWire](https://www.pipewire.org/)

MPD is only used as an audio source.  This behavior can be changed in the
`rewire` function, so MPD is technically not a hard dependency.

If you plan to micspam in a GoldSrc or Source game, make the game run the
commands in `micspam.cfg` upon startup.  This can be done in the following
ways:

* Copy and paste its content into your game's `userconfig.cfg` or
  `autoexec.cfg` file.  On Sven Co-op, these are usually located in
  `~/.steam/steam/steamapps/common/Sven Co-op/sven_coop/`.

* Copy and paste the file itself into the directory given in the above bullet
  point, and add `exec micspam` in `userconfig.cfg` or `autoexec.cfg`.

The last line in `micspam.cfg` binds <kbd>\\</kbd> to `voice_toggle`.  Feel
free to change that key.  Remember that when reading these config files,
GoldSrc assumes a QWERTY keyboard.

To run the script, simply run the following command.

```bash
./micspam.sh
```

Use the `-s` option if you want to change the name of the sink.  This should
only be necessary if the default one (`micspam`) is already taken.

The utility takes care of creating the sink with `media.class=Audio/Duplex` if
it doesn't already exist.  After that, it enters a loop where it rewires MPD
to it every second.  This is necessary because MPD may unload its
audio module when you stop playing music.

To quit the script, simply send `SIGINT` (<kbd>Ctrl</kbd> + <kbd>C</kbd> in the
terminal) to it.  It will take care of setting the PipeWire default microphone
back to what it was when the script was launched.  It will also try to unload
the sink if it previously created and signal if this failed.
