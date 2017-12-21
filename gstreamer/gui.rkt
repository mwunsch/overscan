#lang racket/gui

;;; Experimental AF

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         ffi/vector
         (prefix-in objc: ffi/unsafe/objc)
         ffi/unsafe/define
         racket/class
         racket/contract
         (only-in racket/function const curry thunk)
         (only-in racket/string string-join)
         sgl/gl
         "private/core.rkt"
         gstreamer/gst
         gstreamer/appsink
         gstreamer/caps
         gstreamer/context
         gstreamer/event
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

(define gst-gl
  (introspection 'GstGL))

(define gst-gl-context
  (gst-gl 'GLContext))

(define gst-gl-display
  (gst-gl 'GLDisplay))

(define gst-gl-platform
  (gst-gl 'GLPlatform))

(define gst-gl-memory
  (gst-gl 'GLMemory))

(define gst-gl-basememory
  (gst-gl 'GLBaseMemory))

(define gst-gl-api
  (gst-gl 'GLAPI))

(define gst-gl-upload
  (gst-gl 'GLUpload))

(define gl-memory?
  (gst-gl 'is_gl_memory))

(define GL-DISPLAY-CONTEXT-TYPE
  ((gst-gl 'GL_DISPLAY_CONTEXT_TYPE)))

(define CAPS-FEATURE-MEMORY-GL-MEMORY
  ((gst-gl 'CAPS_FEATURE_MEMORY_GL_MEMORY)))

(define context-set-gl-display
  (gst-gl 'context_set_gl_display))

(define-ffi-definer define-gstgl (gi-repository->ffi-lib gst-gl))

;;; This function works (eg. does not crash) when called outside
(define-gstgl gst-gl-context-new-wrapped
  (_fun (_gi-object gst-gl-display)
        _uintptr
        (_gi-enum gst-gl-platform)
        (_gi-enum gst-gl-api)
        ~> (_gi-object gst-gl-context))
  #:c-id gst_gl_context_new_wrapped)

(define-gstgl gst-gl-upload-perform
  (_fun (_gi-object gst-gl-upload)
        (_gi-struct gst-buffer)
        (_ptr o (_gi-struct gst-buffer))
        ~> (_gi-enum (gst-gl 'GLUploadReturn)))
  #:c-id gst_gl_upload_perform_with_buffer)

(define glcanvas%
  (class canvas%
    (inherit refresh get-dc with-gl-context swap-gl-buffers)
    (super-new [style '(gl no-autoclear)])

    (define gl-context-handle
      (with-gl-context
        (thunk
         (let ([handle (send (get-current-gl-context) get-handle)])
           (with-handlers ([exn:fail:contract? (const handle)])
             (objc:tell handle CGLContextObj))))))

    (define/public (get-gl-context-handle)
      gl-context-handle)

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
    (inherit get-context set-context get-contexts post-message)
    (init-field [label (gobject-send pointer 'get_name)]
                [window (new frame%
                             [label label])])

    (field [canvas (new glcanvas%
                        [parent window])])

    (define gst-gldisplay
      (gst-gl-display 'new))

    (set-context (let ([context (gst-context 'new GL-DISPLAY-CONTEXT-TYPE #t)])
                   (context-set-gl-display context gst-gldisplay)
                   context))

    (define gst-glcontext
      (let ([handle (send canvas get-gl-context-handle)])
        (gst-gl-context-new-wrapped gst-gldisplay
                                    (cast handle _pointer _uintptr)
                                    '(cgl)
                                    '(opengl3))))

    (set-context (make-context "gst.gl.app_context"
                               "gst.gl.app_context"
                               gst-glcontext
                               #t))

    (define gst-glcontext-active?
      #f)

    (define/public (get-gst-glcontext)
      gst-glcontext)

    (define/public (activate-glcontext!)
      (set! gst-glcontext-active?
            (gobject-send gst-glcontext 'activate #t)))

    (define/public (active-glcontext?)
      gst-glcontext-active?)

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
             [memory (buffer-memory buffer)])

        ;; (begin
        ;;   (unless (active-glcontext?)
        ;;     (activate-glcontext!))

        ;;   (resize-area width height)

        ;;   (when (andmap gl-memory? memory)
        ;;     (unless (send window is-shown?)
        ;;       (send window show #t))
        ;;     (draw-gl-memory memory))

        (let* ([frame (video-frame-map vidinfo buffer '(read))]
               [data (video-frame-data frame)])
          (println (array-ref data 1))
          ;; (send bitmap set-argb-pixels 0 0 width height (map-info-data mapinfo))
          (video-frame-unmap! frame))

        ;;   (unless (send window is-shown?)
        ;;     (send window show #t)))
        ))

    (define/augment (on-eos)
      (send window show #f))

    (define (draw-gl-memory memory)
      (let* ([plane (first memory)]
             [txid (gst-gl-memory 'get_texture_id plane)])
        (send canvas with-gl-context
              (thunk
               (glClearColor 0 0 0 0)
               (glClear GL_COLOR_BUFFER_BIT)

               (glMatrixMode GL_PROJECTION)
               (glLoadIdentity)

               (glEnable GL_TEXTURE_2D)
               (glBindTexture GL_TEXTURE_2D txid)

               (glBegin GL_QUADS)

               (glVertex2f -1.0 -1.0)

               (glTexCoord2f 0.0 1.0)
               (glVertex2f -1.0 1.0)

               (glTexCoord2f 1.0 1.0)
               (glVertex2f 1.0 1.0)

               (glTexCoord2f 1.0 0.0)
               (glVertex2f 1.0 -1.0)
               (glEnd)))
        (send canvas swap-gl-buffers)))

    (define (get-gl-context-from-memory memory)
      (let* ([plane (first memory)]
             [glbasememory (gstruct-cast plane gst-gl-basememory)])
        (gobject-get-field 'context glbasememory)))))

(define (make-gui-sink [name #f])
  (let ([sink (make-appsink #f canvas-sink%)])
    ;; (gobject-with-properties (element-factory%-make "glsinkbin" name)
    ;;                          (hash 'sink sink))
    (bin%-compose name
                  (capsfilter (string->caps "video/x-raw,format=ARGB"))
                  sink)
    ))


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
