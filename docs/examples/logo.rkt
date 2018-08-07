#lang overscan

;; gst-launch-1.0 videomixer name=final ! videoconvert ! video/x-raw,width=640,height=640 ! osxvideosink sync=false \
;;                filesrc location=racket-logo.svg.png ! pngdec ! imagefreeze ! videoconvert ! tee name=logo \
;;                videomixer name=background ! final. \
;;                videomixer name=foreground ! alpha method=custom target-r=253 target-g=164 target-b=40 ! final. \
;;                videotestsrc pattern=snow ! video/x-raw,width=640,height=640 ! background. \
;;                logo. ! queue ! alpha method=custom target-r=253 target-g=164 target-b=40 ! background. \
;;                videotestsrc pattern=smpte100 ! video/x-raw,width=640,height=640 ! foreground. \
;;                logo. ! queue ! alpha method=custom target-r=127 target-g=15 target-b=126 ! foreground.
