#lang overscan

(require gstreamer/gui
         ffi/unsafe/introspection
         racket/gui
         (only-in ffi/unsafe _racket)
         (only-in racket/function thunk))

(define sinky (make-gui-sink))
(define window (get-field window sinky))
(define area (get-field canvas sinky))

(add-listener (lambda (msg pipeline)
                (when (prepare-window-handle-msg? msg)
                  (send sinky expose!))))

(add-listener (lambda (msg pipeline)
                (when (fatal-message? msg)
                  (send window show #f))))

(define pipe (pipeline%-compose #f
                                (videotestsrc #:live? #t #:pattern 'ball)
                                sinky))

; (with-handlers ([exn:break? (lambda (ex)
;                               (stop))])
;   (thread-wait (start pipe)))
