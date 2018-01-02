#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         racket/class
         racket/contract
         (only-in racket/string string-join)
         "private/core.rkt"
         gstreamer/gst
         gstreamer/appsink
         gstreamer/caps
         gstreamer/buffer
         gstreamer/element
         gstreamer/elements
         gstreamer/factories
         gstreamer/message
         gstreamer/video)

(provide (contract-out [make-gui-sink
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
