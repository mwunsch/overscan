#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (only-in ffi/unsafe cast _pointer _uintptr)
         (prefix-in objc: ffi/unsafe/objc)
         racket/class
         racket/contract
         (only-in racket/function const curry thunk)
         sgl/gl
         gstreamer/gst
         gstreamer/appsink
         gstreamer/caps
         gstreamer/event
         gstreamer/buffer
         gstreamer/element
         gstreamer/elements
         gstreamer/factories
         gstreamer/video)

(provide (contract-out [make-gui-sink
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c element%))]))

(define gst-gl
  (introspection 'GstGL))

(define gst-gl-context
  (gst-gl 'GLContext))

(define gst-gl-display
  (gst-gl 'GLDisplay))

(define gl-memory?
  (gst-gl 'is_gl_memory))

(define GL-DISPLAY-CONTEXT-TYPE
  ((gst-gl 'GL_DISPLAY_CONTEXT_TYPE)))

(define gst-glcontext%
  (class gst-object%
    (super-new)
    (inherit-field pointer)))

(define glcanvas%
  (class canvas%
    (inherit refresh get-dc with-gl-context swap-gl-buffers)
    (super-new [style '(gl no-autoclear)])

    (define/public (get-gl-context-handle)
      (with-gl-context
        (thunk
         (let ([handle (send (get-current-gl-context) get-handle)])
           (with-handlers ([exn:fail:contract? (const handle)])
             (objc:tell handle CGLContextObj))))))

    (define/public (get-gl-context-intptr)
      (cast (get-gl-context-handle)
            _pointer
            _uintptr))

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
    (inherit get-context get-contexts post-message)
    (init-field [label (gobject-send pointer 'get_name)]
                [window (new frame%
                             [label label])])

    (field [canvas (new glcanvas%
                        [parent window])])

    (define gldisplay
      (gst-gl-display 'new))

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
             [video-info (caps->video-info caps)])
        ;; (unless (send window is-shown?)
        ;;   (send window show #t))
        buffer
        ))

    (define/public (new-context)
      (gst-gl-context 'new_wrapped
                      (gst-gl-display 'new)
                      (send canvas get-gl-context-intptr)
                      'cgl
                      'opengl3))

    (define/augment (on-eos)
      (send window show #f))))

(define (make-gui-sink [name #f])
  (let* ([sink (make-appsink #f canvas-sink%)]
         [canvas (get-field canvas sink)])
    sink))


(module+ main
  (gst-initialize)

  (define sinky (make-gui-sink))

  (define pipe (pipeline%-compose #f
                                  (videotestsrc #:live? #t #:pattern 'ball)
                                  sinky))

  (define (start)
    (send pipe set-state 'playing))

  (define (stop)
    (send pipe send-event (make-eos-event)))

  (send sinky new-context))
