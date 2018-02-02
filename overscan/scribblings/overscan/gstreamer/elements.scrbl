#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@title[#:tag "common-elements"]{Common Elements}

Included in @racketmodname[gstreamer] are helpers and utilities for working with frequently used elements, including predicates (implemented with @racket[element/c]) and property getters/setters.

@section{Source Elements}

A source element generates data for use by a pipeline. A source element has a source @tech{pad} and do not accept data, they only produce it.

Examples of source elements are those that generate video or audio signal, or those that capture data from a disk or some other input device.

@subsection{@racket[videotestsrc]}

@defproc[(videotestsrc [name (or/c string? #f) #f]
                       [#:pattern pattern videotest-pattern/c  'smpte]
                       [#:live? is-live? boolean? #f]) videotestsrc?]{
  Creates a @deftech{videotestsrc} element with the given @racket[name] (or a generated name if @racket[#f]). A videotestsrc element produces a @racket[pattern] on its src pad.
}

@defproc[(videotestsrc? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["videotestsrc"] factory, @racket[#f] otherwise.
}

@defthing[videotest-pattern/c flat-contract?
          #:value (one-of/c 'smpte 'snow 'black 'white 'red 'green 'blue
                            'checkers-1 'checkers-2 'checkers-4 'checkers-8
                            'circular 'blink 'smpte75 'zone-plate 'gamut
                            'chroma-zone-plate 'solid-color 'ball 'smpte100
                            'bar 'pinwheel 'spokes 'gradient 'colors)]{
  A contract that accepts a valid pattern for a @racket[videotestsrc].
}

@defproc[(videotestsrc-pattern [element videotestsrc?]) videotest-pattern/c]{
  Returns the test pattern of @racket[element].
}

@defproc[(set-videotestsrc-pattern! [element videotestsrc?] [pattern videotest-pattern/c]) void?]{
  Sets the test pattern of @racket[element].
}

@defproc[(videotestsrc-live? [element videotestsrc?]) boolean?]{
  Returns @racket[#t] if @racket[element] is being used as a live source, @racket[#f] otherwise.
}

@section{Filter-like Elements}

Filters and filter-like elements have both input and output @tech{pads}, also called sink and source pads respectively. They operate on data they receive on their sink pads and provide data on their output pads.

Examples include an h.264 encoder, an mp4 muxer, or a tee element --- used to take a single input and send it to multiple outputs.

@subsection{@racket[capsfilter]}

@defproc[(capsfilter [caps caps?] [name (or/c string? #f) #f])
         capsfilter?]{
  Create a @deftech{capsfilter} element with the given @racket[name] (or use a generated name if @racket[#f]). A capsfilter element does not modify data but can enforce limitations on the data passing through it via its @racket[caps] property.
}

@defproc[(capsfilter? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["capsfilter"] factory, @racket[#f] otherwise.
}

@defproc[(capsfilter-caps [element capsfilter?]) caps?]{
  Returns the possible allowed @tech{caps} of @racket[element].
}

@defproc[(set-capsfilter-caps! [element capsfilter?] [caps caps?]) void?]{
  Sets the allowed @tech{caps} of @racket[element] to @racket[caps].
}

@subsection{@racket[tee]}

@defproc[(tee [name (or/c string? #f) #f]) tee?]{
  Create a @deftech{tee} element with the given @racket[name] (or use a generated name if @racket[#f]). A tee element is a 1-to-N pipe fitting element, meant for splitting data to multiple pads.
}

@defproc[(tee? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["tee"] factory, @racket[#f] otherwise.
}

@section{Sink Elements}

Sink elements are the end points in a media pipeline. They accept data but do not produce anything. Writing to a disk or video or audio playback are implemented by sink elements.

@subsection{@racket[rtmpsink]}

@defproc[(rtmpsink [location string?] [name (or/c string? #f) #f])
         rtmpsink?]{
  Create a @deftech{rtmpsink} element with the given @racket[name] (or use a generated name if @racket[#f]) and with @racket[location] as the RTMP URL.
}

@defproc[(rtmpsink? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["rtmpsink"] factory, @racket[#f] otherwise.
}

@defproc[(rtmpsink-location [element rtmpsink?]) string?]{
  Returns the RTMP URL of the @racket[element].
}

@subsection{@racket[appsink%]}

@defmodule[gstreamer/appsink]

@defclass[appsink% element% ()]{

}

@defproc[(make-appsink [name (or/c string? #f) #f] [class% (subclass?/c appsink%) appsink%]) (is-a?/c appsink%)]{
}
