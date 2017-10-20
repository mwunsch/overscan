#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    ffi/unsafe/introspection]]


@defclass/title[element% gst-object% ()]{
  The basic building block for any GStreamer media pipeline. Elements are like a black box: something goes in, and something else will come out the other side. For example, a @emph{decoder} element would take in encoded data and would output decoded data. A @emph{muxer} element would take in several different media streams and combine them into one.

  @defmethod[(link [dest (is-a?/c element%)]) boolean?]{
    Links @this-obj[] to @racket[dest] in that direction, looking for existing pads that aren't yet linked or requesting new pads if necessary. Returns @racket[#t] if the elements could be linked, @racket[#f] otherwise.
  }

  @defmethod[(unlink [dest (is-a?/c element%)]) void?]{
    Unlinks all source pads of @this-obj[] with all sink pads of the @racket[dest] element to which they are linked.
  }

  @defmethod[(link-many [element (is-a?/c element%)] ...+) boolean?]{
    Chains together a series of elements, using @method[element% link]. The elements must share a common bin parent.
  }

  @defmethod[(get-factory) (is-a?/c element-factory%)]{
    Retrieves the factory that was used to create @this-obj[].
  }
}
