#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         "gst.rkt"
         "element.rkt")

(provide (contract-out [bin%
                        (class/c
                         [add
                          (->m (is-a?/c element%) boolean?)]
                         [remove
                          (->m (is-a?/c element%) boolean?)]
                         [get-by-name
                          (->m string? (or/c (is-a?/c element%) false/c))]
                         [add-many
                          (->m (is-a?/c element%) (is-a?/c element%) ... boolean?)]
                         [find-unlinked-pad
                          (->m (gi-enum-value/c pad-direction) (or/c (is-a?/c pad%) false/c))]
                         [sync-children-states
                          (->m boolean?)])]
                       [bin->dot
                        (->* ((is-a?/c bin%))
                             (#:details (gi-enum-value/c gst-debug-graph-details))
                             string?)]))

(define bin-mixin
  (make-gobject-delegate add
                         remove
                         get-by-name
                         find-unlinked-pad
                         sync-children-states))

(define bin%
  (class (bin-mixin element%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-by-name name)
      (let ([el (super get-by-name name)])
        (and el
             (new element% [pointer el]))))
    (define/public (add-many el_1 . els)
      (for/and ([el (list* el_1 els)])
        (send this add el)))
    (define/override (find-unlinked-pad direction)
      (let ([pad (super find-unlinked-pad direction)])
        (and pad
             (new pad% [pointer pad]))))))

(define gst-debug-bin->dot-data
  (gst 'debug_bin_to_dot_data))

(define gst-debug-graph-details
  (gst 'DebugGraphDetails))

(define (bin->dot bin
                  #:details [details 'all])
  (gst-debug-bin->dot-data bin details))
