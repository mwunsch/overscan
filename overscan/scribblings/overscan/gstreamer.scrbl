#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@title[#:tag "gstreamer"]{GStreamer}

@hyperlink["https://gstreamer.freedesktop.org"]{GStreamer} is an open source framework for creating streaming media applications. More precisely it is ``a library for constructing graphs of media-handling components.'' GStreamer is at the core of the multimedia capabilities of Overscan. GStreamer is written in the C programming language with the GLib Object model. This module, included in the Overscan package, provides Racket bindings to GStreamer; designed to provide support for building media pipelines in conventional, idiomatic Racket without worrying about the peculiarities of C.

@defmodule[gstreamer]

@defthing[gst gi-repository?]{
  The entry point for the GObject Introspection Repository for GStreamer. Useful for accessing more of the GStreamer C functionality than what is provided by the module.
}

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
  Initializes the GStreamer library, loading standard plugins. You must initialize the GStreamer library before attempting to create any Elements. Returns @racket[#t] if GStreamer could be initialized, @racket[#f] if it could not be for some reason.
}

@defclass[gst-object% gobject% ()]{
  Nearly all objects within GStreamer inherit from this class, which provides mechanisms for getting object names and parentage.
}
