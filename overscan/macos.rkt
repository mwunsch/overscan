#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer)

(provide (contract-out [audio-sources
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
                        (->* (exact-nonnegative-integer?)
                             (#:capture-cursor boolean?
                              #:capture-clicks boolean?)
                             source?)]
                       [osxvideosink
                        (->* ()
                             ((or/c string? false/c))
                             (element/c "osxvideosink"))]))

(unless (gst-initialized?)
  (error "GStreamer must be initialized"))

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

(define (osxvideosink [name #f])
  (element-factory%-make "osxvideosink" name))
