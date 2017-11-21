#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function thunk)
         gstreamer
         overscan/twitch)

(provide (contract-out [broadcast
                        (->* ()
                             (source? sink?)
                             (is-a?/c pipeline%))]
                       [start
                        (-> (is-a?/c pipeline%) thread?)]
                       [stop
                        (->* ()
                             (#:timeout exact-nonnegative-integer?)
                             (gi-enum-value/c state-change-return))]
                       [kill-broadcast
                        (-> void?)]
                       [add-listener
                        (-> (-> message? (is-a?/c pipeline%) any) exact-nonnegative-integer?)]
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
                       [audio-sources
                        (vectorof (is-a?/c device%))]
                       [audio
                        (-> exact-nonnegative-integer? source?)]
                       [camera-sources
                        (vectorof (-> source?))]
                       [camera
                        (-> exact-nonnegative-integer? source?)]
                       [screen-sources
                        (vectorof (-> source?))]
                       [screen
                        (-> exact-nonnegative-integer? source?)])
         (all-from-out racket/base
                       gstreamer
                       overscan/twitch))


(unless (gst-initialized?)
  (if (gst-initialize)
      (displayln (gst-version-string))
      (error "Could not load GStreamer")))

(define audio-sources
  (let ([monitor (device-monitor%-new)])
    (if (positive? (send monitor add-filter "Audio/Source" #f))
        (for/vector ([device (send monitor get-devices)]
                     [i (in-naturals)])
          (displayln (format "Audio Device ~a: ~a" i (send device get-display-name)))
          device)
        (and (displayln "No Audio Devices detected.")
             (vector)))))

(define (audio ref)
  (let ([device (vector-ref audio-sources ref)])
    (send device create-element)))

;;; TODO: Abstract avfvideosrc specifics out
(define camera-sources
  (let* ([factory (element-factory%-find "avfvideosrc")]
         [test-el (send factory create)])
    (define (source-exists? ref)
      (gobject-set! test-el "device-index" ref)
      (and (eq? 'success (send test-el set-state 'ready))
           (send test-el set-state 'null)
           ref))
    (for/vector ([i (in-naturals)]
                 #:break (not (source-exists? i)))
      (displayln (format "Camera ~a: ~a" i (hash-ref (send factory get-metadata)
                                                     'long-name)))
      (lambda () (gobject-with-properties (send factory create)
                                     (hash 'device-index i))))))

(define screen-sources
  (let* ([factory (element-factory%-find "avfvideosrc")]
         [test-el (send factory create)])
    (define (source-exists? ref)
      (gobject-set! test-el "capture-screen" #t)
      (gobject-set! test-el "device-index" ref)
      (and (eq? 'success (send test-el set-state 'ready))
           (send test-el set-state 'null)
           ref))
    (for/vector ([i (in-naturals)]
                 #:break (not (source-exists? i)))
      (displayln (format "Screen Capture ~a: ~a" i (hash-ref (send factory get-metadata)
                                                     'long-name)))
      (lambda () (gobject-with-properties (send factory create)
                                     (hash 'capture-screen #t
                                           'device-index i))))))

(define (camera ref)
  (let ([device (vector-ref camera-sources ref)])
    (device)))

(define (screen ref
                #:capture-cursor [cursor? #f]
                #:capture-clicks [clicks? #f])
  (let ([device (vector-ref screen-sources ref)])
    (gobject-with-properties (device)
                             (hash 'capture-screen-cursor cursor?
                                   'capture-screen-mouse-clicks clicks?))))

(define current-broadcast
  (box #f))

(define broadcast-complete-evt
  (make-semaphore))

(define (default-broadcast-listener msg broadcast)
  (when (fatal-message? msg)
    (send broadcast set-state 'null)))

(define broadcast-listeners
  (make-hash (list (cons 0 default-broadcast-listener))))

(define (broadcast [source (videotestsrc #:live? #t)]
                   [sink (element-factory%-make "fakesink")])
  (let ([pipeline (pipeline%-new #f)])
    (and (send pipeline add source)
         (send pipeline add sink)
         (send source link sink)
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
      (let-values ([(result current pending) (send broadcast get-state)])
        (set-box! current-broadcast #f)
        result)
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

(define (add-listener proc)
  (let* ([stack broadcast-listeners]
         [key (hash-count stack)])
    (hash-set! stack key proc)
    key))

(define (remove-listener key)
  (hash-remove! broadcast-listeners key))

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
