#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@defclass/title[bus% gst-object% ()]{
  The @deftech{bus} is responsible for delivering @tech{messages} in a first-in first-out way from a @tech{pipeline}.

  @defmethod[(post [message message?]) boolean?]{
    Post the @racket[message] on @this-obj[]. Returns @racket[#t] if the message could be posted, otherwise @racket[#f].
  }

  @defmethod[(have-pending?) boolean?]{
    Check if there are pending messages on @this-obj[] that should be handled.
  }

  @defmethod[(peek) (or/c message? #f)]{
    Peek the message on the top of @this-obj[]' queue. The message will remain on the queue. Returns @racket[#f] if the bus is empty.
  }

  @defmethod[(pop) (or/c message? #f)]{
    Gets a message from @this-obj[], or @racket[#f] if the bus is empty.
  }

  @defmethod[(pop-filtered [types message-type/c]) (or/c message? #f)]{
    Get a message matching any of the given @racket[types] from @this-obj[]. Will discard all messages on the bus that do not match @racket[types]. Retruns @racket[#f] if the bus is empty or there are no messages that match @racket[types].
  }

  @defmethod[(timed-pop [timeout clock-time?]) (or/c message? #f)]{
    Gets a message from @this-obj[], waiting up to the specified @racket[timeout]. If @racket[timeout] is @racket[clock-time-none], this method will block until a message was posted on the bus. Returns @racket[#f] if the bus is empty after the @racket[timeout] expired.
  }

  @defmethod[(timed-pop-filtered [timeout clock-time?] [types message-type/c]) (or/c message? #f)]{
    Gets a message from @this-obj[] whose type matches one of the message types in @racket[types], waiting up to the specified @racket[timeout] and discarding any messages that do not match the mask provided.

    If @racket[timeout] is 0, this method behaves like @method[bus% pop-filtered]. If @racket[timeout] is @racket[clock-time-none], this method will block until a matching message was posted on the bus. Returns @racket[#f] if no matching message was found on the bus after the @racket[timeout] expired.
  }

  @defmethod[(disable-sync-message-emission!) void?]{
    Instructs GStreamer to stop emitting the @racket['sync-message] @tech{signal} for @this-obj[]. See @method[bus% enable-sync-message-emission!] for more information.
  }

  @defmethod[(enable-sync-message-emission!) void?]{
    Instructs GStreamer to emit the @racket['sync-message] @tech{signal} after running @this-obj[]'s sync handler. Use @racket[connect] on @this-obj[] to listen for this signal.
  }

  @defmethod[(poll [events message-type/c] [timeout clock-time?]) (or/c message? #f)]{
    Poll @this-obj[] for messages. Will block while waiting for messages to come. Specify a maximum time to poll with @racket[timeout]. If @racket[timeout] is negative, this method will block indefinitely.

    GStreamer calls this function ``pure evil''. Prefer @method[bus% timed-pop-filtered] and @racket[make-bus-channel].
  }

  @defproc[(make-bus-channel [bus (is-a?/c bus%)] [filter message-type/c '(any)]
            [#:timeout timeout clock-time? clock-time-none])
            (evt/c (or/c message? false/c (evt/c exact-integer?)))]{
    This procedure polls @racket[bus] asynchronously using @method[bus% timed-pop-filtered] (the @racket[filter] and @racket[timeout] arguments are forwarded on to that method) and returns a @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{synchronizable event}.

    That event is @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{ready for synchronization} when a new message is emitted from the @racket[bus] (in which case the @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{synchronization result} is a @tech{message}), when the @racket[timeout] has been reached (in which case the synchronization result will be a message or @racket[#f]), or when the @racket[bus] has flushed and closed down (in which case the synchronization result is another event that is always ready for synchronization).
  }
}

@section{Messages}

A @deftech{message} is a small structure representing signals emitted from a pipeline and passed to the application using the @tech{bus}. Messages have a @racket[message-type] useful for taking different actions depending on the type.

@defproc[(message? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a message emitted from a bus, @racket[#f] otherwise.
}

@defproc[(message-type [message message?]) message-type/c]{
  Gets the type of @racket[message].
}

@defproc[(message-seqnum [message message?]) exact-integer?]{
  Retrieve the sequence number of @racket[message].

  Messages have ever-incrementing sequence numbers. Sequence numbers are typically used to indicate that a message corresponds to some other set of messages or events.
}

@defproc[(message-src [message message?]) (is-a?/c gst-object%)]{
  Get the object that posted @racket[message].
}

@defproc[(message-of-type? [message message?] [type symbol?] ...+)
         (or/c message-type/c #f)]{
  Checks if the type of @racket[message] is one of the given @racket[type]s. Returns @racket[#f] if the @racket[message-type] of @racket[message] is not one of the given @racket[type]s.
}

@defproc[(eos-message? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @racket[message?] and has the @racket[message-type] of @racket['eos], otherwise @racket[#f].
}

@defproc[(error-message? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @racket[message?] and has the @racket[message-type] of @racket['error], otherwise @racket[#f].
}

@defproc[(fatal-message? [v any/c]) boolean?
         #:value (or (eos-message? v) (error-message? v))]{
  Returns @racket[#t] if @racket[v] is a @racket[message?] and has a @racket[message-type] indicating that the pipeline that emitted this message should shut down (either a @racket['eos] or @racket['error] message), otherwise @racket[#f].
}

@defthing[message-type/c list-contract?]{
  A contract matching a list of allowed message types.
}
