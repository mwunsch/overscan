#lang scribble/manual
@require[@for-label[ffi/unsafe/introspection
                    racket/base
                    ffi/unsafe]]

@title[#:tag "gobject-introspection"]{GObject Introspection}

@secref{gstreamer} is the core framework that powers much of the
capabilities of Overscan. GStreamer is also a @bold{C} framework,
which means that a big part of Overscan's codebase is dedicated to the
interop between Racket and C. Racket provides a phenomenal
@seclink["top" #:doc '(lib
"scribblings/foreign/foreign.scrbl")]{Foreign Interface}, but to
create foreign functions for all the relevant portions of GStreamer
would be cumbersome, at best.

Luckily, GStreamer is written with
@hyperlink["https://wiki.gnome.org/Projects/GLib"]{GLib} and contains
@hyperlink["https://wiki.gnome.org/Projects/GObjectIntrospection"]{GObject
Introspection} metadata. @emph{GObject Introspection} is a middleware
layer that allows for a language to read this metadata and dynamically
create bindings for constructing an interface into the C library.

The Overscan package provides a module designed to accompany Racket's
FFI collection. This module brings additional functionality and
@secref["types" #:doc '(lib "scribblings/foreign/foreign.scrbl")] for
working with Introspected C libraries. This module powers the
@secref{gstreamer} module, but can be used outside of Overscan for
working with other GLib libraries.

@defmodule[ffi/unsafe/introspection]

@racketblock[
(define gst (introspection 'Gst))
]

@defproc[(introspection [namespace symbol?] [version string? #f])
         gi-repository?]{
 Requires a Repository
}
