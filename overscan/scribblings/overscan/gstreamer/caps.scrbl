#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@title{Capabilities}

Capabilities, or @deftech{caps}, are a mechanism to describe the data that can flow or currently flows through a @tech{pad}. They are a structure describing media types.

@defproc[(caps? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @tech{cap} describing media types, @racket[#f] otherwise.
}

@defproc[(string->caps [str string?]) (or/c caps? #f)]{
  Convert @tech{caps} from a string representation. Returns @racket[#f] if caps could not be converted from @racket[str].
}

@defproc[(caps->string [caps caps?]) string?]{
  Convert @racket[caps] to a string representation.
}

@defproc[(caps-append! [caps1 caps?] [caps2 caps?]) void?]{
  Appends the structure contained in @racket[caps2] to @racket[caps1]. The structures in @racket[caps2] are not copied --- they are transferred and @racket[caps1] is mutated.
}

@defproc[(caps-any? [caps caps?]) boolean?]{
  Returns @racket[#t] if @racket[caps] represents any media format, @racket[#f] otherwise.
}

@defproc[(caps-empty? [caps caps?]) boolean?]{
  Returns @racket[#t] if @racket[caps] represents no media formats, @racket[#f] otherwise.
}

@defproc[(caps-fixed? [caps caps?]) boolean?]{
  Returns @racket[#t] if @racket[caps] is fixed, @racket[#f] otherwise. Fixed caps describe exactly one format.
}

@defproc[(caps=? [caps1 caps?] [caps2 caps?]) boolean?]{
  Returns @racket[#t] if @racket[caps1] and @racket[caps2] represent the same set of caps, @racket[#f] otherwise.
}

@defproc[(make-capsfilter [caps caps?] [name (or/c string? #f) #f])
         (is-a?/c element%)]{
  Create a @deftech{capsfilter} element with the given @racket[name] (or use a generated name if @racket[#f]). A capsfilter element does not modify data but can enforce limitations on the data passing through it via its @racket[caps] property.
}
