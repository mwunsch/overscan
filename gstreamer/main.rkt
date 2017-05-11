#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         racket/place)

(provide gst)

(define gst (introspection 'Gst))

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
    (place chan
           (define bus (gobject-cast (place-channel-get chan) (gst 'Bus)))
           (let loop ()
             (define msg
               (send bus timed-pop-filtered (* 100 millisecond) '(eos error state-changed duration-changed)))
             (and msg
                  (place-channel-put chan (get-field type msg)))
             (loop))))
  (place-channel-put pipe (gtype-instance-pointer (send playbin get-bus)))
  (thread (lambda () (let loop ()
                  (println (place-channel-get pipe))
                  (loop)))))
