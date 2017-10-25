#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@defclass/title[bin% element% ()]{
  A @deftech{bin} is a container element. Elements can be added to a bin. Since a bin is also itself an element, a bin can be handled in the same way as any other element. Bins combine a group of linked elements into one logical element, allowing them to be managed as a group.

  @defproc[(bin%-new [name (or/c string? #f) #f]) (is-a?/c bin%)]{
    Creates a new bin with the given @racket[name], or generates a name if @racket[name] is @racket[#f].
  }

  @defproc[(bin%-compose [name (or/c string? #f)] [element (is-a?/c element%)] ...+)
           (or/c (is-a?/c bin%) #f)]{
    Compose a new bin with the given @racket[name] (or a generated name if @racket[name] is @racket[#f]) by adding the given @racket[element]s, linking them in order, and creating ghost sink and src ghost pads. Returns @racket[#f] if the elements could not be added or linked. A convenient mechanism for creating a bin, adding elements to it, and linking them together in one procedure.
  }

  @defmethod[(add [element (is-a?/c element%)]) boolean?]{
    Adds @racket[element] to @this-obj[]. Sets the element's parent. An element can only be added to one bin.

    If @racket[element]'s pads are linked to other pads, the pads will be unlinked before the element is added to the bin.

    Returns @racket[#t] if @racket[element] could be added, @racket[#f] if @this-obj[] does not want to accept @racket[element].
  }

  @defmethod[(remove [element (is-a?/c element%)]) boolean?]{
    Removes @racket[element] from @this-obj[], unparenting it in the process. Returns @racket[#t] if @racket[element] could be removed, @racket[#f] if @this-obj[] does not want it removed.
  }

  @defmethod[(get-by-name [name string?]) (or/c (is-a?/c element%) #f)]{
    Gets the element with the given @racket[name] from @this-obj[], recursing into child bins. Returns @racket[#f] if no element with the given name is found in the bin.
  }

  @defmethod[(add-many [element (is-a?/c element%)] ...+) boolean?]{
    Adds a series of elements to @this-obj[], equivalent to calling @method[bin% add] for each @racket[element]. Returns @racket[#t] if every @racket[element] could be added to @this-obj[], @racket[#f] otherwise.
  }

  @defmethod[(find-unlinked-pad [direction (one-of/c 'unknown 'src 'sink)]) (or/c (is-a?/c pad%) #f)]{
    Recursively looks for elements with an unlinked @tech{pad} of the given @racket[direction] within @this-obj[] and returns an unlinked pad if one is found, or @racket[#f] otherwise.
  }

  @defmethod[(sync-children-states) boolean?]{
    Synchronizes the state of every child of @this-obj[] with the state of @this-obj[]. Returns @racket[#t] if syncing the state was successful for all children, @racket[#f] otherwise.
  }

  @defproc[(bin->dot [bin (is-a?/c bin%)]
            [#:details details
             (one-of/c 'media-type 'caps-details 'non-default-params 'states 'full-params 'all 'verbose)
             'all]) string?]{
    Return a string of DOT grammar for use with graphviz to visualize the @racket[bin]. Useful for debugging purposes. @racket[details] refines the level of detail to show in the graph.
  }
}

@section[#:style 'hidden]{@racket[pipeline%]}

@defclass[pipeline% bin% ()]{
  A @deftech{pipeline} is a special @tech{bin} used as a top-level container. It provides clocking and message bus functionality to the application.

  @defmethod[(get-bus) (is-a?/c bus%)]{
    Returns the @tech{bus} of @this-obj[]. The bus allows the application to receive @tech{messages}.
  }

  @defmethod[(get-pipeline-clock) (is-a?/c clock%)]{
    Gets the current clock used by @this-obj[].
  }

  @defmethod[(get-latency) clock-time?]{
    Gets the latency configured on @this-obj[]. The latency is the time it takes for a sample to reach the sink.
  }
}

@defproc[(pipeline%-new [name (or/c string? #f) #f]) (is-a?/c pipeline%)]{
  Creates a new pipeline with the given @racket[name], or generates a name if @racket[name] is @racket[#f].
}

@defproc[(pipeline%-compose [name (or/c string? #f)] [element (is-a?/c element%)] ...+)
         (or/c (is-a?/c pipeline%) #f)]{
  Creates a pipeline by first creating a @tech{bin} with @racket[bin%-compose] and then adding that bin as a child of the pipeline. Returns the pipeline or @racket[#f] if the @racket[bin%-compose] call fails or the bin cannot be added to the pipeline.
}
