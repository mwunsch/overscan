#lang overscan

(require gstreamer/gui
         ffi/unsafe/introspection
         racket/gui
         (only-in ffi/unsafe _racket)
         (only-in racket/function thunk))

(define sinky (make-gui-sink))

(define pipe (pipeline%-compose #f
                                (videotestsrc #:live? #t #:pattern 'ball)
                                sinky))

; (with-handlers ([exn:break? (lambda (ex)
;                               (stop))])
;   (thread-wait (start pipe)))
