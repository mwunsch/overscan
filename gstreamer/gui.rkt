#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         ffi/unsafe/define
         racket/class
         racket/contract
         (only-in racket/string string-join)
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
                       [video-overlay%
                        (and/c (subclass?/c element%)
                               (class/c
                                (init-field
                                 [window (is-a?/c window<%>)])
                                [get-window
                                 (->m (is-a?/c window<%>))]))]))

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

(define video-overlay%
  (class element%
    (super-new)
    (inherit-field pointer)
    (init-field [window (new frame%
                             [label (gobject-send pointer 'get_name)]
                             [width 640]
                             [height 480])])

    (define/public (get-window)
      window)

    (when window
      (video-overlay-set-window-handle! pointer
                                        (send window get-client-handle)))))
