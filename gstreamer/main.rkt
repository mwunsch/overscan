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

(define clock-time-none ((gst 'CLOCK_TIME_NONE)))

(define (bin-add-many bin . elements)
  (for/and ([element elements])
    (send bin add element)))

(define (element-link-many . elements)
  (let link ([head (car elements)]
             [tail (cdr elements)])
    (if (pair? tail)
        (and (send head link (car tail))
             (link (car tail) (cdr tail)))
        #t)))


;;;;;


(define cam1 (element-factory 'make "avfvideosrc" "camera1"))
(define cam2 (element-factory 'make "avfvideosrc" "camera2"))
(define selector (element-factory 'make "input-selector" "switch"))
(define sink (element-factory 'make "osxvideosink" "sink"))

(gobject-set! cam2 "device-index" 1 _int)

(define pipeline ((gst 'Pipeline) 'new "test-pipeline"))

(bin-add-many pipeline cam1 cam2 selector sink)

(send cam1 link selector)
(send cam2 link selector)
(send selector link sink)

(define cam1src (send selector get-static-pad "sink_0"))
(define cam2src (send selector get-static-pad "sink_1"))
