#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function thunk)
         gstreamer
         "video.rkt"
         overscan/twitch)

(provide (contract-out [broadcast
                        (->* ()
                             ((is-a?/c element%)
                              (is-a?/c element%)
                              (is-a?/c element%)
                              #:resolution video-resolution/c
                              #:monitor (is-a?/c element%))
                             (is-a?/c pipeline%))]
                       [start
                        (-> (is-a?/c pipeline%) thread?)]
                       [stop
                        (->* ()
                             (#:timeout exact-nonnegative-integer?)
                             state-change-return?)]
                       [kill-broadcast
                        (-> void?)]
                       [add-listener
                        (-> (-> message? (is-a?/c pipeline%) any)
                            exact-nonnegative-integer?)]
                       [remove-listener
                        (-> exact-nonnegative-integer? void?)]
                       [playing?
                        (->* ()
                             ((is-a?/c pipeline%))
                             boolean?)]
                       [stopped?
                        (->* ()
                             ((is-a?/c pipeline%))
                             boolean?)]
                       [on-air?
                        (-> boolean?)]
                       [graphviz
                        (->* (path-string?)
                             ((is-a?/c pipeline%))
                             any)])
         (all-from-out racket/base
                       racket/class
                       gstreamer
                       "video.rkt"
                       overscan/twitch))


(unless (gst-initialized?)
  (if (gst-initialize)
      (displayln (gst-version-string))
      (error "Could not load GStreamer")))

(define overscan-logger
  (make-logger 'Overscan (current-logger)))

(define current-broadcast
  (box #f))

(define broadcast-complete-evt
  (make-semaphore))

(define (default-broadcast-listener msg broadcast)
  (when (fatal-message? msg)
    (send broadcast set-state 'null)))

(define (log-listener msg broadcast)
  (let ([msg-type (message-type msg)]
        [msg-description (message->string msg)])
    (case msg-type
      ['(warning) (log-warning msg-description)]
      ['(error) (log-error msg-description)]
      [else (log-info msg-description)])))

(define broadcast-listeners
  (make-hash (list (cons 0 default-broadcast-listener)
                   (cons 1 log-listener))))

(define (add-listener proc)
  (let* ([stack broadcast-listeners]
         [key (hash-count stack)])
    (hash-set! stack key proc)
    key))

(define (remove-listener key)
  (hash-remove! broadcast-listeners key))

(define (broadcast [video-source (videotestsrc #:live? #t)]
                   [audio-source (gobject-with-properties (element-factory%-make "audiotestsrc")
                                                          (hash 'volume 0.5))]
                   [sink (element-factory%-make "fakesink")]
                   #:resolution [resolution '720p]
                   #:monitor [audio-monitor (element-factory%-make "fakesink")]
                   #:h264-encoder [video-encoder (element-factory%-make "x264enc")]
                   #:aac-encoder [audio-encoder (element-factory%-make "fdkaacenc")])
  (let ([pipeline (pipeline%-new #f)]
        [resolution-caps (video-resolution resolution)]
        [unsynced-sink (gobject-with-properties sink
                                                (hash 'sync #f))])
    (and (send pipeline add-many video-source audio-source)
         (send pipeline add-many video-encoder audio-encoder)
         (send pipeline add-many audio-monitor sink)
         (send video-source link-filtered sink resolution-caps)
         (send audio-source link audio-monitor)

         (start pipeline)
         pipeline)))

(define (start pipeline)
  (when (unbox current-broadcast)
    (error "Already a broadcast in progress"))
  (set-box! current-broadcast pipeline)
  (send pipeline set-state 'playing)
  (spawn-bus-worker pipeline))

(define (stop #:timeout [timeout 5])
  (define broadcast (get-current-broadcast))
  (send broadcast send-event (make-eos-event))
  (if (sync/timeout timeout broadcast-complete-evt)
      (begin
        (send broadcast set-state 'null)
        (let-values ([(result current pending) (send broadcast get-state)])
          (set-box! current-broadcast #f)
          result))
      (error "Could not stop broadcast")))

(define (kill-broadcast)
  (define broadcast (get-current-broadcast))
  (send broadcast send-event (make-eos-event))
  (semaphore-try-wait? broadcast-complete-evt)
  (send broadcast set-state 'null)
  (set-box! current-broadcast #f))

(define (spawn-bus-worker broadcast)
  (let* ([bus (send broadcast get-bus)]
         [chan (make-bus-channel bus)])
    (parameterize ([current-logger overscan-logger])
        (thread (thunk
              (let loop ()
                (let ([ev (sync chan)])
                  (if (evt? ev)
                      (semaphore-post broadcast-complete-evt)
                      (begin
                        (for ([proc (in-hash-values broadcast-listeners)])
                          (proc ev broadcast))
                        (loop))))))))))

(define (playing? [broadcast (get-current-broadcast)])
  (let-values ([(result current pending) (send broadcast get-state)])
    (and (eq? result 'success)
         (eq? current 'playing))))

(define (stopped? [broadcast (get-current-broadcast)])
  (let-values ([(result current pending) (send broadcast get-state)])
    (eq? current 'null)))

(define (on-air?)
  (and (unbox current-broadcast) #t))

(define (graphviz filepath [broadcast (get-current-broadcast)])
  (call-with-output-file filepath
    (lambda (out)
      (display (bin->dot broadcast) out))))

(define (get-current-broadcast)
  (or (unbox current-broadcast)
      (error "No current broadcast")))

(module reader syntax/module-reader
  overscan)
