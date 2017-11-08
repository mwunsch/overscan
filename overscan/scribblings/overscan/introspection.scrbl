#lang scribble/manual
@require[@for-label[ffi/unsafe/introspection
                    racket/base
                    racket/contract
                    racket/class
                    (except-in ffi/unsafe ->)]]

@title[#:tag "gobject-introspection"]{GObject Introspection}

@secref{gstreamer} is the core framework that powers the multimedia capabilities of Overscan. GStreamer is also a @bold{C} framework, which means that a big part of Overscan's codebase is dedicated to the interop between Racket and C. Racket provides a phenomenal @seclink["top" #:doc '(lib "scribblings/foreign/foreign.scrbl")]{Foreign Interface}, but to create foreign functions for all the relevant portions of GStreamer would be cumbersome, at best.

Luckily, GStreamer is written with @hyperlink["https://wiki.gnome.org/Projects/GLib"]{GLib} and contains @hyperlink["https://wiki.gnome.org/Projects/GObjectIntrospection"]{GObject Introspection} metadata. @deftech{GObject Introspection} (aka @deftech{GIR}) is an interface description layer that allows for a language to read this metadata and dynamically create bindings for the C library.

The Overscan package provides a module designed to accompany Racket's FFI collection. This module brings additional functionality and @secref["types" #:doc '(lib "scribblings/foreign/foreign.scrbl")] for working with introspected C libraries. This module powers the @secref{gstreamer} module, but can be used outside of Overscan for working with other GLib libraries.

@defmodule[ffi/unsafe/introspection]

