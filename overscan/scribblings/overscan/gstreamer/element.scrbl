#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]


@defclass/title[element% gst-object% ()]{
  The basic building block for any GStreamer media pipeline. @deftech{Elements} are like a black box: something goes in, and something else will come out the other side. For example, a @emph{decoder} element would take in encoded data and would output decoded data. A @emph{muxer} element would take in several different media streams and combine them into one. Elements are linked via @tech{pads}.

  @defmethod[(add-pad [pad (is-a?/c pad%)]) boolean?]{
    Adds @racket[pad] to @this-obj[]. Returns @racket[#t] if the pad could be added, @racket[#f] otherwise. This method can fail when a pad with the same name already existed or @racket[pad] already had another parent.
  }

  @defmethod[(get-compatible-pad [pad (is-a?/c pad%)] [caps (or/c caps? #f) #f]) (or/c (is-a?/c pad%) #f)]{
    Look for an unlinked pad to which @racket[pad] can link. When @racket[caps] are present, they are used as a filter for the link. Returns a @racket[pad%] to which a link could be made, or @racket[#f] if one cannot be found.
  }

  @defmethod[(get-compatible-pad-template [compattempl pad-template?]) (or/c pad-template? #f)]{
    Retrieves a @tech{pad template} from @this-obj[] that is compatible with @racket[compattempl]. Pads from compatible templates can be linked together.
  }

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

  @defmethod[(set-context [context context?]) void?]{
    Sets the @tech{context} of @this-obj[] to @racket[context].
  }

  @defmethod[(get-context [type string?]) (or/c context? #f)]{
    Gets the context with the @racket[type] from @this-obj[] or @racket[#f] one is not present.
  }

  @defmethod[(get-contexts) (listof context?)]{
    Gets the @tech{contexts} set on @this-obj[].
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

  @defmethod[(post-message [message message?]) boolean?]{
    Posts @racket[message] on @this-obj[]'s @tech{bus}. Returns @racket[#t] if the message was successfully posted, @racket[#f] otherwise.
  }

  @defmethod[(send-event [event event?]) boolean?]{
    Sends an @tech{event} to @this-obj[]. Returns @racket[#t] if the event was handled, @racket[#f] otherwise.
  }

  @defmethod[(play!) (one-of/c 'failure 'success 'async 'no-preroll)]{
    Shorthand equivalent to calling @method[element% set-state] on @this-obj[] with @racket['playing].
  }

  @defmethod[(pause!) (one-of/c 'failure 'success 'async 'no-preroll)]{
    Shorthand equivalent to calling @method[element% set-state] on @this-obj[] with @racket['paused].
  }

  @defmethod[(stop!) (one-of/c 'failure 'success 'async 'no-preroll)]{
    Shorthand equivalent to calling @method[element% set-state] on @this-obj[] with @racket['null].
  }

  @defproc[(element/c [factoryname string?]) flat-contract?]{
    Accepts a string @racket[factoryname] and returns a flat contract that recognizes elements created by a factory of that name.
  }

  @defproc[(parse/launch [description string?]) (or/c (is-a?/c element%) #f)]{
    Create a new element based on @hyperlink["https://gstreamer.freedesktop.org/documentation/tools/gst-launch.html#pipeline-description"]{command line syntax}, where @racket[description] is a command line describing a pipeline. Returns @racket[#f] if an element could not be created.
  }
}

@section[#:style 'hidden]{@racket[element-factory%]}

@defclass[element-factory% gst-object% ()]{
  @deftech{Element factories} are used to create instances of @racket[element%].

  @defmethod[(create [name (or/c string? #f) #f]) (is-a?/c element%)]{
    Creates a new instance of @racket[element%] of the type defined by @this-obj[]. It will be given the @racket[name] supplied, or if @racket[name] is @racket[#f], a unique name will be created for it.
  }

  @defmethod[(get-metadata) (hash/c symbol? any/c)]{
    Returns a @racket[hash] of @this-obj[] metadata e.g. author, description, etc.
  }
}

@defproc[(element-factory%-find [name string?]) (or/c (is-a?/c element-factory%) #f)]{
  Search for an element factory of @racket[name]. Returns @racket[#f] if the factory could not be found.
}

@defproc[(element-factory%-make [factoryname string?] [name (or/c string? #f) #f]
         [#:class factory% (subclass?/c element%) element%])
         (or/c (is-a?/c element%) #f)]{
  Create a new element of the type defined by the given @racket[factoryname]. The element's name will be given the @racket[name] if supplied, otherwise the element will receive a unique name. The returned element will be an instance of @racket[factory%] if provided.

  Returns @racket[#f] if an element was unable to be created.
}

@section{Events}

An @deftech{event} in GStreamer is a small structure to describe notification signals that can be passed up and down a @tech{pipeline}. Events can move both upstream and downstream, notifying elements of stream states. Send an event through a pipeline with @method[element% send-event].

@defproc[(event? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a GStreamer event, @racket[#f] otherwise.
}

@defproc[(event-type [ev event?])
         (one-of/c 'unknown 'flush-start 'flush-stop 'stream-start 'caps 'segment
                   'stream-collection 'tag 'buffersize 'sink-message 'stream-group-done
                   'eos 'toc 'protection 'segment-done 'gap 'qos 'seek 'navigation
                   'latency 'step 'reconfigure 'toc-select 'select-streams
                   'custom-upstream 'custom-downstream 'custom-downstream-oob
                   'custom-downstream-sticky 'custom-both 'custom-both-oob)]{
  Gets the type of event for @racket[ev].
}

@defproc[(event-seqnum [ev event?]) exact-integer?]{
  Retrieve the sequence number of @racket[ev].

  Events have ever-incrementing sequence numbers. Sequence numbers are typically used to indicate that an event corresponds to some other set of messages or events.

  Events and @tech{messages} share the same sequence number incrementor; two events or messages will never have the same sequence number unless that correspondence was made explicitly.
}

@defproc[(make-eos-event) event?]{
  Create a new @deftech{EOS} (end-of-stream) event.

  The EOS event will travel down to the sink elements in the pipeline which will then post an @racket[eos-message?] on the bus after they have finished playing any buffered data.

  The EOS event itself will not cause any state transitions of the pipeline.
}

@section{Contexts}

A GStreamer @deftech{context} is a container used to store contexts that can be shared between multiple elements. Applications will set a context on an element (or a pipeline) with @method[element% set-context].

@defproc[(context? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @tech{context}, @racket[#f] otherwise.
}

@defproc[(context-type [context context?]) string?]{
  Gets the type of @racket[context], which is just a string that describes what the context contains.
}

@defproc[(context-has-type? [context context?] [type string?]) boolean?]{
  Returns @racket[#t] if @racket[context] has a context type of @racket[type], @racket[#f] otherwise.
}

@defproc[(context-persistent? [context context?]) boolean?]{
  Returns @racket[#t] if @racket[context] is persistent, that is the context will be kept by the element even if it reaches a @racket['null] state. Otherwise returns @racket[#f].
}

@defproc[(make-context [type string?] [key string?] [value any/c] [persistent? boolean? #f])
         context?]{
  Create a context of @racket[type] that maps @racket[key] to @racket[value].
}

@defproc[(context-ref [context context?] [key string?]) (or/c any/c #f)]{
  Retrieves the value of @racket[context] mapped to @racket[key], or @racket[#f] if no value is found.
}
