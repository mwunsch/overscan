#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         racket/place
         (only-in racket/function const thunk curry curryr)
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
                        list-contract?]
                       [message/c
                        (-> symbol? flat-contract?)]
                       [parse-message:error
                        (-> message? any)]
                       [parse-message:warning
                        (-> message? any)]
                       [parse-message:info
                        (-> message? any)]
                       [parse-message:tag
                        (-> message? any)]
                       [parse-message:buffering
                        (-> message? number?)]
                       [parse-message:buffering-stats
                        (-> message? any)]
                       [parse-message:state-changed
                        (-> message? (values symbol?
                                             symbol?
                                             symbol?))]
                       [parse-message:step-done
                        (-> message? (values symbol?
                                             exact-integer?
                                             number?
                                             boolean?
                                             boolean?
                                             exact-integer?
                                             boolean?))]
                       [parse-message:new-clock
                        (-> message? any/c)]
                       [parse-message:async-done
                        (-> message? clock-time?)]
                       [parse-message:qos
                        (-> message? (values boolean?
                                             exact-integer?
                                             exact-integer?
                                             exact-integer?
                                             exact-integer?))]
                       [parse-message:qos-values
                        (-> message? (values exact-integer?
                                             number?
                                             exact-integer?))]
                       [parse-message:qos-stats
                        (-> message? (values symbol?
                                             exact-integer?
                                             exact-integer?))]
                       [parse-message:context-type
                        (-> message? (values boolean?
                                             any/c))]
                       [parse-message:have-context
                        (-> message? any/c)]))

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

(define (message/c type)
  (flat-named-contract `(message/c ',type)
                       (and/c message?
                              (curryr message-of-type? type))))

(define (make-parse-msg-proc parsefn)
  (lambda (msg) (call-with-values (thunk (gobject-send msg parsefn))
                             (compose1 (curry apply values)
                                       cdr
                                       list))))

(define parse-message:error
  (make-parse-msg-proc 'parse_error))

(define parse-message:warning
  (make-parse-msg-proc 'parse_warning))

(define parse-message:info
  (make-parse-msg-proc 'parse_info))

(define parse-message:tag
  (make-parse-msg-proc 'parse_tag))

(define parse-message:buffering
  (make-parse-msg-proc 'parse_buffering))

(define parse-message:buffering-stats
  (make-parse-msg-proc 'parse_buffering_stats))

(define parse-message:state-changed
  (make-parse-msg-proc 'parse_state_changed))

(define parse-message:step-done
  (make-parse-msg-proc 'parse_step_done))

(define parse-message:new-clock
  (make-parse-msg-proc 'parse_new_clock))

(define parse-message:async-done
  (make-parse-msg-proc 'parse_async_done))

(define parse-message:qos
  (make-parse-msg-proc 'parse_qos))

(define parse-message:qos-values
  (make-parse-msg-proc 'parse_qos_values))

(define parse-message:qos-stats
  (make-parse-msg-proc 'parse_qos_stats))

(define (parse-message:context-type msg)
  (gobject-send msg 'parse_context_type))

(define parse-message:have-context
  (make-parse-msg-proc 'parse_have_context))

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
