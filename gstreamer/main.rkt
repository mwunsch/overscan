#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         racket/place
         "gst.rkt"
         "bus.rkt")

(provide main)

(let-values ([(initialized? argc argv) ((gst 'init_check) 0 #f)])
  (if initialized?
      (displayln ((gst 'version_string)))
      (error "Could not load Gstreamer")))

(define element-factory (gst 'ElementFactory))

(define clock-time-none ((gst 'CLOCK_TIME_NONE)))

(define millisecond ((gst 'MSECOND)))

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

(define playbin (element-factory 'make "playbin" "playbin"))

(gobject-set! playbin "uri" "http://movietrailers.apple.com/movies/marvel/thor-ragnarok/thor-ragnarok-trailer-1_h480p.mov" _string)

(define (main)
  (send playbin set-state 'playing)
  (define pipe
    (make-bus-channel (send playbin get-bus)))
  (thread (lambda () (let loop ()
                  (define msg (sync pipe))
                  (println (get-field type msg))
                  (unless (memf (lambda (x) (memq x '(eos error))) (get-field type msg))
                    (loop))))))
