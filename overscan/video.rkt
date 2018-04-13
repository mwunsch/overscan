#lang racket/base

(require racket/class
         racket/contract
         (only-in racket/function curry)
         ffi/unsafe/introspection
         (only-in ffi/unsafe _int)
         gstreamer)

(provide (contract-out [video/x-raw
                        (->* (exact-nonnegative-integer?
                              exact-nonnegative-integer?)
                             ((or/c string? false/c)
                              #:pixel-aspect-ratio string?
                              #:fps string?)
                             capsfilter?)]
                       [video-resolution-filters
                        (hash/c symbol?
                                (->* ()
                                     ((or/c string? false/c))
                                     capsfilter?))]
                       [video:720p
                        (->* ()
                             ((or/c string? false/c))
                             capsfilter?)]
                       [picture-in-picture
                        (->* ((is-a?/c element%) (is-a?/c element%))
                             ((or/c string? #f)
                              #:width exact-nonnegative-integer?
                              #:height exact-nonnegative-integer?
                              #:x exact-integer?
                              #:y exact-integer?
                              #:alpha (real-in 0 1))
                             (or/c (is-a?/c bin%) false/c))]
                       [picture-in-picture-reposition
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]
                       [picture-in-picture-resize
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]))

(define (video-caps width height [par "1/1"] [fps "30/1"])
  (let ([str (format "video/x-raw,width=~a,height=~a,pixel-aspect-ratio=~a,framerate=~a"
                     width height par fps)])
    (string->caps str)))

(define (video/x-raw width height [name #f]
                     #:pixel-aspect-ratio [par "1/1"]
                     #:fps [fps "30/1"])
  (capsfilter (video-caps width height par fps) name))

(define video-resolution-filters
  (hash '720p (curry video/x-raw 1280 720)))

(define (video:720p [name #f])
  (let ([f (hash-ref video-resolution-filters '720p)])
    (f name)))

(define (picture-in-picture video1 video2 [name #f]
                            #:width [width 320]
                            #:height [height 240]
                            #:x [xpos #f]
                            #:y [ypos #f]
                            #:alpha [alpha 1.0])
  (let* ([mixer (videomixer "mixer")]
         [vidbox (videobox "box")]
         [vidfilter (video/x-raw width height "filter")]
         [mixpad (send mixer get-static-pad "src")]
         [bin (bin%-new name)])
    (and (send bin add-many video1 video2 vidbox vidfilter mixer)
         (send video1 link mixer)
         (send video2 link vidbox)
         (send vidbox link vidfilter)
         (send vidfilter link mixer)
         (send bin add-pad (ghost-pad%-new "src" mixpad))
         (set-videobox-alpha! vidbox alpha)
         (when (or xpos ypos)
           (picture-in-picture-reposition bin
                                          (or xpos 0)
                                          (or ypos 0)))
         bin)))

(define (picture-in-picture-reposition pip x y)
  (let* ([mixer (send pip get-by-name "mixer")]
         [src (videomixer-ref mixer 1)])
    (gobject-set! src "xpos" x _int)
    (gobject-set! src "ypos" y _int)))

(define (picture-in-picture-resize pip width height)
  (let ([vidfilter (send pip get-by-name "filter")])
    ;; TODO: par and fps!
    (set-capsfilter-caps! vidfilter (video-caps width height))))
