#lang scribble/manual
@require[@for-label[gstreamer
                    racket/base
                    racket/contract
                    racket/class
                    ffi/unsafe/introspection]]

@defclass/title[clock% gst-object% ()]{
  GStreamer uses a global clock to synchronize the different parts of a pipeline. Different clock implementations inherit from @racket[clock%]. The clock returns a monotonically increasing time with @method[clock% get-time]. In GStreamer, time is always expressed in @emph{nanoseconds}.

  @defmethod[(get-time) clock-time?]{
    Gets the current time of @this-obj[]. The time is always monotonically increasing.
  }

  @defproc[(clock-time? [v any/c]) boolean?]{
    Returns @racket[#t] if @racket[v] is a number that can represent the time elapsed in a GStreamer pipeline, @racket[#f] otherwise. All time in GStreamer is expressed in nanoseconds.
  }

  @defthing[clock-time-none clock-time?]{
    An undefined clock time. Often seen used as a timeout for procedures where it implies the procedure should block indefinitely.
  }

  @defproc[(obtain-system-clock) (is-a?/c clock%)]{
    Obtain an instance of @racket[clock%] based on the system time.
  }

  @defproc[(time-as-seconds [time clock-time?]) exact-integer?]{
    Convert @racket[time] to seconds.
  }

  @defproc[(time-as-milliseconds [time clock-time?]) exact-integer?]{
    Convert @racket[time] to milliseconds (@racket[1/1000] of a second).
  }

  @defproc[(time-as-microseconds [time clock-time?]) exact-integer?]{
    Convert @racket[time] to microseconds (@racket[1/1000000] of a second).
  }

  @defproc[(clock-diff [s clock-time?] [e clock-time?]) clock-time?]{
    Calculate a difference between two clock times.
  }
}
