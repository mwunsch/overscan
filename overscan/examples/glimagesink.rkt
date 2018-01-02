#lang overscan

(require gstreamer/gui
         ffi/unsafe/introspection
         racket/gui
         (only-in racket/function thunk))

(define sinky (make-gui-sink))

(define pipe (pipeline%-compose #f
                                (videotestsrc #:live? #t #:pattern 'ball)
                                (draw-overlay)
                                (element-factory%-make "videoconvert")
                                sinky))

; (with-handlers ([exn:break? (lambda (ex)
;                               (stop))])
;   (thread-wait (start pipe)))
