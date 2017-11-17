#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@defclass/title[device% gobject% ()]{
  A GStreamer @deftech{Device} represents a hardware device that can serve as a source or a sink. Each device contains metadata on the device, such as the @tech{caps} it handles as well as its @emph{class}: a string representation that states what the device does. It can also create @tech{elements} that can be used in a GStreamer pipeline.

  @defmethod[(create-element [name (or/c string? #f) #f]) (is-a?/c element%)]{
    Create an element with all of the required parameters to use @this-obj[]. The element will be named @racket[name] or, if @racket[#f], a unique name will be generated.
  }

  @defmethod[(get-caps) caps?]{
    Get the caps supported by @this-obj[].
  }

  @defmethod[(get-device-class) string?]{
    Gets the class of @this-obj[]; A @racket["/"] separated list.
  }

  @defmethod[(get-display-name) string?]{
    Get the user-friendly name of this @this-obj[].
  }

  @defmethod[(has-classes? [classes string?]) boolean?]{
    Returns @racket[#t] if @this-obj[] matches all of the given @racket[classes], @racket[#f] otherwise.
  }
}

@section[#:style 'hidden]{@racket[device-monitor%]}

@defclass[device-monitor% gobject% ()]{
  A @deftech{device monitor} monitors hardware devices. They post messages on their @tech{bus} when new devices are available and have been removed, and can get a list of @tech{devices}.

  @defmethod[(get-bus) (is-a?/c bus%)]{
    Gets the bus for @this-obj[] where messages about device states are posted.
  }

  @defmethod[(add-filter [classes (or/c string? #f)] [caps (or/c caps? #f)])
             exact-integer?]{
    Adds a filter for a @tech{device} to be monitored. Devices that match @racket[classes] and @racket[caps] will be probed by @this-obj[]. If @racket[classes] is @racket[#f] any device class will be matched. Similarly, if @racket[caps] is @racket[#f], any media type will be matched. This will return the id of the filter, or @racket[0] if no device is available to match this filter.
  }

  @defmethod[(remove-filter [filter-id exact-integer?]) boolean?]{
    Removes a filter from @this-obj[] using a @racket[filter-id] that was returned by @method[device-monitor% add-filter]. Returns @racket[#t] if the @racket[filter-id] was valid, @racket[#f] otherwise.
  }

  @defmethod[(get-devices) (listof (is-a?/c device%))]{
    Gets a list of devices from @this-obj[] that match any of its filters.
  }
}

@defproc[(device-monitor%-new) (is-a?/c device-monitor%)]{
  Create a new @tech{device monitor}.
}
