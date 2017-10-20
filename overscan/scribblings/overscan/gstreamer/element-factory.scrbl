#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    ffi/unsafe/introspection]]


@defclass/title[element-factory% gst-object% ()]{
  Used to create instances of @racket[element%].

  @defproc[(element-factory%-find [name string?]) (or/c (is-a?/c element-factory%) #f)]{
    Search for an element factory of @racket[name]. Returns @racket[#f] if the factory could not be found.
  }

  @defproc[(element-factory%-make [factoryname string?] [name (or/c string? #f) #f])
           (or/c (is-a?/c element%) #f)]{
    Create a new element of the type defined by the given @racket[factoryname]. The element's name will be given the @racket[name] if supplied, otherwise the element will receive a unique name. Returns @racket[#f] if an element was unable to be created.
  }

  @defmethod[(create [name (or/c string? #f) #f]) (is-a?/c element%)]{
    Creates a new instance of @racket[element%] of the type defined by @this-obj[]. It will be given the @racket[name] supplied, or if @racket[name] is @racket[#f], a unique name will be created for it.
  }

  @defmethod[(get-metadata) (hash/c symbol? any/c)]{
    Returns a @racket[hash] of @this-obj[] metadata e.g. author, description, etc.
  }
}
