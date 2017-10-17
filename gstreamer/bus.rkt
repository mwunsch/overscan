#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         racket/place
         gstreamer/gst
         gstreamer/clock)

(provide (contract-out [make-bus-channel
                        (->* ((gobject/c gst-bus))
                             (message-type/c
                              #:timeout clock-time?)
                             (evt/c (or/c message?
                                          false/c
                                          evt?)))]
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
                       [message-src
                        (-> message? (is-a?/c gst-object%))]
                       [message-seqnum
                        (-> message? exact-integer?)]
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

(define (make-bus-channel bus [filters '(any)]
                          #:timeout [timeout clock-time-none])
  (define bus-pipe
    (place chan
           (let*-values ([(bus-ptr timeout filter)
                          (apply values (place-channel-get chan))]
                         [(bus-obj) (gobject-cast bus-ptr gst-bus)])
             (let loop ()
               (define msg
                 (gobject-send bus-obj 'timed_pop_filtered timeout filter))
               (define msg-type
                 (message-type msg))
               (place-channel-put chan (and msg
                                            (gtype-instance-pointer msg)))
               (when (and msg
                          (or (memq 'eos msg-type) (memq 'error msg-type)))
                 (exit 0))
               (loop)))))
  (place-channel-put bus-pipe (list (gtype-instance-pointer (gobject-ptr bus))
                                    timeout
                                    filters))
  (choice-evt (wrap-evt bus-pipe
                        (lambda (ptr) (and ptr (gstruct-cast ptr gst-message))))
              (place-dead-evt bus-pipe)))
