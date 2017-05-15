#lang racket/base

(module+ test
  (require rackunit))

;; Notice
;; To install (from within the package directory):
;;   $ raco pkg install
;; To install (once uploaded to pkgs.racket-lang.org):
;;   $ raco pkg install <<name>>
;; To uninstall:
;;   $ raco pkg remove <<name>>
;; To view documentation:
;;   $ raco docs <<name>>
;;
;; For your convenience, we have included a LICENSE.txt file, which links to
;; the GNU Lesser General Public License.
;; If you would prefer to use a different license, replace LICENSE.txt with the
;; desired license.
;;
;; Some users like to add a `private/` directory, place auxiliary files there,
;; and require them in `main.rkt`.
;;
;; See the current version of the racket style guide here:
;; http://docs.racket-lang.org/style/index.html

;; Code here
(require gstreamer
         ffi/unsafe
         ffi/unsafe/introspection)

(let-values ([(initialized? argc argv) ((gst 'init_check) 0 #f)])
  (if initialized?
      (displayln ((gst 'version_string)))
      (error "Could not load Gstreamer")))

(define camera1 (element-factory% 'make "avfvideosrc" "camera1"))
(define tee (element-factory% 'make "tee" "tee"))
(define vidqueue (element-factory% 'make "queue" "vidqueue"))
(define preview (element-factory% 'make "osxvideosink" "osxvideosink"))
(define encoder (element-factory% 'make "vtenc_h264" "h264"))
(define parser (element-factory% 'make "h264parse" "h264parse"))
(define muxer (element-factory% 'make "mp4mux" "mp4mux"))
(define filesink (element-factory% 'make "filesink" "filesink"))

(define pipeline (pipeline% 'new "stream"))

(gobject-set! filesink "location" "test.mp4" _string)

(bin-add-many pipeline camera1 tee vidqueue preview encoder parser muxer filesink)

(send camera1 link tee)
(send tee link vidqueue)
(send vidqueue link preview)
(send tee link encoder)
(send encoder link parser)
(send parser link muxer)
(send muxer link filesink)

; (send pipeline set-state 'playing)
; (send pipeline send-event eos)
; (send pipeline set-state 'null)

(module+ test
  ;; Tests to be run with raco test
  )

(module+ main

  )
