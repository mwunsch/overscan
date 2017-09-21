#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound? is-a? is-a?/c)
         racket/class
         "gst.rkt")

(provide element-factory%
         element%
         element-factory%-find
         element-factory%-make)

(define gst-element-factory (gst 'ElementFactory))

(define element-factory%
  (class gobject%
         (super-new)
         (inherit-field pointer)
         (define/public (get-name)
           (gobject-send pointer 'get_name))
         (define/public (create name)
           (let ([el (gobject-send pointer 'create name)])
             (new element% [pointer el])))
         (define/public (get-metadata)
           (for/hash ([key (in-vector (gobject-send pointer 'get_metadata_keys))])
                     (values (string->symbol key)
                             (gobject-send pointer 'get_metadata key))))))

(define (element-factory%-find name)
  (let ([factory (gst-element-factory 'find name)])
    (new element-factory% [pointer factory])))

(define (element-factory%-make factory-name name)
  (let ([el (gst-element-factory 'make factory-name name)])
    (new element% [pointer el])))

(define element-mixin
  (make-gobject-delegate get-name get-factory))

(define element%
  (class (element-mixin gobject%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-factory)
      (let ([fac (super get-factory)])
        (new element-factory% [pointer fac])))
    (define/public (get-num-src-pads)
      (gobject-get-field 'numsrcpads pointer))
    (define/public (get-num-sink-pads)
      (gobject-get-field 'numsinkpads pointer))
    (define/public (sink?)
      (and (zero? (get-num-src-pads))
           (positive? (get-num-sink-pads))))
    (define/public (src?)
      (not (sink?)))))
