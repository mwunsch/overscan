#lang overscan

(require (only-in ffi/unsafe/introspection
                  gobject-with-properties))

;; gst-launch-1.0 videomixer name=final ! videoconvert ! video/x-raw,width=640,height=640 ! osxvideosink sync=false \
;;                filesrc location=racket-logo.svg.png ! pngdec ! imagefreeze ! videoconvert ! tee name=logo \
;;                videomixer name=background ! final. \
;;                videomixer name=foreground ! alpha method=custom target-r=253 target-g=164 target-b=40 ! final. \
;;                videotestsrc pattern=snow ! video/x-raw,width=640,height=640 ! background. \
;;                logo. ! queue ! alpha method=custom target-r=253 target-g=164 target-b=40 ! background. \
;;                videotestsrc pattern=smpte100 ! video/x-raw,width=640,height=640 ! foreground. \
;;                logo. ! queue ! alpha method=custom target-r=127 target-g=15 target-b=126 ! foreground.


(define pipeline
  (let* ([pl (pipeline%-new)]
         [foreground (videomixer "foreground")]
         [background (videomixer "background")]
         [logosrc (bin%-compose "logo"
                                (filesrc "racket-logo-svg.png")
                                (element-factory%-make "pngdec")
                                (element-factory%-make "imagefreeze")
                                (element-factory%-make "videoconvert"))]
         [logotee (tee)]
         [foreq (bin%-compose #f
                              (element-factory%-make "queue")
                              (gobject-with-properties (element-factory%-make "alpha")
                                                       (hash 'method 3
                                                             'target-r 253
                                                             'target-g 164
                                                             'target-b 40)))]
         [backq (bin%-compose #f
                              (element-factory%-make "queue")
                              (gobject-with-properties (element-factory%-make "alpha")
                                                       (hash 'method 3
                                                             'target-r 127
                                                             'target-g 15
                                                             'target-b 126)))]
         [forepattern (videotestsrc #:pattern 'smpte100)]
         [backpattern (videotestsrc #:pattern 'snow)]
         [destination (videomixer "destination")]
         [sink (bin%-compose #f
                             (element-factory%-make "videoconvert")
                             (capsfilter (video/x-raw 640 640))
                             (element-factory%-make "fakesink"))])
    (and (send pl add-many logosrc logotee)
         (send pl add-many forepattern foreq foreground)
         (send pl add-many backpattern backq background)
         (send pl add-many destination sink)
         (send logosrc link logotee)
         (send logotee link foreq)
         (send logotee link backq)
         (send forepattern link-filtered foreground (video/x-raw 640 640))
         (send foreq link foreground)
         (send backpattern link-filtered background (video/x-raw 640 640))
         (send backq link background)
         (send foreground link destination)
         (send background link destination)
         (send destination link sink)
         pl)))
