#lang scribble/manual
@require[@for-label[overscan
                    racket/base
                    ffi/unsafe/introspection
                    gstreamer]]

@title{Overscan}
@author[(author+email "Mark Wunsch" "mark@markwunsch.com")]

@defmodulelang[overscan]

@include-section["overscan/getting-started.scrbl"]
@include-section["overscan/gstreamer.scrbl"]
@include-section["overscan/introspection.scrbl"]

Overscan is a toolkit and
@hyperlink["https://en.wikipedia.org/wiki/Live_coding"]{live coding
environment} for broadcasting video. @margin-note*{For examples of
other live coding environments, see
@hyperlink["http://sonic-pi.net"]{Sonic Pi} or
@hyperlink["http://extempore.moso.com.au"]{Extempore}.} The
@racket[overscan] DSL can be used to quickly produce a video stream
from a number of video and audio sources, send that stream to a video
@emph{sink} (e.g. @hyperlink["http://twitch.tv"]{Twitch}), and manipulate
that stream on-the-fly.

The Overscan collection is built on top of two additional collections
provided by this package: @racketmodname[gstreamer], a library and
interface to the
@hyperlink["https://gstreamer.freedesktop.org/"]{GStreamer} multimedia
framework, and @racketmodname[ffi/unsafe/introspection] a module for
creating a Foreign Function Interface built on
@hyperlink["https://wiki.gnome.org/Projects/GObjectIntrospection"]{GObject
Introspection} bindings.

@table-of-contents[]
