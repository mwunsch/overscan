#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         ffi/unsafe/define
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
                       [cairo-overlay%
                        (subclass?/c element%)]
                       [make-cairo-overlay
                        (->* ((is-a?/c bitmap-dc%))
                             ((or/c string? false/c))
                             (is-a?/c cairo-overlay%))]))

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

(define-cstruct _overlay-state ([surface (_or-null _cairo_surface_t)]
                                [video-info _video-info-pointer/null])
  #:malloc-mode 'atomic-interior)

(define cairo-overlay%
  (class element%
    (super-new)
    (inherit-field pointer)
    (init-field dc)

    (define target
      (send dc get-bitmap))

    (define surface
      (and target
           (send target get-handle)))

    (define draw-signal
      (connect pointer 'draw (lambda (overlay ptr timestamp duration data)
                               (let ([cr (cast ptr _pointer _cairo_t)])
                                 (cairo_set_source_surface cr data 0.0 0.0)
                                 (cairo_paint cr)))
               #:data surface
               #:cast _cairo_surface_t))

    (define/public (get-dc)
      dc)))

(define (make-cairo-overlay dc
                            [name #f])
  (let ([el (gst-element-factory 'make "cairooverlay" name)])
    (and el
         (new cairo-overlay% [pointer el] [dc dc]))))

(module+ main
  (require gstreamer/event)
  (gst-initialize)

  (define overlay
    (make-cairo-overlay (new bitmap-dc% [bitmap (make-bitmap 320 240)])))

  (define pipe (pipeline%-compose #f
                                  (videotestsrc #:live? #t #:pattern 'ball)
                                  overlay
                                  (element-factory%-make "videoconvert")
                                  (make-gui-sink)))

  (define (start)
    (send pipe set-state 'playing))

  (define (stop)
    (send pipe send-event (make-eos-event))))
