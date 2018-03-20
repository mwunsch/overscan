#lang racket/base

(require racket/class
         racket/contract
         ffi/unsafe/introspection
         (only-in ffi/unsafe _int)
         gstreamer)

(provide (contract-out [picture-in-picture
                        (->* ((is-a?/c element%) (is-a?/c element%))
                             ((or/c string? #f)
                              #:width exact-nonnegative-integer?
                              #:height exact-nonnegative-integer?)
                             (or/c (is-a?/c bin%) false/c))]
                       [picture-in-picture-reposition
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]))

(define (video-caps width height)
  (let ([str (format "video/x-raw,width=~a,height=~a" width height)])
    (string->caps str)))

(define (picture-in-picture video1 video2 [name #f]
                            #:width [width 320]
                            #:height [height 240])
  (let* ([mixer (videomixer "mixer")]
         [vidbox (videobox "box")]
         [mixpad (send mixer get-static-pad "src")]
         [bin (bin%-new name)])
    (and (send bin add-many video1 video2 vidbox mixer)
         (send video1 link mixer)
         (send video2 link-filtered vidbox (video-caps width height))
         (send vidbox link mixer)
         (send bin add-pad (ghost-pad%-new "src" mixpad))
         bin)))

(define (picture-in-picture-reposition pip x y)
  (let* ([mixer (send pip get-by-name "mixer")]
         [src (videomixer-ref mixer 1)])
    (gobject-set! src "xpos" x _int)
    (gobject-set! src "ypos" y _int)))
