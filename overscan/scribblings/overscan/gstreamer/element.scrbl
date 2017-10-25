#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]


@defclass/title[element% gst-object% ()]{
  The basic building block for any GStreamer media pipeline. Elements are like a black box: something goes in, and something else will come out the other side. For example, a @emph{decoder} element would take in encoded data and would output decoded data. A @emph{muxer} element would take in several different media streams and combine them into one. Elements are linked via @tech{pads}.

  @defmethod[(get-request-pad [name string?]) (or/c (is-a?/c pad%) #f)]{
    Retrieves a pad from @this-obj[] by name. This version only retrieves request pads. Returns @racket[#f] if a pad could not be found.
  }

  @defmethod[(get-static-pad [name string?]) (or/c (is-a?/c pad%) #f)]{
    Retrieves a pad from @this-obj[] by name. This version only retrieves already-existing (i.e. @emph{static}) pads. Returns @racket[#f] if a pad could not be found.
  }

  @defmethod[(link [dest (is-a?/c element%)]) boolean?]{
    Links @this-obj[] to @racket[dest] in that direction, looking for existing pads that aren't yet linked or requesting new pads if necessary. Returns @racket[#t] if the elements could be linked, @racket[#f] otherwise.
  }

  @defmethod[(unlink [dest (is-a?/c element%)]) void?]{
    Unlinks all source pads of @this-obj[] with all sink pads of the @racket[dest] element to which they are linked.
  }

  @defmethod[(link-many [element (is-a?/c element%)] ...+) boolean?]{
    Chains together a series of elements, using @method[element% link]. The elements must share a common bin parent.
  }

  @defmethod[(link-pads
              [srcpadname (or/c string? #f)]
              [dest (is-a?/c element%)]
              [destpadname (or/c string? #f)]) boolean?]{
    Links the two named pads of @this-obj[] and @racket[dest]. If both elements have different parents, the link fails. Both @racket[srcpadname] and @racket[destpadname] could be @racket[#f], in which acase any pad will be selected. Returns @racket[#t] if the pads could be linked, @racket[#f] otherwise.
  }

  @defmethod[(link-pads-filtered
              [srcpadname (or/c string? #f)]
              [dest (is-a?/c element%)]
              [destpadname (or/c string? #f)]
              [filter (or/c caps? #f)]) boolean?]{
    Equivalent to @method[element% link-pads], but if @racket[filter] is present and not @racket[#f], the link will be constrained by the specified set of @tech{caps}.
  }

  @defmethod[(link-filtered [dest (is-a?/c element%)] [filter (or/c caps? #f)]) boolean?]{
    Equivalent to @method[element% link], but if @racket[filter] is present and not @racket[#f], the link will be constrained by the specified set of @tech{caps}.
  }

  @defmethod[(get-factory) (is-a?/c element-factory%)]{
    Retrieves the factory that was used to create @this-obj[].
  }

  @defmethod[(set-state [state (one-of/c 'void-pending 'null 'ready 'paused 'playing)])
             (one-of/c 'failure 'success 'async 'no-preroll)]{
    Sets the state of @this-obj[]. If the method returns @racket['async], the element will perform the remainder of the state change asynchronously in another thread, in which case an application can use @method[element% get-state] to await the completion of the state change.
  }

  @defmethod[(get-state [timeout clock-time? clock-time-none])
             (values (one-of/c 'failure 'success 'async 'no-preroll)
                     (one-of/c 'void-pending 'null 'ready 'paused 'playing)
                     (one-of/c 'void-pending 'null 'ready 'paused 'playing))]{
    Gets the state of @this-obj[]. For elements that performed an @racket['async] state change as a result of @method[element% set-state], this method call will block up to the specified @racket[timeout] for the state change to complete.

    This method returns three values.

    The first returned value is the result of most recent state change, i.e. @racket['success] if the element has no more pending state and the last state change succeeded, @racket['async] if the element is still performing a state change, @racket['no-preroll] if the element successfully changed its state but is not able to provide data yet, or @racket['failure] if the last state change failed.

    The second return value is the current state of the element.

    The third return value is the pending state of the element, i.e. what the next state will be when the result of the state change is @racket['async].
  }
}
