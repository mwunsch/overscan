#lang scribble/manual
@require[@for-label[overscan]]

@title[#:tag "getting-started"]{Getting Started}

@section[#:tag "installation"]{Installation}

Install @secref{Overscan} following the instructions at
@secref["raco-pkg-install" #:doc '(lib "pkg/scribblings/pkg.scrbl")]:

@commandline{raco pkg install git://github.com:mwunsch/overscan}

Overscan requires the @secref{gstreamer} and
@secref{gobject-introspection} libraries to be installed, along with a
number of GStreamer plugins. Several of these plugins are
platform-specific e.g. plugins for accessing camera and audio
sources. Overscan, still in its infancy, is currently @emph{only}
configured to work on a Mac. @margin-note*{Overscan has been tested on
macOS Sierra and Racket v6.12.} The requirements are assumed to be
installed via @hyperlink["https://brew.sh"]{Homebrew}.

@commandline{brew install gstreamer}

This will install the core GStreamer framework, along with GObject
Introspection libraries as a dependency. Overscan has been tested with
GStreamer version 1.14.0.

From here, you have to install the different
@hyperlink["https://gstreamer.freedesktop.org/documentation/splitup.html"]{GStreamer
plug-in modules} and some of the dependencies Overscan relies
on. Don't let the naming conventions of these plugin packs confuse you
--- the @tt{gst-plugins-bad} package isn't @emph{bad} per say; it
won't harm you or your machine. It's @emph{bad} because it doesn't
conform to some of the standards and expectations of the core
GStreamer codebase (i.e. it isn't well documented or doesn't include
tests).

@commandline{brew install gst-plugins-base --with-pango}

When installing the base plugins, be sure to include
@hyperlink["http://www.pango.org"]{Pango}, a text layout library used
by GTK+. Overscan uses this for working with text overlays while
streaming.

@commandline{brew install gst-plugins-good --with-aalib}

@hyperlink["http://aa-project.sourceforge.net/aalib/"]{AAlib} is a library for converting still and moving images to ASCII art. Not necessary, but cool.

@commandline{brew install gst-plugins-bad --with-rtmpdump --with-fdk-aac}

@hyperlink["https://rtmpdump.mplayerhq.hu"]{RTMPDump} is a toolkit for
RTMP streams. @hyperlink["https://en.wikipedia.org/wiki/Fraunhofer_FDK_AAC"]{Fraunhofer FDK AAC} is an encoder for AAC audio.

@commandline{brew install gst-plugins-ugly --with-x264}

@hyperlink["http://www.videolan.org/developers/x264.html"]{x264} is a
library for encoding video streams into the H.264/MPEG-4 AVC
format.

With these dependencies in place and a running Racket implementation,
you are now ready to begin broadcasting. @margin-note*{Personally, I
have installed Racket with @exec{brew cask install racket}}

@section[#:tag "basic-usage"]{Basic Usage}

The "Hello, world" of Overscan is a test broadcast:

@codeblock{
  #lang overscan

  (broadcast)
}
