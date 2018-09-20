#lang scribble/manual
@require["utilities.rkt"
         @for-label[overscan
                    racket/base
                    ffi/unsafe/introspection
                    gstreamer]]

@title{Overscan}
@author[(author+email (hyperlink "https://www.markwunsch.com/" "Mark Wunsch")
                      "mark@markwunsch.com")]

@include-section["overscan/getting-started.scrbl"]
@include-section["overscan/broadcasting.scrbl"]
@include-section["overscan/gstreamer.scrbl"]
@include-section["overscan/introspection.scrbl"]

Overscan is a @hyperlink["https://en.wikipedia.org/wiki/Live_coding"]{live coding environment} for live streaming video.

@margin-note{
  Follow Overscan on Twitter @hyperlink["https://twitter.com/overscan_lang" "@overscan_lang"].
}

@margin-note{
  For examples of other live coding environments, see @hyperlink["http://sonic-pi.net"]{Sonic Pi} or @hyperlink["http://extempore.moso.com.au"]{Extempore}.
}

@video["examples/logo.mp4"]

The @racketmodname[overscan] DSL can be used to quickly
produce a video stream from a number of video and audio sources, send
that stream to a video @tech{sink}
(e.g. @hyperlink["http://twitch.tv"]{Twitch}), and manipulate that
stream on-the-fly.

@defmodulelang[overscan]

The Overscan collection is built on top of two additional collections
provided by this package: @racketmodname[gstreamer], a library and
interface to the
@hyperlink["https://gstreamer.freedesktop.org/"]{GStreamer} multimedia
framework, and @racketmodname[ffi/unsafe/introspection], a module for
creating a Foreign Function Interface built on
@hyperlink["https://wiki.gnome.org/Projects/GObjectIntrospection"]{GObject
Introspection} bindings.

@table-of-contents[]
