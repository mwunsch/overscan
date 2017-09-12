#lang scribble/manual
@require[@for-label[ffi/unsafe/introspection
                    racket/base
                    racket/contract
                    (except-in ffi/unsafe ->)]]

@title[#:tag "gobject-introspection"]{GObject Introspection}

@secref{gstreamer} is the core framework that powers much of the capabilities of Overscan. GStreamer is also a @bold{C} framework, which means that a big part of Overscan's codebase is dedicated to the interop between Racket and C. Racket provides a phenomenal @seclink["top" #:doc '(lib "scribblings/foreign/foreign.scrbl")]{Foreign Interface}, but to create foreign functions for all the relevant portions of GStreamer would be cumbersome, at best.

Luckily, GStreamer is written with @hyperlink["https://wiki.gnome.org/Projects/GLib"]{GLib} and contains @hyperlink["https://wiki.gnome.org/Projects/GObjectIntrospection"]{GObject Introspection} metadata. @emph{GObject Introspection} (aka @emph{GIR}) is a middleware layer that allows for a language to read this metadata and dynamically create bindings for the C library.

The Overscan package provides a module designed to accompany Racket's FFI collection. This module brings additional functionality and @secref["types" #:doc '(lib "scribblings/foreign/foreign.scrbl")] for working with Introspected C libraries. This module powers the @secref{gstreamer} module, but can be used outside of Overscan for working with other GLib libraries.

@defmodule[ffi/unsafe/introspection]

@section[#:tag "girepository"]{GIRepository}

GIR's @hyperlink["https://developer.gnome.org/gi/stable/GIRepository.html"]{@tt{GIRepository}} API manages the namespaces provided by the GIR system and type libraries. Each namespace contains metadata entries that map to C functionality. In the case of @secref{gstreamer}, the @racket['Gst] namespace contains all of the introspection information used to power that interface.

