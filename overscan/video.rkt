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
                             (#:pixel-aspect-ratio string?
                              #:fps string?)
                             caps?)]
                       [video-resolutions
                        (hash/c symbol?
                                (cons/c exact-nonnegative-integer?
                                        exact-nonnegative-integer?))]
                       [video-resolution-ref
                        (-> symbol?
                            (values exact-nonnegative-integer?
                                    exact-nonnegative-integer?))]
                       [video-resolution
                        (-> symbol?
                            caps?)]
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
                       [set-picture-in-picture-position!
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]
                       [set-picture-in-picture-size!
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]
                       [set-picture-in-picture-alpha!
                        (-> (is-a?/c bin%)
                            (real-in 0 1)
                            void?)]
                       [video-resolution/c
                        flat-contract?]))

(define (video/x-raw width height
                     #:pixel-aspect-ratio [par "1/1"]
                     #:fps [fps "30/1"])
  (let ([str (format "video/x-raw,width=~a,height=~a,pixel-aspect-ratio=~a,framerate=~a"
                     width height par fps)])
    (string->caps str)))

(define video-resolutions
  (hash '240p '(426 . 240)
        '360p '(640 . 360)
        '480p '(854 . 480)
        '720p '(1280 . 720)
        '1080p '(1920 . 1080)
        '1440p '(2560 . 1440)
        '4k '(3840 . 2160) ; tbh my computer would probably melt
        ))

(define video-resolution/c
  (apply symbols (hash-keys video-resolutions)))

(define (video-resolution-ref resolution)
  (let ([pair (hash-ref video-resolutions resolution)])
    (values (car pair)
            (cdr pair))))

(define (video-resolution resolution)
  (let-values ([(width height) (video-resolution-ref resolution)])
    (video/x-raw width height)))

(define (video:720p [name #f])
  (capsfilter (video-resolution '720p) name))

(define (picture-in-picture video1 video2 [name #f]
                            #:width [width 640]
                            #:height [height 360]
                            #:x [xpos 20]
                            #:y [ypos 20]
                            #:alpha [alpha 1.0]
                            #:resolution [resolution '720p])
  (let* ([bin (bin%-new name)]
         [bin-name (send bin get-name)]
         [mixer (videomixer (format "~a:mixer" bin-name))]
         [boxscale (bin%-compose #f
                                 (element-factory%-make "videorate"))]
         [vidbox (videobox (format "~a:box" bin-name))]
         [box-bin (bin%-compose #f
                                (videoscale)
                                (element-factory%-make "videorate")
                                (capsfilter (video/x-raw width height)
                                            (format "~a:box-size" bin-name))
                                vidbox)]
         [main-picture (bin%-compose #f
                                     video2
                                     (capsfilter (string->caps "video/x-raw,pixel-aspect-ratio=1/1"))
                                     (videoscale)
                                     (element-factory%-make "videorate"))]
         [mixpad (send mixer get-static-pad "src")])
    (and (send bin add mixer)
         (send bin add-pad (ghost-pad%-new "src" mixpad))
         (send bin add-many video1 box-bin)
         (send bin add main-picture)
         (send video1 link-filtered box-bin (string->caps "video/x-raw,pixel-aspect-ratio=1/1"))
         (send main-picture link-filtered mixer (video-resolution resolution))
         (send box-bin link mixer)
         (set-picture-in-picture-position! bin xpos ypos)
         (set-picture-in-picture-alpha! bin alpha)
         bin)))

(define (set-picture-in-picture-position! pip x y)
  (let* ([pip-name (send pip get-name)]
         [mixer (send pip get-by-name (format "~a:mixer" pip-name))]
         [src (videomixer-ref mixer 1)])
    (gobject-set! src "xpos" x)
    (gobject-set! src "ypos" y)))

(define (set-picture-in-picture-size! pip width height)
  (let* ([pip-name (send pip get-name)]
         [boxfilter (send pip get-by-name (format "~a:box-size" pip-name))])
    (set-capsfilter-caps! boxfilter (video/x-raw width height))))

(define (set-picture-in-picture-alpha! pip alpha)
  (let* ([pip-name (send pip get-name)]
         [mixer (send pip get-by-name (format "~a:mixer" pip-name))]
         [src (videomixer-ref mixer 1)])
    (gobject-set! src "alpha" alpha)))
