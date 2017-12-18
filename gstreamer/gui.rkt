#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         (prefix-in objc: ffi/unsafe/objc)
         ffi/unsafe/define
         racket/class
         racket/contract
         (only-in racket/function const curry thunk)
         sgl/gl
         "private/core.rkt"
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

(define gst-gl-platform
  (gst-gl 'GLPlatform))

(define gst-gl-api
  (gst-gl 'GLAPI))

(define gst-gl-upload
  (gst-gl 'GLUpload))

(define gl-memory?
  (gst-gl 'is_gl_memory))

(define GL-DISPLAY-CONTEXT-TYPE
  ((gst-gl 'GL_DISPLAY_CONTEXT_TYPE)))

(define-ffi-definer define-gstgl (gi-repository->ffi-lib gst-gl))

;;; This function works (eg. does not crash) when called outside
(define-gstgl gst-gl-context-new-wrapped
  (_fun (_gi-object gst-gl-display)
        _uintptr
        (_gi-enum gst-gl-platform)
        (_gi-enum gst-gl-api)
        ~> (_gi-object gst-gl-context))
  #:c-id gst_gl_context_new_wrapped)

(define glcanvas%
  (class canvas%
    (inherit refresh get-dc with-gl-context swap-gl-buffers)
    (super-new [style '(gl no-autoclear)])

    (define gst-gldisplay
      (gst-gl-display 'new))

    (define gl-context-handle
      (with-gl-context
        (thunk
         (let ([handle (send (get-current-gl-context) get-handle)])
           (with-handlers ([exn:fail:contract? (const handle)])
             (objc:tell handle CGLContextObj))))))

    (define/public (get-gl-context-handle)
      gl-context-handle)

    (define gst-glcontext
      (gst-gl-context-new-wrapped (gi-instance-pointer gst-gldisplay)
                                  (cast (get-gl-context-handle) _pointer _uintptr)
                                  '(any)
                                  '(opengl3)))

    (define gst-glupload
      (gst-gl-upload 'new gst-glcontext))

    (gobject-send gst-glcontext 'activate #t)

    (define/public (get-gst-glcontext)
      gst-glcontext)

    (define/public (get-gst-glupload)
      gst-glupload)

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
             [glcontext (send canvas get-gst-glcontext)])
        (if glcontext
            (begin
              (resize-area (gobject-get-field 'width vidinfo)
                           (gobject-get-field 'height vidinfo))

              ;upload buffer to glcontext
              ;draw to canvas
              (unless (send window is-shown?)
                (send window show #t)))
            (error "no context"))))

    (define/augment (on-eos)
      (send window show #f))))

(define (make-gui-sink [name #f])
  (bin%-compose name
                (element-factory%-make "glupload")
                (make-appsink #f canvas-sink%)))


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
