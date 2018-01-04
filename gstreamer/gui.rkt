#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         ffi/unsafe/define
         racket/class
         racket/contract
         (only-in racket/string string-join)
         racket/async-channel
         racket/draw/unsafe/cairo-lib
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
                       ))

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

(define-ffi-definer define-cairo cairo-lib)

(define-cairo cairo_surface_reference
  (_fun _cairo_surface_t ~> _cairo_surface_t))

(define-cairo cairo_surface_destroy
  (_fun _cairo_surface_t ~> _void))

(define-cairo cairo_surface_get_reference_count
  (_fun _cairo_surface_t ~> _uint))

(define-cstruct _cairo-bitmap ([surface _cairo_surface_t]))

(define cairo-overlay%
  (class element%
    (super-new)
    (inherit-field pointer)
    (init-field [dc (new bitmap-dc% [bitmap (make-bitmap 320 240)])])

    (define target
      (send dc get-bitmap))

    (define surface
      (send target get-handle))

    (define bitmap
      (make-cairo-bitmap surface))

    ;; (define caps-changed
    ;;   (make-async-channel))

    ;; (define caps-worker
    ;;   (thread (thunk
    ;;            (let loop ()
    ;;              (let* ([changed? (async-channel-get caps-changed)]
    ;;                     [width (cairo-bitmap-width bitmap)]
    ;;                     [height (cairo-bitmap-height bitmap)])
    ;;                (displayln (format "Caps changed: ~a x ~a" width height))
    ;;                (set! dc-bitmap (make-bitmap width height))
    ;;                (send dc set-bitmap dc-bitmap)
    ;;                (set-cairo-bitmap-surface! bitmap (send dc-bitmap get-handle))
    ;;                (loop))))))

    ;; (define caps-changed-signal
    ;;   (connect pointer 'caps-changed (lambda (overlay caps data)
    ;;                                    (let* ([vidinfo (caps->video-info caps)]
    ;;                                           [width (video-info-width vidinfo)]
    ;;                                           [height (video-info-height vidinfo)])
    ;;                                      (set-cairo-bitmap-width! data width)
    ;;                                      (set-cairo-bitmap-height! data height)
    ;;                                      data))
    ;;            #:data bitmap
    ;;            #:cast _cairo-bitmap-pointer
    ;;            #:channel caps-changed))

    (define draw-signal
      (connect pointer 'draw (lambda (overlay ptr timestamp duration data)
                               (let ([cr (cast ptr _pointer _cairo_t)]
                                     [surface (cairo-bitmap-surface data)])
                                 (cairo_set_source_surface cr surface 0.0 0.0)
                                 (cairo_paint cr)))
               #:data bitmap
               #:cast _cairo-bitmap))

    (define/public (get-dc)
      dc)

    (define/public (get-bitmap-state)
      bitmap)))

(module+ main
  (require gstreamer/event)
  (gst-initialize)

  (define overlay
    (element-factory%-make "cairooverlay" #:class cairo-overlay%))

  (define pipe (pipeline%-compose #f
                                  (videotestsrc #:live? #t #:pattern 'ball)
                                  ;; overlay
                                  overlay
                                  (element-factory%-make "videoconvert")
                                  (make-gui-sink)))

  (define (start)
    (send pipe set-state 'playing))

  (define (stop)
    (send pipe send-event (make-eos-event))))