@defproc[(introspection [namespace symbol?] [version string? #f])
         gi-repository?]{
  Search for the @racket[namespace] typelib in the GObject Introspection repository search path and load it. If @racket[version] is not specified, the latest version will be used.

  An example for loading the @secref{gstreamer} namespace:

  @racketinput[
    (define gst (introspection 'Gst))
  ]

  This is the only provided mechanism to construct a @racket[gi-repository].
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
      When called as in the first form, without an argument, the proc will return a @racket[hash] of all of the known members of the namespace.

      When called as the second form, this is the equivalent to @racket[gi-repository-find-name] with the first argument already set. e.g.

      @racketinput[
        (gst 'version)
      ]

      This will return an introspected foreign binding to the @hyperlink["https://gstreamer.freedesktop.org/data/doc/gstreamer/head/gstreamer/html/gstreamer-Gst.html#gst-version"]{@tt{gst_version()}} C function, represented as a @racket[gi-function?].
    }
  }

}

@defproc[(gi-repository-find-name [repo gi-repository?] [name symbol?]) gi-base?]{
  Find a metadata entry called @racket[name] in the @racket[repo]. These @emph{entries} form the basis of the foreign interface. This will raise an @racket[exn:fail:contract] exception if the entry is not a part of the given namespace.
}

@defproc[(gi-repository->ffi-lib [repo gi-repository?]) ffi-lib?]{
  Lookup the library path of a repository and return a @tech[#:doc '(lib "scribblings/foreign/foreign.scrbl")]{foreign-library value}
}

@defproc[(gir-member/c [namespace symbol?]) flat-contract?]{
  Accepts a GIR @racket[namespace] and returns a @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{flat contract} that recognizes a symbol within that namespace. Use this to check for whether or not an entry is a member of a namespace.
}

@defproc[(gi-repository-member/c [repo gi-repository?]) flat-contract?]{
  Equivalent to @racket[gir-member/c] except with a repository struct (as returned by @racket[introspection]) instead of a namespace.
}

@section[#:tag "gibaseinfo"]{GIBaseInfo}

The @hyperlink["https://developer.gnome.org/gi/stable/gi-GIBaseInfo.html"]{@tt{GIBaseInfo}} C Struct is the base struct for all GIR metadata entries. Whenever you do some lookup within GIR, what's returned is an instance of a descendant from this struct. The @racket[gi-base] struct is the Racket equivalent, and @racket[introspection] will return entities that inherit from this base struct.

@defstruct*[gi-base ([info cpointer?])
            #:omit-constructor ]{
  The common base struct of all GIR metadata entries. Instances of this struct have the @racket[prop:cpointer] property, and can be used transparently as @racket[cpointers] to their respective entries.
}

@defproc[(gi-base-name [info gi-base?]) symbol?]{
  Obtain the name of the @racket[info].
}

@defproc[(gi-base=? [a gi-base?] [b gi-base?]) boolean?]{
  Compare two @racket[gi-base]s. Doing pointer comparison or other equality comparisons does not work. This function compares two entries of the typelib.
}

@defproc[(gi-function? [v any/c]) boolean?]{
  A @hyperlink["https://developer.gnome.org/gi/stable/gi-GIFunctionInfo.html"]{@tt{GIFunctionInfo}} struct inherits from GIBaseInfo and represents a C function. Returns @racket[#t] if @racket[v] is a Function Info, @racket[#f] otherwise.
}

@defproc[(gi-registered-type? [v any/c]) boolean?]{
  A @hyperlink["https://developer.gnome.org/gi/stable/gi-GIRegisteredTypeInfo.html"]{@tt{GIRegisteredTypeInfo}} struct inherits from GIBaseInfo. An entry of this type represents some C entity with an associated @hyperlink["https://developer.gnome.org/gobject/stable/gobject-Type-Information.html"]{GType}. Returns @racket[#t] if @racket[v] is a Registered Type, @racket[#f] otherwise.
}

@defproc[(gi-enum? [v any/c]) boolean?]{
  A @hyperlink["https://developer.gnome.org/gi/stable/gi-GIEnumInfo.html"]{@tt{GIEnumInfo}} is an introspected entity representing an enumeration. Returns @racket[#t] if @racket[v] is an Enumeration, @racket[#f] otherwise.
}

@defproc[(gi-enum->list [enum gi-enum?]) list?]{
  Convert @racket[enum] to a list of symbols, representing the values of the enumeration.
}

@defproc[(gi-enum->hash [enum gi-enum?]) hash?]{
  Convert @racket[enum] to a hash mapping symbols to their numeric value.
}

@defproc[(gi-object? [v any/c]) boolean?]{
  A @hyperlink["https://developer.gnome.org/gi/stable/gi-GIObjectInfo.html"]{@tt{GIObjectInfo}} is an introspected entity representing a GObject. This does not represent an instance of a GObject, but instead represents a GObject's type information (roughly analogous to a "class"). Returns @racket[#t] if @racket[v] is a GIObjectInfo, @racket[#f] otherwise.

  See @secref{gobject} for more information about using GObjects from within Racket.
}

@defproc[(gi-struct? [v any/c]) boolean?]{
  A @tt{GIStructInfo} is an introspected entity representing a C Struct. Returns @racket[#t] if @racket[v] is a GIStructInfo, @racket[#f] otherwise.
}

@defproc[(_gi-object [obj gi-object?]) ctype?]{
  Constructs a @racket[ctype] for the given @racket[obj], which is effectively a @racket[_cpointer] that will dereference into an instance of the @racket[obj].
}

@defstruct*[gtype-instance ([type gi-registered-type?] [pointer cpointer?])
            #:omit-constructor ]{
  Represents an instance of a GType @racket[type]. This struct and its descendants have the @racket[prop:cpointer] property, and can be used as a pointer in FFI calls. GType Instances can have methods and fields associated with them.
}

@defproc[(gtype-instance-type-name [instance gtype-instance?]) symbol?]{
  Returns the name of the registered GType of @racket[instance].
}

@defproc[(gtype-instance-name [instance gtype-instance?]) symbol?]{
  Returns the name of the instance of @racket[instance]. The difference between this function and @racket[gtype-instance-type-name] is that the GType name typically has the C prefix for an instance of a GType, where within GObject Introspection that prefix is elided. @racket[gtype-instance-type-name] derives its name from the GType, and @racket[gtype-instance-name] derives its name from GObject Introspection.
}

@defstruct*[(gstruct gtype-instance)
            ([type gi-struct?] [pointer cpointer?])
            #:omit-constructor ]{
  Represents an instance of a C Struct. That Struct can have methods and fields. Similar in most behaviors to a @racket[gobject].
}

@section[#:tag "gobject"]{GObjects}

GObjects like the introspected metadata entries provided by GIR, are transparent pointers with additional tooling to be called as objects within Racket. They therefore behave like Racket objects, with the exception that they aren't backed by _classes_, but instead the introspected metadata. To make using GObjects more like using objects, the library provides several functions and syntax with the same names as those found in @secref["mzlib:class" #:doc '(lib "scribblings/reference/reference.scrbl")].

@defstruct*[(gobject gtype-instance)
            ([type gi-object?] [pointer cpointer?])
            #:omit-constructor ]{
  An instance of @racket[type]. You can call methods, get or set fields, get/set properties, or connect to signals on a GObject.
}

@defproc[(is-a? [instance gtype-instance?] [type gi-registered-type?]) boolean?]{
  Returns @racket[#t] if @racket[instance] is an instance of @racket[type], @racket[#f] otherwise. Similar to the associated @secref["objectutils" #:doc '(lib "scribblings/reference/reference.scrbl")] function.
}

@defproc[(is-a?/c [type gi-registered-type?]) flat-contract?]{
  Accepts a @racket[type] and returns a flat contract that recognizes objects that instantiate it.
}

@defproc[(gobject-send [obj (or/c gobject? gstruct?)] [method-name symbol?] [argument any/c] ...) any]{
  Calls the method on @racket[obj] whose name matches @racket[method-name], passing along all given @racket[argument]s.
}

@defform[(send obj-expr method-id arg ...)
         #:contracts ([obj-expr (or/c gobject? gstruct?)])]{
  Evaluates @racket[obj-expr] to obtain a @racket[gobject] or @racket[gstruct], and calls the method with name @racket[method-id] on the object, providing the @racket[arg] results as arguments.

  Just like the @code{racket/class} equivalent.
}

@defform[(responds-to? obj-expr method-id)
         #:contracts ([obj-expr (or/c gobject? gstruct?)])]{
  Produces @racket[#t] if the result of @racket[obj-expr] or its ancestors defines a method with the name @racket[method-id], @racket[#f] otherwise.
}

@defproc[(gobject-get-field [field-name symbol?] [obj (or/c gobject? gstruct?)]) any]{
  Extracts the field from @racket[obj] whose name matches @racket[field-name]. Note that @emph{fields} are distinct from GObject Properties, which are accessed with @racket[gobject-get].
}

@defform[(get-field id obj-expr)
         #:contracts ([obj-expr (or/c gobject? gstruct?)])]{
  Extracts the field with name @racket[id] from the value of @racket[obj-expr].
}

@defproc[(gobject-set-field! [field-name symbol?] [obj (or/c gobject? gstruct?)] [v any/c]) void?]{
  Sets the field from @racket[obj] whose name matches @racket[field-name] to @racket[v].
}

@defform[(set-field! id obj-expr val-expr)
         #:contracts ([obj-expr (or/c gobject? gstruct?)])]{
  Sets the field with name @racket[id] from the value of @racket[obj-expr] to the value of @racket[val-expr].
}

@defform[(field-bound? id obj-expr)
         #:contracts ([obj-expr (or/c gobject? gstruct?)])]{
  Produces @racket[#t] if the result of @racket[obj-expr] has a field with name @racket[id], @racket[#f] otherwise.
}

@defproc[(method-names [obj (or/c gobject? gstruct?)]) (listof symbol?)]{
  Extracts a list that @racket[obj] recognizes as names of methods it understands. This list might not be exhaustive.
}

@defproc[(connect [obj gobject?] [signal-name symbol?] [handler procedure?]
          [#:data data cpointer? #f]
          [#:cast _user-data (or/c ctype? gi-object?) #f]) exact-integer?]{
  Register a callback @racket[handler] for the @hyperlink["https://developer.gnome.org/gobject/stable/signal.html"]{@emph{Signal}} matching the name @racket[signal-name] for the @racket[obj]. The @racket[handler] will receive three arguments, @racket[obj], the name of the signal as a string, and @racket[data].
}

@defproc[(gobject-cast [pointer cpointer?] [obj gi-object?]) gobject?]{
  This will cast @racket[pointer] to @racket[(_gi-object obj)], thereby transforming it into a @racket[gobject].
}

@defproc[(gobject-get [obj gobject?] [propname string?] [ctype ctype?]) any?]{
  Extract the @hyperlink["https://developer.gnome.org/gobject/stable/gobject-properties.html"]{property} from @racket[obj] whose name matches @racket[propname] and can be dereferenced as a @racket[ctype].
}

@defproc[(gobject-set! [obj gobject?] [propname string?] [v any/c]
          [ctype (or/c ctype? (listof symbol?)) #f]) void?]{
  Sets the property of @racket[obj] whose name matches @racket[propname] to @racket[v]. If @racket[ctype] is a @racket[(listof symbol?)], @racket[v] is assumed to be a symbol in that list, used for representing @racket[_enum]s. If no @racket[ctype] is provided, one is inferred based on @racket[v].
}

@defproc[(gobject-with-properties [obj gobject?]
          [properties (hash/c symbol? any/c)]) gobject?]{
  Sets a group of properties on @racket[obj] based on a hash and returns @racket[obj]. Note that you cannot explicitly set the @racket[ctype] of the properties with this form.
}
