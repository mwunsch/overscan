#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         racket/class
         racket/contract
         (only-in racket/string string-join)
         racket/async-channel
         racket/draw/unsafe/cairo
         "private/core.rkt"
         gstreamer/gst
         gstreamer/appsink
         gstreamer/buffer
         gstreamer/caps
         gstreamer/element
         gstreamer/elements
         gstreamer/factories
         gstreamer/video)

(provide (contract-out [make-gui-sink
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c element%))]
                       [draw-overlay
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c element%))]))

(define canvas-sink%
  (class appsink%
    (super-new)
    (inherit-field pointer)
    (inherit set-caps!)
    (init-field [label (gobject-send pointer 'get_name)]
                [window (new frame%
                             [label label])])

    (field [canvas (new canvas%
                        [parent window])])

    (set-caps! (string->caps "video/x-raw,format=ARGB"))

    (define dc
      (send canvas get-dc))

    (define/public (resize-area width height)
      (define-values (client-width client-height)
        (send window get-client-size))
      (define-values (window-width window-height)
        (send window get-size))
      (unless (and (eq? width client-width)
                   (eq? height client-height))
        (let ([height-delta (- window-height client-height)])
          (send window resize width (+ height-delta height)))))

    (define/augment (on-sample sample)
      (let* ([buffer (sample-buffer sample)]
             [caps (sample-caps sample)]
             [vidinfo (caps->video-info caps)]
             [memory (buffer-memory buffer)]
             [width (video-info-width vidinfo)]
             [height (video-info-height vidinfo)]
             [bitmap (make-bitmap width height)])

        (resize-area width height)

        (let* ([mapinfo (buffer-map buffer '(read))]
               [data (map-info-data mapinfo)])
          (send bitmap set-argb-pixels 0 0 width height data)
          (send dc draw-bitmap bitmap 0 0)
          (buffer-unmap! buffer mapinfo))

        (unless (send window is-shown?)
          (send window show #t))))

    (define/augment (on-eos)
      (send window show #f))))

(define (make-gui-sink [name #f])
  (make-appsink name canvas-sink%))

(define (draw-overlay [name #f])
  (let* ([target (make-bitmap 100 100)]
         [dc (new bitmap-dc% [bitmap target])]
         [el (element-factory%-make "cairooverlay" name)]
         [surface (send target get-handle)])
    (connect el 'draw (lambda (overlay ptr timestamp duration data)
                        (let ([cr (cast ptr _pointer _cairo_t)])
                          (cairo_set_source_surface cr data 0.0 0.0)
                          (cairo_paint cr)))
             #:data surface
             #:cast _cairo_surface_t)
    (values dc el)))

(module+ main
  (require gstreamer/event)
  (gst-initialize)

  (define-values (dc overlay)
    (draw-overlay))

  (send dc set-brush "green" 'solid)
  (send dc draw-ellipse 5 5 90 90)

  (define pipe (pipeline%-compose #f
                                  (videotestsrc #:live? #t #:pattern 'ball)
                                  overlay
                                  (element-factory%-make "videoconvert")
                                  (make-gui-sink)))

  (define (start)
    (send pipe set-state 'playing))

  (define (stop)
    (send pipe send-event (make-eos-event))))
