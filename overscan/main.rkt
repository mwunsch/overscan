#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         racket/list
         racket/file
         (only-in racket/function thunk)
         gstreamer
         "video.rkt"
         overscan/twitch)

(provide broadcast
         (contract-out [make-broadcast
                        (->* ((is-a?/c element%)
                              (is-a?/c element%)
                              (is-a?/c element%))
                             (#:name (or/c string? false/c)
                              #:resolution video-resolution/c
                              #:preview (is-a?/c element%)
                              #:monitor (is-a?/c element%)
                              #:h264-encoder (is-a?/c element%)
                              #:aac-encoder (is-a?/c element%))
                             (or/c (is-a?/c pipeline%) false/c))]
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

(define broadcast
  (make-keyword-procedure
   (lambda (kws kw-args . rest)
     (define defaults (list (videotestsrc #:live? #t)
                            (audiotestsrc #:live? #t)
                            (filesink (make-temporary-file))))

     (let ([pipeline (keyword-apply make-broadcast kws kw-args
                                    (take (append rest (list-tail defaults (length rest))) 3))])
       (unless pipeline
         (error "Could not construct pipeline"))
       (start pipeline)
       pipeline))))

(define (make-broadcast video-source audio-source mux-sink
                        #:name [name #f]
                        #:resolution [resolution '720p]
                        #:preview [video-preview (element-factory%-make "autovideosink")]
                        #:monitor [audio-monitor (element-factory%-make "autoaudiosink")]
                        #:h264-encoder [video-encoder (element-factory%-make "x264enc")]
                        #:aac-encoder [audio-encoder (element-factory%-make "fdkaacenc")])
  (let* ([pipeline (pipeline%-new name)]
         [pipeline-name (send pipeline get-name)]
         [multiqueue (element-factory%-make "multiqueue" (format "~a:buffer" pipeline-name))]
         [video-tee (tee (format "~a:video:tee" pipeline-name))]
         [audio-tee (tee (format "~a:audio:tee" pipeline-name))]
         [preview-bin (make-video-preview pipeline-name video-preview)]
         [monitor-bin (make-audio-monitor pipeline-name audio-monitor)]
         [h264-queue (bin%-compose (format "~a:video:encoding" pipeline-name)
                                   (element-factory%-make "queue")
                                   video-encoder)]
         [aac-queue (bin%-compose (format "~a:audio:encoding" pipeline-name)
                                  (element-factory%-make "queue")
                                  audio-encoder)]
         [muxer (element-factory%-make "flvmux"
                                       (format "~a:muxer" pipeline-name))])
    (gobject-set! muxer "streamable" #t)
    (gobject-set! muxer "latency" 1000000000)  ; increased latency helps sync audio/video sources
    (and (send pipeline add-many video-source audio-source)
         (send pipeline add-many video-tee audio-tee)
         (send pipeline add multiqueue)
         (send pipeline add-many h264-queue aac-queue)
         (send pipeline add muxer)
         (send pipeline add mux-sink)
         (send pipeline add-many preview-bin monitor-bin)
         (send video-source link-filtered multiqueue (video-resolution resolution))
         (send audio-source link multiqueue)
         (send multiqueue link video-tee)
         (send multiqueue link audio-tee)
         (send video-tee link h264-queue)
         (send h264-queue link muxer)
         (send audio-tee link aac-queue)
         (send aac-queue link muxer)
         (send muxer link mux-sink)
         (send video-tee link preview-bin)
         (send audio-tee link monitor-bin)
         pipeline)))

(define (make-video-preview pipeline-name preview)
  (let ([queue (element-factory%-make "queue")])
    (gobject-set! queue "leaky" 'upstream '(no upstream downstream))
    (gobject-set! preview "sync" #f)
    (bin%-compose (format "~a:video:preview" pipeline-name)
                  queue
                  (element-factory%-make "videoconvert")
                  preview)))

(define (make-audio-monitor pipeline-name monitor)
  (let ([queue (element-factory%-make "queue")])
    (gobject-set! queue "leaky" 'upstream '(no upstream downstream))
    (gobject-set! monitor "sync" #f)
    (bin%-compose (format "~a:audio:monitor" pipeline-name)
                  queue
                  monitor)))

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
