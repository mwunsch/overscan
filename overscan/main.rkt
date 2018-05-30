#lang racket/base

(require (only-in ffi/unsafe _bitmask)
         ffi/unsafe/introspection
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
                       [get-current-broadcast
                        (-> (is-a?/c pipeline%))]
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
                             any)]
                       [overscan-logger
                        logger?])
         (all-from-out racket/base
                       racket/class
                       gstreamer
                       "video.rkt"
                       overscan/twitch))


(unless (gst-initialized?)
  (or (gst-initialize)
      (error "Could not load GStreamer")))

(displayln (gst-version-string))

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
                        #:monitor [audio-monitor (element-factory%-make "fakesink")]
                        #:h264-encoder [video-encoder (x264enc)]
                        #:aac-encoder [audio-encoder (element-factory%-make "fdkaacenc")])
  (let* ([pipeline (pipeline%-new name)]
         [pipeline-name (send pipeline get-name)]
         [video-scale (bin%-compose (format "~a:video:scale+rate" pipeline-name)
                                    (videoscale)
                                    (element-factory%-make "videoconvert")
                                    (element-factory%-make "videorate"))]
         [audio-rate (element-factory%-make "audiorate")]
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
         [multiqueue (gobject-with-properties (element-factory%-make "multiqueue"
                                                                     (format "~a:buffer" pipeline-name))
                                              (hash 'sync-by-running-time #t
                                                    'use-buffering #t))]
         [muxer (element-factory%-make "flvmux"
                                       (format "~a:muxer" pipeline-name))]
         [sink-buffer (element-factory%-make "queue"
                                             (format "~a:sink-buffer" pipeline-name))])
    (gobject-set! muxer "streamable" #t)
    (gobject-set! mux-sink "sync" #t)
    (and (send pipeline add-many video-source audio-source)
         (send pipeline add-many video-scale audio-rate)
         (send pipeline add-many video-tee audio-tee)
         (send pipeline add-many h264-queue aac-queue)
         (send pipeline add multiqueue)
         (send pipeline add-many muxer sink-buffer mux-sink)
         (send pipeline add-many preview-bin monitor-bin)
         (send video-source link-filtered video-scale (string->caps "video/x-raw,pixel-aspect-ratio=1/1"))
         (send video-scale link-filtered video-tee (video-resolution resolution))
         (send video-tee link preview-bin)
         (send video-tee link h264-queue)
         (send h264-queue link multiqueue)
         (send multiqueue link muxer)
         (send audio-source link-filtered audio-rate (string->caps "audio/x-raw"))
         (send audio-rate link audio-tee)
         (send audio-tee link monitor-bin)
         (send audio-tee link aac-queue)
         (send aac-queue link multiqueue)
         (send multiqueue link muxer)
         (send muxer link sink-buffer)
         (send sink-buffer link mux-sink)
         pipeline)))

(define (x264enc)
  (let ([enc (element-factory%-make "x264enc")])
    (gobject-set! enc "tune" 'zerolatency (_bitmask '(stillimage
                                                      fastdecode
                                                      zerolatency)))
    (gobject-set! enc "speed-preset" 'veryfast '(none
                                                 ultrafast
                                                 superfast
                                                 veryfast
                                                 faster
                                                 fast
                                                 medium
                                                 slow
                                                 slower
                                                 veryslow
                                                 placebo))
    (gobject-set! enc "key-int-max" 60)
    enc))

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
  (parameterize ([current-logger overscan-logger])
    (spawn-bus-worker pipeline)))

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
    (thread (thunk
             (let loop ()
               (let ([ev (sync chan)])
                 (if (evt? ev)
                     (semaphore-post broadcast-complete-evt)
                     (begin
                       (for ([proc (in-hash-values broadcast-listeners)])
                         (proc ev broadcast))
                       (loop)))))))))

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
