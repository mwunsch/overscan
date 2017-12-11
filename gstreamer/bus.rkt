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
                       [make-message:need-context
                        (-> (is-a?/c gst-object%) string? message?)]
                       [message-type/c
                        list-contract?]
                       [message/c
                        (-> symbol? flat-contract?)]
                       [parse-message:error
                        (-> error-message? any)]
                       [parse-message:warning
                        (-> (message/c 'warning) any)]
                       [parse-message:info
                        (-> (message/c 'info) any)]
                       [parse-message:tag
                        (-> (message/c 'tag)
                            (is-gtype?/c (gst 'TagList)))]
                       [parse-message:buffering
                        (-> (message/c 'buffering) exact-nonnegative-integer?)]
                       [parse-message:buffering-stats
                        (-> (message/c 'buffering)
                            (values (or/c (gi-enum-value/c (gst 'BufferingMode)) #f)
                                    (or/c exact-integer? #f)
                                    (or/c exact-integer? #f)
                                    (or/c exact-nonnegative-integer? #f)))]
                       [parse-message:state-changed
                        (-> (message/c 'state-changed)
                            (values (or/c (gi-enum-value/c (gst 'State)) #f)
                                    (or/c (gi-enum-value/c (gst 'State)) #f)
                                    (or/c (gi-enum-value/c (gst 'State)) #f)))]
                       [parse-message:step-done
                        (-> (message/c 'step-done)
                            (values (gi-enum-value/c (gst 'Format))
                                    exact-integer?
                                    real?
                                    boolean?
                                    boolean?
                                    exact-integer?
                                    boolean?))]
                       [parse-message:new-clock
                        (-> (message/c 'new-clock)
                            (is-gtype?/c (gst 'Clock)))]
                       [parse-message:stream-status
                        (-> (message/c 'stream-status)
                            (values (gi-enum-value/c (gst 'StreamStatusType))
                                    (is-gtype?/c (gst 'Element))))]
                       [parse-message:async-done
                        (-> (message/c 'async-done)
                            clock-time?)]
                       [parse-message:qos
                        (-> (message/c 'qos)
                            (values boolean?
                                    exact-integer?
                                    exact-integer?
                                    exact-integer?
                                    exact-integer?))]
                       [parse-message:qos-values
                        (-> (message/c 'qos)
                            (values exact-integer?
                                    real?
                                    exact-integer?))]
                       [parse-message:qos-stats
                        (-> (message/c 'qos)
                            (values (gi-enum-value/c (gst 'Format))
                                    exact-integer?
                                    exact-integer?))]
                       [parse-message:context-type
                        (-> (message/c 'need-context)
                            (values boolean?
                                    (or/c string? #f)))]
                       [parse-message:have-context
                        (-> (message/c 'have-context)
                            (is-gtype?/c (gst 'Context)))]))

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

(define (make-message:need-context src context-type)
  (gst-message 'new_need_context src context-type))

(define (message/c type)
  (flat-named-contract `(message/c ',type)
                       (and/c message?
                              (curryr message-of-type? type))))

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

(define parse-message:stream-status
  (make-parse-msg-proc 'parse_stream_status))

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
