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

(define source (element-factory 'make "uridecodebin" "source"))
(define converter (element-factory 'make "audioconvert" "convert"))
(define sink (element-factory 'make "osxaudiosink" "sink"))

(define pipeline ((gst 'Pipeline) 'new "test-pipeline"))

(bin-add-many pipeline source converter sink)

(send converter link sink)

(gobject-set! source "uri" "http://movietrailers.apple.com/movies/marvel/thor-ragnarok/thor-ragnarok-trailer-1_h480p.mov" _string)

(define (pad-handler el new-pad user-data)
  (define sink-pad (gobject-cast user-data (gst 'Pad)))
  (if (send sink-pad is-linked)
      (println "We are already linked. Ignoring.")
      (let* ([pad-caps (send new-pad query-caps #f)]
             [pad-struct (pad-caps 'get_structure 0)]
             [pad-type (pad-struct 'get_name)])
        (if (string=? pad-type "audio/x-raw")
            (send new-pad link sink-pad)
            (printf "It has type ~a which is not raw audio. Ignoring.~n" pad-type)))))

(connect source 'pad-added pad-handler
         #:data (send converter get-static-pad "sink"))

;; (send pipeline set-state 'playing)

(define bus (send pipeline get-bus))

;; (send bus timed-pop-filtered clock-time-none '(error eos))
