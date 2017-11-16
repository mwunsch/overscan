#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@title[#:tag "gstreamer" #:style '(toc)]{GStreamer}

@hyperlink["https://gstreamer.freedesktop.org"]{GStreamer} is an open source framework for creating streaming media applications. More precisely it is ``a library for constructing graphs of media-handling components.'' GStreamer is at the core of the multimedia capabilities of Overscan. GStreamer is written in the C programming language with the GLib Object model. This module, included in the Overscan package, provides Racket bindings to GStreamer; designed to provide support for building media pipelines in conventional, idiomatic Racket without worrying about the peculiarities of C.

@defmodule[gstreamer]

@local-table-of-contents[]

@section[#:tag "gstreamer-usage"]{Using GStreamer}

GStreamer must be initialized before using it. Initialization loads the GStreamer libraries and plug-ins.

@racketblock[
  (require gstreamer)

  (unless (gst-initialized?)
    (if (gst-initialize)
        (displayln (gst-version-string))
        (error "Could not load GStreamer")))
]

This initializes GStreamer if it hasn't already been loaded, and prints its version, or raises an error if GStreamer could not be initialized.

From here, a GStreamer @tech{pipeline} is constructed by linking together @tech{elements}. Create an element by using an @tech{element factory} to make elements.

@racketblock[
  (define test-pattern
    (element-factory%-make "videotestsrc"))

  (define preview
    (element-factory%-make "osxvideosink"))

  (define my-pipeline
    (pipeline%-compose "my-pipeline"
                       test-pattern
                       preview))
]

This code creates two elements: a source that generates test video data and a native macOS video sink. It then composes a pipeline by linking those two elements together. Every GStreamer application needs a pipeline and @racket[pipeline%-compose] is a convenient mechanism for quickly creating them.

From here the pipeline can be played by setting its state:

@racketblock[
  (send my-pipeline @#,method[element% set-state] 'playing)
]

This will draw a new window where a test video signal of @hyperlink["https://en.wikipedia.org/wiki/SMPTE_color_bars"]{SMPTE color bars} will be displayed.

Shut down the pipeline by setting its state again:

@racketblock[
  (send my-pipeline @#,method[element% set-state] 'null)
]

A quick way to create a pipeline is by using @racket[parse/launch] to parse a pipeline description into an element.

@racketblock[
  (define trailer-uri
    "http://movietrailers.apple.com/movies/marvel/thor-ragnarok/thor-ragnarok-trailer-1_h720p.mov")

  (define movie-trailer
    (parse/launch (format "playbin uri=~a" trailer-uri)))

  (send movie-trailer @#,method[element% play!])
]

A @deftech{playbin} element is used to quickly play media from a URI. In addition to @racket[parse/launch], the gstreamer module provides a number of utilities and helpers for working with @secref{common-elements} for building basic pipelines.

@include-section["gstreamer/element.scrbl"]
@include-section["gstreamer/bin.scrbl"]
@include-section["gstreamer/bus.scrbl"]
@include-section["gstreamer/pad.scrbl"]
@include-section["gstreamer/clock.scrbl"]
@include-section["gstreamer/device.scrbl"]
@include-section["gstreamer/caps.scrbl"]
@include-section["gstreamer/elements.scrbl"]

@section[#:tag "gstreamer-support"]{Base Support}

@defproc[(gst-version-string) string?]{
  This procedure returns a string that is useful for describing this version of GStreamer to the outside world.
}

@defproc[(gst-version) (values exact-integer? exact-integer? exact-integer? exact-integer?)]{
  Returns the version numbers of the imported GStreamer library as @defterm{major}, @defterm{minor}, @defterm{micro}, and @defterm{nano}.
}

@defproc[(gst-initialized?) boolean?]{
  Returns @racket[#t] if GStreamer has been initialized, @racket[#f] otherwise.
}

@defproc[(gst-initialize) boolean?]{
  Initializes the GStreamer library, loading standard plugins. The GStreamer library must be initialized before attempting to create any Elements. Returns @racket[#t] if GStreamer could be initialized, @racket[#f] if it could not be for some reason.
}

@defthing[gst gi-repository?]{
  The entry point for the @secref{gobject-introspection} Repository for GStreamer. Useful for accessing more of the GStreamer C functionality than what is provided by the module.
}

@defclass[gst-object% gobject% (gobject<%>)]{
  The base class for nearly all objects within GStreamer. Provides mechanisms for getting object names and parentage. Typically, objects of this class should not be instantiated directly; instead factory functions should be used.

  @defmethod[(get-name) string?]{
    Returns the name of @this-obj[].
  }

  @defmethod[(get-parent) (or/c gobject? #f)]{
    Returns the parent of @this-obj[] or @racket[#f] if @this-obj[] has no parent.
  }

  @defmethod[(has-as-parent? [parent gobject?]) boolean?]{
    Returns @racket[#t] if @racket[parent] is the parent of @this-obj[], @racket[#f] otherwise.
  }

  @defmethod[(get-path-string) string?]{
    Generates a string describing the path of @this-obj[] in the object hierarchy.
  }
}
