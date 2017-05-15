# Overscan

A study in live video broadcasting with
the [Racket](http://racket-lang.org) programming language.

The goal of this project is to learn Racket and to better understand
the problems involved in:

+ The Real-Time Messaging Protocol
  ([RTMP](https://en.wikipedia.org/wiki/Real-Time_Messaging_Protocol))
  and constructing and streaming unbounded audio and video feeds.
+ The [Twitch](https://dev.twitch.tv)
  and
  [Facebook Live](https://developers.facebook.com/docs/videos/live-video) API's,
  for authentication, broadcasting live video streams, and gathering
  audience data.
+ Video compositing in software.

Originally, the end-goal was to build a toolkit like that found
in [StreamPro](https://streampro.io)
or [Streamlabs](https://streamlabs.com) (née _TwitchAlerts_) but using
a Racket DSL for on-the-fly compositing and graphics.

Now, this project's ambition is to provide a comprehensive live-coding
environment for video compositing and broadcasting. This project is
inspired by other live-coding environments
like
[Impromptu](http://impromptu.moso.com.au)/[Extempore](https://github.com/digego/extempore) and
[Overtone](http://overtone.github.io).

It is split into three parts:

1. The `ffi/unsafe/introspection` module. This module provides dynamic
   Racket bindings to [GObject Introspection][gobject-introspection],
   allowing interaction with C GObject libraries using common Racket
   idioms (i.e. providing [`racket/class`][racket/class] forms such as
   `send` and `get-field` for GObjects).
2. The `gstreamer` collection (_in progress_). Using the
   aforementioned Introspection module, this collection provides
   Racket bindings for [GStreamer](https://gstreamer.freedesktop.org),
   the open source multimedia framework.
3. The `overscan` collection and language (_TK._). This provides a DSL
   for building a GStreamer pipeline for capturing common video
   sources (cameras and screens), compositing multiple sources,
   including generated graphics, and then encoding them and pushing
   them along to an RTMP server (like Twitch). All of this is designed
   to happen within a Racket REPL session, allowing the broadcaster
   full control over the stream by evaluating S-expressions. That's
   the idea, at least.

You can follow the development along
at <http://tinyletter.com/wunsch>. Read archives of previous weekly
devlogs at <http://www.markwunsch.com/tinyletter/>.

[gobject-introspection]: https://wiki.gnome.org/Projects/GObjectIntrospection

[racket/class]: https://docs.racket-lang.org/reference/mzlib_class.html

## Installation

Overscan has only been tested on macOS Sierra with Racket v6.8 and
GStreamer v1.10.4.

Using homebrew:

    brew install gstreamer

This will install `gstreamer` along with dependencies `glib` and
`gobject-introspection`, all of which are required.

You also need to install GStreamer plugins:

    brew install gst-plugins-base --with-libogg --with-libvorbis --with-theora --with-pango

    brew install gst-plugins-good

    brew install gst-plugins-bad --with-rtmpdump