@section[#:tag "gir-basic-usage"]{Basic Usage}

Using GIR will typically go as follows: Introspect a namespace that you have a typelib for with @racket[introspection], call that namespace as a procedure to look up a binding, work with that binding either as a procedure or some other value (typically a @tech{gobject}).

In this case of a typical "Hello, world" style example with GStreamer, that would look like this:

@racketblock[
  (define gst (introspection 'Gst))
  (define gst-version (gst 'version_string))
  (printf "This program is linked against ~a"
          (gst-version))
]

This will result in the string @tt{"This program is linked against GStreamer 1.10.4"} being printed, or whatever version of GStreamer is available.

In the second line of this program, the @racket['version_string] symbol is looked up against the GStreamer typelib and a @racket[gi-function?] is returned. That can then be called as a procedure, which in this case takes no arguments.

@section[#:tag "girepository"]{GIRepository}

GIR's @hyperlink["https://developer.gnome.org/gi/stable/GIRepository.html"]{@tt{GIRepository}} API manages the namespaces provided by the GIR system and type libraries. Each namespace contains metadata entries that map to C functionality. In the case of @secref{gstreamer}, the @racket['Gst] namespace contains all of the introspection information used to power that interface.

@defproc[(introspection [namespace symbol?] [version string? #f])
         gi-repository?]{
  Search for the @racket[namespace] typelib in the GObject Introspection repository search path and load it. If @racket[version] is not specified, the latest version will be used.

  An example for loading the @secref{gstreamer} namespace:

  @racketinput[
    (define gst (introspection 'Gst))
    @#,racketresult[#,(procedure "gi-repository")]
  ]

  This is the only provided mechanism to construct a @racket[gi-repository].
}

@defstruct*[gi-repository ([namespace symbol?]
                           [version string?]
                           [info-hash (hash/c symbol? gi-base?)])
            #:omit-constructor ]{
  A struct representing a namespace of an introspected typelib. This struct is constructed bye calling @racket[introspection]. This struct has the @racket[prop:procedure] property and is intended to be called as a procedure:

  @nested[#:style 'inset]{
    @defproc*[#:kind "gi-repository" #:link-target? #f
              ([(repository) (hash/c symbol? gi-base?)]
               [(repository [name symbol?]) gi-base?])]{
      When called as in the first form, without an argument, the proc will return a @racket[hash] of all of the known members of the namespace.

      When called as the second form, this is the equivalent to @racket[gi-repository-find-name] with the first argument already set. e.g.

      @racketinput[
        (gst 'version)
        @#,racketresult[#,(procedure "gi-function")]
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
  The common base struct of all GIR metadata entries. Instances of this struct have the @racket[prop:cpointer] property, and can be used transparently as @racket[cpointers] to their respective entries. This struct and its descendants are constructed by looking up a symbol on a @racket[gi-repository].

  When a GIR metadata entry is located it will usually be a subtype of @racket[gi-base]. Most of those subtypes implement @racket[prop:procedure] and are designed to be called on return to produce meaningful values.

  The typical subtypes are:

  @nested[#:style 'inset]{
    @defproc[#:kind "gi-base"
             (gi-function [arg any/c] ...) any]{
      An introspected C function. Call this as you would any other Racket procedure. C functions have a tendency to mutate call-by-reference pointers, and when that is the case calling a @racket[gi-function] returns multiple values. The first return value is always the return value of the function.
    }
  }

  @nested[#:style 'inset]{
    @defproc[#:kind "gi-base"
             (gi-constant) any/c]{
      Calling a @racket[gi-constant] as a procedure returns its value.
    }
  }

  @nested[#:style 'inset]{
    @defproc[#:kind "gi-registered-type"
             (gi-struct [method-name symbol?] [arg any/c] ...) any]{

      The first argument to a @racket[gi-struct] is the name of a method, with subsequent arguments passed in to that method call. This procedure form is mainly used for calling factory style methods, and more useful for the similar @racket[gi-object]. Usually, you'll be working with instances of this type, @racket[gstruct]s.
    }
  }

  @nested[#:style 'inset]{
    @defproc[#:kind "gi-registered-type"
             (gi-object [method-name symbol?] [arg any/c] ...) any]{

      Like @racket[gi-struct], calling a @racket[gi-object] as a procedure will accept a method name and subsequent arguments. This is the preferred form for calling constructors that will return @tech{gobject}s.
    }
  }

  @nested[#:style 'inset]{
    @defthing[#:kind "gi-registered-type"
             gi-enum gi-enum?]{

      A @racket[gi-enum] represents an enumeration of values and, unlike other @racket[gi-base] subtypes, is not represented as a procedure. The main use case is to transform it into some other Racket representation, i.e. with @racket[gi-enum->list].
    }
  }

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

@defproc[(gi-bitmask? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @racket[gi-enum?] but is represented as a bitmask in C.
}

@defproc[(gi-enum->list [enum gi-enum?]) list?]{
  Convert @racket[enum] to a list of symbols, representing the values of the enumeration.
}

@defproc[(gi-enum->hash [enum gi-enum?]) hash?]{
  Convert @racket[enum] to a hash mapping symbols to their numeric value.
}

@defproc[(gi-enum-value/c [enum gi-enum?]) flat-contract?]{
  Accepts a @racket[gi-enum] and returns a flat contract that recognizes its values.
}

@defproc[(gi-bitmask-value/c [enum gi-bitmask?]) list-contract?]{
  Accepts a bitmask @racket[gi-enum] and returns a contract that recognizes a list of allowed values.
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

@defproc[(is-gtype? [v any/c] [type gi-registered-type?]) boolean?]{
  Returns @racket[#t] if @racket[v] is an instance of @racket[type], @racket[#f] otherwise. Similar to @racket[is-a?].
}

@defproc[(is-gtype?/c [type gi-registered-type?]) flat-contract?]{
  Accepts a @racket[type] and returns a flat contract that recognizes its instances.
}

@defstruct*[(gstruct gtype-instance)
            ([type gi-struct?] [pointer cpointer?])
            #:omit-constructor ]{
  Represents an instance of a C Struct. That Struct can have methods and fields.
}

@section[#:tag "gobject"]{GObjects}

A @deftech{gobject} instance, like the introspected metadata entries provided by GIR, is a transparent pointer with additional utilities to be called as an object within Racket. GObjects behave like Racket objects, with the exception that they aren't backed by @emph{classes} in the @racketmodname[racket/class] sense, but instead are derived from the introspected metadata.

@defproc[(gobject? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is an instance of a GObject, @racket[#f] otherwise. You can call methods, get or set fields, get/set properties, or connect to signals on a GObject. @racket[gstruct] structs are also GObjects for the purposes of this predicate, since they behave in similar ways with the exception of signals and properties.
}

@defproc[(gobject/c [type gi-registered-type?]) flat-contract?]{
  Accepts a @racket[type] and returns a flat contract that recognizes objects that instantiate it. Unlike @racket[is-gtype?/c], this implies @racket[gobject?].
}

@defproc[(gobject-ptr [obj gobject?]) gtype-instance?]{
 Returns the @racket[gtype-instance] associated with @racket[obj].
}

@defproc[(gobject-send [obj gobject?] [method-name symbol?] [argument any/c] ...) any]{
  Calls the method on @racket[obj] whose name matches @racket[method-name], passing along all given @racket[argument]s.
}

@defproc[(gobject-get-field [field-name symbol?] [obj gobject?]) any]{
  Extracts the field from @racket[obj] whose name matches @racket[field-name]. Note that @emph{fields} are distinct from GObject @emph{properties}, which are accessed with @racket[gobject-get].
}

@defproc[(gobject-set-field! [field-name symbol?] [obj gobject?] [v any/c]) void?]{
  Sets the field from @racket[obj] whose name matches @racket[field-name] to @racket[v].
}

@defproc[(gobject-responds-to? [obj gobject?] [method-name symbol?]) boolean?]{
  Produces @racket[#t] if @racket[obj] or its ancestors defines a method with the name @racket[method-name], @racket[#f] otherwise.
}

@defproc[(gobject-responds-to?/c [method-name symbol?]) flat-contract?]{
  Accepts a @racket[method-name] and returns a flat contract that recognizes objects with a method defined with the given name in it or its ancestors. Useful for duck-typing.
}

@defproc[(method-names [obj gobject?]) (listof symbol?)]{
  Extracts a list that @racket[obj] recognizes as names of methods it understands. This list might not be exhaustive.
}

@defproc[(connect [obj gobject?] [signal-name symbol?] [handler procedure?]
          [#:data data cpointer? #f]
          [#:cast _user-data (or/c ctype? gi-object?) #f]) exact-integer?]{
  Register a callback @racket[handler] for the @deftech[#:key "signal"]{@hyperlink["https://developer.gnome.org/gobject/stable/signal.html"]{signal}} matching the name @racket[signal-name] for the @racket[obj]. The @racket[handler] will receive three arguments, @racket[obj], the name of the signal as a string, and @racket[data]. When both are present, @racket[data] will be cast to @racket[_user-data] before being passed to the @racket[handler].
}

@defproc[(gobject-cast [pointer cpointer?] [obj gi-object?]) gobject?]{
  This will cast @racket[pointer] to @racket[(_gi-object obj)], thereby transforming it into a @tech{gobject}.
}

@defproc[(gobject-get [obj gobject?] [propname string?] [ctype (or/c ctype? gi-registered-type? (listof symbol?))]) any?]{
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

@defthing[prop:gobject struct-type-property?]{
  A @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{structure type property} that causes instances of a structure type to work as GObject instances. The property value must be either a @racket[gtype-instance] or a procedure that accepts the structure instance and returns a @racket[gtype-instance].

  The @racket[prop:gobject] property allows a GObject instance to be transparently wrapped by a structure that may have additional values or properties.
}

@definterface[gobject<%> ()]{
  A @racket[gobject<%>] object encapsulates a @tech{gobject} pointer. It looks for a field called @racketid[pointer] and will use that as a value for @racket[prop:gobject], so that objects implementing this interface return @racket[#t] to @racket[gobject?] and @racket[cpointer?].
}

@defclass[gobject% object% (gobject<%>)]{
  Instances of this class return @racket[#t] to @racket[gobject?].

  @defconstructor[([pointer gtype-instance?])]
}

@defform[(make-gobject-delegate method-decl ...)
         #:grammar [(method-decl id
                                 (code:line (id internal-method)))]
         #:contracts ([internal-method symbol?])]{
  Create a @racket[mixin] that defines a class extension that implements @racket[gobject<%>]. The specified @racket[id]s will be defined as public methods that delegate to the @racketid[pointer]. When @racket[internal-method] is included, the expression is assumed to result in a symbol that will be used to look up the method in GIR. When no @racket[internal-method] is provided, the method name used by GIR will be the @racket[id] with dashes replaced with underscores.

  e.g.
  @racketblock[
    (make-gobject-delegate get-name get-factory [static-pad 'get_static_pad])
  ]
  is equivalent to:
  @racketblock[
    (mixin (gobject<%>) (gobject<%>)
      (super-new)
      (inherit-field pointer)
      (define/public (get-name . args)
        (apply gobject-send pointer 'get_name args))
      (define/public (get-factory . args)
        (apply gobject-send pointer 'get_factory args))
      (define/public (static-pad . args)
        (apply gobject-send pointer 'get_static_pad args)))
  ]
}
