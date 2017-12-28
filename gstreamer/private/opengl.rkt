#lang racket/base

(require (rename-in ffi/unsafe [-> ~>])
         ffi/unsafe/define
         ffi/unsafe/introspection
         (prefix-in objc: ffi/unsafe/objc)
         racket/class
         racket/gui/base
         (only-in racket/function const thunk)
         sgl/gl
         "core.rkt")

;;; This module is very experimental, unfinished, and currently unused

(provide glcanvas%)

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
