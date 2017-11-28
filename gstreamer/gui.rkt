#lang racket/gui

;;; Experimental AF

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/introspection
         racket/class
         (only-in racket/function thunk)
         (rename-in racket/contract [-> ->>])
         gstreamer/gst
         gstreamer/element
         gstreamer/bus
         gstreamer/factories)

(provide (contract-out [prepare-window-handle-msg?
                        (->> message? boolean?)]
                       [video-overlay%
                        (class/c
                         [expose!
                          (->m void?)]
                         [set-render-rectangle
                          (->m exact-integer?
                               exact-integer?
                               exact-integer?
                               exact-integer?
                               boolean?)])]
                       [make-gui-sink
                        (->> (is-a?/c video-overlay%))]))

(define gst-video
  (introspection 'GstVideo))

(define gst-gl
  (introspection 'GstGL))

(define video-overlay-interface
  (gst-video 'VideoOverlayInterface))

(define gst-glcontext
  (gst-gl 'GLContext))

;;; VideoOverlayInterface is a gi-struct that defines its members as
;;; virtual functions, which ffi/unsafe/introspection does not yet
;;; support. They are defined explicitly with ffi here.

(define-ffi-definer define-gst-video
  (gi-repository->ffi-lib gst-video))

(define-gst-video set-window-handle (_fun _pointer _pointer -> _void)
  #:c-id gst_video_overlay_set_window_handle)

(define-gst-video expose (_fun _pointer -> _void)
  #:c-id gst_video_overlay_expose)

(define-gst-video set-render-rectangle (_fun _pointer _int _int _int _int -> _bool)
  #:c-id gst_video_overlay_set_render_rectangle)

(define-gst-video handle-events (_fun _pointer _bool -> _void)
  #:c-id gst_video_overlay_handle_events)

(define-gst-video prepare-window-handle-msg? (_fun _pointer -> _bool)
  #:c-id gst_is_video_overlay_prepare_window_handle_message)

(define video-overlay%
  (class* element% ()
    (super-new)
    (inherit-field pointer)
    (init-field [label (gobject-send pointer 'get_name)]
                [window (new frame%
                              [label label]
                              [width 640]
                              [height 480])]
                [canvas (new canvas%
                             [parent window]
                             [style '(gl no-autoclear)])])
    (define/public (expose!)
      (expose pointer))
    (define/public (set-render-rectangle x y width height)
      (set-render-rectangle pointer x y width height))
    (define/public (get-glcontext)
      (gobject-get pointer "context" gst-glcontext))

    (set-window-handle pointer (send canvas get-client-handle))))

(define (make-gui-sink)
  (let* ([el (element-factory%-make "glimagesink")]
         [ptr (get-field pointer el)])
    (parameterize ([current-eventspace (make-eventspace)])
      (new video-overlay% [pointer ptr]))))
