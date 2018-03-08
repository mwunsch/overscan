#lang racket/base

(require racket/class
         racket/contract
         ffi/unsafe/introspection
         (only-in ffi/unsafe _int)
         gstreamer)

(provide (contract-out [picture-in-picture
                        (->* ((is-a?/c element%) (is-a?/c element%))
                             ((or/c string? #f))
                             (is-a?/c bin%))]
                       [picture-in-picture-reposition
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]))

(define (video-caps width height)
  ;; crashes on Racket 6.12?
  (let ([str (format "video/x-raw,width=~a,height=~a" width height)])
    (string->caps str)))

(define (picture-in-picture video1 video2 [name #f])
  (let ([mixer (videomixer "mixer")]
        [bin (bin%-new name)])
    (send bin add-many video1 video2 mixer)
    (send video1 link mixer)
    (send video2 link mixer)
    bin))

(define (picture-in-picture-reposition pip x y)
  (let* ([mixer (send pip get-by-name "mixer")]
         [src (videomixer-ref mixer 1)])
    (gobject-set! src "xpos" x _int)
    (gobject-set! src "ypos" y _int)))
