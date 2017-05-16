#lang racket/base

(require gstreamer
         ffi/unsafe
         ffi/unsafe/introspection)

(let-values ([(initialized? argc argv) ((gst 'init_check) 0 #f)])
  (if initialized?
      (displayln ((gst 'version_string)))
      (error "Could not load Gstreamer")))

(define current-broadcast (box #f))

(define (broadcast scene
                   #:preview [preview (element-factory% 'make "osxvideosink" #f)]
                   #:record [recording ()])
  (let ([pipeline (pipeline% 'new "broadcast")])
    (and (bin-add-many pipeline scene preview)
         (element-link-many scene preview)
         (send pipeline set-state 'playing)
         (set-box! current-broadcast pipeline))))

(define (end-broadcast [broadcast (unbox current-broadcast)])
  (and broadcast
       (send broadcast send-event (event% 'new_eos))
       (send broadcast set-state 'null)
       (set-box! current-broadcast #f)))

(define (scene)
  (let ([bin (bin% 'new "scene")]
        [camera (element-factory% 'make "avfvideosrc" "camera")])
    (if (send bin add camera)
        (let* ([pad (send camera get-static-pad "src")])
          (or (and pad
                   (send bin add-pad ((gst 'GhostPad) 'new "src" pad))
                   bin)
              (error "could not create scene")))
        (error "could not create scene"))))
