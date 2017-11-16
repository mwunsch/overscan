#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@defclass/title[device% gobject% ()]{
  @defmethod[(create-element [name (or/c string? #f) #f]) (is-a?/c element%)]{
  }

  @defmethod[(get-caps) caps?]{
  }

  @defmethod[(get-device-class) string?]{
  }

  @defmethod[(get-display-name) string?]{
  }

  @defmethod[(has-classes? [classes string?]) boolean?]{
  }
}

@section[#:style 'hidden]{@racket[device-monitor%]}

@defclass[device-monitor% gobject% ()]{
  @defmethod[(get-bus) (is-a?/c bus%)]{
  }

  @defmethod[(add-filter [classes (or/c string? #f)] [caps (or/c caps? #f)])
             exact-integer?]{
  }

  @defmethod[(remove-filter [filter-id exact-integer?]) boolean?]{
  }

  @defmethod[(get-devices) (listof (is-a?/c device%))]{
  }
}

@defproc[(device-monitor%-new) (is-a?/c device-monitor%)]{
}
