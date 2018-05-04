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
                       [picture-in-picture-reposition
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
                            void?)]
                       [picture-in-picture-resize
                        (-> (is-a?/c bin%)
                            exact-nonnegative-integer?
                            exact-nonnegative-integer?
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

(define (pair-values pair)
  (values (car pair)
          (cdr pair)))

(define (video-resolution resolution)
  (let-values ([(width height)
                (pair-values (hash-ref video-resolutions resolution))])
    (video/x-raw width height)))

(define (video:720p [name #f])
  (capsfilter (video-resolution '720p) name))

(define (picture-in-picture video1 video2 [name #f]
                            #:width [width 320]
                            #:height [height 240]
                            #:x [xpos #f]
                            #:y [ypos #f]
                            #:alpha [alpha 1.0])
  (let* ([bin (bin%-new name)]
         [bin-name (send bin get-name)]
         [mixer (videomixer (format "~a:mixer" bin-name))]
         [vidbox (make-video-box video2 width height (format "~a:box" bin-name))]
         [mixpad (send mixer get-static-pad "src")])
    (and (send bin add-many video1 vidbox mixer)
         (send video1 link mixer)
         (send vidbox link mixer)
         (send bin add-pad (ghost-pad%-new "src" mixpad))
         (set-video-box-alpha! vidbox alpha)
         (when (or xpos ypos)
           (picture-in-picture-reposition bin
                                          (or xpos 0)
                                          (or ypos 0)))
         bin)))

(define (picture-in-picture-reposition pip x y)
  (let* ([pip-name (send pip get-name)]
         [mixer (send pip get-by-name (format "~a:mixer" pip-name))]
         [src (videomixer-ref mixer 1)])
    (gobject-set! src "xpos" x _int)
    (gobject-set! src "ypos" y _int)))

(define (picture-in-picture-resize pip width height)
  (let* ([pip-name (send pip get-name)]
         [vidbox (send pip get-by-name (format "~a:box" pip-name))])
    ;; TODO this is not ideal...
    (video-box-resize pip width height)))

(define (make-video-box source width height [name #f])
  (bin%-compose name
                source
                (videoscale)
                (element-factory%-make "videorate")
                (videobox "box")
                (capsfilter (video/x-raw width height) "filter")))

(define (set-video-box-alpha! bin alpha)
  (let ([vidbox (send bin get-by-name "box")])
    (set-videobox-alpha! vidbox alpha)))

(define (video-box-resize bin width height
                          #:pixel-aspect-ratio [par "1/1"]
                          #:fps [fps "30/1"])
  (let ([vidfilter (send bin get-by-name "filter")])
    (set-capsfilter-caps! vidfilter (video/x-raw width height
                                                 #:pixel-aspect-ratio par
                                                 #:fps fps))))
