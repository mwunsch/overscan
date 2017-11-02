#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@title{Common Elements}

Included in @racketmodname[gstreamer] are helpers and utilities for working with frequently used elements, including predicates (implemented with @racket[element/c]) and property getters/setters.

@defproc[(capsfilter [caps caps?] [name (or/c string? #f) #f])
         capsfilter?]{
  Create a @deftech{capsfilter} element with the given @racket[name] (or use a generated name if @racket[#f]). A capsfilter element does not modify data but can enforce limitations on the data passing through it via its @racket[caps] property.
}

@defproc[(capsfilter? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an element of the @racket["capsfilter"] factory, @racket[#f] otherwise.
}

@defproc[(capsfilter-caps [element capsfilter?]) caps?]{
  Returns the possible allowed @tech{caps} of the @racket[element].
}

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
