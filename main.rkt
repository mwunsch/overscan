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
(require ffi/unsafe
         ffi/unsafe/define)

(define-ffi-definer define-gst (ffi-lib "libgstreamer-1.0"))
(define-ffi-definer define-glib (ffi-lib "libglib-2.0"))

(define-gst gst_init (_fun _pointer _pointer -> _void))
(define-gst gst_init_check (_fun _pointer _pointer _pointer -> _bool))
(define-gst gst_version (_fun _pointer _pointer _pointer _pointer -> _void))
(define-gst gst_version_string (_fun -> _string))

(module+ test
  ;; Tests to be run with raco test
  )

(module+ main
  (displayln (format "This program is linked against ~a" (gst_version_string)))
  )
