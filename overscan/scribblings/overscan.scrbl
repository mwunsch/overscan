#lang scribble/manual
@require[@for-label[overscan
                    racket/base
                    ffi/unsafe/introspection
                    gstreamer]]

@title{Overscan}
@author[(author+email "Mark Wunsch" "mark@markwunsch.com")]

@defmodule[overscan]

Overscan is a Racket toolkit and live coding environment for live
broadcasting video. The Overscan package includes three collections:
@racket[overscan], @racket[ffi/unsafe/introspection] and
@racket[gstreamer].

@margin-note{
A live-coding environment similar to Overtone or Extempore.
}

@table-of-contents[]

@include-section["overscan/gstreamer.scrbl"]
@include-section["overscan/introspection.scrbl"]
