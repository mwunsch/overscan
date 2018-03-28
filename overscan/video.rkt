#lang racket/base

(require racket/class
         racket/contract
         ffi/unsafe/introspection
         (only-in ffi/unsafe _int)
         gstreamer)

(provide (contract-out [video-caps
                        (->* (exact-nonnegative-integer?
                              exact-nonnegative-integer?)
                             (#:pixel-aspect-ratio string?
                              #:fps string?)
                             (or/c caps? false/c))]
                       [video:720p
                        caps?]
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
                            void?)]))

(define (video-caps width height
                    #:pixel-aspect-ratio [par "1/1"]
                    #:fps [fps "30/1"])
  (let ([str (format "video/x-raw,width=~a,height=~a,pixel-aspect-ratio=~a,framerate=~a"
                     width height par fps)])
    (string->caps str)))

(define (video:720p)
  (video-caps 1280 720))

(define (picture-in-picture video1 video2 [name #f]
                            #:width [width 320]
                            #:height [height 240]
                            #:x [xpos #f]
                            #:y [ypos #f]
                            #:alpha [alpha 1])
  (let* ([mixer (videomixer "mixer")]
         [vidbox (videobox "box")]
         [mixpad (send mixer get-static-pad "src")]
         [bin (bin%-new name)])
    (and (send bin add-many video1 video2 vidbox mixer)
         (send video1 link mixer)
         (send video2 link-filtered vidbox (video-caps width height))
         (send vidbox link mixer)
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
