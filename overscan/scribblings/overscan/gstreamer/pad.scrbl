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

  @defmethod[(unlink [sinkpad (is-a?/c pad%)]) boolean?]{
    Unlinks @this-obj[] from the @racket[sinkpad]. Returns @racket[#t] if the pads were unlinked and @racket[#f] if the pads were not linked together.
  }

  @defmethod[(linked?) boolean]{
    Returns @racket[#t] if @this-obj[] is linked to another pad, @racket[#f] otherwise.
  }

  @defmethod[(can-link? [sinkpad (is-a?/c pad%)]) boolean?]{
    Checks if @this-obj[] and @racket[sinkpad] are compatible so they can be linked. Returns @racket[#t] if they can be linked, @racket[#f] otherwise.
  }

  @defmethod[(get-peer) (or/c (is-a?/c pad%) #f)]{
    Gets the peer of @this-obj[] or @racket[#f] if there is none.
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

  @defproc[(pad-template? [v any/c]) boolean?]{
    A @deftech{pad template} describes the possible media types a pad can handle. Returns @racket[#t] if @racket[v] is a pad template, @racket[#f] otherwise.
  }
}
