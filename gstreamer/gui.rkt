#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function curry thunk)
         sgl/gl
         gstreamer/gst
         gstreamer/caps
         gstreamer/event
         gstreamer/buffer
         gstreamer/video
         gstreamer/element
         gstreamer/bus
         gstreamer/factories
         gstreamer/elements
         gstreamer/appsink)

(provide (contract-out [make-gui-sink
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c element%))]))

(define gst-gl
  (introspection 'GstGL))

(define (gl-memory? mem)
  ((gst-gl 'is_gl_memory) mem))

(define gl-memory
  (gst-gl 'GLMemory))

(define canvas-sink%
  (class appsink%
    (super-new)
    (inherit-field pointer)
    (init-field [label (gobject-send pointer 'get_name)]
                [window (new frame%
                              [label label])]
                [canvas (new canvas%
                             [parent window]
                             [style '(gl no-autoclear)])])

    (define/public (resize-area width height)
      (define-values (client-width client-height)
        (send window get-client-size))
      (define-values (window-width window-height)
        (send window get-size))
      (unless (and (eq? width client-width)
                   (eq? height client-height))
        (let ([height-delta (- window-height client-height)])
          (send window resize width (+ height-delta height)))))

    (define (draw-gl-texture memory)
      (let ([txid (gl-memory 'get_texture_id (first memory))])
        (send canvas with-gl-context
              (thunk
               (glClearColor 0 0 0 0)
               (glClear GL_COLOR_BUFFER_BIT)))
        (send canvas swap-gl-buffers)))

    (define/augment (on-sample sample)
      (let* ([buffer (sample-buffer sample)]
             [video-meta (buffer-video-meta buffer)]
             [memory (buffer-memory buffer)])
        (when (andmap gl-memory? memory)
          (unless (send window is-shown?)
            (send window show #t))

          (let-values ([(vid-width vid-height)
                        (video-meta-dimensions video-meta)])
            (resize-area vid-width vid-height))

          (draw-gl-texture memory))))

    (define/augment (on-eos)
      (send window show #f))))

(define (make-gui-sink [name #f])
  (let ([sink (make-appsink #f canvas-sink%)])
    (bin%-compose name
                  (capsfilter (string->caps "video/x-raw,format=UYVY"))
                  (element-factory%-make "glupload")
                  sink)))


(module+ main
  (gst-initialize)

  (define sinky (make-gui-sink))

  (define pipe (pipeline%-compose #f
                                  (videotestsrc #:live? #t #:pattern 'ball)
                                  sinky))

  (define (start)
    (send pipe set-state 'playing))

  (define (stop)
    (send pipe send-event (make-eos-event))))
