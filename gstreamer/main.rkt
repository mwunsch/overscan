#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection)

(provide gst)

(define gst (introspection 'Gst))

(if ((gst 'init_check) 0 #f)
    (displayln ((gst 'version_string)))
    (error "Could not load Gstreamer"))

(define element-factory (gst 'ElementFactory))

(define system-clock ((gst 'SystemClock) 'obtain))

(define (bin-add-many bin . elements)
  (for/and ([element elements])
    (send bin add element)))

(define source (element-factory 'make "videotestsrc" "source"))
;; (define sink (element-factory 'make "autovideosink" "sink"))
(define sink (element-factory 'make "osxvideosink" "sink"))

(define pipeline ((gst 'Pipeline) 'new "test-pipeline"))

(define _test-pattern (_enum '(smpte snow black white red green blue
                                     checkers1 checkers2 checkers4 checkers8
                                     circular blink smpte75 zone-plate gamut
                                     chroma-zone-plate solid ball smpte100 bar
                                     pinwheel spokes gradient colors)))

(bin-add-many pipeline source sink)

(send source link sink)

;; (send pipeline set-state 'playing)
