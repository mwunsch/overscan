#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]


@defclass/title[pad% gst-object% ()]{
  A @racket[element%] is linked to other elements via @deftech{pads}. Pads are the element's interface to the outside world. Data streams from one element's source pad to another element's sink pad. The specific type of media that the element can handle will be exposed by the pad's capabilities.

  A pad is defined by two properties: its direction and its availability. A pad direction can be a @deftech{source pad} or a @deftech{sink pad}. Elements receive data on their sink pads and generate data on their source pads.

  A pad can have three availabilities: always, sometimes, and on request.

  @defmethod[(get-direction) (one-of/c 'unknown 'src 'sink)]{
    Gets the direction of @this-obj[].
  }

  @defmethod[(get-parent-element) (is-a?/c element%)]{
    Gets the parent element of @this-obj[].
  }

  @defmethod[(get-pad-template) (or/c pad-template? #f)]{
    Gets the template for @this-obj[].
  }

  @defmethod[(link [sinkpad (is-a?/c pad%)])
             (one-of/c 'ok 'wrong-hierarchy 'was-linked 'wrong-direction 'noformat 'nosched 'refused)]{
    Links @this-obj[] and the @racket[sinkpad]. Returns a result code indicating if the connection worked or what went wrong.
  }

  @defmethod[(link-maybe-ghosting [sink (is-a?/c pad%)]) boolean?]{
    Links @this-obj[] to @racket[sink], creating any @tech{ghost pads} in between as necessary. Returns @racket[#t] if the link succeeded, @racket[#f] otherwise.
  }

  @defmethod[(unlink [sinkpad (is-a?/c pad%)]) boolean?]{
    Unlinks @this-obj[] from the @racket[sinkpad]. Returns @racket[#t] if the pads were unlinked and @racket[#f] if the pads were not linked together.
  }

  @defmethod[(linked?) boolean]{
    Returns @racket[#t] if @this-obj[] is linked to another pad, @racket[#f] otherwise.
  }

  @defmethod[(can-link? [sinkpad (is-a?/c pad%)]) boolean?]{
    Checks if @this-obj[] and @racket[sinkpad] are compatible so they can be linked. Returns @racket[#t] if they can be linked, @racket[#f] otherwise.
  }

  @defmethod[(get-allowed-caps) (or/c caps? #f)]{
    Gets the @tech[#:key "caps"]{capabilities} of the allowed media types that can flow through @this-obj[] and its peer. Returns @racket[#f] if @this-obj[] has no peer.
  }

  @defmethod[(get-current-caps) caps?]{
    Gets the @tech[#:key "caps"]{capabilities} currently configured on @this-obj[], or @racket[#f] when @this-obj[] has no caps.
  }

  @defmethod[(get-pad-template-caps) caps?]{
    Gets the @tech[#:key "caps"]{capabilities} for @this-obj[]'s template.
  }

  @defmethod[(get-peer) (or/c (is-a?/c pad%) #f)]{
    Gets the peer of @this-obj[] or @racket[#f] if there is none.
  }

  @defmethod[(has-current-caps?) boolean?]{
    Returns @racket[#t] if @this-obj[] has @tech{caps} set on it, @racket[#f] otherwise.
  }

  @defmethod[(active?) boolean?]{
    Returns @racket[#t] if @this-obj[] is active, @racket[#f] otherwise.
  }

  @defmethod[(blocked?) boolean?]{
    Returns @racket[#t] if @this-obj[] is blocked, @racket[#f] otherwise.
  }

  @defmethod[(blocking?) boolean?]{
    Returns @racket[#t] if @this-obj[] is blocking downstream links, @racket[#f] otherwise.
  }
}

@section[#:style 'hidden]{@racket[ghost-pad%]}

@defclass[ghost-pad% pad% ()]{
  A @deftech{ghost pad} acts as a proxy for another pad, and are used when working with @tech{bins}. They allow the bin to have sink and/or source pads that link to the sink/source pads of the child elements.

  @defmethod[(get-target) (or/c (is-a?/c pad%) #f)]{
    Get the target pad of @this-obj[] or @racket[#f] if no target is set.
  }

  @defmethod[(set-target [target (is-a?/c pad%)]) boolean?]{
    Sets the new target of @this-obj[] to @racket[target]. Returns @racket[#t] on success or @racket[#f] if pads could not be linked.
  }
}

@defproc[(ghost-pad%-new [name (or/c string? #f)]
          [target (is-a?/c pad%)])
          (or/c (is-a?/c ghost-pad%) #f)]{
  Create a new ghost pad with @racket{target} as the target, or @racket[#f] if there is an error.
}

@defproc[(ghost-pad%-new-no-target
         [name (or/c string? #f)]
         [direction (one-of/c 'unknown 'src 'sink)])
         (or/c (is-a?/c ghost-pad%) #f)]{
  Create a new ghost pad without a target with the given @racket[direction], or @racket[#f] if there is an error.
}

@section{Pad Templates}

@defproc[(pad-template? [v any/c]) boolean?]{
  A @deftech{pad template} describes the possible media types a pad can handle. Returns @racket[#t] if @racket[v] is a pad template, @racket[#f] otherwise.
}

@defproc[(pad-template-caps [template pad-template?]) caps?]{
  Gets the @tech[#:key "caps"]{capabilities} of @racket[template].
}

@defproc[(make-pad-template
          [name string?]
          [direction (one-of/c 'unknown 'src 'sink)]
          [presence (one-of/c 'always 'sometimes 'request)]
          [caps caps?]) pad-template?]{
  Creates a new pad template with a name and with the given arguments.
}

@defproc[(pad%-new-from-template [template pad-template?] [name (or/c string? #f) #f])
          (or/c (is-a?/c pad%) #f)]{
  Creates a new pad from @racket[template] with the given @racket[name], generating a unique name if @racket[name] is @racket[#f]. Returns @racket[#f] in case of error.
}
