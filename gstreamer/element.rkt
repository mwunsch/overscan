#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound? is-a? is-a?/c)
         racket/class
         "gst.rkt")

(provide element%
         element-factory%)

(define element-factory%
  (let ([elfac (gst 'ElementFactory)])
    (class* object% (gobject<%>)
            (init-field name)
            (field [pointer (elfac 'find name)])
            (super-new)
            (define/public (create name)
              (let ([el (gobject-send pointer 'create name)])
                (new element% [pointer el]))))))

(define element%
  (class gobject%
    (super-new)))

(define (sink? el)
  (and (zero? (get-field numsrcpads el))
       (positive? (get-field numsinkpads el))))

(define (src? el)
  (not (sink? el)))
