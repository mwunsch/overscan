#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         racket/place
         (only-in racket/function const)
         "private/core.rkt"
         (only-in gstreamer/gst gst-object%)
         gstreamer/clock
         gstreamer/message)

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
                          (->m message-type/c clock-time? (or/c message? false/c))])]))

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
