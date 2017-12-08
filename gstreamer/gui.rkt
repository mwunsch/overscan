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

(define gst-glmemory
  (gst-gl 'GLMemory))

(define gst-glcontext
  (gst-gl 'GLContext))

(define gst-glcontext%
  (class gst-object%
    (super-new)
    (inherit-field pointer)))

(define glcanvas%
  (class canvas%
    (inherit refresh with-gl-context swap-gl-buffers)
    (super-new [style '(gl no-autoclear)])

    (define/public (get-gl-context-handle)
      (with-gl-context
        (thunk
         (send (get-current-gl-context) get-handle))))

    (define/override (on-size width height)
      (with-gl-context
        (thunk
         (glViewport 0 0 width height)
         (glMatrixMode GL_PROJECTION)
         (glLoadIdentity)
         (glOrtho 0 width 0 height -1 1)
         (glMatrixMode GL_MODELVIEW)))
      (refresh))))

(define canvas-sink%
  (class appsink%
    (super-new)
    (inherit-field pointer)
    (init-field [label (gobject-send pointer 'get_name)]
                [window (new frame%
                             [label label])])

    (field [canvas (new glcanvas%
                        [parent window])])

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
      (let* ([plane (first memory)]
             [txid (gst-glmemory 'get_texture_id plane)])
        (send canvas with-gl-context
              (thunk
               (glClearColor 0 0 0 0)
               (glClear GL_COLOR_BUFFER_BIT)

               (glMatrixMode GL_PROJECTION)
               (glLoadIdentity)

               (glEnable GL_TEXTURE_2D)
               (glBindTexture GL_TEXTURE_2D txid)

               (glBegin GL_QUADS)
               (glTexCoord2f 0.0 0.0)
               (glVertex2f -1.0 -1.0)

               (glTexCoord2f 0.0 1.0)
               (glVertex2f -1.0 1.0)

               (glTexCoord2f 1.0 1.0)
               (glVertex2f 1.0 1.0)

               (glTexCoord2f 1.0 0.0)
               (glVertex2f 1.0 -1.0)
               (glEnd)))
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
  (let* ([sink (make-appsink #f canvas-sink%)]
         [canvas (get-field canvas sink)]
         [canvas-handle (send canvas get-gl-context-handle)])
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
