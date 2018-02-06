#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@title{Buffers}

@deftech{Buffers} are the basic unit of data transfer of GStreamer. Buffers contain blocks of @tech{memory}.

@defproc[(buffer? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @tech{buffer} containing media data, @racket[#f] otherwise.
}

@section{Memory}

@deftech{Memory} in GStreamer are lightweight objects wrapping a region of memory. They are used to manage the data within a buffer.

@defproc[(memory? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an object referencing a region of @tech{memory} containing media data, @racket[#f] otherwise.
}

@section{Samples}

A media @deftech{sample} is a small object associating a @tech{buffer} with a media type in the form of @tech{caps}.

@defproc[(sample? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a media sample, @racket[#f] otherwise.
}
