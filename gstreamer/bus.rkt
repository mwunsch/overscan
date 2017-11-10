#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         racket/place
         (only-in racket/function const thunk)
         gstreamer/gst
         gstreamer/clock)

(provide (contract-out [make-bus-channel
                        (->* ((gobject/c gst-bus))
                             (message-type/c
                              #:timeout clock-time?)
                             (evt/c (or/c message?
                                          false/c
                                          (evt/c exact-integer?))))]
                       [bus%
                        (class/c
                         [post
                          (->m message? boolean?)]
                         [have-pending?
                          (->m boolean?)]
                         [peek
                          (->m (or/c message? false/c))]
                         [pop
                          (->m (or/c message? false/c))]
                         [pop-filtered
                          (->m message-type/c (or/c message? false/c))]
                         [timed-pop
                          (->m clock-time? (or/c message? false/c))]
                         [timed-pop-filtered
                          (->m clock-time? message-type/c (or/c message? false/c))]
                         [disable-sync-message-emission!
                          (->m void?)]
                         [enable-sync-message-emission!
                          (->m void?)]
                         [poll
                          (->m message-type/c clock-time? (or/c message? false/c))])]
                       [message?
                        (-> any/c boolean?)]
                       [message-type
                        (-> message? message-type/c)]
                       [message-seqnum
                        (-> message? exact-integer?)]
                       [message-src
                        (-> message? (is-a?/c gst-object%))]
                       [message-of-type?
                        (-> message? symbol? symbol? ...
                            (or/c message-type/c false/c))]
                       [eos-message?
                        (-> any/c boolean?)]
                       [error-message?
                        (-> any/c boolean?)]
                       [fatal-message?
                        (-> any/c boolean?)]
                       [message-type/c
                        list-contract?]))

(define gst-bus (gst 'Bus))

(define bus-mixin
  (make-gobject-delegate post
                         [have-pending? 'have_pending]
                         peek
                         pop
                         pop-filtered
                         timed-pop
                         timed-pop-filtered
                         [disable-sync-message-emission!
                          'disable_sync_message_emission]
                         [enable-sync-message-emission!
                          'enable_sync_message_emission]
                         poll))

(define bus%
  (class (bus-mixin gst-object%)
    (super-new)
    (inherit-field pointer)))

(define gst-message (gst 'Message))

(define gst-message-type (gst 'MessageType))

(define message-type/c
  (gi-bitmask-value/c gst-message-type))

(define (message? v)
  (is-gtype? v gst-message))

(define (message-type msg)
  (gobject-get-field 'type msg))

(define (message-seqnum msg)
  (gobject-get-field 'seqnum msg))

(define (message-src msg)
  (new gst-object% [pointer (gobject-get-field 'src msg)]))

(define (message-of-type? msg type_1 . types)
  ;; TODO: Investigate if this works with its stated contract
  (memf (apply symbols type_1 types) (message-type msg)))

(define (eos-message? v)
  (and (message? v)
       (message-of-type? v 'eos)
       #t))

(define (error-message? v)
  (and (message? v)
       (message-of-type? v 'error)
       #t))

(define (fatal-message? v)
  (or (eos-message? v)
      (error-message? v)))

(define (make-bus-channel bus [filters '(any)]
                          #:timeout [timeout clock-time-none])
  (let* ([bus-pipe (spawn-bus-place)]
         [bus-dead? (place-dead-evt bus-pipe)])
    (place-channel-put bus-pipe (list (gi-instance-pointer (gobject-ptr bus))
                                      timeout
                                      filters))
    (choice-evt (wrap-evt bus-pipe
                          (lambda (ptr) (and ptr (gstruct-cast ptr gst-message))))
                (handle-evt bus-dead?
                            (lambda (ev) (wrap-evt ev (const (place-wait bus-pipe))))))))

(define (spawn-bus-place)
  (place chan
         (let*-values ([(bus-ptr timeout filter)
                        (apply values (place-channel-get chan))]
                       [(bus-obj) (gobject-cast bus-ptr gst-bus)])
           (let loop ()
             (define msg
               (gobject-send bus-obj 'timed_pop_filtered timeout filter))
             (place-channel-put chan (and msg
                                          (gi-instance-pointer msg)))
             (when (fatal-message? msg)
               (exit 0))
             (loop)))))
