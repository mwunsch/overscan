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
Introspection} metadata. @emph{GObject Introspection} (aka @emph{GIR})
is a middleware layer that allows for a language to read this metadata
and dynamically create bindings for the C library.

The Overscan package provides a module designed to accompany Racket's
FFI collection. This module brings additional functionality and
@secref["types" #:doc '(lib "scribblings/foreign/foreign.scrbl")] for
working with Introspected C libraries. This module powers the
@secref{gstreamer} module, but can be used outside of Overscan for
working with other GLib libraries.

@defmodule[ffi/unsafe/introspection]

@section[#:tag "girepository"]{GIRepository}

GIR's
@hyperlink["https://developer.gnome.org/gi/stable/GIRepository.html"]{@tt{GIRepository}}
API manages the namespaces provided by the GIR system and type
libraries. Each namespace contains metadata entries that map to C
functionality. In the case of @secref{gstreamer}, the @racket['Gst]
namespace contains all of the introspection information used to power
that interface.

@defproc[(introspection [namespace symbol?] [version string? #f])
         gi-repository?]{

Search for the @racket[namespace] typelib in the GObject Introspection
         repository search path and load it. If @racket[version] is
         not specified, the latest version will be used.

An example for loading the @secref{gstreamer} namespace:

@racketinput[
  (define gst (introspection 'Gst))
]

This is the only provided mechanism to construct a
@racket[gi-repository].
}

@defstruct*[gi-repository ([namespace symbol?]
                           [version string?]
                           [info-hash (hash/c symbol? gi-base?)])
            #:omit-constructor ]{
  A struct representing a namespace of an introspected typelib. The constructor is not provided. Call @racket[introspection] for this to be returned. This struct has the @racket[prop:procedure] property and is intended to be called as a procedure:

@nested[#:style 'inset]{
  @defproc*[#:kind "gi-repository" #:link-target? #f
            ([(repository) (hash/c symbol? gi-base?)]
             [(repository [name symbol?]) gi-base?])]{
    When called as in the first form, without an argument, the proc
  will return a @racket[hash] of all of the known members of the
  namespace.

    When called as the second form, this is the equivalent to
  @racket[gi-repository-find-name] with the first argument already
  set. e.g. @racketinput[(gst 'version)]

    This will return an introspected foreign binding to the
  @hyperlink["https://gstreamer.freedesktop.org/data/doc/gstreamer/head/gstreamer/html/gstreamer-Gst.html#gst-version"]{@tt{gst_version()}}
  C function.
  }
}

}

@defproc[(gi-repository-find-name [repo gi-repository?] [name symbol?]) gi-base?]{
  Find a metadata entry called @racket[name] in the
  @racket[repo]. These @emph{entries} form the basis of the foreign
  interface. This will raise an @racket[exn:fail:contract] exception
  if the entry is not a part of the given namespace.
}

@defproc[(gi-repository->ffi-lib [repo gi-repository?]) ffi-lib?]{
  Lookup the library path of a repository and return a @tech[#:doc
  '(lib "scribblings/foreign/foreign.scrbl")]{foreign-library value}
}

@defproc[(gir-member/c [namespace symbol?]) flat-contract?]{
  Accepts a GIR @racket[namespace] and returns a @tech[#:doc '(lib
  "scribblings/reference/reference.scrbl")]{flat contract} that
  recognizes a symbol within that namespace. Use this to check for
  whether or not an entry is a member of a namespace.
}

@defproc[(gi-repository-member/c [repo gi-repository?]) flat-contract?]{
  Equivalent to @racket[gir-member/c] except with a repository struct
  (as returned by @racket[introspection]) instead of a namespace.
}

@section[#:tag "gibaseinfo"]{GIBaseInfo}

The GIBaseInfo C Struct is the base struct for all GIR metadata
entries. Whenever you do some lookup within GIR, what's returned is
an instance of a descendant from this struct.

@defstruct*[gi-base ([info cpointer?])
            #:omit-constructor ]{
  The common base struct of all GIR metadata entries. Instances of
  this struct have the @racket[prop:cpointer] property, and can be
  used transparently as cpointers to their respective entries.
}

@defproc[(gi-base-name [info gi-base?]) symbol?]{
  Obtain the name of the @racket[info].
}

@defproc[(gi-base=? [a gi-base?] [b gi-base?]) boolean?]{
  Compare two @racket[gi-base]s. Doing pointer comparison or other equality comparisons does not work. This function compares two entries of the typelib.
}

@defproc[(gi-enum->list [enum gi-enum?]) list?]{
}

@defproc[(gi-enum->hash [enum gi-enum?]) hash?]{
}

@defproc[(_gi-object [obj gi-object?]) ctype?]{
}

@defstruct*[gtype-instance ([type gi-registered-type?] [pointer cpointer?])
            #:omit-constructor ]{
}

@defproc[(gtype-instance-type-name [gtype gtype-instance?]) symbol?]{
}

@defproc[(gtype-instance-name [gtype gtype-instance?]) symbol?]{
}

@section[#:tag "gobject"]{GObjects}
