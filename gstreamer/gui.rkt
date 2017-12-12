#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (only-in ffi/unsafe cast _pointer _uintptr)
         (prefix-in objc: ffi/unsafe/objc)
         racket/class
         racket/contract
         (only-in racket/function curry thunk)
         sgl/gl
         gstreamer/gst
         "private/structure.rkt"
         gstreamer/caps
         gstreamer/context
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

(define gst-glmemory
  (gst-gl 'GLMemory))

(define gst-glbasememory
  (gst-gl 'GLBaseMemory))

(define gst-glcontext
  (gst-gl 'GLContext))

(define gst-gldisplay
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

    (define gst-gl-context
      #f)

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

    (define gst-gl-context
      #f)

    (define gl-app-context
      #f)

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
             [memory (buffer-memory buffer)]
             [context:gldisplay (get-context GL-DISPLAY-CONTEXT-TYPE)])

        (if context:gldisplay
            (begin
              (unless gl-app-context
                (make-wrapped-gl-context context:gldisplay))

              (when (andmap gl-memory? memory)
                (unless gst-gl-context
                  (set! gst-gl-context (get-gl-context-from-memory memory)))

                (unless (send window is-shown?)
                  (send window show #t))

                (let-values ([(vid-width vid-height)
                              (video-meta-dimensions video-meta)])
                  (resize-area vid-width vid-height))

                (draw-gl-texture memory)))
            (post-message
             (make-message:need-context this GL-DISPLAY-CONTEXT-TYPE)))))

    (define (make-wrapped-gl-context display-context)
      (send canvas with-gl-context
            (thunk
             (let* ([structure (context-structure display-context)]
                    [gldisplay (gst-structure-ref structure
                                                  (string->symbol GL-DISPLAY-CONTEXT-TYPE))]
                    [nsopenglcontext (send (get-current-gl-context) get-handle)]
                    [cglcontextobj (objc:tell nsopenglcontext CGLContextObj)]
                    [handle (cast cglcontextobj
                                  _pointer
                                  _uintptr)])
               (and gldisplay
                    (println (format "The next call to 'new_wrapped will crash. Handle is ~a. Display is ~a"
                                     handle
                                     (gobject-send gldisplay 'get_name)))
                    (gst-glcontext 'new_wrapped
                                   gldisplay
                                   handle
                                   '(cgl)
                                   (gobject-send gldisplay 'get_gl_api)))))))

    (define (get-gl-context-from-memory memory)
      (let* ([plane (first memory)]
             [glbasememory (gstruct-cast plane gst-glbasememory)])
        (gobject-get-field 'context glbasememory)))

    (define/augment (on-eos)
      (send window show #f))))

(define (make-gui-sink [name #f])
  (let* ([sink (make-appsink #f canvas-sink%)]
         [canvas (get-field canvas sink)])
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
