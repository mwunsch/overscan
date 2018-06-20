#lang scribble/manual
@require[@for-label[gstreamer
                    gstreamer/appsink
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
                       [#:live? is-live? boolean? #t]) videotestsrc?]{
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

@subsection{@racket[audiotestsrc]}

@defproc[(audiotestsrc [name (or/c string? #f) #f]
                       [#:live? is-live? boolean? #t]) audiotestsrc?]{
  Creates a @deftech{audiotestsrc} element with the given @racket[name].
}

@defproc[(audiotestsrc? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["audiotestsrc"] factory, @racket[#f] otherwise.
}

@defproc[(audiotestsrc-live? [element audiotestsrc?]) boolean?]{
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

@subsection{@racket[videomixer]}

@defproc[(videomixer [name (or/c string? #f)]) videomixer?]{
  Create a @deftech{videomixer} element with the given @racket[name] (or use a generated name if @racket[#f]). A videomixer element composites/mixes multiple video streams into one.
}

@defproc[(videomixer? [v any/c]) boolean?]{
  Returns @racket[t] if @racket[v] is an element of the @racket["videomixer"] factory, @racket[#f] otherwise.
}

@defproc[(videomixer-ref [mixer videomixer?] [pos exact-nonnegative-integer?])
         (or/c (is-a?/c pad%) #f)]{
  Gets the @tech{pad} at @racket[pos] from @racket[mixer], or @racket[#f] if there is none present.
}

@subsection{@racket[tee]}

@defproc[(tee [name (or/c string? #f) #f]) tee?]{
  Create a @deftech{tee} element with the given @racket[name] (or use a generated name if @racket[#f]). A tee element is a 1-to-N pipe fitting element, meant for splitting data to multiple pads.
}

@defproc[(tee? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["tee"] factory, @racket[#f] otherwise.
}

@subsection{@racket[videoscale]}

@defproc[(videoscale [name (or/c string? #f) #f]) videoscale?]{
}

@defproc[(videoscale? [v any/c]) boolean?]{
 Returns @racket[#t] if @racket[v] is an element of the @racket["videoscale"] factory, @racket[#f] otherwise.
}

@subsection{@racket[videobox]}

@defproc[(videobox [name (or/c string? #f) #f]
                   [#:autocrop? autocrop boolean?]
                   [#:top top exact-integer?]
                   [#:bottom bottom exact-integer?]
                   [#:left left exact-integer?]
                   [#:right right exact-integer?])
                   videobox?]{
  Create a @deftech{videobox} element with the given @racket[name]. A videobox element will crop or enlarge the input video stream. The @racket[top], @racket[bottom], @racket[left], and @racket[right] parameters will crop pixels or add pixels to a border depending on if the values are positive or negative, respectively. When @racket[autocrop] is @racket[#t], @tech{caps} will determine crop properties. This element can be used to support letterboxing, mosaic, and picture-in-picture.
}

@defproc[(videobox? [v any/c]) boolean?]{
 Returns @racket[#t] if @racket[v] is an element of the @racket["videobox"] factory, @racket[#f] otherwise.
}

@section{Sink Elements}

@deftech{Sink} elements are the end points in a media pipeline. They accept data but do not produce anything. Writing to a disk or video or audio playback are implemented by sink elements.

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

@subsection{@racket[filesink]}

@defproc[(filesink [location path-string?] [name (or/c string? #f) #f])
         filesink?]{
  Create a @deftech{filesink} element with the given @racket[name] (or use a generated name) and with @racket[location] as a file path on the local file system.
}

@defproc[(filesink? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["filesink"] factory, @racket[#f] otherwise.
}

@defproc[(filesink-location [element filesink?]) path-string?]{
  Returns the file path of the @racket[element].
}

@subsection{@racket[appsink%]}

@defmodule[gstreamer/appsink]

An @deftech{appsink} is a @tech{sink} element that is designed to extract sample data out of the pipeline into the application.

@defclass[appsink% element% ()]{

  @defmethod[#:mode public-final
             (eos?) boolean?]{
  }

  @defmethod[#:mode public-final
             (dropping?) boolean?]{
  }

  @defmethod[#:mode public-final
             (get-max-buffers) exact-nonnegative-integer?]{
  }

  @defmethod[#:mode public-final
             (get-caps) (or/c caps? #f)]{
  }

  @defmethod[#:mode public-final
             (set-caps! [caps caps?]) void?]{
  }

  @defmethod[#:mode public-final
             (get-eos-evt) evt?]{
  }

  @defmethod[#:mode pubment
             (on-sample [sample sample?]) any?]{
  }

  @defmethod[#:mode pubment
             (on-eos) any?]{
  }

}

@defproc[(make-appsink [name (or/c string? #f) #f] [class% (subclass?/c appsink%) appsink%]) (is-a?/c appsink%)]{
  Create an appsink element with the name @racket[name] or a generated name if @racket[#f]. If @racket[class%] is provided and a subclass of @racket[appsink%], the returned element will be an instance of @racket[class%].
}
