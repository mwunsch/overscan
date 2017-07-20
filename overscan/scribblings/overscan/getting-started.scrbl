#lang scribble/manual

@title[#:tag "getting-started"]{Getting Started}

@section[#:tag "installation"]{Installation}

Overscan requires the GStreamer and GObject Introspection libraries to
be installed, along with a number of GStreamer plugins. Several of
these plugins are platform-specific e.g. plugins for accessing camera
and audio sources. Overscan, still in its infancy, is currently only
configured to work on a Mac. It has only been tested on macOS
Sierra. The requirements are assumed to be installed via Homebrew.

@commandline{brew install gstreamer}

This will install the core GStreamer framework, along with GObject
Introspection libraries as a dependency. From here, we have to install
the different GStreamer plugin packs and some of the dependencies
Overscan relies on. Don't let the naming conventions of these plugin
packs confuse you -- the @tt{gst-plugins-bad} package isn't @emph{bad}
per say; it won't harm you or your machine. It's @emph{bad} because it
doesn't conform to some of the standards and expectations of the core
GStreamer codebase (i.e. it isn't well documented or doesn't include tests).

@commandline{brew install gst-plugins-base --with-pango}

When installing the base plugins, be sure to include @italic{Pango}, a
text layout library used by GTK+. Overscan uses this for working with
text overlays while streaming.

@commandline{brew install gst-plugins-good}

@commandline{brew install gst-plugins-bad --with-rtmpdump --with-faac}

@hyperlink["https://rtmpdump.mplayerhq.hu"]{RTMPDump} is a toolkit for
RTMP streams. @hyperlink["http://www.audiocoding.com/faac.html"]{FAAC}
is an encoder for AAC audio.

@commandline{brew install gst-plugins-ugly --with-x264}

@hyperlink["http://www.videolan.org/developers/x264.html"]{x264} is a
library for encoding video streams into the H.264/MPEG-4 AVC
format.

With these dependencies in place and a running Racket implementation
(Overscan has been tested on Racket v6.9), you are now ready to begin
broadcasting.

Personally, I have installed Racket with @commandline{brew cask
install racket}
