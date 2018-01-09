#lang racket/base

(require ffi/unsafe/introspection
         (rename-in ffi/unsafe [-> ~>])
         racket/class
         racket/contract
         racket/draw
         racket/draw/unsafe/cairo
         "private/core.rkt"
         gstreamer/gst
         gstreamer/element)

(provide (contract-out [cairo-overlay%
                        (subclass?/c element%)]
                       [make-cairo-overlay
                        (->* ((is-a?/c bitmap-dc%))
                             ((or/c string? false/c))
                             (is-a?/c cairo-overlay%))]))

(define cairo-overlay%
  (class element%
    (super-new)
    (inherit-field pointer)
    (init-field dc)

    (define target
      (send dc get-bitmap))

    (define surface
      (and target
           (send target get-handle)))

    (define draw-signal
      (connect pointer 'draw (lambda (overlay ptr timestamp duration data)
                               (let ([cr (cast ptr _pointer _cairo_t)])
                                 (cairo_set_source_surface cr data 0.0 0.0)
                                 (cairo_paint cr)))
               #:data surface
               #:cast _cairo_surface_t))

    (define/public (get-dc)
      dc)))

(define (make-cairo-overlay dc
                            [name #f])
  (let ([el (gst-element-factory 'make "cairooverlay" name)])
    (and el
         (new cairo-overlay% [pointer el] [dc dc]))))
